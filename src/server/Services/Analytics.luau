--!strict
-- Thin, failure-proof wrapper over Roblox AnalyticsService (Creator Hub > Analytics).
--
-- * Onboarding funnel: each step logged once per player (tracked in data.Onboarding).
-- * Economy: post income is aggregated per player and flushed once a minute instead of
--   per post, which keeps us far below event throughput limits.
-- * Every event carries the player's A/B bucket in CustomField01 so any dashboard can be
--   split by experiment arm.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local Analytics = {}

-- Funnel steps in order. Keep names stable once live; dashboards key on step numbers.
Analytics.Funnel = {
	{ Key = "Joined", Name = "Joined" },
	{ Key = "FirstTake", Name = "Started first take" },
	{ Key = "FirstPost", Name = "Posted first video" },
	{ Key = "FifthPost", Name = "Posted 5 videos" },
	{ Key = "FirstUpgrade", Name = "Bought first gear" },
	{ Key = "FirstTrend", Name = "Posted a trend video" },
	{ Key = "FirstNiche", Name = "Unlocked a niche" },
	{ Key = "FirstViral", Name = "Filmed a Viral Moment" },
	{ Key = "Followers1K", Name = "Reached 1K followers" },
	{ Key = "FirstDaily", Name = "Claimed a daily reward" },
}

local stepIndex: { [string]: number } = {}
for index, step in Analytics.Funnel do
	stepIndex[step.Key] = index
end

-- Experiments: name -> number of arms. A player's arm is a stable hash of their UserId,
-- so they always see the same variant on every server. See docs/TECH.md for the plan.
Analytics.Experiments = {
	FirstTakeZone = 2, -- 0: wide zone for 3 takes (control), 1: wide zone for 6 takes
	TrendMultiplier = 2, -- 0: x2 (control), 1: x3
	ShopNudge = 2, -- 0: glow at first affordable upgrade (control), 1: auto-open shop once
}

function Analytics.bucket(player: Player, experiment: string): number
	local arms = Analytics.Experiments[experiment]
	if not arms then
		return 0
	end
	-- Mix the experiment name in so arms are independent across experiments.
	local hash = player.UserId
	for i = 1, #experiment do
		hash = (hash * 31 + string.byte(experiment, i)) % 2147483647
	end
	return hash % arms
end

local function fields(player: Player): { [string]: any }
	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = `ab:{Analytics.bucket(player, "FirstTakeZone")}{Analytics.bucket(
			player,
			"TrendMultiplier"
		)}{Analytics.bucket(player, "ShopNudge")}`,
	}
end

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: () -> any)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

function Analytics.step(player: Player, data: Types.PlayerData, key: string)
	local index = stepIndex[key]
	if not index or data.Onboarding[key] then
		return
	end
	data.Onboarding[key] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, Analytics.Funnel[index].Name, fields(player))
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, fields(player))
	end)
end

-- Immediate economy event, for discrete transactions (purchases, claims, upgrades).
function Analytics.economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	amount: number,
	endingBalance: number,
	transactionType: Enum.AnalyticsEconomyTransactionType,
	itemSku: string
)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			"Cash",
			math.floor(amount),
			math.floor(endingBalance),
			transactionType.Name,
			itemSku,
			fields(player)
		)
	end)
end

-- Aggregated post income, flushed every 60s.
local pendingPostCash: { [Player]: number } = {}
local balances: { [Player]: number } = {}

function Analytics.postIncome(player: Player, cash: number, endingBalance: number)
	pendingPostCash[player] = (pendingPostCash[player] or 0) + cash
	balances[player] = endingBalance
end

local function flush(player: Player)
	local amount = pendingPostCash[player]
	if amount and amount > 0 then
		Analytics.economy(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			amount,
			balances[player] or 0,
			Enum.AnalyticsEconomyTransactionType.Gameplay,
			"Posts"
		)
	end
	pendingPostCash[player] = nil
	balances[player] = nil
end

function Analytics.start()
	Players.PlayerRemoving:Connect(flush)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pendingPostCash do
				flush(player)
			end
		end
	end)
end

return Analytics
