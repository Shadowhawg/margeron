# Tidewater: Build Spec for Claude Code

> **For Cam: how to use this file**
>
> 1. Install the latest **Roblox Studio**, **git**, and **Claude Code**.
> 2. Make an empty project folder. Save this file inside it as `docs/BUILD_SPEC.md`.
> 3. In Studio: create a new **Baseplate** place and **publish it privately** (File → Publish to Roblox). Consider publishing under a **Roblox Group** you own rather than your personal account; it makes revenue sharing, teammates, and transfer much easier later. Then go to **Game Settings → Security → Enable Studio Access to API Services**. Keep Studio open.
> 4. Connect Studio to Claude Code. In Studio, open **Assistant → … → Manage MCP Servers**, turn on **Enable Studio as MCP server**, then use **Quick connect → Claude Code**. If Quick connect isn't offered, run one of these in a terminal:
>    - macOS: `claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`
>    - Windows: `claude mcp add Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"` (if `%LOCALAPPDATA%` doesn't expand in your shell, use the full path, e.g. `C:\Users\<you>\AppData\Local\Roblox\mcp.bat`)
> 5. Open Claude Code in the project folder and send:
>    **"Read docs/BUILD_SPEC.md in full, then begin Phase 0. Follow the working rules exactly."**
> 6. At the end of every phase Claude Code will stop and give you a short list of things only you can do (save/publish in Studio, create products in the Creator Dashboard, paste IDs). Do those, then say "continue to Phase N."

---

## Part 0: Your role and working rules (Claude Code, read this first)

You are the sole engineer building **Tidewater**, a Roblox experience. The owner is **Cam**. He reviews your work and performs the Studio and Creator Dashboard actions you cannot. He is not a professional Roblox developer, so explain anything he must do in plain, numbered steps.

The goal of these rules is to **minimize trial and error**. Follow them strictly.

1. **The filesystem is the source of truth for code.** All Luau lives in `src/` and syncs into Studio with Rojo. **Never** edit Rojo-managed scripts with the Studio MCP script tools (`multi_edit`, etc.); Rojo will overwrite or diverge from them. Use the Studio MCP for inspection, `execute_luau`, playtesting, console output, screenshots, input simulation, and world building (see §2.8).

2. **One phase at a time.** At the **start** of each phase, post a short plan: files you will create or change, key decisions, risks, and how you'll verify. Then wait for Cam's OK. At the **end** of each phase:
   - run all quality gates,
   - run the MCP playtest smoke checks,
   - update `docs/PROGRESS.md`,
   - commit,
   - report results in under 15 lines,
   - list Cam's manual to-dos,
   - **stop**.

3. **Look it up; don't guess.** Roblox APIs change and many have been deprecated. Before using any API whose exact signature, yielding behavior, limits, or current status you aren't certain of, check the official docs. Use the Studio MCP `http_get` tool (create.roblox.com docs) or web search. Prefer current APIs: `task.wait`/`task.spawn`/`task.defer` (never `wait`/`spawn`/`delay`), `GetProductInfoAsync`, `UserInputService`/`ContextActionService` (never `Mouse`), `TextChatService`.

4. **Pure core, thin shell.** Game rules live in pure Luau modules under `src/shared/Logic/`. They use no Roblox services, no `game`, no `Instance`, no `Random`, and no `os.time`. Randomness and time are **injected** as functions (`rng: () -> number`, `now: () -> number`). This lets you unit-test them headlessly with Lune in seconds. Server services are thin adapters that call Logic modules and touch Roblox APIs.

5. **Verify with the cheapest sufficient check**, in this order:
   1. unit test
   2. `lune run check` (format, lint, types, tests, build)
   3. Studio MCP playtest (`start_stop_play`, `execute_luau` on the Server/Client data model, `get_console_output`, `screen_capture`, `character_navigation`, `user_mouse_input`, `user_keyboard_input`)

   Never report a feature as done without one of these passing.

6. **Ask before you:**
   - publish anything,
   - change the saved data schema after Phase 1,
   - touch non-`_DEV` DataStores,
   - add any package beyond the approved list (§2.3),
   - change anything about monetization or compliance,
   - delete files.

7. **When stuck:** after **two** failed attempts at the same problem, stop. Write down your hypotheses and what you tried, and ask. Do not loop.

8. **Keep `docs/PROGRESS.md` current.** It holds:
   - phase status,
   - decisions made, with one-line reasons,
   - known issues,
   - an open **"Cam to-do"** list.

9. **Small, frequent commits** with clear messages. Never commit secrets or API keys.

10. **Phase 0 bootstraps your memory.** Create `CLAUDE.md` at the repo root containing Part 0 of this spec (these rules), the repo layout, and the commands. It must also say: *"At the start of every session, read `docs/PROGRESS.md` and the section of `docs/BUILD_SPEC.md` for the current phase."*

---

## Part 1: Game design

### 1.1 Pitch

*Tidewater* is a cozy seaside town where every player is a shopkeeper. You fish, garden, and forage. Your catches roll rare **variants** (Shiny, Golden, Rainbow, event-only). You sell to the town or to other players at your own market stall. The whole server works together on **Town Projects** that unlock server-wide rewards. Scheduled **live events** bring rare spawns and limited items.

The community is the economy: an item's value comes from what other players want.

**Design pillars, used to settle any tradeoff:**
1. **Cozy and readable in 10 seconds.** No combat. A new player understands the loop without reading.
2. **Every session has something to show off.** Rare variants, cosmetics, stall displays.
3. **Other players make it better.** Trading, stalls, and shared projects are core, not bolted on.
4. **Fully playable with chat off.** Many younger accounts have chat disabled by default, so every social mechanic must work through structured UI, not typed chat.
5. **Monetize status and convenience, never power over others.**

**Theme isolation:** every player-facing name, item, and string lives in `src/shared/Config/` (or localization tables). This keeps a future re-skin to another theme cheap.

### 1.2 World: Tidewater Cove (single place, ~10 players per server)

| Area | Contents |
|---|---|
| **Town Square** (center) | 12 market stall spots in a ring, the Town Project board, a fountain, the NPC shop (Wren's General Store), and the Robux store kiosk |
| **Docks** | 3 fishing zones gated by rod tier: **Pier** (starter), **Reef** (tier 2), **Deep Water** (tier 3; reached by a short boat ride or dock) |
| **Beach** | Forage nodes: shells, driftwood, sea glass |
| **Meadow** | Forage nodes: berries, wildflowers |
| **Plot Ring** | 10 garden plots around the town edge; each player is assigned one on join |

- **Day/night cycle:** 20 real minutes. Night changes ambient light, music, and some spawn tables.
- **Visual style:** bright, low-poly, pastel. Use one palette defined in `Config/Palette.luau`.

### 1.3 Activities (MVP scope)

**Fishing (primary activity)**

1. **Cast:** hold to set distance, release.
2. **Wait:** the **server** picks the bite time (3–12 s, scaled by rod tier and boosts). It also picks the fish species, size, and variant **at bite time** from the zone's table.
3. **Reel:** a short client-side minigame. Keep the fish inside a moving zone for ~3 s.
4. **Result:** the client reports success or failure plus elapsed time. The server rejects results that arrive faster than physically plausible or that don't match an open bite.

Fish have a **size in kg**, rolled from a per-species range, which scales their value.

**Gardening**

- Plots start with 6 tiles and can be expanded to 24 with Shells.
- Seeds are bought from Wren. Crops grow in **real time, including while offline** (`plantedAt + growSeconds`).
- Harvest yields a unique crop item with size and variant.
- **Weather mutations:** a crop that was growing during a weather or event window can mutate. Compute this **at harvest time** from the deterministic event schedule and the crop's growth window, as a pure function. No server needs to have been running during the event.

**Foraging**

- Nodes are tagged with CollectionService.
- Each player has their **own** respawn timers per node. Nobody can steal "your" node, which prevents griefing.
- Foraging yields stackable materials (shells, driftwood, sea glass, berries, wildflowers).

**Crafting (Phase 2, only if time allows)**

- Simple recipes turn materials into decor and cosmetics. Decor is placed on your plot or stall.

### 1.4 Items and variants

- **Stack items:** materials and seeds. Stored as counts.
- **Unique items:** every caught fish or harvested crop. Each has:
  - a UID (`HttpService:GenerateGUID(false)`)
  - `itemId`, `variant`, `sizeKg`, `obtainedAt`
  - `origin`: `"gameplay" | "event" | "trade" | "paid"`
  - `tradeable: boolean`
  - `paidLuck: boolean` (see §1.9, rule 3)
- **MVP content:** ~15 fish, ~12 crops, ~8 materials, all defined in `Config/Items.luau`. Each item has:
  - rarity (Common, Uncommon, Rare, Epic, Legendary)
  - base sell price
  - size range
  - zone or season availability
  - display info

**Variants** (all values in `Config/Variants.luau` and easy to tune):

| Variant | Base chance | Value multiplier | Notes |
|---|---|---|---|
| Shiny | 1/40 | ×2 | |
| Golden | 1/400 | ×10 | |
| Rainbow | 1/4000 | ×50 | |
| Moonlit | 1/20 during Night Tide only | ×5 | Event-only |
| Stormtouched | 1/25 during storms only | ×4 | Event-only |

- **Luck modifiers** multiply variant chances. The combined multiplier is capped (default ×4) so stacking boosts can't break the economy.
- **Beginner's luck:** the very first catch of a player's life is a guaranteed Shiny. It's a delight moment and the onboarding hook.
- **Collection Log** ("Tide Journal"): tracks every item and variant ever obtained, plus the player's best size per item. Completing pages grants cosmetic rewards.

### 1.5 Economy

- **Soft currency: Shells.** Earned only through gameplay: selling to Wren, selling to players, quests, and streaks.
- **Shells are never sold for Robux.** This is a deliberate compliance decision (see §1.9). Do not add a Robux → Shells product.
- **Sources:**
  - NPC sell prices (fixed base × variant × size factor)
  - player-to-player stall sales
  - daily quests
  - login streak
  - Town Project rewards
- **Sinks:**
  - tool upgrades (rod, hoe, backpack tiers)
  - plot expansion
  - seeds
  - Shell-priced cosmetics and decor
  - **5% harbor tax** on stall sales
  - Town Project contributions
- **Caps:** backpack 30 slots, upgradable to 300. Storage chest max 500 uniques. This keeps profile size bounded.
- **Telemetry:** the economy must be logged (see §2.11) so Cam can watch sources versus sinks for inflation.

### 1.6 Social systems

**Direct trading (same server only)**

Trading is implemented as a pure state machine in `Logic/Trade.luau`:

1. **Request:** the target accepts within 15 s.
2. **Negotiating:**
   - Each side offers up to 9 items plus Shells.
   - **Any** change clears both "Ready" flags and imposes a 3 s edit cooldown before Ready can be pressed again.
3. **Both ready → Countdown:** 5 s. Any change returns the trade to Negotiating.
4. **Commit (server):**
   - re-validate ownership, `tradeable`, policy eligibility, and capacity for both sides
   - swap atomically in memory on both loaded profiles
   - append to both players' trade logs (ring buffer of the last 50)
   - request a save
5. **Cancellation:** leaving the server, moving more than 40 studs apart, or either side pressing Cancel ends the trade.
6. **Scam reduction:** the trade UI shows each side's **estimated value**, based on NPC sell value, with a warning if the trade is very lopsided.
7. **Untradeable items:** `origin = "paid"` items are untradeable at launch. Starter tools are untradeable.

**Market stalls (in-server)**

- A player claims one free stall spot in the Town Square. Each player can hold one stall per server.
- The owner lists up to 6 items (8 with VIP) at Shell prices.
- Listed items are **reserved**: they stay in the owner's inventory but are locked from other uses.
- Stall naming: choose from preset name parts, **or** enter custom text that is filtered with `TextService` before anyone else sees it.
- Buyers browse via ProximityPrompt. The purchase runs entirely on the server:
  - re-check that the listing is valid and the buyer can afford it
  - transfer the item
  - apply the 5% tax
  - notify both players
- The stall clears when the owner leaves.
- **Offline selling is out of scope until Phase 7** (§3).

**Town Projects (server-wide)**

- Each server has one active project, rotating from `Config/Projects.luau`. Example: "Repair the Lighthouse," which needs 300 fish, 200 crops, and 10,000 Shells in total.
- Players contribute **only gameplay items and Shells**, never anything purchased.
- On completion:
  - a 30-minute server-wide luck buff
  - all contributors get a cosmetic plus a badge
  - the next project starts
- The board UI shows progress and the top contributors.

**Light social glue**

- Emote wheel.
- Quick-chat preset phrases, so players can communicate with chat off.
- **Friend bonus:** +10% Shells while a Roblox friend is in the same server. Cache `IsFriendsWith` results.
- Invite prompt via `SocialService:PromptGameInvite`.
- One-time Roblox Group join reward (a free cosmetic), checked with `IsInGroup`.
- A favorite prompt shown after a positive moment, such as the first Golden catch. Do this at most once per player.

### 1.7 Retention loops

- **Onboarding** (log every step as a funnel; see §2.11). The NPC **Wren** guides, with an arrow beacon and no walls of text:
  1. walk to the pier
  2. catch the first fish (guaranteed Shiny)
  3. sell it to Wren
  4. buy seeds
  5. plant on your plot
  6. see the grow timer ("come back in 10 minutes!")
  7. forage one item
  8. open the Tide Journal

  Target: under 3 minutes to finish.
- **Daily:** 3 rotating daily quests and a 7-day login streak calendar.
- **Offline progress:** crops keep growing, which gives players a reason to return.
- **Weekly:** a global "Top Anglers" leaderboard. Use an OrderedDataStore keyed by ISO week number and track heaviest fish per week, stored as integer grams because OrderedDataStore holds integers.

### 1.8 Live events

- **Server weather:** every 20–40 minutes per server (random, server-local), a weather event runs for 5 minutes. Examples: Rain gives crops ×2 growth plus mutations; Storm enables Stormtouched variants; Fog gives rare fish ×2.
- **Scheduled global events** are defined in `Config/Events.luau` as a deterministic **UTC** schedule, so every server agrees without communicating.
  - Example: **Night Tide**, Saturdays 23:00–23:30 UTC (7 pm US Eastern in summer, 6 pm in winter; note this in config).
  - During Night Tide, Moonlit variants appear and event-only items spawn.
- **Admin live events:**
  - Cam can trigger a global event from an admin panel. It broadcasts to all servers via MessagingService.
  - Only allowlisted UserIds in `Config/Admins.luau` can do this.
  - Every admin action is logged.
- **Seasonal limited items:** cosmetics and items with an `availableUntil` timestamp. Once expired, they never return. This makes trading meaningful.
- **LiveConfig service:**
  - Reads a `LiveConfig` DataStore key at server start and every 5 minutes.
  - Overrides only **whitelisted, clamped** keys: event toggles, multipliers within safe ranges, and the active project rotation.
  - The admin panel can write to it.
  - Before building this, check the docs for a built-in Roblox experience-config feature. If a suitable one exists, propose using it instead.

### 1.9 Monetization and compliance

**Principles**
- Sell status, convenience, and time-limited boosts.
- Never sell Shells, power over other players, or anything that blocks free players from the core loop.

**Products** (Cam creates these in the Creator Dashboard; IDs go in `Config/Products.luau`, with `0` as a placeholder until then):

| Type | Product | Effect | Suggested price (R$) |
|---|---|---|---|
| Pass | VIP | VIP nametag, VIP dock area, +2 stall slots, +10% sell price to Wren | 299 |
| Pass | Big Backpack | Backpack ×2 capacity | 149 |
| Pass | Green Thumb | Auto-harvest ready crops while online; +1 garden row | 199 |
| Pass | Swift Reel | 25% shorter bite waits | 249 |
| Dev product | 2× Shells (30 min) | Deterministic multiplier on NPC sales | 79 |
| Dev product | Luck Charm (30 min) | ×2 variant chances for the buyer. **This is a paid random item; see the compliance rules below** | 49 |
| Dev product | Server Luck (15 min) | ×2 variant chances for everyone in the server, with a server-wide shout-out naming the buyer. **Also a paid random item** | 199 |
| Dev product | Cosmetic bundles | Outfits, stall skins, boat skins | 99–399 |
| Dev product | Gift [pass] | Gift any pass to another player in the server; stored as an entitlement | Same as the pass |
| Private servers | — | Cam enables these in the dashboard | ~100/month |

- **Premium perks:** if `MembershipType == Premium`, grant +10% Shells and a badge icon. Show a "Premium perks" panel with `PromptPremiumPurchase`. Roblox pays creators based on Premium subscribers' engagement time, so long cozy sessions earn money passively.
- **Optional, Phase 5+:** a monthly "Harbor Club" experience subscription (daily Shell stipend plus a monthly exclusive cosmetic). Check the current subscriptions API docs before proposing it.

**Hard compliance rules.** Read the official "Paid random items policy guidelines" and the `PolicyService` docs before implementing any of these.

1. **Odds disclosure.** Luck Charm and Server Luck are *probability modifiers*, which Roblox treats as paid random items.
   - Before purchase, show all possible outcomes and their **numerical odds**, both with and without the boost.
   - While a boost is active, the always-available **Odds** panel must show the **current, boosted** odds.
   - Compute these odds in a pure, unit-tested `Logic/Odds.luau` from the same config the server rolls from. The disclosed odds must be the real odds.
2. **Regional restriction.**
   - At join, call `PolicyService:GetPolicyInfoForPlayerAsync` with retry.
   - If `ArePaidRandomItemsRestricted` is true, **hide** paid luck products for that player, block any purchase prompt server-side, and show "unavailable in your region" when relevant.
   - If the policy call fails, treat the player as **restricted** (fail closed).
   - For server-wide paid luck effects, check the current policy text. If it's unclear whether restricted players may receive the effect, exclude them.
3. **Paid item trading.**
   - All `origin = "paid"` items are untradeable at launch. If this changes later, gate it on `IsPaidItemTradingAllowed` for **both** parties.
   - Any unique item obtained while a **paid** luck effect (Luck Charm or Server Luck) was active on the player gets `paidLuck = true`. It may be traded or listed on a stall only if `IsPaidItemTradingAllowed` is true for **both** parties; otherwise it stays sellable to Wren only. Gameplay-earned luck (Town Project buff) does **not** set this flag.
   - Enforce this inside `Logic/Trade.luau` and `Logic/Stall.luau` so it is unit-tested.
4. **No Robux → soft currency.** Robux never buys Shells. This keeps everything bought with Shells outside the paid-random rules.
5. **Dynamic prices.** Never hard-code Robux prices in the UI. Always fetch them via `MarketplaceService:GetProductInfoAsync` (or `GetDeveloperProductsAsync` for the full list) and cache them briefly. This is required for Roblox's managed/regional pricing and price-optimization tests.
6. **Text filtering.** All player-entered text that other players see (stall names, custom signs) goes through `TextService:FilterStringAsync` and the appropriate broadcast method. If filtering fails, show nothing.
7. **Maturity target:** Minimal or Mild. No free-form drawing tools. No unfiltered user text.

---

## Part 2: Technical architecture

### 2.1 Toolchain (pinned via Rokit)

- **Rokit** is the toolchain manager. Use it, not Foreman or Aftman. Pin these in `rokit.toml`:
  - **Rojo** (7.6.x or newer stable)
  - **Wally** (0.3.x)
  - **StyLua**
  - **selene**
  - **luau-lsp**
  - **Lune**
- Record exact versions in `docs/PROGRESS.md`.
- Install the Rojo Studio plugin with `rojo plugin install`. Cam clicks **Connect** in the Rojo plugin.
- Run `rojo serve` as a background process during development.
- Generate `sourcemap.json` with `rojo sourcemap` for luau-lsp. Use Roblox type definitions for analysis.

### 2.2 Repository layout

```
default.project.json   rokit.toml   wally.toml   selene.toml   stylua.toml   .luaurc
CLAUDE.md
docs/  BUILD_SPEC.md  PROGRESS.md  ECONOMY.md (tuning notes)  TESTING.md (manual multi-client checklist)
src/
  shared/                       -> ReplicatedStorage.Shared
    Config/                     Items, Variants, Zones, Crops, Economy, Products, Events, Projects, Quests, Palette, Admins, Flags
    Logic/                      PURE modules: Inventory, Rolls, Pricing, Trade, Stall, Garden, EventSchedule, Odds, Quests, Streak, Projects, Migrations, Validate
    Net/                        Remote definitions + arg validators
    Types.luau
  server/                       -> ServerScriptService.Server
    init.server.luau            boots services in a fixed order
    Services/                   DataService, PlayerStateService, InventoryService, FishingService, GardenService, ForageService,
                                ShopService, TradeService, StallService, ProjectService, QuestService, PurchaseService,
                                PolicyService (wrapper; name it PolicyGate), EventService, LiveConfigService, AdminService,
                                LeaderboardService, Telemetry
    Vendor/ProfileStore.luau    vendored from MadStudio's official repo; record version/commit
  client/                       -> StarterPlayer.StarterPlayerScripts.Client
    init.client.luau            boots controllers
    Controllers/                Input, Fishing, Garden, Forage, Camera, Audio, StateStore, Tutorial
    UI/                         React components (HUD, Backpack, Shop, Journal, Trade, Stall, ProjectBoard, Store, Odds, Settings, Admin)
tests/                          *.spec.luau for every Logic module
lune/                           check.luau, test.luau, analyze.luau, minimal test runner (describe/it/expect)
tools/world/                    world-builder scripts run via MCP execute_luau (see §2.8)
tools/smoke/                    in-Studio smoke checks run via MCP during playtests
```

**Rojo** manages only the code trees above, plus `Packages`. **Do not** put `Workspace` in the Rojo project; the world is built as described in §2.8.

### 2.3 Approved packages (Wally); ask before adding others

- `jsdotlua/react` and `jsdotlua/react-roblox` for UI
- A small Signal implementation and a cleanup helper (Trove or Janitor), or write ~40-line versions in `shared/Util/`
- **ProfileStore** (vendored, not via Wally)
- **No frameworks** (no Knit). Use plain services and controllers with explicit `init()`/`start()`.

**Testing note:** Jest-Lua runs only inside Roblox, so headless tests use a minimal runner you write for Lune (~100 lines). Keep it boring.

### 2.4 Networking

- **Definitions:** one `Net` module declares every remote with a name and an argument validator. At boot, the server creates RemoteEvents/RemoteFunctions under `ReplicatedStorage.Remotes`; the client waits for them.
- **Server handler pipeline**, for every handler:
  1. rate limit (per player, per remote token bucket)
  2. validate types with `typeof`
  3. sanitize numbers:
     - reject NaN (`x ~= x`) and infinities
     - clamp to sane ranges
     - require integers where expected
  4. verify ownership and proximity (distance check against the player's character)
  5. call the service

  Invalid input is dropped and counted; it never throws.
- **Never `InvokeClient`.** Use client → server RemoteFunctions only for request/response UI (with timeouts).
- Use `UnreliableRemoteEvent` for cosmetic, high-frequency effects.
- **Replication:** the server pushes small **state patches** (Shells changed, item added or removed, boost started) through `PlayerStateService`. The client keeps a store that the React UI subscribes to. Send a full snapshot only on join or on resync.

### 2.5 Data

- **ProfileStore** gives session locking, which is essential to prevent item duplication in a trading game.
  - Store name: `PlayerData_v1`.
  - In Studio, append `_DEV` (via `RunService:IsStudio()`) so testing never touches production data.
- **Schema** (`Types.luau`):
  - `schemaVersion`
  - `shells`
  - `stacks: {[itemId]: count}`
  - `uniques: {[uid]: UniqueItem}`
  - `tools`
  - `garden`
  - `collection`
  - `quests`
  - `streak`
  - `entitlements`
  - `purchases: {[purchaseId]: timestamp}` (keep the last 200)
  - `boosts: {{kind, multiplier, endsAt}}`
  - `cosmetics`
  - `equipped`
  - `stats`
  - `tutorialStep`
  - `tradeLog` (ring buffer of 50)
  - `reservedUids` (for stall listings)
- **Migrations:** `Logic/Migrations.luau`. Each step is a pure `vN → vN+1` function, unit-tested.
- **Invariants:** a pure `Validate.profile(data)` check, run after every trade and stall sale **in Studio**. It checks:
  - no negative values
  - no UID in two places
  - reserved UIDs exist
  - capacity is respected
- **Receipts (`PurchaseService`):**
  - Exactly **one** `ProcessReceipt` callback.
  - If the buyer's profile isn't loaded → `NotProcessedYet`.
  - If `purchases[PurchaseId]` already exists → `PurchaseGranted`.
  - Otherwise: grant via a handler table keyed by product ID, record the purchase ID, and **wait for the profile to save successfully** before returning `PurchaseGranted`. Follow ProfileStore's documented guidance for receipts. If the session ends first → `NotProcessedYet`.
  - Gamepasses: check on join with `UserOwnsGamePassAsync` (cached) **and** handle `PromptGamePassPurchaseFinished`. Merge with gifted entitlements.
- **Offline messaging** (Phase 7): use `ProfileStore:MessageAsync` to deliver items or Shells to players who aren't online.

### 2.6 Testing strategy

- **Unit tests (Lune):** every Logic module. Cover normal, edge, and adversarial inputs: wrong types, NaN, huge numbers, unowned UIDs, double-commit, and cancel mid-countdown.
  - Rolls and Odds tests run **100,000 seeded trials** and assert that observed rates match the disclosed odds within tolerance.
- **`lune run check`** runs: StyLua (check mode) → selene → luau-lsp analyze (strict) → tests → `rojo build` to a temp `.rbxl`. It must pass before any commit.
- **Studio smoke checks (MCP):** for each phase, write scripts in `tools/smoke/`. Start a playtest, run them with `execute_luau` on the Server data model, and read `get_console_output`. Example checks:
  - give the test player items, run a sale, assert Shells changed correctly
  - drive the character with `character_navigation` to the pier and simulate a cast via input tools
  - take a `screen_capture` of the HUD to verify the UI renders
- **Multi-client** features (trading, stalls, server luck) can't be fully driven from one MCP session. For each such phase:
  - test the service layer with fake profiles inside a smoke script, **and**
  - write a step-by-step manual checklist in `docs/TESTING.md` for Cam to run with Studio's **Test → Clients and Servers** (2 players).

### 2.7 Code standards

- `--!strict` at the top of every module. Explicit types on public functions.
- `.luau` extensions. One responsibility per module.
- No global state outside services.
- All tunable numbers live in `Config/`. No magic numbers in services.
- Strings shown to players live in `Config/Strings.luau` with whole sentences, not concatenated fragments, so Roblox auto-translation works.
- Disconnect connections and destroy instances via the cleanup helper.
- Handle `PlayerRemoving` everywhere state is keyed by player.

### 2.8 World building

- World geometry is built by **idempotent builder scripts** in `tools/world/`.
  - Run them through MCP `execute_luau` on the **Edit** data model.
  - Each builder deletes and recreates its own folder under `Workspace.Generated.<Area>`.
  - This makes the world reproducible and reviewable in git.
- Gameplay anchors are tagged parts plus attributes that services discover with CollectionService:
  - plot origins
  - stall spots
  - fishing zones
  - forage nodes
  - NPC spots
  - boat dock
- **Never hard-code positions in services.**
- **Assets:**
  - Prefer primitives and the MCP `generate_procedural_model`/`generate_material` tools.
  - If you insert Creator Store assets, **strip every Script, LocalScript, and ModuleScript** from them immediately. Free models are a common backdoor vector. List every inserted asset ID in `docs/PROGRESS.md`.
- **You cannot save the place file.** After any world change, remind Cam to save (File → Save to Roblox). Ask Cam to hand-polish visuals only after the gameplay layout is final.
- **Lighting and atmosphere:** set up via a builder script so the setup is reproducible.

### 2.9 UI and UX

- **Mobile-first;** most players are on phones.
  - Use Scale-based layout.
  - Use a `UIScale` controller driven by viewport size.
  - Respect safe insets (`ScreenGui.ScreenInsets = DeviceSafeInsets`).
  - Touch targets must be at least ~44 px at phone scale.
- Support basic gamepad navigation (console players exist).
- **Screens:**
  - HUD (Shells, backpack, quests, event timer, boost timers)
  - Backpack
  - Wren's Shop
  - Tide Journal
  - Trade
  - Stall manager / stall browse
  - Project board
  - Robux Store
  - Odds panel
  - Settings
  - Admin (admins only)
- **Verify** each screen with `screen_capture` at phone and desktop sizes. Use Studio's device emulator; the MCP `skill` tool has a device-simulation skill.
- **Juice matters:**
  - catch splash
  - variant reveal sparkle with distinct sounds per rarity
  - server-wide toast for Golden and Rainbow catches ("Cam caught a Rainbow Tuna!"), which drives social proof

### 2.10 Performance

- `StreamingEnabled = true`. Client code must tolerate parts that haven't streamed in yet: use `WaitForChild` with timeouts, CollectionService added signals, and no assumptions.
- **No per-item server loops on Heartbeat.** Garden growth is computed from timestamps; visuals update only on the client for plots in range.
- **Budget:** 60 fps on a mid-range phone. Watch part count and memory with Studio's MicroProfiler and Developer Console before each phase ends.

### 2.11 Telemetry

Wrap `AnalyticsService` in `Telemetry`. Verify the current method names in the docs (onboarding funnel, economy, progression, and custom events). Log:

- every onboarding step
- every Shell source and sink with amounts
- every Robux purchase
- tool upgrades
- trades and stall sales (counts and value bands only)
- event participation

Cam's key numbers: **D1/D7 retention, average session length, onboarding completion rate, payer conversion, and source/sink ratio.**

### 2.12 Security checklist (review at the end of every phase)

- The client never decides outcomes, prices, ownership, timers, or odds.
- Every remote is rate-limited and validated, including against NaN and infinity.
- Distance checks apply to all world interactions.
- Trades and stall sales re-validate everything at commit time and are atomic.
- Paid luck products are blocked server-side for restricted players, not just hidden in the UI.
- Admin remotes check the allowlist on the **server**.
- No `loadstring`. No HTTP calls to third parties. No inserted scripts from assets.

---

## Part 3: Phases and acceptance criteria

Each phase must end **playable**. Don't start the next phase until Cam says so.

### Phase 0: Environment and scaffolding
- Install the toolchain via Rokit. Create the repo layout, `CLAUDE.md`, `docs/PROGRESS.md`, and the Lune test runner and check scripts. Initialize git.
- Verify the Studio MCP connection with `list_roblox_studios` and `get_studio_state`. If it's missing, give Cam exact fix steps and stop.
- **Accept when:**
  - `lune run check` passes with one sample test
  - `rojo serve` syncs a server script that prints `Tidewater booted`
  - an MCP playtest shows that line in `get_console_output`

### Phase 1: Vertical slice: fish → sell → upgrade
- Island blockout via world builders: Pier, Town Square, Wren's shop, and spawn.
- DataService (ProfileStore, `_DEV`, schema v1, migrations scaffold), PlayerStateService, and InventoryService.
- Fishing at the Pier: 5 fish, all variants, sizes, minigame, and server validation. Beginner's-luck Shiny.
- Selling to Wren and buying rod tier 2 (faster bites, plus a higher size range at the Pier until Reef exists). HUD (Shells), Backpack UI, catch and variant-reveal juice.
- **Accept when:**
  - a full loop works in a playtest
  - data persists across Studio sessions (stop → play)
  - Rolls tests prove the variant odds
  - the smoke script confirms that selling credits the exact expected Shells
  - the HUD and Backpack screenshots look right at phone size

### Phase 2: Garden, forage, content, and onboarding
- Plot assignment and rendering. Planting, offline growth, harvest, and expansion.
- Foraging nodes with per-player timers.
- Reef and Deep Water zones. Full MVP item set. Tide Journal.
- Daily quests and login streak. Scripted onboarding with funnel telemetry. Day/night cycle.
- Optional crafting if on schedule.
- **Accept when:**
  - a new profile completes onboarding in under 3 minutes in a playtest
  - offline growth math is unit-tested across event windows
  - the Journal updates correctly

### Phase 3: Social
- TradeService, with the pure Trade state machine fully tested.
- StallService with reservations and tax.
- Town Projects with server buff, badge, and cosmetic.
- Emote wheel and quick-chat presets. Friend bonus, invite prompt, and Group reward.
- Golden/Rainbow server toasts. Weekly Top Anglers leaderboard.
- **Accept when:**
  - all Trade and Stall adversarial tests pass (double-commit, change during countdown, leave mid-trade, unowned UID, reserved item)
  - the Validate invariants hold after scripted trade and stall runs
  - `docs/TESTING.md` contains a 2-player checklist for Cam

### Phase 4: Monetization and compliance
- `Config/Products.luau` with placeholders. PurchaseService (idempotent receipts). Passes, gifting, and entitlements.
- Robux Store UI with **dynamic prices**.
- PolicyGate (fail closed). Odds panel and pre-purchase disclosure. Boosts with timers. Premium perks.
- **Before writing code,** list for Cam every pass and product to create in the Creator Dashboard (name, description, suggested price, and icon idea). Wait for the IDs.
- **Accept when:**
  - receipt handling is idempotent under simulated retries
  - a restricted player (forced via a debug flag) can't see or buy luck products, and is blocked server-side
  - odds shown in the UI match `Logic/Odds.luau` exactly
  - no hard-coded prices appear anywhere (grep proves it)

### Phase 5: Live ops
- EventService: server weather plus the deterministic UTC schedule.
- Event-only variants and items. Weather crop mutations.
- Seasonal limited items. AdminService and panel. Global events via MessagingService. LiveConfigService.
- **Accept when:**
  - the event schedule is unit-tested across week and year boundaries
  - an admin-triggered global event fires in a playtest
  - LiveConfig values are clamped

### Phase 6: Polish and launch readiness
- Mobile UX pass. Performance pass. Full security review against §2.12. Audio and music. Settings (music/SFX volume).
- Badges for milestones. Lighting polish.
- **Launch checklist for Cam:**
  - complete the Maturity & Compliance questionnaire
  - icon, thumbnails, and description
  - private server price
  - Group setup
  - first sponsored-ad budget
  - creator outreach list
  - which metrics to watch in the first 72 hours
- **Accept when:** a full playtest from a fresh `_DEV` profile runs onboarding → trade → stall → purchase (in Studio test mode) → event with zero errors in the console.

### Phase 7: Post-launch (only after launch data exists)
- **Harbor Exchange:** a global offline market. Listings go in a MemoryStore sorted map, with items escrowed out of the seller's profile. Deliver proceeds via `ProfileStore:MessageAsync`. Write a design doc and get approval first; this is the riskiest system for dupes.
- Cross-server festival goals (MemoryStore counters).
- Weekly update cadence: new fish and crops, rotating events, limited cosmetics.

---

## Part 4: Known pitfalls (avoid all of these)

1. **Editing code in Studio instead of `src/`.** Rojo will overwrite it.
2. **DataStore calls failing in Studio** because API access is off or the place isn't published. Check this first when data "doesn't save."
3. **Client code requiring server-only modules,** or anything under `ServerScriptService`/`ServerStorage` from the client.
4. **`ProcessReceipt` returning `PurchaseGranted` before the data is saved,** or more than one `ProcessReceipt` assigned.
5. **Hard-coded Robux prices** in the UI.
6. **Trusting client numbers** (NaN, negative, or huge values) or client-chosen item IDs or UIDs.
7. **Deprecated APIs:** `wait`, `spawn`, `delay`, `Mouse`, legacy chat.
8. **Assuming parts exist** with StreamingEnabled on.
9. **Offset-based UI** that breaks on phones. Forgetting safe-area insets.
10. **Free-model scripts** (backdoors).
11. **Time zones:** schedule in UTC; compute with `os.time()`/`DateTime` in UTC only.
12. **Too-large remote payloads.** Send patches, not whole inventories, on every change.
13. **Forgetting `PlayerRemoving` cleanup.** This leaks memory and leaves ghost trades and stalls.
14. **Unbounded profile growth.** Enforce caps and trim logs.
15. **Building ahead of the current phase.** Don't.

---

## Part 5: What Cam must do (keep this list updated in PROGRESS.md)

- Keep Studio open with the MCP server enabled and Rojo connected during sessions.
- Save and publish the place when asked. Claude Code can't.
- Create passes, developer products, and badges in the Creator Dashboard, and paste the IDs.
- Put your Roblox UserId in `Config/Admins.luau`.
- Run the 2-player manual checklists in `docs/TESTING.md`.
- Complete the Maturity & Compliance questionnaire and the store page assets before going public.
