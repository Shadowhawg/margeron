-- Day/night on the client: drives the sky from the shared game clock, darkens the world at night,
-- gives your character a lantern after dark, and shows the time and date on screen.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clock = require(Shared.Clock)
local Calendar = require(Shared.Config.Calendar)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local DayNight = {}
DayNight.Override = nil -- force an hour (the opening cutscenes happen at night)

local timeLabel, dateLabel

local DAY_AMBIENT = Color3.fromRGB(125, 120, 135)
local NIGHT_AMBIENT = Color3.fromRGB(62, 70, 104)

local function nightFactor(hour)
	-- 0 = full day, 1 = full night, with smooth dusk and dawn.
	if hour >= Calendar.NightStart + 1.5 or hour < Calendar.NightEnd - 1 then
		return 1
	elseif hour >= Calendar.NightStart - 1 and hour < Calendar.NightStart + 1.5 then
		return (hour - (Calendar.NightStart - 1)) / 2.5
	elseif hour >= Calendar.NightEnd - 1 and hour < Calendar.NightEnd + 1 then
		return 1 - (hour - (Calendar.NightEnd - 1)) / 2
	end
	return 0
end

function DayNight.IsNight()
	local hour = DayNight.Override or Clock.Hour()
	return nightFactor(hour) > 0.5
end

local function updateLantern(isNight)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local lantern = root:FindFirstChild("Lantern")
	if isNight and not lantern then
		lantern = Instance.new("PointLight")
		lantern.Name = "Lantern"
		lantern.Color = Color3.fromRGB(255, 200, 140)
		lantern.Range = 24
		lantern.Brightness = 0.9
		lantern.Shadows = false
		lantern.Parent = root
	elseif not isNight and lantern then
		lantern:Destroy()
	end
end

function DayNight.Init()
	local gui = Create.Screen("Clock", 2)
	local frame = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.45,
		Parent = gui,
	}, { Create.Corner(8) })
	timeLabel = Create.Label("", {
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.BoldFont,
		TextSize = 16,
		TextColor3 = Theme.Accent,
		Parent = frame,
	})
	dateLabel = Create.Label("", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = Theme.Muted,
		Parent = frame,
	})
	DayNight.Gui = gui
end

function DayNight.Start()
	RunService.RenderStepped:Connect(function()
		local hour = DayNight.Override or Clock.Hour()
		Lighting.ClockTime = hour
		local n = nightFactor(hour)
		Lighting.OutdoorAmbient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, n)
		Lighting.Brightness = 2.4 - n * 1.2
		Lighting.ExposureCompensation = n * 0.35
	end)
	task.spawn(function()
		while true do
			local hour = DayNight.Override or Clock.Hour()
			local night = nightFactor(hour) > 0.5
			updateLantern(night)
			local day = Clock.DayIndex()
			local holiday = Clock.Holiday(day)
			local h = math.floor(hour)
			timeLabel.Text = (night and "☾  " or "☀  ")
				.. string.format("%02d:%02d", h, math.floor((hour - h) * 60))
				.. (holiday and ("   ·   " .. holiday.Name) or "")
			timeLabel.TextColor3 = holiday and Theme.Gold or Theme.Accent
			dateLabel.Text = Clock.FormatDate(day) .. "   ·   " .. Clock.Date(day).Season
			task.wait(0.5)
		end
	end)
end

return DayNight
