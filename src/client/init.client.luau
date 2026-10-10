-- Client entry point.
local StarterGui = game:GetService("StarterGui")

-- We don't use Roblox tools, so hide the backpack bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local Controllers = script.Controllers
local Panels = script.Panels

local modules = {
	require(Controllers.Loading),
	require(Controllers.Notifications),
	require(Controllers.Windows),
	require(Controllers.Cinematic),
	require(Controllers.DayNight),
	require(Controllers.HUD),
	require(Controllers.Effects),
	require(Controllers.Dialogue),
	require(Controllers.Combat),
	require(Controllers.WorldMarkers),
	require(Controllers.Music),
	require(Panels.Creator),
	require(Controllers.Intro),
	require(Panels.SkillsPanel),
	require(Panels.QuestsPanel),
	require(Panels.InventoryPanel),
	require(Panels.ShopPanels),
	require(Panels.CraftingPanel),
	require(Panels.EstatePanels),
	require(Panels.GovernmentPanel),
	require(Panels.MapPanel),
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
