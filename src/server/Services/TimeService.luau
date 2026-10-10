-- Runs the day/night cycle and calendar: starts each server at night, keeps server lighting in
-- step, and announces dusk, dawn, new days and holidays.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clock = require(Shared.Clock)

local TimeService = {}
local Services

local function announce(text, kind)
	for _, player in ipairs(Players:GetPlayers()) do
		Services.PlayerService.Notify(player, text, kind)
	end
end

function TimeService.IsNight()
	return Clock.IsNight()
end

function TimeService.Init(services)
	Services = services
	Clock.Start()
	Lighting.ClockTime = Clock.Hour()
end

function TimeService.Start()
	local wasNight = Clock.IsNight()
	local day = Clock.DayIndex()
	while true do
		task.wait(2)
		Lighting.ClockTime = Clock.Hour()
		local night = Clock.IsNight()
		if night ~= wasNight then
			wasNight = night
			if night then
				announce("Night falls over Margeron. Creatures grow bolder, and so do their rewards.", "Warning")
			else
				announce("Dawn breaks.", "Info")
			end
		end
		local today = Clock.DayIndex()
		if today ~= day then
			day = today
			local holiday = Clock.Holiday(today)
			announce(
				"A new day: "
					.. Clock.FormatDate(today)
					.. (holiday and ("  -  " .. holiday.Name .. "! " .. holiday.Description) or ""),
				holiday and "QuestComplete" or "Info"
			)
		end
	end
end

return TimeService
