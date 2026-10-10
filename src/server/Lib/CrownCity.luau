-- Builds Aurelion, the Crown City: an island capital ringed by tall walls, reached by a long
-- causeway, with the White Tower and palace at its heart, a market, a temple-college, an arena,
-- memorial gardens and stone townhouses along its avenues.
--
-- Layout is written in "city space": the gate is at -X (west). City.Point rotates it to the real
-- gate direction from Config/World.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Config.World)
local Architecture = require(script.Parent.Architecture)
local Props = require(script.Parent.Props)
local ModelBuilder = require(script.Parent.ModelBuilder)

local CrownCity = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local LIMESTONE = rgb(214, 206, 188)
local MARBLE = rgb(236, 232, 224)
local GOLD = rgb(222, 180, 80)
local SLATE_BLUE = rgb(58, 68, 100)
local CRIMSON = rgb(140, 28, 40)

local rng = Random.new(77)

function CrownCity.Build(groundAt)
	local city = World.City
	local center = city.Position
	local rotation = city.GateAngle - math.pi
	local part = Architecture.Part

	-- city space -> world helpers
	local function at(x, z)
		local p = city.Point(x, z)
		return groundAt(p.X, p.Z)
	end
	local function dir(x, z)
		local p = city.Point(x, z) - center
		return Vector3.new(p.X, 0, p.Z).Unit
	end
	local function cityAngle(localAngle)
		return localAngle + rotation
	end
	local H = city.Height
	local plaza = groundAt(center.X, center.Z)

	-- Causeway across the lake ---------------------------------------------------------
	local startX, endX = -420, -(city.WallRadius - 4)
	local steps = math.floor((endX - startX) / 16)
	for i = 0, steps - 1 do
		local x0 = startX + i * (endX - startX) / steps
		local x1 = startX + (i + 1) * (endX - startX) / steps
		local p0, p1 = at(x0, 0), at(x1, 0)
		local y0, y1 = math.max(H, p0.Y) + 0.6, math.max(H, p1.Y) + 0.6
		local a = Vector3.new(p0.X, y0, p0.Z)
		local b = Vector3.new(p1.X, y1, p1.Z)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		part({
			Name = "Causeway",
			Size = Vector3.new(18, 1.4, (b - a).Magnitude + 0.3),
			CFrame = cf,
			Color = LIMESTONE,
			Material = Enum.Material.Limestone,
		})
		for side = -1, 1, 2 do
			part({
				Name = "Parapet",
				Size = Vector3.new(1, 2.4, (b - a).Magnitude + 0.3),
				CFrame = cf * CFrame.new(side * 8.5, 1.9, 0),
				Color = LIMESTONE,
				Material = Enum.Material.Limestone,
			})
		end
		if i % 2 == 0 and p0.Y < 1 then
			local depth = y0 + 16
			part({
				Name = "Pier",
				Size = Vector3.new(14, depth, 4),
				CFrame = CFrame.lookAt(Vector3.new(a.X, y0 - depth / 2, a.Z), Vector3.new(b.X, y0 - depth / 2, b.Z)),
				Color = rgb(170, 165, 150),
				Material = Enum.Material.Limestone,
			})
		end
		if i % 3 == 0 then
			Architecture.Lamp(a + cf.RightVector * 8.5 + Vector3.new(0, 1, 0))
		end
	end
	Props.Sign(at(-432, 10), city.Name .. " - " .. city.Title, dir(-1, 0) * -1)

	-- Outer walls -------------------------------------------------------------------------
	Architecture.CurtainWall(center, city.WallRadius, 24, groundAt, {
		Gates = { city.GateAngle },
		Segments = 72,
		TowerEvery = 6,
		RoundTowers = true,
		TowerRadius = 8,
		Thickness = 6,
		GateWidth = 18,
		Color = LIMESTONE,
		Material = Enum.Material.Limestone,
		Roof = SLATE_BLUE,
		Banner = CRIMSON,
	})

	-- Streets -----------------------------------------------------------------------------
	-- The arena (east), temple (south) and memorial gardens (north) are open plazas: the ring road
	-- and the avenues stop at their edges instead of running through them.
	local plazas = {
		{ X = 150, Z = 0, R = 46 }, -- arena
		{ X = 0, Z = -150, R = 40 }, -- temple
		{ X = 0, Z = 150, R = 40 }, -- gardens
	}
	local function inPlaza(x, z, margin)
		for _, p in ipairs(plazas) do
			if (x - p.X) ^ 2 + (z - p.Z) ^ 2 < (p.R + (margin or 0)) ^ 2 then
				return true
			end
		end
		return false
	end
	local paving = { Color = rgb(200, 195, 185), Material = Enum.Material.Pavement }
	Architecture.Street(at(-city.WallRadius - 6, 0), at(-70, 0), 14, groundAt, paving)
	for _, a in ipairs({ 0, math.pi / 2, -math.pi / 2 }) do
		Architecture.Street(
			at(math.cos(a) * 70, math.sin(a) * 70),
			at(math.cos(a) * 106, math.sin(a) * 106),
			12,
			groundAt,
			paving
		)
	end
	local ringPoints = 40
	for i = 0, ringPoints - 1 do
		local a0, a1 = i / ringPoints * math.pi * 2, (i + 1) / ringPoints * math.pi * 2
		local am = (a0 + a1) / 2
		if not inPlaza(math.cos(am) * 120, math.sin(am) * 120, 4) then
			Architecture.Street(
				at(math.cos(a0) * 120, math.sin(a0) * 120),
				at(math.cos(a1) * 120, math.sin(a1) * 120),
				12,
				groundAt,
				paving
			)
		end
		local lx, lz = math.cos(a0) * 128, math.sin(a0) * 128
		if i % 3 == 0 and not inPlaza(lx, lz, 2) then
			Architecture.Lamp(at(lx, lz))
		end
	end
	for _, r in ipairs({ 80, 100, 145, 165 }) do
		for _, a in ipairs({ math.pi, 0, math.pi / 2, -math.pi / 2 }) do
			-- Just outside the avenue's edge, clear of the houses lining it.
			local x, z = math.cos(a) * r + math.sin(a) * 8.5, math.sin(a) * r - math.cos(a) * 8.5
			if not inPlaza(x, z, 2) then
				Architecture.Lamp(at(x, z))
			end
		end
	end

	-- Palace district: inner wall, White Tower and four palace wings ---------------------
	Architecture.CurtainWall(center, 62, 14, groundAt, {
		Gates = { cityAngle(0), cityAngle(math.pi / 2), cityAngle(math.pi), cityAngle(-math.pi / 2) },
		Segments = 36,
		TowerEvery = 9,
		RoundTowers = true,
		TowerRadius = 5,
		Thickness = 4,
		GateWidth = 12,
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Roof = SLATE_BLUE,
		Banner = CRIMSON,
	})

	-- The White Tower
	local towerH = 150
	part({
		Name = "TowerDrum",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 42, 42),
		CFrame = CFrame.new(plaza + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	part({
		Name = "WhiteTower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(towerH, 24, 24),
		CFrame = CFrame.new(plaza + Vector3.new(0, towerH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(245, 243, 238),
		Material = Enum.Material.Marble,
	})
	for y = 25, towerH - 10, 25 do
		part({
			Name = "GoldBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 25.4, 25.4),
			CFrame = CFrame.new(plaza + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = GOLD,
			Material = Enum.Material.Metal,
		})
	end
	part({
		Name = "Balcony",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 34, 34),
		CFrame = CFrame.new(plaza + Vector3.new(0, towerH - 22, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part({
			Name = "BalconyPillar",
			Size = Vector3.new(1, 6, 1),
			Position = plaza + Vector3.new(math.cos(a) * 16, towerH - 18.5, math.sin(a) * 16),
			Color = MARBLE,
			Material = Enum.Material.Marble,
		})
	end
	part({
		Name = "Crown",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 30, 30),
		CFrame = CFrame.new(plaza + Vector3.new(0, towerH + 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part({
			Name = "CrownPoint",
			Size = Vector3.new(2, 7, 2),
			Position = plaza + Vector3.new(math.cos(a) * 14, towerH + 8, math.sin(a) * 14),
			Color = GOLD,
			Material = Enum.Material.Metal,
		})
	end
	for i = 0, 4 do
		local r = 9 - i * 1.8
		part({
			Name = "Spire",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, r * 2, r * 2),
			CFrame = CFrame.new(plaza + Vector3.new(0, towerH + 7 + i * 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(245, 243, 238),
			Material = Enum.Material.Marble,
		})
	end
	local beacon = part({
		Name = "CrownLight",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		Position = plaza + Vector3.new(0, towerH + 34, 0),
		Color = rgb(255, 225, 140),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 220, 150)
	light.Range = 40
	light.Brightness = 0.8
	light.Parent = beacon

	-- Palace wings around the tower, each with a passage through the middle.
	for k = 0, 3 do
		local a = k * math.pi / 2
		local wingCenter = at(math.cos(a) * 40, math.sin(a) * 40)
		local facing = dir(-math.cos(a), -math.sin(a))
		local cf = CFrame.lookAt(wingCenter, wingCenter + facing)
		for side = -1, 1, 2 do
			part({
				Name = "PalaceWing",
				Size = Vector3.new(17, 20, 14),
				CFrame = cf * CFrame.new(side * 13.5, 10, 0),
				Color = MARBLE,
				Material = Enum.Material.Marble,
			})
			part({
				Name = "PalaceRoof",
				Size = Vector3.new(19, 2, 16),
				CFrame = cf * CFrame.new(side * 13.5, 21, 0),
				Color = SLATE_BLUE,
				Material = Enum.Material.Slate,
			})
			for c = 0, 2 do
				part({
					Name = "Column",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(18, 2, 2),
					CFrame = cf * CFrame.new(side * (8 + c * 5.5), 9, -8) * CFrame.Angles(0, 0, math.rad(90)),
					Color = MARBLE,
					Material = Enum.Material.Marble,
				})
			end
			part({
				Name = "Banner",
				Size = Vector3.new(3, 9, 0.2),
				CFrame = cf * CFrame.new(side * 13.5, 12, -7.2),
				Color = CRIMSON,
				Material = Enum.Material.Fabric,
				CanCollide = false,
			})
		end
		part({
			Name = "PassageArch",
			Size = Vector3.new(10, 6, 14),
			CFrame = cf * CFrame.new(0, 17, 0),
			Color = MARBLE,
			Material = Enum.Material.Marble,
		})
		part({
			Name = "Pediment",
			Size = Vector3.new(30, 3, 2),
			CFrame = cf * CFrame.new(0, 19.5, -7.5),
			Color = GOLD,
			Material = Enum.Material.Metal,
		})
	end
	-- Courtyard gardens between tower and wings
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local g = at(math.cos(a) * 30, math.sin(a) * 30)
		part({
			Name = "CourtGarden",
			Size = Vector3.new(14, 0.6, 14),
			Position = g + Vector3.new(0, 0.3, 0),
			Color = rgb(80, 130, 70),
			Material = Enum.Material.Grass,
		})
		Props.Tree(g, 0.7, rgb(70, 125, 65))
	end

	-- Reserved areas (no houses) ---------------------------------------------------------
	local reserved = {
		{ X = -150, Z = 0, R = 34 }, -- market
		{ X = 0, Z = -150, R = 36 }, -- temple
		{ X = 150, Z = 0, R = 42 }, -- arena
		{ X = 0, Z = 150, R = 38 }, -- gardens
		{ X = -128, Z = 62, R = 18 }, -- inn
		{ X = -160, Z = -62, R = 18 }, -- armory
	}

	-- Market plaza just inside the gate
	local market = at(-150, 0)
	Architecture.Fountain(market, 7)
	local stallColors = { CRIMSON, rgb(60, 110, 170), rgb(200, 160, 60), rgb(70, 130, 80) }
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		if math.abs(math.sin(a)) > 0.45 then -- keep the avenue clear
			local p = at(-150 + math.cos(a) * 22, math.sin(a) * 22)
			Architecture.MarketStall(p, (market - p) * Vector3.new(1, 0, 1), stallColors[i % #stallColors + 1])
		end
	end

	-- The Gilded Stag (inn) and the Royal Armory
	local innGround = at(-128, 66)
	local innCf = Architecture.House(innGround, dir(0, -1), {
		Width = 24,
		Depth = 18,
		Stories = 3,
		Wall = rgb(235, 225, 205),
		Roof = rgb(100, 50, 40),
		Shutters = CRIMSON,
		Sign = "The Gilded Stag",
	})
	local bed = part({
		Name = "InnBed",
		Size = Vector3.new(4, 3, 2),
		CFrame = innCf * CFrame.new(-8, 1.5, -11.5),
		Color = rgb(110, 80, 55),
		Material = Enum.Material.WoodPlanks,
	})
	bed:SetAttribute("Cost", World.NPCs.Innkeeper.RestCost or 15)
	CollectionService:AddTag(bed, "RestSpot")
	Architecture.House(at(-160, -66), dir(0, 1), {
		Width = 20,
		Depth = 16,
		Stories = 2,
		Base = "Stone",
		Wall = rgb(210, 205, 195),
		Roof = SLATE_BLUE,
		Shutters = rgb(60, 60, 70),
		Sign = "Royal Armory",
	})

	-- Collegium of Stars (temple-college) to the north
	local temple = at(0, -150)
	local tcf = CFrame.lookAt(temple, temple + dir(0, 1))
	part({
		Name = "TemplePlatform",
		Size = Vector3.new(44, 3, 34),
		CFrame = tcf * CFrame.new(0, 1.5, 0),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	part({
		Name = "TempleSteps",
		Size = Vector3.new(30, 1.5, 6),
		CFrame = tcf * CFrame.new(0, 0.75, -19),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	part({
		Name = "TempleHall",
		Size = Vector3.new(32, 20, 22),
		CFrame = tcf * CFrame.new(0, 13, 2),
		Color = rgb(228, 222, 210),
		Material = Enum.Material.Marble,
	})
	for x = -18, 18, 6 do
		part({
			Name = "TempleColumn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(22, 2.4, 2.4),
			CFrame = tcf * CFrame.new(x, 14, -14) * CFrame.Angles(0, 0, math.rad(90)),
			Color = MARBLE,
			Material = Enum.Material.Marble,
		})
	end
	part({
		Name = "TempleEntablature",
		Size = Vector3.new(42, 3, 8),
		CFrame = tcf * CFrame.new(0, 26.5, -11),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	part({
		Name = "TempleDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(26, 26, 26),
		CFrame = tcf * CFrame.new(0, 24, 2),
		Color = GOLD,
		Material = Enum.Material.Metal,
	})
	local star = part({
		Name = "Star",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = tcf * CFrame.new(0, 39, 2),
		Color = rgb(170, 200, 255),
		Material = Enum.Material.Neon,
	})
	local starLight = Instance.new("PointLight")
	starLight.Color = rgb(170, 200, 255)
	starLight.Range = 24
	starLight.Brightness = 0.6
	starLight.Parent = star

	-- Arena to the east
	local arena = at(150, 0)
	part({
		Name = "ArenaSand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 46, 46),
		CFrame = CFrame.new(arena + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(210, 190, 140),
		Material = Enum.Material.Sand,
	})
	local arches = 28
	for i = 0, arches - 1 do
		local a = i / arches * math.pi * 2
		local openSide = math.abs(((a - cityAngle(math.pi)) + math.pi) % (2 * math.pi) - math.pi) < 0.2
		if not openSide then
			local p = arena + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
			part({
				Name = "ArenaPier",
				Size = Vector3.new(2.6, 26, 4),
				CFrame = CFrame.new(p + Vector3.new(0, 13, 0)) * CFrame.Angles(0, -a, 0),
				Color = LIMESTONE,
				Material = Enum.Material.Limestone,
			})
			part({
				Name = "ArenaTier",
				Size = Vector3.new(6, 1.4, 7.4),
				CFrame = CFrame.new(arena + Vector3.new(math.cos(a) * 27, 4, math.sin(a) * 27))
					* CFrame.Angles(0, -a, 0),
				Color = rgb(190, 182, 165),
				Material = Enum.Material.Limestone,
			})
			-- Beams between the piers (three tiers of arches)
			local arc = 2 * math.pi * 32 / arches
			local mid = arena + Vector3.new(math.cos(a + math.pi / arches) * 32, 0, math.sin(a + math.pi / arches) * 32)
			for _, y in ipairs({ 9, 18, 26.5 }) do
				part({
					Name = "ArenaBeam",
					Size = Vector3.new(2.8, 1.8, arc + 0.6),
					CFrame = CFrame.new(mid + Vector3.new(0, y, 0)) * CFrame.Angles(0, -(a + math.pi / arches), 0),
					Color = LIMESTONE,
					Material = Enum.Material.Limestone,
				})
			end
		end
	end

	-- Memorial gardens to the south: the Ashen Guard
	local garden = at(0, 150)
	part({
		Name = "Lawn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 64, 64),
		CFrame = CFrame.new(garden + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(85, 140, 70),
		Material = Enum.Material.Grass,
	})
	for i = 0, 6 do
		local a = cityAngle(math.pi / 2) + math.pi + (i - 3) * 0.32
		local p = garden + Vector3.new(math.cos(a) * 20, 0, math.sin(a) * 20)
		local face = (garden - p) * Vector3.new(1, 0, 1)
		local cf = CFrame.lookAt(p, p + face)
		part({
			Name = "StatuePlinth",
			Size = Vector3.new(4, 3, 4),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			Color = rgb(150, 145, 140),
			Material = Enum.Material.Granite,
		})
		part({
			Name = "StatueBody",
			Size = Vector3.new(2.4, 5, 1.4),
			CFrame = cf * CFrame.new(0, 5.5, 0),
			Color = rgb(120, 120, 125),
			Material = Enum.Material.Granite,
		})
		part({
			Name = "StatueHead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = cf * CFrame.new(0, 8.8, 0),
			Color = rgb(120, 120, 125),
			Material = Enum.Material.Granite,
		})
		part({
			Name = "StatueSword",
			Size = Vector3.new(0.3, 5, 0.6),
			CFrame = cf * CFrame.new(0, 5, -1),
			Color = rgb(100, 100, 105),
			Material = Enum.Material.Granite,
		})
	end
	Props.Sign(garden + Vector3.new(0, 0, 0), "The Ashen Guard. Seven climbed. One returned.", dir(0, -1))
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(24, 32)
		Props.Tree(
			garden + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
			rng:NextNumber(0.8, 1.2),
			rgb(70, 125, 60)
		)
	end

	-- Crown Guards at the gates
	local function guard(p, facing)
		local model, info = ModelBuilder.Creature("Crown Guard", {
			Shape = "Humanoid",
			Scale = 1,
			Color = rgb(150, 155, 165),
			HeadColor = rgb(160, 165, 175),
			EyeColor = rgb(30, 30, 35),
			Anchored = true,
		})
		model:PivotTo(
			CFrame.lookAt(p + Vector3.new(0, info.GroundOffset, 0), p + Vector3.new(0, info.GroundOffset, 0) + facing)
		)
		local spear = part({
			Name = "Spear",
			Size = Vector3.new(0.3, 9, 0.3),
			CFrame = info.Root.CFrame * CFrame.new(1.6, 2, -0.6),
			Color = rgb(90, 65, 45),
			Material = Enum.Material.Wood,
		}, model)
		part({
			Name = "SpearTip",
			Size = Vector3.new(0.5, 1.2, 0.2),
			CFrame = spear.CFrame * CFrame.new(0, 5, 0),
			Color = rgb(200, 200, 210),
			Material = Enum.Material.Metal,
		}, model)
		part({
			Name = "Tabard",
			Size = Vector3.new(1.6, 2.4, 0.1),
			CFrame = info.Root.CFrame * CFrame.new(0, -0.3, -0.55),
			Color = CRIMSON,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, model)
		model.Parent = Architecture.Folder
	end
	for _, side in ipairs({ -1, 1 }) do
		guard(at(-city.WallRadius + 10, side * 12), dir(-1, 0))
		guard(at(-70, side * 10), dir(-1, 0))
	end

	-- Townhouses -----------------------------------------------------------------------
	local walls = { rgb(240, 235, 222), rgb(230, 220, 200), rgb(222, 214, 202), rgb(236, 226, 210) }
	local roofs = { SLATE_BLUE, rgb(110, 55, 45), rgb(70, 80, 70), rgb(85, 70, 80) }
	local placed = {}
	local function clear(x, z)
		local r = math.sqrt(x * x + z * z)
		if math.abs(r - 120) < 16 then
			return false -- ring street
		end
		-- avenues: west (gate), east, north, south
		-- Houses are up to ~21 studs across, so their centres stay 20 studs off an avenue's centre line.
		if (math.abs(z) < 20 and r > 60) or (math.abs(x) < 20 and r > 60) then
			return false
		end
		for _, res in ipairs(reserved) do
			if (x - res.X) ^ 2 + (z - res.Z) ^ 2 < (res.R + 10) ^ 2 then
				return false
			end
		end
		for _, p in ipairs(placed) do
			if (x - p.X) ^ 2 + (z - p.Z) ^ 2 < 21 ^ 2 then
				return false
			end
		end
		return true
	end
	for _, ring in ipairs({ { R = 86 }, { R = 104 }, { R = 140 }, { R = 160 }, { R = 174 } }) do
		local count = math.floor(2 * math.pi * ring.R / 22)
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2 + ring.R * 0.01
			local x, z = math.cos(a) * ring.R, math.sin(a) * ring.R
			if clear(x, z) then
				table.insert(placed, { X = x, Z = z })
				-- Face the ring street: houses inside it face out, houses outside it face in.
				local toward = ring.R < 120 and 1 or -1
				Architecture.House(at(x, z), dir(math.cos(a) * toward, math.sin(a) * toward), {
					Width = 15 + (i % 3) * 2,
					Depth = 13,
					Stories = 2 + (i % 3 == 0 and 1 or 0),
					Base = "Stone",
					Wall = walls[i % #walls + 1],
					Roof = roofs[(i + math.floor(ring.R)) % #roofs + 1],
					Shutters = ({ rgb(60, 70, 110), CRIMSON, rgb(50, 90, 70) })[i % 3 + 1],
				})
			end
		end
	end
end

return CrownCity
