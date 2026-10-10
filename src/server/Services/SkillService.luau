-- Spending skill points and resetting the tree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Stats = require(Shared.Stats)

local SkillService = {}
local Services

function SkillService.Unlock(player, nodeId)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return { ok = false }
	end
	local ok, reason = Stats.CanUnlock(data, nodeId)
	if not ok then
		return { ok = false, message = reason }
	end
	data.SkillPoints -= 1
	data.Skills[nodeId] = (data.Skills[nodeId] or 0) + 1
	Services.PlayerService.RefreshStats(player)
	local node = Stats.FindNode(nodeId)
	if node.Ability then
		Services.PlayerService.Notify(player, "New ability: " .. node.Name .. "! Check your hotbar.", "Success")
	end
	return { ok = true }
end

function SkillService.RespecCost(data)
	return Stats.SkillPointsSpent(data) * GameConfig.RespecCostPerPoint
end

function SkillService.Respec(player)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return { ok = false }
	end
	local spent = Stats.SkillPointsSpent(data)
	if spent == 0 then
		return { ok = false, message = "You have no skills to reset." }
	end
	local cost = SkillService.RespecCost(data)
	if not Services.PlayerService.SpendGold(player, cost) then
		return { ok = false, message = "You need " .. cost .. " gold." }
	end
	data.Skills = {}
	data.SkillPoints += spent
	Services.PlayerService.RefreshStats(player)
	Services.PlayerService.Notify(player, "Your skills have been reset. " .. spent .. " points refunded.", "Success")
	return { ok = true }
end

function SkillService.Init(services)
	Services = services
end

return SkillService
