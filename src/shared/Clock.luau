-- Game time and calendar, readable on both server and client.
-- The server publishes three attributes on ReplicatedStorage when it starts; everything else is
-- computed from the synced server clock, so no time updates need to be sent over the network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Calendar = require(script.Parent.Config.Calendar)

local Clock = {}

local DAYS_PER_YEAR = #Calendar.Months * Calendar.DaysPerMonth

local function anchor()
	return ReplicatedStorage:GetAttribute("ClockEpoch") or 0,
		ReplicatedStorage:GetAttribute("ClockStartHour") or Calendar.StartHour,
		ReplicatedStorage:GetAttribute("ClockStartDay") or 0
end

function Clock.Now()
	return workspace:GetServerTimeNow()
end

-- Server only: start the clock (servers open at night).
function Clock.Start()
	local now = Clock.Now()
	ReplicatedStorage:SetAttribute("ClockEpoch", now)
	ReplicatedStorage:SetAttribute("ClockStartHour", Calendar.StartHour)
	ReplicatedStorage:SetAttribute("ClockStartDay", math.floor((os.time() - Calendar.Epoch) / Calendar.DaySeconds))
end

local function totalHours(now)
	local epoch, startHour = anchor()
	return startHour + ((now or Clock.Now()) - epoch) * 24 / Calendar.DaySeconds
end

-- Hour of the day, 0-24 (fractional).
function Clock.Hour(now)
	return totalHours(now) % 24
end

-- Absolute day number since the calendar began.
function Clock.DayIndex(now)
	local _, _, startDay = anchor()
	return startDay + math.floor(totalHours(now) / 24)
end

function Clock.IsNight(now)
	local hour = Clock.Hour(now)
	return hour >= Calendar.NightStart or hour < Calendar.NightEnd
end

function Clock.Date(dayIndex)
	dayIndex = dayIndex or Clock.DayIndex()
	local year = Calendar.BaseYear + math.floor(dayIndex / DAYS_PER_YEAR)
	local dayOfYear = dayIndex % DAYS_PER_YEAR
	local monthIndex = math.floor(dayOfYear / Calendar.DaysPerMonth) + 1
	local month = Calendar.Months[monthIndex]
	return {
		Year = year,
		Month = monthIndex,
		MonthName = month.Name,
		Season = month.Season,
		Day = dayOfYear % Calendar.DaysPerMonth + 1,
		Weekday = Calendar.Weekdays[dayIndex % #Calendar.Weekdays + 1],
	}
end

function Clock.Holiday(dayIndex)
	local date = Clock.Date(dayIndex)
	for _, holiday in ipairs(Calendar.Holidays) do
		if holiday.Month == date.Month and holiday.Day == date.Day then
			return holiday
		end
	end
	return nil
end

-- Multiplier bonus (added to 1) from today's holiday: kind = XP | Gold | Crops | Gather
function Clock.HolidayBonus(kind)
	local holiday = Clock.Holiday()
	return holiday and holiday.Bonus[kind] or 0
end

local function ordinal(n)
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end

function Clock.FormatTime(now)
	local hour = Clock.Hour(now)
	local h = math.floor(hour)
	local m = math.floor((hour - h) * 60)
	return string.format("%02d:%02d", h, m)
end

function Clock.FormatDate(dayIndex)
	local date = Clock.Date(dayIndex)
	return string.format(
		"%s, %s of %s, %d %s",
		date.Weekday,
		ordinal(date.Day),
		date.MonthName,
		date.Year,
		Calendar.EraShort
	)
end

return Clock
