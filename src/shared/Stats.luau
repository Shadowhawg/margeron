-- Derives a player's combat stats from their level, skill tree and weapon. Shared so the
-- client can show the same numbers the server uses.
local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local Skills = require(Config.Skills)
local Items = require(Config.Items)

local Stats = {}

function Stats.FindNode(nodeId)
	for treeId, tree in pairs(Skills.Trees) do
		local node = tree.Nodes[nodeId]
		if node then
			return node, treeId
		end
	end
	return nil
end

function Stats.Compute(data)
	local level = data.Level
	local stats = {
		MaxHealth = GameConfig.BaseHealth + GameConfig.HealthPerLevel * (level - 1),
		PhysicalDamage = 1 + 0.03 * (level - 1),
		SpellPower = 1 + 0.03 * (level - 1),
		CritChance = 0.05,
		CritDamage = 1.5,
		Lifesteal = 0,
		DamageReduction = 0,
		WalkSpeed = GameConfig.BaseWalkSpeed,
		CooldownReduction = 0,
		BackstabBonus = 0,
		Flags = {},
		Abilities = {},
	}

	for nodeId, rank in pairs(data.Skills) do
		local node = Stats.FindNode(nodeId)
		if node and rank > 0 then
			if node.Effects then
				for stat, perRank in pairs(node.Effects) do
					stats[stat] += perRank * rank
				end
			end
			if node.Ability then
				stats.Abilities[node.Ability] = true
			end
			if node.Flag then
				stats.Flags[node.Flag] = true
			end
		end
	end

	local weapon = Items.Weapons[data.EquippedWeapon] or Items.Weapons.IronSword
	stats.CritChance += weapon.CritBonus or 0
	stats.DamageReduction = math.min(stats.DamageReduction, 0.6)
	stats.CooldownReduction = math.min(stats.CooldownReduction, 0.5)
	stats.Weapon = weapon
	return stats
end

function Stats.SkillPointsSpent(data)
	local total = 0
	for _, rank in pairs(data.Skills) do
		total += rank
	end
	return total
end

-- Returns true or false, reason
function Stats.CanUnlock(data, nodeId)
	local node = Stats.FindNode(nodeId)
	if not node then
		return false, "Unknown skill"
	end
	local rank = data.Skills[nodeId] or 0
	if rank >= node.MaxRank then
		return false, "Already mastered"
	end
	if data.SkillPoints <= 0 then
		return false, "No skill points"
	end
	local levelReq = GameConfig.TierLevelRequirements[node.Tier] or 1
	if data.Level < levelReq then
		return false, "Requires level " .. levelReq
	end
	for _, req in ipairs(node.Requires or {}) do
		if (data.Skills[req] or 0) < 1 then
			local reqNode = Stats.FindNode(req)
			return false, "Requires " .. (reqNode and reqNode.Name or req)
		end
	end
	return true
end

return Stats
