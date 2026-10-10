-- Property-related windows: Estate (homes), Stable (horses & livestock), Seeds, Plant, Trader.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Property = require(Shared.Config.Property)
local Items = require(Shared.Config.Items)
local CraftingRules = require(Shared.CraftingRules)
local Util = require(Shared.Util)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local InventoryPanel = require(script.Parent.InventoryPanel)
local New = Create.New

local EstatePanels = {}

local function scroll(parent, top)
	return New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, top or 0),
		Size = UDim2.new(1, 0, 1, -(top or 0)),
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = parent,
	}, { Create.Corner(8), Create.Padding(8), Create.List(6) })
end

local function goldLine(content, data, extra)
	Create.Label("Your gold: " .. Util.FormatNumber(data.Gold) .. (extra or ""), {
		Font = Theme.BoldFont,
		TextColor3 = Theme.Gold,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})
end

local function section(list, order, text)
	Create.Label(text, {
		Font = Theme.TitleFont,
		TextSize = 24,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Parent = list,
	})
end

-- Estate ----------------------------------------------------------------------------------

local function renderEstate(content)
	local data = State.Data
	local current = Property.Homes[data.Property.Home]
	goldLine(content, data, current and ("     Your home: " .. current.Name) or "     You don't own a home yet")
	local list = scroll(content, 30)
	local currentIndex = table.find(Property.Homes.Order, data.Property.Home) or 0
	for i, homeId in ipairs(Property.Homes.Order) do
		local home = Property.Homes[homeId]
		local credit = currentIndex > 0 and math.floor(Property.Homes[data.Property.Home].Price * Property.TradeInRate)
			or 0
		local price = home.Price - credit
		local owned = currentIndex >= i
		local levelOk = data.Level >= home.LevelReq
		local subtitle = home.Fields
			.. " fields · "
			.. home.AnimalSlots
			.. " animals · stations: "
			.. table.concat(home.Stations, ", ")
		local label
		if owned then
			label = currentIndex == i and "Your home" or "Owned"
		elseif not levelOk then
			label = "Requires Lv " .. home.LevelReq
		else
			label = Util.FormatNumber(price) .. "g + tax"
		end
		InventoryPanel.Row(
			list,
			i,
			home.Name .. (credit > 0 and not owned and ("  (trade-in -" .. Util.FormatNumber(credit) .. ")") or ""),
			subtitle,
			label,
			(not owned and levelOk) and Theme.Good or Theme.PanelLight,
			(not owned and levelOk) and function()
				Net.Request("BuyHome", homeId)
			end or nil
		)
	end
	section(list, 10, "")
	Create.Label(
		"Your home is built on a free plot in Greenmeadow whenever you're in a server. Grow crops in your fields, raise animals in your pen, and craft at your own stations. Travel home from the map (M).",
		{
			LayoutOrder = 11,
			TextColor3 = Theme.Muted,
			TextSize = 13,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		}
	)
end

-- Stable ----------------------------------------------------------------------------------

local function renderStable(content)
	local data = State.Data
	local home = Property.Homes[data.Property.Home]
	goldLine(
		content,
		data,
		home and ("     Pen: " .. #data.Property.Animals .. "/" .. home.AnimalSlots) or "     (Livestock needs a home)"
	)
	local list = scroll(content, 30)
	section(list, 0, "Horses  (press H to ride)")
	for i, horseId in ipairs(Property.Horses.Order) do
		local horse = Property.Horses[horseId]
		local owned = data.Property.Horses[horseId]
		local active = data.Property.ActiveHorse == horseId
		local label, color, action
		if owned then
			label = active and "Riding this one" or "Choose"
			color = active and Theme.Border or Theme.Good
			action = not active and function()
				Net.Request("SetHorse", horseId)
			end or nil
		elseif horse.Premium then
			label, color = "In the Store (B)", Theme.Robux
		elseif data.Level < (horse.LevelReq or 1) then
			label, color = "Requires Lv " .. horse.LevelReq, Theme.PanelLight
		else
			label, color = Util.FormatNumber(horse.Price) .. "g + tax", Theme.Good
			action = function()
				Net.Request("BuyHorse", horseId)
			end
		end
		InventoryPanel.Row(list, i, horse.Name, "Speed " .. horse.Speed, label, color, action)
	end
	section(list, 20, "Livestock")
	for i, animalId in ipairs(Property.Animals.Order) do
		local animal = Property.Animals[animalId]
		local produces = Items.Materials[animal.Produces].Name
		InventoryPanel.Row(
			list,
			20 + i,
			animal.Name,
			"Produces " .. produces .. " every " .. math.floor(animal.Interval / 60) .. " min",
			home and (animal.Price .. "g + tax") or "Needs a home",
			home and Theme.Good or Theme.PanelLight,
			home and function()
				Net.Request("BuyAnimal", animalId)
			end or nil
		)
	end
end

-- Seeds -----------------------------------------------------------------------------------

local function renderSeeds(content)
	local data = State.Data
	goldLine(content, data)
	local list = scroll(content, 30)
	for i, cropId in ipairs(Property.Crops.Order) do
		local crop = Property.Crops[cropId]
		local have = data.Materials[crop.Seed] or 0
		local row = InventoryPanel.Row(
			list,
			i,
			crop.Name .. " seeds  (you have " .. have .. ")",
			"Grows in "
				.. math.floor(crop.GrowTime / 60)
				.. " min · yields "
				.. crop.Yield[1]
				.. "-"
				.. crop.Yield[2]
				.. " · "
				.. crop.SeedPrice
				.. "g each"
		)
		local levelOk = data.Level >= (crop.LevelReq or 1)
		local buttons = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(170, 34),
			BackgroundTransparency = 1,
			Parent = row,
		}, { Create.List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
		if not levelOk then
			Create.Label(
				"Requires Lv " .. crop.LevelReq,
				{ Size = UDim2.fromOffset(160, 34), TextColor3 = Theme.Muted, Parent = buttons }
			)
		else
			for _, n in ipairs({ 1, 5, 10 }) do
				Create.Button("x" .. n, Theme.Good, function()
					Net.Request("BuySeeds", cropId, n)
				end, { Size = UDim2.fromOffset(50, 32), Parent = buttons })
			end
		end
	end
end

-- Plant -----------------------------------------------------------------------------------

local function renderPlant(content, args)
	local data = State.Data
	local fieldIndex = args and args.Field or 1
	Create.Label(
		"Plant something in field " .. fieldIndex .. ". Fertilizer (from the workbench) halves the growing time.",
		{
			TextColor3 = Theme.Muted,
			Size = UDim2.new(1, 0, 0, 24),
			Parent = content,
		}
	)
	local list = scroll(content, 30)
	for i, cropId in ipairs(Property.Crops.Order) do
		local crop = Property.Crops[cropId]
		local have = data.Materials[crop.Seed] or 0
		InventoryPanel.Row(
			list,
			i,
			crop.Name,
			"Seeds: " .. have .. " · ripe in " .. math.floor(crop.GrowTime / 60) .. " min",
			have > 0 and "Plant" or "No seeds",
			have > 0 and Theme.Good or Theme.PanelLight,
			have > 0
					and function()
						local result = Net.Request("Plant", fieldIndex, cropId)
						if result.ok then
							Windows.Close()
						end
					end
				or nil
		)
	end
end

-- Trader ----------------------------------------------------------------------------------

local function renderTrader(content)
	local data = State.Data
	goldLine(content, data, "     Marta buys anything. Prices rise under the Open Markets decree.")
	local list = scroll(content, 30)
	local entries = {}
	for id, count in pairs(data.Materials) do
		if count > 0 and Items.Materials[id] then
			table.insert(entries, {
				Key = id,
				Name = Items.Materials[id].Name,
				Count = count,
				Value = Items.Materials[id].Value or 1,
				Category = Items.Materials[id].Category or "",
			})
		end
	end
	for key, count in pairs(data.Consumables) do
		local info = CraftingRules.Describe(key)
		if info and count > 0 then
			table.insert(
				entries,
				{ Key = key, Name = info.Name, Count = count, Value = info.Value, Category = info.Kind }
			)
		end
	end
	table.sort(entries, function(a, b)
		return a.Name < b.Name
	end)
	for i, entry in ipairs(entries) do
		local row = InventoryPanel.Row(
			list,
			i,
			entry.Name .. "  x" .. entry.Count,
			entry.Category .. " · about " .. entry.Value .. "g each"
		)
		local buttons = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(170, 34),
			BackgroundTransparency = 1,
			Parent = row,
		}, { Create.List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
		Create.Button("Sell 1", Theme.Gold, function()
			Net.Request("Sell", entry.Key, 1)
		end, { Size = UDim2.fromOffset(70, 32), TextColor3 = Color3.new(0.1, 0.08, 0.05), Parent = buttons })
		Create.Button("Sell all", Theme.Gold, function()
			Net.Request("Sell", entry.Key, entry.Count)
		end, { Size = UDim2.fromOffset(80, 32), TextColor3 = Color3.new(0.1, 0.08, 0.05), Parent = buttons })
	end
	if #entries == 0 then
		Create.Label("You have nothing to sell.", { TextColor3 = Theme.Muted, Parent = list })
	end
end

function EstatePanels.Init()
	Windows.Register("Estate", "Holdsworth's Deeds", renderEstate)
	Windows.Register("Stable", "Greenmeadow Stables", renderStable)
	Windows.Register("Seeds", "Old Tomas' Seeds", renderSeeds)
	Windows.Register("Plant", "Plant a Field", renderPlant)
	Windows.Register("Trader", "Marta's Trading Post", renderTrader)
end

return EstatePanels
