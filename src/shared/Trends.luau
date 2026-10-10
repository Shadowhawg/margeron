--!strict
-- Deterministic trend schedule. Every server and client derives the same trend from the
-- shared clock (os.time on server, workspace:GetServerTimeNow on client), so no
-- MessagingService traffic is needed. Even slots draw from the first three niches so new
-- players can always ride the trend; odd slots draw from every niche to pull players
-- toward unlocks.

local Game = require(script.Parent.Config.Game)
local Niches = require(script.Parent.Config.Niches)

local Trends = {}

local STARTER_POOL = 3

function Trends.slot(now: number): number
	return now // Game.TrendPeriod
end

function Trends.forSlot(slot: number): string
	local rng = Random.new(slot * 7919 + 104729)
	local poolSize = if slot % 2 == 0 then math.min(STARTER_POOL, #Niches.List) else #Niches.List
	return Niches.List[rng:NextInteger(1, poolSize)].Id
end

function Trends.current(now: number): (string, number)
	local slot = Trends.slot(now)
	return Trends.forSlot(slot), (slot + 1) * Game.TrendPeriod
end

return Trends
