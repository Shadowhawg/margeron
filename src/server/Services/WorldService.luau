--!strict
-- World setup and public show-off surfaces.
--
-- * If the place has no Workspace.Map, builds a placeholder hub (floor, spawn, Viral
--   Moment spawn points and a leaderboard board) so the MVP runs in an empty baseplate.
--   Replace it with a real map: tag BaseParts "ViralSpawn" and one part "LeaderboardBoard".
-- * Overhead billboard on every character: name, follower count, Rebrand title.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Types = require(Shared.Types)

local BOARD_TAG = "LeaderboardBoard"
local VIRAL_TAG = "ViralSpawn"
local BOARD_ROWS = 10

local WorldService = {}

local function part(props: { Name: string, Size: Vector3, CFrame: CFrame, Color: Color3, Parent: Instance }): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent
	return p
end

local function buildBoard(parent: Instance, position: Vector3, lookAt: Vector3)
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	local board = part({
		Name = "Board",
		Size = Vector3.new(28, 16, 1),
		CFrame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)),
		Color = Color3.fromRGB(25, 20, 45),
		Parent = model,
	})
	CollectionService:AddTag(board, BOARD_TAG)
end

local function buildPlaceholderMap()
	local map = Instance.new("Folder")
	map.Name = "Map"

	if not workspace:FindFirstChild("Baseplate") then
		local floor = part({
			Name = "Floor",
			Size = Vector3.new(512, 2, 512),
			CFrame = CFrame.new(0, -1, 0),
			Color = Color3.fromRGB(110, 200, 120),
			Parent = map,
		})
		floor.Material = Enum.Material.Grass
	end

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = CFrame.new(0, 0.5, 0)
		spawn.Duration = 0
		spawn.Parent = map
	end

	-- Viral Moment spots: coloured pads in a ring so players can see where moments land.
	local colors = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 210, 90) }
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local radius = if i % 2 == 0 then 70 else 130
		local pad = part({
			Name = `ViralSpot{i}`,
			Size = Vector3.new(20, 0.4, 20),
			CFrame = CFrame.new(math.cos(angle) * radius, 0.2, math.sin(angle) * radius),
			Color = colors[(i % #colors) + 1],
			Parent = map,
		})
		pad.Material = Enum.Material.SmoothPlastic
		pad.CanCollide = false
		CollectionService:AddTag(pad, VIRAL_TAG)
	end

	buildBoard(map, Vector3.new(0, 9, -36), Vector3.new(0, 9, 0))
	map.Parent = workspace
end

local function makeRow(parent: Instance, order: number, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = `Row{order}`
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 1 / (BOARD_ROWS + 1), 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

local function renderColumn(parent: Instance, title: string, entries: { Types.LeaderboardEntry })
	for _, child in parent:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	makeRow(parent, 0, title, Color3.fromRGB(255, 210, 90))
	for i = 1, BOARD_ROWS do
		local entry = entries[i]
		local text = if entry then `{entry.Rank}. {entry.Name}  {Format.short(entry.Value)}` else `{i}. —`
		makeRow(parent, i, text, Color3.new(1, 1, 1))
	end
end

local function boardGui(board: BasePart): SurfaceGui
	local existing = board:FindFirstChild("BoardGui")
	if existing and existing:IsA("SurfaceGui") then
		return existing
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	for index, name in { "Weekly", "AllTime" } do
		local column = Instance.new("Frame")
		column.Name = name
		column.BackgroundTransparency = 1
		column.Size = UDim2.fromScale(0.46, 0.9)
		column.Position = UDim2.fromScale(if index == 1 then 0.03 else 0.53, 0.05)
		column.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = column
	end
	return gui
end

function WorldService.updateBoards(payload: Types.LeaderboardPayload)
	for _, board in CollectionService:GetTagged(BOARD_TAG) do
		if not board:IsA("BasePart") then
			continue
		end
		local gui = boardGui(board)
		local weekly = gui:FindFirstChild("Weekly")
		local allTime = gui:FindFirstChild("AllTime")
		if weekly and allTime then
			renderColumn(weekly, "🔥 THIS WEEK", payload.Weekly)
			renderColumn(allTime, "🏆 ALL TIME", payload.AllTime)
		end
	end
end

local function attachOverhead(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Overhead"
	billboard.Size = UDim2.fromOffset(200, 64)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0

	local function label(name: string, y: number, height: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, height)
		l.Position = UDim2.fromScale(0, y)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.2
		l.Parent = billboard
		return l
	end
	local title = label("Title", 0, 0.3)
	local followers = label("Followers", 0.3, 0.45)
	local name = label("DisplayName", 0.75, 0.25)
	name.Text = player.DisplayName

	local function refresh()
		local rebrands = (player:GetAttribute("Rebrands") :: number?) or 0
		local count = (player:GetAttribute("Followers") :: number?) or 0
		local t = Game.titleFor(rebrands)
		local vip = player:GetAttribute("VIP") == true
		title.Text = if vip then `👑 {t.Name}` else t.Name
		title.TextColor3 = t.Color
		followers.Text = `👥 {Format.short(count)}`
		name.TextColor3 = if vip then Color3.fromRGB(255, 215, 80) else Color3.new(1, 1, 1)
	end
	refresh()
	player:GetAttributeChangedSignal("Followers"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebrands"):Connect(refresh)
	player:GetAttributeChangedSignal("VIP"):Connect(refresh)
	billboard.Parent = head
end

function WorldService.init()
	if not workspace:FindFirstChild("Map") then
		buildPlaceholderMap()
	end
end

function WorldService.start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			attachOverhead(player, character)
		end)
		if player.Character then
			task.spawn(attachOverhead, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return WorldService
