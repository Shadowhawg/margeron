# Margeron

An open-world fantasy RPG for Roblox: explore the realm around the village of Riverwatch, fight
your way through a main story, build your character through a three-tree skill system, and take on
an endless supply of procedurally generated bounties.

* **Design doc:** [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
* **Adding content (quests, enemies, items, skills):** [docs/CONTENT_GUIDE.md](docs/CONTENT_GUIDE.md)

## What's in the current build

| System | Status |
| --- | --- |
| Cinematic story: prologue, five memory cutscenes ("Echoes"), cutscene-style NPC conversations | ✅ |
| Character creation: 6 races (each with a bonus), gender, height, build, skin, 9 hair styles, beards, outfits | ✅ |
| Open world (3,600 × 3,600 studs): hills, mountains, volcano, river, lakes, forests, 8 regions, 12 landmarks | ✅ |
| Exploration: discoveries (XP), world map (M), fast travel, day/night cycle | ✅ |
| Combat: arm-swing attacks, knockback, telegraphed enemy attacks, bosses, weapon infusions | ✅ |
| XP and levels, three-tree skill system (18 skills, 3 abilities), respec | ✅ |
| Crafting: forge (smelt, forge, temper, infuse), alchemy (discover-by-mixing), cooking, workbench | ✅ |
| Property: three home tiers on Greenmeadow plots, farm fields, livestock, horses you can ride (H) | ✅ |
| Farming: 5 crops, growth over real time (also offline), fertilizer, harvest buffs | ✅ |
| Local government: cross-server elections, Lord/Lady, tax, decrees, appointed Steward and Captain, treasury | ✅ |
| Economy: trader (sell anything), seed shop, taxes, Robux store incl. crafting boosts and a premium horse | ✅ |
| Main story (6 quests) + 8 side quests, endless Bounty Board, Daily Contract, Renown titles | ✅ |
| Adaptive music system (town / wilds / combat / boss / cutscene) | ⚠️ needs track IDs, see below |
| PC, mobile (touch buttons) and gamepad controls | ✅ |

Everything visual is a **placeholder built from parts**, so the game is playable right now. Swap in
real models, maps and animations whenever you're ready (see the content guide).

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
| Ride / dismount horse | H | L1 | Ride button |
| Drink best healing potion | Q | D-pad up | Inventory |
| Talk / read / gather / use station | E | (prompt) | Tap prompt |
| Pick a dialogue reply | 1-7 or click | | Tap |
| Skills / Journal / Inventory / Map / Store | K / J / I / M / B | | HUD buttons |
| Advance or skip cutscene text | Space / click | A | Tap |

## Adding music (5 minutes)

The adaptive music system is wired up, but Roblox audio has to be picked from the Creator Store, so
the track IDs start empty. In Studio: **View → Toolbox → Audio**, search for things like "medieval
village", "fantasy exploration", "epic battle", "dark ambient". Roblox's licensed music library is free
to use. Right-click a track, choose **Copy Asset ID**, and paste it into `src/shared/Config/Music.luau`.
Tracks fall back to each other, so even one "Wilds" track gives you music everywhere.

## Notes for Studio testing

* The world is generated each time a server starts (about 5 seconds), so the edit view is empty and
  everything appears when you press Play.
* Elections use 10-minute terms in Studio (3 days live) so you can test a full cycle.
* For the smoothest cutscenes on a big map, select **Workspace** and turn **StreamingEnabled** off
  (or keep it on for mobile memory; cutscenes request the area they show).

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
                     (Items, Enemies, World, Quests, Story, Races, Skills, Crafting, Property,
                      Government, Music, Products, Bounties, GameConfig)
    Stats.luau       derives combat stats from level/skills/weapon
    QuestRules.luau  quest progress rules
    Remotes.luau     networking
  server/            ServerScriptService.Server
    Services/        Data, Player, Character, Combat, Enemy, Quest, Bounty, NPC, World,
                     Exploration, Crafting, Property, Market, Government, Shop, ...
    Lib/             TerrainGen, Props, ModelBuilder (placeholder models), Signal
  client/            StarterPlayerScripts.Client
    Controllers/     HUD, combat input, cinematics, intro, dialogue, music, effects, markers
    Panels/          Character creator, Skills, Journal, Inventory, Crafting, Estate, Stable,
                     Seeds, Trader, Government, Map, Store, Blacksmith, Bounty Board
```

## Linting and formatting

```sh
selene src     # lint (first run generates roblox.yml)
stylua src     # format
```

## Tests

Logic tests run outside Roblox: config cross-references for every system, skill/quest/crafting
rules, a quest flow simulation, the bounty generator across all levels, and the full terrain
generator (checks that every town, NPC, zone, landmark and plot sits on dry land). Install the Luau CLI once (`rokit add luau-lang/luau`), then:

```sh
./tests/run.sh
```

Run them after editing anything in `src/shared/Config/`. They catch typos like a quest pointing
at an enemy or NPC that doesn't exist.
