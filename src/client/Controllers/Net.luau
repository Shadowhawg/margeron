-- Wrapper around the Request RemoteFunction that surfaces server messages as toasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Notifications = require(script.Parent.Notifications)

local Net = {}

function Net.Request(action, ...)
	local ok, result = pcall(Remotes.Request.InvokeServer, Remotes.Request, action, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false }
	end
	if result.message then
		Notifications.Show(result.message, result.ok and "Info" or "Error")
	end
	return result
end

return Net
