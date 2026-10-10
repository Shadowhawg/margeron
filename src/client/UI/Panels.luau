--!strict
-- Modal panel framework. Each panel builds its rows once (Build) and updates them in place
-- on every state change (Update), so scroll position and gamepad selection survive the
-- constant stream of state updates. One panel open at a time; ButtonB / X / backdrop closes.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

export type PanelDef = {
	Name: string,
	Title: string,
	Build: (body: Frame) -> (),
	Update: ((state: Types.ClientState) -> ())?,
	OnOpen: (() -> ())?,
	FirstSelectable: (() -> GuiObject?)?,
}

local Panels = {}

Panels.BodySize = Vector2.new(620, 330)

local defs: { [string]: PanelDef } = {}
local bodies: { [string]: Frame } = {}
local openName: string? = nil
local backdrop: TextButton? = nil
local modal: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyHost: Frame? = nil

function Panels.isOpen(): boolean
	return openName ~= nil
end

function Panels.close()
	if not openName then
		return
	end
	openName = nil
	if modal then
		modal.Visible = false
	end
	if backdrop then
		backdrop.Visible = false
	end
	GuiService.SelectedObject = nil
	ContextActionService:UnbindAction("GoViralClosePanel")
end

function Panels.open(name: string)
	local def = defs[name]
	local frame, title, host = modal, titleLabel, bodyHost
	if not def or not frame or not title or not host then
		return
	end
	if openName == name then
		Panels.close()
		return
	end
	for panelName, body in bodies do
		body.Visible = panelName == name
	end
	openName = name
	title.Text = def.Title
	frame.Visible = true
	if backdrop then
		backdrop.Visible = true
	end
	Util.pop(frame, 0.85)
	if def.OnOpen then
		def.OnOpen()
	end
	local current = State.current
	if def.Update and current then
		def.Update(current)
	end
	if def.FirstSelectable then
		GuiService.SelectedObject = def.FirstSelectable()
	end
	ContextActionService:BindAction("GoViralClosePanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Panels.close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)
end

function Panels.register(def: PanelDef)
	local host = bodyHost
	assert(host, "Panels.mount() must run before register()")
	local body: Frame = Util.new("Frame", {
		Name = def.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = host,
	})
	defs[def.Name] = def
	bodies[def.Name] = body
	def.Build(body)
	local update = def.Update
	if update then
		State.observe(update)
	end
end

-- Standard vertical scroll list sized to the panel body.
function Panels.scrollList(parent: Instance, size: UDim2?, position: UDim2?): ScrollingFrame
	local scroll: ScrollingFrame = Util.new("ScrollingFrame", {
		Size = size or UDim2.fromScale(1, 1),
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Muted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	local layout = Util.list(scroll, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	Util.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = scroll })
	return scroll
end

function Panels.mount()
	local gui = Root.Gui

	local dim: TextButton = Util.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 9,
		Selectable = false,
		Parent = gui,
	})
	dim.Activated:Connect(Panels.close)
	backdrop = dim

	local frame: Frame = Util.new("Frame", {
		Name = "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Panels.BodySize.X + 20, Panels.BodySize.Y + 70),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Util.corner(frame)
	Util.stroke(frame, Theme.Stroke, 4)
	Root.scaled(frame)
	modal = frame

	titleLabel = Util.label({
		Text = "",
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(16, 10),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Gold,
		Parent = frame,
	})
	local close = Util.button({
		Text = "✕",
		Size = UDim2.fromOffset(48, 48),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Color = Theme.Danger,
		Parent = frame,
	}, Panels.close)
	close.ZIndex = 11

	bodyHost = Util.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.fromOffset(Panels.BodySize.X, Panels.BodySize.Y),
		BackgroundTransparency = 1,
		Parent = frame,
	})
end

return Panels
