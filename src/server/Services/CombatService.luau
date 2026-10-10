-- Player attacks, abilities and damage to players. Everything is validated server-side:
-- the client only says "I swung, facing this way" and the server decides what got hit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local Remotes = require(Shared.Remotes)

local CombatService = {}
local Services

local MAX_MELEE_TARGETS = { Sword = 3, Axe = 4, Dagger = 1 }
local LATENCY_TOLERANCE = 0.12
local REACH_TOLERANCE = 2 -- enemies keep moving while the swing travels over the network

local lastUsed = {} -- [Player] = { [actionName] = os.clock() }
local lastCombat = {} -- [Player] = os.clock() of the last hit dealt or taken
local empoweredUntil = {} -- [Player] = os.clock() (Shadowstep guaranteed crit)
local wardReadyAt = {} -- [Player] = os.clock()

local function validDirection(dir)
	if typeof(dir) ~= "Vector3" then
		return nil
	end
	if dir.Magnitude < 0.01 or dir.Magnitude ~= dir.Magnitude or dir.Magnitude > 1e3 then
		return nil
	end
	return dir.Unit
end

local function cooldownReady(player, action, cooldown)
	local used = lastUsed[player]
	if not used then
		used = {}
		lastUsed[player] = used
	end
	local now = os.clock()
	if now - (used[action] or 0) < cooldown - LATENCY_TOLERANCE then
		return false
	end
	used[action] = now
	return true
end

local function lowHealth(humanoid)
	return humanoid.Health / humanoid.MaxHealth < 0.3
end

-- Applies the player's stats to a hit and deals it. Returns damage dealt.
local function hit(player, e, baseDamage, kind)
	local stats = Services.PlayerService.GetStats(player)
	local humanoid = Services.PlayerService.GetHumanoid(player)
	if not stats or not humanoid then
		return 0
	end

	local damage = baseDamage * (kind == "Spell" and stats.SpellPower or stats.PhysicalDamage)
	if stats.Flags.LastStand and lowHealth(humanoid) then
		damage *= 1.3
	end
	if stats.BackstabBonus > 0 and e.Target ~= player then
		damage *= 1 + stats.BackstabBonus
	end
	-- Sneak attack: crouched and the enemy hasn't noticed you.
	if Services.StealthService.IsCrouching(player) and e.Target == nil then
		damage *= Services.StealthService.SneakAttackMultiplier
		Remotes.Effect:FireClient(player, "Text", "Sneak attack! x" .. Services.StealthService.SneakAttackMultiplier)
	end

	local crit = false
	if (empoweredUntil[player] or 0) > os.clock() then
		crit = true
		empoweredUntil[player] = nil
	elseif math.random() < stats.CritChance then
		crit = true
	end
	if crit then
		damage *= stats.CritDamage
	end
	damage *= 0.9 + math.random() * 0.2

	local dealt, killed = Services.EnemyService.Damage(e, damage, player, crit)
	lastCombat[player] = os.clock()
	if stats.Lifesteal > 0 and dealt > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * stats.Lifesteal)
	end
	-- Weapon infusions
	if dealt > 0 and not killed then
		if stats.Infusion == "Ember" then
			Services.EnemyService.ApplyDot(e, dealt * 0.25, 3, player, "Fire")
		elseif stats.Infusion == "Venom" then
			Services.EnemyService.ApplyDot(e, dealt * 0.3, 4, player, "Poison")
		elseif stats.Infusion == "Frost" then
			Services.EnemyService.ApplySlow(e, 2)
		end
	end
	return dealt
end

function CombatService.InCombat(player)
	return os.clock() - (lastCombat[player] or 0) < 6
end

local function castRay(origin, direction, range)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local generated = workspace:FindFirstChild("GeneratedWorld")
	if generated then
		-- Leaves and other decoration shouldn't block bolts; trunks/walls are fine to ignore too
		-- for a forgiving feel.
		table.insert(exclude, generated)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Spherecast(origin, 1.2, direction * range, params)
	if result then
		return result.Position, Services.EnemyService.FromPart(result.Instance)
	end
	return origin + direction * range, nil
end

function CombatService.Attack(player, aim)
	local direction = validDirection(aim)
	local stats = Services.PlayerService.GetStats(player)
	local humanoid, character = Services.PlayerService.GetHumanoid(player)
	if not direction or not stats or not humanoid then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local weapon = stats.Weapon
	if not root then
		return
	end
	-- Attacking with the weapon sheathed draws it first (like Skyrim); the next click swings.
	local tool = Services.AppearanceService.WeaponTool(player)
	if not tool then
		Services.PropertyService.Dismount(player)
		Services.AppearanceService.SetWeaponDrawn(player, true)
		return
	end
	if not cooldownReady(player, "Attack", weapon.Cooldown) then
		return
	end
	Services.PropertyService.Dismount(player)

	-- The default Animate script plays its slash/lunge animation when a "toolanim" value appears
	-- in the held tool. It runs on every client, so everyone sees the swing.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = (weapon.Type == "Dagger" or weapon.Type == "Staff") and "Lunge" or "Slash"
	anim.Parent = tool
	Remotes.Effect:FireAllClients("Swing", character, weapon.Type)

	if weapon.Type == "Staff" then
		local origin = root.Position + Vector3.new(0, 1.5, 0)
		local hitPos, e = castRay(origin, direction, weapon.Range)
		Remotes.Effect:FireAllClients("Bolt", origin, hitPos, weapon.Glow or weapon.Color, 0.6)
		if e then
			hit(player, e, stats.WeaponDamage, "Spell")
		end
		return
	end

	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or root.CFrame.LookVector
	local candidates = {}
	-- A generous arc (~200 degrees in front). Normal hits don't knock enemies back: shoving them
	-- out of reach after every swing made fights feel broken.
	for _, e in ipairs(Services.EnemyService.InRadius(root.Position, weapon.Range + REACH_TOLERANCE)) do
		local offset = e.Root.Position - root.Position
		offset = Vector3.new(offset.X, 0, offset.Z)
		local inFront = offset.Magnitude < e.Info.BodyRadius + 2 or flat:Dot(offset.Unit) > -0.15
		if inFront and math.abs(e.Root.Position.Y - root.Position.Y) < 12 + e.Info.Height / 2 then
			table.insert(candidates, { E = e, Dist = offset.Magnitude })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Dist < b.Dist
	end)
	for i = 1, math.min(#candidates, MAX_MELEE_TARGETS[weapon.Type] or 2) do
		hit(player, candidates[i].E, stats.WeaponDamage, "Physical")
	end
end

local abilityHandlers = {}

function abilityHandlers.Whirlwind(player, stats, root)
	local ability = Abilities.Whirlwind
	Remotes.Effect:FireAllClients("Burst", root.Position - Vector3.new(0, 2.5, 0), ability.Radius, ability.Color)
	Remotes.Effect:FireAllClients("Spin", player.Character)
	for _, e in ipairs(Services.EnemyService.InRadius(root.Position, ability.Radius)) do
		hit(player, e, stats.WeaponDamage * ability.WeaponMultiplier, "Physical")
		Services.EnemyService.Knockback(e, e.Root.Position - root.Position, 20)
	end
end

function abilityHandlers.Firebolt(player, stats, root, direction, data)
	local ability = Abilities.Firebolt
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local hitPos = castRay(origin, direction, ability.Range)
	Remotes.Effect:FireAllClients("Bolt", origin, hitPos, ability.Color, 1.6)
	Remotes.Effect:FireAllClients("Burst", hitPos, ability.SplashRadius, ability.Color)
	local base = ability.BaseDamage + ability.DamagePerLevel * (data.Level - 1)
	for _, e in ipairs(Services.EnemyService.InRadius(hitPos, ability.SplashRadius)) do
		local dealt = hit(player, e, base, "Spell")
		if stats.Flags.Conflagration and dealt > 0 then
			Services.EnemyService.ApplyBurn(e, dealt * 0.6, 3, player)
		end
	end
end

function abilityHandlers.Shadowstep(player, _stats, root)
	local ability = Abilities.Shadowstep
	empoweredUntil[player] = os.clock() + ability.EmpowerDuration
	Remotes.Effect:FireAllClients("Burst", root.Position - Vector3.new(0, 2.5, 0), 5, ability.Color)
	-- The dash itself is performed by the client (it owns its character's physics).
end

function CombatService.UseAbility(player, abilityId, aim)
	local ability = Abilities[abilityId]
	local handler = abilityHandlers[abilityId]
	local stats = Services.PlayerService.GetStats(player)
	local data = Services.PlayerService.GetData(player)
	local humanoid, character = Services.PlayerService.GetHumanoid(player)
	local direction = validDirection(aim)
	if not ability or not handler or not stats or not humanoid or not direction then
		return { ok = false }
	end
	if not stats.Abilities[abilityId] then
		return { ok = false, message = "You haven't learned " .. ability.Name .. "." }
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local cooldown = ability.Cooldown * (1 - stats.CooldownReduction)
	if not root or not cooldownReady(player, abilityId, cooldown) then
		return { ok = false }
	end

	Services.PropertyService.Dismount(player)
	Services.AppearanceService.SetWeaponDrawn(player, true)
	handler(player, stats, root, direction, data)

	if stats.Flags.ArcaneEcho and math.random() < 0.25 then
		lastUsed[player][abilityId] = 0
		Remotes.Effect:FireClient(player, "Text", "Arcane Echo!")
		return { ok = true, cooldown = 0 }
	end
	return { ok = true, cooldown = cooldown }
end

-- Called by EnemyService when an enemy dies.
function CombatService.OnEnemyKilled(killer, _e)
	if not killer or not killer.Parent then
		return
	end
	local stats = Services.PlayerService.GetStats(killer)
	if stats and stats.Flags.Assassinate then
		local humanoid = Services.PlayerService.GetHumanoid(killer)
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.1)
		end
		if lastUsed[killer] then
			lastUsed[killer].Shadowstep = 0
		end
		Remotes.Effect:FireClient(killer, "CooldownReset", "Shadowstep")
	end
end

function CombatService.DamagePlayer(player, amount, _sourceEnemy)
	local humanoid, character = Services.PlayerService.GetHumanoid(player)
	local stats = Services.PlayerService.GetStats(player)
	local data = Services.PlayerService.GetData(player)
	if not humanoid or not stats or not data then
		return
	end
	if character:FindFirstChildOfClass("ForceField") then
		return
	end

	local damage = amount * (1 - stats.DamageReduction)
	if stats.Flags.LastStand and lowHealth(humanoid) then
		damage *= 0.7
	end
	if stats.Flags.ArcaneWard and os.clock() >= (wardReadyAt[player] or 0) then
		local absorbed = math.min(damage, 20 + 3 * data.Level)
		damage -= absorbed
		wardReadyAt[player] = os.clock() + 12
		Remotes.Effect:FireAllClients("Ward", character)
	end
	damage = math.floor(damage + 0.5)
	lastCombat[player] = os.clock()
	if damage > 0 then
		humanoid:TakeDamage(damage)
		Remotes.Effect:FireClient(player, "Hurt", damage)
	end
end

function CombatService.Init(services)
	Services = services
	Remotes.Attack.OnServerEvent:Connect(function(player, aim)
		CombatService.Attack(player, aim)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUsed[player] = nil
		lastCombat[player] = nil
		empoweredUntil[player] = nil
		wardReadyAt[player] = nil
	end)
end

return CombatService
