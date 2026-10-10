--!strict
-- The FILM button, the timing bar and the post card: the 30-second loop's entire UI.
--
-- Flow: tap FILM -> StartTake (server picks the green zone) -> marker sweeps -> tap again
-- (or let it run out) -> SubmitTake with the marker position -> animate the result.
-- Taps during cooldown are buffered so mashing the button on mobile still feels instant.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

type Phase = "Idle" | "Starting" | "Sweeping" | "Submitting" | "Cooldown"

local FilmButton = {}

local GRADE_STYLE: { [string]: { Text: string, Color: Color3 } } = {
	Perfect = { Text = "PERFECT!", Color = Theme.Gold },
	Good = { Text = "GOOD!", Color = Theme.Cash },
	Miss = { Text = "POSTED", Color = Theme.Muted },
}

function FilmButton.mount(isMenuOpen: () -> boolean)
	local gui = Root.Gui
	local startTake = Net.fn("StartTake")
	local submitTake = Net.fn("SubmitTake")

	-- Layout ----------------------------------------------------------------------------
	local cluster: Frame = Util.new("Frame", {
		Name = "FilmCluster",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(420, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Root.scaled(cluster)

	local button: TextButton = Util.button({
		Text = "🎬 FILM",
		Size = UDim2.fromOffset(150, 150),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Color = Theme.Accent,
		Parent = cluster,
	}, function() end)
	Util.corner(button, UDim.new(1, 0))
	button.Name = "FilmButton"

	local badge = Util.label({
		Text = "",
		Size = UDim2.fromOffset(110, 32),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Color = Theme.Gold,
		Parent = button,
	})

	local pointer = Util.label({
		Text = "👆",
		Size = UDim2.fromOffset(70, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 40, 1, -40),
		Parent = cluster,
	})
	pointer.ZIndex = 5
	pointer.Visible = false

	local bar: Frame = Util.new("Frame", {
		Name = "TakeBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -162),
		Size = UDim2.fromOffset(380, 34),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = cluster,
	})
	Util.corner(bar, UDim.new(0, 10))
	Util.stroke(bar)
	local zone: Frame = Util.new("Frame", { BackgroundColor3 = Theme.Cash, BorderSizePixel = 0, Parent = bar })
	Util.corner(zone, UDim.new(0, 8))
	local core: Frame = Util.new("Frame", { BackgroundColor3 = Theme.Gold, BorderSizePixel = 0, Parent = bar })
	Util.corner(core, UDim.new(0, 6))
	local marker: Frame = Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 8, 1, 14),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Theme.Text,
		ZIndex = 3,
		Parent = bar,
	})
	Util.corner(marker, UDim.new(1, 0))
	Util.stroke(marker, nil, 2)

	local card: Frame = Util.new("Frame", {
		Name = "PostCard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -205),
		Size = UDim2.fromOffset(300, 120),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = cluster,
	})
	Util.corner(card)
	Util.stroke(card)
	local gradeLabel = Util.label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), Parent = card })
	local viewsLabel = Util.label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 36),
		Parent = card,
	})
	local gainsLabel = Util.label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 66),
		Color = Theme.Cash,
		Parent = card,
	})
	local bonusLabel = Util.label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 92),
		Color = Theme.Trend,
		Parent = card,
	})

	local viralSplash = Util.label({
		Text = "🚀 WENT VIRAL!",
		Size = UDim2.fromOffset(520, 90),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Color = Theme.Viral,
		Parent = gui,
	})
	viralSplash.Visible = false
	Root.scaled(viralSplash)

	-- Behaviour -------------------------------------------------------------------------
	local phase: Phase = "Idle"
	local ticket: Types.TakeTicket? = nil
	local sweepStart = 0
	local readyAt = 0
	local buffered = false
	local cardToken = 0

	local function setButton(text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	local function showResult(result: Types.PostResult)
		if not result.ok then
			return
		end
		cardToken += 1
		local token = cardToken
		local style = GRADE_STYLE[result.grade or "Miss"] or GRADE_STYLE.Miss
		gradeLabel.Text = if result.auto then "🤖 AUTO POST" else style.Text
		gradeLabel.TextColor3 = if result.auto then Theme.Muted else style.Color
		Util.countUp(viewsLabel, 0, result.views or 0, 0.5, function(v)
			return `👁 {Format.short(v)} views`
		end)
		gainsLabel.Text = `+{Format.short(result.followers or 0)} 👥   +${Format.short(result.cash or 0)}`

		local bonuses = {}
		if result.trending then
			table.insert(bonuses, "🔥 TREND")
		end
		if result.viral then
			table.insert(bonuses, `🛸 VIRAL ×{Game.ViralMultiplier}`)
		end
		if (result.collabers or 0) > 0 then
			table.insert(bonuses, `🤝 COLLAB +{math.floor((result.collabers or 0) * Game.CollabBonusEach * 100)}%`)
		end
		if result.boosted then
			table.insert(bonuses, "⚡ ×2")
		end
		bonusLabel.Text = table.concat(bonuses, "  ")

		card.Visible = true
		Util.pop(card, if result.grade == "Perfect" then 1.2 else 1.08)
		if result.viral then
			viralSplash.Visible = true
			Util.pop(viralSplash, 1.6)
			task.delay(1.2, function()
				viralSplash.Visible = false
			end)
		end
		task.delay(2.2, function()
			if cardToken == token then
				card.Visible = false
			end
		end)
	end

	local function configureZone(t: Types.TakeTicket)
		local zs, ze = t.zoneStart or 0, t.zoneEnd or 0
		zone.Position = UDim2.fromScale(zs, 0)
		zone.Size = UDim2.fromScale(ze - zs, 1)
		local coreWidth = (ze - zs) * Game.PerfectCoreFraction
		core.Position = UDim2.fromScale((zs + ze) / 2 - coreWidth / 2, 0.15)
		core.Size = UDim2.fromScale(coreWidth, 0.7)
		core.Visible = not t.forcePerfect
	end

	local function submit(tap: number?)
		local t = ticket
		if phase ~= "Sweeping" or not t then
			return
		end
		phase = "Submitting"
		setButton("📤", Theme.Disabled)
		local ok, result = pcall(function(): Types.PostResult
			return submitTake:InvokeServer(t.id, tap)
		end)
		bar.Visible = false
		ticket = nil
		readyAt = sweepStart + (t.duration or Game.TakeDuration) + Game.PostCooldown + 0.05
		phase = "Cooldown"
		setButton("🎬 FILM", Theme.Disabled)
		if ok and result then
			showResult(result)
		end
	end

	local function begin()
		if phase ~= "Idle" then
			return
		end
		phase = "Starting"
		setButton("🎬", Theme.Disabled)
		local ok, result = pcall(function(): Types.TakeTicket
			return startTake:InvokeServer()
		end)
		if not ok or not result or not result.ok then
			phase = "Cooldown"
			readyAt = os.clock() + 0.3
			setButton("🎬 FILM", Theme.Disabled)
			return
		end
		ticket = result
		configureZone(result)
		sweepStart = os.clock()
		bar.Visible = true
		phase = "Sweeping"
		setButton("TAP!", Theme.Gold)
		Util.pop(button, 1.1)
	end

	local function press()
		if phase == "Sweeping" then
			local t = ticket
			local duration = if t then t.duration or Game.TakeDuration else Game.TakeDuration
			submit(math.clamp((os.clock() - sweepStart) / duration, 0, 1))
		elseif phase == "Idle" then
			task.spawn(begin)
		elseif phase == "Cooldown" then
			buffered = true
		end
	end

	button.Activated:Connect(press)

	ContextActionService:BindAction("GoViralFilm", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if isMenuOpen() then
			return Enum.ContextActionResult.Pass
		end
		press()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)

	RunService.RenderStepped:Connect(function()
		if phase == "Sweeping" then
			local t = ticket
			local duration = if t then t.duration or Game.TakeDuration else Game.TakeDuration
			local f = (os.clock() - sweepStart) / duration
			marker.Position = UDim2.fromScale(math.min(f, 1), 0.5)
			if f >= 1 then
				task.spawn(submit, nil)
			end
		elseif phase == "Cooldown" and os.clock() >= readyAt then
			phase = "Idle"
			setButton("🎬 FILM", Theme.Accent)
			if buffered then
				buffered = false
				task.spawn(begin)
			end
		end
	end)

	-- Bobbing tutorial pointer until the player has posted a few times.
	task.spawn(function()
		local t = 0
		while true do
			t += task.wait()
			local s = State.current
			pointer.Visible = s ~= nil and s.TotalPosts < Game.TutorialTakes
			if pointer.Visible then
				pointer.Position = UDim2.new(0.5, 40, 1, -40 + math.sin(t * 6) * 8)
			end
		end
	end)

	-- Badge on the button while a Views Boost is running.
	State.observe(function(s)
		badge.Text = if s.BoostEndsAt > State.serverNow() then "⚡×2" else ""
	end)

	State.Posted:Connect(showResult)
end

return FilmButton
