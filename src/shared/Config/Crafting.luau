-- Crafting: four stations, one system.
--
--   Forge         smelt ore, forge weapons, Temper (+damage levels) and Infuse (one special effect per weapon)
--   AlchemyTable  mix any 2-3 ingredients; effects shared by at least two of them become a potion.
--                 Discover what ingredients do by experimenting (or by tasting them).
--   CookingPot    turn crops and animal goods into food with long-lasting buffs
--   Workbench     fertilizer, leather, dyed capes
--
-- Crafting has its own level. Higher levels unlock recipes and make potions stronger.
local Crafting = {}

Crafting.MaxLevel = 30

function Crafting.XPToNext(level)
	return math.floor(60 * level ^ 1.4)
end

-- Potion/food effects. Magnitude scales with potency tier: Base * (1 + 0.25 * (tier - 1)).
--   Stat    the stat a buff adds to (see Stats.luau); Instant effects apply once instead
Crafting.Effects = {
	RestoreHealth = { Name = "Restore Health", Instant = true, Base = 45, Description = "Heals {m} health" },
	Regeneration = {
		Name = "Regeneration",
		Stat = "Regeneration",
		Base = 3,
		Duration = 30,
		Description = "Heal {m} health per second",
	},
	FortifyDamage = {
		Name = "Fortify Strength",
		Stat = "PhysicalDamage",
		Base = 0.15,
		Duration = 120,
		Percent = true,
		Description = "+{m} weapon damage",
	},
	FortifySpell = {
		Name = "Fortify Magic",
		Stat = "SpellPower",
		Base = 0.15,
		Duration = 120,
		Percent = true,
		Description = "+{m} spell power",
	},
	Swiftness = {
		Name = "Swiftness",
		Stat = "WalkSpeed",
		Base = 4,
		Duration = 120,
		Description = "+{m} movement speed",
	},
	Resistance = {
		Name = "Resistance",
		Stat = "DamageReduction",
		Base = 0.1,
		Duration = 120,
		Percent = true,
		Description = "Take {m} less damage",
	},
	Precision = {
		Name = "Precision",
		Stat = "CritChance",
		Base = 0.08,
		Duration = 120,
		Percent = true,
		Description = "+{m} critical chance",
	},
	Fortune = {
		Name = "Fortune",
		Stat = "GoldFind",
		Base = 0.25,
		Duration = 300,
		Percent = true,
		Description = "+{m} gold from enemies",
	},
	Insight = {
		Name = "Insight",
		Stat = "XPBonus",
		Base = 0.2,
		Duration = 300,
		Percent = true,
		Description = "+{m} experience",
	},
	Vigor = { Name = "Vigor", Stat = "MaxHealth", Base = 25, Duration = 300, Description = "+{m} max health" },
}

-- Potency tier from crafting level (and the Master Artisan pass).
function Crafting.PotencyTier(craftLevel, hasMasterPass)
	return math.min(5, 1 + math.floor(craftLevel / 6) + (hasMasterPass and 1 or 0))
end

function Crafting.Magnitude(effectId, tier)
	return Crafting.Effects[effectId].Base * (1 + 0.25 * (tier - 1))
end

function Crafting.Duration(effectId, tier, durationOverride)
	local effect = Crafting.Effects[effectId]
	return (durationOverride or effect.Duration or 0) * (1 + 0.2 * (tier - 1))
end

function Crafting.Describe(effectId, tier)
	local effect = Crafting.Effects[effectId]
	local m = Crafting.Magnitude(effectId, tier)
	local text = effect.Percent and (math.floor(m * 100 + 0.5) .. "%") or tostring(math.floor(m + 0.5))
	return (effect.Description:gsub("{m}", text))
end

-- Standard recipes. Inputs and outputs are Config/Items material ids.
-- Output: { Material = id, Count = n } | { Weapon = id } | { Cosmetic = id } | { Food = id }
Crafting.Recipes = {
	-- Forge: smelting
	{
		Id = "SmeltIron",
		Station = "Forge",
		Name = "Iron Ingot",
		Inputs = { IronOre = 2 },
		Output = { Material = "IronIngot", Count = 1 },
		Level = 1,
		XP = 6,
	},
	{
		Id = "SmeltSilver",
		Station = "Forge",
		Name = "Silver Ingot",
		Inputs = { SilverOre = 2 },
		Output = { Material = "SilverIngot", Count = 1 },
		Level = 4,
		XP = 10,
	},
	-- Forge: weapons
	{
		Id = "ForgeSilversteel",
		Station = "Forge",
		Name = "Silversteel Blade",
		Inputs = { SilverIngot = 3, IronIngot = 2 },
		Output = { Weapon = "SilversteelBlade" },
		Level = 6,
		XP = 60,
	},
	{
		Id = "ForgeBonecarver",
		Station = "Forge",
		Name = "Bonecarver Axe",
		Inputs = { IronIngot = 4, BoneDust = 6 },
		Output = { Weapon = "BonecarverAxe" },
		Level = 8,
		XP = 70,
	},
	{
		Id = "ForgeWyrmfang",
		Station = "Forge",
		Name = "Wyrmfang Dagger",
		Inputs = { WyrmScale = 2, SilverIngot = 2 },
		Output = { Weapon = "WyrmfangDagger" },
		Level = 10,
		XP = 90,
	},
	{
		Id = "ForgeMarshwood",
		Station = "Forge",
		Name = "Marshwood Staff",
		Inputs = { Bogbloom = 5, BogHeart = 2, SilverIngot = 1 },
		Output = { Weapon = "MarshwoodStaff" },
		Level = 10,
		XP = 90,
	},
	{
		Id = "ForgeSentinel",
		Station = "Forge",
		Name = "Sentinel Greatblade",
		Inputs = { SentinelCore = 3, SilverIngot = 4, IronIngot = 4 },
		Output = { Weapon = "SentinelGreatblade" },
		Level = 14,
		XP = 150,
	},

	-- Workbench
	{
		Id = "Fertilizer",
		Station = "Workbench",
		Name = "Fertilizer (x2)",
		Inputs = { BoneDust = 1, Wheat = 2 },
		Output = { Material = "Fertilizer", Count = 2 },
		Level = 1,
		XP = 5,
	},
	{
		Id = "Leather",
		Station = "Workbench",
		Name = "Leather",
		Inputs = { WolfPelt = 2 },
		Output = { Material = "Leather", Count = 1 },
		Level = 1,
		XP = 5,
	},
	{
		Id = "CapeRed",
		Station = "Workbench",
		Name = "Woven Cape (Crimson)",
		Inputs = { Wool = 4, Leather = 1, Bloodthistle = 2 },
		Output = { Cosmetic = "WovenCapeRed" },
		Level = 3,
		XP = 30,
	},
	{
		Id = "CapeBlue",
		Station = "Workbench",
		Name = "Woven Cape (Moonlit)",
		Inputs = { Wool = 4, Leather = 1, Moonpetal = 2 },
		Output = { Cosmetic = "WovenCapeBlue" },
		Level = 3,
		XP = 30,
	},
	{
		Id = "CapeGreen",
		Station = "Workbench",
		Name = "Woven Cape (Fen)",
		Inputs = { Wool = 4, Leather = 1, Bogbloom = 2 },
		Output = { Cosmetic = "WovenCapeGreen" },
		Level = 5,
		XP = 30,
	},
	{
		Id = "CapeWhite",
		Station = "Workbench",
		Name = "Woven Cape (Frost)",
		Inputs = { Wool = 4, Leather = 1, Frostcap = 2 },
		Output = { Cosmetic = "WovenCapeWhite" },
		Level = 7,
		XP = 30,
	},
	{
		Id = "CapeAmber",
		Station = "Workbench",
		Name = "Woven Cape (Ember)",
		Inputs = { Wool = 4, Leather = 1, Emberroot = 2 },
		Output = { Cosmetic = "WovenCapeAmber" },
		Level = 9,
		XP = 30,
	},

	-- Cooking pot
	{
		Id = "Bread",
		Station = "CookingPot",
		Name = "Bread",
		Inputs = { Wheat = 3 },
		Output = { Food = "Bread" },
		Level = 1,
		XP = 6,
	},
	{
		Id = "Stew",
		Station = "CookingPot",
		Name = "Hearty Stew",
		Inputs = { Carrot = 2, Potato = 2 },
		Output = { Food = "Stew" },
		Level = 2,
		XP = 10,
	},
	{
		Id = "Omelette",
		Station = "CookingPot",
		Name = "Herb Omelette",
		Inputs = { Egg = 2, Milk = 1, Moonpetal = 1 },
		Output = { Food = "Omelette" },
		Level = 3,
		XP = 12,
	},
	{
		Id = "MilkBun",
		Station = "CookingPot",
		Name = "Sweet Milk Bun",
		Inputs = { Wheat = 2, Egg = 1, Milk = 1 },
		Output = { Food = "MilkBun" },
		Level = 4,
		XP = 12,
	},
	{
		Id = "FireChili",
		Station = "CookingPot",
		Name = "Emberroot Chili",
		Inputs = { Emberroot = 2, Potato = 2, Carrot = 1 },
		Output = { Food = "FireChili" },
		Level = 6,
		XP = 16,
	},
	{
		Id = "Feast",
		Station = "CookingPot",
		Name = "Riverwatch Feast",
		Inputs = { Wheat = 3, Potato = 2, Carrot = 2, Milk = 2, Egg = 2 },
		Output = { Food = "Feast" },
		Level = 8,
		XP = 30,
	},
}

-- Foods: always tier 1 magnitude, but they last much longer than potions.
Crafting.Foods = {
	Bread = { Name = "Bread", Effects = { RestoreHealth = 0, Vigor = 600 }, Value = 12 },
	Stew = { Name = "Hearty Stew", Effects = { Regeneration = 600, Vigor = 600 }, Value = 30 },
	Omelette = { Name = "Herb Omelette", Effects = { Insight = 900 }, Value = 35 },
	MilkBun = { Name = "Sweet Milk Bun", Effects = { Fortune = 900 }, Value = 35 },
	FireChili = { Name = "Emberroot Chili", Effects = { FortifyDamage = 600, Swiftness = 600 }, Value = 50 },
	Feast = {
		Name = "Riverwatch Feast",
		Effects = { Vigor = 1200, Regeneration = 1200, Insight = 1200, Fortune = 1200 },
		Value = 120,
	},
}

-- Tempering: each level adds DamagePerLevel to the weapon.
Crafting.Temper = {
	MaxLevel = 5,
	DamagePerLevel = 0.08,
	-- cost to go from level-1 to level
	Cost = function(level)
		return {
			IronIngot = level + 1,
			SilverIngot = level >= 3 and (level - 2) or nil,
			Gold = 40 * level,
		}
	end,
}

-- Infusions: one per weapon. Re-infusing replaces the old one.
Crafting.Infusions = {
	Ember = {
		Name = "Ember",
		Description = "Hits set enemies ablaze (+25% damage over 3s)",
		Inputs = { WyrmScale = 1, Emberroot = 3 },
		Level = 8,
		Color = Color3.fromRGB(255, 110, 40),
	},
	Frost = {
		Name = "Frost",
		Description = "Hits slow enemies by 35% for 2s",
		Inputs = { Frostcap = 4, SilverIngot = 1 },
		Level = 6,
		Color = Color3.fromRGB(140, 210, 255),
	},
	Venom = {
		Name = "Venom",
		Description = "Hits poison (+30% damage over 4s)",
		Inputs = { Bogbloom = 3, BoneDust = 2 },
		Level = 5,
		Color = Color3.fromRGB(110, 200, 80),
	},
	Vampiric = {
		Name = "Vampiric",
		Description = "+5% lifesteal with this weapon",
		Inputs = { TrollFat = 2, Bloodthistle = 3 },
		Level = 7,
		Color = Color3.fromRGB(170, 20, 40),
	},
	Fortune = {
		Name = "Fortune",
		Description = "+20% gold from kills with this weapon",
		Inputs = { BanditInsignia = 5, SilverIngot = 1 },
		Level = 4,
		Color = Color3.fromRGB(255, 215, 90),
	},
	Arcane = {
		Name = "Arcane",
		Description = "+15% spell power while equipped",
		Inputs = { SentinelCore = 2, Moonpetal = 3 },
		Level = 12,
		Color = Color3.fromRGB(170, 120, 255),
	},
}

Crafting.StationNames = {
	Forge = "Forge",
	AlchemyTable = "Alchemy Table",
	CookingPot = "Cooking Pot",
	Workbench = "Workbench",
}

-- Robux boosts (see Config/Products):
Crafting.BoostDoubleChance = 0.25 -- Artisan's Focus: chance to craft twice the output
Crafting.MasterDoubleChance = 0.1 -- Master Artisan pass: permanent chance to craft twice the output

return Crafting
