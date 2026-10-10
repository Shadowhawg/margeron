-- All client/server networking goes through these. The server creates them; clients wait for them.
--
-- RemoteEvents
--   State       S->C  full player data snapshot whenever it changes
--   Notify      S->C  toast message { Text, Kind }
--   Dialogue    S->C  open an NPC conversation
--   Effect      S->C  visual effect for clients to render
--   Attack      C->S  basic attack (aim direction)
--   Cutscene    S->C  play a cutscene from Config/Story
--   Open        S->C  open a window (crafting station, seed picker, government...)
-- RemoteFunctions
--   Request     C->S  every UI action: Request:InvokeServer(action, ...) -> result table
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "State", "Notify", "Dialogue", "Effect", "Attack", "Cutscene", "Open" }
local FUNCTIONS = { "Request" }

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(EVENTS) do
		local remote = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	for _, name in ipairs(FUNCTIONS) do
		local remote = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in ipairs(EVENTS) do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in ipairs(FUNCTIONS) do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
