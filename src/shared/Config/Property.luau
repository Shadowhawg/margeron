-- Property, livestock, horses and farming.
--
-- Homes are deeds: when you join a server, your home is built on a free plot in Greenmeadow.
-- Each tier adds farm fields, animal pens and crafting stations.
local Property = {}

Property.Homes = {
	Order = { "Cottage", "Farmhouse", "Manor" },
	Cottage = {
		Name = "Riverside Cottage",
		Price = 2500,
		LevelReq = 3,
		Fields = 2,
		AnimalSlots = 2,
		Stations = { "CookingPot" },
		Description = "A snug cottage with a vegetable patch and a small pen.",
	},
	Farmhouse = {
		Name = "Greenmeadow Farmhouse",
		Price = 12000,
		LevelReq = 8,
		Fields = 6,
		AnimalSlots = 6,
		Stations = { "CookingPot", "Workbench" },
		Description = "A proper farm: six fields, a barn and a workbench.",
	},
	Manor = {
		Name = "Lakeside Manor",
		Price = 40000,
		LevelReq = 15,
		Fields = 10,
		AnimalSlots = 12,
		Stations = { "CookingPot", "Workbench", "AlchemyTable", "Forge" },
		Description = "A stone manor fit for a lord, with its own forge and alchemy lab.",
	},
}

-- Buying a bigger home trades in your old one for this share of its price.
Property.TradeInRate = 0.5

-- Plots in Greenmeadow (offsets from the Farmlands center). Each server builds owned homes here.
Property.Plots = {
	Vector3.new(-150, 0, -40),
	Vector3.new(-150, 0, 100),
	Vector3.new(-10, 0, 160),
	Vector3.new(130, 0, 120),
	Vector3.new(170, 0, -10),
	Vector3.new(-40, 0, 20),
	Vector3.new(80, 0, -90),
	Vector3.new(-270, 0, 40),
	Vector3.new(290, 0, 60),
}
Property.PlotSize = 110

-- Livestock lives in your home's pens and produces goods over time (even while you're offline).
--   Interval  seconds per item produced; MaxStored  how many can pile up before you collect
Property.Animals = {
	Order = { "Chicken", "Sheep", "Cow" },
	Chicken = {
		Name = "Chicken",
		Price = 150,
		Produces = "Egg",
		Interval = 240,
		MaxStored = 4,
		Color = Color3.fromRGB(240, 235, 225),
	},
	Sheep = {
		Name = "Sheep",
		Price = 500,
		Produces = "Wool",
		Interval = 480,
		MaxStored = 3,
		Color = Color3.fromRGB(230, 230, 220),
	},
	Cow = {
		Name = "Cow",
		Price = 900,
		Produces = "Milk",
		Interval = 420,
		MaxStored = 3,
		Color = Color3.fromRGB(90, 70, 60),
	},
}

-- Horses: summon with H to ride. Stabled with Rhea, so no home is needed.
Property.Horses = {
	Order = { "Courser", "DappleMare", "Charger", "Shadowmare" },
	Courser = {
		Name = "Brown Courser",
		Price = 1500,
		Speed = 28,
		Color = Color3.fromRGB(110, 75, 45),
		Mane = Color3.fromRGB(40, 28, 20),
	},
	DappleMare = {
		Name = "Dapple Mare",
		Price = 4500,
		LevelReq = 6,
		Speed = 32,
		Color = Color3.fromRGB(200, 200, 200),
		Mane = Color3.fromRGB(240, 240, 240),
	},
	Charger = {
		Name = "Highland Charger",
		Price = 10000,
		LevelReq = 12,
		Speed = 36,
		Color = Color3.fromRGB(40, 35, 32),
		Mane = Color3.fromRGB(150, 120, 80),
	},
	Shadowmare = {
		Name = "Shadowmare",
		Premium = "Shadowmare",
		Speed = 36,
		Color = Color3.fromRGB(20, 18, 24),
		Mane = Color3.fromRGB(150, 30, 40),
		Glow = Color3.fromRGB(255, 60, 40),
	},
}

-- Crops. Seeds are bought from Old Tomas; GrowTime in seconds.
Property.Crops = {
	Order = { "Wheat", "Carrot", "Potato", "Moonpetal", "Emberroot" },
	Wheat = {
		Name = "Wheat",
		Seed = "WheatSeeds",
		SeedPrice = 4,
		GrowTime = 180,
		Yield = { 3, 5 },
		Color = Color3.fromRGB(220, 190, 90),
	},
	Carrot = {
		Name = "Carrots",
		Seed = "CarrotSeeds",
		SeedPrice = 6,
		GrowTime = 300,
		Yield = { 2, 4 },
		Color = Color3.fromRGB(240, 130, 40),
	},
	Potato = {
		Name = "Potatoes",
		Seed = "PotatoSeeds",
		SeedPrice = 6,
		GrowTime = 300,
		Yield = { 2, 4 },
		Color = Color3.fromRGB(170, 140, 90),
	},
	Moonpetal = {
		Name = "Moonpetal",
		Seed = "MoonpetalSeeds",
		SeedPrice = 15,
		GrowTime = 600,
		Yield = { 2, 3 },
		Color = Color3.fromRGB(140, 160, 255),
	},
	Emberroot = {
		Name = "Emberroot",
		Seed = "EmberrootSeeds",
		SeedPrice = 40,
		GrowTime = 1200,
		Yield = { 1, 3 },
		Color = Color3.fromRGB(255, 90, 40),
		LevelReq = 8,
	},
}

Property.FertilizerSpeedup = 0.5 -- fertilized crops grow in half the time

return Property
