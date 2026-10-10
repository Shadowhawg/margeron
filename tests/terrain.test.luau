-- Runs the real terrain generator with a fake Terrain to check its output and cost.
local NodeMt = getmetatable(game:GetService("ReplicatedStorage"):WaitForChild("Shared"))
local function mod(path)
	return require(setmetatable({ Path = path }, NodeMt))
end

local writes, cells, waterCells = 0, 0, 0
Region3 = {
	new = function(a, b)
		return { Min = a, Max = b }
	end,
}
workspace.Terrain = {
	WriteVoxels = function(_, region, res, materials, occupancy)
		writes += 1
		local sx = (region.Max.X - region.Min.X) / res
		local sy = (region.Max.Y - region.Min.Y) / res
		local sz = (region.Max.Z - region.Min.Z) / res
		check(#materials == sx and #materials[1] == sy and #materials[1][1] == sz, "voxel array matches region")
		check(#occupancy == sx, "occupancy array matches region")
		cells += sx * sy * sz
		for _, layer in ipairs(materials[1]) do
			for _, m in ipairs(layer) do
				if m == Enum.Material.Water then
					waterCells += 1
				end
			end
		end
	end,
}

local World = mod("Shared/Config/World")
local Property = mod("Shared/Config/Property")
local TerrainGen = mod("Server/Lib/TerrainGen")

local positions = {
	Town = World.Town.Position,
	Farmlands = World.Farmlands.Position,
	City = World.City.Position,
	CityApproach = World.City.Approach,
}
for zoneId, zone in pairs(World.Zones) do
	positions[zoneId] = zone.Position
end
for _, l in ipairs(World.Landmarks) do
	positions[l.Id] = l.Position
end

local started = os.clock()
TerrainGen.Generate(positions)
local elapsed = os.clock() - started
print(string.format("Generated %d chunks, %.1fM voxels in %.2fs (standalone Luau)", writes, cells / 1e6, elapsed))

local function above(pos, label)
	local h = TerrainGen.HeightAt(pos.X, pos.Z)
	check(h > World.WaterLevel + 1, label .. " is on dry land (h=" .. string.format("%.1f", h) .. ")")
	return h
end
-- Riverwatch is level, but the land around it is not.
for _, offset in ipairs({ Vector3.new(0, 0, 0), Vector3.new(60, 0, 0), Vector3.new(-50, 0, 40), Vector3.new(0, 0, -80) }) do
	check(math.abs(TerrainGen.HeightAt(offset.X, offset.Z) - TerrainGen.TownHeight) < 1.5, "town is level")
end
-- The world has real elevation: measure the spread of heights across the map.
local lowest, highest, samples, steep = math.huge, -math.huge, 0, 0
for x = -1400, 1400, 100 do
	for z = -1400, 1400, 100 do
		local h = TerrainGen.HeightAt(x, z)
		lowest, highest = math.min(lowest, h), math.max(highest, h)
		if math.abs(TerrainGen.HeightAt(x + 8, z) - h) > 6 then
			steep += 1
		end
		samples += 1
	end
end
print(string.format("Interior heights: %.0f to %.0f studs, %d%% steep samples", lowest, highest, steep * 100 / samples))
check(highest - math.max(lowest, 0) > 180, "interior has at least 180 studs of relief")
above(World.SpawnPoint, "spawn point")
above(World.IntroPoint, "intro riverbank")
for npcId, npc in pairs(World.NPCs) do
	above(npc.Position, "NPC " .. npcId)
end
for zoneId, zone in pairs(World.Zones) do
	above(zone.Position, "zone " .. zoneId)
end
for _, l in ipairs(World.Landmarks) do
	above(l.Position, "landmark " .. l.Id)
end
for i, offset in ipairs(Property.Plots) do
	local c = World.Farmlands.Position + offset
	above(c, "plot " .. i)
	for _, corner in ipairs({
		Vector3.new(-50, 0, -50),
		Vector3.new(50, 0, 50),
		Vector3.new(-50, 0, 50),
		Vector3.new(50, 0, -50),
	}) do
		above(c + corner, "plot " .. i .. " corner")
	end
end
for _, s in ipairs(World.Stations) do
	above(s.Position, "station " .. s.Station)
end
-- The river and lakes hold water.
check(TerrainGen.IsWater(0, TerrainGen.RiverZ(0)), "river at the bridge")
check(TerrainGen.IsWater(800, TerrainGen.RiverZ(800)), "river further east")
for _, lake in ipairs(World.Lakes) do
	if lake.Island then
		check(not TerrainGen.IsWater(lake.Position.X, lake.Position.Z), lake.Name .. " has an island")
		check(TerrainGen.IsWater(lake.Position.X + lake.Radius * 0.6, lake.Position.Z), lake.Name .. " has water")
	else
		check(TerrainGen.IsWater(lake.Position.X, lake.Position.Z), lake.Name .. " has water")
	end
end
-- The Crown City island is flat and surrounded by water.
local city = World.City
check(math.abs(TerrainGen.HeightAt(city.Position.X, city.Position.Z) - city.Height) < 0.5, "city plateau height")
for _, dir in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
	local edge = city.Position + dir * (city.WallRadius + 10)
	check(math.abs(TerrainGen.HeightAt(edge.X, edge.Z) - city.Height) < 0.5, "city flat out to the walls")
	local lake = city.Position + dir * ((city.IslandRadius + city.LakeRadius) / 2 + 20)
	check(TerrainGen.IsWater(lake.X, lake.Z), "water around the city")
end
above(city.Approach, "causeway start")
local peak = TerrainGen.HeightAt(World.Volcano.Position.X, World.Volcano.Position.Z)
check(math.abs(peak - World.Volcano.Height) < 1, "volcano summit height")
check(waterCells > 0, "water voxels written")
local crossings = TerrainGen.RiverCrossings()
check(#crossings >= 2, "roads cross the river at least twice (" .. #crossings .. ")")
summary()
