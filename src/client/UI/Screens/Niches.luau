--!strict
-- Content niches: unlock in order with followers + cash, switch any time. The current
-- trend is flagged so players learn "switch niche to ride the trend".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Niches = require(Shared.Config.Niches)
local Trends = require(Shared.Trends)
local Types = require(Shared.Types)
local Actions = require(script.Parent.Parent.Parent.Actions)
local State = require(script.Parent.Parent.Parent.State)
local Panels = require(script.Parent.Parent.Panels)
local Row = require(script.Parent.Parent.Row)
local Theme = require(script.Parent.Parent.Theme)

local rows: { Row.Row } = {}

local function update(state: Types.ClientState)
	local trend = Trends.current(State.serverNow())
	for index, row in rows do
		local niche = Niches.List[index]
		local owned = table.find(state.Niches, niche.Id) ~= nil
		local previousOwned = index == 1 or table.find(state.Niches, Niches.List[index - 1].Id) ~= nil
		local isTrend = niche.Id == trend
		row.Title.Text = `{niche.Name}{if isTrend then "  🔥 TRENDING" else ""}`
		row.Title.TextColor3 = if isTrend then Theme.Trend else Theme.Text
		if owned then
			row.Sub.Text = `Views {Format.multiplier(niche.Mult)}`
			if state.ActiveNiche == niche.Id then
				Row.setButton(row, "SELECTED", Theme.Cash, false)
				row.Button.BackgroundColor3 = Theme.Cash
			else
				Row.setButton(row, "SELECT", Theme.Followers, true)
			end
		else
			row.Sub.Text = `Views {Format.multiplier(niche.Mult)} · needs 👥 {Format.short(niche.Followers)}`
			local canUnlock = previousOwned and state.Followers >= niche.Followers and state.Cash >= niche.Cost
			Row.setButton(
				row,
				if previousOwned then `UNLOCK ${Format.short(niche.Cost)}` else "🔒",
				Theme.Accent,
				canUnlock
			)
		end
	end
end

local NichePanel: Panels.PanelDef = {
	Name = "Niches",
	Title = "🎯 CONTENT NICHES",
	Build = function(body)
		local list = Panels.scrollList(body)
		for index, niche in Niches.List do
			local row = Row.new(list, index, function()
				local state = State.current
				if state and table.find(state.Niches, niche.Id) then
					Actions.call("SelectNiche", niche.Id)
				else
					Actions.call("UnlockNiche", niche.Id)
				end
			end)
			row.Icon.Text = niche.Icon
			table.insert(rows, row)
		end
	end,
	Update = update,
	FirstSelectable = function()
		return if rows[1] then rows[1].Button else nil
	end,
}

return NichePanel
