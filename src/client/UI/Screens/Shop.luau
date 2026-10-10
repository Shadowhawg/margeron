--!strict
-- Gear shop: three tabs (Camera / Lighting / Set). Tiers must be bought in order; the
-- next tier is the only buyable row, which keeps the choice obvious for young players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Gear = require(Shared.Config.Gear)
local Types = require(Shared.Types)
local Actions = require(script.Parent.Parent.Parent.Actions)
local Panels = require(script.Parent.Parent.Panels)
local Row = require(script.Parent.Parent.Row)
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local rowsByTrack: { [string]: { Row.Row } } = {}
local lists: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local selected = "Camera"

local function showTab(trackId: string)
	selected = trackId
	for id, list in lists do
		list.Visible = id == trackId
	end
	for id, tab in tabs do
		tab.BackgroundColor3 = if id == trackId then Theme.Accent else Theme.PanelLight
	end
end

local function update(state: Types.ClientState)
	for trackId, rows in rowsByTrack do
		local level = state.Gear[trackId] or 1
		local track = Gear.Tracks[trackId]
		for index, row in rows do
			local tier = track.Tiers[index]
			if index <= level then
				Row.setButton(row, if index == level then "EQUIPPED" else "OWNED ✓", Theme.Cash, false)
				row.Button.BackgroundColor3 = if index == level then Theme.Cash else Theme.Disabled
			elseif index == level + 1 then
				local affordable = state.Cash >= tier.Cost
				Row.setButton(row, `BUY ${Format.short(tier.Cost)}`, Theme.Accent, affordable)
			else
				Row.setButton(row, `🔒 ${Format.short(tier.Cost)}`, Theme.Disabled, false)
			end
		end
	end
end

local Shop: Panels.PanelDef = {
	Name = "Shop",
	Title = "📱 GEAR SHOP",
	Build = function(body)
		local tabBar: Frame = Util.new("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			Parent = body,
		})
		Util.list(tabBar, 8, true)
		for order, trackId in Gear.Order do
			local track = Gear.Tracks[trackId]
			tabs[trackId] = Util.button({
				Text = `{track.Icon} {track.Name}`,
				Size = UDim2.fromOffset(190, 40),
				LayoutOrder = order,
				Color = Theme.PanelLight,
				Parent = tabBar,
			}, function()
				showTab(trackId)
			end)

			local list = Panels.scrollList(body, UDim2.new(1, 0, 1, -52), UDim2.fromOffset(0, 52))
			lists[trackId] = list
			local rows = {}
			for index, tier in track.Tiers do
				local row = Row.new(list, index, function()
					Actions.call("BuyGear", trackId)
				end)
				row.Icon.Text = tier.Icon
				row.Title.Text = tier.Name
				row.Sub.Text = `Views {Format.multiplier(tier.Mult)}`
				table.insert(rows, row)
			end
			rowsByTrack[trackId] = rows
		end
		showTab(selected)
	end,
	Update = update,
	FirstSelectable = function()
		return tabs[selected]
	end,
}

return Shop
