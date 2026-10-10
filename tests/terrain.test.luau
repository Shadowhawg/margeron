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

local positions = { Town = World.Town.Position, Farmlands = World.Farmlands.Position }
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
check(math.abs(TerrainGen.HeightAt(0, 0) - 4) < 0.5, "town is flat at 4")
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
local peak = TerrainGen.HeightAt(World.Volcano.Position.X, World.Volcano.Position.Z)
check(math.abs(peak - World.Volcano.Height) < 1, "volcano summit height")
check(waterCells > 0, "water voxels written")
local crossings = TerrainGen.RiverCrossings()
check(#crossings >= 2, "roads cross the river at least twice (" .. #crossings .. ")")
summary()
