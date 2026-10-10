--!strict
-- Rebrand (prestige). Plain-language keep/lose list and a two-tap confirm, because this
-- resets progress and kids tap fast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Types = require(Shared.Types)
local Actions = require(script.Parent.Parent.Parent.Actions)
local State = require(script.Parent.Parent.Parent.State)
local Panels = require(script.Parent.Parent.Panels)
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local header: TextLabel? = nil
local progressFill: Frame? = nil
local progressText: TextLabel? = nil
local bonusText: TextLabel? = nil
local button: TextButton? = nil
local armed = false

local function update(state: Types.ClientState)
	local requirement = Economy.rebrandRequirement(state.Rebrands)
	local ratio = math.clamp(state.Followers / requirement, 0, 1)
	local nextTitle = Game.titleFor(state.Rebrands + 1)
	if header then
		header.Text = `Become a {nextTitle.Name}!`
		header.TextColor3 = nextTitle.Color
	end
	if progressFill then
		progressFill.Size = UDim2.fromScale(ratio, 1)
	end
	if progressText then
		progressText.Text = `👥 {Format.short(state.Followers)} / {Format.short(requirement)}`
	end
	if bonusText then
		bonusText.Text = `Views bonus: {Format.multiplier(Economy.rebrandMultiplier(state.Rebrands))} → {Format.multiplier(
			Economy.rebrandMultiplier(state.Rebrands + 1)
		)} forever`
	end
	local b = button
	if b then
		local ready = ratio >= 1
		b.Text = if not ready then "NOT YET" elseif armed then "TAP AGAIN TO CONFIRM" else "⭐ REBRAND"
		b.BackgroundColor3 = if not ready then Theme.Disabled elseif armed then Theme.Danger else Theme.Gold
	end
end

local RebrandPanel: Panels.PanelDef = {
	Name = "Rebrand",
	Title = "⭐ REBRAND",
	Build = function(body)
		header = Util.label({ Text = "", Size = UDim2.new(1, 0, 0, 40), Parent = body })
		local bar: Frame = Util.new("Frame", {
			Size = UDim2.new(1, -40, 0, 34),
			Position = UDim2.fromOffset(20, 50),
			BackgroundColor3 = Theme.PanelLight,
			Parent = body,
		})
		Util.corner(bar, Theme.Pill)
		local fill: Frame = Util.new("Frame", { BackgroundColor3 = Theme.Gold, Size = UDim2.fromScale(0, 1), Parent = bar })
		Util.corner(fill, Theme.Pill)
		progressFill = fill
		local text = Util.label({ Text = "", Size = UDim2.fromScale(1, 1), Parent = bar })
		text.ZIndex = 2
		progressText = text
		bonusText = Util.label({
			Text = "",
			Size = UDim2.new(1, -20, 0, 32),
			Position = UDim2.fromOffset(10, 94),
			Color = Theme.Gold,
			Parent = body,
		})
		Util.label({
			Text = "✅ KEEP: niches, lifetime followers, weekly score, titles\n🔄 RESET: cash, gear, current followers",
			Size = UDim2.new(1, -20, 0, 70),
			Position = UDim2.fromOffset(10, 132),
			Font = Theme.BodyFont,
			Color = Theme.Muted,
			Parent = body,
		})
		button = Util.button({
			Text = "",
			Size = UDim2.fromOffset(320, 64),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Color = Theme.Gold,
			Parent = body,
		}, function()
			local state = State.current
			if not state or state.Followers < Economy.rebrandRequirement(state.Rebrands) then
				return
			end
			if not armed then
				armed = true
				update(state)
				task.delay(3, function()
					armed = false
					if State.current then
						update(State.current)
					end
				end)
			else
				armed = false
				Actions.call("Rebrand")
			end
		end)
	end,
	Update = update,
	OnOpen = function()
		armed = false
	end,
	FirstSelectable = function()
		return button
	end,
}

return RebrandPanel
