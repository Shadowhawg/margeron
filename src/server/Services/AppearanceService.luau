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
	if shape then
		p.Shape = shape
	end
	p.CFrame = base.CFrame * offset
	ModelBuilder.Weld(base, p, offset)
	p.Parent = folder
	return p
end

-- Hair styles, in head space (Y up, -Z is the face). s = head scale.
local hairBuilders = {}
local HAIR_MAT = Enum.Material.SmoothPlastic

local function cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"HairCap",
		Vector3.new(1.3, 0.45, 1.3) * s,
		CFrame.new(0, 0.5 * s, 0.05 * s),
		color,
		HAIR_MAT
	)
	attachTo(
		head,
		folder,
		"HairBack",
		Vector3.new(1.3, 0.8, 0.32) * s,
		CFrame.new(0, 0.18 * s, 0.56 * s),
		color,
		HAIR_MAT
	)
end

hairBuilders.Short = cap
function hairBuilders.Swept(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"HairFront",
		Vector3.new(1.2, 0.35, 0.7) * s,
		CFrame.new(0, 0.7 * s, -0.25 * s) * CFrame.Angles(math.rad(15), 0, 0),
		color,
		HAIR_MAT
	)
end
function hairBuilders.Long(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"HairLong",
		Vector3.new(1.3, 2.1, 0.3) * s,
		CFrame.new(0, -0.5 * s, 0.62 * s),
		color,
		HAIR_MAT
	)
	for side = -1, 1, 2 do
		attachTo(
			head,
			folder,
			"HairSide",
			Vector3.new(0.22, 1.5, 0.7) * s,
			CFrame.new(side * 0.66 * s, -0.15 * s, 0.15 * s),
			color,
			HAIR_MAT
		)
	end
end
function hairBuilders.Ponytail(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Tail",
		Vector3.new(0.38, 1.5, 0.38) * s,
		CFrame.new(0, -0.15 * s, 0.85 * s) * CFrame.Angles(math.rad(-15), 0, 0),
		color,
		HAIR_MAT
	)
end
function hairBuilders.Braids(head, folder, s, color)
	cap(head, folder, s, color)
	for side = -1, 1, 2 do
		attachTo(
			head,
			folder,
			"Braid",
			Vector3.new(0.32, 1.7, 0.32) * s,
			CFrame.new(side * 0.58 * s, -0.65 * s, 0.1 * s),
			color,
			HAIR_MAT
		)
	end
end
function hairBuilders.Topknot(head, folder, s, color)
	cap(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Bun",
		Vector3.new(0.65, 0.65, 0.65) * s,
		CFrame.new(0, 0.9 * s, 0.2 * s),
		color,
		HAIR_MAT,
		Enum.PartType.Ball
	)
end
function hairBuilders.Mohawk(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Mohawk",
		Vector3.new(0.25, 0.7, 1.35) * s,
		CFrame.new(0, 0.8 * s, 0.05 * s),
		color,
		HAIR_MAT
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
			Vector3.new(0.32, 0.7, 0.32) * s,
			CFrame.new(math.cos(a) * 0.45 * s, 0.75 * s, math.sin(a) * 0.45 * s)
				* CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6),
			color,
			HAIR_MAT
		)
	end
end

local beardBuilders = {}
function beardBuilders.Stubble(head, folder, s, color)
	local p = attachTo(
		head,
		folder,
		"Stubble",
		Vector3.new(1, 0.45, 0.06) * s,
		CFrame.new(0, -0.38 * s, -0.61 * s),
		color,
		HAIR_MAT
	)
	p.Transparency = 0.35
end
function beardBuilders.Short(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Beard",
		Vector3.new(1.05, 0.55, 0.35) * s,
		CFrame.new(0, -0.45 * s, -0.5 * s),
		color,
		HAIR_MAT
	)
end
function beardBuilders.Full(head, folder, s, color)
	attachTo(
		head,
		folder,
		"Beard",
		Vector3.new(1.15, 0.95, 0.45) * s,
		CFrame.new(0, -0.6 * s, -0.45 * s),
		color,
		HAIR_MAT
	)
	attachTo(
		head,
		folder,
		"Moustache",
		Vector3.new(0.7, 0.15, 0.12) * s,
		CFrame.new(0, -0.15 * s, -0.66 * s),
		color,
		HAIR_MAT
	)
end
function beardBuilders.Braided(head, folder, s, color)
	beardBuilders.Full(head, folder, s, color)
	attachTo(
		head,
		folder,
		"BeardBraid",
		Vector3.new(0.3, 1, 0.3) * s,
		CFrame.new(0, -1.3 * s, -0.55 * s),
		color,
		HAIR_MAT
	)
end

local function attachFeatures(character, folder, appearance)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local s = head.Size.Y / 1.2
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
					Vector3.new(0.14, 0.75, 0.32) * s,
					CFrame.new(side * 0.66 * s, 0.25 * s, 0.05 * s)
						* CFrame.Angles(math.rad(-20), 0, math.rad(-side * 28)),
					skin
				)
			end
		elseif feature == "Tusks" then
			for side = -1, 1, 2 do
				attachTo(
					head,
					folder,
					"Tusk",
					Vector3.new(0.12, 0.32, 0.12) * s,
					CFrame.new(side * 0.26 * s, -0.4 * s, -0.62 * s),
					Color3.fromRGB(240, 235, 215)
				)
			end
		elseif feature == "EmberEyes" then
			for side = -1, 1, 2 do
				local eye = attachTo(
					head,
					folder,
					"EmberEye",
					Vector3.new(0.16, 0.1, 0.05) * s,
					CFrame.new(side * 0.2 * s, 0.12 * s, -0.61 * s),
					Color3.fromRGB(255, 130, 40),
					Enum.Material.Neon
				)
				eye.CastShadow = false
			end
		end
	end
end

local function attachWeapon(character, folder, weaponDef, infusionId)
	local hand = character:FindFirstChild("RightHand")
	local gripOffset
	if hand then
		gripOffset = CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	else
		hand = character:FindFirstChild("Right Arm")
		gripOffset = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	if not hand then
		return
	end

	local infusion = infusionId and Crafting.Infusions[infusionId]
	local def = weaponDef
	if infusion and not weaponDef.Glow then
		def = table.clone(weaponDef)
		def.Glow = infusion.Color
	end
	local model, handle = ModelBuilder.Weapon(def)
	model:PivotTo(hand.CFrame * gripOffset)
	local grip = ModelBuilder.Weld(hand, handle, gripOffset)
	grip.Name = "WeaponGrip"
	model.Parent = folder
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

	local weaponDef = Items.Weapons[data.EquippedWeapon] or Items.Weapons.IronSword
	attachWeapon(character, folder, weaponDef, data.Crafting.Infusions[data.EquippedWeapon])

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
