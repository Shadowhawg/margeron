-- Exploration: discovering landmarks and regions, and gathering herbs and ore from the wild.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Items = require(Shared.Config.Items)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local Clock = require(Shared.Clock)
local Calendar = require(Shared.Config.Calendar)

local ExplorationService = {}
local Services

-- Everything discoverable: landmarks plus every zone and region.
local discoverables = {}

local function buildDiscoverables()
	table.clear(discoverables)
	for _, landmark in ipairs(World.Landmarks) do
		table.insert(discoverables, {
			Id = landmark.Id,
			Name = landmark.Name,
			Position = Services.WorldService.GetLandmarkPosition(landmark.Id),
			Radius = GameConfig.DiscoveryRadius,
			XP = landmark.XP,
			Visit = true,
		})
	end
	for zoneId, zone in pairs(World.Zones) do
		table.insert(discoverables, {
			Id = "Zone:" .. zoneId,
			Name = zone.Name,
			Position = Services.WorldService.GetZonePosition(zoneId),
			Radius = zone.Radius,
			XP = 60,
		})
	end
	table.insert(discoverables, {
		Id = "Region:Farmlands",
		Name = World.Farmlands.Name,
		Position = World.Farmlands.Position,
		Radius = World.Farmlands.Radius * 0.6,
		XP = 40,
	})
	table.insert(discoverables, {
		Id = "Region:City",
		Name = World.City.Name .. ", " .. World.City.Title,
		Position = World.City.Position,
		Radius = World.City.WallRadius,
		XP = 150,
	})
end

local function discover(player, data, entry)
	data.Discoveries[entry.Id] = true
	local isLandmark = not entry.Id:find(":")
	Remotes.Effect:FireClient(player, "Discovery", entry.Name, entry.XP)
	Services.PlayerService.AddXP(player, entry.XP)
	if isLandmark then
		Services.QuestService.OnEvent(player, "Discover")
	end
	Services.PlayerService.Changed(player)
end

local function checkDiscoveries()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Services.PlayerService.GetData(player)
		local humanoid, character = Services.PlayerService.GetHumanoid(player)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if data and humanoid and root and data.Story.PrologueSeen then
			for _, entry in ipairs(discoverables) do
				if
					not data.Discoveries[entry.Id]
					and Util.FlatDistance(root.Position, entry.Position) <= entry.Radius
				then
					discover(player, data, entry)
				end
				-- Quests can ask you to go back to a landmark ("Visit:<id>"), discovered or not.
				if
					entry.Visit
					and data.Quests.Active
					and Util.FlatDistance(root.Position, entry.Position) <= math.min(entry.Radius, 40)
				then
					Services.QuestService.OnEvent(player, "Visit:" .. entry.Id)
				end
			end
		end
	end
end

-- Gathering ------------------------------------------------------------------------------

local function setNodeVisible(node, visible)
	for _, part in ipairs(node:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = visible and (part:GetAttribute("BaseTransparency") or 0) or 1
			part.CanCollide = visible and part.Name == "Vein"
		end
	end
	local prompt = node.PrimaryPart and node.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = visible
	end
end

local function setupNode(node)
	local resource = node:GetAttribute("Resource")
	local def = Items.Materials[resource]
	if not def or not node.PrimaryPart then
		return
	end
	for _, part in ipairs(node:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("BaseTransparency", part.Transparency)
		end
	end
	local isOre = def.Category == "Ore"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = isOre and "Mine" or "Gather"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = isOre and 1.2 or 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = node.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if node:GetAttribute("Depleted") then
			return
		end
		local data = Services.PlayerService.GetData(player)
		if not data then
			return
		end
		node:SetAttribute("Depleted", true)
		setNodeVisible(node, false)
		local amount = math.random(1, isOre and 2 or 3)
		if not isOre then
			-- Holidays can double herbs; Moonpetal is twice as plentiful at night.
			local bonus = 1 + Clock.HolidayBonus("Gather")
			if resource == "Moonpetal" and Clock.IsNight() then
				bonus += Calendar.Night.Moonpetal
			end
			amount = math.floor(amount * bonus + 0.5)
		end
		Services.InventoryService.AddMaterial(player, resource, amount)
		Remotes.Effect:FireClient(player, "Loot", node.PrimaryPart.Position, "+" .. amount .. " " .. def.Name)
		Services.QuestService.OnEvent(player, "Gather")
		task.delay(GameConfig.GatherRespawnSeconds, function()
			if node.Parent then
				node:SetAttribute("Depleted", nil)
				setNodeVisible(node, true)
			end
		end)
	end)
end

function ExplorationService.Discoverables()
	return discoverables
end

local FAST_TRAVEL_COST = 15

-- Travel to the town, your home, or anywhere you've discovered.
function ExplorationService.FastTravel(player, destination)
	local data = Services.PlayerService.GetData(player)
	local humanoid, character = Services.PlayerService.GetHumanoid(player)
	if not data or not humanoid or type(destination) ~= "string" then
		return { ok = false }
	end
	if Services.CombatService.InCombat(player) then
		return { ok = false, message = "You can't travel while in combat." }
	end
	local target
	if destination == "Town" then
		target = World.SpawnPoint
	elseif destination == "Home" then
		target = Services.PropertyService.HomePosition(player)
		if not target then
			return { ok = false, message = "You don't have a home in this server." }
		end
		target += Vector3.new(0, 0, -50)
	else
		for _, entry in ipairs(discoverables) do
			if entry.Id == destination and data.Discoveries[destination] then
				target = entry.Position
			end
		end
	end
	if not target then
		return { ok = false, message = "You haven't discovered that place." }
	end
	if destination ~= "Town" and not Services.PlayerService.SpendGold(player, FAST_TRAVEL_COST) then
		return { ok = false, message = "A carriage costs " .. FAST_TRAVEL_COST .. " gold." }
	end
	Services.PropertyService.Dismount(player)
	local ground = Services.WorldService.Ground(target.X + 6, target.Z + 6)
	character:PivotTo(CFrame.new(ground + Vector3.new(0, 4, 0)))
	return { ok = true }
end

function ExplorationService.Init(services)
	Services = services
end

function ExplorationService.Start()
	buildDiscoverables()
	for _, node in ipairs(CollectionService:GetTagged("GatherNode")) do
		setupNode(node)
	end
	CollectionService:GetInstanceAddedSignal("GatherNode"):Connect(setupNode)
	while true do
		task.wait(1)
		checkDiscoveries()
	end
end

return ExplorationService
