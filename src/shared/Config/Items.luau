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

	-- Crafted at the forge (see Config/Crafting)
	SilversteelBlade = {
		Name = "Silversteel Blade",
		Type = "Sword",
		Damage = 26,
		Cooldown = 0.6,
		Range = 7.5,
		LevelReq = 8,
		Crafted = true,
		Color = Color3.fromRGB(225, 230, 240),
		Description = "Light, bright and very sharp.",
	},
	BonecarverAxe = {
		Name = "Bonecarver Axe",
		Type = "Axe",
		Damage = 40,
		Cooldown = 1.05,
		Range = 8,
		LevelReq = 9,
		Crafted = true,
		Color = Color3.fromRGB(215, 205, 180),
		Description = "Hollow Dead bone, bound in iron.",
	},
	WyrmfangDagger = {
		Name = "Wyrmfang Dagger",
		Type = "Dagger",
		Damage = 19,
		Cooldown = 0.35,
		Range = 6,
		CritBonus = 0.15,
		LevelReq = 10,
		Crafted = true,
		Color = Color3.fromRGB(90, 70, 60),
		Glow = Color3.fromRGB(255, 120, 50),
		Description = "Still warm. +15% crit chance.",
	},
	MarshwoodStaff = {
		Name = "Marshwood Staff",
		Type = "Staff",
		Damage = 27,
		Cooldown = 0.75,
		Range = 55,
		LevelReq = 10,
		Crafted = true,
		Color = Color3.fromRGB(110, 200, 120),
		Description = "Grown, not carved. Scales with Spell Power.",
	},
	SentinelGreatblade = {
		Name = "Sentinel Greatblade",
		Type = "Sword",
		Damage = 42,
		Cooldown = 0.75,
		Range = 8.5,
		LevelReq = 14,
		Crafted = true,
		Color = Color3.fromRGB(150, 170, 200),
		Glow = Color3.fromRGB(120, 180, 255),
		Description = "Forged around a Sentinel's heart. It hums.",
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
	WovenCapeRed = { Name = "Woven Cape (Crimson)", Slot = "Cape", Color = Color3.fromRGB(170, 40, 45) },
	WovenCapeBlue = { Name = "Woven Cape (Moonlit)", Slot = "Cape", Color = Color3.fromRGB(70, 90, 170) },
	WovenCapeGreen = { Name = "Woven Cape (Fen)", Slot = "Cape", Color = Color3.fromRGB(70, 120, 70) },
	WovenCapeWhite = { Name = "Woven Cape (Frost)", Slot = "Cape", Color = Color3.fromRGB(230, 235, 240) },
	WovenCapeAmber = { Name = "Woven Cape (Ember)", Slot = "Cape", Color = Color3.fromRGB(210, 120, 40) },
	GoldenAura = { Name = "Golden Aura", Slot = "Aura", Color = Color3.fromRGB(255, 210, 80), Premium = "GoldenAura" },
	FrostAura = { Name = "Frost Aura", Slot = "Aura", Color = Color3.fromRGB(150, 220, 255), Premium = "FrostAura" },

	TitleWyrmslayer = { Name = "Wyrmslayer", Slot = "Title" },
	TitleSellsword = { Name = "Sellsword", Slot = "Title" },
	TitleBountyHunter = { Name = "Bounty Hunter", Slot = "Title" },
	TitleWarden = { Name = "Warden of Riverwatch", Slot = "Title" },
	TitleUnforgotten = { Name = "The Unforgotten", Slot = "Title" },
	TitleLegend = { Name = "Legend of Margeron", Slot = "Title" },
	TitleFounder = { Name = "Founder", Slot = "Title", Premium = "FounderTitle" },
	TitleExplorer = { Name = "Pathfinder", Slot = "Title" },
}

-- Materials: everything you can carry and stack.
--   Category  Monster | Herb | Ore | Ingot | Crop | Seed | Animal | Crafted
--   Value     gold a merchant pays for one
--   Effects   alchemy effects (Config/Crafting.Effects), in discovery order. Ingredients need 3.
Items.Materials = {
	-- Monster parts
	WolfPelt = { Name = "Wolf Pelt", Category = "Monster", Value = 4 },
	BanditInsignia = { Name = "Redfang Insignia", Category = "Monster", Value = 6 },
	AshenSigil = { Name = "Ashen Hand Sigil", Category = "Monster", Value = 18 },
	BoneDust = {
		Name = "Bone Dust",
		Category = "Monster",
		Value = 8,
		Effects = { "Precision", "Insight", "Resistance" },
	},
	TrollFat = {
		Name = "Troll Fat",
		Category = "Monster",
		Value = 15,
		Effects = { "Regeneration", "Vigor", "Resistance" },
	},
	WyrmScale = {
		Name = "Ashen Wyrm Scale",
		Category = "Monster",
		Value = 60,
		Effects = { "FortifyDamage", "Resistance", "Fortune" },
	},
	BogHeart = {
		Name = "Bog Heart",
		Category = "Monster",
		Value = 14,
		Effects = { "Regeneration", "Swiftness", "Insight" },
	},
	SentinelCore = {
		Name = "Sentinel Core",
		Category = "Monster",
		Value = 30,
		Effects = { "FortifySpell", "Precision", "Vigor" },
	},

	-- Herbs (gathered in the wild; some can be farmed)
	Moonpetal = {
		Name = "Moonpetal",
		Category = "Herb",
		Value = 6,
		Effects = { "RestoreHealth", "FortifySpell", "Insight" },
	},
	Bloodthistle = {
		Name = "Bloodthistle",
		Category = "Herb",
		Value = 5,
		Effects = { "RestoreHealth", "FortifyDamage", "Vigor" },
	},
	Frostcap = {
		Name = "Frostcap",
		Category = "Herb",
		Value = 9,
		Effects = { "Resistance", "FortifySpell", "Precision" },
	},
	Emberroot = {
		Name = "Emberroot",
		Category = "Herb",
		Value = 14,
		Effects = { "FortifyDamage", "Swiftness", "Fortune" },
	},
	Bogbloom = {
		Name = "Bogbloom",
		Category = "Herb",
		Value = 8,
		Effects = { "Regeneration", "Resistance", "Insight" },
	},
	Riverreed = {
		Name = "Riverreed",
		Category = "Herb",
		Value = 3,
		Effects = { "Swiftness", "Regeneration", "RestoreHealth" },
	},

	-- Ore and metal
	IronOre = { Name = "Iron Ore", Category = "Ore", Value = 5 },
	SilverOre = { Name = "Silver Ore", Category = "Ore", Value = 12 },
	IronIngot = { Name = "Iron Ingot", Category = "Ingot", Value = 14 },
	SilverIngot = { Name = "Silver Ingot", Category = "Ingot", Value = 30 },

	-- Farming
	Wheat = { Name = "Wheat", Category = "Crop", Value = 3 },
	Carrot = { Name = "Carrot", Category = "Crop", Value = 4 },
	Potato = { Name = "Potato", Category = "Crop", Value = 4 },
	WheatSeeds = { Name = "Wheat Seeds", Category = "Seed", Value = 2 },
	CarrotSeeds = { Name = "Carrot Seeds", Category = "Seed", Value = 3 },
	PotatoSeeds = { Name = "Potato Seeds", Category = "Seed", Value = 3 },
	MoonpetalSeeds = { Name = "Moonpetal Seeds", Category = "Seed", Value = 7 },
	EmberrootSeeds = { Name = "Emberroot Seeds", Category = "Seed", Value = 20 },

	-- Livestock goods
	Egg = { Name = "Egg", Category = "Animal", Value = 4 },
	Milk = { Name = "Milk", Category = "Animal", Value = 7 },
	Wool = { Name = "Wool", Category = "Animal", Value = 9 },

	-- Crafted goods
	Fertilizer = { Name = "Fertilizer", Category = "Crafted", Value = 6 },
	Leather = { Name = "Leather", Category = "Crafted", Value = 12 },
}

function Items.GetWeapon(id)
	return Items.Weapons[id]
end

function Items.GetCosmetic(id)
	return Items.Cosmetics[id]
end

return Items
