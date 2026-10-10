-- The Robux store, Brann's gold shop and the Bounty Board.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Products = require(Shared.Config.Products)
local Util = require(Shared.Util)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local InventoryPanel = require(script.Parent.InventoryPanel)
local New = Create.New

local player = Players.LocalPlayer

local ShopPanels = {}

local function scrollList(parent, props)
	local list = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = parent,
	}, { Create.Corner(8), Create.Padding(8), Create.List(6) })
	for k, v in pairs(props or {}) do
		list[k] = v
	end
	return list
end

local function owns(data, item)
	local g = item.Grant
	if g.Weapon then
		return data.Weapons[g.Weapon] == true
	elseif g.Cosmetic then
		return data.Cosmetics[g.Cosmetic] == true
	elseif g.Horse then
		return data.Property ~= nil and data.Property.Horses[g.Horse] == true
	elseif g.Pass then
		return data.Passes ~= nil and data.Passes[g.Pass] == true
	end
	return false
end

-- Which inventory tab shows a purchase (nil for gold and one-off effects).
local function inventoryTab(item)
	local g = item.Grant
	if g.Weapon then
		return "Weapons"
	elseif g.Cosmetic then
		return "Cosmetics"
	elseif g.Horse or g.Pass or g.CraftBoostSeconds then
		return "Mounts & Perks"
	end
	return nil
end

local function buy(item, isPass)
	if item.Id == 0 then
		if RunService:IsStudio() then
			local result = Net.Request("StudioPurchase", item.Key)
			local tabName = inventoryTab(item)
			if result.ok and tabName then
				task.wait(0.2) -- let the new save data arrive
				InventoryPanel.Show(tabName)
			end
		end
		return
	end
	if isPass then
		MarketplaceService:PromptGamePassPurchase(player, item.Id)
	else
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end
end

local function renderStore(content)
	local data = State.Data
	local list = scrollList(content)
	local order = 0
	local function section(title)
		order += 1
		Create.Label(title, {
			Font = Theme.TitleFont,
			TextSize = 24,
			TextColor3 = Theme.Accent,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = order,
			Parent = list,
		})
	end
	local function addItems(items, isPass)
		for _, item in ipairs(items) do
			local available = item.Id ~= 0 or RunService:IsStudio()
			if available then
				order += 1
				local owned = owns(data, item)
				local label = owned and "Owned · View" or ("R$ " .. item.Robux)
				if item.Id == 0 and not owned then
					label = "Test (free)"
				end
				InventoryPanel.Row(
					list,
					order,
					item.Name,
					item.Description,
					label,
					owned and Theme.Border or Theme.Robux,
					function()
						if owned then
							InventoryPanel.Show(inventoryTab(item) or "Weapons")
						else
							buy(item, isPass)
						end
					end
				)
			end
		end
	end

	section("Premium Gear")
	addItems(Products.GamePasses, true)
	section("Cosmetics & Gold")
	addItems(Products.DevProducts, false)

	order += 1
	Create.Label("Every purchase supports development. Premium weapons are level-gated so the game stays fair.", {
		TextColor3 = Theme.Muted,
		TextSize = 13,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = list,
	})
end

local function renderBlacksmith(content)
	local data = State.Data
	Create.Label("Your gold: " .. Util.FormatNumber(data.Gold), {
		Font = Theme.BoldFont,
		TextColor3 = Theme.Gold,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		Parent = content,
	})
	local list = scrollList(holder)

	local forSale = {}
	for weaponId, def in pairs(Items.Weapons) do
		if def.Price then
			table.insert(forSale, weaponId)
		end
	end
	table.sort(forSale, function(a, b)
		return Items.Weapons[a].Price < Items.Weapons[b].Price
	end)

	for i, weaponId in ipairs(forSale) do
		local def = Items.Weapons[weaponId]
		local owned = data.Weapons[weaponId]
		local levelOk = data.Level >= (def.LevelReq or 1)
		local affordable = data.Gold >= def.Price
		local label, color, action
		if owned then
			label, color = "Owned", Theme.Border
		elseif not levelOk then
			label, color = "Requires Lv " .. def.LevelReq, Theme.PanelLight
		else
			label = Util.FormatNumber(def.Price) .. " gold"
			color = affordable and Theme.Good or Theme.PanelLight
			action = affordable and function()
				Net.Request("BuyWeapon", weaponId)
			end or nil
		end
		local subtitle = def.Type
			.. "  ·  "
			.. def.Damage
			.. " dmg  ·  "
			.. def.Cooldown
			.. "s  ·  "
			.. (def.Description or "")
		InventoryPanel.Row(list, i, def.Name .. "  (Lv " .. def.LevelReq .. ")", subtitle, label, color, action)
	end
end

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	return m > 0 and (m .. "m") or (seconds .. "s")
end

local function bountyCard(parent, order, def, buttonText, enabled, onAccept)
	local card = New("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 88),
		BackgroundColor3 = def.Daily and Color3.fromRGB(60, 48, 28) or Theme.Background,
		Parent = parent,
	}, { Create.Corner(6), Create.Padding(10), Create.Stroke(def.Daily and Theme.Gold or Theme.Border) })
	Create.Label(def.Name, {
		Font = Theme.BoldFont,
		TextSize = 17,
		TextColor3 = def.Daily and Theme.Gold or Theme.Accent,
		Size = UDim2.new(1, -140, 0, 22),
		Parent = card,
	})
	Create.Label(def.Description, {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -140, 0, 32),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	Create.Label("Reward: " .. def.Rewards.XP .. " XP, " .. def.Rewards.Gold .. " gold", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, -140, 0, 18),
		TextSize = 13,
		TextColor3 = Theme.Gold,
		Parent = card,
	})
	local button = Create.Button(buttonText, enabled and Theme.Good or Theme.PanelLight, enabled and onAccept or nil, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(120, 36),
		Parent = card,
	})
	button.AutoButtonColor = enabled
end

local function renderBoard(content, board)
	if not board then
		Create.Label(
			"The notices are unreadable from here. Walk up to the Bounty Board.",
			{ TextColor3 = Theme.Muted, Parent = content }
		)
		return
	end
	local function apply(result)
		if result.ok and result.board then
			Windows.SetArgs(result.board)
		end
	end
	local full = board.Active >= board.MaxActive

	Create.Label(
		"Active bounties: "
			.. board.Active
			.. "/"
			.. board.MaxActive
			.. "     New notices in "
			.. formatTime(board.RefreshIn),
		{
			TextColor3 = full and Theme.Bad or Theme.Muted,
			Size = UDim2.new(1, -170, 0, 24),
			Parent = content,
		}
	)
	Create.Button("Reroll (" .. board.RerollCost .. " gold)", Theme.PanelLight, function()
		apply(Net.Request("RerollBounties"))
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(160, 28),
		TextSize = 13,
		Parent = content,
	})

	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = content,
	})
	local list = scrollList(holder)

	bountyCard(
		list,
		0,
		board.Daily,
		board.DailyAvailable and "Accept" or "Done today",
		board.DailyAvailable and not full,
		function()
			apply(Net.Request("AcceptBounty", "daily"))
		end
	)
	for i, offer in ipairs(board.Offers) do
		bountyCard(list, i, offer, "Accept", not full, function()
			apply(Net.Request("AcceptBounty", i))
		end)
	end
	if #board.Offers == 0 then
		Create.Label("You've taken every notice. Reroll, or come back later.", {
			TextColor3 = Theme.Muted,
			LayoutOrder = 99,
			Parent = list,
		})
	end
end

function ShopPanels.Init()
	Windows.Register("Store", "Store", renderStore)
	Windows.Register("Blacksmith", "Brann's Forge", renderBlacksmith)
	Windows.Register("Board", "Bounty Board", renderBoard)
end

return ShopPanels
