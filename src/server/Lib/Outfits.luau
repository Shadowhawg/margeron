-- What people wear. Named NPCs have a costume that says who they are; townsfolk are dressed at
-- random from a peasant palette; humanoid enemies get gear that matches their faction.
-- Field reference: ModelBuilder.Clothe.
local Outfits = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local SKIN = {
	rgb(245, 210, 185),
	rgb(234, 192, 160),
	rgb(205, 160, 120),
	rgb(160, 110, 80),
	rgb(110, 75, 55),
}
local HAIR = {
	rgb(35, 25, 20),
	rgb(70, 45, 30),
	rgb(120, 80, 45),
	rgb(190, 150, 90),
	rgb(150, 60, 35),
	rgb(200, 200, 200),
}
local WHITE_HAIR = rgb(225, 225, 220)
local LEATHER = rgb(95, 65, 40)
local DARK_LEATHER = rgb(55, 38, 28)

Outfits.NPC = {
	Elder = {
		Skin = SKIN[2],
		Robe = rgb(110, 95, 75),
		Trim = rgb(170, 140, 80),
		Mantle = rgb(80, 70, 55),
		Hair = WHITE_HAIR,
		HairStyle = "Long",
		Beard = WHITE_HAIR,
		BeardStyle = "Long",
	},
	Blacksmith = {
		Skin = SKIN[3],
		Top = rgb(70, 65, 60),
		Sleeves = SKIN[3], -- bare, soot-dark forearms
		Bottom = rgb(55, 45, 38),
		Apron = DARK_LEATHER,
		HairStyle = "Bald",
		Beard = rgb(60, 35, 25),
		BeardStyle = "Long",
	},
	Hunter = {
		Skin = SKIN[3],
		Top = rgb(70, 95, 55),
		Bottom = rgb(80, 65, 45),
		Boots = DARK_LEATHER,
		Hat = "Hood",
		HatColor = rgb(50, 70, 45),
		Cloak = rgb(50, 70, 45),
		Belt = LEATHER,
	},
	Mystic = {
		Skin = SKIN[4],
		Robe = rgb(90, 55, 110),
		Trim = rgb(200, 170, 90),
		Hat = "Hood",
		HatColor = rgb(70, 40, 90),
		Hair = rgb(30, 25, 30),
		HairStyle = "Long",
	},
	Trader = {
		Skin = SKIN[2],
		Top = rgb(130, 45, 50),
		Bottom = rgb(70, 55, 45),
		Hem = 0.9,
		Hat = "Wide",
		HatColor = rgb(80, 55, 40),
		Hair = HAIR[2],
		Beard = HAIR[2],
	},
	Herald = {
		Skin = SKIN[1],
		Top = rgb(60, 60, 70),
		Bottom = rgb(45, 45, 55),
		Tabard = rgb(40, 70, 130),
		TabardTrim = rgb(220, 185, 80),
		Hat = "Cap",
		HatColor = rgb(40, 70, 130),
		Hair = HAIR[4],
	},
	Chancellor = {
		Skin = SKIN[1],
		Robe = rgb(120, 30, 50),
		Trim = rgb(220, 185, 90),
		Mantle = rgb(235, 230, 220), -- ermine
		Hair = rgb(60, 40, 30),
		HairStyle = "Bun",
	},
	Armorer = {
		Skin = SKIN[4],
		Top = rgb(85, 85, 95),
		Sleeves = SKIN[4],
		Bottom = rgb(50, 50, 55),
		Apron = DARK_LEATHER,
		HairStyle = "Bald",
		Beard = rgb(40, 30, 25),
	},
	Archmage = {
		Skin = SKIN[2],
		Robe = rgb(55, 45, 120),
		Trim = rgb(210, 200, 255),
		Hat = "Pointed",
		HatColor = rgb(45, 35, 100),
		Hair = WHITE_HAIR,
		HairStyle = "Long",
		Beard = WHITE_HAIR,
		BeardStyle = "Long",
	},
	Innkeeper = {
		Skin = SKIN[3],
		Top = rgb(200, 185, 150),
		Bottom = rgb(90, 70, 50),
		Apron = rgb(235, 230, 215),
		HairStyle = "Bald",
		Beard = rgb(120, 80, 45),
	},
	LandSteward = {
		Skin = SKIN[2],
		Top = rgb(70, 90, 70),
		Bottom = rgb(85, 70, 50),
		Hem = 1.1,
		Hat = "Cap",
		HatColor = rgb(50, 60, 45),
		Hair = HAIR[3],
	},
	Farmer = {
		Skin = SKIN[3],
		Top = rgb(200, 185, 150),
		Bottom = rgb(100, 80, 55),
		Hat = "Straw",
		Hair = rgb(150, 150, 145),
		Beard = rgb(150, 150, 145),
	},
	Stablemaster = {
		Skin = SKIN[4],
		Top = rgb(110, 60, 45),
		Bottom = rgb(160, 135, 100),
		Boots = DARK_LEATHER,
		Hair = HAIR[1],
		HairStyle = "Bun",
	},
}

Outfits.Enemy = {
	Bandit = {
		Skin = SKIN[3],
		Top = rgb(110, 40, 35),
		Bottom = rgb(60, 45, 35),
		Hat = "Hood",
		HatColor = rgb(45, 35, 30),
		Belt = DARK_LEATHER,
	},
	BanditChief = {
		Skin = SKIN[3],
		Top = rgb(90, 20, 20),
		Bottom = rgb(50, 35, 30),
		Mantle = rgb(110, 90, 70), -- wolf fur
		Cloak = rgb(70, 20, 20),
		Hat = "Helmet",
		HatColor = rgb(90, 85, 80),
		Beard = rgb(80, 40, 25),
	},
	AshenAcolyte = {
		Skin = rgb(170, 160, 150),
		Robe = rgb(85, 80, 80),
		Trim = rgb(200, 90, 40),
		Hat = "Hood",
		HatColor = rgb(55, 50, 50),
	},
	Corvin = {
		Skin = SKIN[1],
		Top = rgb(40, 30, 35),
		Bottom = rgb(30, 25, 28),
		Cloak = rgb(90, 20, 30),
		Mantle = rgb(60, 50, 50),
		Trim = rgb(200, 150, 60),
		Hair = rgb(200, 195, 190),
		HairStyle = "Long",
	},
}

local TOPS = {
	rgb(120, 85, 60),
	rgb(85, 100, 70),
	rgb(110, 60, 55),
	rgb(70, 80, 110),
	rgb(190, 175, 140),
	rgb(95, 75, 95),
	rgb(150, 110, 70),
	rgb(60, 70, 60),
	rgb(160, 70, 50),
}
local BOTTOMS = { rgb(70, 55, 40), rgb(55, 50, 45), rgb(90, 75, 55), rgb(45, 45, 55), rgb(110, 95, 70) }
local DRESSES = { rgb(140, 60, 60), rgb(70, 90, 120), rgb(110, 120, 80), rgb(150, 120, 90), rgb(120, 85, 120) }
local HATS = { "Cap", "Wide", "Straw", "Hood" }

-- A random commoner. rng: Random
function Outfits.Townsfolk(rng)
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local o = {
		Skin = pick(SKIN),
		Hair = pick(HAIR),
		HairStyle = pick({ "Short", "Short", "Long", "Bun", "Bald" }),
		Boots = rng:NextNumber() < 0.5 and DARK_LEATHER or LEATHER,
	}
	if rng:NextNumber() < 0.4 then
		-- Long dress, often with an apron and kerchief.
		o.Robe = pick(DRESSES)
		o.Belt = false
		o.HairStyle = pick({ "Long", "Bun" })
		if rng:NextNumber() < 0.5 then
			o.Apron = rgb(230, 225, 210)
		end
		if rng:NextNumber() < 0.3 then
			o.Hat = "Hood"
			o.HatColor = pick(DRESSES):Lerp(Color3.new(1, 1, 1), 0.3)
		end
	else
		o.Top = pick(TOPS)
		o.Bottom = pick(BOTTOMS)
		if rng:NextNumber() < 0.5 then
			o.Hem = rng:NextNumber(0.6, 1.2)
		end
		if rng:NextNumber() < 0.4 then
			o.Beard = o.Hair
			o.BeardStyle = rng:NextNumber() < 0.3 and "Long" or "Short"
		end
		if rng:NextNumber() < 0.15 then
			o.Apron = DARK_LEATHER
			o.Sleeves = o.Skin
		end
	end
	if not o.Hat and rng:NextNumber() < 0.35 then
		o.Hat = pick(HATS)
		o.HatColor = pick(BOTTOMS)
	end
	if rng:NextNumber() < 0.12 then
		o.Cloak = pick(TOPS)
	end
	return o
end

return Outfits
