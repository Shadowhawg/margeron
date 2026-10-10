--!strict
-- The standard list row used by every panel: [icon] [title / subtitle] [action button].

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

export type Row = {
	Frame: Frame,
	Icon: TextLabel,
	Title: TextLabel,
	Sub: TextLabel,
	Button: TextButton,
}

local Row = {}

Row.Height = 64

function Row.new(parent: Instance, order: number, onActivated: () -> ()): Row
	local frame: Frame = Util.new("Frame", {
		Name = `Row{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, -16, 0, Row.Height),
		BackgroundColor3 = Theme.PanelLight,
		Parent = parent,
	})
	Util.corner(frame)

	local icon = Util.label({
		Text = "",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(6, 6),
		Parent = frame,
	})
	local title = Util.label({
		Text = "",
		Size = UDim2.new(1, -230, 0, 30),
		Position = UDim2.fromOffset(64, 4),
		XAlign = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local sub = Util.label({
		Text = "",
		Size = UDim2.new(1, -230, 0, 24),
		Position = UDim2.fromOffset(64, 34),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Muted,
		Font = Theme.BodyFont,
		Parent = frame,
	})
	local button = Util.button({
		Text = "",
		Size = UDim2.fromOffset(150, 48),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Parent = frame,
	}, onActivated)

	return { Frame = frame, Icon = icon, Title = title, Sub = sub, Button = button }
end

-- Sets the action button's look in one call.
function Row.setButton(row: Row, text: string, color: Color3, enabled: boolean)
	row.Button.Text = text
	row.Button.BackgroundColor3 = if enabled then color else Theme.Disabled
	row.Button.Active = enabled
	row.Button.AutoButtonColor = false
end

return Row
