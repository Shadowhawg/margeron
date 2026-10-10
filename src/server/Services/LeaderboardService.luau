--!strict
-- Global leaderboards on OrderedDataStore.
--
--   LB_Followers_AllTime_v1        lifetime followers (never resets, survives Rebrand)
--   LB_Followers_Week_v1_<weekId>  followers gained this UTC week (new key each Monday)
--
-- Budget: each server writes a player's two scores at most once per
-- LeaderboardWriteInterval (and on leave) only if they changed, and reads the top
-- LeaderboardSize of each board once per LeaderboardReadInterval. That's well inside the
-- per-server limits (SetAsync 60+10/player/min, GetSortedAsync 5+2/player/min).
-- When DataStores are unavailable (Studio without API access) boards fall back to the
-- players in this server.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Game = require(Shared.Config.Game)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local Remotes = require(script.Parent.Parent.Util.Remotes)

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local lastWritten: { [Player]: { allTime: number, week: number, weekId: number } } = {}
local names: { [number]: string } = {}
local cached: Types.LeaderboardPayload = { AllTime = {}, Weekly = {}, WeekEndsAt = 0 }

local function store(name: string): OrderedDataStore?
	local existing = stores[name]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		stores[name] = result
		return result
	end
	return nil
end

local function weeklyName(weekId: number): string
	return `LB_Followers_Week_v1_{weekId}`
end

local function write(player: Player, data: Types.PlayerData)
	local weekId = Economy.weekNumber(os.time())
	local weekValue = if data.Week.Id == weekId then math.floor(data.Week.Followers) else 0
	local allTimeValue = math.floor(data.LifetimeFollowers)
	local previous = lastWritten[player]
	local key = tostring(player.UserId)

	if not previous or previous.allTime ~= allTimeValue then
		local allTime = store("LB_Followers_AllTime_v1")
		if allTime then
			pcall(function()
				allTime:SetAsync(key, allTimeValue)
			end)
		end
	end
	if weekValue > 0 and (not previous or previous.week ~= weekValue or previous.weekId ~= weekId) then
		local weekly = store(weeklyName(weekId))
		if weekly then
			pcall(function()
				weekly:SetAsync(key, weekValue)
			end)
		end
	end
	lastWritten[player] = { allTime = allTimeValue, week = weekValue, weekId = weekId }
end

local function resolveNames(userIds: { number })
	local missing = {}
	for _, id in userIds do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

local function readTop(name: string): { Types.LeaderboardEntry }?
	local ordered = store(name)
	if not ordered then
		return nil
	end
	local ok, page = pcall(function()
		return ordered:GetSortedAsync(false, Game.LeaderboardSize):GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	local entries: { Types.LeaderboardEntry } = {}
	local ids = {}
	for rank, item in page do
		local userId = tonumber(item.key)
		if userId then
			table.insert(ids, userId)
			table.insert(entries, { Rank = rank, UserId = userId, Name = "", Value = item.value })
		end
	end
	resolveNames(ids)
	for _, entry in entries do
		entry.Name = names[entry.UserId] or "Creator"
	end
	return entries
end

local function localTop(valueOf: (Types.PlayerData) -> number): { Types.LeaderboardEntry }
	local entries: { Types.LeaderboardEntry } = {}
	for player, data in DataService.each() do
		table.insert(entries, { Rank = 0, UserId = player.UserId, Name = player.DisplayName, Value = valueOf(data) })
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	for rank, entry in entries do
		entry.Rank = rank
	end
	return entries
end

local function refresh()
	local now = os.time()
	local weekId = Economy.weekNumber(now)
	local allTime = readTop("LB_Followers_AllTime_v1") or localTop(function(data)
		return math.floor(data.LifetimeFollowers)
	end)
	local weekly = readTop(weeklyName(weekId)) or localTop(function(data)
		return if data.Week.Id == weekId then math.floor(data.Week.Followers) else 0
	end)
	cached = { AllTime = allTime, Weekly = weekly, WeekEndsAt = Economy.weekEndsAt(now) }
	Remotes.event("Leaderboard"):FireAllClients(cached)
	WorldService.updateBoards(cached)
end

function LeaderboardService.start()
	DataService.Loaded:Connect(function(player)
		Remotes.event("Leaderboard"):FireClient(player, cached)
	end)
	DataService.Releasing:Connect(function(player, data)
		write(player, data)
		lastWritten[player] = nil
	end)

	task.spawn(function()
		task.wait(5) -- let the first players load
		while true do
			refresh()
			task.wait(Game.LeaderboardReadInterval)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Game.LeaderboardWriteInterval)
			for player, data in DataService.each() do
				if player.Parent == Players then
					write(player, data)
				end
			end
		end
	end)
end

return LeaderboardService
