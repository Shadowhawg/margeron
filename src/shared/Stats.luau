-- Derives a player's combat stats from their level, skill tree and weapon. Shared so the
-- client can show the same numbers the server uses.
local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local Skills = require(Config.Skills)
local Items = require(Config.Items)
local Races = require(Config.Races)
local Crafting = require(Config.Crafting)

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

-- Current server time; works on both server and client.
function Stats.Now()
	return workspace:GetServerTimeNow()
end

-- Active (unexpired) buffs: { [effectId] = { Until, Magnitude } }
function Stats.ActiveBuffs(data, now)
	now = now or Stats.Now()
	local active = {}
	for effectId, buff in pairs(data.Buffs or {}) do
		if buff.Until > now and Crafting.Effects[effectId] then
			active[effectId] = buff
		end
	end
	return active
end

function Stats.Compute(data, now)
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
		Regeneration = 0,
		GoldFind = 0,
		XPBonus = 0,
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

	-- Race
	local appearance = data.Appearance
	local race = appearance and Races.Races[appearance.Race]
	if race then
		for stat, amount in pairs(race.Bonus) do
			stats[stat] += amount
		end
	end

	-- Potions and food
	for effectId, buff in pairs(Stats.ActiveBuffs(data, now)) do
		local effect = Crafting.Effects[effectId]
		if effect.Stat then
			stats[effect.Stat] += buff.Magnitude
		end
	end

	-- Weapon, tempering and infusion
	local weaponId = data.EquippedWeapon
	local weapon = Items.Weapons[weaponId] or Items.Weapons.IronSword
	stats.CritChance += weapon.CritBonus or 0
	local craft = data.Crafting
	local temper = craft and craft.Temper[weaponId] or 0
	stats.WeaponDamage = weapon.Damage * (1 + Crafting.Temper.DamagePerLevel * temper)
	stats.TemperLevel = temper
	local infusion = craft and craft.Infusions[weaponId] or nil
	stats.Infusion = infusion
	if infusion == "Vampiric" then
		stats.Lifesteal += 0.05
	elseif infusion == "Arcane" then
		stats.SpellPower += 0.15
	elseif infusion == "Fortune" then
		stats.GoldFind += 0.2
	end
	stats.MaxHealth = math.floor(stats.MaxHealth)
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
