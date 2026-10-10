-- Property ownership: homes on Greenmeadow plots, farm fields, livestock and horses (riding).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Property = require(Shared.Config.Property)
local World = require(Shared.Config.World)
local Items = require(Shared.Config.Items)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)
local Clock = require(Shared.Clock)
local Props = require(script.Parent.Parent.Lib.Props)
local Architecture = require(script.Parent.Parent.Lib.Architecture)
local CollectionService = game:GetService("CollectionService")
local ModelBuilder = require(script.Parent.Parent.Lib.ModelBuilder)

local PropertyService = {}
local Services

local plots = {} -- [index] = { Center = Vector3, Owner = Player?, Model = Model }
local playerPlot = {} -- [Player] = index
local mounted = {} -- [Player] = horseId

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function result(ok, message, extra)
	local r = extra or {}
	r.ok = ok
	r.message = message
	return r
end

local function now()
	return Stats.Now()
end

local function festival()
	return (Services.GovernmentService.DecreeActive("HarvestFestival") and 1.5 or 1) + Clock.HolidayBonus("Crops")
end

-- Field layout inside a plot (local offsets from the plot center).
local function fieldOffset(i)
	local col = (i - 1) % 5
	local row = math.floor((i - 1) / 5)
	return Vector3.new(-30 + col * 15, 0, 18 + row * 15)
end

local PEN_OFFSET = Vector3.new(32, 0, -24)

-- Building ---------------------------------------------------------------------------------

local function plotGround(center, offset)
	local p = center + offset
	return Services.WorldService.Ground(p.X, p.Z)
end

local function buildForSale(index)
	local plot = plots[index]
	if plot.Model then
		plot.Model:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	Props.Folder = model
	local half = Property.PlotSize / 2
	for _, c in ipairs({
		Vector3.new(-half, 0, -half),
		Vector3.new(half, 0, -half),
		Vector3.new(-half, 0, half),
		Vector3.new(half, 0, half),
	}) do
		Props.Part({
			Name = "CornerPost",
			Size = Vector3.new(1, 5, 1),
			Position = plotGround(plot.Center, c) + Vector3.new(0, 2.5, 0),
			Color = rgb(95, 68, 45),
			Material = Enum.Material.Wood,
		})
	end
	Props.Sign(
		plotGround(plot.Center, Vector3.new(0, 0, -half + 6)),
		"Land for sale - see Holdsworth",
		Vector3.new(0, 0, -1)
	)
	model.Parent = workspace:FindFirstChild("Properties")
	plot.Model = model
end

local cropParts = {} -- [Player] = { [fieldIndex] = Folder }

local function updateFieldVisual(player, i)
	local data = Services.PlayerService.GetData(player)
	local folder = cropParts[player] and cropParts[player][i]
	if not data or not folder then
		return
	end
	local field = data.Property.Fields[i]
	local soil = folder.Parent
	if not field or field.Crop == "" then
		folder:ClearAllChildren()
		folder:SetAttribute("Stage", nil)
		return
	end
	local crop = Property.Crops[field.Crop]
	local growTime = crop.GrowTime * (field.Fertilized and Property.FertilizerSpeedup or 1)
	local progress = math.clamp((now() - field.PlantedAt) / growTime, 0, 1)
	local ripe = progress >= 1
	-- Only rebuild when the growth stage changes.
	local stage = field.Crop .. (ripe and ":ripe" or (":" .. math.floor(progress * 4)))
	if folder:GetAttribute("Stage") == stage then
		return
	end
	folder:SetAttribute("Stage", stage)
	folder:ClearAllChildren()
	local height = 0.6 + progress * 2.4
	for r = -1, 1 do
		for c = -1, 1 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.Size = Vector3.new(0.5, height, 0.5)
			p.Position = soil.Position + Vector3.new(c * 4, 0.3 + height / 2, r * 4)
			p.Color = ripe and crop.Color or rgb(90, 160, 70):Lerp(crop.Color, progress * 0.4)
			p.Material = ripe and Enum.Material.Neon or Enum.Material.Grass
			p.Parent = folder
		end
	end
	local prompt = soil:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ActionText = ripe and "Harvest" or "Tend"
		prompt.ObjectText = crop.Name
	end
end

local function updateAllFields(player)
	local data = Services.PlayerService.GetData(player)
	if not data or not cropParts[player] then
		return
	end
	for i in pairs(cropParts[player]) do
		updateFieldVisual(player, i)
	end
end

local animalModels = {} -- [Player] = { Model }

local function buildAnimals(player, penCenter)
	for _, m in ipairs(animalModels[player] or {}) do
		m:Destroy()
	end
	animalModels[player] = {}
	local data = Services.PlayerService.GetData(player)
	local plot = plots[playerPlot[player]]
	if not data or not plot then
		return
	end
	for _, animal in ipairs(data.Property.Animals) do
		local def = Property.Animals[animal.Type]
		if def then
			local scale = ({ Chicken = 0.35, Sheep = 0.75, Cow = 1.05 })[animal.Type] or 0.7
			local model, info = ModelBuilder.Creature(def.Name, {
				Shape = "Beast",
				Scale = scale,
				Color = def.Color,
				HeadColor = animal.Type == "Sheep" and rgb(40, 35, 35) or def.Color,
				EyeColor = rgb(20, 20, 20),
				Anchored = true,
			})
			local spot = penCenter + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			local ground = Services.WorldService.Ground(spot.X, spot.Z)
			model:PivotTo(
				CFrame.new(ground + Vector3.new(0, info.GroundOffset, 0)) * CFrame.Angles(0, math.random() * 6, 0)
			)
			model.Parent = plot.Model
			table.insert(animalModels[player], model)
			-- Wander gently around the pen.
			task.spawn(function()
				while model.Parent do
					task.wait(math.random(4, 9))
					if not model.Parent then
						break
					end
					local target = penCenter + Vector3.new(math.random(-9, 9), 0, math.random(-9, 9))
					local g = Services.WorldService.Ground(target.X, target.Z)
					local from = info.Root.Position
					local to = g + Vector3.new(0, info.GroundOffset, 0)
					local look = CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
					local tween = TweenService:Create(
						info.Root,
						TweenInfo.new((to - from).Magnitude / 3, Enum.EasingStyle.Linear),
						{ CFrame = look.Rotation + to }
					)
					info.Root.CFrame = look
					tween:Play()
				end
			end)
		end
	end
end

local function buildHome(player)
	local index = playerPlot[player]
	local data = Services.PlayerService.GetData(player)
	if not index or not data then
		return
	end
	local plot = plots[index]
	local home = Property.Homes[data.Property.Home]
	if not home then
		buildForSale(index)
		return
	end
	if plot.Model then
		plot.Model:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = player.Name .. "'s " .. home.Name
	Props.Folder = model
	Architecture.Folder = model
	local c = plot.Center
	local half = Property.PlotSize / 2

	-- Fences around the plot (gap at the front).
	local corners = {
		plotGround(c, Vector3.new(-half, 0, -half)),
		plotGround(c, Vector3.new(half, 0, -half)),
		plotGround(c, Vector3.new(half, 0, half)),
		plotGround(c, Vector3.new(-half, 0, half)),
	}
	Props.Fence(corners[2], corners[3])
	Props.Fence(corners[3], corners[4])
	Props.Fence(corners[4], corners[1])
	Props.Fence(corners[1], corners[1]:Lerp(corners[2], 0.4))
	Props.Fence(corners[1]:Lerp(corners[2], 0.6), corners[2])

	-- The house itself.
	local houseGround = plotGround(c, Vector3.new(-14, 0, -24))
	local facing = Vector3.new(0, 0, -1)
	if data.Property.Home == "Manor" then
		local cf = CFrame.lookAt(houseGround, houseGround + facing)
		Props.Part({
			Name = "ManorBase",
			Size = Vector3.new(36, 2, 26),
			CFrame = cf * CFrame.new(0, 0.5, 0),
			Color = rgb(140, 135, 130),
			Material = Enum.Material.Cobblestone,
		})
		Props.Part({
			Name = "ManorHall",
			Size = Vector3.new(32, 18, 22),
			CFrame = cf * CFrame.new(0, 10, 0),
			Color = rgb(180, 172, 160),
			Material = Enum.Material.Limestone,
		})
		Props.Part({
			Name = "ManorRoof",
			Size = Vector3.new(35, 3, 25),
			CFrame = cf * CFrame.new(0, 20, 0),
			Color = rgb(70, 60, 80),
			Material = Enum.Material.Slate,
		})
		for _, x in ipairs({ -14, 14 }) do
			Props.Part({
				Name = "ManorTower",
				Size = Vector3.new(8, 28, 8),
				CFrame = cf * CFrame.new(x, 14, -8),
				Color = rgb(170, 162, 150),
				Material = Enum.Material.Limestone,
			})
			Props.Part({
				Name = "TowerCap",
				Size = Vector3.new(9, 3, 9),
				CFrame = cf * CFrame.new(x, 29, -8),
				Color = rgb(70, 60, 80),
				Material = Enum.Material.Slate,
			})
		end
		Props.Part({
			Name = "ManorDoor",
			Size = Vector3.new(6, 9, 0.5),
			CFrame = cf * CFrame.new(0, 5.5, -11.1),
			Color = rgb(70, 45, 30),
			Material = Enum.Material.Wood,
		})
		for _, x in ipairs({ -8, 8 }) do
			Props.Part({
				Name = "Banner",
				Size = Vector3.new(3, 8, 0.2),
				CFrame = cf * CFrame.new(x, 12, -11.2),
				Color = rgb(40, 70, 130),
				Material = Enum.Material.Fabric,
				CanCollide = false,
			})
		end
	else
		local farm = data.Property.Home == "Farmhouse"
		Architecture.House(houseGround, facing, {
			Width = farm and 22 or 16,
			Depth = farm and 18 or 14,
			Stories = farm and 2 or 1,
			Wall = farm and rgb(230, 215, 185) or rgb(225, 205, 175),
			Roof = farm and rgb(90, 60, 45) or rgb(120, 70, 45),
			Base = farm and "Stone" or "Timber",
			Parent = model,
		})
		if data.Property.Home == "Farmhouse" then
			local barn = plotGround(c, Vector3.new(34, 0, -46))
			Props.Part({
				Name = "Barn",
				Size = Vector3.new(18, 12, 14),
				Position = barn + Vector3.new(0, 6, 0),
				Color = rgb(150, 45, 40),
				Material = Enum.Material.WoodPlanks,
			})
			Props.Part({
				Name = "BarnRoof",
				Size = Vector3.new(20, 2, 16),
				Position = barn + Vector3.new(0, 13, 0),
				Color = rgb(80, 60, 50),
				Material = Enum.Material.Slate,
			})
		end
	end
	Props.Sign(plotGround(c, Vector3.new(4, 0, -half + 4)), player.DisplayName .. "'s " .. home.Name, facing)

	-- Your own bed: rest for free.
	local bed = Props.Part({
		Name = "Bedroll",
		Size = Vector3.new(4, 2, 7),
		Position = houseGround + Vector3.new(-16, 0.6, 2),
		Color = rgb(150, 50, 50),
		Material = Enum.Material.Fabric,
	})
	bed:SetAttribute("Owner", player.UserId)
	CollectionService:AddTag(bed, "RestSpot")

	-- Fields
	cropParts[player] = {}
	for i = 1, home.Fields do
		local ground = plotGround(c, fieldOffset(i))
		local soil = Props.Part({
			Name = "Field" .. i,
			Size = Vector3.new(12, 0.6, 12),
			Position = ground + Vector3.new(0, 0.1, 0),
			Color = rgb(95, 70, 50),
			Material = Enum.Material.Ground,
		})
		local crops = Instance.new("Folder")
		crops.Name = "Crops"
		crops.Parent = soil
		cropParts[player][i] = crops
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Plant"
		prompt.ObjectText = "Field " .. i
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = soil
		prompt.Triggered:Connect(function(who)
			if who ~= player then
				Services.PlayerService.Notify(who, "This field belongs to " .. player.DisplayName .. ".", "Error")
				return
			end
			PropertyService.UseField(player, i)
		end)
	end

	-- Animal pen
	if home.AnimalSlots > 0 then
		local penCenter = c + PEN_OFFSET
		local h = 13
		local pc = {
			plotGround(penCenter, Vector3.new(-h, 0, -h)),
			plotGround(penCenter, Vector3.new(h, 0, -h)),
			plotGround(penCenter, Vector3.new(h, 0, h)),
			plotGround(penCenter, Vector3.new(-h, 0, h)),
		}
		for k = 1, 4 do
			Props.Fence(pc[k], pc[k % 4 + 1])
		end
		local trough = Props.Part({
			Name = "Trough",
			Size = Vector3.new(6, 1.5, 2),
			Position = plotGround(penCenter, Vector3.new(0, 0, -h - 3)) + Vector3.new(0, 0.75, 0),
			Color = rgb(110, 80, 55),
			Material = Enum.Material.WoodPlanks,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = "Livestock"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = trough
		prompt.Triggered:Connect(function(who)
			if who == player then
				PropertyService.CollectAnimals(player)
			end
		end)
	end

	-- Stations
	local stationSpots =
		{ Vector3.new(4, 0, -36), Vector3.new(14, 0, -36), Vector3.new(24, 0, -36), Vector3.new(34, 0, -36) }
	for k, stationId in ipairs(home.Stations) do
		local station = Services.WorldService.BuildStation(
			stationId,
			plotGround(c, stationSpots[k] + Vector3.new(-30, 0, 30)),
			Vector3.new(0, 0, -1),
			model
		)
		station:SetAttribute("Owner", player.UserId)
	end

	model.Parent = workspace:FindFirstChild("Properties")
	plot.Model = model
	updateAllFields(player)
	buildAnimals(player, c + PEN_OFFSET)
end

local function assignPlot(player)
	if playerPlot[player] then
		return true
	end
	for i, plot in ipairs(plots) do
		if not plot.Owner then
			plot.Owner = player
			playerPlot[player] = i
			return true
		end
	end
	return false
end

local function releasePlot(player)
	local index = playerPlot[player]
	if index then
		plots[index].Owner = nil
		playerPlot[player] = nil
		buildForSale(index)
	end
	cropParts[player] = nil
	animalModels[player] = nil
end

-- Homes ------------------------------------------------------------------------------------

function PropertyService.HomePosition(player)
	local index = playerPlot[player]
	return index and plots[index].Center or nil
end

function PropertyService.BuyHome(player, homeId)
	local data = Services.PlayerService.GetData(player)
	local home = type(homeId) == "string" and Property.Homes[homeId]
	if not data or not home then
		return result(false)
	end
	if not Services.NPCService.IsNear(player, "LandSteward") then
		return result(false, "Speak to Holdsworth in Greenmeadow to buy land.")
	end
	local currentIndex = table.find(Property.Homes.Order, data.Property.Home)
	local newIndex = table.find(Property.Homes.Order, homeId)
	if currentIndex and currentIndex >= newIndex then
		return result(false, "You already own a home at least that grand.")
	end
	if data.Level < home.LevelReq then
		return result(false, "Requires level " .. home.LevelReq .. ".")
	end
	local credit = currentIndex and math.floor(Property.Homes[data.Property.Home].Price * Property.TradeInRate) or 0
	local price, tax = Services.GovernmentService.PriceWithTax(player, home.Price - credit)
	if not Services.PlayerService.SpendGold(player, price) then
		return result(false, "You need " .. price .. " gold.")
	end
	Services.GovernmentService.CollectTax(tax)
	data.Property.Home = homeId
	while #data.Property.Fields < home.Fields do
		table.insert(data.Property.Fields, { Crop = "", PlantedAt = 0, Fertilized = false })
	end
	if not assignPlot(player) then
		Services.PlayerService.Notify(
			player,
			"Every plot in this server is taken. Your home will appear when you join a server with room.",
			"Warning"
		)
	end
	buildHome(player)
	Services.QuestService.OnEvent(player, "BuyHome")
	Services.PlayerService.Notify(
		player,
		"You are now the owner of a " .. home.Name .. "! It stands in Greenmeadow.",
		"QuestComplete"
	)
	Services.PlayerService.Changed(player)
	return result(true)
end

-- Farming ----------------------------------------------------------------------------------

local function fieldReady(field)
	local crop = Property.Crops[field.Crop]
	local growTime = crop.GrowTime * (field.Fertilized and Property.FertilizerSpeedup or 1)
	return now() >= field.PlantedAt + growTime, field.PlantedAt + growTime - now()
end

function PropertyService.UseField(player, i)
	local data = Services.PlayerService.GetData(player)
	local field = data and data.Property.Fields[i]
	if not field then
		return
	end
	if field.Crop == "" then
		Remotes.Open:FireClient(player, "Plant", { Field = i })
		return
	end
	local ready, remaining = fieldReady(field)
	if ready then
		PropertyService.Harvest(player, i)
	elseif not field.Fertilized and (data.Materials.Fertilizer or 0) > 0 then
		Services.InventoryService.RemoveMaterial(player, "Fertilizer", 1)
		field.Fertilized = true
		updateFieldVisual(player, i)
		Services.PlayerService.Notify(player, "Fertilized. It will grow twice as fast.", "Success")
	else
		Services.PlayerService.Notify(
			player,
			Property.Crops[field.Crop].Name .. " ripe in " .. math.ceil(remaining / 60) .. " min.",
			"Info"
		)
	end
end

function PropertyService.Plant(player, i, cropId)
	local data = Services.PlayerService.GetData(player)
	local crop = type(cropId) == "string" and Property.Crops[cropId]
	local field = data and type(i) == "number" and data.Property.Fields[i]
	local home = data and Property.Homes[data.Property.Home]
	if not crop or not field or not home or i > home.Fields then
		return result(false)
	end
	if field.Crop ~= "" then
		return result(false, "Something is already growing there.")
	end
	if data.Level < (crop.LevelReq or 1) then
		return result(false, "Requires level " .. crop.LevelReq .. ".")
	end
	if not Services.InventoryService.RemoveMaterial(player, crop.Seed, 1) then
		return result(false, "You need " .. Items.Materials[crop.Seed].Name .. ". Old Tomas sells them.")
	end
	field.Crop = cropId
	field.PlantedAt = now()
	field.Fertilized = false
	updateFieldVisual(player, i)
	Services.PlayerService.Changed(player)
	return result(true, "Planted " .. crop.Name .. ".")
end

function PropertyService.Harvest(player, i)
	local data = Services.PlayerService.GetData(player)
	local field = data.Property.Fields[i]
	if not field or field.Crop == "" or not fieldReady(field) then
		return
	end
	local crop = Property.Crops[field.Crop]
	local amount = math.floor(math.random(crop.Yield[1], crop.Yield[2]) * festival() + 0.5)
	local cropId = field.Crop
	field.Crop = ""
	field.PlantedAt = 0
	field.Fertilized = false
	Services.InventoryService.AddMaterial(player, cropId, amount)
	data.Stats.Harvested += 1
	local soil = cropParts[player] and cropParts[player][i] and cropParts[player][i].Parent
	if soil then
		Remotes.Effect:FireClient(player, "Loot", soil.Position, "+" .. amount .. " " .. crop.Name)
		local prompt = soil:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ActionText = "Plant"
			prompt.ObjectText = "Field " .. i
		end
	end
	updateFieldVisual(player, i)
	Services.QuestService.OnEvent(player, "Harvest")
	Services.PlayerService.Changed(player)
end

-- Growth Tonic (Robux): ripen everything now.
function PropertyService.GrowAll(player)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return
	end
	for i, field in ipairs(data.Property.Fields) do
		if field.Crop ~= "" then
			field.PlantedAt = 0
			updateFieldVisual(player, i)
		end
	end
	Services.PlayerService.Changed(player)
end

-- Livestock --------------------------------------------------------------------------------

function PropertyService.BuyAnimal(player, animalType)
	local data = Services.PlayerService.GetData(player)
	local def = type(animalType) == "string" and Property.Animals[animalType]
	if not data or not def then
		return result(false)
	end
	if not Services.NPCService.IsNear(player, "Stablemaster") then
		return result(false, "Speak to Rhea at the Greenmeadow stables.")
	end
	local home = Property.Homes[data.Property.Home]
	if not home then
		return result(false, "You need a home with a pen first. See Holdsworth.")
	end
	if #data.Property.Animals >= home.AnimalSlots then
		return result(false, "Your pen is full (" .. home.AnimalSlots .. " animals). A bigger home has more room.")
	end
	local price, tax = Services.GovernmentService.PriceWithTax(player, def.Price)
	if not Services.PlayerService.SpendGold(player, price) then
		return result(false, "You need " .. price .. " gold.")
	end
	Services.GovernmentService.CollectTax(tax)
	table.insert(data.Property.Animals, { Type = animalType, Since = now() })
	local plot = plots[playerPlot[player]]
	if plot then
		buildAnimals(player, plot.Center + PEN_OFFSET)
	end
	Services.QuestService.OnEvent(player, "BuyAnimal")
	Services.PlayerService.Changed(player)
	return result(true, "A " .. def.Name .. " will be waiting in your pen.")
end

function PropertyService.CollectAnimals(player)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return
	end
	local t = now()
	local totals = {}
	for _, animal in ipairs(data.Property.Animals) do
		local def = Property.Animals[animal.Type]
		if def then
			local elapsed = t - animal.Since
			local produced = math.min(def.MaxStored, math.floor(elapsed / def.Interval))
			if produced > 0 then
				totals[def.Produces] = (totals[def.Produces] or 0) + produced
				animal.Since = produced >= def.MaxStored and t or (animal.Since + produced * def.Interval)
			end
		end
	end
	local parts = {}
	for material, count in pairs(totals) do
		local amount = math.floor(count * festival() + 0.5)
		Services.InventoryService.AddMaterial(player, material, amount)
		table.insert(parts, "+" .. amount .. " " .. Items.Materials[material].Name)
	end
	if #parts == 0 then
		Services.PlayerService.Notify(player, "Nothing to collect yet.", "Info")
	else
		Services.PlayerService.Notify(player, "Collected " .. table.concat(parts, ", "), "Success")
	end
	Services.PlayerService.Changed(player)
end

-- Horses -----------------------------------------------------------------------------------

function PropertyService.BuyHorse(player, horseId)
	local data = Services.PlayerService.GetData(player)
	local def = type(horseId) == "string" and Property.Horses[horseId]
	if not data or not def or def.Premium then
		return result(false)
	end
	if not Services.NPCService.IsNear(player, "Stablemaster") then
		return result(false, "Speak to Rhea at the Greenmeadow stables.")
	end
	if data.Property.Horses[horseId] then
		return result(false, "You already own that horse.")
	end
	if data.Level < (def.LevelReq or 1) then
		return result(false, "Requires level " .. def.LevelReq .. ".")
	end
	local price, tax = Services.GovernmentService.PriceWithTax(player, def.Price)
	if not Services.PlayerService.SpendGold(player, price) then
		return result(false, "You need " .. price .. " gold.")
	end
	Services.GovernmentService.CollectTax(tax)
	PropertyService.GrantHorse(player, horseId)
	Services.QuestService.OnEvent(player, "BuyHorse")
	return result(true, "The " .. def.Name .. " is yours! Press H to ride.")
end

function PropertyService.GrantHorse(player, horseId)
	local data = Services.PlayerService.GetData(player)
	if not data or not Property.Horses[horseId] then
		return
	end
	data.Property.Horses[horseId] = true
	if data.Property.ActiveHorse == "" then
		data.Property.ActiveHorse = horseId
	end
	Services.PlayerService.Changed(player)
end

function PropertyService.SetActiveHorse(player, horseId)
	local data = Services.PlayerService.GetData(player)
	if not data or type(horseId) ~= "string" or not data.Property.Horses[horseId] then
		return result(false)
	end
	data.Property.ActiveHorse = horseId
	if mounted[player] then
		PropertyService.Dismount(player)
	end
	Services.PlayerService.Changed(player)
	return result(true)
end

local function buildHorse(def)
	local model = Instance.new("Model")
	model.Name = "Mount"
	local function add(name, size, offset, color, material)
		local p = ModelBuilder.Part({
			Name = name,
			Size = size,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Massless = true,
		})
		p:SetAttribute("Offset", offset)
		p.Parent = model
		return p
	end
	local body = add("HorseBody", Vector3.new(2.2, 2.2, 5.2), CFrame.new(), def.Color)
	add("Neck", Vector3.new(1.2, 2.6, 1.3), CFrame.new(0, 1.4, -2.6) * CFrame.Angles(math.rad(30), 0, 0), def.Color)
	add("Head", Vector3.new(1, 1, 2.2), CFrame.new(0, 2.6, -3.7) * CFrame.Angles(math.rad(-20), 0, 0), def.Color)
	add("Mane", Vector3.new(0.4, 2.4, 1), CFrame.new(0, 1.9, -2.2) * CFrame.Angles(math.rad(30), 0, 0), def.Mane)
	add("Tail", Vector3.new(0.4, 2.4, 0.4), CFrame.new(0, -0.2, 2.9) * CFrame.Angles(math.rad(25), 0, 0), def.Mane)
	add(
		"Saddle",
		Vector3.new(2.3, 0.3, 1.8),
		CFrame.new(0, 1.15, -0.2),
		Color3.fromRGB(90, 50, 30),
		Enum.Material.Leather
	)
	for _, o in ipairs({
		Vector3.new(-0.7, 0, -1.9),
		Vector3.new(0.7, 0, -1.9),
		Vector3.new(-0.7, 0, 1.9),
		Vector3.new(0.7, 0, 1.9),
	}) do
		add("Leg", Vector3.new(0.5, 2.6, 0.5), CFrame.new(o.X, -2.3, o.Z), def.Color:Lerp(Color3.new(0, 0, 0), 0.2))
	end
	if def.Glow then
		for side = -1, 1, 2 do
			local eye = add(
				"Eye",
				Vector3.new(0.15, 0.2, 0.2),
				CFrame.new(side * 0.5, 2.75, -4.3),
				def.Glow,
				Enum.Material.Neon
			)
			eye.CastShadow = false
		end
	end
	model.PrimaryPart = body
	return model
end

function PropertyService.Mount(player)
	local data = Services.PlayerService.GetData(player)
	local humanoid, character = Services.PlayerService.GetHumanoid(player)
	local def = data and Property.Horses[data.Property.ActiveHorse]
	if not humanoid or not def or not data.Property.Horses[data.Property.ActiveHorse] then
		return result(false, "You don't own a horse. Rhea in Greenmeadow sells them.")
	end
	if mounted[player] then
		return result(true)
	end
	if Services.StealthService.IsCrouching(player) then
		Services.StealthService.SetCrouch(player, false)
	end
	if Services.CombatService.InCombat(player) then
		return result(false, "You can't mount up in combat.")
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local horse = buildHorse(def)
	local lift = 2.6
	character:SetAttribute("BaseHipHeight", humanoid.HipHeight)
	humanoid.HipHeight += lift
	local rootHalf = root.Size.Y / 2
	local base = CFrame.new(0, -(rootHalf + 0.9), 0.2)
	for _, p in ipairs(horse:GetChildren()) do
		local offset = base * p:GetAttribute("Offset")
		p.CFrame = root.CFrame * offset
		ModelBuilder.Weld(root, p, offset)
	end
	horse.Parent = character
	mounted[player] = data.Property.ActiveHorse
	character:SetAttribute("Mounted", true)
	humanoid.WalkSpeed = def.Speed
	return result(true)
end

function PropertyService.Dismount(player)
	if not mounted[player] then
		return
	end
	mounted[player] = nil
	local character = player.Character
	if character then
		local horse = character:FindFirstChild("Mount")
		if horse then
			horse:Destroy()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local base = character:GetAttribute("BaseHipHeight")
		if humanoid and base then
			humanoid.HipHeight = base
		end
		character:SetAttribute("Mounted", nil)
	end
	Services.PlayerService.RefreshStats(player)
end

function PropertyService.ToggleMount(player)
	if mounted[player] then
		PropertyService.Dismount(player)
		return result(true)
	end
	return PropertyService.Mount(player)
end

function PropertyService.IsMounted(player)
	return mounted[player] ~= nil
end

function PropertyService.MountSpeed(player)
	local horseId = mounted[player]
	return horseId and Property.Horses[horseId].Speed or nil
end

-- Setup ------------------------------------------------------------------------------------

function PropertyService.Init(services)
	Services = services
	Services.DataService.Loaded:Connect(function(player, data)
		-- Make sure the save has one field entry per field of the home.
		local home = Property.Homes[data.Property.Home]
		if home then
			while #data.Property.Fields < home.Fields do
				table.insert(data.Property.Fields, { Crop = "", PlantedAt = 0, Fertilized = false })
			end
			if assignPlot(player) then
				buildHome(player)
			end
		end
	end)
end

function PropertyService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Properties"
	folder.Parent = workspace
	local farm = World.Farmlands.Position
	for i, offset in ipairs(Property.Plots) do
		local marker = workspace:FindFirstChild("Map")
			and workspace.Map:FindFirstChild("Markers")
			and workspace.Map.Markers:FindFirstChild("Plot" .. i)
		plots[i] = { Center = marker and marker.Position or (farm + offset) }
		if not plots[i].Owner then
			buildForSale(i)
		end
	end
	-- Homes for players who loaded before Start finished.
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Services.PlayerService.GetData(player)
		if data and Property.Homes[data.Property.Home] and assignPlot(player) then
			buildHome(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		mounted[player] = nil
		releasePlot(player)
	end)

	while true do
		task.wait(5)
		for player in pairs(cropParts) do
			if player.Parent then
				updateAllFields(player)
			end
		end
	end
end

return PropertyService
