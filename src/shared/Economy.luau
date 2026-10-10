--!strict
-- Pure economy formulas shared by server (authoritative) and client (previews only).
-- See docs/GDD.md §2.2 for the design rationale and tools/sim_economy.py for pacing.

local Config = script.Parent.Config
local Game = require(Config.Game)
local Gear = require(Config.Gear)
local Niches = require(Config.Niches)
local Types = require(script.Parent.Types)

local Economy = {}

Economy.BaseViews = 10
Economy.FollowRate = 0.08
Economy.CashRate = 0.2
Economy.TakeMultipliers = { Miss = 1, Good = 1.25, Perfect = 1.6 } :: { [string]: number }

export type PostInput = {
	gear: Types.GearLevels,
	niche: string,
	grade: Types.TakeGrade,
	trendMultiplier: number, -- 1 when the post isn't on-trend
	viral: boolean,
	collabers: number,
	boosted: boolean,
	followers: number,
	rebrands: number,
	cashMultiplier: number,
	followerMultiplier: number,
}

export type PostOutput = { views: number, followers: number, cash: number }

function Economy.reachMultiplier(followers: number): number
	return 1 + 0.35 * math.log10(1 + math.max(followers, 0))
end

function Economy.rebrandMultiplier(rebrands: number): number
	return 1 + Game.RebrandBonus * rebrands
end

function Economy.rebrandRequirement(rebrands: number): number
	return Game.RebrandBase * Game.RebrandGrowth ^ rebrands
end

function Economy.computePost(input: PostInput): PostOutput
	local niche = Niches.get(input.niche)
	local views = Economy.BaseViews
		* Gear.multiplier(input.gear)
		* (if niche then niche.Mult else 1)
		* (Economy.TakeMultipliers[input.grade] or 1)
		* input.trendMultiplier
		* (if input.viral then Game.ViralMultiplier else 1)
		* (1 + Game.CollabBonusEach * math.clamp(input.collabers, 0, Game.CollabMax))
		* (if input.boosted then 2 else 1)
		* Economy.reachMultiplier(input.followers)
		* Economy.rebrandMultiplier(input.rebrands)
	views = math.floor(views)
	return {
		views = views,
		followers = math.max(1, math.floor(views * Economy.FollowRate * input.followerMultiplier)),
		cash = math.max(1, math.floor(views * Economy.CashRate * input.cashMultiplier)),
	}
end

-- Cash from one ordinary Good take with no temporary or purchased bonuses. Used as the
-- unit for daily rewards, Brand Deals, cash packs and offline earnings, so a reward of
-- "200 posts" is always worth the same effort whatever the player's progress.
function Economy.postValue(data: { Gear: Types.GearLevels, ActiveNiche: string, Followers: number, Rebrands: number }): number
	return Economy.computePost({
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
	}).cash
end

-- Days and weeks are UTC so every server agrees without coordination.
function Economy.dayNumber(now: number): number
	return now // 86400
end

local MONDAY_OFFSET = 4 * 86400 -- 1970-01-05 was a Monday
function Economy.weekNumber(now: number): number
	return (now - MONDAY_OFFSET) // 604800
end

function Economy.weekEndsAt(now: number): number
	return (Economy.weekNumber(now) + 1) * 604800 + MONDAY_OFFSET
end

return Economy
