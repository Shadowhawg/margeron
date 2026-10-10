--!strict
-- Daily streak rewards and Brand Deal templates. Amounts are expressed in "posts"
-- (multiples of the player's current PostValue) so rewards stay meaningful at every stage.
-- The exact cash amount is always computed and shown before the player claims.

export type DealTemplate = { Stat: string, Text: string, Goals: { number }, RewardPosts: number }

local Rewards = {}

-- Index = streak day (1..7).
Rewards.DailyPosts = { 40, 60, 80, 120, 160, 200, 250 }
Rewards.DailyBoostDay = 7 -- day 7 also grants one Views Boost duration

Rewards.DealsPerDay = 3

Rewards.DealTemplates = {
	{ Stat = "Posts", Text = "Post %d videos", Goals = { 25, 40, 60 }, RewardPosts = 60 },
	{ Stat = "Perfect", Text = "Land %d PERFECT takes", Goals = { 8, 12, 20 }, RewardPosts = 80 },
	{ Stat = "Trend", Text = "Post %d trending videos", Goals = { 8, 12, 15 }, RewardPosts = 80 },
	{ Stat = "Collab", Text = "Collab with a friend %d times", Goals = { 3, 5, 8 }, RewardPosts = 100 },
	{ Stat = "Viral", Text = "Film %d Viral Moments", Goals = { 1, 2, 3 }, RewardPosts = 100 },
} :: { DealTemplate }

-- Fictional sponsors only (no real brands; see GDD assumption A4).
Rewards.Sponsors = { "Zingo Soda", "PixelPop Snacks", "Bolt Sneakers", "Nimbus Headphones", "Glimmer Gum", "Rocket Rides" }

return Rewards
