-- Loading screen shown while the server builds the world and loads your save.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local New = Create.New

local player = Players.LocalPlayer

local Loading = {}
local released = false

-- The intro calls this once it has the screen covered; until then new players keep the loading screen.
function Loading.Release()
	released = true
end

function Loading.Init()
	local gui = Create.Screen("Loading", 200)
	gui.IgnoreGuiInset = true
	local back = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BorderSizePixel = 0,
		Parent = gui,
	})
	local title = Create.Label("MARGERON", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(700, 90),
		Font = Theme.TitleFont,
		TextSize = 84,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = back,
	})
	local status = Create.Label("The world is taking shape...", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(700, 30),
		Font = Enum.Font.Garamond,
		TextSize = 24,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = back,
	})
	task.spawn(function()
		local dots = 0
		local started = os.clock()
		while
			not (State.Data and player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
			and os.clock() - started < 60
		do
			dots = dots % 3 + 1
			status.Text = "The world is taking shape" .. string.rep(".", dots)
			task.wait(0.4)
		end
		-- Players who haven't seen the prologue go straight from here into the opening cutscene.
		local waitStart = os.clock()
		while State.Data and not State.Data.Story.PrologueSeen and not released and os.clock() - waitStart < 20 do
			task.wait(0.1)
		end
		task.wait(0.5)
		TweenService:Create(back, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		TweenService:Create(status, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		task.wait(1.1)
		gui:Destroy()
	end)
end

return Loading
