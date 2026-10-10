--!strict
-- Single source of truth for remote names. The server creates the instances
-- (server/Util/Remotes.luau); clients fetch them through Net.fn / Net.event.
--
-- Client -> server traffic uses RemoteFunctions only, so every request gets a reply and
-- passes through one rate-limited, validated entry point. Server -> client pushes use
-- RemoteEvents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type FunctionName =
	"StartTake"
	| "SubmitTake"
	| "BuyGear"
	| "UnlockNiche"
	| "SelectNiche"
	| "ClaimDaily"
	| "ClaimDeal"
	| "Rebrand"
	| "SetAutoFilm"

export type EventName = "State" | "PostResult" | "Notify" | "Leaderboard" | "Viral"

local Net = {}

Net.FolderName = "Remotes"

Net.Functions = {
	"StartTake",
	"SubmitTake",
	"BuyGear",
	"UnlockNiche",
	"SelectNiche",
	"ClaimDaily",
	"ClaimDeal",
	"Rebrand",
	"SetAutoFilm",
} :: { FunctionName }

Net.Events = { "State", "PostResult", "Notify", "Leaderboard", "Viral" } :: { EventName }

local function folder(): Folder
	return ReplicatedStorage:WaitForChild(Net.FolderName) :: Folder
end

function Net.fn(name: FunctionName): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

function Net.event(name: EventName): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

-- Yields until the server has created every remote (call once at client start-up).
function Net.waitForAll()
	local remotes = folder()
	for _, name: string in Net.Functions do
		remotes:WaitForChild(name)
	end
	for _, name: string in Net.Events do
		remotes:WaitForChild(name)
	end
end

return Net
