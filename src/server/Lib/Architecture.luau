-- Detailed buildings made from parts: timber-framed houses, stone city walls with battlements,
-- round towers, gatehouses, street lamps and paved streets. Used by Riverwatch, the Crown City
-- and player homes. Everything is parented to Architecture.Folder unless a parent is given.
local Props = require(script.Parent.Props)

local Architecture = {}

Architecture.Folder = nil

local rng = Random.new(9001)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local TIMBER = rgb(70, 48, 32)
local STONE = rgb(132, 128, 122)
local DARK_STONE = rgb(95, 92, 90)
local IRON = rgb(45, 45, 50)

local function part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent or Architecture.Folder
	return p
end
Architecture.Part = part

local function wedge(size, cf, color, material, parent)
	return part({ ClassName = "WedgePart", Size = size, CFrame = cf, Color = color, Material = material }, parent)
end

-- A gable (triangle) of the given width (along local Z) and height, centered at cf (bottom middle).
local function gable(cf, depth, height, thickness, color, material, parent)
	wedge(
		Vector3.new(thickness, height, depth / 2),
		cf * CFrame.new(0, height / 2, -depth / 4),
		color,
		material,
		parent
	)
	wedge(
		Vector3.new(thickness, height, depth / 2),
		cf * CFrame.new(0, height / 2, depth / 4) * CFrame.Angles(0, math.pi, 0),
		color,
		material,
		parent
	)
end

local function lantern(cf, parent)
	part({
		Name = "LanternBracket",
		Size = Vector3.new(0.2, 0.2, 1),
		CFrame = cf * CFrame.new(0, 0.6, 0.5),
		Color = IRON,
		Material = Enum.Material.Metal,
	}, parent)
	local glow = part({
		Name = "Lantern",
		Size = Vector3.new(0.6, 0.8, 0.6),
		CFrame = cf * CFrame.new(0, 0.1, 1),
		Color = rgb(255, 190, 110),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, parent)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 180, 100)
	light.Range = 12
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = glow
end

-- A lit window. Front windows get open shutters; others are simpler to keep part counts down.
local function window(cf, w, h, parent, shutterColor)
	part({
		Name = "WindowGlass",
		Size = Vector3.new(w, h, 0.2),
		CFrame = cf,
		Color = rgb(255, 205, 130),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CastShadow = false,
	}, parent)
	part({
		Name = "Sill",
		Size = Vector3.new(w + 0.6, 0.3, 0.6),
		CFrame = cf * CFrame.new(0, -h / 2 - 0.15, -0.2),
		Color = TIMBER,
		Material = Enum.Material.Wood,
	}, parent)
	if shutterColor then
		part({
			Name = "Lintel",
			Size = Vector3.new(w + 0.6, 0.3, 0.4),
			CFrame = cf * CFrame.new(0, h / 2 + 0.15, -0.1),
			Color = TIMBER,
			Material = Enum.Material.Wood,
		}, parent)
		part({
			Name = "Mullion",
			Size = Vector3.new(0.15, h, 0.3),
			CFrame = cf * CFrame.new(0, 0, -0.1),
			Color = TIMBER,
			Material = Enum.Material.Wood,
		}, parent)
		for side = -1, 1, 2 do
			part({
				Name = "Shutter",
				Size = Vector3.new(w / 2, h, 0.15),
				CFrame = cf
					* CFrame.new(side * (w / 2 + w / 4 + 0.1), 0, -0.25)
					* CFrame.Angles(0, side * math.rad(15), 0),
				Color = shutterColor,
				Material = Enum.Material.WoodPlanks,
			}, parent)
		end
	end
end

--[[
	Architecture.House(ground, facing, opts) -> CFrame of the house base
	opts:
		Width, Depth      footprint (default 16 x 14)
		Stories           1-3 (default 2)
		Wall              upper-floor plaster color
		Base              ground floor material: "Stone" (default) | "Timber"
		Roof              roof color
		Shutters          shutter color
		Parent            parent instance
		Door              door color
		Sign              optional shop sign text
]]
function Architecture.House(ground, facing, opts)
	opts = opts or {}
	local parent = opts.Parent
	local w, d = opts.Width or 16, opts.Depth or 14
	local stories = opts.Stories or 2
	local wallColor = opts.Wall or rgb(225, 210, 180)
	local roofColor = opts.Roof or rgb(110, 60, 45)
	local shutterColor = opts.Shutters or rgb(60, 90, 70)
	local base = CFrame.lookAt(ground, ground + facing)
	local floorH = 9

	-- Foundation and steps
	part({
		Name = "Foundation",
		Size = Vector3.new(w + 1.5, 1.6, d + 1.5),
		CFrame = base * CFrame.new(0, 0.3, 0),
		Color = DARK_STONE,
		Material = Enum.Material.Cobblestone,
	}, parent)
	part({
		Name = "Step",
		Size = Vector3.new(5, 0.6, 2),
		CFrame = base * CFrame.new(0, 0.1, -d / 2 - 1.6),
		Color = DARK_STONE,
		Material = Enum.Material.Cobblestone,
	}, parent)

	local y = 1.1
	local topWidth, topDepth = w, d
	for story = 1, stories do
		-- Upper stories jut out a little (jettying), a classic timber-frame look.
		local jut = (story - 1) * 0.8
		local sw, sd = w + jut * 2, d + jut * 2
		local isStone = story == 1 and (opts.Base or "Stone") == "Stone"
		part({
			Name = "Story" .. story,
			Size = Vector3.new(sw, floorH, sd),
			CFrame = base * CFrame.new(0, y + floorH / 2, 0),
			Color = isStone and STONE or wallColor,
			Material = isStone and Enum.Material.Cobblestone or Enum.Material.Plaster,
		}, parent)
		if not isStone then
			-- Timber frame: corner posts, floor beams, studs and braces on the long faces.
			for _, x in ipairs({ -sw / 2, sw / 2 }) do
				for _, z in ipairs({ -sd / 2, sd / 2 }) do
					part({
						Name = "Post",
						Size = Vector3.new(0.8, floorH, 0.8),
						CFrame = base * CFrame.new(x, y + floorH / 2, z),
						Color = TIMBER,
						Material = Enum.Material.Wood,
					}, parent)
				end
			end
			for _, z in ipairs({ -sd / 2 - 0.12, sd / 2 + 0.12 }) do
				local sign = z < 0 and -1 or 1
				for _, by in ipairs({ y + 0.3, y + floorH - 0.3 }) do
					part({
						Name = "Beam",
						Size = Vector3.new(sw + 0.6, 0.6, 0.35),
						CFrame = base * CFrame.new(0, by, z),
						Color = TIMBER,
						Material = Enum.Material.Wood,
					}, parent)
				end
				for i = -1, 1, 2 do
					part({
						Name = "Stud",
						Size = Vector3.new(0.5, floorH - 0.6, 0.3),
						CFrame = base * CFrame.new(i * sw / 4, y + floorH / 2, z),
						Color = TIMBER,
						Material = Enum.Material.Wood,
					}, parent)
					local braceLen = math.sqrt((sw / 4) ^ 2 + (floorH - 1) ^ 2)
					part({
						Name = "Brace",
						Size = Vector3.new(0.4, braceLen, 0.28),
						CFrame = base
							* CFrame.new(i * sw * 3 / 8, y + floorH / 2, z + sign * 0.02)
							* CFrame.Angles(0, 0, -i * math.atan2(sw / 4, floorH - 1)),
						Color = TIMBER,
						Material = Enum.Material.Wood,
					}, parent)
				end
			end
		else
			part({
				Name = "Quoin",
				Size = Vector3.new(sw + 0.4, 0.8, sd + 0.4),
				CFrame = base * CFrame.new(0, y + floorH - 0.4, 0),
				Color = DARK_STONE,
				Material = Enum.Material.Slate,
			}, parent)
		end

		-- Windows: two on the front and back, one on each side.
		local wy = y + floorH * 0.55
		for _, x in ipairs({ -sw / 3.2, sw / 3.2 }) do
			if not (story == 1 and math.abs(x) < 3) then
				window(base * CFrame.new(x, wy, -sd / 2 - 0.12), 2.6, 3, parent, shutterColor)
				window(base * CFrame.new(x, wy, sd / 2 + 0.12) * CFrame.Angles(0, math.pi, 0), 2.6, 3, parent, nil)
			end
		end
		for side = -1, 1, 2 do
			window(
				base * CFrame.new(side * (sw / 2 + 0.12), wy, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
				2.4,
				3,
				parent,
				nil
			)
		end
		-- Flower boxes under front upper windows
		if story == 2 then
			for _, x in ipairs({ -sw / 3.2, sw / 3.2 }) do
				part({
					Name = "FlowerBox",
					Size = Vector3.new(3, 0.7, 0.9),
					CFrame = base * CFrame.new(x, wy - 2.1, -sd / 2 - 0.7),
					Color = TIMBER,
					Material = Enum.Material.Wood,
				}, parent)
				for f = -1, 1 do
					part({
						Name = "Flower",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(0.6, 0.6, 0.6),
						CFrame = base * CFrame.new(x + f * 0.9, wy - 1.55, -sd / 2 - 0.7),
						Color = ({ rgb(230, 70, 80), rgb(250, 220, 80), rgb(240, 240, 250) })[f + 2],
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
						CastShadow = false,
					}, parent)
				end
			end
		end
		y += floorH
		topWidth, topDepth = sw, sd
	end

	-- Door with frame, awning and lantern
	part({
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = base * CFrame.new(0, 1.1 + 3.5, -d / 2 - 0.15),
		Color = opts.Door or rgb(80, 50, 30),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	part({
		Name = "DoorFrameL",
		Size = Vector3.new(0.6, 7.6, 0.6),
		CFrame = base * CFrame.new(-2.3, 1.1 + 3.8, -d / 2 - 0.2),
		Color = TIMBER,
		Material = Enum.Material.Wood,
	}, parent)
	part({
		Name = "DoorFrameR",
		Size = Vector3.new(0.6, 7.6, 0.6),
		CFrame = base * CFrame.new(2.3, 1.1 + 3.8, -d / 2 - 0.2),
		Color = TIMBER,
		Material = Enum.Material.Wood,
	}, parent)
	part({
		Name = "DoorHandle",
		Size = Vector3.new(0.3, 0.3, 0.3),
		Shape = Enum.PartType.Ball,
		CFrame = base * CFrame.new(1.3, 1.1 + 3.4, -d / 2 - 0.45),
		Color = rgb(200, 170, 80),
		Material = Enum.Material.Metal,
	}, parent)
	part({
		Name = "Awning",
		Size = Vector3.new(6, 0.4, 2.6),
		CFrame = base * CFrame.new(0, 1.1 + 7.9, -d / 2 - 1.2) * CFrame.Angles(math.rad(-18), 0, 0),
		Color = roofColor,
		Material = Enum.Material.Slate,
	}, parent)
	lantern(base * CFrame.new(3.3, 1.1 + 5.5, -d / 2) * CFrame.Angles(0, math.pi, 0), parent)

	-- Gabled roof: ridge along the width, sloping to front and back, with triangle gable ends.
	local roofH = topDepth * 0.42
	local overhang = 1.2
	local slope = math.atan2(roofH, topDepth / 2)
	local panelLen = math.sqrt(roofH ^ 2 + (topDepth / 2) ^ 2) + overhang
	for side = -1, 1, 2 do
		part({
			Name = "Roof",
			Size = Vector3.new(topWidth + overhang * 2, 0.7, panelLen),
			CFrame = base
				* CFrame.new(0, y + roofH / 2 + 0.35, side * topDepth / 4)
				* CFrame.Angles(side * slope, 0, 0)
				* CFrame.new(0, 0, side * overhang / 2),
			Color = roofColor,
			Material = Enum.Material.Slate,
		}, parent)
	end
	for side = -1, 1, 2 do
		gable(
			base * CFrame.new(side * (topWidth / 2 - 0.3), y, 0),
			topDepth,
			roofH,
			0.6,
			wallColor,
			Enum.Material.Plaster,
			parent
		)
		part({
			Name = "GableBeam",
			Size = Vector3.new(0.4, 0.5, topDepth),
			CFrame = base * CFrame.new(side * (topWidth / 2 - 0.05), y + 0.25, 0),
			Color = TIMBER,
			Material = Enum.Material.Wood,
		}, parent)
	end
	part({
		Name = "Ridge",
		Size = Vector3.new(topWidth + overhang * 2 + 0.4, 0.6, 0.6),
		CFrame = base * CFrame.new(0, y + roofH + 0.4, 0),
		Color = TIMBER,
		Material = Enum.Material.Wood,
	}, parent)

	-- Chimney with smoke
	local chimney = part({
		Name = "Chimney",
		Size = Vector3.new(2.2, roofH + 4, 2.2),
		CFrame = base * CFrame.new(topWidth / 3, y + (roofH + 4) / 2, topDepth / 5),
		Color = rgb(120, 80, 65),
		Material = Enum.Material.Brick,
	}, parent)
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(200, 200, 200)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 4
	smoke.Size = 2
	smoke.Parent = chimney

	-- Barrels and crates by the door
	if rng:NextNumber() < 0.6 then
		part({
			Name = "Barrel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.6, 2, 2),
			CFrame = base * CFrame.new(-w / 2 + 1.5, 1.3, -d / 2 - 1.6) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(110, 75, 45),
			Material = Enum.Material.Wood,
		}, parent)
	end
	if rng:NextNumber() < 0.5 then
		part({
			Name = "Crate",
			Size = Vector3.new(2.2, 2.2, 2.2),
			CFrame = base * CFrame.new(w / 2 - 1.4, 1.1, -d / 2 - 1.8) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Color = rgb(140, 100, 60),
			Material = Enum.Material.WoodPlanks,
		}, parent)
	end
	if opts.Sign then
		local sign = part({
			Name = "ShopSign",
			Size = Vector3.new(5, 1.6, 0.3),
			CFrame = base * CFrame.new(0, 1.1 + 9.8, -d / 2 - 2.4),
			Color = rgb(120, 85, 55),
			Material = Enum.Material.WoodPlanks,
		}, parent)
		Props.Lettering(sign, opts.Sign)
	end
	return base, y
end

-- Square stone tower with battlements.
function Architecture.Tower(ground, size, height, opts)
	opts = opts or {}
	local parent = opts.Parent
	local color = opts.Color or STONE
	local cf = CFrame.new(ground) * CFrame.Angles(0, opts.Rotation or 0, 0)
	part({
		Name = "TowerBase",
		Size = Vector3.new(size + 1.5, 3, size + 1.5),
		CFrame = cf * CFrame.new(0, 1, 0),
		Color = DARK_STONE,
		Material = Enum.Material.Cobblestone,
	}, parent)
	part({
		Name = "Tower",
		Size = Vector3.new(size, height, size),
		CFrame = cf * CFrame.new(0, height / 2, 0),
		Color = color,
		Material = Enum.Material.Cobblestone,
	}, parent)
	part({
		Name = "TowerCorbel",
		Size = Vector3.new(size + 1.6, 1.2, size + 1.6),
		CFrame = cf * CFrame.new(0, height + 0.6, 0),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	}, parent)
	local step = (size + 1.6) / 4
	for side = 0, 3 do
		local rot = CFrame.Angles(0, side * math.pi / 2, 0)
		for i = 0, 3 do
			if i % 2 == 0 then
				part({
					Name = "Merlon",
					Size = Vector3.new(step, 2.2, 1),
					CFrame = cf
						* rot
						* CFrame.new(-(size + 1.6) / 2 + step * (i + 0.5), height + 2.3, -(size + 1.6) / 2 + 0.5),
					Color = color,
					Material = Enum.Material.Cobblestone,
				}, parent)
			end
		end
	end
	for _, y in ipairs({ height * 0.4, height * 0.75 }) do
		part({
			Name = "ArrowSlit",
			Size = Vector3.new(0.7, 2.6, 0.3),
			CFrame = cf * CFrame.new(0, y, -size / 2 - 0.1),
			Color = rgb(20, 18, 18),
			Material = Enum.Material.Slate,
		}, parent)
	end
	if opts.Roof then
		-- Pyramid roof from four wedges.
		local rh = size * 0.9
		for side = 0, 3 do
			wedge(
				Vector3.new(size + 1.6, rh, (size + 1.6) / 2),
				cf * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, height + 1.2 + rh / 2, -(size + 1.6) / 4),
				opts.Roof,
				Enum.Material.Slate,
				parent
			)
		end
	end
	if opts.Banner then
		part({
			Name = "FlagPole",
			Size = Vector3.new(0.3, 8, 0.3),
			CFrame = cf * CFrame.new(0, height + (opts.Roof and size * 0.9 + 4 or 5), 0),
			Color = IRON,
			Material = Enum.Material.Metal,
		}, parent)
		part({
			Name = "Flag",
			Size = Vector3.new(3.5, 2.2, 0.1),
			CFrame = cf * CFrame.new(1.9, height + (opts.Roof and size * 0.9 + 7 or 8), 0),
			Color = opts.Banner,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, parent)
	end
end

-- Round tower (used for grand walls). Stacked discs make the conical roof.
function Architecture.RoundTower(ground, radius, height, opts)
	opts = opts or {}
	local parent = opts.Parent
	local color = opts.Color or STONE
	part({
		Name = "RoundTower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = opts.Material or Enum.Material.Cobblestone,
	}, parent)
	part({
		Name = "Corbel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, radius * 2 + 2, radius * 2 + 2),
		CFrame = CFrame.new(ground + Vector3.new(0, height + 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	}, parent)
	local count = math.max(8, math.floor(radius * 1.6))
	for i = 0, count - 1 do
		if i % 2 == 0 then
			local a = i / count * math.pi * 2
			part({
				Name = "Merlon",
				Size = Vector3.new(1.2, 2.2, radius * 0.55),
				CFrame = CFrame.new(
					ground + Vector3.new(math.cos(a) * (radius + 0.4), height + 2.4, math.sin(a) * (radius + 0.4))
				) * CFrame.Angles(0, -a, 0),
				Color = color,
				Material = opts.Material or Enum.Material.Cobblestone,
			}, parent)
		end
	end
	if opts.Roof then
		local layers = 6
		for i = 0, layers - 1 do
			local r = (radius + 1.2) * (1 - i / layers)
			part({
				Name = "Roof",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(radius * 0.4, r * 2, r * 2),
				CFrame = CFrame.new(ground + Vector3.new(0, height + 3.5 + i * radius * 0.35, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = opts.Roof,
				Material = Enum.Material.Slate,
			}, parent)
		end
	end
	if opts.Banner then
		local top = height + (opts.Roof and 3.5 + radius * 2.1 or 3)
		part({
			Name = "FlagPole",
			Size = Vector3.new(0.3, 7, 0.3),
			Position = ground + Vector3.new(0, top + 3.5, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
		}, parent)
		part({
			Name = "Flag",
			Size = Vector3.new(0.1, 2.4, 4),
			Position = ground + Vector3.new(0, top + 5.6, 2.1),
			Color = opts.Banner,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, parent)
	end
end

-- Straight wall segment between two ground points, with a walkway and battlements on the outside.
--   outward: unit vector pointing out of the enclosure
function Architecture.WallSegment(a, b, height, thickness, outward, opts)
	opts = opts or {}
	local parent = opts.Parent
	local color = opts.Color or STONE
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, mid + (b - a))
	local baseY = math.min(a.Y, b.Y) - 2
	local top = math.max(a.Y, b.Y) + height
	local cfBase = CFrame.new(mid.X, (baseY + top) / 2, mid.Z) * cf.Rotation
	part({
		Name = "Wall",
		Size = Vector3.new(thickness, top - baseY, len + 0.6),
		CFrame = cfBase,
		Color = color,
		Material = opts.Material or Enum.Material.Cobblestone,
	}, parent)
	part({
		Name = "Plinth",
		Size = Vector3.new(thickness + 1.2, 3, len + 0.6),
		CFrame = CFrame.new(mid.X, baseY + 2.5, mid.Z) * cf.Rotation,
		Color = DARK_STONE,
		Material = Enum.Material.Cobblestone,
	}, parent)
	-- String course and battlements toward the outside
	local outSide = (cf.RightVector:Dot(outward) > 0) and 1 or -1
	part({
		Name = "StringCourse",
		Size = Vector3.new(thickness + 0.8, 0.8, len + 0.6),
		CFrame = CFrame.new(mid.X, top - 0.4, mid.Z) * cf.Rotation,
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	}, parent)
	local merlons = math.max(1, math.floor(len / 3))
	for i = 0, merlons - 1 do
		if i % 2 == 0 then
			local z = -len / 2 + (i + 0.5) * len / merlons
			part({
				Name = "Merlon",
				Size = Vector3.new(1, 2.4, len / merlons),
				CFrame = CFrame.new(mid.X, top + 1.2, mid.Z)
					* cf.Rotation
					* CFrame.new(outSide * (thickness / 2 - 0.5), 0, z),
				Color = color,
				Material = opts.Material or Enum.Material.Cobblestone,
			}, parent)
		end
	end
end

-- Gatehouse: two towers, an arch over the road, and a raised portcullis.
function Architecture.Gatehouse(ground, facing, width, height, opts)
	opts = opts or {}
	local parent = opts.Parent
	local color = opts.Color or STONE
	local cf = CFrame.lookAt(ground, ground + facing)
	local right = cf.RightVector
	for side = -1, 1, 2 do
		Architecture.Tower(ground + right * side * (width / 2 + 4), 8, height + 6, {
			Parent = parent,
			Color = color,
			Roof = opts.Roof,
			Banner = opts.Banner,
			Rotation = math.atan2(-facing.X, -facing.Z),
		})
	end
	part({
		Name = "GateArch",
		Size = Vector3.new(width + 2, 6, 9),
		CFrame = cf * CFrame.new(0, height + 1, 0),
		Color = color,
		Material = Enum.Material.Cobblestone,
	}, parent)
	part({
		Name = "ArchTrim",
		Size = Vector3.new(width + 2.6, 1, 9.6),
		CFrame = cf * CFrame.new(0, height - 2, 0),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	}, parent)
	-- Portcullis (raised) and open doors
	for i = -3, 3 do
		part({
			Name = "PortcullisBar",
			Size = Vector3.new(0.3, 4, 0.3),
			CFrame = cf * CFrame.new(i * width / 7, height - 0.2, -2),
			Color = IRON,
			Material = Enum.Material.Metal,
		}, parent)
	end
	for side = -1, 1, 2 do
		part({
			Name = "GateDoor",
			Size = Vector3.new(width / 2, height - 3, 0.6),
			CFrame = cf
				* CFrame.new(side * (width / 2 - 0.5), (height - 3) / 2, 3)
				* CFrame.Angles(0, side * math.rad(80), 0)
				* CFrame.new(side * width / 4, 0, 0),
			Color = rgb(90, 60, 35),
			Material = Enum.Material.WoodPlanks,
		}, parent)
	end
	for side = -1, 1, 2 do
		lantern(cf * CFrame.new(side * (width / 2 + 0.2), height * 0.55, -4.6) * CFrame.Angles(0, math.pi, 0), parent)
	end
end

-- A ring of walls around center with towers, leaving gaps at the given gate angles (radians).
--   groundAt(x, z) -> Vector3 ground position
function Architecture.CurtainWall(center, radius, height, groundAt, opts)
	opts = opts or {}
	local segments = opts.Segments or 48
	local gates = opts.Gates or {}
	local gateWidth = opts.GateWidth or 14
	local gateHalfAngle = (gateWidth / 2 + 7) / radius
	local function nearGate(a)
		for _, g in ipairs(gates) do
			if math.abs((a - g + math.pi) % (2 * math.pi) - math.pi) < gateHalfAngle then
				return g
			end
		end
		return nil
	end
	local function point(a)
		return groundAt(center.X + math.cos(a) * radius, center.Z + math.sin(a) * radius)
	end
	for i = 0, segments - 1 do
		local a0 = i / segments * math.pi * 2
		local a1 = (i + 1) / segments * math.pi * 2
		local mid = (a0 + a1) / 2
		if not nearGate(a0) and not nearGate(a1) then
			local outward = Vector3.new(math.cos(mid), 0, math.sin(mid))
			Architecture.WallSegment(point(a0), point(a1), height, opts.Thickness or 4, outward, opts)
		end
		if i % (opts.TowerEvery or 6) == 0 and not nearGate(a0) then
			if opts.RoundTowers then
				Architecture.RoundTower(point(a0), opts.TowerRadius or 6, height + 6, {
					Parent = opts.Parent,
					Color = opts.Color,
					Material = opts.Material,
					Roof = opts.Roof,
					Banner = opts.Banner,
				})
			else
				Architecture.Tower(
					point(a0),
					9,
					height + 5,
					{ Parent = opts.Parent, Color = opts.Color, Roof = opts.Roof, Banner = opts.Banner, Rotation = -a0 }
				)
			end
		end
	end
	for _, g in ipairs(gates) do
		local p = point(g)
		Architecture.Gatehouse(
			p,
			Vector3.new(math.cos(g), 0, math.sin(g)),
			gateWidth,
			height + 2,
			{ Parent = opts.Parent, Color = opts.Color, Roof = opts.Roof, Banner = opts.Banner }
		)
	end
end

function Architecture.Lamp(ground, parent)
	part({
		Name = "LampPost",
		Size = Vector3.new(0.5, 9, 0.5),
		Position = ground + Vector3.new(0, 4.5, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
	}, parent)
	part({
		Name = "LampArm",
		Size = Vector3.new(0.3, 0.3, 1.6),
		Position = ground + Vector3.new(0, 8.8, -0.7),
		Color = IRON,
		Material = Enum.Material.Metal,
	}, parent)
	local glow = part({
		Name = "LampGlow",
		Size = Vector3.new(0.9, 1.1, 0.9),
		Position = ground + Vector3.new(0, 8.2, -1.4),
		Color = rgb(255, 200, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, parent)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 185, 110)
	light.Range = 18
	light.Brightness = 0.7
	light.Shadows = false
	light.Parent = glow
end

-- Paved street from a to b (ground points), laid as thin slabs that follow the ground.
function Architecture.Street(a, b, width, groundAt, opts)
	opts = opts or {}
	local len = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	local pieces = math.max(1, math.ceil(len / 24))
	for i = 0, pieces - 1 do
		local p0 = a:Lerp(b, i / pieces)
		local p1 = a:Lerp(b, (i + 1) / pieces)
		local g0, g1 = groundAt(p0.X, p0.Z), groundAt(p1.X, p1.Z)
		local mid = (g0 + g1) / 2
		local dir = (g1 - g0)
		part({
			Name = "Street",
			Size = Vector3.new(width, 0.4, dir.Magnitude + 0.4),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), mid + Vector3.new(0, 0.15, 0) + dir),
			Color = opts.Color or rgb(125, 120, 112),
			Material = opts.Material or Enum.Material.Cobblestone,
			CastShadow = false,
		}, opts.Parent)
	end
end

function Architecture.MarketStall(ground, facing, color, parent)
	local cf = CFrame.lookAt(ground, ground + facing)
	part({
		Name = "StallCounter",
		Size = Vector3.new(7, 3, 3),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = rgb(110, 80, 55),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	part({
		Name = "StallAwning",
		Size = Vector3.new(8, 0.3, 5),
		CFrame = cf * CFrame.new(0, 7, -0.5) * CFrame.Angles(math.rad(12), 0, 0),
		Color = color,
		Material = Enum.Material.Fabric,
	}, parent)
	for _, x in ipairs({ -3.5, 3.5 }) do
		part({
			Name = "StallPost",
			Size = Vector3.new(0.4, 6, 0.4),
			CFrame = cf * CFrame.new(x, 3, 1.5),
			Color = TIMBER,
			Material = Enum.Material.Wood,
		}, parent)
	end
	for i = -1, 1 do
		part({
			Name = "Goods",
			Size = Vector3.new(1.2, 0.8, 1),
			CFrame = cf * CFrame.new(i * 2, 3.4, 0),
			Color = ({ rgb(200, 60, 50), rgb(230, 190, 80), rgb(90, 150, 70) })[i + 2],
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

function Architecture.Fountain(ground, radius, parent)
	part({
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, radius * 2, radius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(200, 195, 185),
		Material = Enum.Material.Marble,
	}, parent)
	part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2 - 1.2, radius * 2 - 1.2),
		CFrame = CFrame.new(ground + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(70, 140, 190),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	}, parent)
	part({
		Name = "FountainPillar",
		Size = Vector3.new(1.5, 5, 1.5),
		Position = ground + Vector3.new(0, 3.5, 0),
		Color = rgb(210, 205, 195),
		Material = Enum.Material.Marble,
	}, parent)
	local spout = part({
		Name = "Spout",
		Size = Vector3.new(1, 1, 1),
		Position = ground + Vector3.new(0, 6.2, 0),
		Color = rgb(210, 205, 195),
		Material = Enum.Material.Marble,
	}, parent)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(200, 230, 255))
	spray.Size = NumberSequence.new(0.3, 0.1)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 40
	spray.Speed = NumberRange.new(6, 8)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.Parent = spout
end

Architecture.Lantern = lantern
Architecture.Window = window
Architecture.Gable = gable

return Architecture
