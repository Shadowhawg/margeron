-- Cinematic presentation: letterbox bars, scripted camera moves, fades, title cards and
-- typewriter narration. Used by story cutscenes and NPC conversations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Story = require(Shared.Config.Story)
local Races = require(Shared.Config.Races)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local New = Create.New

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Cinematic = {}
Cinematic.Playing = false -- a story cutscene is running
Cinematic.Active = false -- letterbox mode is on (cutscene or conversation)

local gui, topBar, bottomBar, fade, titleCard, speakerLabel, lineLabel, skipButton, hint
local advanceSignal = Instance.new("BindableEvent")
local skipRequested = false
local lineId = 0 -- each ShowLine call gets an id; starting a new line ends the old one
local HIDDEN_GUIS = { "HUD", "Windows" }

local function setControls(enabled)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		local controls = module:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function setOtherGuis(visible)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	for _, name in ipairs(HIDDEN_GUIS) do
		local other = playerGui:FindFirstChild(name)
		if other then
			other.Enabled = visible
		end
	end
end

function Cinematic.Enter(options)
	options = options or {}
	Cinematic.Active = true
	setOtherGuis(false)
	setControls(false)
	gui.Enabled = true
	skipButton.Visible = options.Skippable == true
	TweenService:Create(topBar, TweenInfo.new(0.5), { Size = UDim2.fromScale(1, 0.11) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.5), { Size = UDim2.fromScale(1, options.TallBottom and 0.3 or 0.2) })
		:Play()
	if options.Camera ~= false then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end

function Cinematic.Exit()
	Cinematic.Active = false
	lineId += 1
	speakerLabel.Text = ""
	lineLabel.Text = ""
	hint.Visible = false
	TweenService:Create(topBar, TweenInfo.new(0.4), { Size = UDim2.fromScale(1, 0) }):Play()
	local t = TweenService:Create(bottomBar, TweenInfo.new(0.4), { Size = UDim2.fromScale(1, 0) })
	t:Play()
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	setControls(true)
	setOtherGuis(true)
	task.delay(0.45, function()
		if not Cinematic.Active then
			gui.Enabled = false
		end
	end)
end

function Cinematic.Fade(toBlack, duration)
	local t = TweenService:Create(fade, TweenInfo.new(duration or 0.6), { BackgroundTransparency = toBlack and 0 or 1 })
	t:Play()
	t.Completed:Wait()
end

function Cinematic.MoveCamera(from, to, duration)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = from
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = to }
	)
	tween:Play()
	return tween
end

-- Shows a line with a typewriter effect. Waits for the reader (click/space/tap) or auto-advances.
function Cinematic.ShowLine(speaker, text, autoAdvance)
	lineId += 1
	local myId = lineId
	speakerLabel.Text = speaker or ""
	lineLabel.Text = text
	lineLabel.MaxVisibleGraphemes = 0
	hint.Visible = false
	local function cancelled()
		return skipRequested or lineId ~= myId
	end

	-- Typewriter; the first click/keypress reveals the whole line.
	local length = utf8.len(text) or #text
	local shown = 0
	local revealAll = false
	local conn = advanceSignal.Event:Connect(function()
		revealAll = true
	end)
	while shown < length and not revealAll and not cancelled() do
		shown += 1
		lineLabel.MaxVisibleGraphemes = shown
		task.wait(1 / 45)
	end
	conn:Disconnect()
	if cancelled() then
		return
	end
	lineLabel.MaxVisibleGraphemes = -1

	-- Wait for the reader (or auto-advance after a reading pause).
	hint.Visible = true
	local readTime = autoAdvance and (1.6 + #text * 0.035) or math.huge
	local started = os.clock()
	local advanced = false
	conn = advanceSignal.Event:Connect(function()
		advanced = true
	end)
	while not advanced and not cancelled() and os.clock() - started < readTime do
		task.wait(0.05)
	end
	conn:Disconnect()
	if lineId == myId then
		hint.Visible = false
	end
end

function Cinematic.ClearLine()
	lineId += 1
	speakerLabel.Text = ""
	lineLabel.Text = ""
end

-- Cutscene playback ------------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false

local function groundY(x, z)
	local include = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(include, map)
	end
	groundParams.FilterDescendantsInstances = include
	local result = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), groundParams)
	return result and result.Position.Y or 0
end

local function anchorCFrame(anchor)
	if anchor == "Player" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return root and root.CFrame or CFrame.new()
	end
	local folder = workspace:FindFirstChild("NPCs")
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("NPCId") == anchor and model.PrimaryPart then
				return model.PrimaryPart.CFrame
			end
		end
	end
	return CFrame.new()
end

local function resolvePoint(point)
	if typeof(point) == "Vector3" then
		return Vector3.new(point.X, groundY(point.X, point.Z) + point.Y, point.Z)
	end
	return (anchorCFrame(point.Anchor) * CFrame.new(point.Offset)).Position
end

local function keyframe(k)
	return CFrame.lookAt(resolvePoint(k.Pos), resolvePoint(k.Look))
end

local function personalize(text)
	local data = State.Data
	local raceName = data and Races.Races[data.Appearance.Race] and Races.Races[data.Appearance.Race].Name or "traveler"
	text = text:gsub("{name}", player.DisplayName)
	text = text:gsub("{race}", raceName)
	return text
end

local function titleCardShow(title, subtitle)
	titleCard.Title.Text = title or ""
	titleCard.Subtitle.Text = subtitle or ""
	titleCard.Visible = true
	titleCard.Title.TextTransparency = 1
	titleCard.Subtitle.TextTransparency = 1
	TweenService:Create(titleCard.Title, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
	TweenService:Create(titleCard.Subtitle, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
	local started = os.clock()
	while os.clock() - started < 3.2 and not skipRequested do
		task.wait(0.05)
	end
	TweenService:Create(titleCard.Title, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	TweenService:Create(titleCard.Subtitle, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	task.wait(0.8)
	titleCard.Visible = false
end

-- Plays a cutscene from Config/Story. Yields until it finishes (or is skipped).
function Cinematic.Play(cutsceneId)
	local cutscene = Story.Cutscenes[cutsceneId]
	if not cutscene or Cinematic.Playing then
		return
	end
	Cinematic.Playing = true
	Cinematic.CurrentMusic = cutscene.Music
	skipRequested = false
	fade.BackgroundTransparency = 0
	Cinematic.Enter({ Skippable = true })

	if cutscene.Title then
		titleCardShow(cutscene.Title, cutscene.Subtitle)
	end

	for _, shot in ipairs(cutscene.Shots) do
		if skipRequested then
			break
		end
		local started = os.clock()
		local tween
		if shot.Black then
			fade.BackgroundTransparency = 0
		else
			local from, to = keyframe(shot.From), keyframe(shot.To)
			pcall(function()
				player:RequestStreamAroundAsync(from.Position, 2)
			end)
			tween = Cinematic.MoveCamera(from, to, shot.Duration)
			task.spawn(Cinematic.Fade, false, 0.8)
		end
		for _, line in ipairs(shot.Lines or {}) do
			if skipRequested then
				break
			end
			Cinematic.ShowLine(line.Speaker, personalize(line.Text), true)
		end
		while os.clock() - started < shot.Duration and not skipRequested do
			task.wait(0.05)
		end
		Cinematic.ClearLine()
		if tween then
			tween:Cancel()
		end
		Cinematic.Fade(true, 0.6)
	end

	Cinematic.ClearLine()
	Cinematic.Exit()
	Cinematic.Fade(false, 0.8)
	Cinematic.Playing = false
	Cinematic.CurrentMusic = nil
end

function Cinematic.Init()
	gui = Create.Screen("Cinematic", 50)
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	fade = New("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = gui,
	})
	topBar = New("Frame", {
		Name = "Top",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = gui,
	})
	bottomBar = New("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = gui,
	})
	speakerLabel = Create.Label("", {
		Position = UDim2.new(0.15, 0, 0, 14),
		Size = UDim2.new(0.7, 0, 0, 28),
		Font = Theme.TitleFont,
		TextSize = 28,
		TextColor3 = Theme.Accent,
		ZIndex = 3,
		Parent = bottomBar,
	})
	lineLabel = Create.Label("", {
		Position = UDim2.new(0.15, 0, 0, 46),
		Size = UDim2.new(0.7, 0, 1, -56),
		TextSize = 22,
		Font = Enum.Font.Garamond,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = bottomBar,
	})
	hint = Create.Label("▼", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.86, 0, 1, -10),
		Size = UDim2.fromOffset(30, 24),
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 3,
		Parent = bottomBar,
	})
	skipButton = Create.Button("Skip  ▶▶", Theme.Panel, function()
		skipRequested = true
		advanceSignal:Fire()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(110, 34),
		ZIndex = 5,
		Visible = false,
		Parent = gui,
	})
	titleCard = New("Frame", {
		Name = "TitleCard",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(900, 160),
		Visible = false,
		ZIndex = 4,
		Parent = gui,
	}, {
		New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 100),
			Font = Theme.TitleFont,
			TextSize = 84,
			TextColor3 = Theme.Accent,
			ZIndex = 4,
		}),
		New("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 100),
			Size = UDim2.new(1, 0, 0, 40),
			Font = Enum.Font.Garamond,
			TextSize = 30,
			TextColor3 = Theme.Text,
			ZIndex = 4,
		}),
	})

	-- Click anywhere on the letterbox, press Space/Enter, or tap to advance.
	local clickCatcher = New("TextButton", {
		Name = "Advance",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = bottomBar,
	})
	clickCatcher.Activated:Connect(function()
		advanceSignal:Fire()
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not Cinematic.Active then
			return
		end
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			advanceSignal:Fire()
		end
	end)

	-- Keep the camera scripted while a cutscene runs (the default camera scripts try to reclaim it).
	RunService.RenderStepped:Connect(function()
		if Cinematic.Playing and camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)
end

Cinematic.Advance = advanceSignal

return Cinematic
