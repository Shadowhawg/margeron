# Content guide

Almost everything in the game is defined in `src/shared/Config/`. Change those files and the
systems pick the changes up. No systems code needs editing.

## Add a quest

`Config/Quests.luau`: add an entry and put its id in `Order`.

```lua
MQ7 = {
	Name = "The Mother of Ash",
	Type = "Main",
	Giver = "Elder",          -- NPC id from Config/World (nil = starts automatically)
	TurnIn = "Elder",
	LevelReq = 12,
	Requires = { "MQ6" },     -- unlocks after MQ6
	Description = "...",
	Objectives = {
		{ Kind = "Kill", Target = "FrostTroll", Count = 5, Text = "Slay Frost Trolls" },
		{ Kind = "Collect", Target = "TrollFat", Count = 2, Text = "Collect Troll Fat" },
		{ Kind = "Talk", Target = "Mystic", Count = 1, Text = "Consult Seer Ilsa" },
	},
	Rewards = { XP = 2000, Gold = 500, Weapon = "RunedStaff", Cosmetic = "TitleWarden" },
	Dialogue = { Offer = "...", Progress = "...", Complete = "..." },
},
```

NPCs automatically show `!` when they have a quest for you and `?` when you can turn one in.

## Add a bounty type or flavor

`Config/Bounties.luau`: add names, clients or whole templates. Placeholders: `{enemy}`,
`{enemies}`, `{material}`, `{zone}`, `{client}`, `{count}`.

## Add an enemy

1. `Config/Enemies.luau`: add stats (see the comments at the top of the file).
2. `Config/World.luau`: add it to a zone's `Spawns`.

It automatically becomes eligible for bounties at the right level.

## Add a zone

`Config/World.luau` → `Zones`: give it a position, radius, ground material and spawns. The
generated world paints the ground, adds a signpost and a road from town. To add props, add a
branch to `buildZone` in `server/Services/WorldService.luau`, or build it by hand in Studio.

## Add a weapon or cosmetic

`Config/Items.luau`. Give a weapon a `Price` to sell it at Brann's forge. To sell something for
Robux, set `Premium` and add a matching entry in `Config/Products.luau`.

## Add or change skills

`Config/Skills.luau`. Each node has `Tier` (row 1–4) and `Column` (1–2) for layout, `MaxRank`,
`Requires`, and `Effects` per rank. Stat names: `MaxHealth`, `PhysicalDamage`, `SpellPower`,
`CritChance`, `CritDamage`, `Lifesteal`, `DamageReduction`, `WalkSpeed`, `CooldownReduction`,
`BackstabBonus`.
New active abilities need a handler in `server/Services/CombatService.luau` (`abilityHandlers`)
and an entry in `Config/Abilities.luau`. New `Flag` mechanics are implemented in `CombatService`.

## Replace the placeholder world with a real map

1. Build your map in Studio inside a **Folder named `Map`** in Workspace. When it exists,
   world generation is skipped.
2. Inside `Map`, add a Folder `Markers` with (invisible, anchored) Parts named after NPC ids
   (`Elder`, `Blacksmith`, `Hunter`, `Mystic`, `Board`) and zone ids (`WolfWoods`, `BanditCamp`,
   `HollowCrypt`, `CinderPeak`, `FrostHollow`). NPCs and enemy spawns move to them.
3. Because Rojo only manages `src/`, save the place file in Studio (or publish it). Your map
   lives in the place, and the code syncs on top.

## Replace placeholder models

`server/Lib/ModelBuilder.luau` builds every enemy, NPC and weapon. The simplest swap is to put
real models in `ServerStorage` and have `ModelBuilder.Creature` / `ModelBuilder.Weapon` clone
those by name, falling back to the part-built version. Enemy models need a `HumanoidRootPart`
and a `Humanoid`.

## Story and cutscenes

`Config/Story.luau`. A cutscene is a list of camera shots with lines of narration. Camera points are
either world positions (Y = height above the ground there) or anchored to the player or an NPC.
`{name}` and `{race}` are filled in per player. Link a cutscene to a quest in `Story.QuestEchoes`
and it plays when the quest is turned in (and appears under Journal → Memories).

## Races and character options

`Config/Races.luau`: add a race (height/width ranges, skin palette, features, stat bonus), a hair
style (also add a builder in `server/Services/AppearanceService.luau`), hair colors or outfits.
Hair styles can instead point at a Roblox catalog accessory with `AccessoryId`.

## Crafting

`Config/Crafting.luau`:
* **Recipes:** station, inputs, output (material, weapon, cosmetic or food), level, XP.
* **Effects:** the potion/food effects. New ones need a `Stat` that exists in `Stats.luau`.
* **Ingredients:** add `Effects = { "A", "B", "C" }` to any material in `Config/Items` and it becomes
  an alchemy ingredient automatically. The tests check that every effect is brewable.
* **Infusions:** new weapon infusions. Their on-hit behavior lives in `CombatService` (`hit`).

## Property, farming and animals

`Config/Property.luau`: home tiers (price, fields, animal slots, stations), plot positions, crops
(seed, grow time, yield), livestock (product, interval) and horses (price, speed).

## Government

`Config/Government.luau`: term length, requirements, tax limits, official discounts and decrees.
A new decree needs its effect implemented where it applies (search for `DecreeActive`).

## Music

`Config/Music.luau`: paste Roblox audio IDs. Contexts fall back to each other, so start with one
"Wilds" track and add more over time.

## World

`Config/World.luau`: zones, landmarks (Kind = Tower, Stones, ElderTree, Overlook, Shrine, Hut,
Wreck, Colossus, Mine, Arch), lakes, the river, the volcano, roads and NPCs. `tests/run.sh` checks
that everything lands on dry land after you move things around.

## Calendar and night

`Config/Calendar.luau`: day length, the hour servers open at, night hours, month and weekday names,
the era, holidays (with their bonuses) and night modifiers.

## Buildings

`server/Lib/Architecture.luau` builds the timber-framed houses, stone walls, towers, gatehouses,
lamps, streets, market stalls and fountains; reuse it for new towns.
`server/Lib/CrownCity.luau` lays out Aurelion (positions are in "city space" with the gate at -X).

## Balance knobs

`Config/GameConfig.luau`: XP curve inputs, health per level, respec cost, bounty board size and
refresh, daily multiplier and Renown thresholds.
