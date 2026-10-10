--!strict
-- One place to reskin the whole UI. A UI artist can restyle the game by editing this
-- file plus replacing emoji icons with ImageLabels later.

local Theme = {
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamBold,

	Background = Color3.fromRGB(30, 22, 54),
	Panel = Color3.fromRGB(46, 35, 82),
	PanelLight = Color3.fromRGB(64, 50, 110),
	Stroke = Color3.fromRGB(20, 14, 38),

	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 180, 225),

	Accent = Color3.fromRGB(255, 70, 140), -- FILM button, primary actions
	Followers = Color3.fromRGB(90, 190, 255),
	Cash = Color3.fromRGB(95, 220, 120),
	Gold = Color3.fromRGB(255, 205, 70),
	Trend = Color3.fromRGB(255, 120, 50),
	Viral = Color3.fromRGB(255, 80, 200),
	Danger = Color3.fromRGB(240, 70, 70),
	Disabled = Color3.fromRGB(110, 100, 140),

	Corner = UDim.new(0, 14),
	Pill = UDim.new(1, 0),

	-- Design resolution. Offsets are authored at this size and scaled by UI/Root.
	DesignWidth = 900,
	DesignHeight = 500,
	MinScale = 0.55,
	MaxScale = 1.4,
}

return Theme
