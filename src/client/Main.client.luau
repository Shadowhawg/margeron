--!strict
-- Client entry point: wire state, mount UI, run the returning-player flow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = script.Parent.UI
local FilmButton = require(UI.FilmButton)
local Hud = require(UI.Hud)
local Panels = require(UI.Panels)
local Toasts = require(UI.Toasts)

-- Make sure the server has created the remotes before anything invokes them.
Net.waitForAll()

State.start()
Panels.mount()
Toasts.mount()

local PanelModules = UI.Screens
for _, name in { "Shop", "Niches", "Deals", "Leaderboard", "Rebrand", "Store" } do
	Panels.register(require(PanelModules:WaitForChild(name)) :: any)
end

Hud.mount(Panels.open, Panels.isOpen)
FilmButton.mount(function()
	return Panels.isOpen() or Toasts.isPopupOpen()
end)

-- Returning players with a reward waiting see the Deals panel once, after any
-- "welcome back" popup. Brand-new players get nothing in the way of their first minute.
local first = State.await()
if first.TotalPosts > 0 and first.Daily.CanClaim then
	task.delay(1.5, function()
		Toasts.afterPopup(function()
			Panels.open("Deals")
		end)
	end)
end
