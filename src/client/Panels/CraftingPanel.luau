-- Crafting window for every station: Forge (smelt/forge, temper, infuse), Alchemy Table (mixing),
-- Cooking Pot and Workbench (recipes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crafting = require(Shared.Config.Crafting)
local Items = require(Shared.Config.Items)
local CraftingRules = require(Shared.CraftingRules)
local Stats = require(Shared.Stats)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local New = Create.New

local CraftingPanel = {}

local tab = "Recipes"
local lastStation = nil
local mix = {} -- selected alchemy ingredients
local infuseWeapon = nil

local function scroll(parent, position, size)
	return New("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = parent,
	}, { Create.Corner(8), Create.Padding(8), Create.List(6) })
end

local function inputsText(data, inputs)
	local parts = {}
	for id, need in pairs(inputs) do
		if id == "Gold" then
			table.insert(parts, need .. " gold")
		else
			local have = data.Materials[id] or 0
			local name = Items.Materials[id] and Items.Materials[id].Name or id
			table.insert(parts, name .. " " .. have .. "/" .. need)
		end
	end
	table.sort(parts)
	return table.concat(parts, "   ·   ")
end

local function row(parent, order, title, subtitle, buttonText, enabled, onClick, titleColor)
	local frame = New("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Background,
		Parent = parent,
	}, { Create.Corner(6), Create.Padding(8) })
	Create.Label(title, {
		Font = Theme.BoldFont,
		TextColor3 = titleColor or Theme.Text,
		Size = UDim2.new(1, -140, 0, 20),
		Parent = frame,
	})
	Create.Label(subtitle, {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -140, 0, 20),
		TextSize = 12,
		TextColor3 = Theme.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	local button = Create.Button(buttonText, enabled and Theme.Good or Theme.PanelLight, enabled and onClick or nil, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(130, 34),
		TextSize = 13,
		TextWrapped = true,
		Parent = frame,
	})
	button.AutoButtonColor = enabled
end

local function header(content, data, station)
	local craft = data.Crafting
	local needed = Crafting.XPToNext(craft.Level)
	local boost = (data.CraftBoostUntil or 0) > Stats.Now()
	Create.Label(
		Crafting.StationNames[station]
			.. "     Crafting Lv "
			.. craft.Level
			.. "  ("
			.. craft.XP
			.. "/"
			.. needed
			.. " XP)"
			.. (boost and "     Artisan's Focus active" or ""),
		{
			Font = Theme.BoldFont,
			TextColor3 = boost and Theme.Gold or Theme.Accent,
			Size = UDim2.new(1, 0, 0, 22),
			Parent = content,
		}
	)
end

local function tabs(content, names)
	local bar = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = content,
	}, {
		Create.List(6, Enum.FillDirection.Horizontal),
	})
	for i, name in ipairs(names) do
		Create.Button(name, tab == name and Theme.Border or Theme.PanelLight, function()
			tab = name
			Windows.Render()
		end, { LayoutOrder = i, Size = UDim2.fromOffset(150, 30), Parent = bar })
	end
end

local function renderRecipes(content, data, station, top)
	local list = scroll(content, UDim2.fromOffset(0, top), UDim2.new(1, 0, 1, -top))
	local order = 0
	for _, recipe in ipairs(Crafting.Recipes) do
		if recipe.Station == station then
			order += 1
			local levelOk = data.Crafting.Level >= recipe.Level
			local hasAll = CraftingRules.HasInputs(data, recipe.Inputs)
			local owned = (recipe.Output.Weapon and data.Weapons[recipe.Output.Weapon])
				or (recipe.Output.Cosmetic and data.Cosmetics[recipe.Output.Cosmetic])
			local subtitle = inputsText(data, recipe.Inputs)
			if recipe.Output.Food then
				local info = CraftingRules.Describe("F:" .. recipe.Output.Food)
				subtitle = CraftingRules.EffectSummary(info) .. "   |   " .. subtitle
			elseif recipe.Output.Weapon then
				local w = Items.Weapons[recipe.Output.Weapon]
				subtitle = w.Type .. " " .. w.Damage .. " dmg (Lv " .. w.LevelReq .. ")   |   " .. subtitle
			end
			local label = owned and "Owned" or (not levelOk and ("Craft Lv " .. recipe.Level) or "Craft")
			row(list, order, recipe.Name, subtitle, label, levelOk and hasAll and not owned, function()
				Net.Request("Craft", recipe.Id)
			end)
		end
	end
end

local function renderTemper(content, data, top)
	local list = scroll(content, UDim2.fromOffset(0, top), UDim2.new(1, 0, 1, -top))
	local order = 0
	for weaponId in pairs(data.Weapons) do
		local w = Items.Weapons[weaponId]
		if w then
			order += 1
			local level = data.Crafting.Temper[weaponId] or 0
			local maxed = level >= Crafting.Temper.MaxLevel
			local subtitle = "Maxed out"
			local canAfford = false
			if not maxed then
				local cost = Crafting.Temper.Cost(level + 1)
				subtitle = "+"
					.. math.floor(Crafting.Temper.DamagePerLevel * 100)
					.. "% damage   |   "
					.. inputsText(data, cost)
				canAfford = CraftingRules.HasInputs(data, cost)
			end
			row(
				list,
				order,
				w.Name .. "  +" .. level,
				subtitle,
				maxed and "Max" or ("Temper to +" .. (level + 1)),
				not maxed and canAfford,
				function()
					Net.Request("Temper", weaponId)
				end
			)
		end
	end
end

local function renderInfuse(content, data, top)
	local owned = {}
	for weaponId in pairs(data.Weapons) do
		if Items.Weapons[weaponId] then
			table.insert(owned, weaponId)
		end
	end
	table.sort(owned)
	if not infuseWeapon or not data.Weapons[infuseWeapon] then
		infuseWeapon = data.EquippedWeapon
	end
	local picker = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = content,
	}, {
		Create.List(8, Enum.FillDirection.Horizontal),
	})
	local index = table.find(owned, infuseWeapon) or 1
	Create.Button("<", Theme.PanelLight, function()
		infuseWeapon = owned[(index - 2) % #owned + 1]
		Windows.Render()
	end, { Size = UDim2.fromOffset(34, 32), Parent = picker })
	local current = data.Crafting.Infusions[infuseWeapon]
	Create.Label(
		Items.Weapons[infuseWeapon].Name
			.. (current and ("   (" .. Crafting.Infusions[current].Name .. ")") or "   (no infusion)"),
		{
			Size = UDim2.fromOffset(420, 32),
			Font = Theme.BoldFont,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = picker,
		}
	)
	Create.Button(">", Theme.PanelLight, function()
		infuseWeapon = owned[index % #owned + 1]
		Windows.Render()
	end, { Size = UDim2.fromOffset(34, 32), Parent = picker })

	local list = scroll(content, UDim2.fromOffset(0, top + 40), UDim2.new(1, 0, 1, -(top + 40)))
	local order = 0
	for infusionId, infusion in pairs(Crafting.Infusions) do
		order += 1
		local levelOk = data.Crafting.Level >= infusion.Level
		local has = CraftingRules.HasInputs(data, infusion.Inputs)
		local same = current == infusionId
		row(
			list,
			order,
			infusion.Name,
			infusion.Description .. "   |   " .. inputsText(data, infusion.Inputs),
			same and "Applied" or (levelOk and "Infuse" or ("Craft Lv " .. infusion.Level)),
			levelOk and has and not same,
			function()
				Net.Request("Infuse", infuseWeapon, infusionId)
			end,
			infusion.Color
		)
	end
end

local function knownEffectsText(data, ingredientId)
	local def = Items.Materials[ingredientId]
	local known = data.Crafting.Known[ingredientId] or {}
	local parts = {}
	for _, effect in ipairs(def.Effects) do
		table.insert(parts, known[effect] and Crafting.Effects[effect].Name or "???")
	end
	return table.concat(parts, ", ")
end

local function renderAlchemy(content, data, top)
	-- Drop selections you no longer have.
	for i = #mix, 1, -1 do
		if (data.Materials[mix[i]] or 0) < 1 then
			table.remove(mix, i)
		end
	end

	local list = scroll(content, UDim2.fromOffset(0, top), UDim2.new(0.55, -6, 1, -top))
	local order = 0
	local ids = {}
	for id, count in pairs(data.Materials) do
		if count > 0 and CraftingRules.IsIngredient(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		order += 1
		local selected = table.find(mix, id) ~= nil
		local frame = New("TextButton", {
			Text = "",
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = selected and Color3.fromRGB(60, 50, 30) or Theme.Background,
			AutoButtonColor = true,
			Parent = list,
		}, { Create.Corner(6), Create.Padding(6), Create.Stroke(selected and Theme.Gold or Theme.Border) })
		Create.Label(
			Items.Materials[id].Name .. "  x" .. data.Materials[id],
			{ Font = Theme.BoldFont, Size = UDim2.new(1, 0, 0, 18), Parent = frame }
		)
		Create.Label(knownEffectsText(data, id), {
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 12,
			TextColor3 = Theme.Muted,
			Parent = frame,
		})
		frame.Activated:Connect(function()
			local at = table.find(mix, id)
			if at then
				table.remove(mix, at)
			elseif #mix < 3 then
				table.insert(mix, id)
			end
			Windows.Render()
		end)
	end
	if order == 0 then
		Create.Label("You have no alchemical ingredients. Gather herbs in the wild, or take parts from monsters.", {
			TextColor3 = Theme.Muted,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		})
	end

	local side = New("Frame", {
		Position = UDim2.new(0.55, 6, 0, top),
		Size = UDim2.new(0.45, -6, 1, -top),
		BackgroundColor3 = Theme.Panel,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(12), Create.List(8) })
	Create.Label("Mixture", {
		Font = Theme.TitleFont,
		TextSize = 26,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = side,
	})
	for i = 1, 3 do
		Create.Label((mix[i] and Items.Materials[mix[i]].Name) or "- empty -", {
			LayoutOrder = i,
			TextColor3 = mix[i] and Theme.Text or Theme.Muted,
			Parent = side,
		})
	end

	-- Predict only what the player already knows.
	local predicted = {}
	if #mix >= 2 then
		for _, effect in ipairs(CraftingRules.SharedEffects(mix)) do
			local knownCount = 0
			for _, id in ipairs(mix) do
				local known = data.Crafting.Known[id]
				if known and known[effect] then
					knownCount += 1
				end
			end
			if knownCount >= 2 then
				table.insert(predicted, Crafting.Effects[effect].Name)
			end
		end
	end
	local tier = Crafting.PotencyTier(data.Crafting.Level, data.Passes.MasterArtisan)
	Create.Label(
		#mix < 2 and "Pick two or three ingredients."
			or (#predicted > 0 and ("Known result: " .. table.concat(predicted, ", ")) or "Result unknown. Experiment!"),
		{
			LayoutOrder = 10,
			TextSize = 14,
			TextColor3 = #predicted > 0 and Theme.Good or Theme.Muted,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = side,
		}
	)
	Create.Label(
		"Potency tier " .. tier .. " (rises with crafting level)",
		{ LayoutOrder = 11, TextSize = 12, TextColor3 = Theme.Muted, Parent = side }
	)
	local buttons = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 12, Parent = side },
		{
			Create.List(6, Enum.FillDirection.Horizontal),
		}
	)
	Create.Button("Brew", #mix >= 2 and Theme.Good or Theme.PanelLight, #mix >= 2 and function()
		Net.Request("Brew", mix)
	end or nil, { Size = UDim2.fromOffset(100, 34), Parent = buttons })
	Create.Button("Taste", #mix >= 1 and Theme.PanelLight or Theme.Background, #mix >= 1 and function()
		Net.Request("Taste", mix[1])
	end or nil, { Size = UDim2.fromOffset(80, 34), Parent = buttons })
	Create.Button("Clear", Theme.PanelLight, function()
		table.clear(mix)
		Windows.Render()
	end, { Size = UDim2.fromOffset(80, 34), Parent = buttons })
	Create.Label(
		"Ingredients that share an effect make a potion. Tasting reveals one effect but uses the ingredient up.",
		{
			LayoutOrder = 13,
			TextSize = 12,
			TextColor3 = Theme.Muted,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = side,
		}
	)
end

local function render(content, args)
	local data = State.Data
	local station = args and args.Station or "Workbench"
	if station ~= lastStation then
		lastStation = station
		tab = station == "Forge" and "Smelt & Forge" or "Recipes"
		table.clear(mix)
	end
	header(content, data, station)
	if station == "Forge" then
		tabs(content, { "Smelt & Forge", "Temper", "Infuse" })
		if tab == "Temper" then
			renderTemper(content, data, 64)
		elseif tab == "Infuse" then
			renderInfuse(content, data, 64)
		else
			renderRecipes(content, data, "Forge", 64)
		end
	elseif station == "AlchemyTable" then
		renderAlchemy(content, data, 30)
	else
		renderRecipes(content, data, station, 30)
	end
end

function CraftingPanel.Init()
	Windows.Register("Crafting", "Crafting", render)
end

return CraftingPanel
