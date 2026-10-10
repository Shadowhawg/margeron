-- Runtime tests for pure shared modules:  lune run tests/shared
local T = require("./harness")

local Format = T.require("src/shared/Format")
local Economy = T.require("src/shared/Economy")
local Trends = T.require("src/shared/Trends")
local Gear = T.require("src/shared/Config/Gear")
local Niches = T.require("src/shared/Config/Niches")
local Game = T.require("src/shared/Config/Game")
local Rewards = T.require("src/shared/Config/Rewards")

-- Format ---------------------------------------------------------------------------------
T.eq("short 0", Format.short(0), "0")
T.eq("short 999", Format.short(999), "999")
T.eq("short 1000", Format.short(1000), "1K")
T.eq("short 1500", Format.short(1500), "1.5K")
T.eq("short 150000", Format.short(150000), "150K")
T.eq("short 100000", Format.short(100000), "100K")
T.eq("short 1234567", Format.short(1234567), "1.23M")
T.eq("short 1e9", Format.short(1e9), "1B")
T.eq("short 2.5e12", Format.short(2.5e12), "2.5T")
T.eq("short 19.99K floors", Format.short(19999), "19.9K")
T.eq("short nan", Format.short(0 / 0), "0")
T.eq("commas 100", Format.commas(100), "100")
T.eq("commas 1000", Format.commas(1000), "1,000")
T.eq("commas 1234567", Format.commas(1234567), "1,234,567")
T.eq("commas big", Format.commas(30e9), "30,000,000,000")
T.eq("clock 65", Format.clock(65), "1:05")
T.eq("clock 3725", Format.clock(3725), "1:02:05")
T.eq("clock negative", Format.clock(-5), "0:00")
T.eq("mult 2", Format.multiplier(2), "×2")
T.eq("mult 1.5", Format.multiplier(1.5), "×1.5")
T.eq("mult 1.25", Format.multiplier(1.25), "×1.25")

-- Economy --------------------------------------------------------------------------------
local starter = { Camera = 1, Lighting = 1, Set = 1 }
local function post(overrides)
	local input = {
		gear = starter,
		niche = "Vlogs",
		grade = "Good",
		trendMultiplier = 1,
		viral = false,
		collabers = 0,
		boosted = false,
		followers = 0,
		rebrands = 0,
		cashMultiplier = 1,
		followerMultiplier = 1,
	}
	for k, v in overrides do
		input[k] = v
	end
	return Economy.computePost(input)
end

local first = post({ grade = "Perfect", followerMultiplier = Game.NewCreatorFollowerBonus })
T.eq("first post views", first.views, 16)
T.eq("first post followers (+3 promised in GDD)", first.followers, 3)
T.eq("first post cash", first.cash, 3)
T.eq("miss still earns at least 1 follower", post({ grade = "Miss" }).followers, 1)
T.eq("postValue new player", Economy.postValue({ Gear = starter, ActiveNiche = "Vlogs", Followers = 0, Rebrands = 0 }), 2)
T.eq("trend doubles views", post({ trendMultiplier = 2 }).views, 25)
T.eq("viral x5", post({ viral = true }).views, 62)
T.eq("collab capped at 3", post({ collabers = 10 }).views, post({ collabers = 3 }).views)
T.ok("cash multiplier only affects cash", post({ cashMultiplier = 2 }).views == post({}).views)
T.eq("rebrand req 0", Economy.rebrandRequirement(0), 1_000_000)
T.eq("rebrand req 2", Economy.rebrandRequirement(2), 16_000_000)
T.eq("rebrand mult 3", Economy.rebrandMultiplier(3), 2.5)

local monday = 1791763200 -- 2026-10-12 00:00 UTC (a Monday)
T.eq("week rolls over on Monday 00:00 UTC", Economy.weekNumber(monday), Economy.weekNumber(monday - 1) + 1)
T.eq("week ends next Monday", Economy.weekEndsAt(monday + 3600), monday + 604800)
T.eq("day number", Economy.dayNumber(monday + 86399), Economy.dayNumber(monday))

-- Config sanity --------------------------------------------------------------------------
T.eq("gear multiplier at tier 1", Gear.multiplier(starter), 1)
T.eq("gear multiplier maxed", Gear.multiplier({ Camera = 10, Lighting = 8, Set = 8 }), 65 * 7 * 9)
for _, id in Gear.Order do
	local tiers = Gear.Tracks[id].Tiers
	T.eq(`{id} tier 1 free`, tiers[1].Cost, 0)
	for i = 2, #tiers do
		T.ok(`{id} tier {i} costs more`, tiers[i].Cost > tiers[i - 1].Cost)
		T.ok(`{id} tier {i} multiplies more`, tiers[i].Mult > tiers[i - 1].Mult)
	end
end
for i = 2, #Niches.List do
	T.ok(`niche {i} harder than {i - 1}`, Niches.List[i].Followers > Niches.List[i - 1].Followers)
end
T.eq("daily cycle length", #Rewards.DailyPosts, 7)

-- Trends ---------------------------------------------------------------------------------
for slot = 0, 200, 2 do
	local id = Trends.forSlot(slot)
	T.ok(`even slot {slot} uses starter niches`, (Niches.indexOf(id) or 99) <= 3)
end
T.eq("trend deterministic", Trends.forSlot(12345), Trends.forSlot(12345))
local trendId, endsAt = Trends.current(monday + 30)
T.ok("trend is a real niche", Niches.get(trendId) ~= nil)
T.eq("trend ends on period boundary", endsAt, monday + Game.TrendPeriod)

T.finish()
