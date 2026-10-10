--!strict
-- The core loop: StartTake -> (timing tap) -> SubmitTake -> post -> views/followers/cash.
--
-- Anti-exploit model:
--   * The server owns the take: it picks the green zone, stamps the start time and
--     decides the grade. The client only reports *where* on the bar it tapped.
--   * A tap can't be reported further along the bar than the server clock allows
--     (elapsed >= tap * duration - tolerance), so a client can't "wait" for free.
--   * The next take can't start until the full sweep + PostCooldown has passed, whatever
--     the client sends. That caps throughput at ~1 post / 1.55s for exploiters and
--     autoclickers alike, and bounds the best possible cheat to "always Perfect" (x1.6).
--   * All multipliers (trend, viral position, collab, boosts, passes) are server-derived.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Trends = require(Shared.Trends)
local Types = require(Shared.Types)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local RewardService = require(script.Parent.RewardService)
local SocialService = require(script.Parent.SocialService)
local ViralService = require(script.Parent.ViralService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Remotes = require(script.Parent.Parent.Util.Remotes)

type Take = {
	id: number,
	startedAt: number,
	duration: number,
	zoneStart: number,
	zoneEnd: number,
	forcePerfect: boolean,
}

local ContentService = {}

local takes: { [Player]: Take } = {}
local sweepEndsAt: { [Player]: number } = {}
local lastManualAt: { [Player]: number } = {}
local nextAutoAt: { [Player]: number } = {}
local nextTakeId = 0
local rng = Random.new()

function ContentService.trendMultiplierFor(player: Player): number
	return if Analytics.bucket(player, "TrendMultiplier") == 1 then 3 else Game.TrendMultiplier
end

local function tutorialTakes(player: Player): number
	return Game.TutorialTakes * (if Analytics.bucket(player, "FirstTakeZone") == 1 then 2 else 1)
end

local function gradeFor(take: Take, tap: number?): Types.TakeGrade
	if take.forcePerfect then
		return "Perfect"
	end
	if tap == nil or tap < take.zoneStart or tap > take.zoneEnd then
		return "Miss"
	end
	local centre = (take.zoneStart + take.zoneEnd) / 2
	local coreHalfWidth = (take.zoneEnd - take.zoneStart) / 2 * Game.PerfectCoreFraction
	return if math.abs(tap - centre) <= coreHalfWidth then "Perfect" else "Good"
end

local function announceMilestone(player: Player, before: number, after: number)
	for _, milestone in Game.Milestones do
		if before < milestone and after >= milestone then
			local payload: Types.NotifyPayload = {
				Kind = "Milestone",
				Text = `🎉 {player.DisplayName} just hit {Format.short(milestone)} followers!`,
			}
			Remotes.event("Notify"):FireAllClients(payload)
		end
	end
end

-- Applies one post to the player's data. Used by manual takes and Auto-Film.
function ContentService.post(player: Player, data: Types.PlayerData, grade: Types.TakeGrade, auto: boolean): Types.PostResult
	local now = os.time()
	local trendNiche = Trends.current(now)
	local trending = data.ActiveNiche == trendNiche
	local viral = ViralService.isInside(player)
	local collabers = SocialService.registerPost(player)
	local boosted = data.BoostEndsAt > now

	local out = Economy.computePost({
		gear = data.Gear,
		niche = data.ActiveNiche,
		grade = grade,
		trendMultiplier = if trending then ContentService.trendMultiplierFor(player) else 1,
		viral = viral,
		collabers = collabers,
		boosted = boosted,
		followers = data.Followers,
		rebrands = data.Rebrands,
		cashMultiplier = MonetizationService.cashMultiplier(player) * SocialService.cashMultiplier(player),
		followerMultiplier = MonetizationService.followerMultiplier(player)
			* (if data.LifetimeFollowers < Game.NewCreatorThreshold then Game.NewCreatorFollowerBonus else 1),
	})

	local followersBefore = data.Followers
	data.Cash += out.cash
	data.Followers += out.followers
	data.LifetimeFollowers += out.followers
	data.TotalViews += out.views
	data.TotalPosts += 1
	local week = Economy.weekNumber(now)
	if data.Week.Id ~= week then
		data.Week = { Id = week, Followers = 0 }
	end
	data.Week.Followers += out.followers

	RewardService.recordDeal(player, data, "Posts", 1)
	if grade == "Perfect" then
		data.PerfectTakes += 1
		RewardService.recordDeal(player, data, "Perfect", 1)
	end
	if trending then
		RewardService.recordDeal(player, data, "Trend", 1)
		Analytics.step(player, data, "FirstTrend")
	end
	if collabers > 0 then
		RewardService.recordDeal(player, data, "Collab", 1)
	end
	if viral then
		RewardService.recordDeal(player, data, "Viral", 1)
		Analytics.step(player, data, "FirstViral")
	end

	Analytics.postIncome(player, out.cash, data.Cash)
	if data.TotalPosts >= 1 then
		Analytics.step(player, data, "FirstPost")
	end
	if data.TotalPosts >= 5 then
		Analytics.step(player, data, "FifthPost")
	end
	if data.LifetimeFollowers >= 1000 then
		Analytics.step(player, data, "Followers1K")
	end
	announceMilestone(player, followersBefore, data.Followers)
	DataService.markDirty(player)

	return {
		ok = true,
		grade = grade,
		views = out.views,
		followers = out.followers,
		cash = out.cash,
		trending = trending,
		viral = viral,
		collabers = collabers,
		boosted = boosted,
		auto = auto,
	}
end

local function startTake(player: Player): Types.TakeTicket
	local data = DataService.get(player)
	if not data then
		return { ok = false, err = "Loading..." }
	end
	local now = os.clock()
	local current = takes[player]
	if current and now - current.startedAt <= current.duration + Game.TakeExpiry then
		return { ok = false, err = "Already filming" }
	end
	if now < (sweepEndsAt[player] or 0) + Game.PostCooldown then
		return { ok = false, err = "Cooldown" }
	end

	local forcePerfect = data.TotalPosts == 0
	local width = if data.TotalPosts < tutorialTakes(player) then Game.ZoneWidth * 2 else Game.ZoneWidth
	local zoneStart = if forcePerfect then 0 else rng:NextNumber(0.35, 0.95 - width)
	local zoneEnd = if forcePerfect then 1 else zoneStart + width

	nextTakeId += 1
	local take: Take = {
		id = nextTakeId,
		startedAt = now,
		duration = Game.TakeDuration,
		zoneStart = zoneStart,
		zoneEnd = zoneEnd,
		forcePerfect = forcePerfect,
	}
	takes[player] = take
	lastManualAt[player] = now
	Analytics.step(player, data, "FirstTake")
	return {
		ok = true,
		id = take.id,
		duration = take.duration,
		zoneStart = zoneStart,
		zoneEnd = zoneEnd,
		forcePerfect = forcePerfect,
	}
end

local function submitTake(player: Player, rawId: unknown, rawTap: unknown): Types.PostResult
	local data = DataService.get(player)
	local take = takes[player]
	local id = Guard.integer(rawId, 1, math.huge)
	if not data or not take or id ~= take.id then
		return { ok = false, err = "No take in progress" }
	end
	takes[player] = nil
	sweepEndsAt[player] = take.startedAt + take.duration
	lastManualAt[player] = os.clock()

	local elapsed = os.clock() - take.startedAt
	if elapsed > take.duration + Game.TakeExpiry then
		return { ok = false, err = "Take expired" }
	end

	local tap = if rawTap == nil then nil else Guard.fraction(rawTap)
	if tap and elapsed + Game.LatencyTolerance < tap * take.duration then
		tap = nil -- reported a position the marker couldn't have reached yet
	end
	return ContentService.post(player, data, gradeFor(take, tap), false)
end

local function setAutoFilm(player: Player, rawEnabled: unknown): Types.ActionResult
	local data = DataService.get(player)
	local enabled = Guard.bool(rawEnabled)
	if not data or enabled == nil then
		return { ok = false, err = "Invalid" }
	end
	data.AutoFilm = enabled
	DataService.markDirty(player)
	return { ok = true }
end

local function autoFilmTick()
	local now = os.clock()
	local postResult = Remotes.event("PostResult")
	for player, data in DataService.each() do
		if
			data.AutoFilm
			and MonetizationService.owns(player, "AutoFilm")
			and now - (lastManualAt[player] or 0) >= Game.AutoFilmManualPause
			and now >= (nextAutoAt[player] or 0)
		then
			nextAutoAt[player] = now + Game.AutoFilmInterval
			postResult:FireClient(player, ContentService.post(player, data, "Good", true))
		end
	end
end

function ContentService.start()
	-- Capacity allows a short burst (lag spikes); sustained rate is bounded by the sweep anyway.
	Remotes.handle("StartTake", { capacity = 4, perSecond = 2 }, startTake)
	Remotes.handle("SubmitTake", { capacity = 4, perSecond = 2 }, submitTake)
	Remotes.handle("SetAutoFilm", { capacity = 3, perSecond = 1 }, setAutoFilm)

	Players.PlayerRemoving:Connect(function(player)
		takes[player] = nil
		sweepEndsAt[player] = nil
		lastManualAt[player] = nil
		nextAutoAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			autoFilmTick()
		end
	end)
end

return ContentService
