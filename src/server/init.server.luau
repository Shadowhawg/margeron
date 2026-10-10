-- Server entry point. Loads every service, runs Init (wire-up) on all of them, then Start.
local Players = game:GetService("Players")

-- Characters are spawned by PlayerService once save data has loaded.
Players.CharacterAutoLoads = false

local Services = {}

local ORDER = {
	"DataService",
	"WorldService",
	"PlayerService",
	"CharacterService",
	"AppearanceService",
	"InventoryService",
	"SkillService",
	"QuestService",
	"BountyService",
	"EnemyService",
	"CombatService",
	"NPCService",
	"ExplorationService",
	"CraftingService",
	"PropertyService",
	"MarketService",
	"GovernmentService",
	"ShopService",
	"RequestRouter",
}

for _, name in ipairs(ORDER) do
	Services[name] = require(script.Services[name])
end

for _, name in ipairs(ORDER) do
	local service = Services[name]
	if service.Init then
		service.Init(Services)
	end
end

for _, name in ipairs(ORDER) do
	local service = Services[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[Margeron] Server ready")
