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

local function faceDirection(root, dir)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
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
	local dir = aimDirection(root)
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
				if inputState == Enum.UserInputState.Begin and not Windows.IsOpen() then
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
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed and not Windows.IsOpen() then
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
			if attackHeld and not Windows.IsOpen() then
				tryAttack()
			end
		end
	end)

	State.Observe(bindAbilities)

	Remotes.Effect.OnClientEvent:Connect(function(kind, abilityId)
		if kind == "CooldownReset" then
			HUD.ResetCooldown(abilityId)
		end
	end)
end

return Combat
