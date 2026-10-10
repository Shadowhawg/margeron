# Go Viral! 📱 (Roblox influencer simulator)

Start as a nobody filming on a cracked phone and grow into a mega-creator. Mobile-first, ages 9–15, solo-dev scoped.

| Doc | What's in it |
|---|---|
| [`docs/GDD.md`](docs/GDD.md) | Phases 1–3: hook, comparables, first 60 s, icons/thumbnails, loops, progression numbers, content houses, retention calendar, monetization |
| [`docs/TECH.md`](docs/TECH.md) | Phase 4: architecture, security model, data safety, leaderboards, performance budgets, analytics and A/B plan |
| [`docs/MVP_BUILD.md`](docs/MVP_BUILD.md) | Build order, module by module, with exact Studio tests for each |
| [`tools/sim_economy.py`](tools/sim_economy.py) | Economy pacing simulator. Re-run after changing any number |

## Quick start
```bash
rokit install          # rojo, wally, luau-lsp, selene, stylua (pinned in rokit.toml)
wally install          # -> ServerPackages/ProfileStore
rojo serve             # open an empty Baseplate in Studio, Rojo plugin -> Connect, press Play
```
Checks:
```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --defs=@roblox=globalTypes.d.luau --ignore="ServerPackages/**" src
selene src && stylua --check src
lune run tests/shared  # runtime tests for the shared economy/format/trend modules
python3 tools/sim_economy.py
```

## File tree
```
.
├── default.project.json          Rojo tree (StreamingEnabled on)
├── wally.toml                    ProfileStore (server realm)
├── rokit.toml  selene.toml  stylua.toml  .luaurc (strict)
├── docs/  GDD.md  TECH.md  MVP_BUILD.md
├── tools/sim_economy.py          pacing simulator (mirrors Config/*)
├── tests/  harness.luau  shared.luau        (Lune)
└── src/
    ├── shared/                   -> ReplicatedStorage.Shared
    │   ├── Config/
    │   │   ├── Game.luau         timings, multipliers, social, offline, rebrand, titles
    │   │   ├── Gear.luau         Camera / Lighting / Set tiers
    │   │   ├── Niches.luau       7 niches, unlock order
    │   │   ├── Products.luau     passes + dev products (put your ids here)
    │   │   └── Rewards.luau      daily streak + Brand Deal templates
    │   ├── Economy.luau          post formula, postValue, rebrand math, UTC day/week
    │   ├── Trends.luau           deterministic global trend schedule
    │   ├── Format.luau  Net.luau  Signal.luau  Types.luau
    ├── server/                   -> ServerScriptService.Server
    │   ├── Main.server.luau      boot order + replicated state builder
    │   ├── Services/
    │   │   ├── DataService.luau        ProfileStore, migrations, sanitize, state flush
    │   │   ├── ContentService.luau     take -> post loop, anti-exploit, Auto-Film
    │   │   ├── ProgressionService.luau gear, niches, rebrand
    │   │   ├── RewardService.luau      daily, Brand Deals, offline earnings
    │   │   ├── SocialService.luau      collab, friends, group
    │   │   ├── ViralService.luau       Viral Moments
    │   │   ├── LeaderboardService.luau OrderedDataStore all-time + weekly
    │   │   ├── MonetizationService.luau passes, receipts (PurchaseId-safe), Premium
    │   │   ├── WorldService.luau       placeholder map, boards, overhead billboards
    │   │   └── Analytics.luau          funnel, economy, custom events, A/B buckets
    │   └── Util/  Remotes.luau  Guard.luau  RateLimiter.luau
    └── client/                   -> StarterPlayerScripts.Client
        ├── Main.client.luau  State.luau  Actions.luau
        └── UI/
            ├── Root.luau  Theme.luau  Util.luau  Row.luau
            ├── Hud.luau  FilmButton.luau  Panels.luau  Toasts.luau
            └── Screens/  Shop  Niches  Deals  Leaderboard  Rebrand  Store
```

## Before you publish
- [ ] Create 4 game passes and 4 developer products and paste their ids into `src/shared/Config/Products.luau`.
- [ ] Set `Config.Game.GroupId` if you have a community group.
- [ ] Leave `UseLiveDataInStudio = false` in source control.
- [ ] Replace the placeholder hub: build `Workspace.Map`, tag 6–10 BaseParts `ViralSpawn` and one part `LeaderboardBoard`.
- [ ] Add licensed sound effects (post *whoosh*, follower *pop*, Perfect *ding*).
- [ ] Complete the Maturity & Compliance questionnaire, and keep all brands, apps and celebrities fictional.
- [ ] Icon and 3 thumbnails (GDD §1.4), then run icon tests before buying any ads.
