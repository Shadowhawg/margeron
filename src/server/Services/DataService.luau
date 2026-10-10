--!strict
-- Player persistence on ProfileStore (session-locked, auto-saving, reconciled).
--
-- Safety guarantees:
--   * Session locking: a profile is only writable by one server at a time, so a player
--     hopping servers can't duplicate cash. A second server asking for the session makes
--     this server do a final save and release it (OnSessionEnd -> kick here).
--   * Versioned migrations run after Reconcile, so old saves upgrade in order.
--   * Sanitize() repairs impossible values (NaN, negatives, out-of-range tiers) on load
--     instead of letting one corrupted save brick a player.
--   * Studio play-tests use ProfileStore.Mock unless Config.Game.UseLiveDataInStudio.
--   * Rollback: ProfileStore:VersionQuery can restore an older DataStore version of a
--     key (see docs/TECH.md "Restoring a player").
--
-- Other services never touch DataStores directly. They mutate the table returned by
-- DataService.get(player) and call DataService.markDirty(player) to replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Config.Gear)
local Game = require(Shared.Config.Game)
local Niches = require(Shared.Config.Niches)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local Remotes = require(script.Parent.Parent.Util.Remotes)

type PlayerData = Types.PlayerData

type Connection = { Disconnect: (self: any) -> () }
-- The subset of ProfileStore's Profile API this game uses. Declared locally because the
-- library's generic JSON intersection types don't unify cleanly under --!strict, and it
-- keeps the rest of the codebase independent of wally-package-types.
export type Profile = {
	Data: any,
	LastSavedData: any,
	Key: string,
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	Save: (self: Profile) -> (),
	OnSave: { Connect: (self: any, listener: () -> ()) -> Connection },
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> Connection },
	OnAfterSave: { Connect: (self: any, listener: (lastSavedData: any) -> ()) -> Connection },
}
type Store = {
	StartSessionAsync: (self: Store, key: string, params: { Cancel: () -> boolean }) -> Profile?,
	Mock: Store,
}

local STORE_NAME = "PlayerData_v1"
local CURRENT_VERSION = 1
local FLUSH_INTERVAL = 0.1

local function template(): PlayerData
	return {
		Version = CURRENT_VERSION,
		Cash = 0,
		Followers = 0,
		LifetimeFollowers = 0,
		TotalViews = 0,
		TotalPosts = 0,
		PerfectTakes = 0,
		Rebrands = 0,
		Gear = { Camera = 1, Lighting = 1, Set = 1 },
		Niches = { Niches.Default },
		ActiveNiche = Niches.Default,
		Daily = { LastClaimDay = 0, Streak = 0 },
		Deals = { Day = 0, Templates = {}, Goals = {}, Progress = {}, Claimed = {} },
		Week = { Id = 0, Followers = 0 },
		BoostEndsAt = 0,
		AutoFilm = true,
		LastOnline = 0,
		FirstJoin = 0,
		Onboarding = {},
		PurchaseIdCache = {},
	}
end

-- Migrations upgrade data from version N to N+1. Never edit a shipped migration; add a
-- new one and bump CURRENT_VERSION. Example for a future v1 -> v2 rename:
--   [1] = function(data) data.Clout = data.Rebrands end,
local MIGRATIONS: { [number]: (data: any) -> () } = {}

local store = (ProfileStore.New(STORE_NAME, template() :: any) :: any) :: Store
local activeStore = if RunService:IsStudio() and not Game.UseLiveDataInStudio then store.Mock else store

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local stateBuilder: ((Player, PlayerData) -> Types.ClientState)? = nil

local DataService = {}

DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>
DataService.Releasing = Signal.new() :: Signal.Signal<Player, PlayerData>

local function dataOf(profile: Profile): PlayerData
	return profile.Data :: PlayerData
end

local function finiteNonNegative(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
		return 0
	end
	return value
end

local function migrate(data: any)
	if type(data.Version) ~= "number" then
		data.Version = 1
	end
	while data.Version < CURRENT_VERSION do
		local step = MIGRATIONS[data.Version]
		if step then
			step(data)
		end
		data.Version += 1
	end
end

local function sanitize(data: PlayerData)
	data.Cash = finiteNonNegative(data.Cash)
	data.Followers = finiteNonNegative(data.Followers)
	data.LifetimeFollowers = math.max(finiteNonNegative(data.LifetimeFollowers), data.Followers)
	data.TotalViews = finiteNonNegative(data.TotalViews)
	data.TotalPosts = finiteNonNegative(data.TotalPosts)
	data.PerfectTakes = finiteNonNegative(data.PerfectTakes)
	data.Rebrands = math.floor(finiteNonNegative(data.Rebrands))
	data.BoostEndsAt = finiteNonNegative(data.BoostEndsAt)

	for _, trackId in Gear.Order do
		local track = Gear.Tracks[trackId]
		local level = math.floor(finiteNonNegative(data.Gear[trackId]))
		data.Gear[trackId] = math.clamp(level, 1, #track.Tiers)
	end

	-- Keep only known, unique niches; the default niche is always owned.
	local seen: { [string]: boolean } = {}
	local cleaned = {}
	for _, id in data.Niches do
		if Niches.get(id) and not seen[id] then
			seen[id] = true
			table.insert(cleaned, id)
		end
	end
	if not seen[Niches.Default] then
		table.insert(cleaned, 1, Niches.Default)
		seen[Niches.Default] = true
	end
	data.Niches = cleaned
	if not seen[data.ActiveNiche] then
		data.ActiveNiche = Niches.Default
	end
end

local function createLeaderstats(player: Player, data: PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local followers = Instance.new("IntValue")
	followers.Name = "Followers"
	followers.Value = math.floor(data.Followers)
	followers.Parent = leaderstats
	leaderstats.Parent = player
end

local function syncPublic(player: Player, data: PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	local followers = leaderstats and leaderstats:FindFirstChild("Followers")
	if followers and followers:IsA("IntValue") then
		followers.Value = math.floor(data.Followers)
	end
	-- Attributes drive the overhead billboard (WorldService) and are visible to everyone.
	if player:GetAttribute("Followers") ~= data.Followers then
		player:SetAttribute("Followers", data.Followers)
	end
	if player:GetAttribute("Rebrands") ~= data.Rebrands then
		player:SetAttribute("Rebrands", data.Rebrands)
	end
end

local function onPlayerAdded(player: Player)
	local profile = activeStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Only happens if the session couldn't start (e.g. server shutting down).
		if player.Parent == Players then
			player:Kick("Couldn't load your data. Please rejoin!")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR right-to-erasure support
	profile:Reconcile()

	local data = dataOf(profile)
	migrate(data)
	sanitize(data)
	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end

	profile.OnSave:Connect(function()
		data.LastOnline = os.time()
	end)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		dirty[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin!")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	createLeaderstats(player, data)
	syncPublic(player, data)
	DataService.Loaded:Fire(player, data)
	DataService.markDirty(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		local data = dataOf(profile)
		data.LastOnline = os.time()
		DataService.Releasing:Fire(player, data)
		profile:EndSession()
	end
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return dataOf(profile)
	end
	return nil
end

function DataService.getProfile(player: Player): Profile?
	return profiles[player]
end

-- Yields until the player's data is loaded or they leave. Returns nil if they left.
function DataService.await(player: Player): PlayerData?
	while player.Parent == Players do
		local data = DataService.get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.each(): { [Player]: PlayerData }
	local result: { [Player]: PlayerData } = {}
	for player, profile in profiles do
		if profile:IsActive() then
			result[player] = dataOf(profile)
		end
	end
	return result
end

function DataService.markDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

function DataService.setStateBuilder(builder: (Player, PlayerData) -> Types.ClientState)
	stateBuilder = builder
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local stateEvent = Remotes.event("State")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < FLUSH_INTERVAL then
			return
		end
		elapsed = 0
		local builder = stateBuilder
		for player in dirty do
			dirty[player] = nil
			local data = DataService.get(player)
			if data then
				syncPublic(player, data)
				if builder then
					-- pcall so one bad snapshot can't stop the flush for everyone else.
					local ok, result = pcall(builder, player, data)
					if ok then
						stateEvent:FireClient(player, result)
					else
						warn(`[DataService] state build failed for {player.UserId}: {result}`)
					end
				end
			end
		end
	end)
end

return DataService
