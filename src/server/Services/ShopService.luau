-- Robux purchases: Developer Products (ProcessReceipt) and Game Passes.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Config.Products)

local ShopService = {}
local Services

local MAX_RECEIPT_HISTORY = 100

local productsById = {}
local passesById = {}
local byKey = {}
for _, product in ipairs(Products.DevProducts) do
	if product.Id ~= 0 then
		productsById[product.Id] = product
	end
	byKey[product.Key] = product
end
for _, pass in ipairs(Products.GamePasses) do
	if pass.Id ~= 0 then
		passesById[pass.Id] = pass
	end
	byKey[pass.Key] = pass
end

local function grant(player, item, silent, skipGold)
	local g = item.Grant
	if g.Gold and not skipGold then
		Services.PlayerService.AddGold(player, g.Gold)
	end
	if g.Weapon then
		Services.InventoryService.GrantWeapon(player, g.Weapon, silent)
	end
	if g.Cosmetic then
		Services.InventoryService.GrantCosmetic(player, g.Cosmetic, silent)
	end
	if not silent then
		Services.PlayerService.Notify(player, "Thank you for supporting Margeron! Received: " .. item.Name, "Success")
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Services.PlayerService.GetData(player)
	local product = productsById[receipt.ProductId]
	if not player or not data or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Already granted (e.g. Roblox retried after a failed save): don't grant twice.
	if table.find(data.Purchases, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	grant(player, product, false)
	table.insert(data.Purchases, receipt.PurchaseId)
	while #data.Purchases > MAX_RECEIPT_HISTORY do
		table.remove(data.Purchases, 1)
	end

	if not Services.DataService.Save(player, false) then
		-- Roblox will retry; the PurchaseId check above stops a double grant.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkGamePasses(player)
	for passId, pass in pairs(passesById) do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and owns then
			-- Passes are re-checked every join, so only idempotent grants apply here.
			grant(player, pass, true, true)
		end
	end
end

-- Studio-only: lets you test the purchase flow for items whose ID is still 0.
function ShopService.StudioPurchase(player, key)
	local item = byKey[key]
	if not RunService:IsStudio() or not item or item.Id ~= 0 then
		return { ok = false }
	end
	grant(player, item, false)
	return { ok = true }
end

function ShopService.Init(services)
	Services = services
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passesById[passId]
		if purchased and pass then
			grant(player, pass, false)
		end
	end)
	Services.DataService.Loaded:Connect(checkGamePasses)
end

return ShopService
