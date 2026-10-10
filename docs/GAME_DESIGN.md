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

No paid random items (loot boxes), so there are no odds-disclosure requirements. Every receipt is
recorded to prevent double-granting.

## World
| Zone | Levels | Enemies |
| --- | --- | --- |
| Riverwatch (town) | Safe | NPCs: Elder Maren, Brann, Ysolde, Seer Ilsa, Bounty Board |
| Whisperwood | 1–3 | Wolves |
| Redfang Camp | 3–5 | Bandits, Grisk the Redfang (elite) |
| Hollow Crypt | 6–8 | Hollow Dead |
| Cinder Peak | 9+ | The Ashen Wyrmling (boss) |
| Frosthollow | 10+ | Frost Trolls |

## Roadmap

**v0.1, this build (playable vertical slice).** All systems above with placeholder art.

**v0.2, first public test (about 1–2 weeks).**
* Replace placeholder models with real ones (Creator Store or commissioned), plus animations
* A real map built in Studio, and real sounds and music
* Balance pass from playtest data
* Tutorial hints for the first 5 minutes

**v0.3, retention.**
* Dungeons: instanced crypt runs with a boss at the end
* Crafting with materials
* World events (rotating: Blood Moon wolf surge, bandit raid on Riverwatch), scheduled server-wide
* Weekly bounty chains with a story wrapper

**v0.4+, live service.**
* Chapter 2: "The Mother of Ash" (new region and levels 15–25)
* Parties and guilds, leaderboards (Renown, kills)
* Seasonal cosmetics and Seasonal Renown tracks
* Mounts (cosmetic plus speed in the open world)

## Success metrics to watch (Creator Dashboard)
* Day-1 / Day-7 retention (targets: 20%+ / 5%+ for an early RPG)
* Average session length (target: 15+ min)
* % of players finishing MQ2 (tutorial funnel)
* Conversion and ARPPU on the Store
