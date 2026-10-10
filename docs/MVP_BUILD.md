# MVP Build Order: module by module, with Studio tests

Build and test in this order. Each module runs on its own before the next one goes in.
Command-bar snippets go in **View → Command Bar** while a Play session is running. Make sure the dropdown says **Server**.

Handy server snippet (paste first, reuse `p`, `d`, `DS`):
```lua
local S = game.ServerScriptService.Server.Services
DS = require(S.DataService); p = game.Players:GetPlayers()[1]; d = DS.get(p)
```
After editing `d.*` by hand, call `DS.markDirty(p)` so the HUD refreshes.

---

## 0. Project setup
`rokit install` → `wally install` → `rojo serve` → Rojo plugin **Connect** in an empty Baseplate.
**Test:** Explorer shows `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `ServerScriptService.ServerPackages.ProfileStore` and `StarterPlayerScripts.Client`. Workspace › StreamingEnabled = true.

## 1. Shared config and economy (`src/shared`)
`Config/*`, `Economy`, `Trends`, `Format`, `Types`, `Signal`, `Net`.
**Test:**
- `python3 tools/sim_economy.py` prints the pacing table from the GDD.
- `lune run tests/shared` passes (formula, formatting and trend tests).
- Command bar (either side): `print(require(game.ReplicatedStorage.Shared.Format).short(1234567))` → `1.23M`.

## 2. Data persistence (`DataService`)
**Test:**
1. Press Play. A Followers column appears in the player list, and Output shows no errors.
2. Command bar: `print(d.Version, d.Gear.Camera, d.ActiveNiche)` → `1 1 Vlogs`.
3. **Persistence:** in Game Settings › Security, enable *Studio Access to API Services*. Set `UseLiveDataInStudio = true` in `Config/Game.luau`. Play, run `d.Cash = 777`, Stop, Play again, then `print(d.Cash)` → `777`. **Set the flag back to `false` afterwards.**
4. **Sanitize:** `d.Cash = -50; d.Gear.Camera = 99`, Stop and replay (live data on) → Cash `0`, Camera `10`. (Don't test with NaN: DataStores can't save it.)
5. **Session lock:** publish, then join the same place on two devices/servers with one account. The first server kicks with "opened on another server" and keeps the data.

## 3. Remote safety (`Util/Remotes`, `Guard`, `RateLimiter`)
**Test** (client command bar, i.e. an exploiter's view):
```lua
local rf = game.ReplicatedStorage.Remotes.BuyGear
print(rf:InvokeServer(0/0).err, rf:InvokeServer({}).err, rf:InvokeServer("Camera").err)
for i = 1, 200 do task.spawn(function() rf:InvokeServer("Camera") end) end
```
Expect `Unknown item`, `Unknown item`, `Not enough cash`. Then "Slow down!" replies, and a kick at 150 rejections within a minute.

## 4. Core loop (`ContentService` + `UI/FilmButton`)
**Test:**
1. Play as a new player. Without reading anything, tap 🎬 FILM, the bar sweeps, and the first take says **PERFECT!** wherever you tap. The views card counts up, about +3 👥 flies in, and the overhead billboard updates. All within about 5 seconds.
2. Takes 2–3 have a double-width green zone, then a normal one. A gold core = Perfect, green = Good, outside = Miss (still posts).
3. Mash the button: posts never come faster than about 1 per 1.55 s, and the taps are buffered.
4. Keys **F/E** and gamepad **R2/X** film too.
5. **Exploit check:** in the client command bar, `print(game.ReplicatedStorage.Remotes.SubmitTake:InvokeServer(1, 0.5).err)` → `No take in progress`.

## 5. Progression (`ProgressionService` + Shop/Niches/Rebrand screens)
**Test:**
1. After ~5 posts the 📱 Gear button shows "!" and glows. Buy the Hand-me-down Phone and the next post's views rise.
2. Command bar: `d.Cash = 1e6; d.Followers = 6000; DS.markDirty(p)`. Unlock Gaming, then Dance; you can't skip ahead to Cooking. SELECT switches niche.
3. `d.Followers = 1e6; DS.markDirty(p)`: ⭐ shows "!". In the Rebrand screen, the first tap arms the button and the second confirms. Cash, gear and followers reset, the title becomes **Rising Star**, the views bonus is ×1.5 and niches are kept.

## 6. Retention (`RewardService` + Deals screen + Trends + Viral)
**Test:**
1. **Daily:** the Deals screen shows Day 1 with an exact cash amount. Claim it, and the button becomes a countdown. Then `d.Daily.LastClaimDay -= 1; DS.markDirty(p)` → claim again = Day 2. Repeat to Day 7, which also starts a ⚡ boost.
2. **Brand Deals:** 3 fictional-sponsor deals. Post until one completes, then CLAIM. The cash shown is what you get.
3. **Offline:** `d.LastOnline = os.time() - 7200; require(S.RewardService).grantOffline(p, d)` → a "Welcome back" popup with followers and cash.
4. **Trends:** the banner shows the trend niche and a countdown. Tapping it switches niche if owned. Trend posts show 🔥 on the card.
5. **Viral Moments:** a new player gets a beam within ~40 s (or run `require(S.ViralService).spawnNow(true)`). The banner shows distance; standing inside gives ×5 and the full-screen WENT VIRAL.

## 7. Social (`SocialService`)
**Test:** Test tab → Clients and Servers → **2 players**. Stand within 25 studs and both film: cards show 🤝 COLLAB +20%. Walk apart and it disappears. Milestone toasts ("just hit 1K followers!") appear on both clients.

## 8. Leaderboards (`LeaderboardService` + board + Top screen)
**Test:** without API access, the spawn board and the 🏆 screen list the players in this server within ~5 s. With API access (live flag on, 2+ test accounts), entries persist across sessions. The Weekly tab shows the reset countdown, and your row is gold.

## 9. Monetization (`MonetizationService` + Store screen)
**Test:**
1. Create the 4 passes and 4 dev products in Creator Hub and paste the ids into `Config/Products.luau`. Rows with an id of 0 show **SOON**.
2. Studio test purchases are free. Buy **Cash Stack**: cash rises by exactly the amount shown on the row. Buy **Views Boost**: a ⚡ timer appears and stacks on a second buy.
3. Buy **2x Cash**: the post card shows double cash immediately. **Auto-Film**: the 🤖 toggle appears and posts every 2.5 s while you're idle, pausing while you film manually.
4. Rejoin: passes stay owned, and purchases are never granted twice (`print(#d.PurchaseIdCache)`).

## 10. Analytics (`Analytics`)
**Test:** Output shows no `[Analytics]` warnings while playing. After publishing, Creator Hub › Analytics › **Funnels** shows the 10 onboarding steps and **Economy** shows Cash sources and sinks. Data shows up after a few hours.

## 11. Device pass
**Test:** Studio Device Emulator → *iPhone SE* (smallest), a *low-end Android tablet*, and portrait mode. FILM is never under the thumbstick or jump button, and all text is readable. Gamepad: Y opens Gear, B closes, and the D-pad moves the selection inside a panel. MicroProfiler (Ctrl+F6) shows no script spikes over 1 ms.
