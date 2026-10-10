--!strict
-- Toasts (short messages, top-centre) and the "Welcome back" offline-earnings popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Types = require(Shared.Types)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Toasts = {}

local MAX_TOASTS = 3

local stack: Frame? = nil
local popup: Frame? = nil
local popupBody: TextLabel? = nil
local popupClosed: (() -> ())? = nil

function Toasts.show(text: string, color: Color3?, duration: number?)
	local container = stack
	if not container then
		return
	end
	local count = 0
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count >= MAX_TOASTS then
		return
	end
	local toast = Util.label({
		Text = text,
		Size = UDim2.fromOffset(460, 34),
		Color = color or Theme.Text,
		Parent = container,
	})
	toast.BackgroundTransparency = 0.25
	toast.BackgroundColor3 = Theme.Background
	Util.corner(toast, Theme.Pill)
	Util.pop(toast, 1.15)
	task.delay(duration or 3, function()
		Util.tween(toast, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		task.wait(0.3)
		toast:Destroy()
	end)
end

function Toasts.error(text: string?)
	Toasts.show(`❌ {text or "Something went wrong"}`, Theme.Danger)
end

function Toasts.isPopupOpen(): boolean
	return popup ~= nil and popup.Visible
end

-- Runs `callback` once the popup is closed (immediately if none is open).
function Toasts.afterPopup(callback: () -> ())
	if Toasts.isPopupOpen() then
		popupClosed = callback
	else
		callback()
	end
end

local function showOffline(payload: Types.NotifyPayload)
	local frame, body = popup, popupBody
	if not frame or not body then
		return
	end
	body.Text = `{payload.Text}\n\n👥 +{Format.short(payload.Followers or 0)} followers\n💵 +${Format.short(payload.Cash or 0)}`
	frame.Visible = true
	Util.pop(frame, 0.8)
end

function Toasts.mount()
	local gui = Root.Gui

	local container: Frame = Util.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(460, 130),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})
	Util.list(container, 4)
	Root.scaled(container)
	stack = container

	local frame: Frame = Util.new("Frame", {
		Name = "OfflinePopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 260),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	Util.corner(frame)
	Util.stroke(frame, Theme.Gold, 4)
	Root.scaled(frame)
	Util.label({
		Text = "👋 WELCOME BACK!",
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 10),
		Color = Theme.Gold,
		Parent = frame,
	})
	local body = Util.label({
		Text = "",
		Size = UDim2.new(1, -30, 0, 130),
		Position = UDim2.fromOffset(15, 58),
		Font = Theme.BodyFont,
		Parent = frame,
	})
	popupBody = body
	Util.button({
		Text = "COLLECT!",
		Size = UDim2.fromOffset(200, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Color = Theme.Cash,
		Parent = frame,
	}, function()
		frame.Visible = false
		local callback = popupClosed
		popupClosed = nil
		if callback then
			callback()
		end
	end)
	popup = frame

	State.Notified:Connect(function(payload)
		if payload.Kind == "Offline" then
			showOffline(payload)
		elseif payload.Kind == "Milestone" then
			Toasts.show(payload.Text, Theme.Gold, 4)
		elseif payload.Kind == "Error" then
			Toasts.error(payload.Text)
		else
			Toasts.show(payload.Text)
		end
	end)
end

return Toasts
