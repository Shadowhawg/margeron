--!native
-- Generates the open-world terrain from Config/World: rolling hills, mountain borders, a volcano,
-- flattened town/zone areas, lakes, a winding river and roads, written with Terrain:WriteVoxels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Config.World)

local TerrainGen = {}

local RES = 4
local CHUNK = 16 -- columns per chunk side (64 studs); small chunks waste fewer air voxels
local FLOOR_Y = -16
local HALF = World.MapHalfSize
local WATER = World.WaterLevel
local SEED = World.Seed * 0.0137

local M = Enum.Material

local function smoothstep(edge0, edge1, x)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function flatDist(x, z, pos)
	local dx, dz = x - pos.X, z - pos.Z
	return math.sqrt(dx * dx + dz * dz)
end

function TerrainGen.RiverZ(x)
	local r = World.River
	return r.BaseZ + r.Amplitude * math.sin(x / r.Wavelength)
end

local function rawHeight(x, z)
	local h = 6
		+ math.noise(x / 420, z / 420, SEED) * 36
		+ math.noise(x / 130, z / 130, SEED + 5.3) * 10
		+ math.noise(x / 38, z / 38, SEED + 9.1) * 2
	-- Mountains ring the map edge.
	local edge = math.max(math.abs(x), math.abs(z)) / HALF
	if edge > 0.78 then
		h += ((edge - 0.78) / 0.22) ^ 1.5 * 240 + math.noise(x / 90, z / 90, SEED + 2) * 30 * (edge - 0.78) / 0.22
	end
	return h
end

-- Areas that get flattened to a target height: { X, Z, Radius, Blend, Target }
local flats = {}
local function addFlat(pos, radius, blend, target)
	table.insert(flats, { X = pos.X, Z = pos.Z, Radius = radius, Blend = blend, Target = target })
end

local volcano = World.Volcano
local frost = World.Zones.FrostHollow

local function shapedHeight(x, z)
	local h = rawHeight(x, z)

	local dv = flatDist(x, z, volcano.Position)
	if dv < volcano.BaseRadius then
		local t = smoothstep(volcano.BaseRadius, volcano.TopRadius, dv)
		h = lerp(h, volcano.Height, t)
	end

	if frost then
		local df = flatDist(x, z, frost.Position)
		h += 22 * smoothstep(frost.Radius * 1.8, frost.Radius * 0.7, df)
	end

	for _, f in ipairs(flats) do
		local dx, dz = x - f.X, z - f.Z
		local d2 = dx * dx + dz * dz
		local outer = f.Radius + f.Blend
		if d2 < outer * outer then
			h = lerp(h, f.Target, smoothstep(outer, f.Radius, math.sqrt(d2)))
		end
	end

	for _, lake in ipairs(World.Lakes) do
		local d = flatDist(x, z, lake.Position)
		local outer = lake.Radius + 45
		if d < outer then
			h = lerp(h, -10, smoothstep(outer, lake.Radius * 0.6, d))
			if lake.Island and d < lake.Island + 12 then
				h = lerp(h, 4, smoothstep(lake.Island + 12, lake.Island, d))
			end
		end
	end

	local river = World.River
	local dz = math.abs(z - TerrainGen.RiverZ(x))
	if dz < river.Width + 34 then
		h = lerp(h, -7, smoothstep(river.Width + 34, river.Width * 0.5, dz))
	end

	-- The Crown City: a lake (the river flows into it) with a flat island plateau.
	local city = World.City
	if city then
		local dc = flatDist(x, z, city.Position)
		if dc < city.LakeRadius + 50 then
			h = lerp(h, -12, smoothstep(city.LakeRadius + 50, city.LakeRadius - 20, dc))
			if dc < city.IslandRadius + 30 then
				h = lerp(h, city.Height, smoothstep(city.IslandRadius + 30, city.IslandRadius, dc))
			end
		end
	end
	return h
end

-- Final terrain height at a point (no raycast needed).
function TerrainGen.HeightAt(x, z)
	return shapedHeight(x, z)
end

function TerrainGen.IsWater(x, z)
	return shapedHeight(x, z) < WATER + 0.5
end

-- Road segments: { A = Vector3, B = Vector3 }
local roads = {}
local function roadDistance(x, z, list)
	local best = math.huge
	for _, seg in ipairs(list) do
		local ax, az, bx, bz = seg.A.X, seg.A.Z, seg.B.X, seg.B.Z
		local vx, vz = bx - ax, bz - az
		local len2 = vx * vx + vz * vz
		local t = math.clamp(((x - ax) * vx + (z - az) * vz) / len2, 0, 1)
		local px, pz = ax + vx * t - x, az + vz * t - z
		local d = math.sqrt(px * px + pz * pz)
		if d < best then
			best = d
		end
	end
	return best
end

-- Zones with a ground material: { X, Z, Radius, Material }
local paint = {}

local function surfaceMaterial(x, z, h, slope, roadList)
	if h < WATER + 1.2 then
		return M.Sand
	end
	local dv = flatDist(x, z, volcano.Position)
	if dv < volcano.BaseRadius * 0.85 then
		if dv < volcano.TopRadius * 0.35 then
			return M.CrackedLava
		end
		return dv < volcano.BaseRadius * 0.6 and M.Basalt or M.Rock
	end
	if h > 175 then
		return M.Snow
	end
	if slope > 1.1 then
		return M.Rock
	end
	if #roadList > 0 and roadDistance(x, z, roadList) < 5 then
		return flatDist(x, z, World.Town.Position) < World.Town.Radius and M.Cobblestone or M.Mud
	end
	for _, p in ipairs(paint) do
		local dx, dz = x - p.X, z - p.Z
		if dx * dx + dz * dz < p.Radius * p.Radius then
			return p.Material
		end
	end
	if h > 95 then
		return slope > 0.6 and M.Rock or M.Slate
	end
	local n = math.noise(x / 70, z / 70, SEED + 17)
	if n > 0.2 then
		return M.LeafyGrass
	elseif n < -0.32 then
		return M.Ground
	end
	return M.Grass
end

local function underMaterial(surface)
	if
		surface == M.Snow
		or surface == M.Rock
		or surface == M.Slate
		or surface == M.Basalt
		or surface == M.CrackedLava
	then
		return M.Rock
	end
	if surface == M.Sand then
		return M.Sandstone
	end
	return M.Ground
end

-- positions: table name -> Vector3 for roads ("Town", zone ids, landmark ids, "Farmlands")
function TerrainGen.Generate(positions, onProgress)
	table.clear(flats)
	table.clear(roads)
	table.clear(paint)

	local town = World.Town
	addFlat(town.Position, town.Radius, 60, 4)
	addFlat(World.Farmlands.Position, World.Farmlands.Radius, 80, 3)
	for zoneId, zone in pairs(World.Zones) do
		if zoneId ~= "CinderPeak" then
			local target = math.max(4, rawHeight(zone.Position.X, zone.Position.Z))
			if zoneId == "FrostHollow" then
				target += 22
			end
			addFlat(zone.Position, zone.Radius * 0.75, 70, target)
		end
		table.insert(paint, {
			X = zone.Position.X,
			Z = zone.Position.Z,
			Radius = zone.Radius * (zone.Biome == "Snow" and 1.6 or 1.05),
			Material = zone.Material,
		})
	end
	for _, landmark in ipairs(World.Landmarks) do
		if landmark.Kind ~= "Shrine" then
			local target = math.max(4, rawHeight(landmark.Position.X, landmark.Position.Z))
			addFlat(landmark.Position, 22, 30, target)
		end
	end
	table.insert(paint, { X = town.Position.X, Z = town.Position.Z, Radius = 60, Material = M.Cobblestone })
	if World.City then
		local c = World.City.Position
		table.insert(paint, 1, { X = c.X, Z = c.Z, Radius = World.City.IslandRadius - 8, Material = M.Pavement })
	end

	for _, road in ipairs(World.Roads) do
		local a, b = positions[road.From], positions[road.To]
		if a and b then
			table.insert(roads, { A = a, B = b })
		end
	end

	local columns = math.floor(HALF * 2 / RES)
	local chunks = math.ceil(columns / CHUNK)
	local lastYield = os.clock()
	local done = 0

	for cx = 0, chunks - 1 do
		for cz = 0, chunks - 1 do
			local x0 = -HALF + cx * CHUNK * RES
			local z0 = -HALF + cz * CHUNK * RES

			-- Roads near this chunk only
			local near = {}
			for _, seg in ipairs(roads) do
				local minX, maxX = math.min(seg.A.X, seg.B.X) - 10, math.max(seg.A.X, seg.B.X) + 10
				local minZ, maxZ = math.min(seg.A.Z, seg.B.Z) - 10, math.max(seg.A.Z, seg.B.Z) + 10
				if maxX >= x0 and minX <= x0 + CHUNK * RES and maxZ >= z0 and minZ <= z0 + CHUNK * RES then
					table.insert(near, seg)
				end
			end

			-- Heights with a one-column border for slopes
			local heights = {}
			local maxH = WATER
			for i = 0, CHUNK do
				local row = {}
				heights[i] = row
				local x = x0 + i * RES + RES / 2
				for k = 0, CHUNK do
					local h = shapedHeight(x, z0 + k * RES + RES / 2)
					row[k] = h
					if h > maxH then
						maxH = h
					end
				end
			end

			local topY = math.ceil((maxH + 8) / RES) * RES
			local sizeY = (topY - FLOOR_Y) / RES
			local materials, occupancy = {}, {}
			for i = 1, CHUNK do
				local matX, occX = {}, {}
				materials[i], occupancy[i] = matX, occX
				for y = 1, sizeY do
					matX[y], occX[y] = {}, {}
				end
				local x = x0 + (i - 1) * RES + RES / 2
				for k = 1, CHUNK do
					local h = heights[i - 1][k - 1]
					local slope = math.max(math.abs(heights[i][k - 1] - h), math.abs(heights[i - 1][k] - h)) / RES
					local z = z0 + (k - 1) * RES + RES / 2
					local surface = surfaceMaterial(x, z, h, slope, near)
					local under = underMaterial(surface)
					for y = 1, sizeY do
						local bottom = FLOOR_Y + (y - 1) * RES
						local top = bottom + RES
						local mat, occ
						if top <= h then
							mat = (h - top) < RES * 1.5 and surface or under
							occ = 1
						elseif bottom < h then
							mat = surface
							occ = math.max(0.05, (h - bottom) / RES)
						elseif bottom < WATER then
							mat = M.Water
							occ = 1
						else
							mat = M.Air
							occ = 0
						end
						matX[y][k] = mat
						occX[y][k] = occ
					end
				end
			end

			local region =
				Region3.new(Vector3.new(x0, FLOOR_Y, z0), Vector3.new(x0 + CHUNK * RES, topY, z0 + CHUNK * RES))
			workspace.Terrain:WriteVoxels(region, RES, materials, occupancy)

			done += 1
			if os.clock() - lastYield > 0.05 then
				if onProgress then
					onProgress(done / (chunks * chunks))
				end
				task.wait()
				lastYield = os.clock()
			end
		end
	end
end

-- Points where roads cross the river (for bridges): { Position = Vector3, Direction = Vector3 }
function TerrainGen.RiverCrossings()
	local crossings = {}
	for _, seg in ipairs(roads) do
		local steps = math.floor((seg.B - seg.A).Magnitude / 4)
		local prev = nil
		for i = 0, steps do
			local p = seg.A:Lerp(seg.B, i / steps)
			local side = p.Z - TerrainGen.RiverZ(p.X) > 0
			if prev ~= nil and side ~= prev then
				local dir = (seg.B - seg.A) * Vector3.new(1, 0, 1)
				table.insert(
					crossings,
					{ Position = Vector3.new(p.X, 0, TerrainGen.RiverZ(p.X)), Direction = dir.Unit }
				)
			end
			prev = side
		end
	end
	return crossings
end

function TerrainGen.Roads()
	return roads
end

TerrainGen.Smoothstep = smoothstep

return TerrainGen
