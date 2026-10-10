-- Story quests, side quests and bounties all flow through here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local World = require(Shared.Config.World)
local Items = require(Shared.Config.Items)
local Enemies = require(Shared.Config.Enemies)
local GameConfig = require(Shared.Config.GameConfig)
local QuestRules = require(Shared.QuestRules)

local QuestService = {}
local Services

local function npcName(npcId)
	local npc = World.NPCs[npcId]
	return npc and npc.Name or npcId
end

local function notify(player, text, kind)
	Services.PlayerService.Notify(player, text, kind)
end

local function startQuest(player, data, key, def)
	local progress = {}
	for i in ipairs(def.Objectives) do
		progress[i] = 0
	end
	data.Quests.Active[key] = { Progress = progress }
	if data.TrackedQuest == "" or not data.Quests.Active[data.TrackedQuest] then
		data.TrackedQuest = key
	end
	notify(player, "Quest started: " .. def.Name, "Quest")
	Services.PlayerService.Changed(player)
end

-- Quests with no giver start on their own once their requirements are met (e.g. the opening quest).
function QuestService.GrantAutomaticQuests(player)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return
	end
	for _, questId in ipairs(Quests.Order) do
		local def = Quests[questId]
		if def.Giver == nil and QuestRules.CanAccept(data, questId) then
			startQuest(player, data, questId, def)
		end
	end
end

function QuestService.Accept(player, questId)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return { ok = false }
	end
	local ok, reason = QuestRules.CanAccept(data, questId)
	if not ok then
		return { ok = false, message = reason }
	end
	startQuest(player, data, questId, Quests[questId])
	return { ok = true }
end

-- Called by BountyService with a generated definition.
function QuestService.StartBounty(player, def)
	local data = Services.PlayerService.GetData(player)
	data.Bounties.Counter += 1
	local key = "B" .. data.Bounties.Counter
	data.Bounties.Defs[key] = def
	startQuest(player, data, key, def)
	return key
end

function QuestService.CountActiveBounties(data)
	local n = 0
	for key in pairs(data.Quests.Active) do
		if data.Bounties.Defs[key] then
			n += 1
		end
	end
	return n
end

local function checkReady(player, data, key, def)
	if QuestRules.IsReady(data, key) then
		local where = def.TurnIn == "Board" and "the Bounty Board" or npcName(def.TurnIn)
		notify(player, def.Name .. ": complete! Return to " .. where .. ".", "Quest")
	end
end

function QuestService.OnEnemyKilled(player, enemyId)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return
	end
	local changed = false
	for key, active in pairs(data.Quests.Active) do
		local def = QuestRules.GetDef(data, key)
		if def then
			for i, objective in ipairs(def.Objectives) do
				if objective.Kind == "Kill" and objective.Target == enemyId and active.Progress[i] < objective.Count then
					active.Progress[i] += 1
					changed = true
					local enemyName = Enemies[enemyId] and Enemies[enemyId].Name or enemyId
					notify(player, enemyName .. " " .. active.Progress[i] .. "/" .. objective.Count, "Progress")
					if active.Progress[i] >= objective.Count then
						checkReady(player, data, key, def)
					end
				end
			end
		end
	end
	if changed then
		Services.PlayerService.Changed(player)
	end
end

function QuestService.OnMaterialsChanged(player, materialId)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return
	end
	for key in pairs(data.Quests.Active) do
		local def = QuestRules.GetDef(data, key)
		if def then
			for i, objective in ipairs(def.Objectives) do
				if objective.Kind == "Collect" and objective.Target == materialId then
					local have = QuestRules.GetProgress(data, key, i)
					local name = Items.Materials[materialId].Name
					notify(player, name .. " " .. have .. "/" .. objective.Count, "Progress")
					if have >= objective.Count then
						checkReady(player, data, key, def)
					end
				end
			end
		end
	end
end

local function updateRenownTitles(player, data)
	for _, entry in ipairs(GameConfig.RenownTitles) do
		if data.Renown >= entry.Renown then
			for cosmeticId, cosmetic in pairs(Items.Cosmetics) do
				if cosmetic.Slot == "Title" and cosmetic.Name == entry.Title then
					Services.InventoryService.GrantCosmetic(player, cosmeticId)
				end
			end
		end
	end
end

function QuestService.TurnIn(player, key)
	local data = Services.PlayerService.GetData(player)
	local def = QuestRules.GetDef(data, key)
	if not def or not QuestRules.IsReady(data, key) then
		return nil
	end

	for _, objective in ipairs(def.Objectives) do
		if objective.Kind == "Collect" then
			Services.InventoryService.RemoveMaterial(player, objective.Target, objective.Count)
		end
	end

	data.Quests.Active[key] = nil
	data.Stats.QuestsCompleted += 1
	if data.TrackedQuest == key then
		data.TrackedQuest = ""
	end

	local bounty = data.Bounties.Defs[key]
	if bounty then
		data.Bounties.Defs[key] = nil
		data.Bounties.Completed += 1
		data.Renown += bounty.Daily and 3 or 1
		updateRenownTitles(player, data)
	else
		data.Quests.Completed[key] = true
	end

	local rewards = def.Rewards or {}
	local parts = {}
	if rewards.XP then
		table.insert(parts, rewards.XP .. " XP")
	end
	if rewards.Gold then
		table.insert(parts, rewards.Gold .. " gold")
	end
	notify(player, "Quest complete: " .. def.Name .. "  (+" .. table.concat(parts, ", +") .. ")", "QuestComplete")

	if rewards.Gold then
		Services.PlayerService.AddGold(player, rewards.Gold)
	end
	if rewards.Weapon then
		Services.InventoryService.GrantWeapon(player, rewards.Weapon)
	end
	if rewards.Cosmetic then
		Services.InventoryService.GrantCosmetic(player, rewards.Cosmetic)
	end
	if rewards.XP then
		Services.PlayerService.AddXP(player, rewards.XP)
	end

	QuestService.GrantAutomaticQuests(player)
	Services.PlayerService.Changed(player)
	return def
end

-- Talking to an NPC advances "Talk" objectives and turns in finished quests.
-- Returns the completion lines to show in the dialogue.
function QuestService.OnTalk(player, npcId)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return {}
	end
	for key, active in pairs(data.Quests.Active) do
		local def = QuestRules.GetDef(data, key)
		if def then
			for i, objective in ipairs(def.Objectives) do
				if objective.Kind == "Talk" and objective.Target == npcId and active.Progress[i] < objective.Count then
					active.Progress[i] = objective.Count
				end
			end
		end
	end

	local completed = {}
	for _, key in ipairs(QuestRules.ActiveKeys(data)) do
		local def = QuestRules.GetDef(data, key)
		if def and def.TurnIn == npcId and QuestRules.IsReady(data, key) then
			local done = QuestService.TurnIn(player, key)
			if done then
				table.insert(completed, done)
			end
		end
	end
	Services.PlayerService.Changed(player)
	return completed
end

function QuestService.Abandon(player, key)
	local data = Services.PlayerService.GetData(player)
	local def = data and QuestRules.GetDef(data, key)
	if not def or not data.Quests.Active[key] then
		return { ok = false }
	end
	if def.Type == "Main" then
		return { ok = false, message = "You can't abandon the main story." }
	end
	data.Quests.Active[key] = nil
	if data.Bounties.Defs[key] then
		data.Bounties.Defs[key] = nil
	end
	if data.TrackedQuest == key then
		data.TrackedQuest = ""
	end
	notify(player, "Abandoned: " .. def.Name, "Info")
	Services.PlayerService.Changed(player)
	return { ok = true }
end

function QuestService.Track(player, key)
	local data = Services.PlayerService.GetData(player)
	if not data or not data.Quests.Active[key] then
		return { ok = false }
	end
	data.TrackedQuest = key
	Services.PlayerService.Changed(player)
	return { ok = true }
end

function QuestService.Init(services)
	Services = services
	Services.DataService.Loaded:Connect(function(player, data)
		-- Clean up quests removed from the config since the player last played.
		for key in pairs(data.Quests.Active) do
			if not QuestRules.GetDef(data, key) then
				data.Quests.Active[key] = nil
			end
		end
		QuestService.GrantAutomaticQuests(player)
	end)
end

return QuestService
