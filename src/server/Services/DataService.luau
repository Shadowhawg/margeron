-- Loads and saves player data with retries and a session lock (stops item duplication by
-- hopping servers). Falls back to temporary in-memory data in Studio when API access is off.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Races = require(Shared.Config.Races)
local Util = require(Shared.Util)
local Signal = require(script.Parent.Parent.Lib.Signal)

local SESSION_LOCK_SECONDS = GameConfig.AutosaveInterval * 3
local LOAD_ATTEMPTS = 6

local TEMPLATE = {
	Level = 1,
	XP = 0,
	Gold = GameConfig.StartingGold,
	SkillPoints = 0,
	Skills = {},
	Weapons = { IronSword = true },
	EquippedWeapon = "IronSword",
	Cosmetics = {},
	Equipped = { Cape = "", Aura = "", Title = "" },
	Materials = {},
	Quests = { Active = {}, Completed = {} },
	TrackedQuest = "",
	Bounties = {
		Defs = {},
		Board = {},
		BoardRefreshedAt = 0,
		DailyTakenDay = 0,
		Counter = 0,
		Completed = 0,
	},
	Renown = 0,
	Stats = { Kills = 0, QuestsCompleted = 0, Deaths = 0, Crafted = 0, Harvested = 0 },
	Purchases = {},

	-- Character creation
	Appearance = Util.DeepCopy(Races.Default),
	-- Story progress: prologue and unlocked memories
	Story = { PrologueSeen = false, Echoes = {} },
	-- Exploration: discovered landmark/zone ids
	Discoveries = {},
	-- Crafting: level, discovered ingredient effects, weapon tempering and infusions
	Crafting = { XP = 0, Level = 1, Known = {}, Temper = {}, Infusions = {} },
	-- Potions and food: { [key] = count }
	Consumables = {},
	-- Active buffs: { [effectId] = { Until = serverTime, Magnitude = n } }
	Buffs = {},
	CraftBoostUntil = 0,
	-- Permanent Robux perks (game passes) recorded here as flags
	Passes = {},
	-- Property: home tier, farm fields, livestock and horses
	Property = {
		Home = "",
		Fields = {},
		Animals = {},
		Horses = {},
		ActiveHorse = "",
	},
	-- Local government participation
	Gov = { VotedTerm = -1, RanTerm = -1 },
}

local DataService = {}
DataService.Loaded = Signal.new() -- (player, data)

local store = nil
local profiles = {} -- [Player] = data
local noSave = {} -- [Player] = true when loading failed; never overwrite their real save

local function key(player)
	return "Player_" .. player.UserId
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.IsPersistent()
	return store ~= nil
end

local function loadData(player)
	if not store then
		return Util.DeepCopy(TEMPLATE), true
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local force = attempt == LOAD_ATTEMPTS
		local lockedElsewhere = false
		local loaded = nil

		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				lockedElsewhere = false
				if
					not force
					and old
					and old.SessionJobId
					and old.SessionJobId ~= game.JobId
					and os.time() - (old.SessionTime or 0) < SESSION_LOCK_SECONDS
				then
					lockedElsewhere = true
					return nil
				end
				local data = old or Util.DeepCopy(TEMPLATE)
				data.SessionJobId = game.JobId
				data.SessionTime = os.time()
				loaded = data
				return data
			end)
		end)

		if ok and loaded then
			return Util.Reconcile(loaded, TEMPLATE), true
		end
		if not ok then
			warn("[DataService] Load failed for", player.Name, err)
		end
		if lockedElsewhere then
			warn("[DataService] Session locked elsewhere for", player.Name, "- retrying")
		end
		task.wait(5)
	end

	return Util.DeepCopy(TEMPLATE), false
end

function DataService.Save(player, release)
	local data = profiles[player]
	if not data or not store or noSave[player] then
		return true
	end

	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			if old and old.SessionJobId and old.SessionJobId ~= game.JobId then
				return nil -- another server owns this save now
			end
			data.SessionJobId = if release then nil else game.JobId
			data.SessionTime = os.time()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
	return ok
end

local function onPlayerAdded(player)
	local data, ok = loadData(player)
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		if ok and store then
			profiles[player] = data
			DataService.Save(player, true)
			profiles[player] = nil
		end
		return
	end
	if not ok then
		noSave[player] = true
	end
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
	if not ok then
		task.delay(3, function()
			local Remotes = require(Shared.Remotes)
			Remotes.Notify:FireClient(player, {
				Text = "Could not load your save. Progress this session will NOT be saved. Try rejoining.",
				Kind = "Error",
			})
		end)
	end
end

local function onPlayerRemoving(player)
	if profiles[player] then
		DataService.Save(player, true)
	end
	profiles[player] = nil
	noSave[player] = nil
end

function DataService.Init()
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(GameConfig.DataStoreName)
		ds:GetAsync("__probe") -- errors in Studio when API access is disabled
		return ds
	end)
	if ok then
		store = result
	else
		warn(
			"[DataService] DataStores unavailable, using temporary data. In Studio enable "
				.. "Game Settings > Security > Enable Studio Access to API Services. ("
				.. tostring(result)
				.. ")"
		)
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(GameConfig.AutosaveInterval)
		for player in pairs(profiles) do
			task.spawn(DataService.Save, player, false)
		end
	end
end

return DataService
