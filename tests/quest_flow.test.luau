local NodeMt = getmetatable(game:GetService("ReplicatedStorage"):WaitForChild("Shared"))
local function mod(path)
	return require(setmetatable({ Path = path }, NodeMt))
end
local Leveling = mod("Shared/Leveling")
local Util = mod("Shared/Util")
local QuestRules = mod("Shared/QuestRules")
local GameConfig = mod("Shared/Config/GameConfig")

local player = { Name = "Tester", UserId = 42, Parent = true }
local data = {
	Level = 1,
	XP = 0,
	Gold = 25,
	SkillPoints = 0,
	Skills = {},
	Weapons = { IronSword = true },
	EquippedWeapon = "IronSword",
	Cosmetics = {},
	Equipped = { Cape = "", Aura = "", Title = "" },
	Materials = {},
	Quests = { Active = {}, Completed = {} },
	TrackedQuest = "",
	Bounties = { Defs = {}, Board = {}, BoardRefreshedAt = 0, DailyTakenDay = 0, Counter = 0, Completed = 0 },
	Renown = 0,
	Stats = { Kills = 0, QuestsCompleted = 0, Deaths = 0 },
	Purchases = {},
}
local notes = {}
local Services = {}
Services.PlayerService = {
	GetData = function()
		return data
	end,
	Notify = function(_, text)
		table.insert(notes, text)
	end,
	Changed = function() end,
	RefreshStats = function() end,
	AddGold = function(_, n)
		data.Gold += n
	end,
	SpendGold = function(_, n)
		if data.Gold < n then
			return false
		end
		data.Gold -= n
		return true
	end,
	AddXP = function(_, n)
		local lv, xp, gained = Leveling.AddXP(data.Level, data.XP, n)
		data.Level, data.XP = lv, xp
		data.SkillPoints += gained
		if gained > 0 then
			Services.QuestService.GrantAutomaticQuests(player)
		end
	end,
	GetHumanoid = function()
		return true, {
			FindFirstChild = function()
				return { Position = Vector3.new(14, 0, 18) }
			end,
		}
	end,
}
Services.WorldService = {
	GetNPCPosition = function()
		return Vector3.new(14, 0, 18)
	end,
}
Services.QuestService = mod("Server/Services/QuestService")
Services.InventoryService = mod("Server/Services/InventoryService")
Services.BountyService = mod("Server/Services/BountyService")
Services.QuestService.Init({
	DataService = { Loaded = { Connect = function() end } },
	PlayerService = Services.PlayerService,
	InventoryService = Services.InventoryService,
})
Services.InventoryService.Init(Services)
Services.BountyService.Init(Services)
-- QuestService captured a partial table; give it the full one.
Services.QuestService.Init(
	setmetatable({ DataService = { Loaded = { Connect = function() end } } }, { __index = Services })
)

local Q = Services.QuestService
Q.GrantAutomaticQuests(player)
check(data.Quests.Active.MQ1 ~= nil, "MQ1 auto-granted")
check(data.TrackedQuest == "MQ1", "MQ1 tracked")

local done = Q.OnTalk(player, "Elder")
check(#done == 1 and data.Quests.Completed.MQ1, "MQ1 completes on talking to Elder")
check(data.XP == 50 and data.Gold == 35, "MQ1 rewards")

check(Q.Accept(player, "MQ2").ok, "accept MQ2")
check(not Q.Accept(player, "MQ2").ok, "cannot accept twice")
for _ = 1, 4 do
	Q.OnEnemyKilled(player, "Wolf")
end
check(not QuestRules.IsReady(data, "MQ2"), "MQ2 not ready at 4/5")
Q.OnEnemyKilled(player, "Wolf")
Q.OnEnemyKilled(player, "Wolf")
check(data.Quests.Active.MQ2.Progress[1] == 5, "kill progress capped at 5")
check(QuestRules.IsReady(data, "MQ2"), "MQ2 ready")
Q.OnTalk(player, "Blacksmith")
check(data.Quests.Active.MQ2 ~= nil, "MQ2 not turned in at wrong NPC")
Q.OnTalk(player, "Elder")
check(data.Quests.Completed.MQ2, "MQ2 turned in")
check(data.Level == 2, "level 2 after MQ2 (xp " .. data.XP .. ")")

-- MQ3: talk objective + turn in at Blacksmith gives Steel Sword
check(Q.Accept(player, "MQ3").ok, "accept MQ3")
Q.OnTalk(player, "Blacksmith")
check(data.Quests.Completed.MQ3 and data.Weapons.SteelSword, "MQ3 gives Steel Sword")

-- Collect quest consumes materials
check(Q.Accept(player, "SQ_Pelts").ok, "accept pelts")
Services.InventoryService.AddMaterial(player, "WolfPelt", 6)
Q.OnTalk(player, "Hunter")
check(data.Quests.Completed.SQ_Pelts, "pelts turned in")
check(data.Materials.WolfPelt == 2, "4 pelts consumed, 2 left")
check(data.Cosmetics.RiverwatchCape, "cape reward granted")
check(
	Services.InventoryService.EquipCosmetic(player, "RiverwatchCape").ok and data.Equipped.Cape == "RiverwatchCape",
	"equip cape"
)
Services.InventoryService.EquipCosmetic(player, "RiverwatchCape")
check(data.Equipped.Cape == "", "toggle cape off")

-- Main quest can't be abandoned
data.Level = 3
check(Q.Accept(player, "MQ4").ok, "accept MQ4 at lv3")
check(not Q.Abandon(player, "MQ4").ok, "can't abandon main")

-- Bounties
local board = Services.BountyService.GetBoard(player)
check(#board.Offers == GameConfig.BountyBoardSize, "board filled")
check(board.DailyAvailable, "daily available")
local r = Services.BountyService.Accept(player, 1)
check(r.ok and #r.board.Offers == GameConfig.BountyBoardSize - 1, "accepted offer removed from board")
check(Services.BountyService.Accept(player, "daily").ok, "accept daily")
check(not Services.BountyService.Accept(player, "daily").ok, "daily only once")
check(Services.BountyService.Accept(player, 1).ok, "third bounty")
check(not Services.BountyService.Accept(player, 1).ok, "max 3 bounties")
check(Q.CountActiveBounties(data) == 3, "3 active bounties")

-- Complete every bounty
local renownBefore = data.Renown
for key, active in pairs(data.Quests.Active) do
	local def = data.Bounties.Defs[key]
	if def then
		local o = def.Objectives[1]
		if o.Kind == "Kill" then
			for _ = 1, o.Count do
				Q.OnEnemyKilled(player, o.Target)
			end
		else
			Services.InventoryService.AddMaterial(player, o.Target, o.Count)
		end
	end
end
local turned = Q.OnTalk(player, "Board")
check(#turned == 3, "turned in 3 bounties (got " .. #turned .. ")")
check(data.Renown == renownBefore + 5, "renown +1 +1 +3")
check(data.Cosmetics.TitleSellsword, "Sellsword title at 5 renown")
check(Util.Count(data.Bounties.Defs) == 0, "bounty defs cleaned up")
check(data.Bounties.Completed == 3, "bounty count")

-- Reroll costs gold
local gold = data.Gold
check(Services.BountyService.Reroll(player).ok and data.Gold == gold - 25, "reroll costs 25")

-- Abandon side bounty
Services.BountyService.Accept(player, 1)
local bountyKey
for key in pairs(data.Quests.Active) do
	if data.Bounties.Defs[key] then
		bountyKey = key
	end
end
check(Q.Abandon(player, bountyKey).ok and data.Bounties.Defs[bountyKey] == nil, "abandon bounty")

print("Final: Lv " .. data.Level .. ", gold " .. data.Gold .. ", renown " .. data.Renown .. ", notes " .. #notes)
summary()
