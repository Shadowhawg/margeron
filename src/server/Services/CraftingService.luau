-- Crafting stations, recipes, alchemy, tempering, infusions, consumables and buffs.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crafting = require(Shared.Config.Crafting)
local Items = require(Shared.Config.Items)
local Remotes = require(Shared.Remotes)
local CraftingRules = require(Shared.CraftingRules)
local Stats = require(Shared.Stats)

local CraftingService = {}
local Services

local STATION_RANGE = 16

local function result(ok, message, extra)
	local r = extra or {}
	r.ok = ok
	r.message = message
	return r
end

local function now()
	return Stats.Now()
end

-- Is the player standing at a station of this type that they may use?
local function atStation(player, stationId)
	local _, character = Services.PlayerService.GetHumanoid(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, model in ipairs(CollectionService:GetTagged("CraftingStation")) do
		local owner = model:GetAttribute("Owner")
		if
			model:GetAttribute("Station") == stationId
			and (owner == nil or owner == player.UserId)
			and model.PrimaryPart
		then
			if (model.PrimaryPart.Position - root.Position).Magnitude <= STATION_RANGE then
				return true
			end
		end
	end
	return false
end

local function consume(player, _data, inputs)
	for id, count in pairs(inputs) do
		if id == "Gold" then
			Services.PlayerService.SpendGold(player, count)
		else
			Services.InventoryService.RemoveMaterial(player, id, count)
		end
	end
	Services.PlayerService.Changed(player)
end

local function boostActive(data)
	return (data.CraftBoostUntil or 0) > now()
end

local function doubleOutput(data)
	local chance = (boostActive(data) and Crafting.BoostDoubleChance or 0)
		+ (data.Passes.MasterArtisan and Crafting.MasterDoubleChance or 0)
	return math.random() < chance
end

function CraftingService.AddCraftXP(player, amount)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return
	end
	if boostActive(data) then
		amount *= 2
	end
	if Services.GovernmentService.DecreeActive("ArtisansCharter") then
		amount *= 1.3
	end
	local craft = data.Crafting
	craft.XP += math.floor(amount)
	while craft.Level < Crafting.MaxLevel and craft.XP >= Crafting.XPToNext(craft.Level) do
		craft.XP -= Crafting.XPToNext(craft.Level)
		craft.Level += 1
		Services.PlayerService.Notify(
			player,
			"Crafting level " .. craft.Level .. "! New recipes and stronger potions.",
			"LevelUp"
		)
	end
	data.Stats.Crafted += 1
	Services.PlayerService.Changed(player)
end

local EVENT_FOR_STATION = { Forge = "Craft", Workbench = "Craft", CookingPot = "Cook" }

function CraftingService.Craft(player, recipeId)
	local data = Services.PlayerService.GetData(player)
	local recipe
	for _, r in ipairs(Crafting.Recipes) do
		if r.Id == recipeId then
			recipe = r
		end
	end
	if not data or not recipe then
		return result(false)
	end
	if not atStation(player, recipe.Station) then
		return result(false, "You need to be at a " .. Crafting.StationNames[recipe.Station] .. ".")
	end
	if data.Crafting.Level < recipe.Level then
		return result(false, "Requires crafting level " .. recipe.Level .. ".")
	end
	local ok, missing = CraftingRules.HasInputs(data, recipe.Inputs)
	if not ok then
		return result(false, "Not enough " .. missing .. ".")
	end
	local out = recipe.Output
	if out.Weapon and data.Weapons[out.Weapon] then
		return result(false, "You already own that weapon.")
	end
	if out.Cosmetic and data.Cosmetics[out.Cosmetic] then
		return result(false, "You already own that.")
	end

	consume(player, data, recipe.Inputs)
	local times = doubleOutput(data) and 2 or 1
	if out.Material then
		Services.InventoryService.AddMaterial(player, out.Material, out.Count * times)
	elseif out.Food then
		local key = "F:" .. out.Food
		data.Consumables[key] = (data.Consumables[key] or 0) + times
	elseif out.Weapon then
		Services.InventoryService.GrantWeapon(player, out.Weapon)
		times = 1
	elseif out.Cosmetic then
		Services.InventoryService.GrantCosmetic(player, out.Cosmetic)
		times = 1
	end
	CraftingService.AddCraftXP(player, recipe.XP)
	Services.QuestService.OnEvent(player, EVENT_FOR_STATION[recipe.Station] or "Craft")
	if recipe.Id:find("^Smelt") then
		Services.QuestService.OnEvent(player, "Smelt")
	end
	Remotes.Effect:FireClient(player, "Crafted", recipe.Station)
	return result(
		true,
		times > 1 and ("Crafted " .. recipe.Name .. " - double output!") or ("Crafted " .. recipe.Name .. ".")
	)
end

-- Alchemy: mix 2-3 different ingredients.
function CraftingService.Brew(player, ingredientIds)
	local data = Services.PlayerService.GetData(player)
	if not data or type(ingredientIds) ~= "table" or #ingredientIds < 2 or #ingredientIds > 3 then
		return result(false, "Choose two or three ingredients.")
	end
	if not atStation(player, "AlchemyTable") then
		return result(false, "You need to be at an Alchemy Table.")
	end
	local seen = {}
	for _, id in ipairs(ingredientIds) do
		if type(id) ~= "string" or not CraftingRules.IsIngredient(id) or seen[id] then
			return result(false, "Invalid ingredients.")
		end
		seen[id] = true
		if (data.Materials[id] or 0) < 1 then
			return result(false, "You're out of " .. Items.Materials[id].Name .. ".")
		end
	end

	local inputs = {}
	for _, id in ipairs(ingredientIds) do
		inputs[id] = 1
	end
	consume(player, data, inputs)

	local effects = CraftingRules.SharedEffects(ingredientIds)
	if #effects == 0 then
		CraftingService.AddCraftXP(player, 2)
		return result(false, "The mixture fizzles into grey sludge. These ingredients share nothing.")
	end

	-- Learn which effects each ingredient has.
	local learned = 0
	for _, id in ipairs(ingredientIds) do
		local known = data.Crafting.Known[id] or {}
		data.Crafting.Known[id] = known
		for _, effect in ipairs(Items.Materials[id].Effects) do
			if table.find(effects, effect) and not known[effect] then
				known[effect] = true
				learned += 1
			end
		end
	end

	local tier = Crafting.PotencyTier(data.Crafting.Level, data.Passes.MasterArtisan)
	local key = CraftingRules.PotionKey(effects, tier)
	local count = doubleOutput(data) and 2 or 1
	data.Consumables[key] = (data.Consumables[key] or 0) + count
	CraftingService.AddCraftXP(player, 10 + 6 * #effects + 4 * learned)
	Services.QuestService.OnEvent(player, "Brew")
	Remotes.Effect:FireClient(player, "Crafted", "AlchemyTable")
	local name = CraftingRules.Describe(key).Name
	local text = "Brewed " .. (count > 1 and "2x " or "") .. name .. "!"
	if learned > 0 then
		text ..= " Discovered " .. learned .. " new ingredient effect" .. (learned > 1 and "s" or "") .. "."
	end
	return result(true, text)
end

-- Tasting reveals an ingredient's first unknown effect (and uses it up).
function CraftingService.Taste(player, ingredientId)
	local data = Services.PlayerService.GetData(player)
	if not data or type(ingredientId) ~= "string" or not CraftingRules.IsIngredient(ingredientId) then
		return result(false)
	end
	if (data.Materials[ingredientId] or 0) < 1 then
		return result(false, "You don't have any.")
	end
	local known = data.Crafting.Known[ingredientId] or {}
	data.Crafting.Known[ingredientId] = known
	local def = Items.Materials[ingredientId]
	for _, effect in ipairs(def.Effects) do
		if not known[effect] then
			Services.InventoryService.RemoveMaterial(player, ingredientId, 1)
			known[effect] = true
			Services.PlayerService.Changed(player)
			return result(true, "You taste the " .. def.Name .. "... " .. Crafting.Effects[effect].Name .. "!")
		end
	end
	return result(false, "You already know everything about " .. def.Name .. ".")
end

function CraftingService.Temper(player, weaponId)
	local data = Services.PlayerService.GetData(player)
	if not data or type(weaponId) ~= "string" or not data.Weapons[weaponId] then
		return result(false, "You don't own that weapon.")
	end
	if not atStation(player, "Forge") then
		return result(false, "You need to be at a Forge.")
	end
	local level = data.Crafting.Temper[weaponId] or 0
	if level >= Crafting.Temper.MaxLevel then
		return result(false, "That weapon can't be improved further.")
	end
	local cost = Crafting.Temper.Cost(level + 1)
	local ok, missing = CraftingRules.HasInputs(data, cost)
	if not ok then
		return result(false, "Not enough " .. missing .. ".")
	end
	consume(player, data, cost)
	data.Crafting.Temper[weaponId] = level + 1
	CraftingService.AddCraftXP(player, 20 + 10 * level)
	Services.QuestService.OnEvent(player, "Temper")
	Services.PlayerService.RefreshStats(player)
	Remotes.Effect:FireClient(player, "Crafted", "Forge")
	return result(true, Items.Weapons[weaponId].Name .. " tempered to +" .. (level + 1) .. ".")
end

function CraftingService.Infuse(player, weaponId, infusionId)
	local data = Services.PlayerService.GetData(player)
	local infusion = type(infusionId) == "string" and Crafting.Infusions[infusionId]
	if not data or type(weaponId) ~= "string" or not data.Weapons[weaponId] or not infusion then
		return result(false)
	end
	if not atStation(player, "Forge") then
		return result(false, "You need to be at a Forge.")
	end
	if data.Crafting.Level < infusion.Level then
		return result(false, "Requires crafting level " .. infusion.Level .. ".")
	end
	if data.Crafting.Infusions[weaponId] == infusionId then
		return result(false, "It already carries that infusion.")
	end
	local ok, missing = CraftingRules.HasInputs(data, infusion.Inputs)
	if not ok then
		return result(false, "Not enough " .. missing .. ".")
	end
	consume(player, data, infusion.Inputs)
	data.Crafting.Infusions[weaponId] = infusionId
	CraftingService.AddCraftXP(player, 45)
	Services.QuestService.OnEvent(player, "Infuse")
	Services.PlayerService.RefreshStats(player)
	Remotes.Effect:FireClient(player, "Crafted", "Forge")
	return result(true, Items.Weapons[weaponId].Name .. " infused with " .. infusion.Name .. ".")
end

-- Drink a potion or eat food.
function CraftingService.Use(player, key)
	local data = Services.PlayerService.GetData(player)
	local info = CraftingRules.Describe(key)
	local humanoid = Services.PlayerService.GetHumanoid(player)
	if not data or not info or (data.Consumables[key] or 0) < 1 then
		return result(false)
	end
	if not humanoid then
		return result(false)
	end
	data.Consumables[key] -= 1
	if data.Consumables[key] <= 0 then
		data.Consumables[key] = nil
	end
	local t = now()
	for _, e in ipairs(info.Effects) do
		local effect = Crafting.Effects[e.Id]
		if effect.Instant then
			if e.Magnitude > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + e.Magnitude)
			end
		else
			local current = data.Buffs[e.Id]
			local magnitude = e.Magnitude
			if current and current.Until > t then
				magnitude = math.max(magnitude, current.Magnitude)
			end
			data.Buffs[e.Id] = { Until = t + e.Duration, Magnitude = magnitude }
		end
	end
	Services.PlayerService.RefreshStats(player)
	Remotes.Effect:FireAllClients("Drink", player.Character, info.Kind)
	return result(true, (info.Kind == "Food" and "Ate " or "Drank ") .. info.Name .. ".")
end

-- Buff upkeep: regeneration ticks and expiry.
local function tickBuffs()
	local t = now()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Services.PlayerService.GetData(player)
		if data then
			local expired = false
			for effectId, buff in pairs(data.Buffs) do
				if buff.Until <= t then
					data.Buffs[effectId] = nil
					expired = true
				end
			end
			if expired then
				Services.PlayerService.RefreshStats(player)
			end
			local stats = Services.PlayerService.GetStats(player)
			local humanoid = Services.PlayerService.GetHumanoid(player)
			if stats and humanoid and stats.Regeneration > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + stats.Regeneration)
			end
		end
	end
end

local function setupStation(model)
	local stationId = model:GetAttribute("Station")
	if not stationId or not model.PrimaryPart or model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use"
	prompt.ObjectText = Crafting.StationNames[stationId] or stationId
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		local owner = model:GetAttribute("Owner")
		if owner and owner ~= player.UserId then
			Services.PlayerService.Notify(player, "This belongs to someone else.", "Error")
			return
		end
		Remotes.Open:FireClient(player, "Crafting", { Station = stationId })
	end)
end

function CraftingService.Init(services)
	Services = services
end

function CraftingService.Start()
	for _, model in ipairs(CollectionService:GetTagged("CraftingStation")) do
		setupStation(model)
	end
	CollectionService:GetInstanceAddedSignal("CraftingStation"):Connect(function(model)
		task.defer(setupStation, model)
	end)
	while true do
		task.wait(1)
		tickBuffs()
	end
end

return CraftingService
