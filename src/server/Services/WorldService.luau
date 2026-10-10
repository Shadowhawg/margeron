-- Generates a placeholder world (terrain, town, zone landmarks, lighting) so the game is playable
-- before any map is built. If Workspace contains a Folder named "Map", generation is skipped and
-- positions can be overridden with Parts in Map/Markers named after NPC or zone ids.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local ModelBuilder = require(script.Parent.Parent.Lib.ModelBuilder)

local WorldService = {}

local terrain = workspace.Terrain
local propsFolder

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

-- Raycast down to find the ground under a point.
function WorldService.GroundAt(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local include = { terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(include, map)
	end
	params.FilterDescendantsInstances = include
	local result = workspace:Raycast(Vector3.new(position.X, 250, position.Z), Vector3.new(0, -500, 0), params)
	return result and result.Position or Vector3.new(position.X, 0, position.Z)
end

local function prop(props)
	local p = ModelBuilder.Part(props)
	p.Anchored = true
	p.Parent = propsFolder
	return p
end

local rng = Random.new(1337)

local function tree(position, scale, leafColor)
	local ground = WorldService.GroundAt(position)
	local h = 10 * scale
	prop({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(ground + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 65, 45),
		Material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		local size = (8 - i * 1.6) * scale
		prop({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = ground + Vector3.new(rng:NextNumber(-1, 1), h * 0.65 + i * 2.6 * scale, rng:NextNumber(-1, 1)),
			Color = leafColor,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

local function rock(position, size, color)
	local ground = WorldService.GroundAt(position)
	prop({
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(ground + Vector3.new(0, size.Y / 2 - 0.5, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
		Color = color or Color3.fromRGB(110, 110, 115),
		Material = Enum.Material.Slate,
	})
end

local function house(position, rotation, wallColor)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
	local w, d, h = 16, 14, 10
	prop({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = base * CFrame.new(0, h / 2, 0), Color = wallColor, Material = Enum.Material.WoodPlanks })
	prop({ Name = "Door", Size = Vector3.new(4, 7, 0.4), CFrame = base * CFrame.new(0, 3.5, -d / 2 - 0.1), Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.Wood })
	for side = -1, 1, 2 do
		prop({
			Name = "Roof",
			Size = Vector3.new(w + 2, 0.8, d / 2 / math.cos(math.rad(35)) + 1),
			CFrame = base * CFrame.new(0, h + 2.6, side * d / 4) * CFrame.Angles(math.rad(35) * side, 0, 0),
			Color = Color3.fromRGB(120, 50, 40),
			Material = Enum.Material.Slate,
		})
	end
end

local function torch(position)
	local ground = WorldService.GroundAt(position)
	prop({ Name = "Post", Size = Vector3.new(0.5, 6, 0.5), Position = ground + Vector3.new(0, 3, 0), Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood })
	local flame = prop({ Name = "Flame", Size = Vector3.new(0.8, 0.8, 0.8), Position = ground + Vector3.new(0, 6.4, 0), Color = Color3.fromRGB(255, 160, 60), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 20
	light.Brightness = 1.5
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Parent = flame
end

local function buildTown()
	local town = World.Town
	terrain:FillCylinder(CFrame.new(town.Position + Vector3.new(0, -2, 0)), 4.2, town.Radius * 0.55, Enum.Material.Cobblestone)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + 0.3
		local pos = town.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (town.Radius * 0.75)
		local colors = { Color3.fromRGB(160, 130, 95), Color3.fromRGB(140, 115, 85), Color3.fromRGB(175, 150, 115) }
		house(WorldService.GroundAt(pos), -math.deg(angle) - 90, colors[i % 3 + 1])
	end
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		torch(town.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 26)
	end
	-- Forge next to the blacksmith
	local forge = WorldService.GetNPCPosition("Blacksmith") + Vector3.new(6, 0, -4)
	prop({ Name = "Forge", Size = Vector3.new(5, 3.5, 5), Position = WorldService.GroundAt(forge) + Vector3.new(0, 1.75, 0), Color = Color3.fromRGB(80, 75, 75), Material = Enum.Material.Brick })
	torch(forge + Vector3.new(0, 0, 0.1))
	prop({ Name = "Anvil", Size = Vector3.new(2.5, 1.5, 1.2), Position = WorldService.GroundAt(forge + Vector3.new(-5, 0, 2)) + Vector3.new(0, 0.75, 0), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
end

local function buildZone(zoneId, zone)
	local center = WorldService.GetZonePosition(zoneId)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4.1, zone.Radius, zone.Material)

	if zoneId == "WolfWoods" then
		for _ = 1, 45 do
			local r = math.sqrt(rng:NextNumber()) * zone.Radius * 1.1
			local a = rng:NextNumber(0, math.pi * 2)
			tree(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(0.9, 1.5), Color3.fromRGB(45, 90, 50))
		end
	elseif zoneId == "BanditCamp" then
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2
			if i ~= 0 and i ~= 1 then -- leave a gap for the gate
				local pos = WorldService.GroundAt(center + Vector3.new(math.cos(a), 0, math.sin(a)) * zone.Radius * 0.85)
				prop({ Name = "Palisade", Size = Vector3.new(2, 12, 2), Position = pos + Vector3.new(0, 5, 0), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood })
			end
		end
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			local pos = WorldService.GroundAt(center + Vector3.new(math.cos(a), 0, math.sin(a)) * 30)
			local tentCf = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, a, 0)
			for side = -1, 1, 2 do
				local wedge = Instance.new("WedgePart")
				wedge.Name = "Tent"
				wedge.Anchored = true
				wedge.Size = Vector3.new(8, 6, 4)
				wedge.CFrame = tentCf * CFrame.new(0, 0, side * 2) * CFrame.Angles(0, side == 1 and math.pi or 0, 0)
				wedge.Color = Color3.fromRGB(150, 50, 45)
				wedge.Material = Enum.Material.Fabric
				wedge.Parent = propsFolder
			end
		end
		torch(center)
	elseif zoneId == "HollowCrypt" then
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			local pos = WorldService.GroundAt(center + Vector3.new(math.cos(a), 0, math.sin(a)) * zone.Radius * 0.7)
			prop({ Name = "Pillar", Size = Vector3.new(3, 16, 3), Position = pos + Vector3.new(0, 7, 0), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Slate })
		end
		local ground = WorldService.GroundAt(center)
		prop({ Name = "CryptEntrance", Size = Vector3.new(20, 12, 10), Position = ground + Vector3.new(0, 6, -zone.Radius * 0.4), Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Slate })
		prop({ Name = "CryptDoor", Size = Vector3.new(6, 8, 0.5), Position = ground + Vector3.new(0, 4, -zone.Radius * 0.4 + 5.1), Color = Color3.new(0, 0, 0), Material = Enum.Material.Slate })
		for _ = 1, 12 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(10, zone.Radius * 0.9)
			prop({ Name = "Gravestone", Size = Vector3.new(2.5, 3.5, 0.6), Position = WorldService.GroundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Slate })
		end
	elseif zoneId == "CinderPeak" then
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local h = rng:NextNumber(18, 34)
			local pos = WorldService.GroundAt(center + Vector3.new(math.cos(a), 0, math.sin(a)) * zone.Radius * 1.05)
			prop({ Name = "Spire", Size = Vector3.new(7, h, 7), CFrame = CFrame.new(pos + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, a, rng:NextNumber(-0.15, 0.15)), Color = Color3.fromRGB(45, 40, 40), Material = Enum.Material.Basalt })
		end
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -1.9, 0)), 4, 10, Enum.Material.CrackedLava)
	elseif zoneId == "FrostHollow" then
		for _ = 1, 25 do
			local r = math.sqrt(rng:NextNumber()) * zone.Radius
			local a = rng:NextNumber(0, math.pi * 2)
			tree(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(1, 1.6), Color3.fromRGB(220, 235, 240))
		end
		for _ = 1, 10 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(10, zone.Radius)
			rock(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(3, 6), rng:NextNumber(4, 9)), Color3.fromRGB(170, 190, 200))
		end
	end

	-- Signpost at the zone edge closest to town
	local toTown = (World.Town.Position - center)
	toTown = Vector3.new(toTown.X, 0, toTown.Z).Unit
	local signPos = WorldService.GroundAt(center + toTown * (zone.Radius + 8))
	prop({ Name = "SignPost", Size = Vector3.new(0.6, 6, 0.6), Position = signPos + Vector3.new(0, 3, 0), Color = Color3.fromRGB(90, 65, 45), Material = Enum.Material.Wood })
	local board = prop({ Name = "Sign", Size = Vector3.new(7, 2, 0.4), CFrame = CFrame.lookAt(signPos + Vector3.new(0, 5.5, 0), signPos + Vector3.new(0, 5.5, 0) + toTown), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.WoodPlanks })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.Text = zone.Name .. "  (Lv " .. zone.Levels .. ")"
	label.Parent = gui
	gui.Parent = board
end

local function buildPaths()
	-- Dirt roads from town to each zone.
	for zoneId in pairs(World.Zones) do
		local from = World.Town.Position
		local to = WorldService.GetZonePosition(zoneId)
		local steps = math.floor((to - from).Magnitude / 8)
		for i = 0, steps do
			local p = from:Lerp(to, i / steps)
			terrain:FillCylinder(CFrame.new(p + Vector3.new(0, -1.95, 0)), 4.05, 6, Enum.Material.Mud)
		end
	end
end

local function buildTerrain()
	local size = World.MapSize
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(size, 12, size), Enum.Material.Grass)
	-- River south of town
	terrain:FillBlock(CFrame.new(0, -3, 95), Vector3.new(size, 6, 18), Enum.Material.Water)
	prop({ Name = "Bridge", Size = Vector3.new(14, 1, 26), Position = Vector3.new(0, 0.3, 95), Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.WoodPlanks })
	-- Mountains around the edge keep players inside the map.
	local edge = size / 2
	for i = 0, 63 do
		local a = i / 64 * math.pi * 2
		local r = edge - 30
		local pos = Vector3.new(math.cos(a) * r, -10, math.sin(a) * r)
		terrain:FillBall(pos, rng:NextNumber(45, 70), Enum.Material.Rock)
		terrain:FillBall(pos + Vector3.new(0, 35, 0), rng:NextNumber(18, 28), Enum.Material.Snow)
	end
	-- Scatter trees and rocks in the open fields.
	for _ = 1, 90 do
		local pos = Vector3.new(rng:NextNumber(-edge + 80, edge - 80), 0, rng:NextNumber(-edge + 80, edge - 80))
		local clear = (pos - World.Town.Position).Magnitude > World.Town.Radius + 15 and math.abs(pos.Z - 95) > 20
		for _, zone in pairs(World.Zones) do
			if (pos - zone.Position).Magnitude < zone.Radius + 20 then
				clear = false
			end
		end
		if clear then
			if rng:NextNumber() < 0.75 then
				tree(pos, rng:NextNumber(0.8, 1.4), Color3.fromRGB(60, 110, 55))
			else
				rock(pos, Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 5), rng:NextNumber(3, 8)))
			end
		end
	end
end

local function setupLighting()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 115, 130)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 190, 175)
	atmosphere.Decay = Color3.fromRGB(110, 95, 90)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

function WorldService.Init()
	if workspace:FindFirstChild("Map") then
		print("[WorldService] Custom Map found, skipping world generation")
	else
		propsFolder = Instance.new("Folder")
		propsFolder.Name = "GeneratedWorld"
		propsFolder.Parent = workspace
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
		buildTerrain()
		buildPaths()
		buildTown()
		for zoneId, zone in pairs(World.Zones) do
			buildZone(zoneId, zone)
		end
		setupLighting()
	end

	if not workspace:FindFirstChild("MargeronSpawn", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "MargeronSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0
		spawn.Position = WorldService.GroundAt(World.SpawnPoint) + Vector3.new(0, 0.5, 0)
		spawn.Parent = workspace
	end
end

return WorldService
