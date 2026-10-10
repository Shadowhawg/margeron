-- The skill tree. Three trees, mix freely: every level grants a skill point.
--
-- Node fields:
--   Tier       1-4. Tier N needs GameConfig.TierLevelRequirements[N] player level.
--   Column     horizontal position in the UI (1-2).
--   MaxRank    how many points can go into it.
--   Requires   node ids that need at least 1 rank first.
--   Effects    stat bonus PER RANK (see Stats.luau for the stat names).
--   Ability    unlocks an active ability (see Config/Abilities).
--   Flag       unlocks a unique mechanic handled in CombatService.
return {
	Order = { "Might", "Arcana", "Shadow" },

	Trees = {
		Might = {
			Name = "Might",
			Description = "Steel, sinew and stubbornness.",
			Color = Color3.fromRGB(220, 80, 60),
			Nodes = {
				IronSkin = {
					Name = "Iron Skin",
					Tier = 1,
					Column = 1,
					MaxRank = 3,
					Effects = { MaxHealth = 15 },
					Description = "+15 max health per rank.",
				},
				HeavyBlows = {
					Name = "Heavy Blows",
					Tier = 1,
					Column = 2,
					MaxRank = 3,
					Effects = { PhysicalDamage = 0.08 },
					Description = "+8% weapon damage per rank.",
				},
				Bloodthirst = {
					Name = "Bloodthirst",
					Tier = 2,
					Column = 1,
					MaxRank = 2,
					Requires = { "IronSkin" },
					Effects = { Lifesteal = 0.03 },
					Description = "Heal for 3% of damage dealt per rank.",
				},
				Whirlwind = {
					Name = "Whirlwind",
					Tier = 2,
					Column = 2,
					MaxRank = 1,
					Requires = { "HeavyBlows" },
					Ability = "Whirlwind",
					Description = "ABILITY: Spin, striking every enemy around you.",
				},
				Juggernaut = {
					Name = "Juggernaut",
					Tier = 3,
					Column = 1,
					MaxRank = 2,
					Requires = { "Bloodthirst" },
					Effects = { DamageReduction = 0.06 },
					Description = "Take 6% less damage per rank.",
				},
				LastStand = {
					Name = "Last Stand",
					Tier = 4,
					Column = 2,
					MaxRank = 1,
					Requires = { "Juggernaut", "Whirlwind" },
					Flag = "LastStand",
					Description = "Below 30% health: deal 30% more damage and take 30% less.",
				},
			},
		},

		Arcana = {
			Name = "Arcana",
			Description = "Old words with sharp edges.",
			Color = Color3.fromRGB(110, 140, 255),
			Nodes = {
				Focus = {
					Name = "Focus",
					Tier = 1,
					Column = 1,
					MaxRank = 3,
					Effects = { SpellPower = 0.12 },
					Description = "+12% Spell Power per rank (staves and spells).",
				},
				Swiftcast = {
					Name = "Swiftcast",
					Tier = 1,
					Column = 2,
					MaxRank = 3,
					Effects = { CooldownReduction = 0.07 },
					Description = "Abilities recharge 7% faster per rank.",
				},
				Firebolt = {
					Name = "Firebolt",
					Tier = 2,
					Column = 1,
					MaxRank = 1,
					Requires = { "Focus" },
					Ability = "Firebolt",
					Description = "ABILITY: Hurl an exploding bolt of fire.",
				},
				ArcaneWard = {
					Name = "Arcane Ward",
					Tier = 2,
					Column = 2,
					MaxRank = 1,
					Requires = { "Swiftcast" },
					Flag = "ArcaneWard",
					Description = "A ward absorbs the next 20 + 3/level damage. Recharges after 12s.",
				},
				Conflagration = {
					Name = "Conflagration",
					Tier = 3,
					Column = 1,
					MaxRank = 1,
					Requires = { "Firebolt" },
					Flag = "Conflagration",
					Description = "Firebolt sets enemies ablaze for 60% extra damage over 3s.",
				},
				ArcaneEcho = {
					Name = "Arcane Echo",
					Tier = 4,
					Column = 2,
					MaxRank = 1,
					Requires = { "Conflagration", "ArcaneWard" },
					Flag = "ArcaneEcho",
					Description = "Abilities have a 25% chance to recharge instantly.",
				},
			},
		},

		Shadow = {
			Name = "Shadow",
			Description = "Strike first. Strike unseen.",
			Color = Color3.fromRGB(150, 90, 200),
			Nodes = {
				KeenEye = {
					Name = "Keen Eye",
					Tier = 1,
					Column = 1,
					MaxRank = 3,
					Effects = { CritChance = 0.04 },
					Description = "+4% critical hit chance per rank.",
				},
				FleetFoot = {
					Name = "Fleet Foot",
					Tier = 1,
					Column = 2,
					MaxRank = 3,
					Effects = { WalkSpeed = 1.5 },
					Description = "+1.5 movement speed per rank.",
				},
				Backstab = {
					Name = "Backstab",
					Tier = 2,
					Column = 1,
					MaxRank = 2,
					Requires = { "KeenEye" },
					Effects = { BackstabBonus = 0.25 },
					Description = "+25% damage per rank to enemies that aren't fighting you.",
				},
				Shadowstep = {
					Name = "Shadowstep",
					Tier = 2,
					Column = 2,
					MaxRank = 1,
					Requires = { "FleetFoot" },
					Ability = "Shadowstep",
					Description = "ABILITY: Dash forward. Your next hit within 3s is a guaranteed crit.",
				},
				Lethality = {
					Name = "Lethality",
					Tier = 3,
					Column = 1,
					MaxRank = 2,
					Requires = { "Backstab" },
					Effects = { CritDamage = 0.25 },
					Description = "+25% critical damage per rank.",
				},
				Assassinate = {
					Name = "Assassinate",
					Tier = 4,
					Column = 2,
					MaxRank = 1,
					Requires = { "Lethality", "Shadowstep" },
					Flag = "Assassinate",
					Description = "Killing blows refresh Shadowstep and heal you for 10% max health.",
				},
			},
		},
	},
}
