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

--[[
	Dresses a humanoid Creature (the part-built rig) in clothes. Every garment is welded to the body
	part it belongs to, so it moves with the limbs when clients animate them.
	outfit fields (all optional):
	  Skin, Top, Sleeves (colour, or Skin for bare arms), Bottom, Boots, Belt, Trim
	  Hem = skirt length below the tunic (studs) | Robe = colour of a long robe over the legs
	  Apron, Tabard (+ TabardTrim), Cloak, Mantle (shoulder cape)
	  Hair = colour, HairStyle = "Short" | "Long" | "Bun" | "Bald", Beard = colour, BeardStyle = "Short" | "Long"
	  Hat = "Cap" | "Wide" | "Pointed" | "Straw" | "Hood" | "Helmet", HatColor
]]
function ModelBuilder.Clothe(model, info, outfit)
	local root = info.Root
	local s = root.Size.X / 2
	local hip = info.HipHeight
	local head = model:FindFirstChild("Head")
	local FABRIC = Enum.Material.Fabric
	local LEATHER = Enum.Material.Leather

	local function wear(parentPart, name, size, offset, color, material, shape)
		local p = part({
			Name = name,
			Size = size,
			Color = color,
			Material = material or FABRIC,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Massless = true,
		})
		if shape then
			p.Shape = shape
		end
		p.CFrame = parentPart.CFrame * offset
		weld(parentPart, p, offset)
		p.Parent = model
		return p
	end

	local skin = outfit.Skin or Color3.fromRGB(234, 192, 160)
	local top = outfit.Robe or outfit.Top or Color3.fromRGB(120, 90, 60)
	local bottom = outfit.Robe or outfit.Bottom or Color3.fromRGB(70, 55, 40)
	local trim = outfit.Trim or top:Lerp(Color3.new(0, 0, 0), 0.35)
	if head then
		head.Color = skin
	end
	root.Color = top
	root.Material = FABRIC

	-- Arms: sleeves in the tunic colour (or bare), hands in skin.
	for _, side in ipairs({ "LeftArm", "RightArm" }) do
		local arm = model:FindFirstChild(side)
		if arm then
			arm.Color = outfit.Sleeves or top
			arm.Material = FABRIC
			wear(
				arm,
				"Hand",
				Vector3.new(0.84, 0.5, 0.84) * s,
				CFrame.new(0, -0.95 * s, 0),
				skin,
				Enum.Material.SmoothPlastic
			)
			if outfit.Sleeves == nil then
				wear(arm, "Cuff", Vector3.new(0.86, 0.16, 0.86) * s, CFrame.new(0, -0.66 * s, 0), trim)
			end
		end
	end
	-- Legs: trousers and boots.
	for _, side in ipairs({ "LeftLeg", "RightLeg" }) do
		local leg = model:FindFirstChild(side)
		if leg then
			leg.Color = bottom
			leg.Material = FABRIC
			wear(
				leg,
				"Boot",
				Vector3.new(0.98 * s, hip * 0.38, 1.08 * s),
				CFrame.new(0, -hip / 2 + hip * 0.19, -0.04 * s),
				outfit.Boots or Color3.fromRGB(60, 42, 30),
				LEATHER
			)
		end
	end

	-- Torso details
	wear(root, "Collar", Vector3.new(1.15, 0.16, 1.08) * s, CFrame.new(0, 0.93 * s, 0), trim)
	if outfit.Belt ~= false then
		local belt = outfit.Belt or Color3.fromRGB(55, 38, 28)
		wear(root, "Belt", Vector3.new(2.08, 0.26, 1.08) * s, CFrame.new(0, -0.82 * s, 0), belt, LEATHER)
		wear(
			root,
			"Buckle",
			Vector3.new(0.34, 0.24, 0.06) * s,
			CFrame.new(0, -0.82 * s, -0.56 * s),
			Color3.fromRGB(200, 170, 90),
			Enum.Material.Metal
		)
	end
	if outfit.Robe then
		-- A long robe flaring over the legs, stopping just above the boots.
		local len = hip * 0.82
		wear(root, "Robe", Vector3.new(2.3 * s, len, 1.45 * s), CFrame.new(0, -s - len / 2, 0), outfit.Robe)
		wear(root, "RobeTrim", Vector3.new(2.34 * s, 0.18 * s, 1.49 * s), CFrame.new(0, -s - len + 0.09 * s, 0), trim)
	elseif outfit.Hem then
		wear(
			root,
			"Hem",
			Vector3.new(2.12 * s, outfit.Hem * s, 1.14 * s),
			CFrame.new(0, -s - outfit.Hem * s / 2, 0),
			top
		)
	end
	if outfit.Apron then
		wear(root, "Apron", Vector3.new(1.5 * s, 2.5 * s, 0.08 * s), CFrame.new(0, -0.55 * s, -0.56 * s), outfit.Apron)
	end
	if outfit.Tabard then
		for _, z in ipairs({ -0.56, 0.56 }) do
			wear(
				root,
				"Tabard",
				Vector3.new(1.3 * s, 2.7 * s, 0.07 * s),
				CFrame.new(0, -0.45 * s, z * s),
				outfit.Tabard
			)
		end
		wear(
			root,
			"Emblem",
			Vector3.new(0.6, 0.6, 0.05) * s,
			CFrame.new(0, 0.2 * s, -0.61 * s) * CFrame.Angles(0, 0, math.rad(45)),
			outfit.TabardTrim or Color3.fromRGB(220, 180, 70)
		)
	end
	if outfit.Mantle then
		wear(root, "Mantle", Vector3.new(2.5, 0.38, 1.3) * s, CFrame.new(0, 1.02 * s, 0), outfit.Mantle)
	end
	if outfit.Cloak then
		local len = 2 * s + hip * 0.75
		wear(
			root,
			"Cloak",
			Vector3.new(2.05 * s, len, 0.12 * s),
			CFrame.new(0, s - len / 2, 0.58 * s) * CFrame.Angles(math.rad(-4), 0, 0),
			outfit.Cloak
		)
	end

	if not head then
		return
	end
	-- Hair
	local style = outfit.HairStyle or "Short"
	local hatHidesHair = outfit.Hat == "Hood" or outfit.Hat == "Helmet"
	if outfit.Hair and style ~= "Bald" and not hatHidesHair then
		wear(head, "Hair", Vector3.new(1.28, 0.32, 1.28) * s, CFrame.new(0, 0.66 * s, 0.02 * s), outfit.Hair)
		wear(
			head,
			"HairBack",
			Vector3.new(1.28, style == "Long" and 1.7 or 0.95, 0.3) * s,
			CFrame.new(0, (style == "Long" and -0.2 or 0.2) * s, 0.52 * s),
			outfit.Hair
		)
		if style == "Bun" then
			wear(
				head,
				"Bun",
				Vector3.new(0.6, 0.6, 0.6) * s,
				CFrame.new(0, 0.55 * s, 0.75 * s),
				outfit.Hair,
				nil,
				Enum.PartType.Ball
			)
		end
	end
	if outfit.Beard then
		local long = outfit.BeardStyle == "Long"
		wear(
			head,
			"Beard",
			Vector3.new(1.0, long and 1.0 or 0.5, 0.26) * s,
			CFrame.new(0, (long and -0.62 or -0.42) * s, -0.56 * s),
			outfit.Beard
		)
	end
	-- Headwear
	local hatColor = outfit.HatColor or trim
	if outfit.Hat == "Hood" then
		wear(head, "HoodTop", Vector3.new(1.46, 0.3, 1.46) * s, CFrame.new(0, 0.72 * s, 0.02 * s), hatColor)
		wear(head, "HoodBack", Vector3.new(1.46, 1.35, 0.3) * s, CFrame.new(0, 0.05 * s, 0.62 * s), hatColor)
		for _, x in ipairs({ -0.66, 0.66 }) do
			wear(head, "HoodSide", Vector3.new(0.16, 1.35, 1.3) * s, CFrame.new(x * s, 0.05 * s, 0.05 * s), hatColor)
		end
		if not outfit.Mantle then
			wear(root, "Mantle", Vector3.new(2.3, 0.34, 1.25) * s, CFrame.new(0, 1.0 * s, 0), hatColor)
		end
	elseif outfit.Hat == "Cap" then
		wear(head, "Cap", Vector3.new(1.32, 0.34, 1.32) * s, CFrame.new(0, 0.74 * s, 0), hatColor)
		wear(head, "CapBrim", Vector3.new(1.34, 0.08, 0.5) * s, CFrame.new(0, 0.6 * s, -0.8 * s), hatColor)
	elseif outfit.Hat == "Wide" or outfit.Hat == "Straw" then
		local c = outfit.Hat == "Straw" and Color3.fromRGB(215, 190, 120) or hatColor
		wear(head, "HatBrim", Vector3.new(2.5, 0.1, 2.5) * s, CFrame.new(0, 0.66 * s, 0), c, nil)
		wear(head, "HatCrown", Vector3.new(1.3, 0.6, 1.3) * s, CFrame.new(0, 0.98 * s, 0), c, nil)
		wear(head, "HatBand", Vector3.new(1.34, 0.14, 1.34) * s, CFrame.new(0, 0.76 * s, 0), trim)
	elseif outfit.Hat == "Pointed" then
		for i, w in ipairs({ 1.5, 1.05, 0.65, 0.3 }) do
			wear(
				head,
				"WizardHat",
				Vector3.new(w, 0.42, w) * s,
				CFrame.new(0, (0.7 + (i - 1) * 0.4) * s, 0.04 * i * s),
				hatColor
			)
		end
		wear(head, "HatBrim", Vector3.new(2.3, 0.08, 2.3) * s, CFrame.new(0, 0.62 * s, 0), hatColor)
	elseif outfit.Hat == "Helmet" then
		wear(
			head,
			"Helmet",
			Vector3.new(1.36, 0.75, 1.36) * s,
			CFrame.new(0, 0.4 * s, 0.02 * s),
			hatColor,
			Enum.Material.Metal
		)
		wear(
			head,
			"NoseGuard",
			Vector3.new(0.16, 0.6, 0.1) * s,
			CFrame.new(0, 0.05 * s, -0.68 * s),
			hatColor,
			Enum.Material.Metal
		)
	end
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
