-- World map (M): regions, lakes, the river, discovered landmarks, your position, and fast travel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local New = Create.New

local player = Players.LocalPlayer

local MapPanel = {}

local MAP_PX = 500
local playerDot = nil

local function toMap(position)
	local half = World.MapHalfSize
	return UDim2.fromOffset((position.X + half) / (half * 2) * MAP_PX, (position.Z + half) / (half * 2) * MAP_PX)
end

local function circle(parent, position, radius, color, transparency, z)
	local size = radius / (World.MapHalfSize * 2) * MAP_PX * 2
	return New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(position),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0.4,
		ZIndex = z or 2,
		Parent = parent,
	}, { Create.Corner(math.ceil(size / 2)) })
end

local function label(parent, position, text, color, z)
	return New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = toMap(position) + UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(140, 14),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or Theme.Text,
		TextStrokeTransparency = 0.3,
		Font = Theme.BoldFont,
		TextSize = 11,
		ZIndex = z or 4,
		Parent = parent,
	})
end

local function render(content)
	local data = State.Data
	local map = New("Frame", {
		Size = UDim2.fromOffset(MAP_PX, MAP_PX),
		BackgroundColor3 = Color3.fromRGB(70, 95, 60),
		ClipsDescendants = true,
		Parent = content,
	}, { Create.Corner(8), Create.Stroke(Theme.Border, 2) })
	-- Mountains at the edge
	New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = map,
	}, { Create.Stroke(Color3.fromRGB(110, 105, 100), 26) })

	-- River
	local half = World.MapHalfSize
	for x = -half, half, 40 do
		local z = World.River.BaseZ + World.River.Amplitude * math.sin(x / World.River.Wavelength)
		circle(map, Vector3.new(x, 0, z), 22, Color3.fromRGB(60, 110, 160), 0.1, 2)
	end
	for _, lake in ipairs(World.Lakes) do
		circle(map, lake.Position, lake.Radius, Color3.fromRGB(60, 110, 160), 0.1, 2)
	end
	circle(map, World.Volcano.Position, World.Volcano.BaseRadius * 0.6, Color3.fromRGB(70, 55, 50), 0.2, 2)

	-- The Crown City on its lake
	local city = World.City
	circle(map, city.Position, city.LakeRadius, Color3.fromRGB(60, 110, 160), 0.1, 2)
	circle(map, city.Position, city.IslandRadius, Color3.fromRGB(215, 205, 185), 0.05, 3)
	circle(map, city.Position, 14, Color3.fromRGB(250, 248, 240), 0, 4)
	label(map, city.Position, city.Name, Theme.Gold)

	-- Town and farmlands
	circle(map, World.Town.Position, World.Town.Radius, Color3.fromRGB(190, 170, 120), 0.1, 3)
	label(map, World.Town.Position, World.Town.Name, Theme.Gold)
	circle(map, World.Farmlands.Position, World.Farmlands.Radius * 0.7, Color3.fromRGB(150, 160, 80), 0.5, 3)
	label(map, World.Farmlands.Position, World.Farmlands.Name, Theme.Text)

	-- Zones
	local zoneColors = {
		Forest = Color3.fromRGB(40, 80, 40),
		Camp = Color3.fromRGB(140, 60, 50),
		Crypt = Color3.fromRGB(90, 90, 100),
		Marsh = Color3.fromRGB(80, 100, 70),
		Volcano = Color3.fromRGB(200, 80, 40),
		Snow = Color3.fromRGB(220, 230, 240),
		Ruins = Color3.fromRGB(170, 160, 130),
	}
	for zoneId, zone in pairs(World.Zones) do
		local known = data.Discoveries["Zone:" .. zoneId]
		circle(map, zone.Position, zone.Radius, zoneColors[zone.Biome] or Theme.Muted, known and 0.3 or 0.75, 3)
		label(
			map,
			zone.Position,
			known and (zone.Name .. " (" .. zone.Levels .. ")") or "?",
			known and Theme.Text or Theme.Muted
		)
	end

	-- Landmarks
	for _, landmark in ipairs(World.Landmarks) do
		local known = data.Discoveries[landmark.Id]
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(landmark.Position),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = known and Theme.Gold or Theme.Muted,
			ZIndex = 5,
			Parent = map,
		})
		if known then
			label(map, landmark.Position, landmark.Name, Theme.Gold, 5)
		end
	end

	playerDot = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = "▲",
		TextColor3 = Color3.fromRGB(255, 80, 80),
		TextStrokeTransparency = 0,
		TextSize = 18,
		Font = Theme.BoldFont,
		ZIndex = 8,
		Parent = map,
	})

	-- Fast travel list
	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(MAP_PX + 14, 0),
		Size = UDim2.new(1, -(MAP_PX + 14), 1, 0),
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(8), Create.List(5) })
	Create.Label(
		"Fast travel (15 gold, free to town)",
		{ Font = Theme.BoldFont, TextColor3 = Theme.Accent, TextSize = 14, LayoutOrder = 0, Parent = list }
	)
	local order = 0
	local function travelButton(text, id)
		order += 1
		Create.Button(text, Theme.PanelLight, function()
			local result = Net.Request("FastTravel", id)
			if result.ok then
				Windows.Close()
			end
		end, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 30), TextSize = 13, Parent = list })
	end
	travelButton(World.Town.Name, "Town")
	if data.Property.Home ~= "" then
		travelButton("Home", "Home")
	end
	for zoneId, zone in pairs(World.Zones) do
		if data.Discoveries["Zone:" .. zoneId] then
			travelButton(zone.Name, "Zone:" .. zoneId)
		end
	end
	if data.Discoveries["Region:City"] then
		travelButton(World.City.Name .. " (Crown City)", "Region:City")
	end
	if data.Discoveries["Region:Farmlands"] then
		travelButton(World.Farmlands.Name, "Region:Farmlands")
	end
	for _, landmark in ipairs(World.Landmarks) do
		if data.Discoveries[landmark.Id] then
			travelButton(landmark.Name, landmark.Id)
		end
	end
	local found = 0
	for _ in pairs(data.Discoveries) do
		found += 1
	end
	order += 1
	Create.Label(
		"Discovered " .. found .. " places.",
		{ TextColor3 = Theme.Muted, TextSize = 12, LayoutOrder = order, Parent = list }
	)
end

function MapPanel.Init()
	Windows.Register("Map", "Map of Margeron", render)
	RunService.RenderStepped:Connect(function()
		if playerDot and playerDot.Parent and Windows.IsOpen("Map") then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				playerDot.Position = toMap(root.Position)
				local look = root.CFrame.LookVector
				playerDot.Rotation = math.deg(math.atan2(look.X, -look.Z))
			end
		end
	end)
end

return MapPanel
