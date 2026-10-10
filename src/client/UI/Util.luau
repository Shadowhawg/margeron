--!strict
-- Small UI construction helpers. Everything is code-built so the MVP needs zero assets.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

-- Generic constructor: Util.new("Frame", { Size = ..., Parent = ... }).
-- Parent is applied last so the instance replicates/renders once, fully configured.
function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Util.corner(parent: Instance, radius: UDim?): UICorner
	return Util.new("UICorner", { CornerRadius = radius or Theme.Corner, Parent = parent })
end

function Util.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Util.new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Util.textStroke(parent: Instance, thickness: number?): UIStroke
	return Util.new("UIStroke", {
		Color = Theme.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = parent,
	})
end

function Util.padding(parent: Instance, px: number): UIPadding
	local unit = UDim.new(0, px)
	return Util.new("UIPadding", {
		PaddingTop = unit,
		PaddingBottom = unit,
		PaddingLeft = unit,
		PaddingRight = unit,
		Parent = parent,
	})
end

function Util.list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	return Util.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = parent,
	})
end

export type LabelProps = {
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Font: Enum.Font?,
	XAlign: Enum.TextXAlignment?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function Util.label(props: LabelProps): TextLabel
	local label: TextLabel = Util.new("TextLabel", {
		Text = props.Text,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Font = props.Font or Theme.Font,
		TextColor3 = props.Color or Theme.Text,
		TextScaled = true,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Util.new("UITextSizeConstraint", { MaxTextSize = 48, MinTextSize = 8, Parent = label })
	Util.textStroke(label)
	return label
end

export type ButtonProps = {
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	TextColor: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Chunky, tappable button with press feedback. Returns the button; read .Text to update.
function Util.button(props: ButtonProps, onActivated: () -> ()): TextButton
	local button: TextButton = Util.new("TextButton", {
		Text = props.Text,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or Theme.Accent,
		AutoButtonColor = false,
		Font = Theme.Font,
		TextColor3 = props.TextColor or Theme.Text,
		TextScaled = true,
		LayoutOrder = props.LayoutOrder or 0,
		Selectable = true,
		Parent = props.Parent,
	})
	Util.corner(button)
	Util.stroke(button)
	Util.textStroke(button)
	Util.new("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 8, Parent = button })
	Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = button,
	})
	local scale: UIScale = Util.new("UIScale", { Parent = button })

	button.MouseButton1Down:Connect(function()
		Util.tween(scale, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		Util.tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		Util.tween(scale, 0.12, { Scale = 1 })
	end)
	button.Activated:Connect(onActivated)
	return button
end

function Util.tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Quick "boing" on any GuiObject (adds a UIScale if missing).
function Util.pop(instance: GuiObject, amount: number?)
	local existing = instance:FindFirstChild("PopScale")
	local scale: UIScale = if existing and existing:IsA("UIScale")
		then existing
		else Util.new("UIScale", { Name = "PopScale", Parent = instance })
	scale.Scale = amount or 1.25
	Util.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Animates a label's number from `from` to `to`, formatting each frame.
function Util.countUp(label: TextLabel, from: number, to: number, duration: number, format: (number) -> string)
	local value: NumberValue = Util.new("NumberValue", { Value = from })
	value.Changed:Connect(function(v)
		label.Text = format(v)
	end)
	label.Text = format(from)
	local tween = Util.tween(value, duration, { Value = to })
	tween.Completed:Connect(function()
		label.Text = format(to)
		value:Destroy()
	end)
end

return Util
