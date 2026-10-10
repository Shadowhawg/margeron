# Tidewater

**At the start of every session, read `docs/PROGRESS.md` and the section of `docs/BUILD_SPEC.md` for the current phase.**

The full spec is `docs/BUILD_SPEC.md`. Part 0 (the working rules) is copied below so it is always in context.

## Working rules (BUILD_SPEC Part 0)

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

## Commands

Run everything from the repo root.

| Command | What it does |
|---|---|
| `rokit install` | Install the toolchain pinned in `rokit.toml` |
| `lune run check` | **The quality gate.** StyLua check → selene → conventions → luau-lsp (strict) → tests → `rojo build`. Must pass before every commit |
| `lune run test` | Run all `tests/**/*.spec.luau`; `lune run test -- Trade` runs only matching files |
| `lune run analyze` | luau-lsp strict type-check of `src/`, plus the Logic purity pass |
| `lune run conventions` | Project-rule checks (banned APIs, `--!strict`, require style, pure Logic) |
| `stylua src lune tests tools` | Auto-format |
| `rojo serve` | Live-sync `src/` into Studio (run in the background; Cam clicks **Connect** in the Rojo plugin) |
| `rojo sourcemap default.project.json --output sourcemap.json` | Regenerate the sourcemap for luau-lsp (`lune run analyze` does this) |
| `rojo plugin install` | Install the Rojo Studio plugin |
| `wally install` | Install packages from `wally.toml` into `Packages/` |

**Cloud sessions** (Claude Code on the web): Rokit can't reach the GitHub API there. Run `tools/install-toolchain.sh`, then `export PATH="$PWD/.toolchain/bin:$PATH"`. There's no Roblox Studio in the cloud, so MCP checks must run on Cam's machine. See "Known issues" in `docs/PROGRESS.md` for the selene std workaround.

## Repo layout

```
default.project.json   rokit.toml   wally.toml   selene.toml   stylua.toml   .luaurc
CLAUDE.md
docs/  BUILD_SPEC.md  PROGRESS.md  ECONOMY.md  TESTING.md
src/
  shared/          -> ReplicatedStorage.Shared
    Config/        all tunables and player-facing strings (Strings.luau)
    Logic/         PURE modules: no Roblox globals, no os.time/os.clock/math.random; inject rng and now
    Net/           remote definitions + arg validators
    Types.luau
  server/          -> ServerScriptService.Server (init.server.luau boots Services/ in a fixed order)
    Services/      thin adapters over Logic; touch Roblox APIs
    Vendor/        ProfileStore (vendored; version recorded in PROGRESS.md)
  client/          -> StarterPlayer.StarterPlayerScripts.Client (init.client.luau boots Controllers/)
    Controllers/
    UI/            React components
tests/             *.spec.luau for every Logic module
lune/              check / test / analyze / conventions scripts; lib/testing.luau is the test runner
tools/world/       idempotent world builders, run via MCP execute_luau on the Edit data model
tools/smoke/       in-Studio smoke checks, run via MCP during playtests
tools/install-toolchain.sh   toolchain fallback for cloud sessions
```

Rojo manages only `src/` and `Packages/`. **Workspace is not in the Rojo project**; the world comes from `tools/world/` builders.

## Code conventions (enforced by `lune run check`)

- `--!strict` on the first line of every `src/` file; `.luau` extension only.
- **Requires:**
  - Shared modules require each other with relative string paths (`require("./Rolls")`, `require("../Config/Variants")`). Roblox resolves `./` from `script.Parent` and `@self/` from `script`, and Lune uses the same rules, so Logic modules run unchanged in tests.
  - Server and client code require shared modules by instance path (`ReplicatedStorage.Shared.Logic.X`).
  - `.luaurc` aliases (`@shared`, `@testing`) exist only in Lune and luau-lsp. Use them in `tests/` and `lune/`, never in `src/`.
- **Banned in `src/` and `tools/`:**
  - `wait`, `spawn`, `delay`, `tick`, `loadstring`
  - `GetMouse`, `GetProductInfo` (use `GetProductInfoAsync`), `InvokeClient`
  - the legacy `Chat` service
- **Tests:** `local T = require("@testing")`, then `T.describe` / `T.it` / `T.expect(x).toBe(y)`. Available matchers: `toEqual`, `toBeNear`, `toBeNil`, `toBeTruthy`, `toBeGreaterThan`, `toBeLessThan`, `toThrow`, plus `.never` to negate any of them.
