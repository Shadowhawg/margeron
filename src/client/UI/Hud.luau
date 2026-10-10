--!strict
-- Always-on HUD: follower/cash counters, trend banner, boost timer, Viral Moment tracker,
-- the left-hand menu (with "!" badges that point at the next thing to do) and the
-- Auto-Film toggle for pass owners.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Gear = require(Shared.Config.Gear)
local Niches = require(Shared.Config.Niches)
local Trends = require(Shared.Trends)
local Types = require(Shared.Types)
local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Hud = {}

local MENU = {
	{ Panel = "Shop", Icon = "📱", Label = "Gear" },
	{ Panel = "Niches", Icon = "🎯", Label = "Niches" },
	{ Panel = "Deals", Icon = "🤝", Label = "Deals" },
	{ Panel = "Leaderboard", Icon = "🏆", Label = "Top" },
	{ Panel = "Rebrand", Icon = "⭐", Label = "Rebrand" },
	{ Panel = "Store", Icon = "💎", Label = "Store" },
}

local function pill(parent: Instance, order: number, color: Color3, width: number): TextLabel
	local frame: Frame = Util.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, 44),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		Parent = parent,
	})
	Util.corner(frame, Theme.Pill)
	Util.stroke(frame, color, 3)
	return Util.label({
		Text = "",
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		XAlign = Enum.TextXAlignment.Left,
		Color = color,
		Parent = frame,
	})
end

local function claimableDeals(state: Types.ClientState): number
	local count = if state.Daily.CanClaim then 1 else 0
	for _, deal in state.Deals do
		if not deal.Claimed and deal.Progress >= deal.Goal then
			count += 1
		end
	end
	return count
end

local function canAffordGear(state: Types.ClientState): boolean
	for _, trackId in Gear.Order do
		local tier = Gear.tier(trackId, (state.Gear[trackId] or 1) + 1)
		if tier and state.Cash >= tier.Cost then
			return true
		end
	end
	return false
end

local function canUnlockNiche(state: Types.ClientState): boolean
	for index, niche in Niches.List do
		local owned = table.find(state.Niches, niche.Id) ~= nil
		if not owned then
			return state.Followers >= niche.Followers
				and state.Cash >= niche.Cost
				and (index == 1 or table.find(state.Niches, Niches.List[index - 1].Id) ~= nil)
		end
	end
	return false
end

function Hud.mount(openPanel: (string) -> (), isMenuOpen: () -> boolean)
	local gui = Root.Gui

	-- Top-left counters ----------------------------------------------------------------
	local stats: Frame = Util.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(240, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Root.scaled(stats)
	local statsLayout = Util.list(stats, 6)
	statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	local followersLabel = pill(stats, 1, Theme.Followers, 230)
	local cashLabel = pill(stats, 2, Theme.Cash, 200)
	local titleLabel = Util.label({
		Text = "",
		Size = UDim2.fromOffset(200, 26),
		XAlign = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		Parent = stats,
	})

	-- Top-centre banners ---------------------------------------------------------------
	local banners: Frame = Util.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 90),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Root.scaled(banners)
	local bannerLayout = Util.list(banners, 4)
	bannerLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	local trendButton = Util.button({
		Text = "",
		Size = UDim2.fromOffset(400, 38),
		Color = Theme.Trend,
		LayoutOrder = 1,
		Parent = banners,
	}, function()
		local state = State.current
		local trend = Trends.current(State.serverNow())
		if state and table.find(state.Niches, trend) and state.ActiveNiche ~= trend then
			Actions.call("SelectNiche", trend)
		else
			openPanel("Niches")
		end
	end)
	trendButton.Name = "TrendBanner"

	local boostLabel = Util.label({
		Text = "",
		Size = UDim2.fromOffset(240, 26),
		Color = Theme.Gold,
		LayoutOrder = 2,
		Parent = banners,
	})
	local viralLabel = Util.label({
		Text = "",
		Size = UDim2.fromOffset(400, 26),
		Color = Theme.Viral,
		LayoutOrder = 3,
		Parent = banners,
	})

	-- Left menu ------------------------------------------------------------------------
	local menu: Frame = Util.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.55, 0),
		Size = UDim2.fromOffset(150, 3 * 78),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Root.scaled(menu)
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(70, 70),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local menuButtons: { [string]: TextButton } = {}
	local menuBadges: { [string]: TextLabel } = {}
	for order, item in MENU do
		local button = Util.button({
			Text = `{item.Icon}\n{item.Label}`,
			Size = UDim2.fromOffset(70, 70),
			Color = Theme.Panel,
			LayoutOrder = order,
			Parent = menu,
		}, function()
			openPanel(item.Panel)
		end)
		button.Name = item.Panel
		local badge = Util.label({
			Text = "!",
			Size = UDim2.fromOffset(26, 26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Parent = button,
		})
		badge.BackgroundColor3 = Theme.Danger
		badge.BackgroundTransparency = 0
		badge.Visible = false
		badge.ZIndex = 3
		Util.corner(badge, Theme.Pill)
		menuButtons[item.Panel] = button
		menuBadges[item.Panel] = badge
	end

	-- Auto-Film toggle (right side, only for pass owners) -------------------------------
	local autoToggle = Util.button({
		Text = "",
		Size = UDim2.fromOffset(150, 46),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Color = Theme.Panel,
		Parent = gui,
	}, function()
		local state = State.current
		if state then
			Actions.call("SetAutoFilm", not state.AutoFilm)
		end
	end)
	autoToggle.Visible = false
	Root.scaled(autoToggle)

	-- Gamepad shortcut: Y opens the gear shop.
	ContextActionService:BindAction("GoViralShop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not isMenuOpen() then
			openPanel("Shop")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonY)

	-- State-driven updates -------------------------------------------------------------
	local shopNudged = false
	local lastFollowers: number? = nil

	State.observe(function(state)
		followersLabel.Text = `👥 {Format.short(state.Followers)}`
		cashLabel.Text = `💵 ${Format.short(state.Cash)}`
		local title = Game.titleFor(state.Rebrands)
		titleLabel.Text = `{if state.Passes.VIP then "👑 " else ""}{title.Name}`
		titleLabel.TextColor3 = title.Color
		if lastFollowers and state.Followers > lastFollowers then
			Util.pop(followersLabel, 1.12)
		end
		lastFollowers = state.Followers

		local gearReady = canAffordGear(state)
		menuBadges.Shop.Visible = gearReady
		menuBadges.Niches.Visible = canUnlockNiche(state)
		local deals = claimableDeals(state)
		menuBadges.Deals.Visible = deals > 0
		menuBadges.Deals.Text = tostring(deals)
		menuBadges.Rebrand.Visible = state.Followers >= Economy.rebrandRequirement(state.Rebrands)

		-- First-upgrade nudge: glow the Shop button (control) or open it once (variant).
		local firstUpgrade = state.Gear.Camera == 1 and state.Gear.Lighting == 1 and state.Gear.Set == 1
		if firstUpgrade and gearReady and not shopNudged then
			shopNudged = true
			if state.Experiments.ShopNudge == 1 then
				openPanel("Shop")
			else
				task.spawn(function()
					local button = menuButtons.Shop
					for _ = 1, 6 do
						button.BackgroundColor3 = Theme.Gold
						Util.pop(button, 1.2)
						task.wait(0.4)
						button.BackgroundColor3 = Theme.Panel
						task.wait(0.4)
					end
				end)
			end
		end

		autoToggle.Visible = state.Passes.AutoFilm == true
		autoToggle.Text = if state.AutoFilm then "🤖 AUTO: ON" else "🤖 AUTO: OFF"
		autoToggle.BackgroundColor3 = if state.AutoFilm then Theme.Cash else Theme.Panel
	end)

	-- Clock-driven updates (trend rotation, timers, viral distance) --------------------
	task.spawn(function()
		while true do
			local now = State.serverNow()
			local state = State.current
			local trendId, endsAt = Trends.current(now)
			local niche = Niches.get(trendId)
			if niche and state then
				local onTrend = state.ActiveNiche == trendId
				local owned = table.find(state.Niches, trendId) ~= nil
				local hint = if onTrend then "✅" elseif owned then "· TAP TO SWITCH" else "· 🔒"
				trendButton.Text = `🔥 TRENDING: {niche.Icon} {niche.Name} {Format.multiplier(state.TrendMultiplier)}  {Format.clock(
					endsAt - now
				)} {hint}`
				trendButton.BackgroundColor3 = if onTrend then Theme.Cash else Theme.Trend
			end

			if state and state.BoostEndsAt > now then
				boostLabel.Text = `⚡ 2x VIEWS  {Format.clock(state.BoostEndsAt - now)}`
				boostLabel.Visible = true
			else
				boostLabel.Visible = false
			end

			local viral = State.viral
			if viral.Active and viral.Position and viral.EndsAt and viral.EndsAt > now then
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local distance = if root and root:IsA("BasePart")
					then (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(viral.Position.X, 0, viral.Position.Z)).Magnitude
					else math.huge
				local inside = distance <= Game.ViralRadius
				viralLabel.Text = if inside
					then `🛸 IN THE VIRAL ZONE! ×{Game.ViralMultiplier} · {Format.clock(viral.EndsAt - now)}`
					else `🛸 {viral.Name or "Viral Moment"}! Run to the beam · {math.floor(distance)}m · {Format.clock(
						viral.EndsAt - now
					)}`
				viralLabel.Visible = true
			else
				viralLabel.Visible = false
			end
			task.wait(0.25)
		end
	end)
end

return Hud
