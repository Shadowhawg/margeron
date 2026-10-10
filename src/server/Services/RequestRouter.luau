-- Single entry point for client requests (Remotes.Request:InvokeServer(action, ...)).
-- Every argument from the client is untrusted, so each handler type-checks its input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local RequestRouter = {}
local Services

local RATE_LIMIT = 15 -- requests per second
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
