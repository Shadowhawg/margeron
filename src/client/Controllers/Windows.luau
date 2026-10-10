-- Manages the full-screen menu windows (skills, quests, inventory, store, shops).
-- Only one is open at a time; open windows re-render whenever player data changes.
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local New = Create.New

local Windows = {}

local gui, frame, titleLabel, content
local registry = {} -- [name] = { Title, Render(content, args) }
local current, currentArgs

function Windows.Register(name, title, render)
	registry[name] = { Title = title, Render = render }
end

function Windows.IsOpen(name)
	if name then
		return current == name
	end
	return current ~= nil
end

function Windows.Render()
	if not current or not State.Data then
		return
	end
	Create.Clear(content)
	registry[current].Render(content, currentArgs)
end

function Windows.Open(name, args)
	if not registry[name] then
		return
	end
	current = name
	currentArgs = args
	titleLabel.Text = registry[name].Title
	frame.Visible = true
	Windows.Render()
end

function Windows.Close()
	current = nil
	currentArgs = nil
	frame.Visible = false
	Create.Clear(content)
end

function Windows.Toggle(name)
	if current == name then
		Windows.Close()
	else
		Windows.Open(name)
	end
end

function Windows.SetArgs(args)
	currentArgs = args
	Windows.Render()
end

function Windows.Init()
	gui = Create.Screen("Windows", 10)
	frame = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 580),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Create.Corner(10), Create.Stroke(Theme.Border, 2) })

	titleLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -80, 0, 44),
		Font = Theme.TitleFont,
		TextSize = 34,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	Create.Button("X", Theme.Bad, Windows.Close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		Parent = frame,
	})
	content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		Parent = frame,
	})

	State.Changed:Connect(Windows.Render)
end

function Windows.Start()
	-- The server can open windows too (crafting stations, planting a field).
	local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)
	Remotes.Open.OnClientEvent:Connect(function(name, args)
		Windows.Open(name, args)
	end)
end

return Windows
