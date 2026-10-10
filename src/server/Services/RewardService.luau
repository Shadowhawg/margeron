--!strict
-- Daily streak, Brand Deals (daily quests) and offline earnings.
-- All reward amounts are in "posts" (Economy.postValue multiples) so they scale with
-- progress, and the exact cash value is replicated to the client before claiming.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Game = require(Shared.Config.Game)
local Rewards = require(Shared.Config.Rewards)
local Types = require(Shared.Types)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Remotes = require(script.Parent.Parent.Util.Remotes)

local RewardService = {}

local function today(): number
	return Economy.dayNumber(os.time())
end

-- Daily streak ------------------------------------------------------------------------

local function nextDailyDay(data: Types.PlayerData, day: number): number
	if data.Daily.LastClaimDay == day - 1 then
		return (data.Daily.Streak % #Rewards.DailyPosts) + 1
	end
	return 1
end

function RewardService.dailyView(data: Types.PlayerData): { CanClaim: boolean, NextDay: number, NextReward: number, NextResetAt: number }
	local day = today()
	local canClaim = data.Daily.LastClaimDay < day
	-- If already claimed today, preview tomorrow's reward.
	local streakDay = if canClaim
		then nextDailyDay(data, day)
		else (data.Daily.Streak % #Rewards.DailyPosts) + 1
	return {
		CanClaim = canClaim,
		NextDay = streakDay,
		NextReward = Economy.postValue(data) * Rewards.DailyPosts[streakDay],
		NextResetAt = (day + 1) * 86400,
	}
end

local function claimDaily(player: Player): Types.ActionResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	local day = today()
	if data.Daily.LastClaimDay >= day then
		return { ok = false, err = "Come back tomorrow!" }
	end
	local streakDay = nextDailyDay(data, day)
	local amount = Economy.postValue(data) * Rewards.DailyPosts[streakDay]
	data.Cash += amount
	if streakDay == Rewards.DailyBoostDay then
		data.BoostEndsAt = math.max(data.BoostEndsAt, os.time()) + Game.BoostDuration
	end
	data.Daily.LastClaimDay = day
	data.Daily.Streak = streakDay
	Analytics.step(player, data, "FirstDaily")
	Analytics.economy(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		amount,
		data.Cash,
		Enum.AnalyticsEconomyTransactionType.TimedReward,
		`Daily{streakDay}`
	)
	DataService.markDirty(player)
	return { ok = true }
end

-- Brand Deals -------------------------------------------------------------------------

local function ensureDeals(player: Player, data: Types.PlayerData)
	local day = today()
	if data.Deals.Day == day then
		return
	end
	local rng = Random.new(day * 7919 + player.UserId)
	local pool = {}
	for index in Rewards.DealTemplates do
		table.insert(pool, index)
	end
	local templates, goals, progress, claimed = {}, {}, {}, {}
	for _ = 1, math.min(Rewards.DealsPerDay, #pool) do
		local templateIndex = table.remove(pool, rng:NextInteger(1, #pool)) :: number
		local template = Rewards.DealTemplates[templateIndex]
		table.insert(templates, templateIndex)
		table.insert(goals, template.Goals[rng:NextInteger(1, #template.Goals)])
		table.insert(progress, 0)
		table.insert(claimed, false)
	end
	data.Deals = { Day = day, Templates = templates, Goals = goals, Progress = progress, Claimed = claimed }
end

function RewardService.recordDeal(player: Player, data: Types.PlayerData, stat: Types.DealStat, amount: number)
	ensureDeals(player, data)
	local deals = data.Deals
	for i, templateIndex in deals.Templates do
		local template = Rewards.DealTemplates[templateIndex]
		if template and template.Stat == stat and not deals.Claimed[i] then
			deals.Progress[i] = math.min(deals.Goals[i], deals.Progress[i] + amount)
		end
	end
end

function RewardService.dealViews(player: Player, data: Types.PlayerData): { Types.DealView }
	ensureDeals(player, data)
	local deals = data.Deals
	local postValue = Economy.postValue(data)
	local views: { Types.DealView } = {}
	for i, templateIndex in deals.Templates do
		local template = Rewards.DealTemplates[templateIndex]
		if template then
			table.insert(views, {
				Sponsor = Rewards.Sponsors[((deals.Day + i + player.UserId) % #Rewards.Sponsors) + 1],
				Text = string.format(template.Text, deals.Goals[i]),
				Goal = deals.Goals[i],
				Progress = deals.Progress[i],
				Claimed = deals.Claimed[i],
				Reward = postValue * template.RewardPosts,
			})
		end
	end
	return views
end

local function claimDeal(player: Player, rawIndex: unknown): Types.ActionResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	ensureDeals(player, data)
	local index = Guard.integer(rawIndex, 1, #data.Deals.Templates)
	if not index then
		return { ok = false, err = "Unknown deal" }
	end
	local deals = data.Deals
	local template = Rewards.DealTemplates[deals.Templates[index]]
	if not template or deals.Claimed[index] or deals.Progress[index] < deals.Goals[index] then
		return { ok = false, err = "Not finished yet" }
	end
	local amount = Economy.postValue(data) * template.RewardPosts
	deals.Claimed[index] = true
	data.Cash += amount
	Analytics.economy(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		amount,
		data.Cash,
		Enum.AnalyticsEconomyTransactionType.Gameplay,
		`Deal_{template.Stat}`
	)
	DataService.markDirty(player)
	return { ok = true }
end

-- Offline earnings --------------------------------------------------------------------

-- Public so it can be exercised from the Studio command bar (see docs/MVP_BUILD.md).
function RewardService.grantOffline(player: Player, data: Types.PlayerData)
	if data.LastOnline <= 0 then
		return
	end
	local away = os.time() - data.LastOnline
	if away < Game.OfflineMinMinutes * 60 then
		return
	end
	MonetizationService.awaitReady(player)
	local capped = math.min(away, MonetizationService.offlineCapHours(player) * 3600)
	local posts = (capped / 60) * Game.EstimatedPostsPerMinute * Game.OfflineEfficiency
	local perPost = Economy.computePost({
		gear = data.Gear,
		niche = data.ActiveNiche,
		grade = "Good",
		trendMultiplier = 1,
		viral = false,
		collabers = 0,
		boosted = false,
		followers = data.Followers,
		rebrands = data.Rebrands,
		cashMultiplier = 1,
		followerMultiplier = 1,
	})
	local cash = math.floor(perPost.cash * posts)
	local followers = math.floor(perPost.followers * posts)
	if cash <= 0 and followers <= 0 then
		return
	end
	data.Cash += cash
	data.Followers += followers
	data.LifetimeFollowers += followers
	local week = Economy.weekNumber(os.time())
	if data.Week.Id ~= week then
		data.Week = { Id = week, Followers = 0 }
	end
	data.Week.Followers += followers
	Analytics.economy(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		cash,
		data.Cash,
		Enum.AnalyticsEconomyTransactionType.TimedReward,
		"Offline"
	)
	DataService.markDirty(player)
	local payload: Types.NotifyPayload = {
		Kind = "Offline",
		Text = "While you were away, your old videos kept getting views!",
		Cash = cash,
		Followers = followers,
	}
	Remotes.event("Notify"):FireClient(player, payload)
end

function RewardService.start()
	Remotes.handle("ClaimDaily", { capacity = 3, perSecond = 0.5 }, claimDaily)
	Remotes.handle("ClaimDeal", { capacity = 5, perSecond = 1 }, claimDeal)
	DataService.Loaded:Connect(function(player, data)
		ensureDeals(player, data)
		RewardService.grantOffline(player, data)
	end)
end

return RewardService
