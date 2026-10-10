# Margeron: Game Design Document

## Pitch

A Roblox open-world fantasy RPG in the spirit of the great single-player epics, rebuilt for
multiplayer sessions. You wake on a riverbank with no memory, a sword and a sky full of ash.
Explore, fight, level up, and shape your character however you like. When the story ends,
the world keeps giving you reasons to come back.

> **IP note:** Margeron is *inspired by* games like Skyrim, but it must not use their names,
> characters, logos, music or assets. Roblox removes experiences that infringe IP. Everything
> here (names, places, lore) is original.

## Design pillars

1. **Freedom of build.** Every level gives one skill point to spend in any tree. A sword-wielding
   pyromancer or a stealthy tank are both valid builds.
2. **There's always something to do.** The story is hand-written. Bounties, daily contracts and
   (later) events are generated and never run out.
3. **Fair monetization.** Robux buys looks, convenience and *side-grade* weapons that are level
   gated and no stronger than gold-bought gear at that level. Players can't buy power they
   haven't earned.
4. **Readable combat.** Enemies telegraph attacks (red flash, red ground circles). Dodging
   matters, especially against elites and bosses.
5. **Content as data.** Quests, enemies, items, skills and zones are config tables. Adding content
   should never require touching systems code.

## Core loop

```
Take a quest or bounty → travel to a zone → fight (XP, gold, materials)
        ↑                                                      ↓
   new gear / skills  ←  level up, spend points, shop  ←  turn in rewards
```

**Session loop (10–30 min):** check the Bounty Board, grab up to 3 bounties plus the Daily
Contract, clear them, spend rewards.
**Long loop:** finish the story → reach max level → collect Renown titles and cosmetics →
take on harder zones and world bosses (roadmap).

## Systems

### Progression
* Levels 1–50. XP to next level = `100 × level^1.5`.
* Each level: +8 max health, +3% weapon damage and spell power, +1 skill point.
* Tunable in `Config/GameConfig.luau`.

### Skill tree (3 trees × 6 nodes)
| Tree | Fantasy | Ability | Unique mechanic |
| --- | --- | --- | --- |
| **Might** | Warrior | Whirlwind (AoE spin) | *Last Stand*: below 30% HP deal +30% and take -30% damage |
| **Arcana** | Mage | Firebolt (exploding bolt) | *Arcane Ward* (damage shield), *Conflagration* (burning), *Arcane Echo* (25% instant recharge) |
| **Shadow** | Rogue | Shadowstep (dash + guaranteed crit) | *Backstab* (bonus vs. distracted enemies), *Assassinate* (kills refresh Shadowstep and heal) |

Tiers unlock at levels 1 / 3 / 6 / 10, and nodes have prerequisites. Seer Ilsa resets the tree for gold.

### Combat
* **Weapon types:** Sword (cleaves 3 targets), Axe (slow, cleaves 4), Dagger (fast, single target,
  +crit), Staff (ranged bolt, scales with Spell Power).
* Server-authoritative hit detection: the client sends only an aim direction.
* Enemies have aggro range, leash to their zone, reset and heal if you run away, and wind up
  before every attack. Elites and bosses have telegraphed area attacks.
* Co-op friendly: everyone who damages an enemy gets full XP, gold, drops and quest credit.

### Quests
* **Main story, "The Ashen Wake" (6 quests, levels 1–9):** wolves → blacksmith → Redfang
  bandits → Hollow Crypt → the Ashen Wyrmling boss. The ending sets up the next chapter (the
  wyrm's mother).
* **Side quests:** hand-written, from town NPCs.
* **Bounties (evergreen):** see below.

### The evergreen layer
1. **Bounty Board.** It generates contracts from templates (Hunt, Gather, Elite) × eligible enemies ×
   flavor text, scaled to the player's level, with 4 offers at a time. It refreshes every 30 minutes,
   and players can pay 25 gold to reroll.
2. **Daily Contract.** The same contract for everyone each day (seeded by date), with 2.5× rewards.
3. **Renown.** Bounties grant Renown (+1, or +3 for dailies), which unlocks titles: Sellsword → Bounty
   Hunter → Warden of Riverwatch → Legend of Margeron.
4. **Data-driven story chapters.** New chapters are new quest entries that require the last one.
   Players who finished earlier chapters pick them up automatically.

### Economy
* **Gold sources:** kills, quests, bounties.
* **Gold sinks:** weapons at Brann's forge, rerolls, respecs.
* **Materials:** drop from enemies and are used by Gather bounties and quests. Crafting is on the
  roadmap.

### Monetization
| Product | Type | Notes |
| --- | --- | --- |
| Emberbrand, Frostfang Staff | Game Pass | Side-grade weapons, level-gated (Lv 4 / Lv 6) |
| Founder's Title | Game Pass | Cosmetic |
| Capes, Auras | Developer Product (one-time unlock) | Cosmetic |
| Gold pouches | Developer Product (consumable) | Convenience |
| Artisan's Focus (1 hour) | Developer Product (consumable) | Crafting boost |
| Growth Tonic | Developer Product (consumable) | Instantly ripens crops |
| Master Artisan | Game Pass | Permanent crafting boost |
| Shadowmare | Game Pass | Premium horse (same top speed as the best gold horse) |

No paid random items (loot boxes), so there are no odds-disclosure requirements. Every receipt is
recorded to prevent double-granting.

## Story: "The Unremembered"

The player is spoken to directly from the first second. A voice wakes you on a riverbank:
*"Breathe. ...Good. You still remember how to do that, at least."* You have no memory and no face, so
character creation happens as you look into the water (*"Tell me who you see"*).

The voice turns out to be **what is left of your own former self**. You were the commander of the
Ashen Guard, seven soldiers who climbed Cinder Peak to bind the Mother of Ash. Only you came back,
and the binding cost your memory and your name. Each main quest unlocks an **Echo**, a memory cutscene
that reveals another piece:

| Quest | Echo | Reveal |
| --- | --- | --- |
| Teeth in the Woods | I: The Burning Wood | You've seen this before; you never ran |
| Arms for the Watch | II: A Blade With a Name | You were a warrior for a very long time |
| The Redfang Problem | III: What Was Buried | Someone is digging up what *you* buried |
| Whispers Below | IV: The Ashen Guard | The truth about the seal and the voice |
| The Ashen Wake | V: Oathbreaker | The Mother knows you, and you have a choice about who you become |

The ending of chapter one deliberately points at the player-driven systems: *"Build a home. Earn a
name. Rule this valley if you want to."* Chapter two (the Mother of Ash) continues from Echo V.

## Time, calendar & night
* **Clock:** every server opens at **night** (9:30 PM), and a game day lasts 24 real minutes.
  The HUD shows the time, date and season.
* **The Margeron Reckoning:** 12 months of 30 days (Frostwane, Thawmoon, Seedrise, Rainhold,
  Bloomtide, Highsun, Emberfall, Goldreap, Leafturn, Duskmere, Hearthfrost, Longnight), 7 weekdays
  (Sunsday to Starsday), and the year *913 of the Ember Age*. The date is shared by every server.
* **Holidays** grant a day-long bonus to everyone:
  * New Ember (+XP)
  * Founding Day (+gold)
  * Blossom Fair (double herbs)
  * Night of Embers (+XP and gold, honoring the Ashen Guard)
  * Harvest Moon (+yields)
  * Veil Night (+XP)
  * Longnight Vigil (double gathering, +gold)
* **Night:**
  * Enemies hit 20% harder but give 25% more XP and gold.
  * Moonpetal yields double.
  * Sneaking is more effective.
  * Players carry a lantern, and lamps and windows light the towns.
* **Rest:** at an inn (for gold) or at home (free) for full health plus *Well Rested* (+10% XP for
  30 minutes).

## Stealth
Press **C** to crouch: you move at 55% speed and enemies only notice you within 45% of their
normal range (30% at night). Hitting an enemy that hasn't noticed you is a **sneak attack** for
double damage, and it stacks with the Shadow tree. The HUD shows **Hidden** or **Detected**.

## Aurelion, the Crown City
A walled capital on an island in a lake east of Riverwatch, reached by a long causeway. At its
heart is the 175-stud **White Tower**, crowned with light and visible across the map, inside a
walled palace with gardens.
* **Market plaza:** stalls and a fountain just inside the gate.
* **Collegium of Stars:** a domed temple-college (Archmage Selene).
* **Arena:** reserved for future PvP or events.
* **Memorial gardens:** statues of the seven Ashen Guard.
* **The Gilded Stag:** an inn where you can rent a bed.
* **Royal Armory:** Master Davor's shop.
* **Second Bounty Board**, crown guards, and five districts of stone townhouses.
* **Quests:** *The Crown City*, *The Chancellor's Writ*, and *Stone Sentinels*, which ties the
  Sentinels' binding glyphs to the player's past.

## Character creation
Six races, each with a passive bonus: Riverfolk (+10% XP), Highlander (-8% damage taken), Sylvan
(+12% spell power, pointed ears), Ironblood (+10% weapon damage, tusks), Deepkin (+20 HP, +10% gold,
short and stocky), Cindertouched (+6% crit, ember eyes). Players also choose gender, height and build
sliders (scaled within each race's range), skin tone (per-race palette), 9 hair styles, 10 hair colors,
5 beards and 8 outfits. Seer Ilsa can reshape your appearance later for gold.

## World & exploration
A 3,600 × 3,600 stud open world generated from config: rolling hills, a mountain border, a volcano,
a winding river with bridges, three lakes (one with an island shrine), forests, snowfields and marsh.
* **Regions:** Riverwatch (walled town), Greenmeadow (farmland and property plots) and 7 combat zones
  from level 1 to 15.
* **12 landmarks** grant XP when discovered and become fast-travel points on the map (M).
* **Gathering:** about 350 herb and ore spots, placed by biome.
* **Day/night:** a 24-minute cycle.

| Zone | Levels | Enemies |
| --- | --- | --- |
| Whisperwood | 1-3 | Wolves |
| Redfang Camp | 3-5 | Bandits, Grisk the Redfang (elite) |
| Hollow Crypt | 6-8 | Hollow Dead |
| Mirelake Marsh | 7-9 | Bog Lurkers |
| Cinder Peak | 9+ | The Ashen Wyrmling (boss) |
| Frosthollow | 10-12 | Frost Trolls |
| Ruins of Vael | 12-15 | Ruin Sentinels |

## Crafting
Simple to start, with lots of room for creativity:
* **Forge.** Smelt ore into ingots, forge 5 unique weapons, temper any weapon (+8% damage per level,
  up to +5), and **infuse** one effect per weapon (Ember burn, Frost slow, Venom poison, Vampiric
  lifesteal, Fortune gold, Arcane spell power). Combined with skills and potions, this makes for a lot
  of build combinations.
* **Alchemy (discovery).** Every ingredient has 3 hidden effects. Mixing 2-3 ingredients makes a potion
  of every effect they share. Players learn effects by experimenting or by tasting. Ten effects
  (healing, regeneration, strength, magic, speed, resistance, precision, fortune, insight, vigor) give
  hundreds of combinations, and potency rises with crafting level.
* **Cooking.** Farm produce and animal goods become long-lasting food buffs.
* **Workbench.** Fertilizer, leather, and dyed woven capes, where the herb you choose sets the color.
* **Crafting level.** Up to 30. It unlocks recipes and raises potion potency.
* **Robux boosts.** *Artisan's Focus* (1 hour of double crafting XP plus a 25% chance of double output)
  and the *Master Artisan* pass (+1 potion potency and a 10% chance of double output, permanently).

## Property, farming & livestock
* **Homes** (gold sinks): Riverside Cottage 2,500 → Greenmeadow Farmhouse 12,000 → Lakeside Manor
  40,000. Upgrading trades in your old home for 50% of its price. A home is a deed: it's built on a free
  Greenmeadow plot in whatever server you join, with your name on the sign.
* Each tier adds **farm fields** (2/6/10), **animal pens** (2/6/12) and **crafting stations**. The Manor
  has its own forge and alchemy lab.
* **Farming:** buy seeds from Old Tomas, plant, and come back when they're ripe. Crops grow in real
  time, even while you're offline. Fertilizer halves the growing time. Moonpetal and Emberroot are
  farmable alchemy herbs.
* **Livestock:** chickens (eggs), sheep (wool) and cows (milk) produce goods over time.
* **Horses:** four horses with increasing speed (H to ride). One of them, the Shadowmare, is a premium
  Robux horse.

## Local government
Riverwatch is ruled by an elected **Lord or Lady**, shared across *every* server through DataStores.
* **Terms** last 3 days. During a term, eligible players (level 8, 10 Renown, 2,000 gold fee) stand
  for the next term by pledging a decree. Everyone level 3 or higher gets one vote per term at the
  Town Hall.
* **The winner** can set the purchase tax (0-15%), choose the active **decree** (Harvest Festival,
  Bounty Edict, Open Markets, Artisans' Charter, Veterans' Due), and appoint a **Steward** and a
  **Captain of the Watch** by username. They can also claim the **treasury**: taxes and filing fees
  collected across all servers.
* **Officials** get titles over their heads, shop discounts and a golden aura (Lord). The statue
  plaque in town names the current ruler.
* **Why it matters:** this gives top players a social, competitive goal that changes the game for
  everyone.

## Presentation
* **Cutscenes:** letterbox bars, scripted camera moves, title cards, and typewriter narration that
  personalizes lines with the player's name and race.
* **NPC conversations:** a cinematic over-the-shoulder shot of the NPC, who turns to face you.
* **Adaptive music:** picks a track for town, farmland, each biome, combat, boss fights and cutscenes,
  with crossfades and ambience layers. Track IDs are set in `Config/Music`.

## Roadmap

**v0.1, this build (playable vertical slice).** All systems above with placeholder art.

**v0.2, first public test (about 1–2 weeks).**
* Replace placeholder models with real ones (Creator Store or commissioned), plus animations
* A real map built in Studio, and real sounds and music
* Balance pass from playtest data
* Tutorial hints for the first 5 minutes

**v0.3, retention.**
* Dungeons: instanced crypt runs with a boss at the end
* World events (rotating: Blood Moon wolf surge, bandit raid on Riverwatch), scheduled server-wide
* Weekly bounty chains with a story wrapper

**v0.4+, live service.**
* Chapter 2: "The Mother of Ash" (new region and levels 15–25)
* Parties and guilds, leaderboards (Renown, kills)
* Seasonal cosmetics and Seasonal Renown tracks
* More mounts and mounted combat

## Success metrics to watch (Creator Dashboard)
* Day-1 / Day-7 retention (targets: 20%+ / 5%+ for an early RPG)
* Average session length (target: 15+ min)
* % of players finishing MQ2 (tutorial funnel)
* Conversion and ARPPU on the Store
