local Shared =
	setmetatable({ Path = "Shared" }, getmetatable(game:GetService("ReplicatedStorage"):WaitForChild("Shared")))
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Products = require(Shared.Config.Products)
local Skills = require(Shared.Config.Skills)
local Abilities = require(Shared.Config.Abilities)
local Enemies = require(Shared.Config.Enemies)
local World = require(Shared.Config.World)
local Quests = require(Shared.Config.Quests)
local Bounties = require(Shared.Config.Bounties)
local Leveling = require(Shared.Leveling)
local Stats = require(Shared.Stats)
local QuestRules = require(Shared.QuestRules)
local Util = require(Shared.Util)

-- Leveling
check(Leveling.XPToNext(1) == 100, "XPToNext(1)")
local l, x, g = Leveling.AddXP(1, 0, 100)
check(l == 2 and x == 0 and g == 1, "level up exactly")
l, x, g = Leveling.AddXP(1, 0, 10 ^ 9)
check(l == GameConfig.MaxLevel and x == 0, "max level cap")

-- Config integrity: quests
local inOrder = {}
for _, id in ipairs(Quests.Order) do
	inOrder[id] = true
	check(Quests[id] ~= nil, "Quests.Order entry exists: " .. id)
end
for id, q in pairs(Quests) do
	if type(q) == "table" and id ~= "Order" then
		check(inOrder[id], "quest in Order: " .. id)
		check(q.Giver == nil or World.NPCs[q.Giver] ~= nil, "giver exists: " .. id)
		check(World.NPCs[q.TurnIn] ~= nil, "turn-in exists: " .. id)
		for _, req in ipairs(q.Requires or {}) do
			check(Quests[req] ~= nil, "requirement exists: " .. id .. " -> " .. req)
		end
		for _, o in ipairs(q.Objectives) do
			if o.Kind == "Kill" then
				check(Enemies[o.Target] ~= nil, "kill target exists: " .. id)
			elseif o.Kind == "Collect" then
				check(Items.Materials[o.Target] ~= nil, "collect target exists: " .. id)
			elseif o.Kind == "Talk" then
				check(World.NPCs[o.Target] ~= nil, "talk target exists: " .. id)
			elseif o.Kind == "Event" then
				check(type(o.Target) == "string", "event target: " .. id)
			else
				check(false, "unknown objective kind in " .. id)
			end
		end
		local r = q.Rewards or {}
		check(r.Weapon == nil or Items.Weapons[r.Weapon] ~= nil, "reward weapon exists: " .. id)
		check(r.Cosmetic == nil or Items.Cosmetics[r.Cosmetic] ~= nil, "reward cosmetic exists: " .. id)
	end
end

-- Skills
for _, treeId in ipairs(Skills.Order) do
	local tree = Skills.Trees[treeId]
	check(tree ~= nil, "tree exists " .. treeId)
	local slots = {}
	for nodeId, node in pairs(tree.Nodes) do
		local slot = node.Tier .. ":" .. node.Column
		check(not slots[slot], "unique node slot " .. treeId .. " " .. slot)
		slots[slot] = true
		for _, req in ipairs(node.Requires or {}) do
			check(tree.Nodes[req] ~= nil, "skill req exists " .. nodeId)
		end
		check(node.Ability == nil or Abilities[node.Ability] ~= nil, "ability exists " .. nodeId)
		for stat in pairs(node.Effects or {}) do
			local s = Stats.Compute({ Level = 1, Skills = {}, EquippedWeapon = "IronSword" })
			check(type(s[stat]) == "number", "effect stat is valid: " .. stat)
		end
	end
end

-- Items <-> products
local productKeys = {}
for _, list in ipairs({ Products.DevProducts, Products.GamePasses }) do
	for _, p in ipairs(list) do
		productKeys[p.Key] = true
		check(p.Grant.Weapon == nil or Items.Weapons[p.Grant.Weapon] ~= nil, "product weapon exists " .. p.Key)
		check(p.Grant.Cosmetic == nil or Items.Cosmetics[p.Grant.Cosmetic] ~= nil, "product cosmetic exists " .. p.Key)
	end
end
for id, w in pairs(Items.Weapons) do
	check(w.Premium == nil or productKeys[w.Premium], "premium weapon has product " .. id)
	check(w.Price == nil or w.Premium == nil, "weapon not both gold and premium " .. id)
end
for id, c in pairs(Items.Cosmetics) do
	check(c.Premium == nil or productKeys[c.Premium], "premium cosmetic has product " .. id)
end
for _, entry in ipairs(GameConfig.RenownTitles) do
	local found = false
	for _, c in pairs(Items.Cosmetics) do
		if c.Slot == "Title" and c.Name == entry.Title then
			found = true
		end
	end
	check(found, "renown title cosmetic exists " .. entry.Title)
end

-- Enemies / zones
for zoneId, zone in pairs(World.Zones) do
	for _, s in ipairs(zone.Spawns) do
		check(Enemies[s.Enemy] ~= nil, "zone enemy exists " .. zoneId)
	end
end
for id, e in pairs(Enemies) do
	for m in pairs(e.Drops or {}) do
		check(Items.Materials[m] ~= nil, "drop exists " .. id .. " " .. m)
	end
end

-- Stats & skill rules
local data = {
	Level = 1,
	XP = 0,
	Gold = 0,
	SkillPoints = 1,
	Skills = {},
	EquippedWeapon = "IronSword",
	Materials = {},
	Quests = { Active = {}, Completed = {} },
	Bounties = { Defs = {} },
}
local ok = Stats.CanUnlock(data, "IronSkin")
check(ok, "can unlock tier 1")
ok = Stats.CanUnlock(data, "Bloodthirst")
check(not ok, "tier 2 locked at lv1")
data.Level = 3
ok = Stats.CanUnlock(data, "Bloodthirst")
check(not ok, "bloodthirst needs IronSkin")
data.Skills.IronSkin = 3
data.SkillPoints = 1
ok = Stats.CanUnlock(data, "IronSkin")
check(not ok, "maxed")
check(Stats.CanUnlock(data, "Bloodthirst"), "bloodthirst unlockable")
local st = Stats.Compute(data)
check(st.MaxHealth == GameConfig.BaseHealth + GameConfig.HealthPerLevel * 2 + 45, "max health with Iron Skin")
data.Skills.Whirlwind = 1
check(Stats.Compute(data).Abilities.Whirlwind, "ability flag")

-- Quest rules
data.Level = 1
check(QuestRules.CanAccept(data, "MQ1"), "MQ1 acceptable")
check(not QuestRules.CanAccept(data, "MQ2"), "MQ2 locked before MQ1")
data.Quests.Completed.MQ1 = true
local offers = QuestRules.OffersFor(data, "Elder")
check(#offers == 1 and offers[1] == "MQ2", "Elder offers MQ2")
data.Quests.Active.SQ_Pelts = { Progress = { 0 } }
check(not QuestRules.IsReady(data, "SQ_Pelts"), "pelts not ready")
data.Materials.WolfPelt = 5
check(QuestRules.IsReady(data, "SQ_Pelts"), "pelts ready from inventory")
check(QuestRules.GetProgress(data, "SQ_Pelts", 1) == 4, "collect progress capped")

-- Bounty generation across levels and seeds
local Services = {}
local BountyService = require(setmetatable({ Path = "Server/Services/BountyService" }, getmetatable(Shared)))
BountyService.Init(Services)
local kinds = {}
for level = 1, 50 do
	for seed = 1, 40 do
		local def = BountyService.Generate(level, Random.new(seed * 7919 + level), 1, seed % 5 == 0)
		local o = def.Objectives[1]
		kinds[o.Kind] = (kinds[o.Kind] or 0) + 1
		check(not def.Name:find("{"), "name filled: " .. def.Name)
		check(not def.Description:find("{"), "description filled: " .. def.Description)
		check(o.Count >= 1, "count positive")
		check(def.Rewards.XP > 0 and def.Rewards.Gold > 0, "rewards positive")
		if o.Kind == "Kill" then
			check(
				Enemies[o.Target] and Enemies[o.Target].Level <= level + 1,
				"kill target level-appropriate L" .. level
			)
		else
			check(Items.Materials[o.Target] ~= nil, "gather material exists")
		end
	end
end
check((kinds.Kill or 0) > 0 and (kinds.Collect or 0) > 0, "both bounty kinds generated")

-- New systems: crafting, property, story, races, quests events
local Crafting = require(Shared.Config.Crafting)
local Property = require(Shared.Config.Property)
local Story = require(Shared.Config.Story)
local Races = require(Shared.Config.Races)
local Gov = require(Shared.Config.Government)
local CraftingRules = require(Shared.CraftingRules)

local function materialExists(id, label)
	check(id == "Gold" or Items.Materials[id] ~= nil, label .. ": material " .. tostring(id))
end
for _, recipe in ipairs(Crafting.Recipes) do
	check(Crafting.StationNames[recipe.Station] ~= nil, "recipe station " .. recipe.Id)
	for id in pairs(recipe.Inputs) do
		materialExists(id, "recipe " .. recipe.Id)
	end
	local out = recipe.Output
	check(
		(out.Material and Items.Materials[out.Material] ~= nil)
			or (out.Weapon and Items.Weapons[out.Weapon] ~= nil)
			or (out.Cosmetic and Items.Cosmetics[out.Cosmetic] ~= nil)
			or (out.Food and Crafting.Foods[out.Food] ~= nil),
		"recipe output exists " .. recipe.Id
	)
end
for id, infusion in pairs(Crafting.Infusions) do
	for m in pairs(infusion.Inputs) do
		materialExists(m, "infusion " .. id)
	end
end
for level = 1, Crafting.Temper.MaxLevel do
	for m in pairs(Crafting.Temper.Cost(level)) do
		materialExists(m, "temper cost")
	end
end
for id, food in pairs(Crafting.Foods) do
	for effect in pairs(food.Effects) do
		check(Crafting.Effects[effect] ~= nil, "food effect " .. id .. " " .. effect)
	end
end
-- Every ingredient effect is real, and every effect can actually be brewed (appears in 2+ ingredients).
local effectCount = {}
for id, m in pairs(Items.Materials) do
	if m.Effects then
		check(#m.Effects == 3, "ingredient has 3 effects " .. id)
		for _, e in ipairs(m.Effects) do
			check(Crafting.Effects[e] ~= nil, "ingredient effect exists " .. id .. " " .. e)
			effectCount[e] = (effectCount[e] or 0) + 1
		end
	end
end
for effectId in pairs(Crafting.Effects) do
	check((effectCount[effectId] or 0) >= 2, "effect is brewable " .. effectId)
end
-- Potion mixing
local fx = CraftingRules.SharedEffects({ "Moonpetal", "Bloodthistle" })
check(#fx == 1 and fx[1] == "RestoreHealth", "moonpetal + bloodthistle = restore health")
check(#CraftingRules.SharedEffects({ "WolfPelt", "Moonpetal" }) == 0, "non-ingredient adds nothing")
local key = CraftingRules.PotionKey({ "FortifyDamage", "RestoreHealth" }, 2)
local info = CraftingRules.Describe(key)
check(
	info and #info.Effects == 2 and info.Name:find("Elixir") ~= nil,
	"describe elixir " .. tostring(info and info.Name)
)
check(CraftingRules.Describe("F:Bread") ~= nil, "describe food")
check(CraftingRules.Describe("P:Nonsense:1") == nil, "reject bad potion key")
check(CraftingRules.Describe("garbage") == nil, "reject garbage key")

for id, crop in pairs(Property.Crops) do
	if id ~= "Order" then
		check(Items.Materials[crop.Seed] ~= nil, "crop seed exists " .. id)
		check(Items.Materials[id] ~= nil, "crop harvest material exists " .. id)
	end
end
for _, id in ipairs(Property.Crops.Order) do
	check(Property.Crops[id] ~= nil, "crop order " .. id)
end
for _, id in ipairs(Property.Animals.Order) do
	check(Items.Materials[Property.Animals[id].Produces] ~= nil, "animal product exists " .. id)
end
for _, id in ipairs(Property.Homes.Order) do
	for _, station in ipairs(Property.Homes[id].Stations) do
		check(Crafting.StationNames[station] ~= nil, "home station " .. id)
	end
end
for i, a in ipairs(Property.Plots) do
	for j, b in ipairs(Property.Plots) do
		if i < j then
			check((a - b).Magnitude >= Property.PlotSize, "plots don't overlap " .. i .. "," .. j)
		end
	end
end

local EVENTS = {
	Gather = 1,
	Brew = 1,
	Cook = 1,
	Craft = 1,
	Smelt = 1,
	Temper = 1,
	Infuse = 1,
	Harvest = 1,
	Discover = 1,
	BuyHome = 1,
	BuyAnimal = 1,
	BuyHorse = 1,
	Vote = 1,
}
for id, q in pairs(Quests) do
	if type(q) == "table" and id ~= "Order" then
		for _, o in ipairs(q.Objectives) do
			if o.Kind == "Event" then
				check(EVENTS[o.Target] ~= nil, "quest event valid " .. id .. " " .. o.Target)
			end
		end
		for m in pairs((q.Rewards or {}).Materials or {}) do
			materialExists(m, "quest reward " .. id)
		end
	end
end
for questId, echoId in pairs(Story.QuestEchoes) do
	check(Quests[questId] ~= nil, "echo quest exists " .. questId)
	check(Story.Cutscenes[echoId] ~= nil, "echo cutscene exists " .. echoId)
end
for id, cutscene in pairs(Story.Cutscenes) do
	for i, shot in ipairs(cutscene.Shots) do
		check(shot.Black or (shot.From and shot.To), "shot has camera " .. id .. "#" .. i)
		check(type(shot.Duration) == "number", "shot duration " .. id .. "#" .. i)
	end
end
for _, raceId in ipairs(Races.Order) do
	local race = Races.Races[raceId]
	check(race ~= nil and #race.SkinTones > 0, "race " .. raceId)
	local st = Stats.Compute({ Level = 1, Skills = {}, EquippedWeapon = "IronSword", Appearance = { Race = raceId } })
	for stat in pairs(race.Bonus) do
		check(type(st[stat]) == "number", "race bonus stat " .. raceId .. " " .. stat)
	end
end
check(
	Races.Hair.Styles[Races.Default.Hair] ~= nil and Races.Races[Races.Default.Race] ~= nil,
	"default appearance valid"
)
for _, list in ipairs({ Products.DevProducts, Products.GamePasses }) do
	for _, p in ipairs(list) do
		check(p.Grant.Horse == nil or Property.Horses[p.Grant.Horse] ~= nil, "product horse exists " .. p.Key)
	end
end
for _, d in ipairs(Gov.Decrees.Order) do
	check(Gov.Decrees[d] ~= nil, "decree " .. d)
end
for npcId in pairs(World.NPCs) do
	check(World.NPCs[npcId].Name ~= nil, "npc named " .. npcId)
end
-- Buffs feed stats and expire
local buffed = {
	Level = 1,
	Skills = {},
	EquippedWeapon = "IronSword",
	Buffs = { Vigor = { Until = workspace:GetServerTimeNow() + 60, Magnitude = 25 } },
}
local base = Stats.Compute({ Level = 1, Skills = {}, EquippedWeapon = "IronSword" }).MaxHealth
check(Stats.Compute(buffed).MaxHealth == base + 25, "vigor buff adds health")
check(Stats.Compute(buffed, workspace:GetServerTimeNow() + 61).MaxHealth == base, "buff expires")
local tempered = {
	Level = 1,
	Skills = {},
	EquippedWeapon = "IronSword",
	Crafting = { Temper = { IronSword = 2 }, Infusions = { IronSword = "Vampiric" } },
}
local ts = Stats.Compute(tempered)
check(math.abs(ts.WeaponDamage - 12 * 1.16) < 0.01, "temper adds damage")
check(math.abs(ts.Lifesteal - 0.05) < 1e-6, "vampiric infusion lifesteal")

print("Sample bounties:")
for _, level in ipairs({ 1, 4, 8, 15 }) do
	local def = BountyService.Generate(level, Random.new(level * 31), 1, false)
	print(
		string.format(
			"  Lv%-2d %-28s | %s | %d XP, %d gold",
			level,
			def.Name,
			def.Description,
			def.Rewards.XP,
			def.Rewards.Gold
		)
	)
end
print(
	"XP curve: "
		.. Leveling.XPToNext(1)
		.. ", "
		.. Leveling.XPToNext(5)
		.. ", "
		.. Leveling.XPToNext(10)
		.. ", "
		.. Leveling.XPToNext(25)
)
summary()
