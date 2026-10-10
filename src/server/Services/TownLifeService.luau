-- Brings the towns to life: townsfolk stroll Riverwatch's and Aurelion's streets, stop to chat,
-- work or look around, and the quest NPCs potter about near their posts instead of standing frozen.
-- Movement is plain Humanoid:MoveTo along a graph of street points (ring roads and avenues), so
-- nobody walks through a house. Clients animate limbs for anything tagged "Walker" (Effects).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Clock = require(Shared.Clock)
local ModelBuilder = require(script.Parent.Parent.Lib.ModelBuilder)

local TownLifeService = {}
local Services

local rng = Random.new()

local CLOTHES = {
	Color3.fromRGB(120, 85, 60),
	Color3.fromRGB(85, 100, 70),
	Color3.fromRGB(110, 60, 55),
	Color3.fromRGB(70, 80, 110),
	Color3.fromRGB(140, 120, 90),
	Color3.fromRGB(95, 75, 95),
	Color3.fromRGB(150, 140, 120),
	Color3.fromRGB(60, 70, 60),
}
local SKIN = {
	Color3.fromRGB(234, 192, 160),
	Color3.fromRGB(205, 160, 120),
	Color3.fromRGB(160, 110, 80),
	Color3.fromRGB(110, 75, 55),
	Color3.fromRGB(245, 210, 185),
}
local ACTIVITIES = { "Talk", "Work", "Look", "Idle" }

-- Things townsfolk say when a player passes. Kept vague so they fit any point in the story.
local BARKS = {
	Riverwatch = {
		"Mind the river road after dark.",
		"Brann's been at that forge since dawn.",
		"They say the Stones of Ael hum at night.",
		"Another election coming. As if it changes anything.",
		"Wolves took two of Oren's sheep last week.",
		"You're the one they pulled from the river, aren't you?",
		"Fresh bread at the market, if you're quick.",
		"My grandmother swore the old crypt sings.",
	},
	Aurelion = {
		"The Chancellor hasn't slept in days, they say.",
		"Seven climbed. One returned. Never did learn his name.",
		"Mind your purse near the market.",
		"The White Tower lit itself last night. No one was inside.",
		"Arena's taking challengers again.",
		"Ash on the wind from Cinder Peak. A bad sign.",
		"The Crown Light has never once gone out.",
		"Strangers come through the gate every day. Few stay.",
	},
}

-- Street graphs -----------------------------------------------------------------------------

local function newGraph()
	return { Nodes = {}, Links = {} }
end

local function addNode(graph, position)
	table.insert(graph.Nodes, position)
	graph.Links[#graph.Nodes] = {}
	return #graph.Nodes
end

local function link(graph, a, b)
	table.insert(graph.Links[a], b)
	table.insert(graph.Links[b], a)
end

local function ground(x, z)
	return Services.WorldService.Ground(x, z)
end

-- A ring road plus spokes (avenues) leaving it. toWorld(radius, angle) -> x, z
local function buildRingGraph(ringRadius, ringCount, spokes, toWorld)
	local graph = newGraph()
	local ring = {}
	for i = 0, ringCount - 1 do
		local x, z = toWorld(ringRadius, i / ringCount * math.pi * 2)
		ring[i] = addNode(graph, ground(x, z))
		if i > 0 then
			link(graph, ring[i - 1], ring[i])
		end
	end
	link(graph, ring[ringCount - 1], ring[0])
	for _, spoke in ipairs(spokes) do
		local a = spoke.Angle % (math.pi * 2)
		local nearest = ring[math.floor(a / (math.pi * 2) * ringCount + 0.5) % ringCount]
		for _, direction in ipairs({ -1, 1 }) do
			local previous = nearest
			local r = ringRadius + direction * 14
			while r >= spoke.Inner and r <= spoke.Outer do
				local x, z = toWorld(r, spoke.Angle)
				local node = addNode(graph, ground(x, z))
				link(graph, previous, node)
				previous = node
				r += direction * 14
			end
		end
	end
	return graph
end

local function riverwatchGraph()
	local center = World.Town.Position
	local spokes = {}
	for _, angle in ipairs(Services.WorldService.TownGates or {}) do
		table.insert(spokes, { Angle = angle, Inner = 18, Outer = World.Town.Radius - 18 })
	end
	return buildRingGraph(58, 28, spokes, function(r, a)
		return center.X + math.cos(a) * r, center.Z + math.sin(a) * r
	end)
end

local function aurelionGraph()
	local city = World.City
	local spokes = {
		{ Angle = 0, Inner = 66, Outer = city.WallRadius - 10 },
		{ Angle = math.pi / 2, Inner = 66, Outer = city.WallRadius - 10 },
		{ Angle = -math.pi / 2, Inner = 66, Outer = city.WallRadius - 10 },
		{ Angle = math.pi, Inner = 66, Outer = city.WallRadius - 14 },
	}
	return buildRingGraph(120, 40, spokes, function(r, a)
		local p = city.Point(math.cos(a) * r, math.sin(a) * r)
		return p.X, p.Z
	end)
end

-- Shared helpers --------------------------------------------------------------------------

local function keepUpright(humanoid)
	for _, state in ipairs({
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.PlatformStanding,
	}) do
		humanoid:SetStateEnabled(state, false)
	end
end

-- Walk to a point; returns when arrived or after a timeout (blocked by something).
local function walkTo(humanoid, target, timeout)
	humanoid:MoveTo(target)
	local arrived = false
	local conn = humanoid.MoveToFinished:Connect(function(reached: boolean)
		arrived = true
		local _ = reached
	end)
	local started = os.clock()
	while not arrived and os.clock() - started < (timeout or 10) and humanoid.Parent do
		task.wait(0.25)
	end
	conn:Disconnect()
end

local function face(root, position)
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.2 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function nearestPlayerRoot(position, range)
	local best, bestDist = nil, range
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

-- A short speech bubble over someone's head.
local function bark(root, height, text)
	local old = root:FindFirstChild("Bark")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bark"
	gui.Size = UDim2.fromOffset(240, 46)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 45
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 22, 18)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(245, 235, 215)
	label.Font = Enum.Font.Garamond
	label.TextSize = 18
	label.TextWrapped = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = root
	task.delay(4.5, function()
		gui:Destroy()
	end)
end

-- Plays an activity in place for a while (the client animates the "Activity" attribute).
local function doActivity(model, root, seconds)
	local activity = ACTIVITIES[rng:NextInteger(1, #ACTIVITIES)]
	model:SetAttribute("Activity", activity)
	local started = os.clock()
	while os.clock() - started < seconds and model.Parent do
		if activity == "Look" then
			local a = rng:NextNumber(0, math.pi * 2)
			face(root, root.Position + Vector3.new(math.cos(a), 0, math.sin(a)))
		end
		task.wait(rng:NextNumber(1.2, 2.5))
	end
	model:SetAttribute("Activity", nil)
end

-- Townsfolk ------------------------------------------------------------------------------

local function spawnCitizen(folder, graph, townName)
	local model, info = ModelBuilder.Creature("Townsfolk", {
		Shape = "Humanoid",
		Scale = rng:NextNumber(0.88, 1.05),
		Color = CLOTHES[rng:NextInteger(1, #CLOTHES)],
		HeadColor = SKIN[rng:NextInteger(1, #SKIN)],
		EyeColor = Color3.fromRGB(35, 28, 25),
	})
	local nodeIndex = rng:NextInteger(1, #graph.Nodes)
	local start = graph.Nodes[nodeIndex]
	model:PivotTo(CFrame.new(start + Vector3.new(0, info.GroundOffset + 0.5, 0)))
	model.Parent = folder
	info.Root:SetNetworkOwner(nil)
	keepUpright(info.Humanoid)
	info.Humanoid.WalkSpeed = rng:NextNumber(5, 7.5)
	CollectionService:AddTag(model, "Walker")

	local barks = BARKS[townName]
	local lastBark = 0
	task.spawn(function()
		local previous = nil
		while model.Parent do
			-- Pick the next street point, avoiding turning straight back where possible.
			local links = graph.Links[nodeIndex]
			local choices = {}
			for _, n in ipairs(links) do
				if n ~= previous or #links == 1 then
					table.insert(choices, n)
				end
			end
			previous = nodeIndex
			nodeIndex = choices[rng:NextInteger(1, #choices)]
			local target = graph.Nodes[nodeIndex]
			-- A little sideways offset so walkers don't march along one line.
			local jitter = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			walkTo(info.Humanoid, target + jitter, 12)

			-- Stop now and then: more often in the evening, chatting with passers-by.
			if rng:NextNumber() < (Clock.IsNight() and 0.12 or 0.22) then
				local near = nearestPlayerRoot(info.Root.Position, 22)
				if near and os.clock() - lastBark > 30 and rng:NextNumber() < 0.6 then
					lastBark = os.clock()
					face(info.Root, near.Position)
					bark(info.Root, info.Height - info.GroundOffset + 1.5, barks[rng:NextInteger(1, #barks)])
				end
				doActivity(model, info.Root, rng:NextNumber(3, 9))
			end
		end
	end)
end

-- Quest NPCs: idle near their post ----------------------------------------------------------

local paused = {} -- [Model] = os.clock() until which the NPC holds still (talking)

function TownLifeService.Pause(model, seconds)
	paused[model] = os.clock() + seconds
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
	model:SetAttribute("Activity", "Talk")
end

-- Called by NPCService for every person NPC (built unanchored).
function TownLifeService.Animate(model, info, post, radius)
	info.Root:SetNetworkOwner(nil)
	keepUpright(info.Humanoid)
	info.Humanoid.WalkSpeed = 5
	CollectionService:AddTag(model, "Walker")
	task.spawn(function()
		task.wait(rng:NextNumber(0, 4))
		while model.Parent do
			if (paused[model] or 0) > os.clock() then
				task.wait(0.5)
				continue
			end
			if model:GetAttribute("Activity") == "Talk" and paused[model] then
				paused[model] = nil
				model:SetAttribute("Activity", nil)
			end
			if rng:NextNumber() < 0.45 then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(1.5, radius)
				local target = Services.WorldService.Ground(post.X + math.cos(a) * r, post.Z + math.sin(a) * r)
				walkTo(info.Humanoid, target, 6)
			else
				doActivity(model, info.Root, rng:NextNumber(4, 10))
			end
			task.wait(rng:NextNumber(0.5, 2))
		end
	end)
end

function TownLifeService.Init(services)
	Services = services
end

function TownLifeService.Start()
	-- Only the generated towns have known streets (a hand-built Map brings its own life).
	local waited = 0
	while not Services.WorldService.IsGenerated() do
		task.wait(1)
		waited += 1
		if waited > 60 then
			return
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Townsfolk"
	folder.Parent = workspace
	local towns = {
		{ Name = "Riverwatch", Graph = riverwatchGraph(), Count = 8 },
		{ Name = "Aurelion", Graph = aurelionGraph(), Count = 14 },
	}
	for _, town in ipairs(towns) do
		for _ = 1, town.Count do
			spawnCitizen(folder, town.Graph, town.Name)
			task.wait(0.1)
		end
	end
end

TownLifeService.BuildGraphs = function()
	return riverwatchGraph(), aurelionGraph()
end

return TownLifeService
