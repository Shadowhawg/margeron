-- The Margeron calendar and the day/night cycle.
--
-- Every server starts at night (StartHour). Time then runs at DaySeconds of real time per game day.
-- The date is shared by all servers: it advances one day per DaySeconds of real time since Epoch.
return {
	DaySeconds = 24 * 60, -- one in-game day = 24 real minutes
	StartHour = 21.5, -- servers open at 9:30 at night
	NightStart = 20, -- 8 PM
	NightEnd = 5.5, -- 5:30 AM
	Epoch = 1767225600,

	BaseYear = 913,
	Era = "of the Ember Age",
	EraShort = "E.A.",

	Weekdays = { "Sunsday", "Moonsday", "Tidesday", "Windsday", "Thornsday", "Fireday", "Starsday" },

	-- 12 months x 30 days = 360-day year.
	Months = {
		{ Name = "Frostwane", Season = "Winter" },
		{ Name = "Thawmoon", Season = "Winter" },
		{ Name = "Seedrise", Season = "Spring" },
		{ Name = "Rainhold", Season = "Spring" },
		{ Name = "Bloomtide", Season = "Spring" },
		{ Name = "Highsun", Season = "Summer" },
		{ Name = "Emberfall", Season = "Summer" },
		{ Name = "Goldreap", Season = "Summer" },
		{ Name = "Leafturn", Season = "Autumn" },
		{ Name = "Duskmere", Season = "Autumn" },
		{ Name = "Hearthfrost", Season = "Autumn" },
		{ Name = "Longnight", Season = "Winter" },
	},
	DaysPerMonth = 30,

	-- Holidays last a whole in-game day (24 real minutes) and give everyone a bonus.
	--   Bonus keys: XP, Gold, Crops, Gather (multipliers added on top of 1)
	Holidays = {
		{
			Month = 1,
			Day = 1,
			Name = "New Ember",
			Description = "The year turns. +25% experience.",
			Bonus = { XP = 0.25 },
		},
		{
			Month = 3,
			Day = 10,
			Name = "Founding Day",
			Description = "Riverwatch celebrates its founding. +25% gold.",
			Bonus = { Gold = 0.25 },
		},
		{
			Month = 5,
			Day = 15,
			Name = "Blossom Fair",
			Description = "Wildflowers everywhere. Double herbs when gathering.",
			Bonus = { Gather = 1 },
		},
		{
			Month = 7,
			Day = 1,
			Name = "Night of Embers",
			Description = "The Ashen Guard is remembered. +25% XP and gold.",
			Bonus = { XP = 0.25, Gold = 0.25 },
		},
		{
			Month = 8,
			Day = 20,
			Name = "Harvest Moon",
			Description = "+50% crop and livestock yields.",
			Bonus = { Crops = 0.5 },
		},
		{
			Month = 10,
			Day = 13,
			Name = "Veil Night",
			Description = "The dead are restless. +25% XP.",
			Bonus = { XP = 0.25 },
		},
		{
			Month = 12,
			Day = 30,
			Name = "Longnight Vigil",
			Description = "The longest night. Double gathering and +25% gold.",
			Bonus = { Gather = 1, Gold = 0.25 },
		},
	},

	-- Night is more dangerous and more rewarding.
	Night = {
		EnemyDamage = 0.2, -- +20% damage from enemies
		EnemyRewards = 0.25, -- +25% XP and gold from kills
		Moonpetal = 1, -- Moonpetal yields double at night
		SneakDetection = 0.3, -- sneaking enemies only notice you at 30% of their range (45% by day)
	},
}
