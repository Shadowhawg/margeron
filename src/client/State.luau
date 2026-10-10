-- Latest copy of the player's data from the server, plus derived stats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)

local State = {
	Data = nil,
	Stats = nil,
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

Remotes.State.OnClientEvent:Connect(function(data)
	State.Data = data
	State.Stats = Stats.Compute(data)
	changed:Fire(data)
end)

-- Runs callback now if data has arrived, and again on every change.
function State.Observe(callback)
	if State.Data then
		task.spawn(callback, State.Data)
	end
	return State.Changed:Connect(callback)
end

return State
