-- Owns progression (XP, levels, gold), derived stats, characters and syncing data to the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Leveling = require(Shared.Leveling)
local Stats = require(Shared.Stats)
local Remotes = require(Shared.Remotes)

local PlayerService = {}
local Services

local statsCache = {} -- [Player] = computed stats
local pushQueued = {} -- [Player] = true

function PlayerService.GetData(player)
	return Services.DataService.Get(player)
end

function PlayerService.GetStats(player)
	return statsCache[player]
end

function PlayerService.GetHumanoid(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid, character
	end
	return nil
end

function PlayerService.Notify(player, text, kind)
	Remotes.Notify:FireClient(player, { Text = text, Kind = kind or "Info" })
end

local function sendState(player)
	pushQueued[player] = nil
	local data = PlayerService.GetData(player)
	if not data or not player.Parent then
		return
	end
	local snapshot = table.clone(data)
	snapshot.SessionJobId = nil
	snapshot.SessionTime = nil
	snapshot.Purchases = nil
	snapshot.Persistent = Services.DataService.IsPersistent()
	Remotes.State:FireClient(player, snapshot)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = data.Level
		leaderstats.Gold.Value = data.Gold
	end
end

-- Call after any change to a player's data. Batches multiple changes into one network send.
function PlayerService.Changed(player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(sendState, player)
end

local function applyToCharacter(player)
	local stats = statsCache[player]
	local humanoid = PlayerService.GetHumanoid(player)
	if not stats or not humanoid then
		return
	end
	local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = math.clamp(stats.MaxHealth * ratio, 1, stats.MaxHealth)
	humanoid.WalkSpeed = stats.WalkSpeed
	Services.AppearanceService.Apply(player)
end

-- Recompute stats after level/skill/equipment changes.
function PlayerService.RefreshStats(player)
	local data = PlayerService.GetData(player)
	if not data then
		return
	end
	statsCache[player] = Stats.Compute(data)
	applyToCharacter(player)
	PlayerService.Changed(player)
end

function PlayerService.AddXP(player, amount)
	local data = PlayerService.GetData(player)
	if not data or amount <= 0 then
		return
	end
	local newLevel, newXP, gained = Leveling.AddXP(data.Level, data.XP, math.floor(amount))
	data.Level = newLevel
	data.XP = newXP
	if gained > 0 then
		data.SkillPoints += gained * GameConfig.SkillPointsPerLevel
		PlayerService.RefreshStats(player)
		local humanoid, character = PlayerService.GetHumanoid(player)
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
			Remotes.Effect:FireAllClients("LevelUp", character)
		end
		PlayerService.Notify(player, "LEVEL UP! You are now level " .. newLevel .. ". New skill point available (K).", "LevelUp")
		Services.QuestService.GrantAutomaticQuests(player)
	end
	PlayerService.Changed(player)
end

function PlayerService.AddGold(player, amount)
	local data = PlayerService.GetData(player)
	if not data then
		return
	end
	data.Gold += math.floor(amount)
	PlayerService.Changed(player)
end

function PlayerService.SpendGold(player, amount)
	local data = PlayerService.GetData(player)
	if not data or data.Gold < amount then
		return false
	end
	data.Gold -= amount
	PlayerService.Changed(player)
	return true
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	-- Health is applied once the character is fully built.
	task.defer(function()
		local stats = statsCache[player]
		if stats then
			humanoid.MaxHealth = stats.MaxHealth
			humanoid.Health = stats.MaxHealth
		end
		applyToCharacter(player)
	end)
	humanoid.Died:Connect(function()
		local data = PlayerService.GetData(player)
		if data then
			data.Stats.Deaths += 1
		end
		task.delay(4, function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
end

local function onLoaded(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.Level
	level.Parent = leaderstats
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = data.Gold
	gold.Parent = leaderstats
	leaderstats.Parent = player

	-- Drop skill ranks that no longer exist (e.g. a node was removed from the config).
	for nodeId, rank in pairs(data.Skills) do
		if not Stats.FindNode(nodeId) then
			data.Skills[nodeId] = nil
			data.SkillPoints += rank
		end
	end

	statsCache[player] = Stats.Compute(data)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- Avatar loading can replace body parts, which would drop welded gear; re-apply it.
	player.CharacterAppearanceLoaded:Connect(function()
		applyToCharacter(player)
	end)
	player:LoadCharacter()
	PlayerService.Changed(player)
end

function PlayerService.Init(services)
	Services = services
	Services.DataService.Loaded:Connect(onLoaded)
end

function PlayerService.Start()
	Players.PlayerRemoving:Connect(function(player)
		statsCache[player] = nil
		pushQueued[player] = nil
	end)
end


return PlayerService
