--!strict
-- Friends-in-server bonus, group bonus and proximity collabs.
--
-- Collab rule: when you post, every *other* player within CollabRadius who also posted in
-- the last CollabWindow seconds counts as a collaborator (max CollabMax). Two friends
-- filming side by side therefore both get the bonus on every post.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Config.Game)

local SocialService = {}

local friendsWith: { [Player]: { [Player]: boolean } } = {}
local inGroup: { [Player]: boolean } = {}
local lastPost: { [Player]: { at: number, position: Vector3 } } = {}

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function checkFriendship(a: Player, b: Player)
	local ok, isFriend = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	if ok and isFriend then
		friendsWith[a] = friendsWith[a] or {}
		friendsWith[b] = friendsWith[b] or {}
		friendsWith[a][b] = true
		friendsWith[b][a] = true
	end
end

local function onPlayerAdded(player: Player)
	friendsWith[player] = friendsWith[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(checkFriendship, player, other)
		end
	end
	if Game.GroupId ~= 0 then
		local ok, member = pcall(function()
			return player:IsInGroupAsync(Game.GroupId)
		end)
		inGroup[player] = ok and member == true
	end
end

local function onPlayerRemoving(player: Player)
	local friends = friendsWith[player]
	if friends then
		for other in friends do
			local theirs = friendsWith[other]
			if theirs then
				theirs[player] = nil
			end
		end
	end
	friendsWith[player] = nil
	inGroup[player] = nil
	lastPost[player] = nil
end

function SocialService.friendCount(player: Player): number
	local count = 0
	local friends = friendsWith[player]
	if friends then
		for _ in friends do
			count += 1
		end
	end
	return math.min(count, Game.FriendMax)
end

function SocialService.isInGroup(player: Player): boolean
	return inGroup[player] == true
end

-- Combined social cash multiplier (friends + group).
function SocialService.cashMultiplier(player: Player): number
	return 1
		+ Game.FriendBonusEach * SocialService.friendCount(player)
		+ (if SocialService.isInGroup(player) then Game.GroupBonus else 0)
end

-- Counts collaborators for a post happening now, then records this post.
function SocialService.registerPost(player: Player): number
	local now = os.clock()
	local position = rootPosition(player)
	local collabers = 0
	if position then
		for other, info in lastPost do
			if
				other ~= player
				and other.Parent == Players
				and now - info.at <= Game.CollabWindow
				and (info.position - position).Magnitude <= Game.CollabRadius
			then
				collabers += 1
			end
		end
		lastPost[player] = { at = now, position = position }
	end
	return math.min(collabers, Game.CollabMax)
end

function SocialService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return SocialService
