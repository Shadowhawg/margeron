-- Weapons, cosmetics and crafting materials.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)

local InventoryService = {}
local Services

local function result(ok, message)
	return { ok = ok, message = message }
end

function InventoryService.EquipWeapon(player, weaponId)
	local data = Services.PlayerService.GetData(player)
	local def = Items.Weapons[weaponId]
	if not data or not def or not data.Weapons[weaponId] then
		return result(false, "You don't own that.")
	end
	if data.Level < (def.LevelReq or 1) then
		return result(false, "Requires level " .. def.LevelReq)
	end
	data.EquippedWeapon = weaponId
	Services.PlayerService.RefreshStats(player)
	return result(true)
end

function InventoryService.BuyWeapon(player, weaponId)
	local data = Services.PlayerService.GetData(player)
	local def = Items.Weapons[weaponId]
	if not data or not def or not def.Price then
		return result(false, "Not for sale.")
	end
	if data.Weapons[weaponId] then
		return result(false, "You already own that.")
	end
	if data.Level < (def.LevelReq or 1) then
		return result(false, "Requires level " .. def.LevelReq)
	end
	if not Services.PlayerService.SpendGold(player, def.Price) then
		return result(false, "Not enough gold.")
	end
	data.Weapons[weaponId] = true
	Services.PlayerService.Notify(player, "Purchased " .. def.Name .. ". Equip it from your inventory (I).", "Success")
	Services.PlayerService.Changed(player)
	return result(true)
end

function InventoryService.EquipCosmetic(player, cosmeticId)
	local data = Services.PlayerService.GetData(player)
	local def = Items.Cosmetics[cosmeticId]
	if not data or not def or not data.Cosmetics[cosmeticId] then
		return result(false, "You don't own that.")
	end
	-- Equipping an already-equipped cosmetic takes it off.
	if data.Equipped[def.Slot] == cosmeticId then
		data.Equipped[def.Slot] = ""
	else
		data.Equipped[def.Slot] = cosmeticId
	end
	Services.PlayerService.RefreshStats(player)
	return result(true)
end

function InventoryService.GrantWeapon(player, weaponId, silent)
	local data = Services.PlayerService.GetData(player)
	local def = Items.Weapons[weaponId]
	if not data or not def or data.Weapons[weaponId] then
		return
	end
	data.Weapons[weaponId] = true
	if not silent then
		Services.PlayerService.Notify(player, "New weapon: " .. def.Name .. "!", "Success")
	end
	Services.PlayerService.Changed(player)
end

function InventoryService.GrantCosmetic(player, cosmeticId, silent)
	local data = Services.PlayerService.GetData(player)
	local def = Items.Cosmetics[cosmeticId]
	if not data or not def or data.Cosmetics[cosmeticId] then
		return
	end
	data.Cosmetics[cosmeticId] = true
	if not silent then
		local label = def.Slot == "Title" and "New title" or "New cosmetic"
		Services.PlayerService.Notify(
			player,
			label .. ": " .. def.Name .. "! Equip it from your inventory (I).",
			"Success"
		)
	end
	Services.PlayerService.Changed(player)
end

function InventoryService.AddMaterial(player, materialId, amount)
	local data = Services.PlayerService.GetData(player)
	if not data or not Items.Materials[materialId] then
		return
	end
	data.Materials[materialId] = (data.Materials[materialId] or 0) + amount
	Services.QuestService.OnMaterialsChanged(player, materialId)
	Services.PlayerService.Changed(player)
end

function InventoryService.RemoveMaterial(player, materialId, amount)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return false
	end
	local have = data.Materials[materialId] or 0
	if have < amount then
		return false
	end
	data.Materials[materialId] = have - amount
	if data.Materials[materialId] == 0 then
		data.Materials[materialId] = nil
	end
	Services.PlayerService.Changed(player)
	return true
end

function InventoryService.Init(services)
	Services = services
end

return InventoryService
