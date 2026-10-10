-- The evergreen layer: a Bounty Board that keeps generating fresh contracts scaled to the
-- player's level, plus one Daily Contract shared by every player each day.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounties = require(Shared.Config.Bounties)
local Enemies = require(Shared.Config.Enemies)
local Items = require(Shared.Config.Items)
local World = require(Shared.Config.World)
local GameConfig = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)

local BountyService = {}
local Services

local REROLL_COST = 25

-- enemyId -> zone name, built from the world config
local enemyZone = {}
for _, zone in pairs(World.Zones) do
	for _, spawn in ipairs(zone.Spawns) do
		enemyZone[spawn.Enemy] = zone.Name
	end
end

local function today()
	return math.floor(os.time() / 86400)
end

local function fill(text, vars)
	return (text:gsub("{(%w+)}", function(name)
		return tostring(vars[name] or name)
	end))
end

local function eligibleEnemies(level, wantElite, needsDrops)
	local list = {}
	for enemyId, def in pairs(Enemies) do
		local inWorld = enemyZone[enemyId] ~= nil
		local levelOk = def.Level <= level + (wantElite and 1 or 2)
		local typeOk = (def.Elite == true) == wantElite
		local dropsOk = not needsDrops or (def.Drops and next(def.Drops) ~= nil)
		if inWorld and levelOk and typeOk and dropsOk then
			table.insert(list, enemyId)
		end
	end
	table.sort(list) -- deterministic order so seeded rolls are stable
	return list
end

-- Builds one bounty definition. rng is a Random object so results can be seeded.
function BountyService.Generate(level, rng, rewardScale, isDaily)
	local templates = Bounties.Templates
	local template, pool
	for _ = 1, 10 do
		template = templates[rng:NextInteger(1, #templates)]
		pool = eligibleEnemies(level, template.Kind == "Elite", template.Kind == "Gather")
		if #pool > 0 then
			break
		end
	end
	if #pool == 0 then
		template = templates[1]
		pool = eligibleEnemies(level, false, false)
	end

	-- Prefer enemies close to the player's level: pick from the top of the pool more often.
	table.sort(pool, function(a, b)
		return Enemies[a].Level > Enemies[b].Level
	end)
	local pick = pool[math.min(#pool, rng:NextInteger(1, math.min(#pool, 3)))]
	local enemy = Enemies[pick]

	local count = rng:NextInteger(template.Count[1], template.Count[2])
	local objective
	local material
	if template.Kind == "Gather" then
		local best, bestChance = nil, -1
		for materialId, chance in pairs(enemy.Drops) do
			if chance > bestChance then
				best, bestChance = materialId, chance
			end
		end
		material = Items.Materials[best].Name
		objective = { Kind = "Collect", Target = best, Count = count, Text = "Collect " .. material }
	else
		objective = { Kind = "Kill", Target = pick, Count = count, Text = "Defeat " .. Util.Pluralize(enemy.Name) }
	end

	-- Gather rewards account for drop chance (you need more kills on average).
	local effectiveKills = count
	if template.Kind == "Gather" then
		effectiveKills = count / math.max(enemy.Drops[objective.Target], 0.2)
	end
	local multiplier = template.RewardMultiplier * (rewardScale or 1)
	local avgGold = (enemy.Gold[1] + enemy.Gold[2]) / 2

	local vars = {
		enemy = enemy.Name,
		enemies = Util.Pluralize(enemy.Name),
		material = material,
		zone = enemyZone[pick],
		client = Bounties.Clients[rng:NextInteger(1, #Bounties.Clients)],
		count = count,
	}
	local name
	if isDaily then
		name = Bounties.DailyNames[rng:NextInteger(1, #Bounties.DailyNames)]
	else
		name = fill(template.Names[rng:NextInteger(1, #template.Names)], vars)
	end

	return {
		Name = name,
		Type = "Bounty",
		Daily = isDaily or nil,
		TurnIn = "Board",
		Description = fill(template.Description, vars),
		Objectives = { objective },
		Rewards = {
			XP = math.floor(enemy.XP * effectiveKills * multiplier),
			Gold = math.floor(avgGold * effectiveKills * multiplier + 10),
		},
	}
end

local function refreshBoardIfNeeded(player, data, force)
	local board = data.Bounties
	if force or #board.Board == 0 or os.time() - board.BoardRefreshedAt >= GameConfig.BountyBoardRefreshSeconds then
		local rng = Random.new(player.UserId + os.time())
		board.Board = {}
		for i = 1, GameConfig.BountyBoardSize do
			board.Board[i] = BountyService.Generate(data.Level, rng, 1, false)
		end
		board.BoardRefreshedAt = os.time()
		Services.PlayerService.Changed(player)
	end
end

local function dailyFor(data)
	-- Same seed for everyone today; scaled to the player's level bracket.
	local bracket = math.max(1, math.floor(data.Level / 3) * 3)
	local rng = Random.new(today() * 1000 + bracket)
	return BountyService.Generate(bracket, rng, GameConfig.DailyContractRewardMultiplier, true)
end

local function hasActiveDaily(data)
	for key in pairs(data.Quests.Active) do
		local def = data.Bounties.Defs[key]
		if def and def.Daily then
			return true
		end
	end
	return false
end

local function isNearBoard(player)
	local _, character = Services.PlayerService.GetHumanoid(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local position = Services.WorldService.GetNPCPosition("Board")
	return Util.FlatDistance(root.Position, position) <= GameConfig.NPCInteractDistance + 6
end

function BountyService.GetBoard(player)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return nil
	end
	refreshBoardIfNeeded(player, data, false)
	return {
		Offers = data.Bounties.Board,
		Daily = dailyFor(data),
		DailyAvailable = data.Bounties.DailyTakenDay ~= today() and not hasActiveDaily(data),
		RefreshIn = math.max(0, GameConfig.BountyBoardRefreshSeconds - (os.time() - data.Bounties.BoardRefreshedAt)),
		RerollCost = REROLL_COST,
		Active = Services.QuestService.CountActiveBounties(data),
		MaxActive = GameConfig.MaxActiveBounties,
	}
end

function BountyService.Accept(player, which)
	local data = Services.PlayerService.GetData(player)
	if not data or not isNearBoard(player) then
		return { ok = false, message = "You need to be at the Bounty Board." }
	end
	if Services.QuestService.CountActiveBounties(data) >= GameConfig.MaxActiveBounties then
		return { ok = false, message = "You can only hold " .. GameConfig.MaxActiveBounties .. " bounties at once." }
	end

	if which == "daily" then
		if data.Bounties.DailyTakenDay == today() or hasActiveDaily(data) then
			return { ok = false, message = "Come back tomorrow for a new contract." }
		end
		data.Bounties.DailyTakenDay = today()
		Services.QuestService.StartBounty(player, dailyFor(data))
	else
		local offer = type(which) == "number" and data.Bounties.Board[which]
		if not offer then
			return { ok = false, message = "That notice is gone." }
		end
		table.remove(data.Bounties.Board, which)
		Services.QuestService.StartBounty(player, offer)
	end
	return { ok = true, board = BountyService.GetBoard(player) }
end

function BountyService.Reroll(player)
	local data = Services.PlayerService.GetData(player)
	if not data or not isNearBoard(player) then
		return { ok = false, message = "You need to be at the Bounty Board." }
	end
	if not Services.PlayerService.SpendGold(player, REROLL_COST) then
		return { ok = false, message = "Not enough gold." }
	end
	refreshBoardIfNeeded(player, data, true)
	return { ok = true, board = BountyService.GetBoard(player) }
end

function BountyService.Init(services)
	Services = services
end

return BountyService
