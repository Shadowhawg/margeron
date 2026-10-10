-- Crouching and sneaking. Crouched players move slower but enemies only notice them at a fraction
-- of their normal range (even less at night), and attacks on unaware enemies are sneak attacks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Calendar = require(Shared.Config.Calendar)
local Clock = require(Shared.Clock)

local StealthService = {}
local Services

local crouching = {} -- [Player] = true

StealthService.SpeedMultiplier = 0.55
StealthService.SneakAttackMultiplier = 2

function StealthService.IsCrouching(player)
	return crouching[player] == true
end

-- How far away an enemy notices this player, as a fraction of its aggro range.
function StealthService.DetectionMultiplier(player)
	if not crouching[player] then
		return 1
	end
	return Clock.IsNight() and Calendar.Night.SneakDetection or 0.45
end

function StealthService.SetCrouch(player, on)
	on = on == true
	local _, character = Services.PlayerService.GetHumanoid(player)
	if not character then
		return { ok = false }
	end
	if on and Services.PropertyService.IsMounted(player) then
		Services.PropertyService.Dismount(player)
	end
	crouching[player] = on or nil
	character:SetAttribute("Crouching", on or nil)
	Services.PlayerService.RefreshStats(player)
	return { ok = true }
end

function StealthService.Init(services)
	Services = services
	Players.PlayerRemoving:Connect(function(player)
		crouching[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			crouching[player] = nil
		end)
	end)
end

return StealthService
