-- Puts hair, race features, the equipped weapon, cape, aura and title on a player's character.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Races = require(Shared.Config.Races)
local Crafting = require(Shared.Config.Crafting)
local ModelBuilder = require(script.Parent.Parent.Lib.ModelBuilder)

local AppearanceService = {}
local Services

local GEAR_FOLDER = "MargeronGear"

local function clearGear(character)
	local old = character:FindFirstChild(GEAR_FOLDER)
	if old then
		old:Destroy()
	end
	local head = character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("TitleTag")
	if tag then
		tag:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local aura = root and root:FindFirstChild("Aura")
	if aura then
		aura:Destroy()
	end
end

local function attachTo(base, folder, name, size, offset, color, material, shape)
	local p = ModelBuilder.Part({
		Name = name,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
	})
	if shape == "Ellipsoid" then
		-- A sphere mesh stretched to the part's size: smooth, rounded hair and beards.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape then
		p.Shape = shape
	end
	p.CFrame = base.CFrame * offset
	ModelBuilder.Weld(base, p, offset)
	p.Parent = folder
	return p
end

-- How big the head actually looks. Classic heads are a 2x1x1 part with a scaled mesh, so the
-- part's Size alone is misleading.
local function headScale(head)
	local height = head.Size.Y
	if not head:IsA("MeshPart") then
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			height = head.Size.Y * mesh.Scale.Y
		end
	end
	return height / 1.2
end

-- Hair styles, in head space (Y up, -Z is the face). s = head scale (1 = a 1.2-stud head).
local hairBuilders = {}
local HAIR = Enum.Material.SmoothPlastic
local E = "Ellipsoid"

local function cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"HairCap",
		Vector3.new(1.34, 0.95, 1.36) * s,
		CFrame.new(0, 0.3 * s, 0.06 * s),
		color,
		HAIR,
		E
	)
	attachTo(
		head,
		folder,
		"HairBack",
		Vector3.new(1.3, 1.05, 0.75) * s,
		CFrame.new(0, 0.04 * s, 0.36 * s),
		color,
		HAIR,
		E
	)
end

hairBuilders.Short = cap
function hairBuilders.Swept(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"HairFront",
		Vector3.new(1.15, 0.45, 0.85) * s,
		CFrame.new(0, 0.62 * s, -0.18 * s) * CFrame.Angles(math.rad(18), 0, 0),
		color,
		HAIR,
		E
	)
end
function hairBuilders.Long(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"HairLong",
		Vector3.new(1.25, 2.1, 0.5) * s,
		CFrame.new(0, -0.62 * s, 0.48 * s),
		color,
		HAIR,
		E
	)
	for side = -1, 1, 2 do
		attachTo(
			head,
			folder,
			"HairSide",
			Vector3.new(0.3, 1.5, 0.75) * s,
			CFrame.new(side * 0.6 * s, -0.25 * s, 0.12 * s),
			color,
			HAIR,
			E
		)
	end
end
function hairBuilders.Ponytail(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Tie",
		Vector3.new(0.3, 0.3, 0.3) * s,
		CFrame.new(0, 0.15 * s, 0.7 * s),
		color:Lerp(Color3.new(0, 0, 0), 0.4),
		HAIR,
		E
	)
	attachTo(
		head,
		folder,
		"Tail",
		Vector3.new(0.38, 1.4, 0.38) * s,
		CFrame.new(0, -0.45 * s, 0.82 * s) * CFrame.Angles(math.rad(-12), 0, 0),
		color,
		HAIR,
		E
	)
end
function hairBuilders.Braids(head, folder, s, color)
	cap(head, folder, s, color)
	for side = -1, 1, 2 do
		attachTo(
			head,
			folder,
			"Braid",
			Vector3.new(0.3, 1.6, 0.3) * s,
			CFrame.new(side * 0.55 * s, -0.75 * s, 0.12 * s),
			color,
			HAIR,
			E
		)
	end
end
function hairBuilders.Topknot(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(head, folder, "Bun", Vector3.new(0.62, 0.62, 0.62) * s, CFrame.new(0, 0.82 * s, 0.18 * s), color, HAIR, E)
end
function hairBuilders.Mohawk(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Mohawk",
		Vector3.new(0.28, 0.7, 1.35) * s,
		CFrame.new(0, 0.62 * s, 0.06 * s),
		color,
		HAIR,
		E
	)
end
function hairBuilders.Wild(head, folder, s, color)
	cap(head, folder, s, color)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		attachTo(
			head,
			folder,
			"Spike",
			Vector3.new(0.32, 0.75, 0.32) * s,
			CFrame.new(math.cos(a) * 0.42 * s, 0.68 * s, math.sin(a) * 0.42 * s)
				* CFrame.Angles(math.sin(a) * 0.7, 0, -math.cos(a) * 0.7),
			color,
			HAIR,
			E
		)
	end
end

-- Beards wrap the lower half of the face (chin at about y = -0.45, face surface at z = -0.6).
local beardBuilders = {}
function beardBuilders.Stubble(head, folder, s, color)
	local p = attachTo(
		head,
		folder,
		"Stubble",
		Vector3.new(1.06, 0.55, 1.0) * s,
		CFrame.new(0, -0.3 * s, -0.04 * s),
		color,
		HAIR,
		E
	)
	p.Transparency = 0.45
end
function beardBuilders.Short(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Beard",
		Vector3.new(1.02, 0.62, 0.78) * s,
		CFrame.new(0, -0.4 * s, -0.2 * s),
		color,
		HAIR,
		E
	)
end
function beardBuilders.Full(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Beard",
		Vector3.new(1.1, 0.95, 0.82) * s,
		CFrame.new(0, -0.55 * s, -0.2 * s),
		color,
		HAIR,
		E
	)
	attachTo(
		head,
		folder,
		"Moustache",
		Vector3.new(0.62, 0.15, 0.2) * s,
		CFrame.new(0, -0.14 * s, -0.58 * s),
		color,
		HAIR,
		E
	)
end
function beardBuilders.Braided(head, folder, s, color)
	beardBuilders.Full(head, folder, s, color)
	attachTo(
		head,
		folder,
		"BeardBraid",
		Vector3.new(0.28, 0.9, 0.28) * s,
		CFrame.new(0, -1.12 * s, -0.42 * s),
		color,
		HAIR,
		E
	)
end

-- Clothes over the R15 body: sleeves, a belted tunic with a hem, collar and lacing, and boots.
-- The body colours (tunic torso, trouser legs) come from the HumanoidDescription; these parts add
-- the shape so the character reads as dressed rather than as coloured blocks.
local LEATHER = Color3.fromRGB(70, 48, 32)
local function attachClothes(character, folder, appearance)
	local outfit = Races.Outfits[appearance.Outfit] or Races.Outfits[1]
	local tunic, trousers = outfit.Tunic, outfit.Trousers
	local trim = tunic:Lerp(Color3.new(0, 0, 0), 0.4)
	local FABRIC = Enum.Material.Fabric
	local function on(partName, name, grow, scaleY, offsetY, color, material)
		local base = character:FindFirstChild(partName)
		if not base or not base:IsA("BasePart") then
			return nil
		end
		local size = base.Size
		return attachTo(
			base,
			folder,
			name,
			Vector3.new(size.X + grow, size.Y * scaleY + (scaleY >= 1 and grow or 0), size.Z + grow),
			CFrame.new(0, size.Y * offsetY, 0),
			color,
			material or FABRIC
		)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		on(side .. "UpperArm", "Sleeve", 0.08, 1, 0, tunic)
		on(side .. "LowerArm", "Sleeve", 0.06, 0.55, 0.22, tunic)
		on(side .. "LowerArm", "Cuff", 0.1, 0.12, -0.06, trim)
		on(side .. "LowerLeg", "Boot", 0.1, 0.8, -0.1, LEATHER, Enum.Material.Leather)
		on(side .. "Foot", "Boot", 0.12, 1.1, 0.05, LEATHER, Enum.Material.Leather)
		on(side .. "UpperLeg", "Trousers", 0.04, 1, 0, trousers)
	end
	local upper = character:FindFirstChild("UpperTorso")
	if upper then
		local s = upper.Size
		attachTo(
			upper,
			folder,
			"Collar",
			Vector3.new(s.X * 0.5, 0.16, s.Z + 0.1),
			CFrame.new(0, s.Y / 2 - 0.05, 0),
			trim,
			FABRIC
		)
		attachTo(
			upper,
			folder,
			"Lacing",
			Vector3.new(0.16, s.Y * 0.45, 0.05),
			CFrame.new(0, s.Y * 0.2, -s.Z / 2 - 0.03),
			trim,
			FABRIC
		)
	end
	local lower = character:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		local hem = appearance.Gender == "Female" and 1.5 or 0.9
		attachTo(
			lower,
			folder,
			"Belt",
			Vector3.new(s.X + 0.14, 0.3, s.Z + 0.14),
			CFrame.new(0, s.Y / 2 - 0.1, 0),
			LEATHER,
			Enum.Material.Leather
		)
		attachTo(
			lower,
			folder,
			"Buckle",
			Vector3.new(0.34, 0.26, 0.06),
			CFrame.new(0, s.Y / 2 - 0.1, -s.Z / 2 - 0.09),
			Color3.fromRGB(200, 170, 90),
			Enum.Material.Metal
		)
		attachTo(
			lower,
			folder,
			"Hem",
			Vector3.new(s.X + 0.18, hem, s.Z + 0.22),
			CFrame.new(0, -s.Y / 2 - hem / 2 + 0.15, 0),
			tunic,
			FABRIC
		)
	end
end

local function attachFeatures(character, folder, appearance)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local s = headScale(head)
	local race = Races.Races[appearance.Race] or Races.Races.Riverfolk
	local hairColor = Races.HairColors[appearance.HairColor] or Races.HairColors[1]
	local skin = race.SkinTones[appearance.SkinTone] or race.SkinTones[1]

	local hair = hairBuilders[appearance.Hair]
	if hair then
		hair(head, folder, s, hairColor)
	end
	local beard = beardBuilders[appearance.Beard]
	if beard then
		beard(head, folder, s, hairColor)
	end

	for _, feature in ipairs(race.Features) do
		if feature == "PointedEars" then
			for side = -1, 1, 2 do
				attachTo(
					head,
					folder,
					"Ear",
					Vector3.new(0.14, 0.7, 0.3) * s,
					CFrame.new(side * 0.62 * s, 0.2 * s, 0.05 * s)
						* CFrame.Angles(math.rad(-20), 0, math.rad(-side * 28)),
					skin,
					nil,
					E
				)
			end
		elseif feature == "Tusks" then
			for side = -1, 1, 2 do
				attachTo(
					head,
					folder,
					"Tusk",
					Vector3.new(0.1, 0.3, 0.1) * s,
					CFrame.new(side * 0.24 * s, -0.36 * s, -0.56 * s) * CFrame.Angles(0, 0, math.rad(side * 10)),
					Color3.fromRGB(240, 235, 215),
					nil,
					E
				)
			end
		elseif feature == "EmberEyes" then
			for side = -1, 1, 2 do
				local eye = attachTo(
					head,
					folder,
					"EmberEye",
					Vector3.new(0.16, 0.1, 0.05) * s,
					CFrame.new(side * 0.2 * s, 0.12 * s, -0.6 * s),
					Color3.fromRGB(255, 130, 40),
					Enum.Material.Neon,
					E
				)
				eye.CastShadow = false
			end
		end
	end
end

local WEAPON_TOOL = "MargeronWeapon"
local SHEATH = "MargeronSheath"
-- Sheathed: slung across the back, hilt over the right shoulder.
local BACK_OFFSET = CFrame.new(0.55, 1, 0.62) * CFrame.Angles(0, 0, math.rad(145))

local function removeWeapon(player, character)
	for _, container in ipairs({ character, player:FindFirstChild("Backpack") }) do
		local old = container and container:FindFirstChild(WEAPON_TOOL)
		if old then
			old:Destroy()
		end
	end
	local sheath = character:FindFirstChild(SHEATH)
	if sheath then
		sheath:Destroy()
	end
end

-- Drawn: a real Tool in the hand, so the character's own Animate script holds it up and plays
-- the built-in slash animation (which every player sees). Sheathed: welded across the back.
local function attachWeapon(player, character, weaponDef, infusionId)
	removeWeapon(player, character)
	local infusion = infusionId and Crafting.Infusions[infusionId]
	local def = weaponDef
	if infusion and not weaponDef.Glow then
		def = table.clone(weaponDef)
		def.Glow = infusion.Color
	end
	local model, handle = ModelBuilder.Weapon(def)

	if character:GetAttribute("WeaponDrawn") == true then
		local tool = Instance.new("Tool")
		tool.Name = WEAPON_TOOL
		tool.ToolTip = def.Name
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool.ManualActivationOnly = true
		tool.Grip = CFrame.new() -- the hand's grip attachment already points the blade forward
		-- Welds live inside each part (Part1), so moving the parts keeps them attached to the handle.
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = tool
		end
		model:Destroy()
		tool.Parent = character
		return
	end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		model:Destroy()
		return
	end
	model.Name = SHEATH
	model:PivotTo(torso.CFrame * BACK_OFFSET)
	ModelBuilder.Weld(torso, handle, BACK_OFFSET)
	model.Parent = character
end

-- Draw or sheathe the equipped weapon. Returns the new state.
function AppearanceService.SetWeaponDrawn(player, drawn)
	local character = player.Character
	local data = Services.PlayerService.GetData(player)
	if not character or not data then
		return false
	end
	if (character:GetAttribute("WeaponDrawn") == true) == drawn then
		return drawn
	end
	character:SetAttribute("WeaponDrawn", drawn)
	local weaponDef = Items.Weapons[data.EquippedWeapon] or Items.Weapons.IronSword
	attachWeapon(player, character, weaponDef, data.Crafting.Infusions[data.EquippedWeapon])
	return drawn
end

function AppearanceService.IsWeaponDrawn(player)
	local character = player.Character
	return character ~= nil and character:FindFirstChild(WEAPON_TOOL) ~= nil
end

function AppearanceService.WeaponTool(player)
	local character = player.Character
	return character and character:FindFirstChild(WEAPON_TOOL)
end

local function attachCape(character, folder, cosmetic)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local cape = ModelBuilder.Part({
		Name = "Cape",
		Size = Vector3.new(1.9, 2.8, 0.08),
		Color = cosmetic.Color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
	})
	-- Top edge of the cape sits at the shoulders, hanging down the back.
	local hang = CFrame.new(0, torso.Size.Y / 2 - cape.Size.Y / 2, torso.Size.Z / 2 + 0.08)
		* CFrame.Angles(math.rad(-4), 0, 0)
	cape.CFrame = torso.CFrame * hang
	ModelBuilder.Weld(torso, cape, hang)
	cape.Parent = folder
end

local function attachAura(character, color)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 18
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Parent = root
end

local function attachTitle(player, character, data)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local office = Services.GovernmentService and Services.GovernmentService.OfficeTitle(player)
	local title = Items.Cosmetics[data.Equipped.Title]
	local text = "Lv. " .. data.Level
	if office then
		text = office .. "  ·  " .. text
	elseif title then
		text = title.Name .. "  ·  " .. text
	end
	local tag = ModelBuilder.NameTag(
		head,
		2.4,
		text,
		nil,
		office and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(255, 225, 150)
	)
	tag.Name = "TitleTag"
	tag.Size = UDim2.fromOffset(240, 22)
	tag.MaxDistance = 60
end

function AppearanceService.Apply(player)
	local character = player.Character
	local data = Services.PlayerService.GetData(player)
	if not character or not data then
		return
	end
	clearGear(character)

	local folder = Instance.new("Folder")
	folder.Name = GEAR_FOLDER

	attachFeatures(character, folder, data.Appearance)
	attachClothes(character, folder, data.Appearance)

	local weaponDef = Items.Weapons[data.EquippedWeapon] or Items.Weapons.IronSword
	attachWeapon(player, character, weaponDef, data.Crafting.Infusions[data.EquippedWeapon])

	local cape = Items.Cosmetics[data.Equipped.Cape]
	if cape and data.Cosmetics[data.Equipped.Cape] then
		attachCape(character, folder, cape)
	end
	local aura = Items.Cosmetics[data.Equipped.Aura]
	if aura and data.Cosmetics[data.Equipped.Aura] then
		attachAura(character, aura.Color)
	elseif Services.GovernmentService and Services.GovernmentService.OfficeOf(player) == "Lord" then
		attachAura(character, Color3.fromRGB(255, 215, 90))
	end
	attachTitle(player, character, data)

	folder.Parent = character
end

function AppearanceService.Init(services)
	Services = services
end

return AppearanceService
