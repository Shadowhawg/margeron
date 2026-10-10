-- Builds placeholder models out of parts: enemies, NPCs and weapons. When you have real models,
-- this is the one place to swap them in (e.g. clone from ServerStorage instead of building).
local ModelBuilder = {}

local function weld(part0, part1, c0)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
	return w
end

local function part(props)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

-- Attach a decorative part to root at offset.
local function attach(root, model, name, size, offset, color, material, shape)
	local p = part({
		Name = name,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanTouch = false,
		Massless = true,
		Anchored = false,
	})
	if shape then
		p.Shape = shape
	end
	p.CFrame = root.CFrame * offset
	weld(root, p, offset)
	p.Parent = model
	return p
end

--[[
	Builds a creature.
	opts: Shape ("Beast"|"Humanoid"), Scale, Color, HeadColor, EyeColor, Wings (bool), Anchored (bool)
	Returns model, info { Root, Humanoid, HipHeight, BodyRadius, Height }
]]
function ModelBuilder.Creature(name, opts)
	local s = opts.Scale or 1
	local color = opts.Color or Color3.fromRGB(150, 150, 150)
	local headColor = opts.HeadColor or color
	local eyeColor = opts.EyeColor or Color3.fromRGB(255, 60, 40)

	local model = Instance.new("Model")
	model.Name = name

	local root = part({
		Name = "HumanoidRootPart",
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Anchored = opts.Anchored or false,
		CanCollide = true,
	})

	local hipHeight, bodyRadius, height
	if opts.Shape == "Beast" then
		local body = Vector3.new(1.8, 1.5, 3.8) * s
		root.Size = body
		root.CFrame = CFrame.new()
		hipHeight = 1.4 * s
		bodyRadius = body.Z / 2
		height = hipHeight + body.Y + 0.6 * s
		root.Parent = model

		local headOffset = CFrame.new(0, 0.55 * s, -body.Z / 2 - 0.45 * s)
		attach(root, model, "Head", Vector3.new(1.2, 1.1, 1.3) * s, headOffset, headColor)
		attach(
			root,
			model,
			"Snout",
			Vector3.new(0.7, 0.55, 0.8) * s,
			headOffset * CFrame.new(0, -0.15 * s, -0.95 * s),
			headColor
		)
		attach(
			root,
			model,
			"EarL",
			Vector3.new(0.3, 0.5, 0.2) * s,
			headOffset * CFrame.new(-0.35 * s, 0.7 * s, 0.2 * s),
			headColor
		)
		attach(
			root,
			model,
			"EarR",
			Vector3.new(0.3, 0.5, 0.2) * s,
			headOffset * CFrame.new(0.35 * s, 0.7 * s, 0.2 * s),
			headColor
		)
		attach(
			root,
			model,
			"EyeL",
			Vector3.new(0.18, 0.18, 0.1) * s,
			headOffset * CFrame.new(-0.3 * s, 0.15 * s, -0.66 * s),
			eyeColor,
			Enum.Material.Neon
		)
		attach(
			root,
			model,
			"EyeR",
			Vector3.new(0.18, 0.18, 0.1) * s,
			headOffset * CFrame.new(0.3 * s, 0.15 * s, -0.66 * s),
			eyeColor,
			Enum.Material.Neon
		)
		attach(
			root,
			model,
			"Tail",
			Vector3.new(0.35, 0.35, 1.6) * s,
			CFrame.new(0, 0.3 * s, body.Z / 2 + 0.6 * s) * CFrame.Angles(math.rad(25), 0, 0),
			color
		)
		local legY = -body.Y / 2 - hipHeight / 2
		for _, offset in ipairs({
			Vector3.new(-0.6, legY / s, -1.4),
			Vector3.new(0.6, legY / s, -1.4),
			Vector3.new(-0.6, legY / s, 1.4),
			Vector3.new(0.6, legY / s, 1.4),
		}) do
			attach(
				root,
				model,
				"Leg",
				Vector3.new(0.45 * s, hipHeight, 0.45 * s),
				CFrame.new(offset.X * s, legY, offset.Z * s),
				color
			)
		end
		if opts.Wings then
			attach(
				root,
				model,
				"WingL",
				Vector3.new(3.2, 0.15, 2.2) * s,
				CFrame.new(-2.2 * s, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(20)),
				headColor
			)
			attach(
				root,
				model,
				"WingR",
				Vector3.new(3.2, 0.15, 2.2) * s,
				CFrame.new(2.2 * s, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(-20)),
				headColor
			)
		end
	else
		local body = Vector3.new(2, 2, 1) * s
		root.Size = body
		root.CFrame = CFrame.new()
		hipHeight = 2 * s
		bodyRadius = 1 * s
		height = hipHeight + body.Y + 1.2 * s
		root.Parent = model

		local headOffset = CFrame.new(0, 1.6 * s, 0)
		attach(root, model, "Head", Vector3.new(1.2, 1.2, 1.2) * s, headOffset, headColor)
		attach(
			root,
			model,
			"EyeL",
			Vector3.new(0.2, 0.2, 0.1) * s,
			headOffset * CFrame.new(-0.25 * s, 0.1 * s, -0.6 * s),
			eyeColor,
			Enum.Material.Neon
		)
		attach(
			root,
			model,
			"EyeR",
			Vector3.new(0.2, 0.2, 0.1) * s,
			headOffset * CFrame.new(0.25 * s, 0.1 * s, -0.6 * s),
			eyeColor,
			Enum.Material.Neon
		)
		attach(root, model, "LeftArm", Vector3.new(0.8, 2, 0.8) * s, CFrame.new(-1.4 * s, 0, 0), color)
		attach(root, model, "RightArm", Vector3.new(0.8, 2, 0.8) * s, CFrame.new(1.4 * s, 0, 0), color)
		attach(
			root,
			model,
			"LeftLeg",
			Vector3.new(0.9 * s, hipHeight, 0.9 * s),
			CFrame.new(-0.5 * s, -body.Y / 2 - hipHeight / 2, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.3)
		)
		attach(
			root,
			model,
			"RightLeg",
			Vector3.new(0.9 * s, hipHeight, 0.9 * s),
			CFrame.new(0.5 * s, -body.Y / 2 - hipHeight / 2, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.3)
		)
	end

	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	return model,
		{
			Root = root,
			Humanoid = humanoid,
			HipHeight = hipHeight,
			BodyRadius = bodyRadius,
			Height = height,
			-- distance from the root's center down to the ground
			GroundOffset = hipHeight + root.Size.Y / 2,
		}
end

-- Billboard with a name (and optional subtitle) floating over a model.
function ModelBuilder.NameTag(adornee, height, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.55)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = title
	label.Parent = gui

	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.55)
		sub.Size = UDim2.fromScale(1, 0.4)
		sub.Font = Enum.Font.Gotham
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(220, 210, 180)
		sub.TextStrokeTransparency = 0.5
		sub.Text = subtitle
		sub.Parent = gui
	end

	gui.Parent = adornee
	return gui
end

-- Weapon model. Handle is at the origin, blade/shaft points along +Y.
function ModelBuilder.Weapon(def)
	local model = Instance.new("Model")
	model.Name = "Weapon"
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.3, 1.1, 0.3),
		Color = Color3.fromRGB(70, 45, 30),
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
	})
	handle.Parent = model
	model.PrimaryPart = handle

	local function add(name, size, offset, color, material, shape)
		local p = attach(handle, model, name, size, offset, color, material or Enum.Material.Metal, shape)
		p.CanQuery = false
		return p
	end

	local tip
	local color = def.Color or Color3.fromRGB(180, 180, 185)
	if def.Type == "Sword" then
		add("Guard", Vector3.new(1.3, 0.2, 0.35), CFrame.new(0, 0.6, 0), Color3.fromRGB(120, 100, 60))
		tip = add("Blade", Vector3.new(0.32, 3.4, 0.1), CFrame.new(0, 2.4, 0), color)
		add(
			"Pommel",
			Vector3.new(0.4, 0.4, 0.4),
			CFrame.new(0, -0.6, 0),
			Color3.fromRGB(120, 100, 60),
			nil,
			Enum.PartType.Ball
		)
	elseif def.Type == "Axe" then
		handle.Size = Vector3.new(0.3, 1.1, 0.3)
		add(
			"Shaft",
			Vector3.new(0.28, 3.4, 0.28),
			CFrame.new(0, 1.9, 0),
			Color3.fromRGB(80, 55, 35),
			Enum.Material.Wood
		)
		tip = add("Head", Vector3.new(1.5, 1.1, 0.16), CFrame.new(0.65, 3.2, 0), color)
		add("Spike", Vector3.new(0.5, 0.4, 0.14), CFrame.new(-0.35, 3.2, 0), color)
	elseif def.Type == "Dagger" then
		handle.Size = Vector3.new(0.25, 0.8, 0.25)
		add("Guard", Vector3.new(0.8, 0.15, 0.25), CFrame.new(0, 0.45, 0), Color3.fromRGB(120, 100, 60))
		tip = add("Blade", Vector3.new(0.24, 1.5, 0.08), CFrame.new(0, 1.25, 0), color)
	else -- Staff
		add("ShaftTop", Vector3.new(0.28, 3, 0.28), CFrame.new(0, 2, 0), Color3.fromRGB(80, 55, 35), Enum.Material.Wood)
		add(
			"ShaftBottom",
			Vector3.new(0.28, 1.6, 0.28),
			CFrame.new(0, -1.3, 0),
			Color3.fromRGB(80, 55, 35),
			Enum.Material.Wood
		)
		tip =
			add("Orb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 3.8, 0), color, Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = tip
	end

	if def.Glow then
		tip.Material = Enum.Material.Neon
		tip.Color = def.Glow
		local light = Instance.new("PointLight")
		light.Color = def.Glow
		light.Range = 10
		light.Parent = tip
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(def.Glow)
		sparks.LightEmission = 1
		sparks.Rate = 12
		sparks.Lifetime = NumberRange.new(0.4, 0.8)
		sparks.Speed = NumberRange.new(0.5, 1.5)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new(0.2, 0)
		sparks.Parent = tip
	end

	return model, handle
end

ModelBuilder.Weld = weld
ModelBuilder.Part = part

return ModelBuilder
