-- Character creator: race, gender, height, build, skin tone, hair, beard and outfit, with a live
-- preview on your actual character. Opens during the intro, and again from Seer Ilsa (for gold).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Races = require(Shared.Config.Races)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local New = Create.New

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Creator = {}
Creator.Open_ = false

local gui, panel, content
local appearance = nil
local firstTime = false
local dirty = false
local orbit = 0
local zoomed = false
local activeDrag = nil -- the slider being dragged
local confirmedEvent = Instance.new("BindableEvent")
Creator.Confirmed = confirmedEvent.Event

local function section(title, order)
	local frame = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = content,
	}, { Create.List(6) })
	Create.Label(title, {
		Font = Theme.BoldFont,
		TextColor3 = Theme.Accent,
		TextSize = 15,
		LayoutOrder = 0,
		Parent = frame,
	})
	return frame
end

local function row(parent, order, height)
	return New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 34),
		LayoutOrder = order,
		Parent = parent,
	}, { Create.List(6, Enum.FillDirection.Horizontal) })
end

local function changed()
	dirty = true
	Creator.Render()
end

local function slider(parent, order, label, value, onChange)
	local frame = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = parent }
	)
	Create.Label(label, { Size = UDim2.fromScale(0.28, 1), TextSize = 14, TextColor3 = Theme.Muted, Parent = frame })
	local track = New("Frame", {
		Position = UDim2.new(0.3, 0, 0.5, -4),
		Size = UDim2.new(0.66, 0, 0, 8),
		BackgroundColor3 = Theme.PanelLight,
		Parent = frame,
	}, { Create.Corner(4) })
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Accent,
		Parent = track,
	}, { Create.Corner(10) })
	local function set(x)
		local t = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		onChange(t)
		dirty = true
	end
	local hit = New("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.7, 1),
		Position = UDim2.fromScale(0.28, 0),
		Parent = frame,
	})
	hit.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			activeDrag = set
			set(input.Position.X)
		end
	end)
end

local function swatches(parent, order, colors, selected, onPick)
	local frame = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, {
		New("UIGridLayout", {
			CellSize = UDim2.fromOffset(34, 34),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, color in ipairs(colors) do
		local b = New("TextButton", {
			Text = "",
			LayoutOrder = i,
			BackgroundColor3 = color,
			AutoButtonColor = true,
			Parent = frame,
		}, {
			Create.Corner(17),
			Create.Stroke(i == selected and Color3.new(1, 1, 1) or Theme.Border, i == selected and 3 or 1),
		})
		b.Activated:Connect(function()
			onPick(i)
		end)
	end
end

local function cycler(parent, order, label, list, current, names, onPick)
	local frame = row(parent, order, 34)
	Create.Label(label, { Size = UDim2.fromScale(0.28, 1), TextSize = 14, TextColor3 = Theme.Muted, Parent = frame })
	local index = table.find(list, current) or 1
	Create.Button("<", Theme.PanelLight, function()
		onPick(list[(index - 2) % #list + 1])
	end, { Size = UDim2.fromOffset(34, 32), Parent = frame })
	Create.Label(names[current] or current, {
		Size = UDim2.fromScale(0.42, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.BoldFont,
		Parent = frame,
	})
	Create.Button(">", Theme.PanelLight, function()
		onPick(list[index % #list + 1])
	end, { Size = UDim2.fromOffset(34, 32), Parent = frame })
end

function Creator.Render()
	if not appearance then
		return
	end
	Create.Clear(content)
	local race = Races.Races[appearance.Race]

	-- Race
	local raceSection = section("RACE", 1)
	local grid = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = raceSection,
	}, {
		New("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 34),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, raceId in ipairs(Races.Order) do
		local selected = raceId == appearance.Race
		Create.Button(Races.Races[raceId].Name, selected and Theme.Border or Theme.PanelLight, function()
			appearance.Race = raceId
			appearance.SkinTone = math.min(appearance.SkinTone, #Races.Races[raceId].SkinTones)
			changed()
		end, { LayoutOrder = i, Parent = grid })
	end
	Create.Label(race.Description, {
		TextSize = 13,
		TextColor3 = Theme.Text,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = raceSection,
	})
	Create.Label(
		race.BonusText,
		{ TextSize = 13, TextColor3 = Theme.Gold, Font = Theme.BoldFont, LayoutOrder = 3, Parent = raceSection }
	)

	-- Body
	local body = section("BODY", 2)
	local genders = row(body, 1)
	for _, gender in ipairs(Races.Genders) do
		Create.Button(gender, appearance.Gender == gender and Theme.Border or Theme.PanelLight, function()
			appearance.Gender = gender
			if gender == "Female" and appearance.Beard ~= "None" and firstTime then
				appearance.Beard = "None"
			end
			changed()
		end, { Size = UDim2.new(0.5, -3, 1, 0), Parent = genders })
	end
	slider(body, 2, "Height", appearance.Height, function(v)
		appearance.Height = v
	end)
	slider(body, 3, "Build", appearance.Weight, function(v)
		appearance.Weight = v
	end)

	-- Skin
	local skin = section("SKIN TONE", 3)
	swatches(skin, 1, race.SkinTones, appearance.SkinTone, function(i)
		appearance.SkinTone = i
		changed()
	end)

	-- Hair
	local hair = section("HAIR", 4)
	local hairNames, beardNames = {}, {}
	for id, style in pairs(Races.Hair.Styles) do
		hairNames[id] = style.Name
	end
	for id, style in pairs(Races.Beards.Styles) do
		beardNames[id] = style.Name
	end
	cycler(hair, 1, "Style", Races.Hair.Order, appearance.Hair, hairNames, function(v)
		appearance.Hair = v
		changed()
	end)
	cycler(hair, 2, "Beard", Races.Beards.Order, appearance.Beard, beardNames, function(v)
		appearance.Beard = v
		changed()
	end)
	swatches(hair, 3, Races.HairColors, appearance.HairColor, function(i)
		appearance.HairColor = i
		changed()
	end)

	-- Outfit
	local outfit = section("OUTFIT", 5)
	local outfitColors = {}
	for _, o in ipairs(Races.Outfits) do
		table.insert(outfitColors, o.Tunic)
	end
	swatches(outfit, 1, outfitColors, appearance.Outfit, function(i)
		appearance.Outfit = i
		changed()
	end)
	Create.Label(
		Races.Outfits[appearance.Outfit].Name .. " garb",
		{ TextSize = 13, TextColor3 = Theme.Muted, LayoutOrder = 2, Parent = outfit }
	)

	-- Actions
	local actions = section("", 6)
	local buttons = row(actions, 1, 44)
	Create.Button("Randomize", Theme.PanelLight, function()
		local raceId = Races.Order[math.random(1, #Races.Order)]
		local r = Races.Races[raceId]
		appearance.Race = raceId
		appearance.Gender = Races.Genders[math.random(1, 2)]
		appearance.Height = math.random()
		appearance.Weight = math.random()
		appearance.SkinTone = math.random(1, #r.SkinTones)
		appearance.Hair = Races.Hair.Order[math.random(1, #Races.Hair.Order)]
		appearance.HairColor = math.random(1, #Races.HairColors)
		appearance.Beard = appearance.Gender == "Male" and Races.Beards.Order[math.random(1, #Races.Beards.Order)]
			or "None"
		appearance.Outfit = math.random(1, #Races.Outfits)
		changed()
	end, { Size = UDim2.fromScale(0.38, 1), Parent = buttons })
	Create.Button(firstTime and "This is me" or "Confirm", Theme.Good, function()
		local result = Net.Request("ConfirmAppearance", appearance)
		if result.ok then
			Creator.Close()
			confirmedEvent:Fire()
		end
	end, { Size = UDim2.fromScale(0.6, 1), TextSize = 17, Parent = buttons })
end

local function updateCamera()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local base = root.CFrame * CFrame.Angles(0, math.rad(orbit), 0)
	local focus = (base * CFrame.new(0, zoomed and 1.6 or 0.4, 0)).Position
	local distance = zoomed and 4.5 or 10
	local camPos = (base * CFrame.new(-distance * 0.25, zoomed and 1.8 or 1.2, -distance)).Position
	-- Shift the framing so the character sits to the right of the panel.
	local look = CFrame.lookAt(camPos, focus)
	camera.CFrame = look * CFrame.new(-(zoomed and 0.9 or 2.2), 0, 0)
end

function Creator.Open(isFirstTime)
	local data = State.Data
	if not data then
		return
	end
	firstTime = isFirstTime
	appearance = table.clone(data.Appearance)
	gui.Enabled = true
	Creator.Open_ = true
	camera.CameraType = Enum.CameraType.Scriptable
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, name in ipairs({ "HUD", "Windows" }) do
		local other = playerGui and playerGui:FindFirstChild(name)
		if other then
			other.Enabled = false
		end
	end
	Creator.Render()
end

function Creator.Close()
	gui.Enabled = false
	Creator.Open_ = false
	camera.CameraType = Enum.CameraType.Custom
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, name in ipairs({ "HUD", "Windows" }) do
		local other = playerGui and playerGui:FindFirstChild(name)
		if other then
			other.Enabled = true
		end
	end
end

function Creator.Init()
	gui = Create.Screen("Creator", 40)
	gui.Enabled = false
	panel = New("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.new(0, 420, 1, -48),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, { Create.Corner(10), Create.Stroke(Theme.Border, 2) })
	Create.Label("Who do you see?", {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -36, 0, 40),
		Font = Theme.TitleFont,
		TextSize = 34,
		TextColor3 = Theme.Accent,
		Parent = panel,
	})
	content = New("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 1, -70),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, { Create.List(14), New("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

	-- Camera controls
	local controls = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.62, 0, 1, -24),
		Size = UDim2.fromOffset(300, 44),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Create.List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	Create.Button("⟲", Theme.Panel, function()
		orbit -= 30
	end, { Size = UDim2.fromOffset(60, 44), TextSize = 22, Parent = controls })
	Create.Button("Face / Body", Theme.Panel, function()
		zoomed = not zoomed
	end, { Size = UDim2.fromOffset(140, 44), Parent = controls })
	Create.Button("⟳", Theme.Panel, function()
		orbit += 30
	end, { Size = UDim2.fromOffset(60, 44), TextSize = 22, Parent = controls })

	UserInputService.InputChanged:Connect(function(input)
		if
			activeDrag
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			activeDrag(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			activeDrag = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		if Creator.Open_ then
			camera.CameraType = Enum.CameraType.Scriptable
			updateCamera()
		end
	end)

	-- Send previews at most 4 times a second.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if Creator.Open_ and dirty then
				dirty = false
				Net.Request("PreviewAppearance", appearance)
			end
		end
	end)
end

return Creator
