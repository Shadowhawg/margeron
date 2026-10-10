--!strict
-- Tunable game constants. Economy curves live in Gear/Niches; this file holds timing,
-- social and system knobs. Keep tools/sim_economy.py in sync when changing economy values.

local Game = {
	-- Set to your Roblox group id to enable the +10% group bonus (0 = disabled).
	GroupId = 0,
	-- false = Studio play-tests use ProfileStore.Mock and never touch live player data.
	UseLiveDataInStudio = false,

	-- Core loop
	TakeDuration = 1.1, -- seconds the marker takes to sweep the bar
	PostCooldown = 0.45, -- server-enforced gap between the end of one take and the next StartTake
	TakeExpiry = 4, -- a take not submitted within duration + this is discarded
	LatencyTolerance = 0.06, -- seconds of clock jitter allowed when validating tap timing
	PerfectCoreFraction = 0.3, -- inner share of the green zone that counts as Perfect
	ZoneWidth = 0.22, -- green zone width as a fraction of the bar
	TutorialTakes = 3, -- first N takes use a wide zone; take #1 is always Perfect

	-- Multipliers
	TrendMultiplier = 2,
	TrendPeriod = 600, -- seconds per trend
	ViralMultiplier = 5,
	ViralInterval = 240,
	ViralDuration = 60,
	ViralRadius = 30,
	ViralFirstSpawnDelay = 40, -- a brand-new player gets a Viral Moment within this many seconds
	BoostDuration = 900, -- seconds of real time per Views Boost purchase

	-- Social
	CollabRadius = 25,
	CollabWindow = 10,
	CollabBonusEach = 0.2,
	CollabMax = 3,
	FriendBonusEach = 0.1,
	FriendMax = 3,
	GroupBonus = 0.1,
	PremiumCashBonus = 0.1,
	VipFollowerBonus = 0.2,
	-- "New creator buzz": x3 followers until 250 lifetime followers, so the very first
	-- posts visibly pop (+3 instead of +1) and Gaming unlocks in the first few minutes.
	NewCreatorThreshold = 250,
	NewCreatorFollowerBonus = 3,

	-- Auto-Film game pass
	AutoFilmInterval = 2.5,
	AutoFilmManualPause = 5, -- auto-film pauses while the player films manually

	-- Offline earnings
	OfflineMinMinutes = 5,
	OfflineCapHours = 8,
	OfflineCapHoursPass = 24,
	OfflineEfficiency = 0.1, -- share of active earnings granted while away
	EstimatedPostsPerMinute = 25,

	-- Rebrand (prestige)
	RebrandBase = 1_000_000,
	RebrandGrowth = 4,
	RebrandBonus = 0.5,

	-- Leaderboards
	LeaderboardWriteInterval = 120,
	LeaderboardReadInterval = 120,
	LeaderboardSize = 50,

	-- Follower milestones announced to the whole server
	Milestones = { 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000, 10_000_000_000 },

	-- Overhead titles by rebrand count (index = rebrands + 1, last entry repeats)
	Titles = {
		{ Name = "Newbie", Color = Color3.fromRGB(220, 220, 220) },
		{ Name = "Rising Star", Color = Color3.fromRGB(120, 220, 255) },
		{ Name = "Influencer", Color = Color3.fromRGB(120, 255, 150) },
		{ Name = "Celebrity", Color = Color3.fromRGB(255, 210, 90) },
		{ Name = "Icon", Color = Color3.fromRGB(255, 120, 200) },
		{ Name = "Legend", Color = Color3.fromRGB(190, 130, 255) },
		{ Name = "Mythic", Color = Color3.fromRGB(255, 90, 90) },
	},
}

function Game.titleFor(rebrands: number): { Name: string, Color: Color3 }
	local titles = Game.Titles
	return titles[math.min(rebrands + 1, #titles)]
end

return Game
