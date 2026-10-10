-- Player input for attacking and abilities (mouse/keyboard, gamepad and touch).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Net)
local HUD = require(script.Parent.HUD)
local Windows = require(script.Parent.Windows)
local Cinematic = require(script.Parent.Cinematic)
local Creator = require(script.Parent.Parent.Panels.Creator)
local CraftingRules = require(Shared.CraftingRules)

local player = Players.LocalPlayer

local Combat = {}

local GAMEPAD_KEYS = {
	Whirlwind = Enum.KeyCode.ButtonX,
	Firebolt = Enum.KeyCode.ButtonY,
	Shadowstep = Enum.KeyCode.ButtonL2,
}

local attackHeld = false
local lastAttack = 0
local boundAbilities = {}

local function getRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- Where the player is aiming: the mouse on PC, otherwise where the camera looks.
local function aimDirection(root)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mousePos = UserInputService:GetMouseLocation()
		local ray = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		local target = result and result.Position or (ray.Origin + ray.Direction * 500)
		local dir = target - origin
		if dir.Magnitude > 0.5 then
			return dir.Unit
		end
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	return Vector3.new(look.X, math.clamp(look.Y, -0.3, 0.3), look.Z).Unit
end

-- Aim assist: snap to the nearest living enemy you're roughly facing (or aiming at), so swings
-- connect without pixel-perfect mouse aim. Staffs only assist within a narrow cone.
local function assistedAim(root, aim, range, coneDot)
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return aim
	end
	local facing = root.CFrame.LookVector
	local best, bestScore = nil, math.huge
	for _, model in ipairs(folder:GetChildren()) do
		local enemyRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if enemyRoot and not model:GetAttribute("Dead") then
			local offset = enemyRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dist = flat.Magnitude
			if dist <= range and dist > 0.1 then
				local toward = flat.Unit
				local aimFlat = Vector3.new(aim.X, 0, aim.Z)
				aimFlat = aimFlat.Magnitude > 0.01 and aimFlat.Unit or facing
				local dot = math.max(toward:Dot(aimFlat), toward:Dot(facing))
				if dot >= coneDot then
					local score = dist * (2 - dot)
					if score < bestScore then
						best, bestScore = offset, score
					end
				end
			end
		end
	end
	return best and best.Unit or aim
end

-- Turn toward the aim without fighting the default auto-rotation (which caused the jitter).
local autoRotateToken = 0
local function faceDirection(root, dir)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if flat.Magnitude < 0.01 or not humanoid then
		return
	end
	autoRotateToken += 1
	local token = autoRotateToken
	humanoid.AutoRotate = false
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	task.delay(0.45, function()
		if token == autoRotateToken and humanoid.Parent then
			humanoid.AutoRotate = true
		end
	end)
end

-- No fighting during cutscenes, conversations, menus or the character creator.
local function blocked()
	local creator = Creator.Open_
	return Windows.IsOpen() or Cinematic.Active or creator
end

local function tryAttack()
	local root = getRoot()
	local stats = State.Stats
	if not root or not stats then
		return
	end
	local now = os.clock()
	if now - lastAttack < stats.Weapon.Cooldown then
		return
	end
	lastAttack = now
	HUD.StartCooldown("Attack", stats.Weapon.Cooldown)
	local weapon = stats.Weapon
	local dir = aimDirection(root)
	if weapon.Type == "Staff" then
		dir = assistedAim(root, dir, weapon.Range, 0.94)
	else
		dir = assistedAim(root, dir, weapon.Range + 6, -0.2)
	end
	faceDirection(root, dir)
	Remotes.Attack:FireServer(dir)
end

local function shadowstepDash(root, dir)
	local ability = Abilities.Shadowstep
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = root.CFrame.LookVector
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(root.Position, flat * ability.Distance, params)
	local distance = result and math.max(0, (result.Position - root.Position).Magnitude - 2.5) or ability.Distance
	local target = root.Position + flat * distance
	root.CFrame = CFrame.lookAt(target, target + flat)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function useAbility(abilityId)
	local root = getRoot()
	local stats = State.Stats
	if not root or not stats or not stats.Abilities[abilityId] or HUD.IsOnCooldown(abilityId) then
		return
	end
	local dir = aimDirection(root)
	if abilityId == "Firebolt" then
		dir = assistedAim(root, dir, Abilities.Firebolt.Range, 0.9)
	end
	faceDirection(root, dir)
	-- Optimistically show the cooldown, then correct it from the server's answer.
	HUD.StartCooldown(abilityId, 0.5)
	local result = Net.Request("UseAbility", abilityId, dir)
	if result.ok then
		HUD.StartCooldown(abilityId, result.cooldown)
		if abilityId == "Shadowstep" then
			local currentRoot = getRoot()
			if currentRoot then
				shadowstepDash(currentRoot, dir)
			end
		end
	else
		HUD.ResetCooldown(abilityId)
	end
end

local function bindAbilities()
	local stats = State.Stats
	if not stats then
		return
	end
	for _, abilityId in ipairs(Abilities.Order) do
		local unlocked = stats.Abilities[abilityId] == true
		if unlocked and not boundAbilities[abilityId] then
			boundAbilities[abilityId] = true
			local actionName = "Ability_" .. abilityId
			ContextActionService:BindAction(actionName, function(_, inputState)
				if inputState == Enum.UserInputState.Begin and not blocked() then
					task.spawn(useAbility, abilityId)
				end
				return Enum.ContextActionResult.Sink
			end, true, Abilities[abilityId].Key, GAMEPAD_KEYS[abilityId])
			ContextActionService:SetTitle(actionName, Abilities[abilityId].Name)
		elseif not unlocked and boundAbilities[abilityId] then
			boundAbilities[abilityId] = nil
			ContextActionService:UnbindAction("Ability_" .. abilityId)
		end
	end
end

function Combat.Start()
	-- Mouse: hold to keep attacking. Clicks on UI are ignored (processed == true).
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed and not blocked() then
			attackHeld = true
			tryAttack()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackHeld = false
		end
	end)

	-- Gamepad trigger and an on-screen button for touch devices.
	ContextActionService:BindAction("Attack", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			attackHeld = true
			tryAttack()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			attackHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("Attack", "Attack")
	ContextActionService:SetPosition("Attack", UDim2.new(1, -170, 1, -160))

	task.spawn(function()
		while true do
			task.wait(0.05)
			if attackHeld and not blocked() then
				tryAttack()
			end
		end
	end)

	State.Observe(bindAbilities)

	-- Crouch / sneak: slower, much harder for enemies to notice, sneak attacks deal double damage.
	ContextActionService:BindAction("Crouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not blocked() then
			local character = player.Character
			local crouching = character and character:GetAttribute("Crouching") == true
			task.spawn(Net.Request, "SetCrouch", not crouching)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Crouch", "Sneak")
	ContextActionService:SetPosition("Crouch", UDim2.new(1, -330, 1, -100))

	-- Ride / dismount your horse.
	ContextActionService:BindAction("Mount", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not blocked() then
			task.spawn(Net.Request, "ToggleMount")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.H, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("Mount", "Ride")
	ContextActionService:SetPosition("Mount", UDim2.new(1, -250, 1, -100))

	-- Quick heal: drink the strongest healing potion you carry.
	ContextActionService:BindAction("QuickHeal", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or blocked() or not State.Data then
			return Enum.ContextActionResult.Sink
		end
		local bestKey, bestHeal = nil, 0
		for key in pairs(State.Data.Consumables) do
			local info = CraftingRules.Describe(key)
			for _, e in ipairs(info and info.Effects or {}) do
				if e.Id == "RestoreHealth" and e.Magnitude > bestHeal then
					bestKey, bestHeal = key, e.Magnitude
				end
			end
		end
		if bestKey then
			task.spawn(Net.Request, "UseConsumable", bestKey)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.DPadUp)

	Remotes.Effect.OnClientEvent:Connect(function(kind, abilityId)
		if kind == "CooldownReset" then
			HUD.ResetCooldown(abilityId)
		end
	end)
end

return Combat
