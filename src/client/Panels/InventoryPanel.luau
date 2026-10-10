-- Inventory: weapons, cosmetics, materials and a character sheet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local New = Create.New

local InventoryPanel = {}

local tab = "Weapons"

local function percent(x)
	return math.floor(x * 100 + 0.5) .. "%"
end

local function weaponStats(def)
	local text = def.Type .. "  ·  " .. def.Damage .. " dmg  ·  " .. def.Cooldown .. "s"
	if def.CritBonus then
		text ..= "  ·  +" .. percent(def.CritBonus) .. " crit"
	end
	return text
end

-- Shared row layout: title, subtitle and an action button on the right.
function InventoryPanel.Row(parent, order, title, subtitle, buttonText, buttonColor, onClick, titleColor)
	local row = New("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Theme.Background,
		Parent = parent,
	}, { Create.Corner(6), Create.Padding(8) })
	Create.Label(title, {
		Font = Theme.BoldFont,
		TextColor3 = titleColor or Theme.Text,
		Size = UDim2.new(1, -130, 0, 20),
		Parent = row,
	})
	Create.Label(subtitle or "", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -130, 0, 18),
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	if buttonText then
		local button = Create.Button(buttonText, buttonColor, onClick, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(120, 34),
			TextSize = 13,
			Parent = row,
		})
		button.AutoButtonColor = onClick ~= nil
	end
	return row
end

local function render(content)
	local data = State.Data
	local stats = State.Stats

	local tabs = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.62, 0, 0, 34),
		Parent = content,
	}, { Create.List(6, Enum.FillDirection.Horizontal) })
	for i, name in ipairs({ "Weapons", "Cosmetics", "Materials" }) do
		Create.Button(name, tab == name and Theme.Border or Theme.PanelLight, function()
			tab = name
			Windows.Render()
		end, { LayoutOrder = i, Parent = tabs })
	end

	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0.62, 0, 1, -42),
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(8), Create.List(6) })

	local order = 0
	if tab == "Weapons" then
		for weaponId, def in pairs(Items.Weapons) do
			if data.Weapons[weaponId] then
				order += 1
				local equipped = data.EquippedWeapon == weaponId
				local canEquip = data.Level >= (def.LevelReq or 1)
				InventoryPanel.Row(list, order, def.Name, weaponStats(def),
					equipped and "Equipped" or (canEquip and "Equip" or "Lv " .. def.LevelReq),
					equipped and Theme.Border or (canEquip and Theme.Good or Theme.PanelLight),
					(not equipped and canEquip) and function()
						Net.Request("EquipWeapon", weaponId)
					end or nil,
					def.Premium and Theme.Robux or nil)
			end
		end
	elseif tab == "Cosmetics" then
		for cosmeticId, def in pairs(Items.Cosmetics) do
			if data.Cosmetics[cosmeticId] then
				order += 1
				local equipped = data.Equipped[def.Slot] == cosmeticId
				InventoryPanel.Row(list, order, def.Name, def.Slot,
					equipped and "Unequip" or "Equip",
					equipped and Theme.Border or Theme.Good,
					function()
						Net.Request("EquipCosmetic", cosmeticId)
					end)
			end
		end
		if order == 0 then
			Create.Label("No cosmetics yet. Earn titles from quests and bounties, or visit the Store (B).", {
				TextColor3 = Theme.Muted,
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = list,
			})
		end
	else
		for materialId, count in pairs(data.Materials) do
			local def = Items.Materials[materialId]
			if def then
				order += 1
				InventoryPanel.Row(list, order, def.Name .. "  x" .. count, "Used for quests and bounties")
			end
		end
		if order == 0 then
			Create.Label("No materials. Enemies drop them when defeated.", { TextColor3 = Theme.Muted, Parent = list })
		end
	end

	-- Character sheet
	local sheet = New("Frame", {
		Position = UDim2.new(0.62, 12, 0, 0),
		Size = UDim2.new(0.38, -12, 1, 0),
		BackgroundColor3 = Theme.Panel,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(14), Create.List(4) })
	Create.Label(game:GetService("Players").LocalPlayer.DisplayName, {
		Font = Theme.TitleFont,
		TextSize = 28,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = sheet,
	})
	local lines = {
		{ "Level", data.Level },
		{ "Max Health", stats.MaxHealth },
		{ "Weapon Damage", percent(stats.PhysicalDamage) },
		{ "Spell Power", percent(stats.SpellPower) },
		{ "Crit Chance", percent(stats.CritChance) },
		{ "Crit Damage", percent(stats.CritDamage) },
		{ "Lifesteal", percent(stats.Lifesteal) },
		{ "Damage Reduction", percent(stats.DamageReduction) },
		{ "Move Speed", stats.WalkSpeed },
		{ "Cooldown Reduction", percent(stats.CooldownReduction) },
		{ "Renown", data.Renown },
		{ "Enemies Slain", data.Stats.Kills },
	}
	for i, line in ipairs(lines) do
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i + 1, Parent = sheet })
		Create.Label(line[1], { TextColor3 = Theme.Muted, TextSize = 14, Parent = row })
		Create.Label(tostring(line[2]), { TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.BoldFont, TextSize = 14, Parent = row })
	end
end

function InventoryPanel.Init()
	Windows.Register("Inventory", "Inventory", render)
end

return InventoryPanel
