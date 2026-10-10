-- NPC conversations, presented like a cutscene: letterbox bars, an over-the-shoulder camera on
-- the speaker, typewriter text, and reply options. The server sends lines and options.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local Net = require(script.Parent.Net)
local Windows = require(script.Parent.Windows)
local Cinematic = require(script.Parent.Cinematic)
local New = Create.New

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Dialogue = {}

local frame, optionList
local handlers = {} -- option index -> callback, for number keys
local busy = false
local open = false
local token = 0

local function close()
	if not open then
		return
	end
	open = false
	token += 1
	frame.Visible = false
	Cinematic.Exit()
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
	elseif result.open == "Creator" then
		close()
		require(script.Parent.Parent.Panels.Creator).Open(false)
	elseif result.open then
		close()
		Windows.Open(result.open, result.args or result.board)
	else
		close()
	end
end

-- Frame the NPC over the player's shoulder.
local function frameShot(position, isObject)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not position then
		return
	end
	local npcHead = position + Vector3.new(0, isObject and 1 or 1.6, 0)
	local toNpc = (npcHead - root.Position) * Vector3.new(1, 0, 1)
	if toNpc.Magnitude < 0.1 then
		return
	end
	local dir = toNpc.Unit
	local right = dir:Cross(Vector3.yAxis)
	local camPos = root.Position + Vector3.new(0, 2.2, 0) - dir * 4 + right * 2.4
	local target = CFrame.lookAt(camPos, npcHead)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService
		:Create(camera, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = target })
		:Play()
end

function show(payload)
	token += 1
	local myToken = token
	if not open then
		open = true
		Cinematic.Enter({ TallBottom = true })
		frameShot(payload.Position, payload.IsObject)
	end
	Create.Clear(optionList)
	table.clear(handlers)
	frame.Visible = true
	task.spawn(function()
		Cinematic.ShowLine(payload.Name .. (payload.Role and ("  ·  " .. payload.Role) or ""), payload.Text, false)
	end)
	-- Show options right away; picking one skips the rest of the line.
	for i, option in ipairs(payload.Options) do
		local isQuest = option.Id:match("^quest:") or option.Id:match("^accept:")
		local function pick()
			if myToken ~= token then
				return
			end
			choose(payload.NPC, option.Id)
		end
		handlers[i] = pick
		Create.Button(
			"  " .. i .. ".  " .. option.Label,
			isQuest and Color3.fromRGB(70, 58, 36) or Color3.fromRGB(28, 26, 24),
			pick,
			{
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = isQuest and Theme.Accent or Theme.Text,
				TextSize = 15,
				Parent = optionList,
			}
		)
	end
end

function Dialogue.IsOpen()
	return open
end

function Dialogue.Init()
	local gui = Create.Screen("Dialogue", 60)
	gui.IgnoreGuiInset = true
	frame = New("Frame", {
		Name = "Options",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.97, 0, 1, -16),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	optionList = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, { Create.List(5) })
end

function Dialogue.Start()
	Remotes.Dialogue.OnClientEvent:Connect(function(payload)
		if Cinematic.Playing then
			return
		end
		Windows.Close()
		show(payload)
	end)
	-- Number keys pick options while talking.
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not open or processed then
			return
		end
		local numbers = {
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
			Enum.KeyCode.Five,
			Enum.KeyCode.Six,
			Enum.KeyCode.Seven,
		}
		local index = table.find(numbers, input.KeyCode)
		if index and handlers[index] then
			handlers[index]()
		end
	end)
end

return Dialogue
