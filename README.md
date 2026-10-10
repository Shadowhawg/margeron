# Margeron

An open-world fantasy RPG for Roblox: explore the realm around the village of Riverwatch, fight
your way through a main story, build your character through a three-tree skill system, and take on
an endless supply of procedurally generated bounties.

* **Design doc:** [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
* **Adding content (quests, enemies, items, skills):** [docs/CONTENT_GUIDE.md](docs/CONTENT_GUIDE.md)

## What's in the current build

| System | Status |
| --- | --- |
| Generated placeholder world: town, 5 zones, roads, river, lighting | ✅ |
| Combat: melee cleave, staff bolts, crits, enemy wind-up telegraphs, boss area attacks | ✅ |
| XP and levels (cap 50), gold, saving with session locking | ✅ |
| Skill tree: Might / Arcana / Shadow, 18 nodes, 3 abilities, 5 unique mechanics, respec | ✅ |
| Main story (6 quests) and 2 side quests with NPC dialogue | ✅ |
| Bounty Board: endless generated bounties plus a Daily Contract, Renown titles | ✅ |
| Weapons shop (gold), inventory, cosmetics (capes, auras, titles) | ✅ |
| Robux store: Developer Products and Game Passes, Studio test purchases | ✅ |
| Quest waypoint, NPC `!`/`?` markers, zone banners | ✅ |
| PC, mobile (touch buttons) and gamepad controls | ✅ |

Everything visual is a **placeholder built from parts** so the game is playable right now. Swap in
real models/maps whenever you're ready (see the content guide).

## Setup (one time)

1. Install **Roblox Studio**.
2. Install **Rokit** (the tool manager): <https://github.com/rojo-rbx/rokit#installation>
3. In this folder run:
   ```sh
   rokit install
   ```
   This installs the pinned versions of Rojo, Selene and StyLua from `rokit.toml`.
4. Install the **Rojo plugin** in Studio: run `rojo plugin install`, or get "Rojo" from the
   Creator Store, then restart Studio.

## Running the game

**Option A: live sync (recommended while developing)**

```sh
rojo serve
```
Open a new **Baseplate** in Studio, go to the **Plugins** tab, then **Rojo**, then **Connect**. Code changes
in `src/` now sync into Studio. Press **Play** (F5).

**Option B: build a place file**

```sh
rojo build -o Margeron.rbxlx
```
Open `Margeron.rbxlx` in Studio and press **Play**.

### Turning on saving in Studio

By default Studio can't reach DataStores, and the HUD shows *"TEST MODE: progress is not saved"*.
To test saving: publish the place (**File → Publish to Roblox**), then **Game Settings → Security →
Enable Studio Access to API Services**.

## Controls

| Action | PC | Gamepad | Mobile |
| --- | --- | --- | --- |
| Attack (hold to repeat) | Left click | R2 | Attack button |
| Abilities | 1 / 2 / 3 | X / Y / L2 | Ability buttons |
| Talk / read | E | (prompt) | Tap prompt |
| Skills / Journal / Inventory / Store | K / J / I / B | — | HUD buttons |

## Publishing and monetization checklist

1. **File → Publish to Roblox** from Studio.
2. Creator Dashboard → your experience → **Monetization**:
   * Create a **Developer Product** for each entry in `Products.DevProducts`.
   * Create a **Pass** for each entry in `Products.GamePasses`.
3. Paste each ID into `src/shared/Config/Products.luau` (items with ID `0` are hidden in live servers).
4. Set the experience to Public. Fill in the description and thumbnails, and set the age rating
   (complete the **Experience Questionnaire**).

## Project layout

```
src/
  shared/            ReplicatedStorage.Shared: used by server and client
    Config/          ALL game content and balance: edit these to change the game
    Stats.luau       derives combat stats from level/skills/weapon
    QuestRules.luau  quest progress rules
    Remotes.luau     networking
  server/            ServerScriptService.Server
    Services/        Data, Player, Combat, Enemy, Quest, Bounty, NPC, Shop, World, ...
    Lib/             ModelBuilder (placeholder models), Signal
  client/            StarterPlayerScripts.Client
    Controllers/     HUD, combat input, effects, dialogue, notifications, world markers
    Panels/          Skills, Journal, Inventory, Store, Blacksmith, Bounty Board windows
```

## Linting and formatting

```sh
selene src     # lint (first run generates roblox.yml)
stylua src     # format
```

## Tests

Logic tests run outside Roblox: config cross-references, skill rules, quest flow, and the bounty
generator across all levels. Install the Luau CLI once (`rokit add luau-lang/luau`), then:

```sh
./tests/run.sh
```

Run them after editing anything in `src/shared/Config/`. They catch typos like a quest pointing
at an enemy or NPC that doesn't exist.
