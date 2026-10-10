-- "!" and "?" over NPCs, a waypoint for the tracked quest, and zone entry banners.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Quests = require(Shared.Config.Quests)
local Enemies = require(Shared.Config.Enemies)
local QuestRules = require(Shared.QuestRules)
local Util = require(Shared.Util)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local Notifications = require(script.Parent.Notifications)

local player = Players.LocalPlayer

local WorldMarkers = {}

local npcIndicators = {} -- [npcId] = BillboardGui
local waypointPart, waypointLabel
local currentZone = nil
local eventTarget -- defined below

local function markerPosition(name)
	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Markers")
	local part = markers and markers:FindFirstChild(name)
	return part and part:IsA("BasePart") and part.Position or nil
end

local function npcPosition(npcId)
	local folder = workspace:FindFirstChild("NPCs")
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("NPCId") == npcId and model.PrimaryPart then
				return model.PrimaryPart.Position
			end
		end
	end
	return markerPosition(npcId) or World.NPCs[npcId].Position
end

local function zonePosition(zoneId)
	return markerPosition(zoneId) or World.Zones[zoneId].Position
end

-- Find the zone where an enemy (or the enemy that drops a material) lives.
local function zoneForTarget(objective)
	for zoneId, zone in pairs(World.Zones) do
		for _, spawn in ipairs(zone.Spawns) do
			local enemy = Enemies[spawn.Enemy]
			local matches = (objective.Kind == "Kill" and spawn.Enemy == objective.Target)
				or (objective.Kind == "Collect" and enemy.Drops and enemy.Drops[objective.Target] ~= nil)
			if matches then
				return zoneId
			end
		end
	end
	return nil
end

local function stationPosition(stationId)
	for _, s in ipairs(World.Stations) do
		if s.Station == stationId then
			return s.Position
		end
	end
	return World.Town.Position
end

local EVENT_NPCS = {
	BuyHome = "LandSteward",
	BuyAnimal = "Stablemaster",
	BuyHorse = "Stablemaster",
	Vote = "Herald",
}
local EVENT_STATIONS = {
	Brew = { "AlchemyTable", "Alchemy Table" },
	Cook = { "CookingPot", "Cooking Pot" },
	Craft = { "Forge", "Forge" },
	Smelt = { "Forge", "Forge" },
	Temper = { "Forge", "Forge" },
	Infuse = { "Forge", "Forge" },
}

-- Where to go for "Event" objectives. Returns { Position, Label, Radius } or nil.
eventTarget = function(data, eventName)
	local npcId = EVENT_NPCS[eventName]
	if npcId then
		return { Position = npcPosition(npcId), Label = World.NPCs[npcId].Name, Radius = 12 }
	end
	local station = EVENT_STATIONS[eventName]
	if station then
		return { Position = stationPosition(station[1]), Label = station[2], Radius = 10 }
	end
	if eventName == "Harvest" then
		return { Position = World.Farmlands.Position, Label = "Your fields", Radius = World.Farmlands.Radius * 0.6 }
	end
	if eventName == "Discover" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestDist = nil, math.huge
		for _, landmark in ipairs(World.Landmarks) do
			if not data.Discoveries[landmark.Id] and root then
				local d = Util.FlatDistance(root.Position, landmark.Position)
				if d < bestDist then
					best, bestDist = landmark, d
				end
			end
		end
		if best then
			return { Position = best.Position, Label = "Unexplored landmark", Radius = 40 }
		end
	end
	return nil
end

-- Where should the waypoint point? Returns position, label, arriveRadius
local function waypointTarget(data)
	local key = data.TrackedQuest
	if key == "" or not data.Quests.Active[key] then
		key = QuestRules.ActiveKeys(data)[1]
	end
	if not key then
		return nil
	end
	local def = QuestRules.GetDef(data, key)
	if QuestRules.IsReady(data, key) then
		return npcPosition(def.TurnIn), World.NPCs[def.TurnIn].Name, 12
	end
	for i, objective in ipairs(def.Objectives) do
		if QuestRules.GetProgress(data, key, i) < objective.Count then
			if objective.Kind == "Talk" then
				return npcPosition(objective.Target), World.NPCs[objective.Target].Name, 12
			elseif objective.Kind == "Event" then
				local target = eventTarget(data, objective.Target)
				if target then
					return target.Position, target.Label, target.Radius
				end
				return nil
			end
			local zoneId = zoneForTarget(objective)
			if zoneId then
				return zonePosition(zoneId), World.Zones[zoneId].Name, World.Zones[zoneId].Radius * 0.6
			end
		end
	end
	return nil
end

local function indicator(npcId)
	local gui = npcIndicators[npcId]
	if gui and gui.Parent then
		return gui
	end
	local folder = workspace:FindFirstChild("NPCs")
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("NPCId") == npcId and model.PrimaryPart then
			gui = Instance.new("BillboardGui")
			gui.Name = "QuestIndicator"
			gui.Size = UDim2.fromOffset(40, 50)
			gui.StudsOffset = Vector3.new(0, 7, 0)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 150
			gui.Adornee = model.PrimaryPart
			local label = Instance.new("TextLabel")
			label.Name = "Mark"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextStrokeTransparency = 0.2
			label.Parent = gui
			gui.Parent = player:WaitForChild("PlayerGui")
			npcIndicators[npcId] = gui
			return gui
		end
	end
	return nil
end

local function updateIndicators(data)
	for npcId in pairs(World.NPCs) do
		local gui = indicator(npcId)
		if gui then
			local mark = ""
			local color = Theme.Gold
			for _, key in ipairs(QuestRules.ActiveKeys(data)) do
				local def = QuestRules.GetDef(data, key)
				if def.TurnIn == npcId and QuestRules.IsReady(data, key) then
					mark = "?"
				end
			end
			if mark == "" then
				for _, questId in ipairs(QuestRules.OffersFor(data, npcId)) do
					if data.Level >= (Quests[questId].LevelReq or 1) then
						mark = "!"
					end
				end
			end
			if mark == "" and npcId == "Board" then
				mark = "!"
				color = Color3.fromRGB(190, 160, 230)
			end
			gui.Mark.Text = mark
			gui.Mark.TextColor3 = color
		end
	end
end

local function buildWaypoint()
	waypointPart = Instance.new("Part")
	waypointPart.Name = "QuestWaypoint"
	waypointPart.Anchored = true
	waypointPart.CanCollide = false
	waypointPart.CanQuery = false
	waypointPart.CanTouch = false
	waypointPart.Transparency = 1
	waypointPart.Size = Vector3.new(0.2, 0.2, 0.2)
	waypointPart.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = waypointPart
	waypointLabel = Instance.new("TextLabel")
	waypointLabel.BackgroundTransparency = 1
	waypointLabel.Size = UDim2.fromScale(1, 1)
	waypointLabel.Font = Enum.Font.GothamBold
	waypointLabel.TextSize = 15
	waypointLabel.TextColor3 = Theme.Gold
	waypointLabel.TextStrokeTransparency = 0.3
	waypointLabel.Parent = gui
end

local function zoneAt(position)
	for zoneId, zone in pairs(World.Zones) do
		if Util.FlatDistance(position, zonePosition(zoneId)) <= zone.Radius then
			return zoneId, zone.Name, "Level " .. zone.Levels
		end
	end
	if Util.FlatDistance(position, World.Town.Position) <= World.Town.Radius then
		return "Town", World.Town.Name, "Safe haven"
	end
	if Util.FlatDistance(position, World.City.Position) <= World.City.WallRadius then
		return "City", World.City.Name, World.City.Title
	end
	if Util.FlatDistance(position, World.Farmlands.Position) <= World.Farmlands.Radius * 0.75 then
		return "Farmlands", World.Farmlands.Name, "Farmland and homesteads"
	end
	return "Wilds", nil, nil
end

function WorldMarkers.Start()
	buildWaypoint()
	State.Observe(updateIndicators)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local data = State.Data
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if data and root then
				-- Waypoint
				local position, label, arriveRadius = waypointTarget(data)
				if position and Util.FlatDistance(root.Position, position) > arriveRadius then
					waypointPart.Position = position + Vector3.new(0, 10, 0)
					waypointLabel.Text = "◆ "
						.. label
						.. "\n"
						.. math.floor(Util.FlatDistance(root.Position, position))
						.. "m"
					waypointLabel.Visible = true
				else
					waypointLabel.Visible = false
				end

				-- Zone banner
				local zoneId, name, subtitle = zoneAt(root.Position)
				if zoneId ~= currentZone then
					currentZone = zoneId
					if name then
						Notifications.Banner(name, subtitle)
					end
				end
			end
		end
	end)
end

return WorldMarkers
