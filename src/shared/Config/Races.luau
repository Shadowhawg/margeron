-- Character creation options: races, body, skin, hair and outfit.
--
-- Race fields:
--   Height/Width     {min, max} body scale range; the Height and Weight sliders pick inside it
--   Head             head scale
--   SkinTones        list of Color3 choices for this race
--   Features         extra parts added to the head: "PointedEars", "Tusks", "EmberEyes"
--   Bonus            stat bonus (same stat names as skills, see Stats.luau) + a description
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local HUMAN_SKIN = {
	rgb(255, 224, 196),
	rgb(241, 194, 160),
	rgb(224, 172, 128),
	rgb(198, 134, 90),
	rgb(160, 102, 64),
	rgb(120, 76, 48),
	rgb(86, 54, 36),
	rgb(60, 40, 28),
}

return {
	Order = { "Riverfolk", "Highlander", "Sylvan", "Ironblood", "Deepkin", "Cindertouched" },

	Races = {
		Riverfolk = {
			Name = "Riverfolk",
			Description = "Common folk of the river valleys. Quick to learn, slow to quit.",
			Height = { 0.95, 1.08 },
			Width = { 0.9, 1.1 },
			Head = 1,
			SkinTones = HUMAN_SKIN,
			Features = {},
			Bonus = { XPBonus = 0.1 },
			BonusText = "Adaptable: +10% experience",
		},
		Highlander = {
			Name = "Highlander",
			Description = "Broad-shouldered mountain clans who laugh at the cold.",
			Height = { 1.02, 1.15 },
			Width = { 1, 1.2 },
			Head = 1,
			SkinTones = { rgb(250, 228, 210), rgb(236, 205, 180), rgb(220, 180, 150), rgb(196, 150, 118) },
			Features = {},
			Bonus = { DamageReduction = 0.08 },
			BonusText = "Hardy: take 8% less damage",
		},
		Sylvan = {
			Name = "Sylvan",
			Description = "Tall, long-lived forest kin with old magic in their blood.",
			Height = { 1.05, 1.18 },
			Width = { 0.82, 0.95 },
			Head = 0.95,
			SkinTones = {
				rgb(244, 232, 210),
				rgb(226, 214, 170),
				rgb(200, 190, 160),
				rgb(170, 180, 190),
				rgb(140, 120, 100),
			},
			Features = { "PointedEars" },
			Bonus = { SpellPower = 0.12 },
			BonusText = "Arcane Blood: +12% spell power",
		},
		Ironblood = {
			Name = "Ironblood",
			Description = "Fierce, proud and strong. Ironblood warriors are feared across Margeron.",
			Height = { 1.04, 1.16 },
			Width = { 1.12, 1.3 },
			Head = 1.05,
			SkinTones = { rgb(130, 150, 100), rgb(110, 130, 85), rgb(90, 110, 75), rgb(120, 120, 110), rgb(95, 95, 90) },
			Features = { "Tusks" },
			Bonus = { PhysicalDamage = 0.1 },
			BonusText = "Bloodrage: +10% weapon damage",
		},
		Deepkin = {
			Name = "Deepkin",
			Description = "Stout delvers of the deep halls. Hard to kill, harder to cheat.",
			Height = { 0.78, 0.88 },
			Width = { 1.15, 1.32 },
			Head = 1.08,
			SkinTones = { rgb(240, 210, 185), rgb(220, 180, 150), rgb(190, 145, 110), rgb(150, 105, 75) },
			Features = {},
			Bonus = { MaxHealth = 20, GoldFind = 0.1 },
			BonusText = "Stoneborn: +20 max health, +10% gold",
		},
		Cindertouched = {
			Name = "Cindertouched",
			Description = "Marked by the old fire. Ash in the skin, embers behind the eyes.",
			Height = { 0.96, 1.1 },
			Width = { 0.9, 1.08 },
			Head = 1,
			SkinTones = { rgb(90, 85, 85), rgb(70, 64, 64), rgb(120, 105, 100), rgb(150, 120, 110), rgb(50, 46, 48) },
			Features = { "EmberEyes" },
			Bonus = { CritChance = 0.06 },
			BonusText = "Ember Heart: +6% critical chance",
		},
	},

	Genders = { "Male", "Female" },

	Hair = {
		Order = { "Bald", "Short", "Swept", "Long", "Ponytail", "Braids", "Topknot", "Mohawk", "Wild" },
		-- AccessoryId: optional Roblox catalog hair accessory id to use instead of the part-built style.
		Styles = {
			Bald = { Name = "Bald" },
			Short = { Name = "Short" },
			Swept = { Name = "Swept Back" },
			Long = { Name = "Long" },
			Ponytail = { Name = "Ponytail" },
			Braids = { Name = "Twin Braids" },
			Topknot = { Name = "Topknot" },
			Mohawk = { Name = "Mohawk" },
			Wild = { Name = "Wild" },
		},
	},

	Beards = {
		Order = { "None", "Stubble", "Short", "Full", "Braided" },
		Styles = {
			None = { Name = "None" },
			Stubble = { Name = "Stubble" },
			Short = { Name = "Short Beard" },
			Full = { Name = "Full Beard" },
			Braided = { Name = "Braided Beard" },
		},
	},

	HairColors = {
		rgb(20, 18, 18),
		rgb(60, 40, 28),
		rgb(110, 70, 40),
		rgb(160, 110, 60),
		rgb(220, 180, 110),
		rgb(240, 225, 190),
		rgb(160, 50, 30),
		rgb(200, 200, 205),
		rgb(60, 70, 120),
		rgb(90, 140, 80),
	},

	-- Tunic and trouser colors (body colors stand in for clothing).
	Outfits = {
		{ Name = "Traveler", Tunic = rgb(110, 80, 55), Trousers = rgb(60, 50, 40) },
		{ Name = "Forest", Tunic = rgb(60, 90, 55), Trousers = rgb(70, 55, 40) },
		{ Name = "River", Tunic = rgb(60, 85, 120), Trousers = rgb(50, 50, 60) },
		{ Name = "Crimson", Tunic = rgb(130, 35, 40), Trousers = rgb(45, 35, 35) },
		{ Name = "Ash", Tunic = rgb(70, 70, 75), Trousers = rgb(35, 35, 40) },
		{ Name = "Linen", Tunic = rgb(215, 200, 170), Trousers = rgb(110, 90, 70) },
		{ Name = "Royal", Tunic = rgb(80, 50, 120), Trousers = rgb(50, 40, 60) },
		{ Name = "Ember", Tunic = rgb(170, 90, 40), Trousers = rgb(60, 40, 30) },
	},

	Default = {
		Created = false,
		Race = "Riverfolk",
		Gender = "Male",
		Height = 0.5,
		Weight = 0.5,
		SkinTone = 3,
		Hair = "Short",
		HairColor = 2,
		Beard = "None",
		Outfit = 1,
	},
}
