-- Quest state helpers shared by the server (authoritative) and client (UI, markers).
local Config = script.Parent.Config
local Quests = require(Config.Quests)

local QuestRules = {}

-- Static quests live in Config/Quests; bounties carry their definition in the save data.
function QuestRules.GetDef(data, key)
	return Quests[key] or (data.Bounties.Defs[key])
end

function QuestRules.GetProgress(data, key, index)
	local def = QuestRules.GetDef(data, key)
	local active = data.Quests.Active[key]
	if not def or not active then
		return 0
	end
	local objective = def.Objectives[index]
	if objective.Kind == "Collect" then
		return math.min(data.Materials[objective.Target] or 0, objective.Count)
	end
	return math.min(active.Progress[index] or 0, objective.Count)
end

function QuestRules.IsReady(data, key)
	local def = QuestRules.GetDef(data, key)
	if not def or not data.Quests.Active[key] then
		return false
	end
	for i, objective in ipairs(def.Objectives) do
		if QuestRules.GetProgress(data, key, i) < objective.Count then
			return false
		end
	end
	return true
end

-- Returns true or false, reason
function QuestRules.CanAccept(data, questId)
	local def = Quests[questId]
	if not def then
		return false, "Unknown quest"
	end
	if data.Quests.Active[questId] or data.Quests.Completed[questId] then
		return false, "Already taken"
	end
	if data.Level < (def.LevelReq or 1) then
		return false, "Requires level " .. def.LevelReq
	end
	for _, req in ipairs(def.Requires or {}) do
		if not data.Quests.Completed[req] then
			return false, "Not yet available"
		end
	end
	return true
end

-- Quests an NPC can offer right now (ignores level so we can tease locked ones).
function QuestRules.OffersFor(data, npcId)
	local list = {}
	for _, questId in ipairs(Quests.Order) do
		local def = Quests[questId]
		if def.Giver == npcId and not data.Quests.Active[questId] and not data.Quests.Completed[questId] then
			local prereqsDone = true
			for _, req in ipairs(def.Requires or {}) do
				if not data.Quests.Completed[req] then
					prereqsDone = false
				end
			end
			if prereqsDone then
				table.insert(list, questId)
			end
		end
	end
	return list
end

-- Active quests (in display order: main, side, bounties) as a list of keys.
function QuestRules.ActiveKeys(data)
	local keys = {}
	for _, questId in ipairs(Quests.Order) do
		if data.Quests.Active[questId] then
			table.insert(keys, questId)
		end
	end
	local bountyKeys = {}
	for key in pairs(data.Quests.Active) do
		if not Quests[key] then
			table.insert(bountyKeys, key)
		end
	end
	table.sort(bountyKeys)
	for _, key in ipairs(bountyKeys) do
		table.insert(keys, key)
	end
	return keys
end

return QuestRules
