-- Puts the equipped weapon, cape, aura and title on a player's character.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
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

local function attachWeapon(character, folder, weaponDef)
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

	local model, handle = ModelBuilder.Weapon(weaponDef)
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

local function attachAura(character, cosmetic)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Color = ColorSequence.new(cosmetic.Color)
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

local function attachTitle(character, data)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local title = Items.Cosmetics[data.Equipped.Title]
	local text = "Lv. " .. data.Level
	if title then
		text = title.Name .. "  ·  " .. text
	end
	local tag = ModelBuilder.NameTag(head, 2.2, text, nil, Color3.fromRGB(255, 225, 150))
	tag.Name = "TitleTag"
	tag.Size = UDim2.fromOffset(220, 22)
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

	local weaponDef = Items.Weapons[data.EquippedWeapon] or Items.Weapons.IronSword
	attachWeapon(character, folder, weaponDef)

	local cape = Items.Cosmetics[data.Equipped.Cape]
	if cape and data.Cosmetics[data.Equipped.Cape] then
		attachCape(character, folder, cape)
	end
	local aura = Items.Cosmetics[data.Equipped.Aura]
	if aura and data.Cosmetics[data.Equipped.Aura] then
		attachAura(character, aura)
	end
	attachTitle(character, data)

	folder.Parent = character
end

function AppearanceService.Init(services)
	Services = services
end

return AppearanceService
