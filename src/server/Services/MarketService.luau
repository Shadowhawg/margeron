-- Trading: sell goods to Marta, buy seeds from Old Tomas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Property = require(Shared.Config.Property)
local GameConfig = require(Shared.Config.GameConfig)
local CraftingRules = require(Shared.CraftingRules)

local MarketService = {}
local Services

local function result(ok, message)
	return { ok = ok, message = message }
end

function MarketService.SellPrice(itemKey)
	local multiplier = GameConfig.SellRate * (Services.GovernmentService.DecreeActive("OpenMarkets") and 1.2 or 1)
	local material = Items.Materials[itemKey]
	if material then
		return math.max(1, math.floor((material.Value or 1) * multiplier))
	end
	local info = CraftingRules.Describe(itemKey)
	if info then
		return math.max(1, math.floor(info.Value * multiplier))
	end
	return nil
end

function MarketService.Sell(player, itemKey, count)
	local data = Services.PlayerService.GetData(player)
	if not data or type(itemKey) ~= "string" or type(count) ~= "number" or count ~= count then
		return result(false)
	end
	if not Services.NPCService.IsNear(player, "Trader") then
		return result(false, "Find Marta in Riverwatch to sell goods.")
	end
	count = math.floor(count)
	if count < 1 then
		return result(false)
	end
	local price = MarketService.SellPrice(itemKey)
	if not price then
		return result(false)
	end
	if Items.Materials[itemKey] then
		if not Services.InventoryService.RemoveMaterial(player, itemKey, count) then
			return result(false, "You don't have that many.")
		end
	else
		if (data.Consumables[itemKey] or 0) < count then
			return result(false, "You don't have that many.")
		end
		data.Consumables[itemKey] -= count
		if data.Consumables[itemKey] <= 0 then
			data.Consumables[itemKey] = nil
		end
	end
	Services.PlayerService.AddGold(player, price * count)
	return result(true, "Sold for " .. price * count .. " gold.")
end

function MarketService.BuySeeds(player, cropId, count)
	local data = Services.PlayerService.GetData(player)
	local crop = type(cropId) == "string" and Property.Crops[cropId]
	if not data or not crop or type(count) ~= "number" or count ~= count then
		return result(false)
	end
	if not Services.NPCService.IsNear(player, "Farmer") then
		return result(false, "Old Tomas sells seeds in Greenmeadow.")
	end
	count = math.clamp(math.floor(count), 1, 50)
	if data.Level < (crop.LevelReq or 1) then
		return result(false, "Requires level " .. crop.LevelReq .. ".")
	end
	local price, tax = Services.GovernmentService.PriceWithTax(player, crop.SeedPrice * count)
	if not Services.PlayerService.SpendGold(player, price) then
		return result(false, "You need " .. price .. " gold.")
	end
	Services.GovernmentService.CollectTax(tax)
	Services.InventoryService.AddMaterial(player, crop.Seed, count)
	return result(true, "Bought " .. count .. " " .. Items.Materials[crop.Seed].Name .. ".")
end

function MarketService.Init(services)
	Services = services
end

return MarketService
