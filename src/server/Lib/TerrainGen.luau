--!native
-- Generates the open-world terrain from Config/World and writes it with Terrain:WriteVoxels.
--
-- The land is built in layers:
--   landform   broad uplands and valleys, ridged mountain ranges, and a mountain rim at the map edge
--   detail     small bumps and gullies on top of the landform
--   shaping    the volcano, the Frosthollow plateau, and settlements gently levelled into the hills
--   roads      cut a smooth path through the land (bridges span the river where it crosses)
--   water      lakes, the river canyon, and the Crown City's lake basin with its island
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Property = require(Shared.Config.Property)

local TerrainGen = {}

local RES = 4
local CHUNK = 16 -- columns per chunk side (64 studs); small chunks waste fewer air voxels
local FLOOR_Y = -24
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

-- Sharp-crested noise for mountain ridges (1 on the crest, falling off quickly).
local function ridged(x, z, scale, seed)
	local n = math.noise(x / scale, z / scale, seed)
	local r = 1 - math.min(1, math.abs(n) * 2.4)
	return r * r * r
end

-- Large-scale shape of the land (no small detail). Also used to grade roads.
local function computeLandform(x, z)
	local h = 40
		+ math.noise(x / 1000, z / 1000, SEED) * 80
		+ math.noise(x / 300, z / 300, SEED + 5.3) * 70
		+ ridged(x, z, 240, SEED + 41) * 45 -- foothill ridges everywhere
	-- Mountain ranges only rise where the range mask allows, leaving open valleys between them.
	local rangeMask = smoothstep(-0.08, 0.22, math.noise(x / 1400, z / 1400, SEED + 21))
	if rangeMask > 0 then
		h += ridged(x, z, 620, SEED + 31) * 190 * rangeMask
	end
	-- A broken ring of hills around Riverwatch's valley: from town you see ridgelines, not the
	-- whole map. Passes open where the noise dips, and the roads and river cut through.
	local dt = math.sqrt(x * x + z * z)
	local rim = smoothstep(520, 780, dt) * (1 - smoothstep(1100, 1450, dt))
	if rim > 0 then
		local gaps = smoothstep(-0.25, 0.25, math.noise(x / 380, z / 380, SEED + 61))
		h += rim * (0.35 + 0.65 * gaps) * (55 + ridged(x, z, 280, SEED + 51) * 75)
	end
	local edge = math.max(math.abs(x), math.abs(z)) / HALF
	if edge > 0.78 then
		h += ((edge - 0.78) / 0.22) ^ 1.4 * 280
	end
	return h
end

-- The landform is smooth at this scale, so it's sampled once on a coarse grid and interpolated.
local GRID = 16
local GRID_MIN = -HALF - GRID * 4
local gridSize = math.ceil((HALF * 2 + GRID * 8) / GRID) + 1
local grid = nil

local function buildGrid()
	grid = table.create(gridSize * gridSize)
	for i = 0, gridSize - 1 do
		for k = 0, gridSize - 1 do
			grid[i * gridSize + k + 1] = computeLandform(GRID_MIN + i * GRID, GRID_MIN + k * GRID)
		end
	end
end

local function landform(x, z)
	if not grid then
		return computeLandform(x, z)
	end
	local fx, fz = (x - GRID_MIN) / GRID, (z - GRID_MIN) / GRID
	local i, k = math.clamp(math.floor(fx), 0, gridSize - 2), math.clamp(math.floor(fz), 0, gridSize - 2)
	local tx, tz = fx - i, fz - k
	local a = grid[i * gridSize + k + 1]
	local b = grid[(i + 1) * gridSize + k + 1]
	local c = grid[i * gridSize + k + 2]
	local d = grid[(i + 1) * gridSize + k + 2]
	return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * tz
end

local function detail(x, z)
	return math.noise(x / 110, z / 110, SEED + 9.1) * 16 + math.noise(x / 36, z / 36, SEED + 13.7) * 3
end

-- Areas levelled toward a target height: { X, Z, Radius, Blend, Target, Strength }
local flats = {}
local function addFlat(pos, radius, blend, target, strength)
	table.insert(
		flats,
		{ X = pos.X, Z = pos.Z, Radius = radius, Blend = blend, Target = target, Strength = strength or 1 }
	)
end

local volcano = World.Volcano
local frost = World.Zones.FrostHollow

-- Volcano, plateau and settlement levelling, applied to any base height.
local function shape(h, x, z)
	local dv = flatDist(x, z, volcano.Position)
	if dv < volcano.BaseRadius then
		h = lerp(h, volcano.Height, smoothstep(volcano.BaseRadius, volcano.TopRadius, dv))
	end
	if frost then
		h += 60 * smoothstep(frost.Radius * 2, frost.Radius * 0.8, flatDist(x, z, frost.Position))
	end
	for _, f in ipairs(flats) do
		local dx, dz = x - f.X, z - f.Z
		local outer = f.Radius + f.Blend
		local d2 = dx * dx + dz * dz
		if d2 < outer * outer then
			h = lerp(h, f.Target, smoothstep(outer, f.Radius, math.sqrt(d2)) * f.Strength)
		end
	end
	local city = World.City
	if city then
		-- The land dips into a broad basin around the city's lake.
		local dc = flatDist(x, z, city.Position)
		if dc < city.LakeRadius + 260 then
			h = lerp(h, 16, smoothstep(city.LakeRadius + 260, city.LakeRadius + 40, dc))
		end
	end
	return h
end

-- Smooth height used for road surfaces and bridges.
local function macroHeight(x, z)
	return shape(landform(x, z), x, z)
end

-- Road segments: { A = Vector3, B = Vector3 }
local roads = {}
local ROAD_HALF_WIDTH = 6
local ROAD_BLEND = 18

-- Closest point on any road: distance, px, pz
local function nearestRoad(x, z, list)
	local best, bx, bz = math.huge, 0, 0
	for _, seg in ipairs(list) do
		local ax, az, vx, vz = seg.A.X, seg.A.Z, seg.B.X - seg.A.X, seg.B.Z - seg.A.Z
		local t = math.clamp(((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz), 0, 1)
		local px, pz = ax + vx * t, az + vz * t
		local d = math.sqrt((px - x) ^ 2 + (pz - z) ^ 2)
		if d < best then
			best, bx, bz = d, px, pz
		end
	end
	return best, bx, bz
end

local function finalHeight(x, z, roadList)
	local h = shape(landform(x, z) + detail(x, z), x, z)

	-- Roads are graded smoothly through the hills.
	if #roadList > 0 then
		local d, px, pz = nearestRoad(x, z, roadList)
		if d < ROAD_HALF_WIDTH + ROAD_BLEND then
			h = lerp(h, macroHeight(px, pz), smoothstep(ROAD_HALF_WIDTH + ROAD_BLEND, ROAD_HALF_WIDTH, d))
		end
	end

	for _, lake in ipairs(World.Lakes) do
		local d = flatDist(x, z, lake.Position)
		local outer = lake.Radius + 90
		if d < outer then
			h = lerp(h, -10, smoothstep(outer, lake.Radius * 0.6, d))
			if lake.Island and d < lake.Island + 12 then
				h = lerp(h, 4, smoothstep(lake.Island + 12, lake.Island, d))
			end
		end
	end

	-- The river cuts a canyon through whatever it meets.
	local river = World.River
	local dz = math.abs(z - TerrainGen.RiverZ(x))
	if dz < river.Width + 34 then
		h = lerp(h, -7, smoothstep(river.Width + 34, river.Width * 0.5, dz))
	end

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
	return finalHeight(x, z, roads)
end

function TerrainGen.IsWater(x, z)
	return TerrainGen.HeightAt(x, z) < WATER + 0.5
end

-- Ground materials by region: { X, Z, Radius, Material }
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
	if h > 210 then
		return slope > 0.9 and M.Rock or M.Snow
	end
	if slope > 1.05 then
		return M.Rock -- cliffs
	end
	if #roadList > 0 and nearestRoad(x, z, roadList) < 5 then
		return flatDist(x, z, World.Town.Position) < World.Town.Radius and M.Cobblestone or M.Mud
	end
	for _, p in ipairs(paint) do
		local dx, dz = x - p.X, z - p.Z
		if dx * dx + dz * dz < p.Radius * p.Radius then
			return p.Material
		end
	end
	if h > 130 then
		return slope > 0.55 and M.Rock or M.Slate
	end
	if slope > 0.7 then
		return M.Ground
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

local function clampTarget(h, low, high)
	return math.clamp(h, low, high)
end

-- positions: table name -> Vector3 for roads ("Town", "Farmlands", "City", zone and landmark ids)
function TerrainGen.Generate(positions, onProgress)
	table.clear(flats)
	table.clear(roads)
	table.clear(paint)
	buildGrid()

	-- Settlements: levelled where they stand, blending into the surrounding hills.
	local town = World.Town
	local townHeight = clampTarget(landform(town.Position.X, town.Position.Z), 18, 40)
	addFlat(town.Position, town.Radius, 140, townHeight)
	TerrainGen.TownHeight = townHeight

	local farm = World.Farmlands
	local farmHeight = clampTarget(landform(farm.Position.X, farm.Position.Z), 14, 34)
	addFlat(farm.Position, farm.Radius * 0.8, 160, farmHeight, 0.8) -- gently rolling farmland
	for _, offset in ipairs(Property.Plots) do
		addFlat(farm.Position + offset, Property.PlotSize * 0.55, 30, farmHeight)
	end

	for zoneId, zone in pairs(World.Zones) do
		if zoneId ~= "CinderPeak" then
			-- Zones keep their surrounding hills; only the area where enemies roam is eased.
			local target = math.max(8, landform(zone.Position.X, zone.Position.Z))
			if zoneId == "FrostHollow" then
				target += 60
			end
			addFlat(zone.Position, zone.Radius * 0.45, zone.Radius * 0.8, target, 0.85)
		end
		table.insert(paint, {
			X = zone.Position.X,
			Z = zone.Position.Z,
			Radius = zone.Radius * (zone.Biome == "Snow" and 1.6 or 1.05),
			Material = zone.Material,
		})
	end
	for _, landmark in ipairs(World.Landmarks) do
		if landmark.Kind ~= "Shrine" or landmark.Id ~= "DrownedShrine" then
			-- Landmarks sit where the land puts them: towers on ridges, mines in cliffs. The pad's height
			-- is the smooth landform, the same height a road through it is graded to, so the two agree.
			local target = math.max(8, landform(landmark.Position.X, landmark.Position.Z))
			addFlat(landmark.Position, 30, 40, target)
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
	local margin = ROAD_HALF_WIDTH + ROAD_BLEND + 4

	for cx = 0, chunks - 1 do
		for cz = 0, chunks - 1 do
			local x0 = -HALF + cx * CHUNK * RES
			local z0 = -HALF + cz * CHUNK * RES

			-- Roads near this chunk only
			local near = {}
			for _, seg in ipairs(roads) do
				local minX, maxX = math.min(seg.A.X, seg.B.X) - margin, math.max(seg.A.X, seg.B.X) + margin
				local minZ, maxZ = math.min(seg.A.Z, seg.B.Z) - margin, math.max(seg.A.Z, seg.B.Z) + margin
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
					local h = finalHeight(x, z0 + k * RES + RES / 2, near)
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

-- Points where roads cross the river (for bridges): { Position = Vector3 (Y = road height), Direction }
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
				local z = TerrainGen.RiverZ(p.X)
				table.insert(
					crossings,
					{ Position = Vector3.new(p.X, math.max(4, macroHeight(p.X, z)), z), Direction = dir.Unit }
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
TerrainGen.Landform = landform

return TerrainGen
