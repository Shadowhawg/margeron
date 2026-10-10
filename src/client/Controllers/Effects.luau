-- Renders visual effects the server asks for: swings, bolts, bursts, damage numbers, etc.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function swing(character, weaponType)
	local gear = character and character:FindFirstChild("MargeronGear")
	local weapon = gear and gear:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local grip = handle and handle:FindFirstChild("WeaponGrip")
	if not grip then
		return
	end
	local base = originalGrips[grip]
	if not base then
		base = grip.C0
		originalGrips[grip] = base
	end
	local windBack, strike
	if weaponType == "Staff" then
		windBack = base * CFrame.new(0, 0, 0.6)
		strike = base * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(-15), 0, 0)
	else
		windBack = base * CFrame.Angles(math.rad(-50), 0, math.rad(-20))
		strike = base * CFrame.Angles(math.rad(70), 0, math.rad(25))
	end
	local t1 = TweenService:Create(grip, TweenInfo.new(0.07), { C0 = windBack })
	local t2 = TweenService:Create(grip, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { C0 = strike })
	local t3 = TweenService:Create(grip, TweenInfo.new(0.15), { C0 = base })
	t1:Play()
	t1.Completed:Wait()
	t2:Play()
	t2.Completed:Wait()
	t3:Play()
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

local function windup(model, duration)
	if not model or not model.Parent then
		return
	end
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
	Spin = function(character)
		swing(character, "Sword")
	end,
	Bolt = bolt,
	Burst = burst,
	Windup = windup,
	DamageNumber = function(position, amount, crit)
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

function Effects.Start()
	Remotes.Effect.OnClientEvent:Connect(function(kind, ...)
		local handler = handlers[kind]
		if handler then
			task.spawn(handler, ...)
		end
	end)
end

return Effects
