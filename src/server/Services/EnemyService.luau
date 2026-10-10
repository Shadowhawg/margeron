-- Spawns enemies in each zone, runs their AI, and hands out rewards when they die.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Items = require(Shared.Config.Items)
local World = require(Shared.Config.World)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local ModelBuilder = require(script.Parent.Parent.Lib.ModelBuilder)

local EnemyService = {}
local Services

local AI_TICK = 0.2
local LEASH_EXTRA = 50

local folder
local active = {} -- [Model] = enemy state
local zoneCounts = {} -- [zoneId][enemyId] = alive count

local function setBar(e)
	local fill = e.Bar and e.Bar:FindFirstChild("Fill", true)
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(e.HP / e.MaxHP, 0, 1), 1)
	end
end

local function buildHealthBar(e)
	local def = e.Def
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(170, 38)
	gui.StudsOffset = Vector3.new(0, e.Info.Height - e.Info.GroundOffset + 1.5, 0)
	gui.MaxDistance = def.Boss and 200 or 70
	gui.LightInfluence = 0
	gui.Adornee = e.Root

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextStrokeTransparency = 0.4
	name.TextColor3 = def.Elite and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 235, 235)
	name.Text = "Lv " .. def.Level .. "  " .. def.Name
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(10, 24)
	back.Size = UDim2.new(1, -20, 0, 9)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill

	gui.Parent = e.Root
	e.Bar = gui
end

local function randomPointInZone(zoneId)
	local zone = World.Zones[zoneId]
	local center = Services.WorldService.GetZonePosition(zoneId)
	local r = math.sqrt(math.random()) * zone.Radius * 0.8
	local a = math.random() * math.pi * 2
	return Services.WorldService.GroundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
end

local spawnEnemy

local function scheduleRespawn(zoneId, enemyId)
	local zone = World.Zones[zoneId]
	local delay = Enemies[enemyId].RespawnTime or zone.RespawnTime
	task.delay(delay, function()
		spawnEnemy(zoneId, enemyId)
	end)
end

function spawnEnemy(zoneId, enemyId)
	local def = Enemies[enemyId]
	local isWyrm = enemyId == "AshenWyrmling"
	local model, info = ModelBuilder.Creature(def.Name, {
		Shape = def.Shape,
		Scale = def.Scale,
		Color = def.Color,
		Wings = isWyrm,
		EyeColor = isWyrm and Color3.fromRGB(255, 140, 30)
			or (enemyId == "Skeleton" and Color3.fromRGB(120, 200, 255) or nil),
	})
	local ground = randomPointInZone(zoneId)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, info.GroundOffset + 0.5, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model:SetAttribute("EnemyId", enemyId)
	model.Parent = folder
	info.Root:SetNetworkOwner(nil)
	info.Humanoid.WalkSpeed = def.WalkSpeed

	local e = {
		Id = enemyId,
		Def = def,
		ZoneId = zoneId,
		Model = model,
		Root = info.Root,
		Humanoid = info.Humanoid,
		Info = info,
		Home = ground,
		HP = def.Health,
		MaxHP = def.Health,
		Target = nil,
		LastAttack = 0,
		LastSpecial = os.clock(),
		Busy = false,
		Dead = false,
		Damagers = {},
		LastDamaged = 0,
	}
	buildHealthBar(e)
	active[model] = e
	zoneCounts[zoneId][enemyId] = (zoneCounts[zoneId][enemyId] or 0) + 1
	if def.Boss then
		for _, player in ipairs(Players:GetPlayers()) do
			Services.PlayerService.Notify(player, def.Name .. " has appeared at " .. World.Zones[zoneId].Name .. "!", "Boss")
		end
	end
	return e
end

local function playerRoot(player)
	local humanoid, character = Services.PlayerService.GetHumanoid(player)
	if humanoid then
		return character:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

local function nearestPlayer(position, range)
	local best, bestDist = nil, range
	for _, player in ipairs(Players:GetPlayers()) do
		local root = playerRoot(player)
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

local function reach(e)
	return e.Def.AttackRange + e.Info.BodyRadius
end

local function face(e, position)
	local rootPos = e.Root.Position
	local flat = Vector3.new(position.X, rootPos.Y, position.Z)
	if (flat - rootPos).Magnitude > 0.1 then
		e.Root.CFrame = CFrame.lookAt(rootPos, flat)
	end
end

local function basicAttack(e, player)
	e.Busy = true
	e.LastAttack = os.clock()
	e.Humanoid:MoveTo(e.Root.Position)
	local root = playerRoot(player)
	if root then
		face(e, root.Position)
	end
	Remotes.Effect:FireAllClients("Windup", e.Model, e.Def.Windup)
	task.delay(e.Def.Windup, function()
		e.Busy = false
		if e.Dead then
			return
		end
		local targetRoot = playerRoot(player)
		if targetRoot and (targetRoot.Position - e.Root.Position).Magnitude <= reach(e) + 2.5 then
			Services.CombatService.DamagePlayer(player, e.Def.Damage, e)
		end
	end)
end

local function specialAttack(e)
	local special = e.Def.Special
	e.Busy = true
	e.LastSpecial = os.clock()
	e.Humanoid:MoveTo(e.Root.Position)
	local targetRoot = e.Target and playerRoot(e.Target)
	if targetRoot then
		face(e, targetRoot.Position)
	end

	local groundY = e.Root.Position.Y - e.Info.GroundOffset
	local center = e.Root.Position + e.Root.CFrame.LookVector * (special.Offset or 0)
	center = Vector3.new(center.X, groundY + 0.15, center.Z)

	local telegraph = ModelBuilder.Part({
		Name = "Telegraph",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, special.Radius * 2, special.Radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 60, 30),
		Material = Enum.Material.Neon,
		Transparency = 0.65,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	telegraph.Parent = workspace
	Remotes.Effect:FireAllClients("Windup", e.Model, special.Windup)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = playerRoot(player)
		if root and (root.Position - center).Magnitude < 80 then
			Services.PlayerService.Notify(player, e.Def.Name .. " prepares " .. special.Name .. "! Get out of the red!", "Warning")
		end
	end

	task.delay(special.Windup, function()
		telegraph:Destroy()
		e.Busy = false
		if e.Dead then
			return
		end
		Remotes.Effect:FireAllClients("Burst", center, special.Radius, Color3.fromRGB(255, 110, 40))
		for _, player in ipairs(Players:GetPlayers()) do
			local root = playerRoot(player)
			if root and Util.FlatDistance(root.Position, center) <= special.Radius + 1 then
				Services.CombatService.DamagePlayer(player, special.Damage, e)
			end
		end
	end)
end

local function resetEnemy(e)
	e.Target = nil
	e.Damagers = {}
	e.HP = e.MaxHP
	e.Burn = nil
	setBar(e)
end

local function tickEnemy(e, now)
	if e.Dead or e.Busy then
		return
	end
	local def = e.Def
	local rootPos = e.Root.Position
	local zone = World.Zones[e.ZoneId]
	local leash = zone.Radius + LEASH_EXTRA

	-- Drop targets that died, left or dragged us too far from home.
	if e.Target then
		local root = playerRoot(e.Target)
		if
			not root
			or (root.Position - rootPos).Magnitude > def.AggroRange * 2
			or Util.FlatDistance(rootPos, e.Home) > leash
		then
			e.Target = nil
		end
	end
	if not e.Target then
		e.Target = nearestPlayer(rootPos, def.AggroRange)
	end

	if e.Target then
		local root = playerRoot(e.Target)
		local dist = (root.Position - rootPos).Magnitude
		local special = def.Special
		if special and now - e.LastSpecial >= special.Cooldown and dist <= special.Radius + (special.Offset or 0) then
			specialAttack(e)
		elseif dist <= reach(e) then
			if now - e.LastAttack >= def.AttackCooldown then
				basicAttack(e, e.Target)
			else
				face(e, root.Position)
			end
		else
			e.Humanoid:MoveTo(root.Position)
		end
	else
		local homeDist = Util.FlatDistance(rootPos, e.Home)
		if homeDist > 6 then
			e.Humanoid:MoveTo(e.Home)
			if next(e.Damagers) and now - e.LastDamaged > 4 then
				resetEnemy(e) -- walked home without finishing the fight: heal up
			end
		elseif math.random() < 0.03 then
			local wander = e.Home + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
			e.Humanoid:MoveTo(wander)
		end
	end

	-- Burning (Conflagration)
	if e.Burn then
		if now >= e.Burn.Until or not e.Burn.Player.Parent then
			e.Burn = nil
			local fire = e.Root:FindFirstChild("BurnFire")
			if fire then
				fire:Destroy()
			end
		elseif now >= e.Burn.NextTick then
			e.Burn.NextTick = now + 0.5
			EnemyService.Damage(e, e.Burn.PerTick, e.Burn.Player, false)
		end
	end
end

local function rewardPlayers(e)
	local def = e.Def
	for player in pairs(e.Damagers) do
		local root = playerRoot(player)
		local data = Services.PlayerService.GetData(player)
		if player.Parent and data and root and (root.Position - e.Root.Position).Magnitude <= GameConfig.XPShareRadius then
			local gold = math.random(def.Gold[1], def.Gold[2])
			local parts = { "+" .. def.XP .. " XP", "+" .. gold .. " gold" }
			data.Stats.Kills += 1
			Services.PlayerService.AddGold(player, gold)
			for materialId, chance in pairs(def.Drops or {}) do
				if math.random() < chance then
					Services.InventoryService.AddMaterial(player, materialId, 1)
					table.insert(parts, "+" .. Items.Materials[materialId].Name)
				end
			end
			Remotes.Effect:FireClient(player, "Loot", e.Root.Position, table.concat(parts, "   "))
			Services.QuestService.OnEnemyKilled(player, e.Id)
			Services.PlayerService.AddXP(player, def.XP)
		end
	end
end

local function kill(e, killer)
	e.Dead = true
	active[e.Model] = nil
	zoneCounts[e.ZoneId][e.Id] -= 1
	rewardPlayers(e)
	Services.CombatService.OnEnemyKilled(killer, e)
	if e.Def.Boss then
		for _, player in ipairs(Players:GetPlayers()) do
			Services.PlayerService.Notify(player, e.Def.Name .. " has been slain!", "Boss")
		end
	end

	if e.Bar then
		e.Bar:Destroy()
	end
	e.Humanoid:MoveTo(e.Root.Position)
	e.Root.Anchored = true
	for _, descendant in ipairs(e.Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			TweenService:Create(descendant, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(e.Root, TweenInfo.new(1.2), { CFrame = e.Root.CFrame * CFrame.Angles(0, 0, math.rad(80)) - Vector3.new(0, 1, 0) }):Play()
	task.delay(1.5, function()
		e.Model:Destroy()
	end)
	scheduleRespawn(e.ZoneId, e.Id)
end

-- Public: deal damage to an enemy. Returns damageDealt, killed.
function EnemyService.Damage(e, amount, player, crit)
	if e.Dead then
		return 0, false
	end
	amount = math.max(1, math.floor(amount))
	e.HP -= amount
	e.LastDamaged = os.clock()
	e.Damagers[player] = (e.Damagers[player] or 0) + amount
	if not e.Target then
		e.Target = player
	end
	setBar(e)
	Remotes.Effect:FireClient(player, "DamageNumber", e.Root.Position + Vector3.new(0, e.Info.Height / 2, 0), amount, crit)
	if e.HP <= 0 then
		kill(e, player)
		return amount, true
	end
	return amount, false
end

function EnemyService.ApplyBurn(e, totalDamage, duration, player)
	if e.Dead then
		return
	end
	local ticks = math.max(1, math.floor(duration / 0.5))
	e.Burn = {
		PerTick = math.max(1, totalDamage / ticks),
		Until = os.clock() + duration,
		NextTick = os.clock() + 0.5,
		Player = player,
	}
	if not e.Root:FindFirstChild("BurnFire") then
		local fire = Instance.new("Fire")
		fire.Name = "BurnFire"
		fire.Size = 4
		fire.Parent = e.Root
	end
end

-- Enemies whose body is within radius of position (flat distance).
function EnemyService.InRadius(position, radius)
	local list = {}
	for _, e in pairs(active) do
		if not e.Dead and Util.FlatDistance(e.Root.Position, position) <= radius + e.Info.BodyRadius then
			table.insert(list, e)
		end
	end
	return list
end

function EnemyService.FromPart(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	return model and active[model]
end

function EnemyService.Folder()
	return folder
end

function EnemyService.Init(services)
	Services = services
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
end

function EnemyService.Start()
	for zoneId, zone in pairs(World.Zones) do
		zoneCounts[zoneId] = {}
		for _, spawnInfo in ipairs(zone.Spawns) do
			for _ = 1, spawnInfo.Count do
				spawnEnemy(zoneId, spawnInfo.Enemy)
			end
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < AI_TICK then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, e in pairs(active) do
			local ok, err = pcall(tickEnemy, e, now)
			if not ok then
				warn("[EnemyService] AI error:", err)
			end
		end
	end)
end

return EnemyService
