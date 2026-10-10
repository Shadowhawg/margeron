# Go Viral: Technical Architecture

## 1. Toolchain and workflow

| Tool | Purpose |
|---|---|
| **Rokit** (`rokit.toml`) | Pins tool versions: `rokit install` |
| **Rojo 7.7** | Syncs `src/` into Studio (`rojo serve`) or builds a place (`rojo build -o GoViral.rbxl`) |
| **Wally** | Packages. `wally install` → `ServerPackages/ProfileStore` |
| **luau-lsp** | Strict type checking. Every file is `--!strict`, and the code checks clean under both the new and the old Luau type solver |
| **selene / StyLua** | Lint and format (`selene src`, `stylua src`) |

```
rokit install && wally install
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
  --defs=@roblox=globalTypes.d.luau --ignore="ServerPackages/**" src
rojo serve      # then Connect from the Rojo Studio plugin
```

Get `globalTypes.d.luau` from the luau-lsp repo (`scripts/globalTypes.d.luau`), or let the VS Code extension manage it.

### Layout

```
ReplicatedStorage.Shared   (src/shared)   pure config + formulas used by both sides
ServerScriptService.Server (src/server)   authoritative services, one Script entry
StarterPlayerScripts.Client(src/client)   UI + input, one LocalScript entry
ServerScriptService.ServerPackages        Wally server realm (ProfileStore)
```

Services are plain ModuleScripts with `init()` (sync) and `start()` (connections/loops), started in explicit order by `Main.server.luau`. There's no framework, which means less magic for a solo dev to debug. Cross-service events use the typed `Shared/Signal`.

## 2. Security model (assume every client is an exploiter)

**Principle:** the client sends *intents* and never values. Every number a player can see or brag about is computed and stored on the server.

| Remote (client → server) | Args validated | Rate limit (burst / per s) | Server re-checks |
|---|---|---|---|
| StartTake | none | 4 / 2 | data loaded · no take in flight · sweep + cooldown elapsed |
| SubmitTake | `id` integer = live take id, `tap` ∈ [0,1] or nil | 4 / 2 | tap position reachable by server clock, take not expired |
| BuyGear | track ∈ Gear.Tracks | 6 / 3 | next tier exists, cash ≥ cost |
| UnlockNiche | id ∈ Niches | 4 / 1 | previous niche owned, followers + cash |
| SelectNiche | id ∈ Niches | 6 / 2 | owned |
| ClaimDaily | none | 3 / 0.5 | UTC day > last claim |
| ClaimDeal | index integer 1..3 | 5 / 1 | progress ≥ goal, unclaimed |
| Rebrand | none | 2 / 0.2 | followers ≥ requirement |
| SetAutoFilm | boolean | 3 / 1 | (owns pass checked at tick time) |

- All RemoteFunctions go through `Util/Remotes.handle`: a token bucket per player per remote, `pcall` (errors never leak to or hang the client), and **auto-kick after 150 rejected calls per minute**.
- Guard rejects NaN, ±inf, non-integers, oversized strings and unknown ids.
- **What a perfect exploiter can achieve:** Perfect on every take (×1.6 vs. a skilled human's ~×1.4 average) at the server-capped ~38 posts/min. They can also teleport into Viral zones, which they could have walked to anyway. That's the whole attack surface; currency injection isn't possible.
- Server → client uses RemoteEvents only. There's no `InvokeClient` anywhere, because an exploiter can stall it forever.
- Purchases: `ProcessReceipt` with a PurchaseId cache that's confirmed saved before returning `PurchaseGranted` (no double-grants, no lost purchases).

## 3. Data

### Player data (ProfileStore)
- `PlayerData_v1` store, key = UserId. **Session-locked**: only one server can write a profile. Joining a second server makes the first save and release; `OnSessionEnd` then kicks the stale copy. This is the core anti-dupe guarantee.
- Auto-save is ProfileStore's periodic save, plus a final save on leave or `BindToClose`, both handled by the library. `OnSave` stamps `LastOnline`.
- **Reconcile** fills new template keys. **Migrations** (`MIGRATIONS[n]` upgrades vN → vN+1) run after Reconcile and are append-only. **Sanitize** repairs NaN, negatives, out-of-range tiers and unknown niches, so a corrupted save self-heals instead of erroring.
- Studio uses `ProfileStore.Mock` unless `Config.Game.UseLiveDataInStudio = true`, so testing can never wipe live data.
- `profile:AddUserId` supports GDPR erasure (`PlayerStore:RemoveAsync(key)` when Roblox sends a Right to Erasure request).

**Restoring a player** (rollback after a bug or a reported loss). This is ProfileStore's documented `VersionQuery` + `SetAsync` flow. Run it from a server console or a temporary admin script **while the player is offline**:
```lua
local ProfileStore = require(game.ServerScriptService.ServerPackages.ProfileStore)
local store = ProfileStore.New("PlayerData_v1", {})
local before = DateTime.fromUniversalTime(2027, 1, 10) -- a UTC date before the loss
local version = store:VersionQuery("12345678", Enum.SortDirection.Descending, nil, before):NextAsync()
if version then
    print(version.Data)   -- inspect first (Studio with API access + expressive output)
    version:SetAsync()    -- makes this old version the latest one
end
```

### Content house data (Update 4 design, not in MVP)
House data is **shared across servers**, so it can't be session-locked to one server the way a player is:
1. **House document**: regular DataStore `Houses_v1/<houseId>`, written **only via `UpdateAsync`** (atomic read-modify-write). It holds members, roles, banner, bank balance, shared upgrade levels and the last 50 transaction ids.
2. **Deposits are two-phase and idempotent.** The player's profile (session-locked) deducts cash and records `PendingHouseTx = {id, houseId, amount}`. Then `UpdateAsync` on the house doc adds the amount only if `id` isn't in its tx list. Then the pending entry is cleared. On join, any leftover pending tx is retried. A crash at any step either retries or no-ops, so cash is never duplicated or lost.
3. **Battle points** use per-player, per-week contribution stored in the *player's* profile (authoritative). The house total is aggregated with `OrderedDataStore:IncrementAsync` on `HouseBattle_<week>`, which is atomic and commutative across servers.
4. **Live sync**: a `MessagingService` topic `house_<id>` broadcasts "doc changed" so other servers re-read it. Reads are cached for 60 s, with MemoryStore for invites and "looking for members" listings (short-lived data).
5. Names and banners pass `TextService:FilterStringAsync` and are stored raw, then filtered per viewer at display time.

## 4. Leaderboards
- `LB_Followers_AllTime_v1` (lifetime followers) and `LB_Followers_Week_v1_<weekId>` (UTC Monday-based week number). A fresh key each week means **no reset job is needed**.
- Writes go out once every 120 s per player, only when changed, plus on leave. Reads fetch the top 50 of each board every 120 s per server. Both stay far below per-server budgets (SetAsync 60+10·players/min, GetSortedAsync 5+2·players/min).
- Display names come in one batched `UserService:GetUserInfosByUserIdsAsync` call and are cached.
- Without DataStore access (Studio), boards fall back to players in this server.
- A physical board at spawn (SurfaceGui, Persistent model) plus a panel.

## 5. Client, mobile and performance
- **Mobile-first layout:** FILM at bottom-centre (away from the thumbstick at bottom-left and jump at bottom-right), menu as a 2×3 grid at left-centre, counters top-left, banners top-centre. Clusters are authored at 900×500 and scaled by a viewport `UIScale` (clamped 0.55–1.4), so tap targets stay ≥ 44 pt on phones. `ScreenInsets = CoreUISafeInsets` handles notches.
- **Controller:** R2/X/F/E = film, Y = shop, B = close panel. Panels set `GuiService.SelectedObject`, and all buttons are Selectable.
- **No-reading onboarding:** a bouncing 👆 pointer, a forced-Perfect first take, a glowing "!" badge on the next useful menu item, and emoji everywhere.
- **StreamingEnabled** (MinRadius 64, TargetRadius 384). The Viral beam and leaderboard use `ModelStreamingMode.Persistent` so they're always visible.
- **Low-end phone budget** (2 GB Android): client memory < 700 MB, < 80 k visible triangles, < 300 draw calls, 0 unanchored map parts, ≤ 1 server tick loop per system (0.25–1 s, never per-Heartbeat per-player work except the 0.1 s state flush), and UI rebuilt **never**: panels build once and update in place. State replication is ~1 KB per post per player.
- Sound IDs were left out deliberately. Add Creator Store audio you've licensed, rather than guessed asset IDs.

## 6. Analytics (Roblox AnalyticsService)

| Signal | Implementation | Dashboard |
|---|---|---|
| Onboarding funnel | 10 steps, once per player: Joined → First take → First post → 5 posts → First upgrade → Trend post → Niche unlock → Viral post → 1K followers → Daily claim | Creator Hub › Analytics › Funnels |
| Economy sources/sinks | Post income aggregated per minute; gear/niche sinks, daily/deal/offline/IAP sources logged per event with SKU | Economy dashboard |
| Retention cohorts | Native D1/D7/D30 | Retention |
| Monetization | Native + `Purchase_<key>` custom events | Monetization |
| Rebrands | `Rebrand` custom event (value = count) | Custom events |
| Solo vs. house (U4) | CustomField02 = `solo`/`house` on all events | Split any chart |

Every event carries `CustomField01 = ab:<arms>` so every chart can be split by experiment arm.

**Targets to unlock paid ads (A2):** D1 ≥ 25 %, D7 ≥ 7 %, avg session ≥ 12 min, funnel step 5 (first upgrade) ≥ 70 % of joiners, payer conversion ≥ 1.5 %.

### First 3 A/B experiments (already wired: `Analytics.Experiments`)
Assignment is a stable hash of the UserId per experiment, so arms are independent and sticky across servers. With a D1 baseline of ~20 %, detecting +2 pp at 80 % power and α = 0.05 needs **~6,300 new players per arm**. Run each for at least 7 days to cover weekday and weekend.

| # | Experiment | Arms | Primary metric | Guardrail | Hypothesis |
|---|---|---|---|---|---|
| 1 | `FirstTakeZone` | wide zone for 3 vs. 6 takes | funnel "5 posts" + D1 | Perfect-rate after tutorial | A longer easy ramp lifts early wins without boring kids. |
| 2 | `ShopNudge` | glow Shop button vs. auto-open once | "first upgrade within 2 min" + D1 | session length | Auto-open removes the one menu a 9-year-old must discover. |
| 3 | `TrendMultiplier` | ×2 vs. ×3 | trend-post share, niche switches/session, D1 | cash/min inflation, weekly-board share by arm | Bigger trend payoff teaches niche switching and pulls players to unlocks. *Run for one week max: it affects weekly leaderboard fairness.* |

Run icon and thumbnail tests through Creator Hub's thumbnail experiments, one variable at a time, **before** spending on ads.
