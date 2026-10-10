--!strict
-- Daily streak card + today's three Brand Deals. Every reward shows its exact cash value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Rewards = require(Shared.Config.Rewards)
local Types = require(Shared.Types)
local Actions = require(script.Parent.Parent.Parent.Actions)
local State = require(script.Parent.Parent.Parent.State)
local Panels = require(script.Parent.Parent.Panels)
local Row = require(script.Parent.Parent.Row)
local Theme = require(script.Parent.Parent.Theme)

local dailyRow: Row.Row? = nil
local dealRows: { Row.Row } = {}

local function update(state: Types.ClientState)
	local daily = dailyRow
	if daily then
		local d = state.Daily
		local bonus = if d.NextDay == Rewards.DailyBoostDay then " + ⚡ Boost" else ""
		daily.Title.Text = `Daily Reward · Day {d.NextDay}/{#Rewards.DailyPosts}`
		daily.Sub.Text = `${Format.short(d.NextReward)}{bonus}`
		if d.CanClaim then
			Row.setButton(daily, "CLAIM!", Theme.Cash, true)
		else
			Row.setButton(daily, `⏰ {Format.clock(d.NextResetAt - State.serverNow())}`, Theme.Disabled, false)
		end
	end

	for index, row in dealRows do
		local deal = state.Deals[index]
		row.Frame.Visible = deal ~= nil
		if deal then
			row.Title.Text = `{deal.Sponsor}: {deal.Text}`
			row.Sub.Text = `{Format.short(deal.Progress)}/{Format.short(deal.Goal)} · reward ${Format.short(deal.Reward)}`
			if deal.Claimed then
				Row.setButton(row, "DONE ✓", Theme.Disabled, false)
			elseif deal.Progress >= deal.Goal then
				Row.setButton(row, "CLAIM!", Theme.Cash, true)
			else
				Row.setButton(row, `{math.floor(deal.Progress / deal.Goal * 100)}%`, Theme.Disabled, false)
			end
		end
	end
end

local DealsPanel: Panels.PanelDef = {
	Name = "Deals",
	Title = "🤝 BRAND DEALS",
	Build = function(body)
		local list = Panels.scrollList(body)
		dailyRow = Row.new(list, 0, function()
			Actions.call("ClaimDaily")
		end)
		if dailyRow then
			dailyRow.Icon.Text = "🎁"
			dailyRow.Frame.BackgroundColor3 = Theme.Accent
		end
		for index = 1, Rewards.DealsPerDay do
			local row = Row.new(list, index, function()
				Actions.call("ClaimDeal", index)
			end)
			row.Icon.Text = "💼"
			table.insert(dealRows, row)
		end
	end,
	Update = update,
	FirstSelectable = function()
		return if dailyRow then dailyRow.Button else nil
	end,
}

return DealsPanel
