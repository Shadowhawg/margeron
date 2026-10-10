--!strict
-- Weekly and all-time follower leaderboards (refreshed by the server every ~2 minutes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Types = require(Shared.Types)
local State = require(script.Parent.Parent.Parent.State)
local Panels = require(script.Parent.Parent.Panels)
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local MEDALS = { "🥇", "🥈", "🥉" }

local lists: { [string]: { TextLabel } } = {}
local frames: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local resetLabel: TextLabel? = nil
local selected = "Weekly"

local function showTab(name: string)
	selected = name
	for id, frame in frames do
		frame.Visible = id == name
	end
	for id, tab in tabs do
		tab.BackgroundColor3 = if id == name then Theme.Accent else Theme.PanelLight
	end
end

local function render(payload: Types.LeaderboardPayload)
	local me = Players.LocalPlayer.UserId
	for name, labels in lists do
		local entries = if name == "Weekly" then payload.Weekly else payload.AllTime
		for i, label in labels do
			local entry = entries[i]
			label.Visible = entry ~= nil
			if entry then
				local medal = MEDALS[entry.Rank] or `{entry.Rank}.`
				label.Text = `{medal}  {entry.Name}   👥 {Format.short(entry.Value)}`
				label.TextColor3 = if entry.UserId == me then Theme.Gold else Theme.Text
			end
		end
	end
	local reset = resetLabel
	if reset then
		reset.Text = `Weekly board resets in {Format.clock(payload.WeekEndsAt - State.serverNow())}`
	end
end

local LeaderboardPanel: Panels.PanelDef = {
	Name = "Leaderboard",
	Title = "🏆 TOP CREATORS",
	Build = function(body)
		local tabBar: Frame = Util.new("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			Parent = body,
		})
		Util.list(tabBar, 8, true)
		for order, name in { "Weekly", "AllTime" } do
			tabs[name] = Util.button({
				Text = if name == "Weekly" then "🔥 This Week" else "🏆 All Time",
				Size = UDim2.fromOffset(200, 40),
				LayoutOrder = order,
				Color = Theme.PanelLight,
				Parent = tabBar,
			}, function()
				showTab(name)
			end)
			local scroll = Panels.scrollList(body, UDim2.new(1, 0, 1, -80), UDim2.fromOffset(0, 50))
			frames[name] = scroll
			local labels = {}
			for i = 1, Game.LeaderboardSize do
				local label = Util.label({
					Text = "",
					Size = UDim2.new(1, -20, 0, 30),
					XAlign = Enum.TextXAlignment.Left,
					LayoutOrder = i,
					Parent = scroll,
				})
				label.Visible = false
				table.insert(labels, label)
			end
			lists[name] = labels
		end
		resetLabel = Util.label({
			Text = "",
			Size = UDim2.new(1, 0, 0, 24),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Color = Theme.Muted,
			Font = Theme.BodyFont,
			Parent = body,
		})
		showTab(selected)
		if State.leaderboard then
			render(State.leaderboard)
		end
		State.LeaderboardChanged:Connect(render)
	end,
	OnOpen = function()
		if State.leaderboard then
			render(State.leaderboard)
		end
	end,
	FirstSelectable = function()
		return tabs[selected]
	end,
}

return LeaderboardPanel
