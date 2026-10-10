-- Toast messages, the big level-up banner and zone entry banners.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local New = Create.New

local Notifications = {}

local KIND_COLORS = {
	Info = Theme.Text,
	Success = Theme.Good,
	Error = Theme.Bad,
	Warning = Color3.fromRGB(255, 140, 60),
	Quest = Theme.Accent,
	QuestComplete = Theme.Gold,
	Progress = Theme.Muted,
	LevelUp = Theme.Gold,
	Boss = Color3.fromRGB(255, 110, 60),
}

local gui, stack, banner

function Notifications.Show(text, kind)
	if not stack then
		return
	end
	kind = kind or "Info"
	if kind == "LevelUp" then
		Notifications.Banner("LEVEL UP", text)
	end
	local isSmall = kind == "Progress"
	local toast = New("TextLabel", {
		Size = UDim2.fromOffset(isSmall and 260 or 460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.2,
		Text = text,
		TextColor3 = KIND_COLORS[kind] or Theme.Text,
		Font = isSmall and Theme.BodyFont or Theme.BoldFont,
		TextSize = isSmall and 14 or 17,
		TextWrapped = true,
		Parent = stack,
	}, { Create.Corner(6), Create.Padding(8) })
	task.delay(isSmall and 2 or 4.5, function()
		local tween =
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
	-- Keep the stack short.
	local toasts = {}
	for _, child in ipairs(stack:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 6 then
		toasts[1]:Destroy()
	end
end

-- Large centered title, used for level ups and entering zones.
function Notifications.Banner(title, subtitle)
	if not banner then
		return
	end
	banner.Title.Text = title
	banner.Subtitle.Text = subtitle or ""
	banner.Title.TextTransparency = 1
	banner.Subtitle.TextTransparency = 1
	banner.Visible = true
	TweenService:Create(banner.Title, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	TweenService:Create(banner.Subtitle, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	local token = {}
	Notifications._bannerToken = token
	task.delay(3, function()
		if Notifications._bannerToken ~= token then
			return
		end
		TweenService:Create(banner.Title, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		TweenService:Create(banner.Subtitle, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	end)
end

function Notifications.Init()
	gui = Create.Screen("Notifications", 20)
	stack = New("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(460, 400),
		Parent = gui,
	}, { Create.List(6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center) })

	banner = New("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 110),
		Visible = false,
		Parent = gui,
	}, {
		New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 64),
			Font = Theme.TitleFont,
			TextSize = 56,
			TextColor3 = Theme.Accent,
			TextStrokeTransparency = 0.5,
		}),
		New("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, 0, 0, 30),
			Font = Theme.BodyFont,
			TextSize = 20,
			TextColor3 = Theme.Text,
			TextStrokeTransparency = 0.5,
			TextWrapped = true,
		}),
	})

	Remotes.Notify.OnClientEvent:Connect(function(payload)
		Notifications.Show(payload.Text, payload.Kind)
	end)
end

return Notifications
