-- NPC conversation box. The server sends the lines and options; we send back the choice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local Net = require(script.Parent.Net)
local Windows = require(script.Parent.Windows)
local New = Create.New

local player = Players.LocalPlayer

local Dialogue = {}

local frame, nameLabel, roleLabel, textLabel, optionList
local openedAt -- position when the dialogue opened, to close it if the player walks away
local busy = false

local function close()
	frame.Visible = false
	openedAt = nil
end

local show

local function choose(npcId, optionId)
	if busy then
		return
	end
	if optionId == "bye" then
		close()
		return
	end
	busy = true
	local result = Net.Request("DialogueChoice", npcId, optionId)
	busy = false
	if result.dialogue then
		show(result.dialogue)
	elseif result.open then
		close()
		Windows.Open(result.open, result.board)
	else
		close()
	end
end

function show(payload)
	nameLabel.Text = payload.Name
	roleLabel.Text = payload.Role or ""
	textLabel.Text = payload.Text
	Create.Clear(optionList)
	for i, option in ipairs(payload.Options) do
		local isQuest = option.Id:match("^quest:") or option.Id:match("^accept:")
		Create.Button("  " .. i .. ".  " .. option.Label, isQuest and Color3.fromRGB(70, 58, 36) or Theme.PanelLight, function()
			choose(payload.NPC, option.Id)
		end, {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = isQuest and Theme.Accent or Theme.Text,
			Parent = optionList,
		})
	end
	frame.Visible = true
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	openedAt = root and root.Position
end

function Dialogue.Init()
	local gui = Create.Screen("Dialogue", 5)
	frame = New("Frame", {
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(680, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = gui,
	}, { Create.Corner(10), Create.Stroke(Theme.Border, 2), Create.Padding(16), Create.List(8) })

	local header = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = frame,
	})
	nameLabel = Create.Label("", {
		Font = Theme.TitleFont,
		TextSize = 30,
		TextColor3 = Theme.Accent,
		Size = UDim2.fromScale(0.6, 1),
		Parent = header,
	})
	roleLabel = Create.Label("", {
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.fromScale(0.4, 1),
		Parent = header,
	})
	textLabel = Create.Label("", {
		TextSize = 18,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	optionList = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = frame,
	}, { Create.List(6) })
end

function Dialogue.Start()
	Remotes.Dialogue.OnClientEvent:Connect(function(payload)
		Windows.Close()
		show(payload)
	end)
	RunService.Heartbeat:Connect(function()
		if not openedAt then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - openedAt).Magnitude > 18 then
			close()
		end
	end)
end

return Dialogue
