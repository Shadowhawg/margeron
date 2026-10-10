-- Small helpers for building UI in code.
local Theme = require(script.Parent.Theme)

local Create = {}

function Create.New(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local New = Create.New

function Create.Corner(radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

function Create.Stroke(color, thickness)
	return New("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.Padding(px)
	local p = UDim.new(0, px)
	return New("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Create.List(padding, direction, align)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Create.Label(text, props)
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Theme.BodyFont,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
	})
	for k, v in pairs(props or {}) do
		label[k] = v
	end
	return label
end

function Create.Button(text, color, onClick, props)
	local button = New("TextButton", {
		Text = text,
		BackgroundColor3 = color or Theme.PanelLight,
		TextColor3 = Theme.Text,
		Font = Theme.BoldFont,
		TextSize = 15,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(110, 32),
	}, { Create.Corner(6), Create.Stroke(Theme.Border) })
	for k, v in pairs(props or {}) do
		button[k] = v
	end
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A ScreenGui that scales to the screen (so the same layout works on phones and monitors).
function Create.Screen(name, displayOrder)
	local gui = New("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
	})
	local scale = New("UIScale", { Parent = gui })
	local function update()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.55, 1.25)
		end
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Create.Clear(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Create
