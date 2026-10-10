--!strict
-- Server entry point. Services are plain modules with optional init() (sync setup, no
-- yielding) and start() (connect events, spawn loops). Order matters only for init.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Types = require(Shared.Types)

local Services = script.Parent.Services
local Analytics = require(Services.Analytics)
local ContentService = require(Services.ContentService)
local DataService = require(Services.DataService)
local LeaderboardService = require(Services.LeaderboardService)
local MonetizationService = require(Services.MonetizationService)
local ProgressionService = require(Services.ProgressionService)
local RewardService = require(Services.RewardService)
local SocialService = require(Services.SocialService)
local ViralService = require(Services.ViralService)
local WorldService = require(Services.WorldService)

-- The replicated view of a player's state. Everything the client shows comes from here,
-- including pre-computed reward amounts, so the UI never has to guess at server math.
DataService.setStateBuilder(function(player: Player, data: Types.PlayerData): Types.ClientState
	return {
		Cash = data.Cash,
		Followers = data.Followers,
		LifetimeFollowers = data.LifetimeFollowers,
		Rebrands = data.Rebrands,
		TotalPosts = data.TotalPosts,
		Gear = data.Gear,
		Niches = data.Niches,
		ActiveNiche = data.ActiveNiche,
		BoostEndsAt = data.BoostEndsAt,
		AutoFilm = data.AutoFilm,
		PostValue = Economy.postValue(data),
		Daily = RewardService.dailyView(data),
		Deals = RewardService.dealViews(player, data),
		Passes = MonetizationService.ownedPasses(player),
		IsPremium = MonetizationService.isPremium(player),
		CashMultiplier = MonetizationService.cashMultiplier(player) * SocialService.cashMultiplier(player),
		FollowerMultiplier = MonetizationService.followerMultiplier(player),
		TrendMultiplier = ContentService.trendMultiplierFor(player),
		Experiments = {
			FirstTakeZone = Analytics.bucket(player, "FirstTakeZone"),
			TrendMultiplier = Analytics.bucket(player, "TrendMultiplier"),
			ShopNudge = Analytics.bucket(player, "ShopNudge"),
		},
	}
end)

DataService.Loaded:Connect(function(player, data)
	Analytics.step(player, data, "Joined")
end)

WorldService.init()

Analytics.start()
SocialService.start()
MonetizationService.start()
DataService.start()
RewardService.start()
ProgressionService.start()
ContentService.start()
ViralService.start()
WorldService.start()
LeaderboardService.start()
