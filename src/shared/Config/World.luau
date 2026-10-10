-- World layout. The server generates terrain and scenery from this if Workspace has no "Map" folder.
-- When you build your own map, put a Folder named "Map" in Workspace and, inside it, a Folder named
-- "Markers" with Parts named after any NPC id (e.g. "Elder"), zone id (e.g. "WolfWoods"),
-- landmark id or plot id (e.g. "Plot1") to move them.
--
-- Coordinates: X = east/west, Z = north(-)/south(+). The map spans -MapHalfSize..MapHalfSize.
local CITY = Vector3.new(1080, 0, 180)
-- The city's main gate faces north-west (away from where the river enters the lake).
local CITY_GATE_ANGLE = math.pi + 0.61

-- City layout is written as if the gate were due west (-X); this rotates it to the real gate.
local function cityPoint(x, z)
	local g = CITY_GATE_ANGLE - math.pi
	return CITY + Vector3.new(x * math.cos(g) - z * math.sin(g), 0, x * math.sin(g) + z * math.cos(g))
end

return {
	MapHalfSize = 1800,
	WaterLevel = 0,
	Seed = 1337,

	-- Where brand-new characters wake up (the riverbank), and where everyone respawns.
	IntroPoint = Vector3.new(-40, 0, 205),
	SpawnPoint = Vector3.new(0, 0, 40),

	-- The river winds east-west south of Riverwatch: Z = Base + Amplitude * sin(X / Wavelength)
	River = { BaseZ = 170, Amplitude = 35, Wavelength = 260, Width = 18 },

	Town = {
		Name = "Riverwatch",
		Position = Vector3.new(0, 0, 0),
		Radius = 125,
	},

	-- The Crown City: a walled capital on an island in a lake, reached by a causeway from the west.
	City = {
		Name = "Aurelion",
		Title = "The Crown City",
		Position = CITY,
		Height = 8, -- island plateau height
		IslandRadius = 215,
		LakeRadius = 330,
		WallRadius = 190,
		GateAngle = CITY_GATE_ANGLE,
		Approach = cityPoint(-420, 0), -- where the causeway starts on the shore
		Point = cityPoint, -- helper for placing things in the city
	},

	-- Safe region with buyable property plots (see Config/Property).
	Farmlands = {
		Name = "Greenmeadow",
		Position = Vector3.new(60, 0, 470),
		Radius = 340,
	},

	NPCs = {
		Elder = {
			Name = "Elder Maren",
			Role = "Village Elder",
			Position = Vector3.new(0, 0, -34),
			Color = Color3.fromRGB(90, 70, 120),
			Greeting = "You again. The river gave you back to us, and I've stopped asking why.",
			Greetings = {
				{
					After = "MQ2",
					Text = "The wolves have settled since you thinned them. The children play by the river again. Thank you.",
				},
				{
					After = "MQ4",
					Text = 'Caravans are moving again. People have started calling you "the river-born". I\'d get used to it.',
				},
				{
					After = "MQ6",
					Text = "Wyrmslayer. I still can't quite believe it. Sit, if you like. You never sit.",
				},
				{
					After = "MQ8",
					Text = "The ash has stopped falling. Some mornings I catch you staring east, like you're listening for something. Is it gone, then?",
				},
			},
		},
		Blacksmith = {
			Name = "Brann",
			Role = "Blacksmith",
			Position = Vector3.new(38, 0, -6),
			Color = Color3.fromRGB(110, 70, 40),
			Greeting = "Need an edge? Or need one sharpened? Either way, mind the sparks.",
			Greetings = {
				{ After = "MQ3", Text = "Blade holding up? Course it is. I made it." },
				{
					After = "MQ6",
					Text = 'They\'re singing songs about you in the tavern. Terrible songs. The one about the wyrm rhymes "scale" with "ale" four times.',
				},
			},
		},
		Hunter = {
			Name = "Ysolde",
			Role = "Hunter",
			Position = Vector3.new(-40, 0, 4),
			Color = Color3.fromRGB(60, 100, 50),
			Greeting = "Quiet. You'll scare the deer. ...What do you want?",
		},
		Mystic = {
			Name = "Seer Ilsa",
			Role = "Mystic & Alchemist",
			Position = Vector3.new(-26, 0, -40),
			Color = Color3.fromRGB(60, 90, 160),
			Greeting = "You hear it too, don't you? The voice. No, don't answer. Not here.",
			Greetings = {
				{
					After = "MQ5",
					Text = "The bones are quiet now. You are not. I can hear two heartbeats when you stand close, did you know?",
				},
				{
					After = "MQ8",
					Text = "One heartbeat now. Only one. ...Be gentle with yourself. Grief for a part of you is still grief.",
				},
			},
		},
		Trader = {
			Name = "Marta",
			Role = "General Trader",
			Position = Vector3.new(26, 0, 30),
			Color = Color3.fromRGB(150, 110, 60),
			Greeting = "Buying, selling, gossiping. Mostly gossiping. What've you got?",
		},
		Herald = {
			Name = "Herald Corwin",
			Role = "Town Hall",
			Position = Vector3.new(-48, 0, -58),
			Color = Color3.fromRGB(120, 30, 40),
			Greeting = "Hear ye. Riverwatch is governed by those it chooses. Have you come to choose, or to be chosen?",
		},
		Board = {
			Name = "Bounty Board",
			Role = "Contracts & Bounties",
			Position = Vector3.new(14, 0, 22),
			IsObject = true,
			Greeting = "Notices flap in the wind. Coin for those willing to earn it.",
		},
		Chancellor = {
			Name = "Chancellor Aurelia",
			Role = "Royal Court of Aurelion",
			Position = cityPoint(-40, 0),
			Color = Color3.fromRGB(120, 30, 50),
			Greeting = "Welcome to Aurelion. Mind the guards, mind your manners, and mind the Tower. It has been watching the east for three hundred years.",
			Greetings = {
				{
					After = "MQ4B",
					Text = "Any word of the coins? I've had the mint's ledgers pulled. Someone has been very careful.",
				},
				{
					After = "MQ7",
					Text = "I keep his letters in my desk. I've read them all twice since you brought me the sigils.",
				},
				{
					After = "MQ8",
					Text = "He was my brother, and he was afraid, and he did terrible things because of it. Thank you for ending it. I mean that.",
				},
			},
		},
		Armorer = {
			Name = "Master Davor",
			Role = "Royal Armorer",
			Position = cityPoint(-148, -32),
			Wander = 4, -- keeps close to the shop door
			Color = Color3.fromRGB(90, 90, 100),
			Shop = "Blacksmith",
			Greeting = "Crown steel. The finest in Margeron, priced accordingly.",
		},
		Archmage = {
			Name = "Archmage Selene",
			Role = "Collegium of Stars",
			Position = cityPoint(0, -128),
			Color = Color3.fromRGB(70, 60, 140),
			Shop = "Blacksmith",
			Greeting = "The stars remember everything, even what you've forgotten. Especially that, in your case.",
			Greetings = {
				{
					After = "MQ5B",
					Text = "The stars over Cinder Peak are dimmer every night. Whatever you mean to do, do it soon.",
				},
				{
					After = "MQ8",
					Text = "The seal is whole. Seven souls, at last. I won't ask whose the seventh was. I think I already know.",
				},
			},
		},
		Innkeeper = {
			Name = "Odo",
			Role = "The Gilded Stag",
			Position = cityPoint(-128, 46),
			Wander = 4, -- keeps close to the shop door
			Color = Color3.fromRGB(150, 100, 60),
			RestCost = 15,
			Greeting = "Best beds in the Crown City. Best ale too, if you ask me. Which you should.",
		},
		CityBoard = {
			Name = "Crown Notices",
			Role = "Contracts & Bounties",
			Position = cityPoint(-165, 24),
			IsObject = true,
			Alias = "Board",
			Greeting = "Royal seals on half the notices. Crown coin for those who earn it.",
		},
		LandSteward = {
			Name = "Holdsworth",
			Role = "Land Steward",
			Position = Vector3.new(30, 0, 300),
			Color = Color3.fromRGB(70, 90, 70),
			Greeting = "Land, friend. The only thing they're not making more of. Fancy a deed?",
		},
		Farmer = {
			Name = "Old Tomas",
			Role = "Farmer & Seed Seller",
			Position = Vector3.new(80, 0, 300),
			Color = Color3.fromRGB(130, 120, 70),
			Greeting = "Seeds, soil and patience. Two of those I can sell you.",
		},
		Stablemaster = {
			Name = "Rhea",
			Role = "Stablemaster",
			Position = Vector3.new(130, 0, 290),
			Color = Color3.fromRGB(100, 60, 50),
			Greeting = "Every horse here would carry you to the end of the world. Some of them would even bring you back.",
		},
	},

	-- Crafting stations in town. Players' homes add their own (see Config/Property).
	Stations = {
		{ Station = "Forge", Position = Vector3.new(46, 0, -12) },
		{ Station = "AlchemyTable", Position = Vector3.new(-32, 0, -46) },
		{ Station = "CookingPot", Position = Vector3.new(-14, 0, 34) },
		{ Station = "Workbench", Position = Vector3.new(34, 0, 38) },
		{ Station = "Forge", Position = cityPoint(-160, -44) },
		{ Station = "AlchemyTable", Position = cityPoint(16, -140) },
		{ Station = "CookingPot", Position = cityPoint(-118, 58) },
	},

	-- Combat zones. Spawns: { Enemy = Config/Enemies key, Count = how many alive at once }
	Zones = {
		WolfWoods = {
			Name = "Whisperwood",
			Levels = "1-3",
			Position = Vector3.new(560, 0, -40),
			Radius = 150,
			Material = Enum.Material.LeafyGrass,
			Biome = "Forest",
			RespawnTime = 12,
			Spawns = { { Enemy = "Wolf", Count = 12 } },
		},
		BanditCamp = {
			Name = "Redfang Camp",
			Levels = "3-5",
			Position = Vector3.new(-700, 0, 560),
			Radius = 100,
			Material = Enum.Material.Ground,
			Biome = "Camp",
			RespawnTime = 18,
			Spawns = { { Enemy = "Bandit", Count = 9 }, { Enemy = "BanditChief", Count = 1 } },
		},
		HollowCrypt = {
			Name = "Hollow Crypt",
			Levels = "6-9",
			Position = Vector3.new(220, 0, -800),
			Radius = 100,
			Material = Enum.Material.Slate,
			Biome = "Crypt",
			RespawnTime = 18,
			Spawns = { { Enemy = "Skeleton", Count = 10 }, { Enemy = "AshenAcolyte", Count = 4 } },
		},
		Mirelake = {
			Name = "Mirelake Marsh",
			Levels = "7-9",
			Position = Vector3.new(900, 0, 720),
			Radius = 160,
			Material = Enum.Material.Mud,
			Biome = "Marsh",
			RespawnTime = 18,
			Spawns = { { Enemy = "BogLurker", Count = 10 } },
		},
		CinderPeak = {
			Name = "Cinder Peak",
			Levels = "9-12 (Bosses)",
			Position = Vector3.new(1180, 0, -1180),
			Radius = 110,
			Material = Enum.Material.Basalt,
			Biome = "Volcano",
			RespawnTime = 120,
			Spawns = { { Enemy = "AshenWyrmling", Count = 1 }, { Enemy = "Corvin", Count = 1 } },
		},
		FrostHollow = {
			Name = "Frosthollow",
			Levels = "10-12",
			Position = Vector3.new(-1050, 0, -1000),
			Radius = 190,
			Material = Enum.Material.Snow,
			Biome = "Snow",
			RespawnTime = 20,
			Spawns = { { Enemy = "FrostTroll", Count = 7 } },
		},
		VaelRuins = {
			Name = "Ruins of Vael",
			Levels = "12-15",
			Position = Vector3.new(-1250, 0, 400),
			Radius = 160,
			Material = Enum.Material.Pavement,
			Biome = "Ruins",
			RespawnTime = 25,
			Spawns = { { Enemy = "RuinSentinel", Count = 6 } },
		},
	},

	-- Lakes carved into the terrain.
	Lakes = {
		{ Name = "Glass Lake", Position = Vector3.new(-520, 0, -640), Radius = 130, Island = 26 },
		{ Name = "Mirelake", Position = Vector3.new(1160, 0, 940), Radius = 95 },
		{ Name = "Millpond", Position = Vector3.new(430, 0, 720), Radius = 45 },
	},

	-- The volcano rising under Cinder Peak.
	Volcano = { Position = Vector3.new(1180, 0, -1180), BaseRadius = 620, Height = 260, TopRadius = 115 },

	-- Discoverable places. Finding one grants XP and marks it on your map (M).
	Landmarks = {
		{
			Id = "Greyspire",
			Name = "Greyspire Watchtower",
			Position = Vector3.new(-330, 0, -330),
			Kind = "Tower",
			XP = 80,
		},
		{ Id = "StonesOfAel", Name = "Stones of Ael", Position = Vector3.new(430, 0, 330), Kind = "Stones", XP = 80 },
		{ Id = "ElderOak", Name = "The Elder Oak", Position = Vector3.new(780, 0, -330), Kind = "ElderTree", XP = 100 },
		{
			Id = "AshenOverlook",
			Name = "Ashen Overlook",
			Position = Vector3.new(720, 0, -780),
			Kind = "Overlook",
			XP = 150,
		},
		{
			Id = "DrownedShrine",
			Name = "The Drowned Shrine",
			Position = Vector3.new(-520, 0, -640),
			Kind = "Shrine",
			XP = 150,
		},
		{
			Id = "HermitsHollow",
			Name = "Hermit's Hollow",
			Position = Vector3.new(-860, 0, -300),
			Kind = "Hut",
			XP = 100,
		},
		{
			Id = "WreckOfTheGull",
			Name = "Wreck of the Gull",
			Position = Vector3.new(1060, 0, 880),
			Kind = "Wreck",
			XP = 150,
		},
		{
			Id = "FrozenColossus",
			Name = "The Frozen Colossus",
			Position = Vector3.new(-1280, 0, -1260),
			Kind = "Colossus",
			XP = 250,
		},
		{
			Id = "KingsroadShrine",
			Name = "Kingsroad Shrine",
			Position = Vector3.new(-330, 0, 320),
			Kind = "Shrine",
			XP = 60,
		},
		{
			Id = "SilverfallMine",
			Name = "Silverfall Mine",
			Position = Vector3.new(-1350, 0, -520),
			Kind = "Mine",
			XP = 150,
		},
		{ Id = "SunkenGate", Name = "The Sunken Gate", Position = Vector3.new(-1000, 0, 420), Kind = "Arch", XP = 120 },
		{ Id = "BeaconHill", Name = "Beacon Hill", Position = Vector3.new(380, 0, 1050), Kind = "Tower", XP = 120 },
	},

	-- Roads (painted on the terrain; bridges are added where they cross the river).
	Roads = {
		{ From = "Town", To = "Farmlands" },
		{ From = "Town", To = "StonesOfAel" },
		{ From = "StonesOfAel", To = "CityApproach" },
		{ From = "Town", To = "WolfWoods" },
		{ From = "Town", To = "BanditCamp" },
		{ From = "Town", To = "HollowCrypt" },
		{ From = "Town", To = "Greyspire" },
		{ From = "WolfWoods", To = "AshenOverlook" },
		{ From = "AshenOverlook", To = "CinderPeak" },
		{ From = "Farmlands", To = "Mirelake" },
		{ From = "Greyspire", To = "FrostHollow" },
		{ From = "BanditCamp", To = "VaelRuins" },
		{ From = "Greyspire", To = "HermitsHollow" },
	},
}
