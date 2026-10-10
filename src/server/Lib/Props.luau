-- Builders for world scenery made from parts. Every function takes a ground position
-- (Y = ground height) and parents what it builds to Props.Folder.
local Props = {}

Props.Folder = nil

local rng = Random.new(4242)
Props.Random = rng

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or Props.Folder
	return p
end
Props.Part = part

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WOOD = rgb(95, 68, 45)
local STONE = rgb(120, 120, 125)

function Props.Tree(ground, scale, leafColor)
	local h = 10 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(ground + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		local size = (8.5 - i * 1.7) * scale
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = ground
				+ Vector3.new(rng:NextNumber(-1, 1) * scale, h * 0.62 + i * 2.6 * scale, rng:NextNumber(-1, 1) * scale),
			Color = leafColor:Lerp(rgb(30, 50, 25), rng:NextNumber(0, 0.25)),
			Material = Enum.Material.Grass,
			CanCollide = false,
			CastShadow = i == 1,
		})
	end
end

function Props.Pine(ground, scale, snowy)
	local h = 14 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.3 * scale, 1.3 * scale),
		CFrame = CFrame.new(ground + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(80, 55, 40),
		Material = Enum.Material.Wood,
	})
	for i = 1, 4 do
		local w = (9 - i * 1.8) * scale
		local tier = part({
			Name = "Needles",
			Size = Vector3.new(w, 2.6 * scale, w),
			CFrame = CFrame.new(ground + Vector3.new(0, h * 0.3 + i * 2.6 * scale, 0))
				* CFrame.Angles(0, math.rad(i * 25), 0),
			Color = rgb(40, 75, 50),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
		if snowy then
			part({
				Name = "Snow",
				Size = Vector3.new(w * 0.8, 0.5 * scale, w * 0.8),
				CFrame = tier.CFrame * CFrame.new(0, 1.4 * scale, 0),
				Color = rgb(240, 245, 250),
				Material = Enum.Material.Snow,
				CanCollide = false,
			})
		end
	end
end

function Props.DeadTree(ground, scale)
	local h = 9 * scale
	part({
		Name = "DeadTrunk",
		Size = Vector3.new(1.2 * scale, h, 1.2 * scale),
		CFrame = CFrame.new(ground + Vector3.new(0, h / 2 - 0.5, 0))
			* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15)),
		Color = rgb(70, 60, 50),
		Material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		part({
			Name = "Branch",
			Size = Vector3.new(0.5 * scale, 4 * scale, 0.5 * scale),
			CFrame = CFrame.new(ground + Vector3.new(0, h * (0.5 + i * 0.15), 0))
				* CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(rng:NextNumber(35, 60)))
				* CFrame.new(0, 2 * scale, 0),
			Color = rgb(70, 60, 50),
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
end

function Props.Rock(ground, size, color, material)
	part({
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(ground + Vector3.new(0, size.Y / 2 - 0.8, 0))
			* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
		Color = color or STONE,
		Material = material or Enum.Material.Slate,
	})
end

function Props.Bush(ground, color)
	local s = rng:NextNumber(2.5, 4.5)
	part({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s, s * 0.8, s),
		Position = ground + Vector3.new(0, s * 0.25, 0),
		Color = color or rgb(55, 100, 50),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

function Props.Flowers(ground, color)
	for _ = 1, 4 do
		part({
			Name = "Flower",
			Size = Vector3.new(0.5, 0.5, 0.5),
			Position = ground + Vector3.new(rng:NextNumber(-2, 2), 0.4, rng:NextNumber(-2, 2)),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

function Props.Torch(ground)
	part({
		Name = "Post",
		Size = Vector3.new(0.5, 6, 0.5),
		Position = ground + Vector3.new(0, 3, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	local flame = part({
		Name = "Flame",
		Size = Vector3.new(0.8, 0.8, 0.8),
		Position = ground + Vector3.new(0, 6.4, 0),
		Color = rgb(255, 160, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 170, 90)
	light.Range = 18
	light.Brightness = 1
	light.Shadows = false
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Parent = flame
	return flame
end

-- A house facing `facing` (unit vector). Returns its CFrame.
function Props.House(ground, facing, wallColor, scale)
	scale = scale or 1
	local base = CFrame.lookAt(ground, ground + facing)
	local w, d, h = 16 * scale, 14 * scale, 10 * scale
	part({
		Name = "Foundation",
		Size = Vector3.new(w + 1, 2, d + 1),
		CFrame = base * CFrame.new(0, 0, 0),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})
	part({
		Name = "Walls",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2 + 1, 0),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			part({
				Name = "Beam",
				Size = Vector3.new(1, h, 1),
				CFrame = base * CFrame.new(x, h / 2 + 1, z),
				Color = WOOD,
				Material = Enum.Material.Wood,
			})
		end
	end
	part({
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = base * CFrame.new(0, 4.5, -d / 2 - 0.15),
		Color = rgb(60, 40, 25),
		Material = Enum.Material.Wood,
	})
	for _, x in ipairs({ -w / 3, w / 3 }) do
		local window = part({
			Name = "Window",
			Size = Vector3.new(2.5, 2.5, 0.3),
			CFrame = base * CFrame.new(x, h * 0.6 + 1, -d / 2 - 0.1),
			Color = rgb(255, 210, 130),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
		window.CastShadow = false
	end
	for side = -1, 1, 2 do
		part({
			Name = "Roof",
			Size = Vector3.new(w + 2, 0.8, d / 2 / math.cos(math.rad(35)) + 1.2),
			CFrame = base * CFrame.new(0, h + 3.6, side * d / 4) * CFrame.Angles(math.rad(35) * side, 0, 0),
			Color = rgb(120, 50, 40),
			Material = Enum.Material.Slate,
		})
	end
	part({
		Name = "Chimney",
		Size = Vector3.new(2, 6, 2),
		CFrame = base * CFrame.new(w / 3, h + 4, d / 5),
		Color = STONE,
		Material = Enum.Material.Brick,
	})
	return base
end

function Props.Fence(a, b)
	local dir = b - a
	local len = dir.Magnitude
	local posts = math.max(1, math.floor(len / 8))
	for i = 0, posts do
		local p = a:Lerp(b, i / posts)
		part({
			Name = "FencePost",
			Size = Vector3.new(0.6, 4, 0.6),
			Position = p + Vector3.new(0, 2, 0),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
	end
	for _, y in ipairs({ 1.4, 3 }) do
		part({
			Name = "FenceRail",
			Size = Vector3.new(0.3, 0.4, len),
			CFrame = CFrame.lookAt(a:Lerp(b, 0.5) + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
	end
end

-- Paint text onto both faces of a board. Unlit (LightInfluence 0) so it stays legible at night
-- and in shade, with a dark outline so it reads against any wood colour.
function Props.Lettering(board, text, color)
	local labels = {}
	for side, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = side == 1 and "LetteringFront" or "LetteringBack"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.MaxDistance = 220
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = color or rgb(255, 238, 205)
		label.TextStrokeColor3 = rgb(25, 15, 8)
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = gui
		gui.Parent = board
		table.insert(labels, label)
	end
	return labels
end

-- A signpost. The board widens to fit its text and reads from both sides.
-- Returns the board and its text labels (front, back) so callers can change the text later.
function Props.Sign(ground, text, facing)
	local width = math.clamp(#text * 0.62 + 2, 7, 22)
	local lines = width >= 22 and 2 or 1
	local height = lines == 2 and 3.4 or 2.2
	for side = -1, 1, 2 do
		local offset = facing:Cross(Vector3.new(0, 1, 0)).Unit * side * (width / 2 - 0.6)
		part({
			Name = "SignPost",
			Size = Vector3.new(0.6, 5 + height, 0.6),
			Position = ground + offset + Vector3.new(0, (5 + height) / 2, 0),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
	end
	local center = ground + Vector3.new(0, 4.2 + height / 2, 0)
	local board = part({
		Name = "Sign",
		Size = Vector3.new(width, height, 0.4),
		CFrame = CFrame.lookAt(center, center + facing),
		Color = rgb(92, 64, 42),
		Material = Enum.Material.WoodPlanks,
	})
	local labels = Props.Lettering(board, text)
	return board, labels
end

function Props.Bridge(a, b, width)
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	part({
		Name = "Bridge",
		Size = Vector3.new(width, 1, length),
		CFrame = cf,
		Color = rgb(110, 80, 55),
		Material = Enum.Material.WoodPlanks,
	})
	local posts = math.max(4, math.floor(length / 14))
	for side = -1, 1, 2 do
		part({
			Name = "Rail",
			Size = Vector3.new(0.6, 1, length),
			CFrame = cf * CFrame.new(side * (width / 2 - 0.3), 2.5, 0),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
		for i = 0, posts do
			part({
				Name = "RailPost",
				Size = Vector3.new(0.6, 3, 0.6),
				CFrame = cf * CFrame.new(side * (width / 2 - 0.3), 1.5, (i / posts - 0.5) * length),
				Color = WOOD,
				Material = Enum.Material.Wood,
			})
		end
	end
	-- Piers: every ~28 studs, from the underside of the deck down to the riverbed.
	local piers = math.max(1, math.floor(length / 28))
	for i = 1, piers do
		local at = cf * CFrame.new(0, 0, (i / (piers + 1) - 0.5) * length)
		local top = at.Position.Y - 0.5
		local depth = top + 14
		for side = -1, 1, 2 do
			part({
				Name = "Pier",
				Size = Vector3.new(3, depth, 3),
				CFrame = CFrame.new(
					at.Position + at.RightVector * side * (width / 2 - 1.5) - Vector3.new(0, 0.5 + depth / 2, 0)
				),
				Color = STONE,
				Material = Enum.Material.Cobblestone,
			})
		end
		part({
			Name = "PierBeam",
			Size = Vector3.new(width, 1.2, 1.6),
			CFrame = at * CFrame.new(0, -1.1, 0),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
	end
end

-- Landmarks ------------------------------------------------------------------------------

local landmarkBuilders = {}

function landmarkBuilders.Tower(ground)
	local h = 46
	part({
		Name = "Tower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 16, 16),
		CFrame = CFrame.new(ground + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})
	part({
		Name = "TowerTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 20, 20),
		CFrame = CFrame.new(ground + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part({
			Name = "Crenel",
			Size = Vector3.new(3, 3, 2),
			CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * 9, h + 2.5, math.sin(a) * 9))
				* CFrame.Angles(0, -a, 0),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
		})
	end
	part({
		Name = "Door",
		Size = Vector3.new(4, 7, 1),
		Position = ground + Vector3.new(0, 3.5, -8),
		Color = rgb(40, 30, 25),
		Material = Enum.Material.Wood,
	})
	local beacon = part({
		Name = "Beacon",
		Size = Vector3.new(3, 3, 3),
		Position = ground + Vector3.new(0, h + 3, 0),
		Color = rgb(255, 150, 60),
		Material = Enum.Material.Neon,
	})
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Parent = beacon
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Color = rgb(255, 160, 80)
	light.Parent = beacon
end

function landmarkBuilders.Stones(ground)
	for i = 0, 8 do
		local a = i / 9 * math.pi * 2
		local h = rng:NextNumber(10, 16)
		part({
			Name = "Monolith",
			Size = Vector3.new(3, h, 2),
			CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * 16, h / 2 - 1, math.sin(a) * 16))
				* CFrame.Angles(rng:NextNumber(-0.08, 0.08), -a, 0),
			Color = rgb(105, 110, 115),
			Material = Enum.Material.Slate,
		})
	end
	part({
		Name = "Altar",
		Size = Vector3.new(6, 3, 4),
		Position = ground + Vector3.new(0, 1.5, 0),
		Color = rgb(90, 90, 95),
		Material = Enum.Material.Slate,
	})
	local rune = part({
		Name = "Rune",
		Size = Vector3.new(1.5, 1.5, 1.5),
		Shape = Enum.PartType.Ball,
		Position = ground + Vector3.new(0, 4, 0),
		Color = rgb(120, 170, 255),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(120, 170, 255)
	light.Range = 18
	light.Parent = rune
end

function landmarkBuilders.ElderTree(ground)
	local h = 48
	part({
		Name = "ElderTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 9, 9),
		CFrame = CFrame.new(ground + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(85, 60, 40),
		Material = Enum.Material.Wood,
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part({
			Name = "Root",
			Size = Vector3.new(2.5, 2.5, 12),
			CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * 6, 0.8, math.sin(a) * 6))
				* CFrame.Angles(0, -a + math.pi / 2, 0)
				* CFrame.Angles(math.rad(-10), 0, 0),
			Color = rgb(85, 60, 40),
			Material = Enum.Material.Wood,
		})
	end
	for i = 1, 7 do
		local s = rng:NextNumber(18, 28)
		part({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s * 0.8, s),
			Position = ground
				+ Vector3.new(rng:NextNumber(-14, 14), h + rng:NextNumber(-4, 8), rng:NextNumber(-14, 14)),
			Color = i % 2 == 0 and rgb(70, 120, 60) or rgb(90, 140, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

function landmarkBuilders.Overlook(ground)
	part({
		Name = "Outcrop",
		Size = Vector3.new(26, 8, 22),
		CFrame = CFrame.new(ground + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0.4, 0.05),
		Color = rgb(95, 90, 90),
		Material = Enum.Material.Slate,
	})
	for i = 1, 4 do
		local h = rng:NextNumber(6, 14)
		part({
			Name = "BrokenPillar",
			Size = Vector3.new(2.5, h, 2.5),
			Position = ground + Vector3.new(-9 + i * 4, 7 + h / 2, 6),
			Color = rgb(170, 165, 155),
			Material = Enum.Material.Marble,
		})
	end
	part({
		Name = "Bench",
		Size = Vector3.new(6, 1, 2),
		Position = ground + Vector3.new(0, 8, -4),
		Color = rgb(170, 165, 155),
		Material = Enum.Material.Marble,
	})
end

function landmarkBuilders.Shrine(ground)
	part({
		Name = "Platform",
		Size = Vector3.new(20, 2, 20),
		Position = ground + Vector3.new(0, 1, 0),
		Color = rgb(200, 195, 185),
		Material = Enum.Material.Marble,
	})
	for _, x in ipairs({ -8, 8 }) do
		for _, z in ipairs({ -8, 8 }) do
			part({
				Name = "Column",
				Size = Vector3.new(2, 14, 2),
				Position = ground + Vector3.new(x, 9, z),
				Color = rgb(210, 205, 195),
				Material = Enum.Material.Marble,
			})
		end
	end
	part({
		Name = "Dome",
		Size = Vector3.new(22, 2, 22),
		Position = ground + Vector3.new(0, 17, 0),
		Color = rgb(200, 195, 185),
		Material = Enum.Material.Marble,
	})
	local orb = part({
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = ground + Vector3.new(0, 6, 0),
		Color = rgb(150, 220, 255),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(150, 220, 255)
	light.Range = 25
	light.Parent = orb
end

function landmarkBuilders.Hut(ground)
	Props.House(ground, Vector3.new(0, 0, -1), rgb(110, 90, 70), 0.7)
	local fire = part({
		Name = "Campfire",
		Size = Vector3.new(2, 0.6, 2),
		Position = ground + Vector3.new(0, 0.3, -14),
		Color = rgb(255, 120, 40),
		Material = Enum.Material.Neon,
	})
	local f = Instance.new("Fire")
	f.Size = 4
	f.Parent = fire
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		Props.Rock(ground + Vector3.new(math.cos(a) * 2.2, 0.6, -14 + math.sin(a) * 2.2), Vector3.new(1, 0.8, 1))
	end
end

function landmarkBuilders.Wreck(ground)
	local hull = rgb(80, 60, 45)
	part({
		Name = "Hull",
		Size = Vector3.new(12, 8, 40),
		CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0.6, math.rad(25)),
		Color = hull,
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "Mast",
		Size = Vector3.new(1.2, 26, 1.2),
		CFrame = CFrame.new(ground + Vector3.new(2, 10, 3)) * CFrame.Angles(math.rad(20), 0.6, math.rad(30)),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	part({
		Name = "Sail",
		Size = Vector3.new(10, 9, 0.2),
		CFrame = CFrame.new(ground + Vector3.new(5, 14, 4)) * CFrame.Angles(math.rad(10), 0.6, math.rad(35)),
		Color = rgb(210, 200, 180),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
end

function landmarkBuilders.Colossus(ground)
	local ice = rgb(170, 200, 215)
	part({
		Name = "ColossusHead",
		Size = Vector3.new(18, 20, 18),
		CFrame = CFrame.new(ground + Vector3.new(0, 6, 0)) * CFrame.Angles(0.2, 0.5, 0.35),
		Color = ice,
		Material = Enum.Material.Glacier,
	})
	part({
		Name = "ColossusHand",
		Size = Vector3.new(10, 26, 8),
		CFrame = CFrame.new(ground + Vector3.new(26, 10, 10)) * CFrame.Angles(0.1, 0, -0.3),
		Color = ice,
		Material = Enum.Material.Glacier,
	})
	part({
		Name = "ColossusSword",
		Size = Vector3.new(3, 60, 8),
		CFrame = CFrame.new(ground + Vector3.new(-24, 24, -6)) * CFrame.Angles(0.25, 0.3, 0.2),
		Color = rgb(140, 160, 180),
		Material = Enum.Material.Ice,
	})
end

function landmarkBuilders.Mine(ground)
	part({
		Name = "CliffFace",
		Size = Vector3.new(50, 34, 20),
		Position = ground + Vector3.new(0, 15, 10),
		Color = rgb(100, 98, 100),
		Material = Enum.Material.Rock,
	})
	part({
		Name = "MineEntrance",
		Size = Vector3.new(10, 12, 2),
		Position = ground + Vector3.new(0, 6, -0.5),
		Color = rgb(15, 12, 12),
		Material = Enum.Material.Slate,
	})
	part({
		Name = "Lintel",
		Size = Vector3.new(14, 1.5, 2),
		Position = ground + Vector3.new(0, 12.5, -1),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	for _, x in ipairs({ -6, 6 }) do
		part({
			Name = "Support",
			Size = Vector3.new(1.5, 12, 1.5),
			Position = ground + Vector3.new(x, 6, -1),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
	end
	part({
		Name = "Cart",
		Size = Vector3.new(4, 3, 6),
		Position = ground + Vector3.new(8, 1.5, -10),
		Color = rgb(80, 70, 60),
		Material = Enum.Material.Metal,
	})
	for _, x in ipairs({ -1.5, 1.5 }) do
		part({
			Name = "Rail",
			Size = Vector3.new(0.4, 0.3, 30),
			Position = ground + Vector3.new(x, 0.2, -16),
			Color = rgb(90, 90, 95),
			Material = Enum.Material.Metal,
		})
	end
end

function landmarkBuilders.Arch(ground)
	local stone = rgb(150, 145, 135)
	for _, x in ipairs({ -12, 12 }) do
		part({
			Name = "ArchLeg",
			Size = Vector3.new(6, 30, 6),
			Position = ground + Vector3.new(x, 14, 0),
			Color = stone,
			Material = Enum.Material.Limestone,
		})
	end
	part({
		Name = "ArchTop",
		Size = Vector3.new(32, 6, 7),
		Position = ground + Vector3.new(0, 31, 0),
		Color = stone,
		Material = Enum.Material.Limestone,
	})
	local gate = part({
		Name = "GateGlow",
		Size = Vector3.new(18, 26, 0.3),
		Position = ground + Vector3.new(0, 14, 0),
		Color = rgb(130, 90, 220),
		Material = Enum.Material.ForceField,
		CanCollide = false,
	})
	gate.Transparency = 0.3
end

function Props.Landmark(kind, ground)
	local builder = landmarkBuilders[kind]
	if builder then
		builder(ground)
	end
end

return Props
