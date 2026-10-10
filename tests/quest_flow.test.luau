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
	Story = { PrologueSeen = false, Echoes = {} },
	Crafting = { XP = 0, Level = 1, Known = {}, Temper = {}, Infusions = {} },
	Discoveries = {},
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
Services.GovernmentService = {
	DecreeActive = function()
		return false
	end,
}
Services.NPCService = {
	IsNear = function()
		return true
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
check(data.Quests.Active.MQ1 == nil, "story waits for the prologue")
data.Story.PrologueSeen = true
Q.GrantAutomaticQuests(player)
check(data.Quests.Active.MQ1 ~= nil, "MQ1 auto-granted")
check(data.TrackedQuest == "MQ1", "MQ1 tracked")

local done = Q.OnTalk(player, "Elder")
check(#done == 1 and data.Quests.Completed.MQ1, "MQ1 completes on talking to Elder")
check(data.XP == 50 and data.Gold == 50, "MQ1 rewards")

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
check(data.Story.Echoes.Echo1 == true, "MQ2 unlocks the first memory")

-- Event objectives (alchemy side quest)
check(Q.Accept(player, "SQ_Herbs").ok, "accept herbs quest")
Q.OnEvent(player, "Gather")
Q.OnEvent(player, "Gather")
Q.OnEvent(player, "Brew")
check(not QuestRules.IsReady(data, "SQ_Herbs"), "herbs quest needs 3 gathers")
Q.OnEvent(player, "Gather")
check(QuestRules.IsReady(data, "SQ_Herbs"), "herbs quest ready")
Q.OnTalk(player, "Mystic")
check(data.Quests.Completed.SQ_Herbs and (data.Materials.Moonpetal or 0) >= 2, "herbs quest rewards materials")

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

-- The rest of the main story: MQ4 -> MQ4B -> MQ5 -> MQ5B (landmark visit) -> MQ6 -> MQ7 -> MQ8
Q.OnEnemyKilled(player, "BanditChief")
for _ = 1, 6 do
	Q.OnEnemyKilled(player, "Bandit")
end
Q.OnTalk(player, "Elder")
check(data.Quests.Completed.MQ4, "MQ4 done")
check(not Q.Accept(player, "MQ5").ok, "MQ5 now needs Crown Coin first")
data.Level = math.max(data.Level, 4)
check(Q.Accept(player, "MQ4B").ok, "accept MQ4B")
Q.OnTalk(player, "Chancellor")
check(data.Quests.Completed.MQ4B, "Crown Coin turned in to the Chancellor")
data.Level = math.max(data.Level, 6)
check(Q.Accept(player, "MQ5").ok, "accept MQ5")
Services.InventoryService.AddMaterial(player, "BoneDust", 5)
Q.OnTalk(player, "Mystic")
check(data.Quests.Completed.MQ5, "MQ5 done")
check(Q.Accept(player, "MQ5B").ok, "accept MQ5B")
Q.OnEvent(player, "Visit:Greyspire")
check(data.Quests.Active.MQ5B.Progress[1] == 0, "visiting the wrong landmark doesn't count")
Q.OnEvent(player, "Visit:DrownedShrine")
check(data.Quests.Active.MQ5B.Progress[1] == 1, "visiting the Drowned Shrine counts")
Q.OnTalk(player, "Archmage")
check(data.Quests.Completed.MQ5B, "The Seventh Name turned in")
check(data.Story.Echoes.EchoOath == true, "MQ5B unlocks the oath memory")
data.Level = math.max(data.Level, 11)
check(Q.Accept(player, "MQ6").ok, "accept MQ6")
Q.OnEnemyKilled(player, "AshenWyrmling")
Q.OnTalk(player, "Elder")
check(data.Quests.Completed.MQ6, "MQ6 done")
check(Q.Accept(player, "MQ7").ok, "accept MQ7")
for _ = 1, 6 do
	Q.OnEnemyKilled(player, "AshenAcolyte")
end
Services.InventoryService.AddMaterial(player, "AshenSigil", 3)
Q.OnTalk(player, "Chancellor")
check(data.Quests.Completed.MQ7, "MQ7 done")
check(Q.Accept(player, "MQ8").ok, "accept MQ8")
Q.OnEnemyKilled(player, "Corvin")
Q.OnTalk(player, "Elder")
check(data.Quests.Completed.MQ8, "MQ8 done")
check(data.Cosmetics.TitleUnforgotten, "finale title granted")
check(data.Story.Echoes.Echo6 == true, "finale memory unlocked")

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
