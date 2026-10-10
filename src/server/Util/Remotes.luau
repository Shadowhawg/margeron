--!strict
-- Creates every remote listed in Shared/Net and wraps RemoteFunction handlers with:
--   1. a per-player, per-remote token bucket,
--   2. pcall so a handler error never leaks a stack trace or hangs the client,
--   3. abuse tracking that kicks clients that hammer remotes far beyond human speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = {}

local KICK_THRESHOLD = 150 -- rejected calls per minute before we assume an exploit client

local folder = Instance.new("Folder")
folder.Name = Net.FolderName

local functions: { [string]: RemoteFunction } = {}
local events: { [string]: RemoteEvent } = {}

for _, name in Net.Functions do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	functions[name] = remote
end

for _, name in Net.Events do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	events[name] = remote
end

folder.Parent = ReplicatedStorage

local rejections: { [Player]: { count: number, windowStart: number } } = {}

local function currentWindow(player: Player, now: number): { count: number, windowStart: number }
	local entry = rejections[player]
	if entry and now - entry.windowStart <= 60 then
		return entry
	end
	local fresh = { count = 0, windowStart = now }
	rejections[player] = fresh
	return fresh
end

local function recordRejection(player: Player)
	local entry = currentWindow(player, os.clock())
	entry.count += 1
	if entry.count >= KICK_THRESHOLD then
		player:Kick("Too many requests. Please rejoin.")
	end
end

Players.PlayerRemoving:Connect(function(player)
	rejections[player] = nil
end)

export type RateConfig = { capacity: number, perSecond: number }

-- Handlers receive raw, untrusted arguments and must validate them (see Util/Guard).
function Remotes.handle(name: Net.FunctionName, rate: RateConfig, handler: (Player, ...unknown) -> any)
	local remote = functions[name]
	assert(remote, `Unknown remote function {name}`)
	assert(remote.OnServerInvoke == nil, `{name} already has a handler`)
	local limiter = RateLimiter.new(rate.capacity, rate.perSecond)

	remote.OnServerInvoke = function(player: Player, ...: unknown): any
		if not limiter.take(player) then
			recordRejection(player)
			return { ok = false, err = "Slow down!" }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[Remotes] {name} failed for {player.UserId}: {result}`)
			return { ok = false, err = "Something went wrong" }
		end
		return result
	end
end

function Remotes.event(name: Net.EventName): RemoteEvent
	local remote = events[name]
	assert(remote, `Unknown remote event {name}`)
	return remote
end

return Remotes
