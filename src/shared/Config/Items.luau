-- Every item in the game. Add new weapons/cosmetics/materials here and they show up automatically
-- in shops, inventory and quest rewards.
--
-- Weapon fields:
--   Type        Sword | Axe | Dagger | Staff (Staff attacks are ranged bolts and scale with Spell Power)
--   Damage      base damage per hit
--   Cooldown    seconds between attacks
--   Range       melee reach, or bolt range for staves
--   CritBonus   extra crit chance (0.1 = +10%)
--   Price       gold cost at the blacksmith (nil = not sold for gold)
--   LevelReq    level needed to buy/equip
--   Premium     key into Config/Products (Robux unlock)
local Items = {}

Items.Weapons = {
	IronSword = {
		Name = "Iron Sword",
		Type = "Sword",
		Damage = 12,
		Cooldown = 0.6,
		Range = 7,
		LevelReq = 1,
		Color = Color3.fromRGB(150, 150, 155),
		Description = "Standard issue. Reliable, if unremarkable.",
	},
	ApprenticeStaff = {
		Name = "Apprentice Staff",
		Type = "Staff",
		Damage = 11,
		Cooldown = 0.8,
		Range = 45,
		Price = 120,
		LevelReq = 2,
		Color = Color3.fromRGB(110, 170, 255),
		Description = "Hurls arcane bolts. Scales with Spell Power.",
	},
	SteelSword = {
		Name = "Steel Sword",
		Type = "Sword",
		Damage = 17,
		Cooldown = 0.6,
		Range = 7,
		Price = 200,
		LevelReq = 3,
		Color = Color3.fromRGB(200, 205, 215),
		Description = "Brann's own work. Holds an edge.",
	},
	HuntersKnife = {
		Name = "Hunter's Knife",
		Type = "Dagger",
		Damage = 10,
		Cooldown = 0.35,
		Range = 5.5,
		CritBonus = 0.1,
		Price = 250,
		LevelReq = 4,
		Color = Color3.fromRGB(120, 90, 60),
		Description = "Fast and precise. +10% crit chance.",
	},
	NorthernWarAxe = {
		Name = "Northern War Axe",
		Type = "Axe",
		Damage = 30,
		Cooldown = 1.05,
		Range = 8,
		Price = 450,
		LevelReq = 6,
		Color = Color3.fromRGB(90, 95, 100),
		Description = "Slow, brutal, satisfying.",
	},
	RunedStaff = {
		Name = "Runed Staff",
		Type = "Staff",
		Damage = 22,
		Cooldown = 0.8,
		Range = 55,
		Price = 700,
		LevelReq = 9,
		Color = Color3.fromRGB(170, 110, 255),
		Description = "Carved with old wards. Scales with Spell Power.",
	},
	OrcishBlade = {
		Name = "Ironbark Greatblade",
		Type = "Sword",
		Damage = 34,
		Cooldown = 0.75,
		Range = 8,
		Price = 1200,
		LevelReq = 12,
		Color = Color3.fromRGB(70, 110, 70),
		Description = "A veteran's weapon.",
	},

	-- Premium (Robux) weapons: strong but level-gated, and no stronger than the best gold weapon
	-- for their level, so the game stays fair.
	EmberBrand = {
		Name = "Emberbrand",
		Type = "Sword",
		Damage = 20,
		Cooldown = 0.55,
		Range = 7.5,
		LevelReq = 4,
		Premium = "EmberBrand",
		Color = Color3.fromRGB(255, 120, 40),
		Glow = Color3.fromRGB(255, 90, 20),
		Description = "Forged in wyrm-fire. Leaves trails of embers.",
	},
	FrostfangStaff = {
		Name = "Frostfang Staff",
		Type = "Staff",
		Damage = 19,
		Cooldown = 0.7,
		Range = 55,
		LevelReq = 6,
		Premium = "FrostfangStaff",
		Color = Color3.fromRGB(150, 230, 255),
		Glow = Color3.fromRGB(120, 220, 255),
		Description = "Bitterly cold to the touch.",
	},
}

-- Slot: Cape | Aura | Title
Items.Cosmetics = {
	CrimsonCape = { Name = "Crimson Cape", Slot = "Cape", Color = Color3.fromRGB(150, 20, 30), Premium = "CrimsonCape" },
	ShadowCape = { Name = "Shadow Cape", Slot = "Cape", Color = Color3.fromRGB(25, 20, 35), Premium = "ShadowCape" },
	RiverwatchCape = { Name = "Riverwatch Cape", Slot = "Cape", Color = Color3.fromRGB(40, 80, 140) },
	GoldenAura = { Name = "Golden Aura", Slot = "Aura", Color = Color3.fromRGB(255, 210, 80), Premium = "GoldenAura" },
	FrostAura = { Name = "Frost Aura", Slot = "Aura", Color = Color3.fromRGB(150, 220, 255), Premium = "FrostAura" },

	TitleWyrmslayer = { Name = "Wyrmslayer", Slot = "Title" },
	TitleSellsword = { Name = "Sellsword", Slot = "Title" },
	TitleBountyHunter = { Name = "Bounty Hunter", Slot = "Title" },
	TitleWarden = { Name = "Warden of Riverwatch", Slot = "Title" },
	TitleLegend = { Name = "Legend of Margeron", Slot = "Title" },
	TitleFounder = { Name = "Founder", Slot = "Title", Premium = "FounderTitle" },
}

Items.Materials = {
	WolfPelt = { Name = "Wolf Pelt" },
	BanditInsignia = { Name = "Redfang Insignia" },
	BoneDust = { Name = "Bone Dust" },
	TrollFat = { Name = "Troll Fat" },
	WyrmScale = { Name = "Ashen Wyrm Scale" },
}

function Items.GetWeapon(id)
	return Items.Weapons[id]
end

function Items.GetCosmetic(id)
	return Items.Cosmetics[id]
end

return Items
