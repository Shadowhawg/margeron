-- Single entry point for client requests (Remotes.Request:InvokeServer(action, ...)).
-- Every argument from the client is untrusted, so each handler type-checks its input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local RequestRouter = {}
local Services

local RATE_LIMIT = 20 -- requests per second
local buckets = {} -- [Player] = { Count, WindowStart }

local function allowed(player)
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket or now - bucket.WindowStart >= 1 then
		buckets[player] = { Count = 1, WindowStart = now }
		return true
	end
	bucket.Count += 1
	return bucket.Count <= RATE_LIMIT
end

local function isString(v)
	return type(v) == "string" and #v < 64
end

local handlers = {
	UnlockSkill = function(player, nodeId)
		if not isString(nodeId) then
			return { ok = false }
		end
		return Services.SkillService.Unlock(player, nodeId)
	end,
	EquipWeapon = function(player, weaponId)
		if not isString(weaponId) then
			return { ok = false }
		end
		return Services.InventoryService.EquipWeapon(player, weaponId)
	end,
	BuyWeapon = function(player, weaponId)
		if not isString(weaponId) then
			return { ok = false }
		end
		return Services.InventoryService.BuyWeapon(player, weaponId)
	end,
	EquipCosmetic = function(player, cosmeticId)
		if not isString(cosmeticId) then
			return { ok = false }
		end
		return Services.InventoryService.EquipCosmetic(player, cosmeticId)
	end,
	UseAbility = function(player, abilityId, aim)
		if not isString(abilityId) then
			return { ok = false }
		end
		return Services.CombatService.UseAbility(player, abilityId, aim)
	end,
	DialogueChoice = function(player, npcId, optionId)
		return Services.NPCService.Choose(player, npcId, optionId)
	end,
	AcceptBounty = function(player, which)
		if which ~= "daily" and type(which) ~= "number" then
			return { ok = false }
		end
		return Services.BountyService.Accept(player, which)
	end,
	RerollBounties = function(player)
		return Services.BountyService.Reroll(player)
	end,
	AbandonQuest = function(player, key)
		if not isString(key) then
			return { ok = false }
		end
		return Services.QuestService.Abandon(player, key)
	end,
	TrackQuest = function(player, key)
		if not isString(key) then
			return { ok = false }
		end
		return Services.QuestService.Track(player, key)
	end,
	-- Character creation and story
	PreviewAppearance = function(player, appearance)
		return Services.CharacterService.Preview(player, appearance)
	end,
	ConfirmAppearance = function(player, appearance)
		return Services.CharacterService.Confirm(player, appearance)
	end,
	FinishIntro = function(player)
		return Services.CharacterService.FinishIntro(player)
	end,

	-- Crafting
	Craft = function(player, recipeId)
		if not isString(recipeId) then
			return { ok = false }
		end
		return Services.CraftingService.Craft(player, recipeId)
	end,
	Brew = function(player, ingredients)
		return Services.CraftingService.Brew(player, ingredients)
	end,
	Taste = function(player, ingredientId)
		return Services.CraftingService.Taste(player, ingredientId)
	end,
	Temper = function(player, weaponId)
		return Services.CraftingService.Temper(player, weaponId)
	end,
	Infuse = function(player, weaponId, infusionId)
		return Services.CraftingService.Infuse(player, weaponId, infusionId)
	end,
	UseConsumable = function(player, key)
		if not isString(key) then
			return { ok = false }
		end
		return Services.CraftingService.Use(player, key)
	end,

	-- Trading
	Sell = function(player, itemKey, count)
		if not isString(itemKey) then
			return { ok = false }
		end
		return Services.MarketService.Sell(player, itemKey, count)
	end,
	BuySeeds = function(player, cropId, count)
		return Services.MarketService.BuySeeds(player, cropId, count)
	end,

	-- Property
	BuyHome = function(player, homeId)
		return Services.PropertyService.BuyHome(player, homeId)
	end,
	Plant = function(player, fieldIndex, cropId)
		return Services.PropertyService.Plant(player, fieldIndex, cropId)
	end,
	BuyAnimal = function(player, animalType)
		return Services.PropertyService.BuyAnimal(player, animalType)
	end,
	BuyHorse = function(player, horseId)
		return Services.PropertyService.BuyHorse(player, horseId)
	end,
	SetHorse = function(player, horseId)
		return Services.PropertyService.SetActiveHorse(player, horseId)
	end,
	ToggleMount = function(player)
		return Services.PropertyService.ToggleMount(player)
	end,

	SetCrouch = function(player, on)
		return Services.StealthService.SetCrouch(player, on == true)
	end,

	-- Exploration
	FastTravel = function(player, destination)
		if not isString(destination) then
			return { ok = false }
		end
		return Services.ExplorationService.FastTravel(player, destination)
	end,

	-- Government
	GetGovernment = function(player)
		return { ok = true, state = Services.GovernmentService.GetState(player) }
	end,
	RunForOffice = function(player, pledge)
		return Services.GovernmentService.Run(player, pledge)
	end,
	Vote = function(player, candidateId)
		return Services.GovernmentService.Vote(player, candidateId)
	end,
	SetTax = function(player, rate)
		return Services.GovernmentService.SetTax(player, rate)
	end,
	SetDecree = function(player, decreeId)
		return Services.GovernmentService.SetDecree(player, decreeId)
	end,
	Appoint = function(player, office, username)
		return Services.GovernmentService.Appoint(player, office, username)
	end,
	ClaimTreasury = function(player)
		return Services.GovernmentService.ClaimTreasury(player)
	end,

	ToggleWeapon = function(player)
		local drawn = Services.AppearanceService.IsWeaponDrawn(player)
		Services.PropertyService.Dismount(player)
		return { ok = true, drawn = Services.AppearanceService.SetWeaponDrawn(player, not drawn) }
	end,

	StudioPurchase = function(player, key)
		if not isString(key) then
			return { ok = false }
		end
		return Services.ShopService.StudioPurchase(player, key)
	end,
}

function RequestRouter.Init(services)
	Services = services
	Remotes.Request.OnServerInvoke = function(player, action, ...)
		if not allowed(player) then
			return { ok = false, message = "Slow down!" }
		end
		local handler = type(action) == "string" and handlers[action]
		if not handler or not Services.PlayerService.GetData(player) then
			return { ok = false }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn("[RequestRouter]", action, "failed:", result)
			return { ok = false, message = "Something went wrong." }
		end
		return result
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RequestRouter
