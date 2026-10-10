--!strict
-- Per-player token buckets. Each remote gets its own bucket so spamming one action
-- can't starve another. Buckets are cleared when the player leaves.

local Players = game:GetService("Players")

export type Limiter = {
	take: (player: Player) -> boolean,
}

local RateLimiter = {}

local allBuckets: { { [Player]: { tokens: number, updated: number } } } = {}

function RateLimiter.new(capacity: number, refillPerSecond: number): Limiter
	local buckets: { [Player]: { tokens: number, updated: number } } = {}
	table.insert(allBuckets, buckets)

	local function take(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = capacity, updated = now }
			buckets[player] = bucket
		end
		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.updated) * refillPerSecond)
		bucket.updated = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	return { take = take }
end

Players.PlayerRemoving:Connect(function(player)
	for _, buckets in allBuckets do
		buckets[player] = nil
	end
end)

return RateLimiter
