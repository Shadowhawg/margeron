-- World layout. The server generates a placeholder map from this if Workspace has no "Map" folder.
-- When you build your own map, put a Folder named "Map" in Workspace and, inside it, a Folder named
-- "Markers" with Parts named after any NPC id (e.g. "Elder") or zone id (e.g. "WolfWoods") to move them.
return {
	SpawnPoint = Vector3.new(0, 1, 30),
	MapSize = 1300,

	Town = {
		Name = "Riverwatch",
		Position = Vector3.new(0, 0, 0),
		Radius = 75,
	},

	NPCs = {
		Elder = {
			Name = "Elder Maren",
			Role = "Village Elder",
			Position = Vector3.new(0, 0, -30),
			Color = Color3.fromRGB(90, 70, 120),
			Greeting = "The roads grow darker every season, traveler. Riverwatch needs steel like yours.",
		},
		Blacksmith = {
			Name = "Brann",
			Role = "Blacksmith",
			Position = Vector3.new(32, 0, -6),
			Color = Color3.fromRGB(110, 70, 40),
			Greeting = "Need an edge? I've got edges.",
		},
		Hunter = {
			Name = "Ysolde",
			Role = "Hunter",
			Position = Vector3.new(-34, 0, 2),
			Color = Color3.fromRGB(60, 100, 50),
			Greeting = "Quiet. You'll scare the deer. ...What do you want?",
		},
		Mystic = {
			Name = "Seer Ilsa",
			Role = "Mystic",
			Position = Vector3.new(-22, 0, -34),
			Color = Color3.fromRGB(60, 90, 160),
			Greeting = "Your path is not yet fixed. Paths rarely are.",
		},
		Board = {
			Name = "Bounty Board",
			Role = "Contracts & Bounties",
			Position = Vector3.new(14, 0, 18),
			IsObject = true,
			Greeting = "Notices flap in the wind. Coin for those willing to earn it.",
		},
	},

	-- Spawns: { Enemy = Config/Enemies key, Count = how many alive at once }
	Zones = {
		WolfWoods = {
			Name = "Whisperwood",
			Levels = "1-3",
			Position = Vector3.new(230, 0, 40),
			Radius = 95,
			Material = Enum.Material.LeafyGrass,
			RespawnTime = 12,
			Spawns = { { Enemy = "Wolf", Count = 9 } },
		},
		BanditCamp = {
			Name = "Redfang Camp",
			Levels = "3-5",
			Position = Vector3.new(-240, 0, 150),
			Radius = 75,
			Material = Enum.Material.Ground,
			RespawnTime = 18,
			Spawns = { { Enemy = "Bandit", Count = 7 }, { Enemy = "BanditChief", Count = 1 } },
		},
		HollowCrypt = {
			Name = "Hollow Crypt",
			Levels = "6-8",
			Position = Vector3.new(90, 0, -290),
			Radius = 70,
			Material = Enum.Material.Slate,
			RespawnTime = 18,
			Spawns = { { Enemy = "Skeleton", Count = 8 } },
		},
		CinderPeak = {
			Name = "Cinder Peak",
			Levels = "9+ (Boss)",
			Position = Vector3.new(360, 0, -360),
			Radius = 60,
			Material = Enum.Material.Basalt,
			RespawnTime = 120,
			Spawns = { { Enemy = "AshenWyrmling", Count = 1 } },
		},
		FrostHollow = {
			Name = "Frosthollow",
			Levels = "10+",
			Position = Vector3.new(-290, 0, -280),
			Radius = 85,
			Material = Enum.Material.Snow,
			RespawnTime = 20,
			Spawns = { { Enemy = "FrostTroll", Count = 5 } },
		},
	},
}
