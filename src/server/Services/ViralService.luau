--!strict
-- Viral Moments: every ViralInterval seconds a glowing beam spawns at a random spawn
-- point for ViralDuration seconds. Posting while standing inside it gives xViralMultiplier.
-- Brand-new players get one near spawn within ViralFirstSpawnDelay seconds so they see
-- the mechanic in their first minute.
--
-- The beam lives in a Persistent model so StreamingEnabled never hides it from distant
-- players. Position checks are server-side against the character root.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Parent.Util.Remotes)

local SPAWN_TAG = "ViralSpawn"
local MOMENTS = { "🛸 UFO Landing", "🐱 Giant Cat", "🌟 Celebrity Cameo", "🦖 Dino Escape", "🎆 Fireworks Show" }

local ViralService = {}

local active: { position: Vector3, endsAt: number, name: string, model: Model }? = nil
local nextSpawnAt = os.time() + 60
local rng = Random.new()

local function spawnPoints(): { BasePart }
	local points = {}
	for _, instance in CollectionService:GetTagged(SPAWN_TAG) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(points, instance)
		end
	end
	return points
end

local function nearestToSpawn(points: { BasePart }): BasePart?
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawn then
		return points[1]
	end
	local best, bestDistance = nil, math.huge
	for _, point in points do
		local distance = (point.Position - spawn.Position).Magnitude
		-- Close enough to find, far enough that the new player has to move.
		if distance > 20 and distance < bestDistance then
			best, bestDistance = point, distance
		end
	end
	return best or points[1]
end

local function buildBeam(position: Vector3, name: string): Model
	local model = Instance.new("Model")
	model.Name = "ViralMoment"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 80, 200)
	beam.Transparency = 0.45
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(120, Game.ViralRadius * 2, Game.ViralRadius * 2)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 70)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 70, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = math.huge
	billboard.Parent = beam

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = `{name}\n×{Game.ViralMultiplier} VIEWS`
	label.Parent = billboard

	model.PrimaryPart = beam
	model.Parent = workspace
	return model
end

local function broadcast(player: Player?)
	local payload: Types.ViralPayload = if active
		then { Active = true, Position = active.position, EndsAt = active.endsAt, Name = active.name }
		else { Active = false }
	if player then
		Remotes.event("Viral"):FireClient(player, payload)
	else
		Remotes.event("Viral"):FireAllClients(payload)
	end
end

local function spawnMoment(preferSpawn: boolean): boolean
	local points = spawnPoints()
	if #points == 0 then
		return false
	end
	local point = if preferSpawn then nearestToSpawn(points) else points[rng:NextInteger(1, #points)]
	if not point then
		return false
	end
	local name = MOMENTS[rng:NextInteger(1, #MOMENTS)]
	local position = point.Position
	active = {
		position = position,
		endsAt = os.time() + Game.ViralDuration,
		name = name,
		model = buildBeam(position, name),
	}
	broadcast(nil)
	return true
end

local function endMoment()
	if active then
		active.model:Destroy()
		active = nil
		broadcast(nil)
	end
end

-- Studio/admin hook: spawn a moment immediately (ends any current one first).
function ViralService.spawnNow(nearSpawn: boolean?)
	endMoment()
	if spawnMoment(nearSpawn == true) then
		nextSpawnAt = math.huge
	end
end

function ViralService.isInside(player: Player): boolean
	local moment = active
	if not moment or os.time() > moment.endsAt then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local offset = root.Position - moment.position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Game.ViralRadius and math.abs(offset.Y) < 40
end

function ViralService.start()
	local preferSpawn = false

	DataService.Loaded:Connect(function(player, data)
		broadcast(player)
		if data.TotalPosts < 10 and not active then
			nextSpawnAt = math.min(nextSpawnAt, os.time() + Game.ViralFirstSpawnDelay)
			preferSpawn = true
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			if active and now >= active.endsAt then
				endMoment()
				nextSpawnAt = now + Game.ViralInterval - Game.ViralDuration
			elseif not active and now >= nextSpawnAt and #Players:GetPlayers() > 0 then
				local spawned = spawnMoment(preferSpawn)
				preferSpawn = false
				nextSpawnAt = if spawned then math.huge else now + Game.ViralInterval
			end
		end
	end)
end

return ViralService
