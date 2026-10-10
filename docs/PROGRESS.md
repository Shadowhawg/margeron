# Tidewater: Progress

Last updated: 2026-10-10

## Phase status

| Phase | Status |
|---|---|
| 0. Environment and scaffolding | **Code done; waiting on Cam's Studio check** (see Cam to-do) |
| 1. Vertical slice: fish → sell → upgrade | Not started |
| 2. Garden, forage, content, onboarding | Not started |
| 3. Social | Not started |
| 4. Monetization and compliance | Not started |
| 5. Live ops | Not started |
| 6. Polish and launch readiness | Not started |
| 7. Post-launch | Not started |

### Phase 0 acceptance

- [x] `lune run check` passes with one sample test (verified 2026-10-10 in a cloud session)
- [ ] `rojo serve` syncs a server script that prints `Tidewater booted` (needs Studio)
- [ ] an MCP playtest shows that line in `get_console_output` (needs Studio)

## Toolchain (pinned in `rokit.toml`)

| Tool | Version |
|---|---|
| Rojo | 7.7.1 |
| Wally | 0.3.2 |
| StyLua | 2.6.0 |
| selene | 0.32.0 |
| luau-lsp | 1.70.1 (Roblox type definitions from the same tag, `globalTypes.None`) |
| Lune | 0.10.5 |

## Decisions

- **Toolchain:** the latest stable release of each tool as of 2026-10-10. This meets the spec's Rojo ≥ 7.6 and Wally 0.3.x requirements.
- **Requires in shared code:** relative string requires (`./X`, `../Config/Y`). The Roblox docs say `./` resolves from `script.Parent` and `@self/` from `script`, and Lune uses the same rules, so Logic modules run unchanged in Lune tests.
- **`.luaurc` aliases (`@shared`, `@testing`):** for Lune and tests only. Roblox doesn't read `.luaurc`, so `lune run conventions` rejects aliases in `src/`.
- **Logic purity is enforced mechanically:**
  - luau-lsp runs a second pass on `src/shared/Logic/` with no Roblox definitions, so `game`, `Instance`, `Random`, `task` and the rest become errors.
  - The conventions step bans `os.time`, `os.clock`, `os.date` and `math.random` in Logic.
- **Conventions step:** banned APIs (Part 4 pitfalls), `--!strict` on line one, and `.luau` only. These are cheap to check and catch the most common mistakes.
- **Type defs pinned to the luau-lsp tag:** this keeps analysis reproducible, and the defs update with the toolchain. They're cached in `.cache/` (gitignored) and downloaded with `curl`, because Lune's HTTP client ignores system certificates behind proxies.
- **luau-lsp checks `src/` only:** `lune/` and `tests/` are formatted, linted and executed but not type-checked. That would need per-machine `lune setup` typedefs.
- **Rojo `Packages` path is optional:** the project builds before any `wally install`.
- **Test runner:** `it` bodies run immediately when a spec file loads, and there are no hooks yet. It's the smallest thing that works; add `beforeEach` only when a spec needs it.
- **`lune run check` runs every step:** it reports a PASS/FAIL summary even after a failure, so one run shows every problem. The build output is deleted afterwards.
- **`.gitattributes` forces LF line endings:** without it, Windows checkouts would fail the StyLua check.
- **`tools/install-toolchain.sh`:** a fallback for cloud sessions. Rokit needs the GitHub API, which is blocked there; this script installs the same pinned versions from release downloads.

## Known issues

- **Phase 0 Studio checks are not done yet.** They couldn't be run from the cloud session because there's no Studio there.
- **Cloud sessions only: selene can't download its Roblox standard library.** Its TLS client doesn't trust the session proxy's certificate. This isn't an issue on a normal machine. Workaround used on 2026-10-10:
  1. Clone selene 0.32.0.
  2. Patch `selene/src/roblox/generate_std.rs` to read the API dump from `$SELENE_API_DUMP_FILE` when that's set.
  3. `cargo build --release -p selene`.
  4. `curl` the API dump from `CloneTrooper1019/Roblox-Client-Tracker` (branch `roblox`, `API-Dump.json`).
  5. Run the patched `selene update-roblox-std`. This writes `~/.cache/selene/roblox.yml`, which the official pinned binary then uses.

## Inserted Creator Store assets

None.

## Cam to-do

### To finish Phase 0 (on your computer)

1. **Install Rokit** (skip this if you have it), then close and reopen your terminal.
   - macOS: `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
   - Windows (PowerShell): `Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression`
2. **Get the code:**
   - `git clone https://github.com/shadowhawg/margeron.git`
   - `cd margeron`
   - `git checkout claude/new-session-jurd2i`
3. **Install the tools:** run `rokit install` and answer **yes** to each "trust this tool?" prompt.
4. **Install the Rojo plugin:** run `rojo plugin install`, then restart Studio.
5. **Run the gate:** `lune run check`. All six summary lines should say **PASS**. The first run downloads type definitions, so it takes a little longer.
6. **Open the Tidewater place in Studio** and make sure the MCP server is enabled (spec steps 3–4).
7. **Start Claude Code in the `margeron` folder** and send: **"Read CLAUDE.md and docs/PROGRESS.md, then finish the Phase 0 Studio checks."** It will start `rojo serve` and ask you to click **Connect** in the Rojo plugin (Plugins tab → Rojo). Then it playtests and confirms `Tidewater booted` shows up in the output.

### Standing (from BUILD_SPEC Part 5)

- Keep Studio open with the MCP server enabled and Rojo connected during sessions.
- Save and publish the place when asked.
- Create passes, developer products and badges in the Creator Dashboard when asked (Phase 4), and paste the IDs.
- Put your Roblox UserId in `Config/Admins.luau` (Phase 5).
- Run the 2-player checklists in `docs/TESTING.md` (from Phase 3).
- Complete the Maturity & Compliance questionnaire and store page assets before going public (Phase 6).
