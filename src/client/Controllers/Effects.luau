-- Renders visual effects the server asks for: swings, bolts, bursts, damage numbers, etc.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Notifications = require(script.Parent.Notifications)

local player = Players.LocalPlayer

local Effects = {}

local folder
local originalGrips = {} -- [Weld] = CFrame (weak keys so destroyed welds are collected)
setmetatable(originalGrips, { __mode = "k" })

local function effectPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function floatingText(position, text, color, size, duration)
	local anchor = effectPart({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Position = position })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	local offset = Vector3.new(math.random(-10, 10) / 10, 0, 0)
	TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 3, 0) + offset,
	}):Play()
	TweenService:Create(
		label,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, duration * 0.5),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()
	Debris:AddItem(anchor, duration + 0.1)
end

-- Built-in Roblox sounds (ship with every client, no upload needed).
local SOUNDS = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Hit = "rbxasset://sounds/swordlunge.wav",
	Equip = "rbxasset://sounds/unsheath.wav",
}

local function playSound(id, position, volume, pitch)
	local anchor = effectPart({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Position = position })
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or (0.9 + math.random() * 0.2)
	sound.RollOffMaxDistance = 120
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, 3)
end
Effects.PlaySound = playSound

-- The arm swing itself is the character's built-in slash animation (the server drops a "toolanim"
-- value into the held weapon); here we only add the whoosh.
local function swing(character, weaponType)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		playSound(weaponType == "Staff" and SOUNDS.Equip or SOUNDS.Swing, root.Position, 0.45)
	end
end

local function spin(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	playSound(SOUNDS.Swing, root.Position, 0.7, 0.8)
	local trail = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 10, 10),
		CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 230, 240),
		Transparency = 0.5,
		Material = Enum.Material.ForceField,
	})
	TweenService:Create(trail, TweenInfo.new(0.35), { Size = Vector3.new(0.3, 24, 24), Transparency = 1 }):Play()
	Debris:AddItem(trail, 0.4)
	swing(character, "Sword")
end

local function bolt(from, to, color, size)
	local ball = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Color = color,
		Position = from,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Parent = ball
	local duration = math.max(0.05, (to - from).Magnitude / 160)
	local tween = TweenService:Create(ball, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = to })
	tween:Play()
	tween.Completed:Connect(function()
		ball:Destroy()
	end)
end

local function burst(position, radius, color)
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.2,
	})
	local tween = TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, 0.4)
end

local windups = {} -- [Model] = { Start, Duration } (raised arms while an enemy winds up)
setmetatable(windups, { __mode = "k" })

local function windup(model, duration)
	if not model or not model.Parent then
		return
	end
	windups[model] = { Start = os.clock(), Duration = duration }
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 40)
	highlight.OutlineColor = Color3.fromRGB(255, 200, 120)
	highlight.FillTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(duration), { FillTransparency = 0.3 }):Play()
	Debris:AddItem(highlight, duration + 0.1)
end

local function sphereFlash(character, color, size)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sphere = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = root.Position,
		Color = color,
		Transparency = 0.4,
		Material = Enum.Material.ForceField,
	})
	TweenService:Create(sphere, TweenInfo.new(0.5), { Size = Vector3.new(size, size, size), Transparency = 1 }):Play()
	Debris:AddItem(sphere, 0.6)
end

local hurtEffect
local function hurt(damage)
	if not hurtEffect then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local intensity = humanoid and math.clamp(damage / humanoid.MaxHealth * 4, 0.15, 0.6) or 0.3
	hurtEffect.TintColor = Color3.new(1, 1 - intensity, 1 - intensity)
	TweenService:Create(hurtEffect, TweenInfo.new(0.4), { TintColor = Color3.new(1, 1, 1) }):Play()
end

local handlers = {
	Swing = function(character, weaponType)
		swing(character, weaponType)
	end,
	Spin = spin,
	Bolt = bolt,
	Burst = burst,
	Windup = windup,
	DamageNumber = function(position, amount, crit, model)
		playSound(SOUNDS.Hit, position, crit and 0.8 or 0.5, crit and 0.8 or nil)
		-- Hit flash: the enemy blinks white so every connecting blow is obvious.
		if model and model.Parent then
			local flash = Instance.new("Highlight")
			flash.FillColor = crit and Color3.fromRGB(255, 220, 90) or Color3.new(1, 1, 1)
			flash.FillTransparency = 0.35
			flash.OutlineTransparency = 1
			flash.DepthMode = Enum.HighlightDepthMode.Occluded
			flash.Parent = model
			TweenService:Create(flash, TweenInfo.new(0.25), { FillTransparency = 1 }):Play()
			Debris:AddItem(flash, 0.3)
		end
		if crit then
			floatingText(position, amount .. "!", Color3.fromRGB(255, 220, 60), 34, 0.9)
		else
			floatingText(position, tostring(amount), Color3.new(1, 1, 1), 24, 0.7)
		end
	end,
	Loot = function(position, text)
		floatingText(position + Vector3.new(0, 4, 0), text, Color3.fromRGB(255, 215, 120), 18, 1.8)
	end,
	LevelUp = function(character)
		sphereFlash(character, Color3.fromRGB(255, 210, 90), 18)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			burst(root.Position - Vector3.new(0, 2.5, 0), 14, Color3.fromRGB(255, 210, 90))
		end
	end,
	Ward = function(character)
		sphereFlash(character, Color3.fromRGB(120, 170, 255), 9)
	end,
	Hurt = hurt,
	Discovery = function(name, xp)
		Notifications.Banner("Discovered", name .. "   (+" .. xp .. " XP)")
	end,
	Drink = function(character, kind)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			burst(
				root.Position - Vector3.new(0, 2.5, 0),
				5,
				kind == "Food" and Color3.fromRGB(240, 200, 120) or Color3.fromRGB(120, 230, 150)
			)
		end
	end,
	Crafted = function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			playSound(SOUNDS.Equip, root.Position, 0.5)
			sphereFlash(player.Character, Color3.fromRGB(255, 220, 140), 7)
		end
	end,
	Text = function(text)
		Notifications.Show(text, "Success")
	end,
}

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace

	hurtEffect = Instance.new("ColorCorrectionEffect")
	hurtEffect.Name = "HurtFlash"
	hurtEffect.Parent = Lighting
end

-- Riders sit on their horse: play the character's own sit animation while mounted.
local mountTracks = {}
setmetatable(mountTracks, { __mode = "k" })

local function updateMountPose(character)
	local mounted = character:GetAttribute("Mounted") == true
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if mounted and animator and not mountTracks[character] then
		local animate = character:FindFirstChild("Animate")
		local sit = animate and animate:FindFirstChild("sit")
		local anim = sit and sit:FindFirstChildOfClass("Animation")
		if anim then
			local track = animator:LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play()
			mountTracks[character] = track
		end
	elseif not mounted and mountTracks[character] then
		mountTracks[character]:Stop()
		mountTracks[character] = nil
	end
end

-- Crouching: bend hips and knees, lower the body, lean forward. Joint C0 offsets layer on top of
-- the normal walk animation, so sneaking still animates.
local CROUCH_POSE = {
	{ Part = "LowerTorso", Joint = "Root", Pose = CFrame.new(0, -0.6, 0) },
	{ Part = "UpperTorso", Joint = "Waist", Pose = CFrame.Angles(math.rad(-18), 0, 0) },
	{ Part = "RightUpperLeg", Joint = "RightHip", Pose = CFrame.Angles(math.rad(55), 0, 0) },
	{ Part = "LeftUpperLeg", Joint = "LeftHip", Pose = CFrame.Angles(math.rad(55), 0, 0) },
	{ Part = "RightLowerLeg", Joint = "RightKnee", Pose = CFrame.Angles(math.rad(-75), 0, 0) },
	{ Part = "LeftLowerLeg", Joint = "LeftKnee", Pose = CFrame.Angles(math.rad(-75), 0, 0) },
}
local crouchBase = {}
setmetatable(crouchBase, { __mode = "k" })

local function updateCrouchPose(character)
	local crouching = character:GetAttribute("Crouching") == true
	for _, entry in ipairs(CROUCH_POSE) do
		local p = character:FindFirstChild(entry.Part)
		local joint = p and p:FindFirstChild(entry.Joint)
		if joint and joint:IsA("Motor6D") then
			local base = crouchBase[joint]
			if not base then
				base = joint.C0
				crouchBase[joint] = base
			end
			TweenService:Create(joint, TweenInfo.new(0.25), { C0 = crouching and base * entry.Pose or base }):Play()
		end
	end
	if character == player.Character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			TweenService:Create(
				humanoid,
				TweenInfo.new(0.25),
				{ CameraOffset = crouching and Vector3.new(0, -1.3, 0) or Vector3.zero }
			):Play()
		end
	end
end

-- Walkers (townsfolk, NPCs, enemies) are part-built rigs welded to their root. Swing their limbs
-- from the hip/shoulder as they move, and play simple activities ("Work", "Talk") when standing.
local LIMBS = { LeftArm = 1, RightArm = -1, LeftLeg = -1, RightLeg = 1 }
local ARMS = { LeftArm = false, RightArm = true } -- value: is it the right arm
local walkers = {} -- [Model] = { Joints = { {Weld, Base, Half, Phase, IsArm, IsRight} }, Clock }
setmetatable(walkers, { __mode = "k" })

local function setupWalker(model)
	if walkers[model] or not model:IsA("Model") then
		return
	end
	local joints = {}
	local legIndex = 0
	for _, limb in ipairs(model:GetChildren()) do
		local name: string = limb.Name
		if limb:IsA("BasePart") and (LIMBS[name] or name == "Leg") then
			local weld = limb:FindFirstChildOfClass("Weld")
			if weld then
				local isArm = ARMS[name] ~= nil
				local isRight = ARMS[name] == true
				local sign = LIMBS[name]
				if name == "Leg" then
					-- Beasts: front-left and back-right move together.
					legIndex += 1
					sign = (legIndex == 1 or legIndex == 4) and 1 or -1
				end
				table.insert(joints, {
					Weld = weld,
					Base = weld.C0,
					Half = limb.Size.Y / 2,
					Sign = sign,
					IsArm = isArm,
					IsRight = isRight,
				})
			end
		end
	end
	if #joints > 0 then
		walkers[model] = { Joints = joints, Phase = math.random() * 6, T = 0 }
	end
end

local function animateWalkers(dt)
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	for model, state in pairs(walkers) do
		local root = model.Parent and model.PrimaryPart
		if not root then
			walkers[model] = nil
			continue
		end
		if (root.Position - camPos).Magnitude > 160 then
			continue
		end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local moving = math.clamp(speed / 7, 0, 1)
		state.Phase += dt * (4 + speed * 0.9)
		state.T += dt
		local activity = model:GetAttribute("Activity")
		local wind = windups[model]
		local windAmount = 0
		if wind then
			local t = (now - wind.Start) / wind.Duration
			if t > 1.15 then
				windups[model] = nil
			else
				windAmount = t < 1 and t or (1.15 - t) / 0.15
			end
		end
		for _, joint in ipairs(state.Joints) do
			local swing = math.sin(state.Phase) * 0.7 * moving * joint.Sign
			if joint.IsArm and speed < 1 then
				if activity == "Work" and joint.IsRight then
					swing = -0.6 - math.abs(math.sin(state.T * 5)) * 1.1 -- hammering, sweeping, stirring
				elseif activity == "Talk" then
					swing = math.sin(state.T * 2.2 + (joint.IsRight and 0 or 1.7)) * 0.35 - 0.25
				end
			end
			if joint.IsArm and windAmount > 0 then
				swing = -2.6 * windAmount -- arms raised to strike
			end
			joint.Weld.C0 = joint.Base
				* CFrame.new(0, joint.Half, 0)
				* CFrame.Angles(swing, 0, 0)
				* CFrame.new(0, -joint.Half, 0)
		end
	end
end

local function watchCharacter(character)
	character:GetAttributeChangedSignal("Mounted"):Connect(function()
		updateMountPose(character)
	end)
	character:GetAttributeChangedSignal("Crouching"):Connect(function()
		updateCrouchPose(character)
	end)
	updateMountPose(character)
end

local function watchPlayer(p)
	p.CharacterAdded:Connect(watchCharacter)
	if p.Character then
		watchCharacter(p.Character)
	end
end

function Effects.Start()
	for _, model in ipairs(CollectionService:GetTagged("Walker")) do
		task.spawn(setupWalker, model)
	end
	CollectionService:GetInstanceAddedSignal("Walker"):Connect(function(model)
		task.wait(0.2) -- let the limbs replicate
		setupWalker(model)
	end)
	RunService.RenderStepped:Connect(animateWalkers)

	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	Remotes.Effect.OnClientEvent:Connect(function(kind, ...)
		local handler = handlers[kind]
		if handler then
			task.spawn(handler, ...)
		end
	end)
end

return Effects
