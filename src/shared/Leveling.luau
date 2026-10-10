local GameConfig = require(script.Parent.Config.GameConfig)

local Leveling = {}

function Leveling.XPToNext(level)
	return math.floor(100 * level ^ 1.5)
end

-- Returns newLevel, newXP, levelsGained
function Leveling.AddXP(level, xp, amount)
	local gained = 0
	xp += amount
	while level < GameConfig.MaxLevel and xp >= Leveling.XPToNext(level) do
		xp -= Leveling.XPToNext(level)
		level += 1
		gained += 1
	end
	if level >= GameConfig.MaxLevel then
		xp = 0
	end
	return level, xp, gained
end

return Leveling
