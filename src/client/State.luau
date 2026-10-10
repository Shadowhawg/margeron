--!strict
-- Client-side mirror of server state. Read-only: the client never decides values, it only
-- renders what the server sent and asks the server to act through remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local State = {}

State.current = nil :: Types.ClientState?
State.leaderboard = nil :: Types.LeaderboardPayload?
State.viral = { Active = false } :: Types.ViralPayload

State.Changed = Signal.new() :: Signal.Signal<Types.ClientState>
State.LeaderboardChanged = Signal.new() :: Signal.Signal<Types.LeaderboardPayload>
State.ViralChanged = Signal.new() :: Signal.Signal<Types.ViralPayload>
State.Posted = Signal.new() :: Signal.Signal<Types.PostResult>
State.Notified = Signal.new() :: Signal.Signal<Types.NotifyPayload>

function State.serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Yields until the first state snapshot arrives.
function State.await(): Types.ClientState
	while State.current == nil do
		task.wait()
	end
	return State.current :: Types.ClientState
end

function State.start()
	Net.event("State").OnClientEvent:Connect(function(snapshot: Types.ClientState)
		State.current = snapshot
		State.Changed:Fire(snapshot)
	end)
	Net.event("Leaderboard").OnClientEvent:Connect(function(payload: Types.LeaderboardPayload)
		State.leaderboard = payload
		State.LeaderboardChanged:Fire(payload)
	end)
	Net.event("Viral").OnClientEvent:Connect(function(payload: Types.ViralPayload)
		State.viral = payload
		State.ViralChanged:Fire(payload)
	end)
	Net.event("PostResult").OnClientEvent:Connect(function(result: Types.PostResult)
		State.Posted:Fire(result)
	end)
	Net.event("Notify").OnClientEvent:Connect(function(payload: Types.NotifyPayload)
		State.Notified:Fire(payload)
	end)
end

-- Fires `handler` now (if state exists) and on every change.
function State.observe(handler: (Types.ClientState) -> ())
	if State.current then
		task.spawn(handler, State.current)
	end
	State.Changed:Connect(handler)
end

return State
