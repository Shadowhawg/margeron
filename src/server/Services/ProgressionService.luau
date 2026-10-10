--!strict
-- Spending: gear upgrades, niche unlocks/selection, and Rebrand (prestige).
-- Every handler re-validates against server data; the client UI is only a suggestion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Game = require(Shared.Config.Game)
local Gear = require(Shared.Config.Gear)
local Niches = require(Shared.Config.Niches)
local Types = require(Shared.Types)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Remotes = require(script.Parent.Parent.Util.Remotes)

local ProgressionService = {}

local function buyGear(player: Player, rawTrack: unknown): Types.ActionResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	local trackId = Guard.oneOf(rawTrack, Gear.Tracks)
	if not trackId then
		return { ok = false, err = "Unknown item" }
	end
	local level = data.Gear[trackId]
	local nextTier = Gear.tier(trackId, level + 1)
	if not nextTier then
		return { ok = false, err = "Already maxed!" }
	end
	if data.Cash < nextTier.Cost then
		return { ok = false, err = "Not enough cash" }
	end
	data.Cash -= nextTier.Cost
	data.Gear[trackId] = level + 1
	Analytics.step(player, data, "FirstUpgrade")
	Analytics.economy(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		nextTier.Cost,
		data.Cash,
		Enum.AnalyticsEconomyTransactionType.Shop,
		`{trackId}{level + 1}`
	)
	DataService.markDirty(player)
	return { ok = true }
end

local function owns(data: Types.PlayerData, nicheId: string): boolean
	return table.find(data.Niches, nicheId) ~= nil
end

local function unlockNiche(player: Player, rawId: unknown): Types.ActionResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	local id = Guard.oneOf(rawId, Niches.ById)
	local index = id and Niches.indexOf(id)
	if not id or not index then
		return { ok = false, err = "Unknown niche" }
	end
	if owns(data, id) then
		return { ok = false, err = "Already unlocked" }
	end
	local niche = Niches.List[index]
	if index > 1 and not owns(data, Niches.List[index - 1].Id) then
		return { ok = false, err = `Unlock {Niches.List[index - 1].Name} first` }
	end
	if data.Followers < niche.Followers then
		return { ok = false, err = "Need more followers" }
	end
	if data.Cash < niche.Cost then
		return { ok = false, err = "Not enough cash" }
	end
	data.Cash -= niche.Cost
	table.insert(data.Niches, id)
	data.ActiveNiche = id
	Analytics.step(player, data, "FirstNiche")
	Analytics.economy(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		niche.Cost,
		data.Cash,
		Enum.AnalyticsEconomyTransactionType.Shop,
		`Niche_{id}`
	)
	DataService.markDirty(player)
	return { ok = true }
end

local function selectNiche(player: Player, rawId: unknown): Types.ActionResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	local id = Guard.oneOf(rawId, Niches.ById)
	if not id or not owns(data, id) then
		return { ok = false, err = "Locked" }
	end
	data.ActiveNiche = id
	DataService.markDirty(player)
	return { ok = true }
end

local function rebrand(player: Player): Types.ActionResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	if data.Followers < Economy.rebrandRequirement(data.Rebrands) then
		return { ok = false, err = "Need more followers" }
	end
	-- Keep: niches, lifetime followers, weekly progress, cosmetics. Reset: cash, gear, followers.
	data.Rebrands += 1
	data.Cash = 0
	data.Followers = 0
	for _, trackId in Gear.Order do
		data.Gear[trackId] = 1
	end
	Analytics.custom(player, "Rebrand", data.Rebrands)
	DataService.markDirty(player)
	local payload: Types.NotifyPayload = {
		Kind = "Milestone",
		Text = `⭐ {player.DisplayName} rebranded and is now a {Game.titleFor(data.Rebrands).Name}!`,
	}
	Remotes.event("Notify"):FireAllClients(payload)
	return { ok = true }
end

function ProgressionService.start()
	Remotes.handle("BuyGear", { capacity = 6, perSecond = 3 }, buyGear)
	Remotes.handle("UnlockNiche", { capacity = 4, perSecond = 1 }, unlockNiche)
	Remotes.handle("SelectNiche", { capacity = 6, perSecond = 2 }, selectNiche)
	Remotes.handle("Rebrand", { capacity = 2, perSecond = 0.2 }, rebrand)
end

return ProgressionService
