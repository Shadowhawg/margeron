-- Builds the open world: terrain, Riverwatch, Greenmeadow, combat zones, landmarks, forests and
-- other scenery, gathering spots, crafting stations, lighting and the day/night cycle.
--
-- If Workspace contains a Folder named "Map", generation is skipped and positions can be overridden
-- with Parts in Map/Markers named after NPC, zone, landmark or plot ids.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local TerrainGen = require(script.Parent.Parent.Lib.TerrainGen)
local Props = require(script.Parent.Parent.Lib.Props)
local Architecture = require(script.Parent.Parent.Lib.Architecture)
local CrownCity = require(script.Parent.Parent.Lib.CrownCity)
local Util = require(Shared.Util)

local WorldService = {}

local terrain = workspace.Terrain
local generated = false
local rng = Random.new(World.Seed)
local lordPlaque = nil

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function marker(name)
	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Markers")
	local part = markers and markers:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part.Position
	end
	return nil
end

function WorldService.GetNPCPosition(npcId)
	return marker(npcId) or World.NPCs[npcId].Position
end

function WorldService.GetZonePosition(zoneId)
	return marker(zoneId) or World.Zones[zoneId].Position
end

function WorldService.GetLandmarkPosition(id)
	for _, landmark in ipairs(World.Landmarks) do
		if landmark.Id == id then
			return marker(id) or landmark.Position
		end
	end
	return nil
end

-- Named positions used by roads.
local function namedPosition(name)
	if name == "Town" then
		return World.Town.Position
	elseif name == "City" then
		return World.City.Position
	elseif name == "CityApproach" then
		return World.City.Approach
	elseif name == "Farmlands" then
		return World.Farmlands.Position
	elseif World.Zones[name] then
		return WorldService.GetZonePosition(name)
	end
	return WorldService.GetLandmarkPosition(name)
end

-- Raycast down to find the ground (terrain or custom map) under a point.
function WorldService.GroundAt(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = true
	local include = { terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(include, map)
	end
	params.FilterDescendantsInstances = include
	local result = workspace:Raycast(Vector3.new(position.X, 600, position.Z), Vector3.new(0, -1200, 0), params)
	return result and result.Position or Vector3.new(position.X, 0, position.Z)
end

-- Ground position at X/Z: fast and exact for the generated world.
function WorldService.Ground(x, z)
	if generated then
		return Vector3.new(x, TerrainGen.HeightAt(x, z), z)
	end
	return WorldService.GroundAt(Vector3.new(x, 0, z))
end

function WorldService.IsGenerated()
	return generated
end

function WorldService.SetLordName(text)
	for _, label in ipairs(lordPlaque or {}) do
		label.Text = text
	end
end

-- Helpers ---------------------------------------------------------------------------------

local function nearAny(x, z, list, radius)
	for _, p in ipairs(list) do
		local dx, dz = x - p.X, z - p.Z
		if dx * dx + dz * dz < radius * radius then
			return true
		end
	end
	return false
end

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function roadDistance(x, z)
	local best = math.huge
	for _, seg in ipairs(TerrainGen.Roads()) do
		local a, b = seg.A, seg.B
		local v = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local t = math.clamp(((x - a.X) * v.X + (z - a.Z) * v.Z) / v.Magnitude ^ 2, 0, 1)
		local d = Vector3.new(a.X + v.X * t - x, 0, a.Z + v.Z * t - z).Magnitude
		best = math.min(best, d)
	end
	return best
end

-- Gathering spots: tagged "GatherNode" with a "Resource" attribute (handled by ExplorationService).
local function gatherNode(ground, resource)
	local model = Instance.new("Model")
	model.Name = "Gather_" .. resource
	local isOre = resource == "IronOre" or resource == "SilverOre"
	local base
	if isOre then
		base = Props.Part({
			Name = "Vein",
			Size = Vector3.new(4, 3, 4),
			CFrame = CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.2),
			Color = rgb(95, 95, 100),
			Material = Enum.Material.Slate,
			Parent = model,
		})
		for _ = 1, 5 do
			Props.Part({
				Name = "Fleck",
				Size = Vector3.new(0.5, 0.5, 0.5),
				CFrame = base.CFrame
					* CFrame.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(-0.6, 1.5), rng:NextNumber(-1.6, 1.6)),
				Color = resource == "SilverOre" and rgb(220, 230, 240) or rgb(180, 110, 70),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
		end
	else
		local colors = {
			Moonpetal = rgb(140, 160, 255),
			Bloodthistle = rgb(200, 30, 50),
			Frostcap = rgb(200, 235, 255),
			Emberroot = rgb(255, 100, 30),
			Bogbloom = rgb(120, 200, 80),
			Riverreed = rgb(190, 170, 110),
		}
		base = Props.Part({
			Name = "Stem",
			Size = Vector3.new(0.3, 1.6, 0.3),
			Position = ground + Vector3.new(0, 0.8, 0),
			Color = rgb(60, 110, 50),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = model,
		})
		for i = 1, 3 do
			local bloom = Props.Part({
				Name = "Bloom",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.8, 0.8, 0.8),
				Position = ground + Vector3.new(math.cos(i * 2.1) * 0.6, 1.4 + i * 0.15, math.sin(i * 2.1) * 0.6),
				Color = colors[resource] or rgb(255, 255, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
			bloom.CastShadow = false
		end
	end
	model.PrimaryPart = base
	model:SetAttribute("Resource", resource)
	model.Parent = Props.Folder
	CollectionService:AddTag(model, "GatherNode")
end

-- Crafting stations: tagged "CraftingStation" with a "Station" attribute (handled by CraftingService).
function WorldService.BuildStation(stationId, ground, facing, parent)
	local model = Instance.new("Model")
	model.Name = stationId
	local cf = CFrame.lookAt(ground, ground + (facing or Vector3.new(0, 0, -1)))
	local main
	if stationId == "Forge" then
		main = Props.Part({
			Name = "Forge",
			Size = Vector3.new(5, 3.5, 5),
			CFrame = cf * CFrame.new(0, 1.75, 0),
			Color = rgb(80, 75, 75),
			Material = Enum.Material.Brick,
			Parent = model,
		})
		local coals = Props.Part({
			Name = "Coals",
			Size = Vector3.new(3.5, 0.4, 3.5),
			CFrame = cf * CFrame.new(0, 3.6, 0),
			Color = rgb(255, 100, 30),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Parent = coals
		Props.Part({
			Name = "Anvil",
			Size = Vector3.new(2.5, 1.5, 1.2),
			CFrame = cf * CFrame.new(-4.5, 0.75, 0),
			Color = rgb(50, 50, 55),
			Material = Enum.Material.Metal,
			Parent = model,
		})
	elseif stationId == "AlchemyTable" then
		main = Props.Part({
			Name = "Table",
			Size = Vector3.new(6, 3, 3),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			Color = rgb(90, 65, 45),
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
		local colors = { rgb(120, 220, 120), rgb(220, 90, 200), rgb(90, 170, 255) }
		for i = 1, 3 do
			local flask = Props.Part({
				Name = "Flask",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				CFrame = cf * CFrame.new(-2 + i, 3.5, 0),
				Color = colors[i],
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
			flask.Transparency = 0.2
		end
	elseif stationId == "CookingPot" then
		main = Props.Part({
			Name = "Pot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.5, 3.5, 3.5),
			CFrame = cf * CFrame.new(0, 1.8, 0),
			Color = rgb(40, 40, 45),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		local fire = Props.Part({
			Name = "Embers",
			Size = Vector3.new(3, 0.4, 3),
			CFrame = cf * CFrame.new(0, 0.2, 0),
			Color = rgb(255, 120, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
		local f = Instance.new("Fire")
		f.Size = 2
		f.Parent = fire
		local steam = Instance.new("Smoke")
		steam.Color = rgb(230, 230, 230)
		steam.Size = 1
		steam.Opacity = 0.15
		steam.RiseVelocity = 3
		steam.Parent = main
	else -- Workbench
		main = Props.Part({
			Name = "Bench",
			Size = Vector3.new(7, 3, 3.5),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			Color = rgb(120, 85, 55),
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
		Props.Part({
			Name = "Saw",
			Size = Vector3.new(2, 0.1, 0.8),
			CFrame = cf * CFrame.new(1.5, 3.1, 0),
			Color = rgb(170, 170, 175),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		Props.Part({
			Name = "Hammer",
			Size = Vector3.new(0.4, 0.4, 1.6),
			CFrame = cf * CFrame.new(-1.5, 3.2, 0.5),
			Color = rgb(90, 70, 50),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	model.PrimaryPart = main
	model:SetAttribute("Station", stationId)
	model.Parent = parent or Props.Folder
	CollectionService:AddTag(model, "CraftingStation")
	return model
end

-- Riverwatch -------------------------------------------------------------------------------

local function buildTown()
	local town = World.Town
	local center = town.Position
	local function groundAt(x, z)
		return WorldService.Ground(x, z)
	end

	-- A gate wherever a road leaves town (plus the south gate to the bridge).
	local gateAngles = {}
	local function addGate(angle)
		for _, g in ipairs(gateAngles) do
			if math.abs((angle - g + math.pi) % (2 * math.pi) - math.pi) < 0.3 then
				return
			end
		end
		table.insert(gateAngles, angle)
	end
	for _, road in ipairs(World.Roads) do
		local other = road.From == "Town" and road.To or (road.To == "Town" and road.From or nil)
		local p = other and namedPosition(other)
		if p then
			addGate(math.atan2(p.Z - center.Z, p.X - center.X))
		end
	end
	addGate(math.atan2(170 - center.Z, 0 - center.X))
	WorldService.TownGates = gateAngles
	local function nearGate(a, width)
		for _, g in ipairs(gateAngles) do
			if math.abs((a - g + math.pi) % (2 * math.pi) - math.pi) < width then
				return true
			end
		end
		return false
	end

	-- Stone curtain wall with towers, battlements and gatehouses.
	local wallRadius = town.Radius - 6
	Architecture.CurtainWall(center, wallRadius, 14, groundAt, {
		Gates = gateAngles,
		Segments = 60,
		TowerEvery = 6,
		Thickness = 4,
		GateWidth = 14,
		Roof = rgb(95, 45, 40),
		Banner = rgb(40, 70, 130),
	})

	-- Streets: a ring road, roads out to every gate, and lamps along them.
	local ringRadius = 58
	local ringPoints = 28
	for i = 0, ringPoints - 1 do
		local a0 = i / ringPoints * math.pi * 2
		local a1 = (i + 1) / ringPoints * math.pi * 2
		Architecture.Street(
			Vector3.new(math.cos(a0) * ringRadius, 0, math.sin(a0) * ringRadius) + center,
			Vector3.new(math.cos(a1) * ringRadius, 0, math.sin(a1) * ringRadius) + center,
			9,
			groundAt
		)
		if i % 4 == 0 then
			Architecture.Lamp(
				groundAt(center.X + math.cos(a0) * (ringRadius + 6), center.Z + math.sin(a0) * (ringRadius + 6))
			)
		end
	end
	for _, g in ipairs(gateAngles) do
		local dir = Vector3.new(math.cos(g), 0, math.sin(g))
		Architecture.Street(center + dir * 16, center + dir * (wallRadius + 4), 10, groundAt)
		for _, r in ipairs({ 30, 80, 104 }) do
			local side = Vector3.new(-dir.Z, 0, dir.X) * 7
			Architecture.Lamp(groundAt(center.X + dir.X * r + side.X, center.Z + dir.Z * r + side.Z))
		end
	end

	-- Spots houses must keep clear of: NPCs, stations, the inn, the hall and market stalls.
	local reserved = { Vector3.new(-52, 0, 48), Vector3.new(49, 0, 48), Vector3.new(58, 0, 48), Vector3.new(67, 0, 48) }
	for _, npc in pairs(World.NPCs) do
		if Util.FlatDistance(npc.Position, center) < town.Radius then
			table.insert(reserved, npc.Position)
		end
	end
	for _, st in ipairs(World.Stations) do
		table.insert(reserved, st.Position)
	end

	-- Two rings of timber-framed houses facing the streets.
	local hallPos = Vector3.new(-66, 0, -66)
	local hallAngle = math.atan2(hallPos.Z, hallPos.X)
	local walls = { rgb(232, 220, 195), rgb(220, 200, 165), rgb(236, 228, 210), rgb(210, 190, 160), rgb(225, 205, 185) }
	local roofs = { rgb(110, 55, 45), rgb(85, 70, 65), rgb(120, 75, 50), rgb(70, 75, 85) }
	local shutters = { rgb(60, 90, 70), rgb(120, 40, 40), rgb(50, 70, 110), rgb(110, 85, 50) }
	for ring, ringInfo in ipairs({ { Radius = 80, Count = 18, Stories = 2 }, { Radius = 101, Count = 24, Stories = 2 } }) do
		for i = 0, ringInfo.Count - 1 do
			local a = i / ringInfo.Count * math.pi * 2 + 0.13 * ring
			local nearHall = math.abs((a - hallAngle + math.pi) % (2 * math.pi) - math.pi) < 0.45
			local spot =
				Vector3.new(center.X + math.cos(a) * ringInfo.Radius, 0, center.Z + math.sin(a) * ringInfo.Radius)
			if not nearGate(a, 0.2) and not nearHall and not nearAny(spot.X, spot.Z, reserved, 22) then
				local ground = WorldService.Ground(spot.X, spot.Z)
				local facing = ((center - ground) * Vector3.new(1, 0, 1)).Unit
				Architecture.House(ground, facing, {
					Width = 14 + (i % 3) * 2,
					Depth = 12 + (i % 2) * 2,
					Stories = (i % 4 == 0) and 1 or ringInfo.Stories + ((ring == 2 and i % 5 == 0) and 1 or 0),
					Wall = walls[i % #walls + 1],
					Roof = roofs[(i + ring) % #roofs + 1],
					Shutters = shutters[i % #shutters + 1],
				})
				table.insert(reserved, spot)
			end
		end
	end

	-- Town hall
	local hallGround = WorldService.Ground(hallPos.X, hallPos.Z)
	local hallCf = CFrame.lookAt(hallGround, hallGround + Vector3.new(-hallPos.X, 0, -hallPos.Z).Unit)
	Props.Part({
		Name = "HallSteps",
		Size = Vector3.new(30, 2, 26),
		CFrame = hallCf * CFrame.new(0, 0.5, 0),
		Color = rgb(150, 145, 140),
		Material = Enum.Material.Cobblestone,
	})
	Props.Part({
		Name = "HallWalls",
		Size = Vector3.new(26, 16, 22),
		CFrame = hallCf * CFrame.new(0, 9, 2),
		Color = rgb(170, 160, 145),
		Material = Enum.Material.Limestone,
	})
	Props.Part({
		Name = "HallRoof",
		Size = Vector3.new(30, 3, 26),
		CFrame = hallCf * CFrame.new(0, 18, 2),
		Color = rgb(110, 40, 40),
		Material = Enum.Material.Slate,
	})
	for _, x in ipairs({ -10, -4, 4, 10 }) do
		Props.Part({
			Name = "HallColumn",
			Size = Vector3.new(2, 15, 2),
			CFrame = hallCf * CFrame.new(x, 8.5, -10),
			Color = rgb(200, 195, 185),
			Material = Enum.Material.Marble,
		})
	end
	for _, x in ipairs({ -7, 7 }) do
		Props.Part({
			Name = "Banner",
			Size = Vector3.new(4, 9, 0.2),
			CFrame = hallCf * CFrame.new(x, 10, -9.2),
			Color = rgb(130, 25, 35),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end

	-- Statue of the ruler with a plaque that shows the current Lord.
	local statueGround = WorldService.Ground(-20, 10)
	Props.Part({
		Name = "Plinth",
		Size = Vector3.new(6, 5, 6),
		Position = statueGround + Vector3.new(0, 2.5, 0),
		Color = rgb(160, 155, 150),
		Material = Enum.Material.Marble,
	})
	Props.Part({
		Name = "StatueBody",
		Size = Vector3.new(2.4, 5, 1.4),
		Position = statueGround + Vector3.new(0, 7.5, 0),
		Color = rgb(190, 180, 150),
		Material = Enum.Material.Marble,
	})
	Props.Part({
		Name = "StatueHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = statueGround + Vector3.new(0, 10.8, 0),
		Color = rgb(190, 180, 150),
		Material = Enum.Material.Marble,
	})
	local _, plaqueLabels =
		Props.Sign(statueGround + Vector3.new(0, 0, -6), "Riverwatch, free town", Vector3.new(0, 0, -1))
	lordPlaque = plaqueLabels

	-- Well, market stalls, inn, torches
	local wellGround = WorldService.Ground(0, 0)
	Props.Part({
		Name = "Well",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 7, 7),
		CFrame = CFrame.new(wellGround + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(130, 125, 120),
		Material = Enum.Material.Cobblestone,
	})
	Props.Part({
		Name = "WellRoof",
		Size = Vector3.new(8, 0.6, 8),
		Position = wellGround + Vector3.new(0, 7, 0),
		Color = rgb(120, 50, 40),
		Material = Enum.Material.Slate,
	})
	for _, x in ipairs({ -3, 3 }) do
		Props.Part({
			Name = "WellPost",
			Size = Vector3.new(0.6, 5, 0.6),
			Position = wellGround + Vector3.new(x, 4.5, 0),
			Color = rgb(95, 68, 45),
			Material = Enum.Material.Wood,
		})
	end
	local stallColors = { rgb(170, 50, 50), rgb(60, 110, 170), rgb(200, 160, 60) }
	for i = 1, 3 do
		Architecture.MarketStall(WorldService.Ground(40 + i * 9, 48), Vector3.new(0, 0, -1), stallColors[i])
	end
	local innGround = WorldService.Ground(-52, 48)
	local innFacing = ((Vector3.new(0, 0, 0) - Vector3.new(-52, 0, 48)) * Vector3.new(1, 0, 1)).Unit
	local innCf = Architecture.House(innGround, innFacing, {
		Width = 22,
		Depth = 18,
		Stories = 3,
		Wall = rgb(225, 205, 170),
		Roof = rgb(100, 50, 40),
		Shutters = rgb(120, 40, 40),
		Sign = "The Drowned Rat",
	})
	-- The innkeeper's counter: rent a bed for the Well Rested bonus.
	local bed = Props.Part({
		Name = "InnBed",
		Size = Vector3.new(4, 3, 2),
		CFrame = innCf * CFrame.new(-7, 1.5, -11.5),
		Color = rgb(110, 80, 55),
		Material = Enum.Material.WoodPlanks,
	})
	bed:SetAttribute("Cost", 10)
	CollectionService:AddTag(bed, "RestSpot")

	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		Props.Torch(WorldService.Ground(math.cos(a) * 30, math.sin(a) * 30))
	end
	for _, s in ipairs(World.Stations) do
		local ground = WorldService.Ground(s.Position.X, s.Position.Z)
		local facing = (center - ground) * Vector3.new(1, 0, 1)
		WorldService.BuildStation(s.Station, ground, facing.Magnitude > 0 and facing.Unit or nil)
	end
end

-- Greenmeadow ------------------------------------------------------------------------------

local function buildFarmlands()
	local farm = World.Farmlands
	local c = farm.Position
	-- Windmill
	local millGround = WorldService.Ground(c.X - 60, c.Z - 210)
	Props.Part({
		Name = "MillTower",
		Size = Vector3.new(10, 26, 10),
		Position = millGround + Vector3.new(0, 12, 0),
		Color = rgb(200, 190, 170),
		Material = Enum.Material.Plaster,
	})
	Props.Part({
		Name = "MillCap",
		Size = Vector3.new(12, 6, 12),
		Position = millGround + Vector3.new(0, 27, 0),
		Color = rgb(110, 50, 40),
		Material = Enum.Material.Slate,
	})
	local hub = Props.Part({
		Name = "MillHub",
		Size = Vector3.new(2, 2, 2),
		Position = millGround + Vector3.new(0, 24, -6),
		Color = rgb(90, 65, 45),
		Material = Enum.Material.Wood,
	})
	for i = 0, 3 do
		Props.Part({
			Name = "MillSail",
			Size = Vector3.new(2.5, 16, 0.3),
			CFrame = hub.CFrame * CFrame.Angles(0, 0, i * math.pi / 2 + 0.3) * CFrame.new(0, 8, -0.5),
			Color = rgb(225, 215, 195),
			Material = Enum.Material.Fabric,
		})
	end
	-- Stable
	local stableGround =
		WorldService.Ground(World.NPCs.Stablemaster.Position.X + 16, World.NPCs.Stablemaster.Position.Z - 10)
	Props.Part({
		Name = "StableRoof",
		Size = Vector3.new(24, 1, 12),
		Position = stableGround + Vector3.new(0, 9, 0),
		Color = rgb(120, 60, 40),
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in ipairs({ -11, 0, 11 }) do
		for _, z in ipairs({ -5, 5 }) do
			Props.Part({
				Name = "StablePost",
				Size = Vector3.new(1, 9, 1),
				Position = stableGround + Vector3.new(x, 4.5, z),
				Color = rgb(95, 68, 45),
				Material = Enum.Material.Wood,
			})
		end
	end
	Props.Sign(WorldService.Ground(c.X - 40, c.Z - 250), "Greenmeadow", Vector3.new(0, 0, -1))
	-- Hay bales and crop rows near the farmer
	for _ = 1, 8 do
		local ground = WorldService.Ground(
			World.NPCs.Farmer.Position.X + rng:NextNumber(-25, 25),
			World.NPCs.Farmer.Position.Z + rng:NextNumber(-30, -14)
		)
		Props.Part({
			Name = "HayBale",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 3.5, 3.5),
			CFrame = CFrame.new(ground + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = rgb(215, 185, 100),
			Material = Enum.Material.Grass,
		})
	end
end

-- Zones ------------------------------------------------------------------------------------

local function scatter(center, radius, count, fn)
	for _ = 1, count do
		local r = math.sqrt(rng:NextNumber()) * radius
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		if not TerrainGen.IsWater(x, z) then
			fn(WorldService.Ground(x, z), x, z)
		end
	end
end

local zoneBuilders = {}

function zoneBuilders.Forest(_, center, zone)
	scatter(center, zone.Radius * 1.4, 240, function(g)
		if rng:NextNumber() < 0.85 then
			Props.Tree(g, rng:NextNumber(1, 1.7), rgb(45, 95, 50))
		else
			Props.Bush(g)
		end
	end)
end

function zoneBuilders.Camp(_, center, zone)
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		if i ~= 0 and i ~= 1 and i ~= 18 then
			local p = WorldService.Ground(
				center.X + math.cos(a) * zone.Radius * 0.85,
				center.Z + math.sin(a) * zone.Radius * 0.85
			)
			Props.Part({
				Name = "Palisade",
				Size = Vector3.new(2.4, 13, 2.4),
				CFrame = CFrame.new(p + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, -a, rng:NextNumber(-0.08, 0.08)),
				Color = rgb(100, 70, 45),
				Material = Enum.Material.Wood,
			})
		end
	end
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		local p = WorldService.Ground(center.X + math.cos(a) * 38, center.Z + math.sin(a) * 38)
		local cf = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, a, 0)
		for side = -1, 1, 2 do
			Props.Part({
				ClassName = "WedgePart",
				Name = "Tent",
				Size = Vector3.new(9, 6, 4.5),
				CFrame = cf * CFrame.new(0, 0, side * 2.25) * CFrame.Angles(0, side == 1 and math.pi or 0, 0),
				Color = rgb(150, 50, 45),
				Material = Enum.Material.Fabric,
			})
		end
	end
	Props.Torch(WorldService.Ground(center.X, center.Z))
	local tower = WorldService.Ground(center.X + 30, center.Z - 30)
	Props.Part({
		Name = "Lookout",
		Size = Vector3.new(8, 1, 8),
		Position = tower + Vector3.new(0, 16, 0),
		Color = rgb(100, 70, 45),
		Material = Enum.Material.WoodPlanks,
	})
	for _, o in ipairs({
		Vector3.new(-3.5, 0, -3.5),
		Vector3.new(3.5, 0, -3.5),
		Vector3.new(-3.5, 0, 3.5),
		Vector3.new(3.5, 0, 3.5),
	}) do
		Props.Part({
			Name = "LookoutLeg",
			Size = Vector3.new(1, 16, 1),
			Position = tower + o + Vector3.new(0, 8, 0),
			Color = rgb(95, 68, 45),
			Material = Enum.Material.Wood,
		})
	end
end

function zoneBuilders.Crypt(_, center, zone)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p =
			WorldService.Ground(center.X + math.cos(a) * zone.Radius * 0.7, center.Z + math.sin(a) * zone.Radius * 0.7)
		Props.Part({
			Name = "Pillar",
			Size = Vector3.new(3, rng:NextNumber(8, 18), 3),
			Position = p + Vector3.new(0, 6, 0),
			Color = rgb(90, 90, 95),
			Material = Enum.Material.Slate,
		})
	end
	local g = WorldService.Ground(center.X, center.Z - zone.Radius * 0.35)
	Props.Part({
		Name = "CryptEntrance",
		Size = Vector3.new(24, 14, 12),
		Position = g + Vector3.new(0, 7, 0),
		Color = rgb(70, 70, 75),
		Material = Enum.Material.Slate,
	})
	Props.Part({
		Name = "CryptDoor",
		Size = Vector3.new(7, 9, 0.5),
		Position = g + Vector3.new(0, 4.5, 6.1),
		Color = rgb(5, 5, 8),
		Material = Enum.Material.Slate,
	})
	local glow = Props.Part({
		Name = "CryptGlow",
		Size = Vector3.new(6, 8, 0.3),
		Position = g + Vector3.new(0, 4.5, 6.4),
		Color = rgb(90, 160, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	glow.Transparency = 0.7
	scatter(center, zone.Radius * 0.95, 30, function(p)
		Props.Part({
			Name = "Gravestone",
			Size = Vector3.new(2.5, 3.5, 0.6),
			CFrame = CFrame.new(p + Vector3.new(0, 1.4, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.4, 0.4), 0),
			Color = rgb(120, 120, 125),
			Material = Enum.Material.Slate,
		})
	end)
	scatter(center, zone.Radius * 1.3, 25, function(p)
		Props.DeadTree(p, rng:NextNumber(0.9, 1.3))
	end)
end

function zoneBuilders.Marsh(_, center, zone)
	scatter(center, zone.Radius * 1.2, 70, function(p)
		Props.DeadTree(p, rng:NextNumber(0.8, 1.4))
	end)
	scatter(center, zone.Radius * 1.2, 160, function(p)
		Props.Part({
			Name = "Reeds",
			Size = Vector3.new(0.3, rng:NextNumber(2, 4), 0.3),
			Position = p + Vector3.new(0, 1.2, 0),
			Color = rgb(120, 130, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
			CastShadow = false,
		})
	end)
	local fogGround = WorldService.Ground(center.X, center.Z)
	local fog = Props.Part({
		Name = "MarshFog",
		Size = Vector3.new(zone.Radius * 2, 1, zone.Radius * 2),
		Position = fogGround + Vector3.new(0, 1, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(rgb(180, 200, 170))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Parent = fog
end

function zoneBuilders.Volcano(_, center, zone)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local h = rng:NextNumber(18, 40)
		local p = WorldService.Ground(
			center.X + math.cos(a) * zone.Radius * 1.05,
			center.Z + math.sin(a) * zone.Radius * 1.05
		)
		Props.Part({
			Name = "Spire",
			Size = Vector3.new(8, h, 8),
			CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(0, a, rng:NextNumber(-0.15, 0.15)),
			Color = rgb(45, 40, 40),
			Material = Enum.Material.Basalt,
		})
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(zone.Radius * 0.3, zone.Radius * 0.8)
		local p = WorldService.Ground(center.X + math.cos(a) * r, center.Z + math.sin(a) * r)
		local pool = Props.Part({
			Name = "LavaPool",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, rng:NextNumber(5, 10), rng:NextNumber(5, 10)),
			CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(255, 90, 20),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 110, 40)
		light.Range = 16
		light.Parent = pool
	end
	local ashSource = Props.Part({
		Name = "AshSky",
		Size = Vector3.new(300, 1, 300),
		Position = WorldService.Ground(center.X, center.Z) + Vector3.new(0, 70, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local ash = Instance.new("ParticleEmitter")
	ash.Color = ColorSequence.new(rgb(90, 85, 85))
	ash.Size = NumberSequence.new(0.4)
	ash.Lifetime = NumberRange.new(10, 14)
	ash.Rate = 60
	ash.Speed = NumberRange.new(2, 4)
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Parent = ashSource
end

function zoneBuilders.Snow(_, center, zone)
	scatter(center, zone.Radius * 1.6, 160, function(p)
		Props.Pine(p, rng:NextNumber(0.9, 1.6), true)
	end)
	scatter(center, zone.Radius, 20, function(p)
		Props.Rock(
			p,
			Vector3.new(rng:NextNumber(4, 10), rng:NextNumber(3, 7), rng:NextNumber(4, 10)),
			rgb(170, 195, 210),
			Enum.Material.Glacier
		)
	end)
end

function zoneBuilders.Ruins(_, center, zone)
	local stone = rgb(150, 145, 130)
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, zone.Radius)
		local p = WorldService.Ground(center.X + math.cos(a) * r, center.Z + math.sin(a) * r)
		if rng:NextNumber() < 0.5 then
			local len = rng:NextNumber(10, 26)
			Props.Part({
				Name = "RuinWall",
				Size = Vector3.new(len, rng:NextNumber(4, 12), 2.5),
				CFrame = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				Color = stone,
				Material = Enum.Material.Limestone,
			})
		else
			local h = rng:NextNumber(6, 20)
			Props.Part({
				Name = "RuinColumn",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(h, 3, 3),
				CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = stone,
				Material = Enum.Material.Marble,
			})
		end
	end
	local g = WorldService.Ground(center.X, center.Z)
	Props.Part({
		Name = "RuinThrone",
		Size = Vector3.new(6, 9, 4),
		Position = g + Vector3.new(0, 4.5, 0),
		Color = rgb(110, 105, 100),
		Material = Enum.Material.Granite,
	})
end

local function buildZone(zoneId, zone)
	local center = WorldService.GetZonePosition(zoneId)
	local builder = zoneBuilders[zone.Biome]
	if builder then
		builder(zoneId, center, zone)
	end
	local toTown = (World.Town.Position - center) * Vector3.new(1, 0, 1)
	toTown = toTown.Unit
	local signAt = center + toTown * (zone.Radius + 14)
	Props.Sign(WorldService.Ground(signAt.X, signAt.Z), zone.Name .. "  (Lv " .. zone.Levels .. ")", toTown)
end

-- Open-world scenery and gathering -----------------------------------------------------------

local function biomeAt(x, z, h)
	local p = Vector3.new(x, 0, z)
	if flatDist(p, World.Volcano.Position) < World.Volcano.BaseRadius then
		return "Volcano"
	end
	local frost = World.Zones.FrostHollow
	if (x < -600 and z < -550) or flatDist(p, frost.Position) < frost.Radius * 2 or h > 160 then
		return "Snow"
	end
	if flatDist(p, World.Zones.Mirelake.Position) < World.Zones.Mirelake.Radius * 1.6 then
		return "Marsh"
	end
	if math.noise(x / 300, z / 300, 3.3) > 0.12 then
		return "Forest"
	end
	return "Meadow"
end

local function buildScenery()
	local landmarkPositions = {}
	for _, l in ipairs(World.Landmarks) do
		table.insert(landmarkPositions, l.Position)
	end
	local half = World.MapHalfSize * 0.86

	local flowerColors =
		{ rgb(240, 220, 80), rgb(230, 120, 180), rgb(250, 250, 250), rgb(150, 120, 230), rgb(240, 120, 60) }
	local lastYield = os.clock()
	for _ = 1, 3600 do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		local h = TerrainGen.HeightAt(x, z)
		local clear = h > 1.5
			and flatDist(Vector3.new(x, 0, z), World.Town.Position) > World.Town.Radius + 10
			and flatDist(Vector3.new(x, 0, z), World.Farmlands.Position) > World.Farmlands.Radius * 0.8
			and flatDist(Vector3.new(x, 0, z), World.City.Position) > World.City.LakeRadius + 20
			and not nearAny(x, z, landmarkPositions, 34)
			and roadDistance(x, z) > 9
		if clear then
			local slope = math.abs(TerrainGen.HeightAt(x + 4, z) - h) + math.abs(TerrainGen.HeightAt(x, z + 4) - h)
			local ground = Vector3.new(x, h, z)
			local biome = biomeAt(x, z, h)
			local roll = rng:NextNumber()
			if biome == "Volcano" then
				if roll < 0.25 then
					Props.Rock(
						ground,
						Vector3.new(rng:NextNumber(3, 9), rng:NextNumber(2, 6), rng:NextNumber(3, 9)),
						rgb(50, 45, 45),
						Enum.Material.Basalt
					)
				end
			elseif biome == "Snow" then
				if roll < 0.45 and slope < 6 then
					Props.Pine(ground, rng:NextNumber(0.9, 1.5), true)
				elseif roll < 0.55 then
					Props.Rock(
						ground,
						Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 5), rng:NextNumber(3, 8)),
						rgb(170, 180, 190)
					)
				end
			elseif biome == "Marsh" then
				if roll < 0.2 then
					Props.DeadTree(ground, rng:NextNumber(0.8, 1.2))
				end
			elseif biome == "Forest" then
				if slope < 6 and roll < 0.75 then
					if h > 70 then
						Props.Pine(ground, rng:NextNumber(0.9, 1.4), false)
					else
						Props.Tree(ground, rng:NextNumber(0.9, 1.6), rgb(55, 105, 55))
					end
				elseif roll < 0.85 then
					Props.Bush(ground)
				end
			else -- Meadow
				if roll < 0.12 and slope < 6 then
					Props.Tree(ground, rng:NextNumber(0.8, 1.4), rgb(70, 120, 60))
				elseif roll < 0.2 then
					Props.Rock(ground, Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 5), rng:NextNumber(3, 8)))
				elseif roll < 0.3 then
					Props.Bush(ground, rgb(70, 115, 55))
				elseif roll < 0.42 then
					Props.Flowers(ground, flowerColors[rng:NextInteger(1, #flowerColors)])
				end
			end
		end
		if os.clock() - lastYield > 0.05 then
			task.wait()
			lastYield = os.clock()
		end
	end
end

local function buildGatherNodes()
	local half = World.MapHalfSize * 0.84
	local placed = 0
	local tries = 0
	while placed < 320 and tries < 6000 do
		tries += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		local h = TerrainGen.HeightAt(x, z)
		local p = Vector3.new(x, 0, z)
		if
			h > 0.5
			and flatDist(p, World.Town.Position) > World.Town.Radius
			and flatDist(p, World.Farmlands.Position) > World.Farmlands.Radius * 0.7
			and flatDist(p, World.City.Position) > World.City.IslandRadius
			and roadDistance(x, z) > 6
		then
			local biome = biomeAt(x, z, h)
			local nearWater = h < 4
			local resource
			local roll = rng:NextNumber()
			if nearWater then
				resource = "Riverreed"
			elseif biome == "Volcano" then
				resource = roll < 0.6 and "Emberroot" or "IronOre"
			elseif biome == "Snow" then
				resource = roll < 0.55 and "Frostcap" or "SilverOre"
			elseif biome == "Marsh" then
				resource = "Bogbloom"
			elseif h > 55 then
				resource = roll < 0.7 and "IronOre" or "Moonpetal"
			elseif biome == "Forest" then
				resource = roll < 0.65 and "Moonpetal" or (roll < 0.85 and "Bloodthistle" or "IronOre")
			else
				resource = roll < 0.6 and "Bloodthistle" or (roll < 0.8 and "Moonpetal" or "IronOre")
			end
			gatherNode(Vector3.new(x, h, z), resource)
			placed += 1
		end
	end
	-- Guaranteed clusters at landmarks and near town so new players find some early.
	for _, spot in ipairs({
		{ Id = "SilverfallMine", Resource = "SilverOre", Count = 8 },
		{ Id = "Greyspire", Resource = "IronOre", Count = 6 },
		{ Id = "HermitsHollow", Resource = "Moonpetal", Count = 5 },
		{ Id = "KingsroadShrine", Resource = "Bloodthistle", Count = 5 },
	}) do
		local c = WorldService.GetLandmarkPosition(spot.Id)
		for _ = 1, spot.Count do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(14, 34)
			gatherNode(WorldService.Ground(c.X + math.cos(a) * r, c.Z + math.sin(a) * r), spot.Resource)
		end
	end
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(World.Town.Radius + 15, World.Town.Radius + 70)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not TerrainGen.IsWater(x, z) then
			gatherNode(WorldService.Ground(x, z), rng:NextNumber() < 0.5 and "Bloodthistle" or "Moonpetal")
		end
	end
end

local function buildLandmarks()
	for _, landmark in ipairs(World.Landmarks) do
		local p = WorldService.GetLandmarkPosition(landmark.Id)
		Props.Landmark(landmark.Kind, WorldService.Ground(p.X, p.Z))
	end
end

local function buildBridges()
	local crossings = TerrainGen.RiverCrossings()
	for _, crossing in ipairs(crossings) do
		-- The canyon is cut River.Width + 34 either side of the centre line; span it fully,
		-- lengthening the bridge when the road meets the river at an angle.
		local p, dir = crossing.Position, crossing.Direction
		local half = math.min(110, (World.River.Width + 40) / math.max(0.35, math.abs(dir.Z)))
		local function bank(sign)
			local at = p + dir * half * sign
			return Vector3.new(at.X, math.max(4, TerrainGen.HeightAt(at.X, at.Z)) + 0.5, at.Z)
		end
		Props.Bridge(bank(-1), bank(1), 14)
	end
end

local function setupLighting()
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = rgb(120, 115, 130)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GeographicLatitude = 35
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = rgb(200, 195, 185)
	atmosphere.Decay = rgb(110, 100, 95)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 18
	bloom.Threshold = 2
	bloom.Parent = Lighting
	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.06
	sunRays.Parent = Lighting
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = terrain
	terrain.WaterColor = rgb(50, 90, 100)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterReflectance = 0.6
end

function WorldService.Init()
	if workspace:FindFirstChild("Map") then
		print("[WorldService] Custom Map found, skipping world generation")
	else
		local started = os.clock()
		Props.Folder = Instance.new("Folder")
		Props.Folder.Name = "GeneratedWorld"
		Props.Folder.Parent = workspace
		Architecture.Folder = Props.Folder
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end

		local positions = {
			Town = World.Town.Position,
			Farmlands = World.Farmlands.Position,
			City = World.City.Position,
			CityApproach = World.City.Approach,
		}
		for zoneId in pairs(World.Zones) do
			positions[zoneId] = WorldService.GetZonePosition(zoneId)
		end
		for _, l in ipairs(World.Landmarks) do
			positions[l.Id] = WorldService.GetLandmarkPosition(l.Id)
		end

		TerrainGen.Generate(positions)
		generated = true
		buildTown()
		CrownCity.Build(function(x, z)
			return WorldService.Ground(x, z)
		end)
		buildFarmlands()
		buildBridges()
		buildLandmarks()
		for zoneId, zone in pairs(World.Zones) do
			buildZone(zoneId, zone)
		end
		buildScenery()
		buildGatherNodes()
		setupLighting()
		print(string.format("[WorldService] World generated in %.1fs", os.clock() - started))
	end

	if not workspace:FindFirstChild("MargeronSpawn", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "MargeronSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0
		spawn.Position = WorldService.Ground(World.SpawnPoint.X, World.SpawnPoint.Z) + Vector3.new(0, 1, 0)
		spawn.Parent = workspace
	end
end

return WorldService
