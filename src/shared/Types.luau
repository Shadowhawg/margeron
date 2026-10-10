--!strict
-- Shared type definitions. PlayerData is what ProfileStore persists; ClientState is
-- the read-only view the server replicates to the owning client.

export type GearTrack = "Camera" | "Lighting" | "Set"
export type TakeGrade = "Miss" | "Good" | "Perfect"
export type DealStat = "Posts" | "Perfect" | "Trend" | "Collab" | "Viral"

-- Keyed by GearTrack. A plain string map keeps indexing simple under strict mode.
export type GearLevels = { [string]: number }

export type PlayerData = {
	Version: number,
	Cash: number,
	Followers: number,
	LifetimeFollowers: number,
	TotalViews: number,
	TotalPosts: number,
	PerfectTakes: number,
	Rebrands: number,
	Gear: GearLevels,
	Niches: { string },
	ActiveNiche: string,
	Daily: { LastClaimDay: number, Streak: number },
	Deals: { Day: number, Templates: { number }, Goals: { number }, Progress: { number }, Claimed: { boolean } },
	Week: { Id: number, Followers: number },
	BoostEndsAt: number,
	AutoFilm: boolean,
	LastOnline: number,
	FirstJoin: number,
	Onboarding: { [string]: boolean },
	PurchaseIdCache: { string },
}

export type DealView = {
	Sponsor: string,
	Text: string,
	Goal: number,
	Progress: number,
	Claimed: boolean,
	Reward: number,
}

export type ClientState = {
	Cash: number,
	Followers: number,
	LifetimeFollowers: number,
	Rebrands: number,
	TotalPosts: number,
	Gear: GearLevels,
	Niches: { string },
	ActiveNiche: string,
	BoostEndsAt: number,
	AutoFilm: boolean,
	PostValue: number,
	Daily: { CanClaim: boolean, NextDay: number, NextReward: number, NextResetAt: number },
	Deals: { DealView },
	Passes: { [string]: boolean },
	IsPremium: boolean,
	CashMultiplier: number,
	FollowerMultiplier: number,
	TrendMultiplier: number,
	Experiments: { [string]: number },
}

export type PostResult = {
	ok: boolean,
	err: string?,
	grade: TakeGrade?,
	views: number?,
	followers: number?,
	cash: number?,
	trending: boolean?,
	viral: boolean?,
	collabers: number?,
	boosted: boolean?,
	auto: boolean?,
}

export type TakeTicket = {
	ok: boolean,
	err: string?,
	id: number?,
	duration: number?,
	zoneStart: number?,
	zoneEnd: number?,
	forcePerfect: boolean?,
}

-- Generic RemoteFunction reply for simple actions (buy, claim, select…).
export type ActionResult = { ok: boolean, err: string? }

export type LeaderboardEntry = { Rank: number, UserId: number, Name: string, Value: number }
export type LeaderboardPayload = { AllTime: { LeaderboardEntry }, Weekly: { LeaderboardEntry }, WeekEndsAt: number }

export type ViralPayload = { Active: boolean, Position: Vector3?, EndsAt: number?, Name: string? }

export type NotifyKind = "Toast" | "Offline" | "Milestone" | "Error"
export type NotifyPayload = { Kind: NotifyKind, Text: string, Cash: number?, Followers: number? }

return nil
