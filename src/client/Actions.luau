--!strict
-- Calls a server action and surfaces any error as a toast. Returns true on success.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Toasts = require(script.Parent.UI.Toasts)

local Actions = {}

function Actions.call(name: Net.FunctionName, ...: any): boolean
	local remote = Net.fn(name)
	local args = table.pack(...)
	local ok, result = pcall(function(): Types.ActionResult
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok or type(result) ~= "table" then
		Toasts.error("Connection hiccup, try again")
		return false
	end
	if not result.ok then
		Toasts.error(result.err)
		return false
	end
	return true
end

return Actions
