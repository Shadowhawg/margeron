-- Robux store: every product and pass grants something the player can see in their inventory.
local NodeMt = getmetatable(game:GetService("ReplicatedStorage"):WaitForChild("Shared"))
local function mod(path)
	return require(setmetatable({ Path = path }, NodeMt))
end
local Products = mod("Shared/Config/Products")
local Items = mod("Shared/Config/Items")
local Property = mod("Shared/Config/Property")
local ShopService = mod("Server/Services/ShopService")
local InventoryService = mod("Server/Services/InventoryService")

local player = { Name = "Buyer", UserId = 7 }
local data
local notes = {}
local grown = 0
local Services = {}
Services.PlayerService = {
	GetData = function()
		return data
	end,
	Notify = function(_, text)
		table.insert(notes, text)
	end,
	Changed = function() end,
	AddGold = function(_, n)
		data.Gold += n
	end,
}
Services.InventoryService = InventoryService
Services.PropertyService = {
	GrantHorse = function(_, horseId)
		data.Property.Horses[horseId] = true
	end,
	GrowAll = function()
		grown += 1
	end,
}
Services.DataService = {
	Loaded = { Connect = function() end },
	Save = function()
		return true
	end,
}
Services.QuestService = { OnMaterialsChanged = function() end }
InventoryService.Init(Services)
ShopService.Init(Services)

local function fresh()
	data = {
		Gold = 0,
		Weapons = {},
		Cosmetics = {},
		Passes = {},
		Purchases = {},
		Property = { Horses = {}, ActiveHorse = "" },
		CraftBoostUntil = 0,
	}
end

for _, list in ipairs({ Products.DevProducts, Products.GamePasses }) do
	for _, item in ipairs(list) do
		fresh()
		local result = ShopService.StudioPurchase(player, item.Key)
		check(result.ok, item.Key .. " can be test-bought in Studio")
		local g = item.Grant
		if g.Gold then
			check(data.Gold == g.Gold, item.Key .. " grants its gold")
		end
		if g.Weapon then
			check(Items.Weapons[g.Weapon] ~= nil, item.Key .. " weapon exists")
			check(data.Weapons[g.Weapon] == true, item.Key .. " lands in Weapons")
		end
		if g.Cosmetic then
			check(Items.Cosmetics[g.Cosmetic] ~= nil, item.Key .. " cosmetic exists")
			check(data.Cosmetics[g.Cosmetic] == true, item.Key .. " lands in Cosmetics")
		end
		if g.Horse then
			check(Property.Horses[g.Horse] ~= nil, item.Key .. " horse exists")
			check(data.Property.Horses[g.Horse] == true, item.Key .. " lands in the stable")
		end
		if g.Pass then
			check(data.Passes[g.Pass] == true, item.Key .. " sets its perk")
		end
		if g.CraftBoostSeconds then
			check(data.CraftBoostUntil > 0, item.Key .. " starts the crafting boost")
		end
		check(#notes > 0, item.Key .. " tells the player what they got")
		table.clear(notes)
	end
end
summary()
