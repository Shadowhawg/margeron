--!strict
-- The single ScreenGui plus device-aware scaling. HUD clusters are authored in offsets
-- at Theme.DesignWidth x DesignHeight and each gets a UIScale tied to the viewport, so a
-- 150px FILM button is ~115pt on a landscape phone and full size on a monitor.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local Root = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "GoViralUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

Root.Gui = gui

local scales: { UIScale } = {}

function Root.currentScale(): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(
		math.min(viewport.X / Theme.DesignWidth, viewport.Y / Theme.DesignHeight),
		Theme.MinScale,
		Theme.MaxScale
	)
end

function Root.isPortrait(): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y > camera.ViewportSize.X
end

-- Attach to any offset-authored cluster.
function Root.scaled(object: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Scale = Root.currentScale()
	scale.Parent = object
	table.insert(scales, scale)
end

local function refresh()
	local value = Root.currentScale()
	for _, scale in scales do
		scale.Scale = value
	end
end

local viewportConnection: RBXScriptConnection? = nil
local function watchCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

return Root
