-- Client entry point.
local StarterGui = game:GetService("StarterGui")

-- We don't use Roblox tools, so hide the backpack bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local Controllers = script.Controllers
local Panels = script.Panels

local modules = {
	require(Controllers.Notifications),
	require(Controllers.Windows),
	require(Controllers.HUD),
	require(Controllers.Effects),
	require(Controllers.Dialogue),
	require(Controllers.Combat),
	require(Controllers.WorldMarkers),
	require(Panels.SkillsPanel),
	require(Panels.QuestsPanel),
	require(Panels.InventoryPanel),
	require(Panels.ShopPanels),
}

for _, module in ipairs(modules) do
	if module.Init then
		module.Init()
	end
end
for _, module in ipairs(modules) do
	if module.Start then
		task.spawn(module.Start)
	end
end
