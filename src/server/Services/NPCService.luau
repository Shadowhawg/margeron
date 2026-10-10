-- Town NPCs: builds them, handles "E to talk", and drives dialogue options.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Quests = require(Shared.Config.Quests)
local GameConfig = require(Shared.Config.GameConfig)
local QuestRules = require(Shared.QuestRules)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local ModelBuilder = require(script.Parent.Parent.Lib.ModelBuilder)

local NPCService = {}
local Services

local npcRoots = {} -- [npcId] = BasePart

local function buildBoard(npcId, npc, folder)
	local position = Services.WorldService.GetNPCPosition(npcId)
	local ground = Services.WorldService.GroundAt(position)
	local model = Instance.new("Model")
	model.Name = npc.Name
	for side = -1, 1, 2 do
		local post = ModelBuilder.Part({
			Name = "Post",
			Size = Vector3.new(0.6, 8, 0.6),
			Position = ground + Vector3.new(side * 3.5, 4, 0),
			Color = Color3.fromRGB(90, 65, 45),
			Material = Enum.Material.Wood,
			Anchored = true,
		})
		post.Parent = model
	end
	local board = ModelBuilder.Part({
		Name = "Board",
		Size = Vector3.new(8, 5, 0.4),
		CFrame = CFrame.lookAt(
			ground + Vector3.new(0, 5, 0),
			ground + Vector3.new(0, 5, 0) + (World.Town.Position - ground) * Vector3.new(1, 0, 1)
		),
		Color = Color3.fromRGB(130, 95, 60),
		Material = Enum.Material.WoodPlanks,
		Anchored = true,
	})
	board.Parent = model
	for i = 1, 5 do
		local paper = ModelBuilder.Part({
			Name = "Notice",
			Size = Vector3.new(1.4, 1.8, 0.05),
			CFrame = board.CFrame
				* CFrame.new(-2.8 + (i - 1) * 1.4, (i % 2) * 0.8 - 0.3, -0.25)
				* CFrame.Angles(0, 0, math.rad((i * 7) % 11 - 5)),
			Color = Color3.fromRGB(235, 225, 195),
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
		})
		paper.Parent = model
	end
	model.PrimaryPart = board
	model.Parent = folder
	ModelBuilder.NameTag(board, 4, npc.Name, npc.Role, Color3.fromRGB(255, 220, 140))
	return board
end

local function buildPerson(npcId, npc, folder)
	local model, info = ModelBuilder.Creature(npc.Name, {
		Shape = "Humanoid",
		Scale = 1,
		Color = npc.Color,
		HeadColor = Color3.fromRGB(234, 192, 160),
		EyeColor = Color3.fromRGB(40, 30, 30),
	})
	local position = Services.WorldService.GetNPCPosition(npcId)
	local ground = Services.WorldService.GroundAt(position)
	local facing = World.Town.Position + Vector3.new(0, 0, 15)
	local rootPos = ground + Vector3.new(0, info.GroundOffset, 0)
	model:PivotTo(CFrame.lookAt(rootPos, Vector3.new(facing.X, rootPos.Y, facing.Z)))
	model.Parent = folder
	ModelBuilder.NameTag(
		info.Root,
		info.Height - info.GroundOffset + 1.8,
		npc.Name,
		npc.Role,
		Color3.fromRGB(255, 255, 255)
	)
	-- Potter about near the post (indoor NPCs keep to a smaller patch).
	Services.TownLifeService.Animate(model, info, ground, npc.Wander or 6)
	return info.Root
end

-- Builds the conversation shown to the player.
local function buildDialogue(player, npcId, completed)
	local npc = World.NPCs[npcId]
	local data = Services.PlayerService.GetData(player)
	local text = npc.Greeting
	-- People change as the story moves on: use the greeting for the latest milestone reached.
	for _, step in ipairs(npc.Greetings or {}) do
		if data.Quests.Completed[step.After] then
			text = step.Text
		end
	end
	local options = {}

	if completed and #completed > 0 then
		local last = completed[#completed]
		text = (last.Dialogue and last.Dialogue.Complete) or ("Quest complete: " .. last.Name)
	else
		-- Remind the player about unfinished quests this NPC cares about.
		for _, key in ipairs(QuestRules.ActiveKeys(data)) do
			local def = QuestRules.GetDef(data, key)
			if def.TurnIn == npcId and def.Dialogue and def.Dialogue.Progress then
				text = def.Dialogue.Progress
				break
			end
		end
	end

	for _, questId in ipairs(QuestRules.OffersFor(data, npcId)) do
		local def = Quests[questId]
		local prefix = def.Type == "Main" and "[Main Quest] " or "[Quest] "
		local label = prefix .. def.Name
		if data.Level < (def.LevelReq or 1) then
			label ..= "  (Requires Lv " .. def.LevelReq .. ")"
		end
		table.insert(options, { Id = "quest:" .. questId, Label = label })
	end

	if npc.Shop then
		table.insert(options, { Id = "shop", Label = "Show me your wares." })
	end
	if npc.RestCost then
		table.insert(options, { Id = "rest", Label = "I'd like a bed. (" .. npc.RestCost .. " gold)" })
	end
	if npcId == "Blacksmith" then
		table.insert(options, { Id = "shop", Label = "Show me your wares." })
	elseif npcId == "Board" or npc.Alias == "Board" then
		table.insert(options, { Id = "board", Label = "Read the notices." })
	elseif npcId == "Mystic" then
		local cost = Services.SkillService.RespecCost(data)
		table.insert(options, { Id = "respec", Label = "Reshape my path. (Reset skills: " .. cost .. " gold)" })
		table.insert(
			options,
			{ Id = "reshape", Label = "Change how I look. (" .. Services.CharacterService.ReshapeCost .. " gold)" }
		)
	elseif npcId == "Trader" then
		table.insert(options, { Id = "trade", Label = "I have goods to sell." })
	elseif npcId == "Farmer" then
		table.insert(options, { Id = "seeds", Label = "I need seeds." })
	elseif npcId == "LandSteward" then
		table.insert(options, { Id = "estate", Label = "Show me the deeds." })
	elseif npcId == "Stablemaster" then
		table.insert(options, { Id = "stable", Label = "Show me your horses and livestock." })
	elseif npcId == "Herald" then
		table.insert(options, { Id = "hall", Label = "Enter the Hall. (Elections and decrees)" })
	end
	table.insert(options, { Id = "bye", Label = "Farewell." })

	local root = npcRoots[npcId]
	return {
		NPC = npcId,
		Name = npc.Name,
		Role = npc.Role,
		Text = text,
		Options = options,
		Position = root and root.Position or nil,
		IsObject = npc.IsObject,
	}
end

local function isNear(player, npcId)
	if type(npcId) ~= "string" then
		return false
	end
	local _, character = Services.PlayerService.GetHumanoid(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local npcRoot = npcRoots[npcId]
	if not root or not npcRoot then
		return false
	end
	return Util.FlatDistance(root.Position, npcRoot.Position) <= GameConfig.NPCInteractDistance + 4
end

function NPCService.Talk(player, npcId)
	if not Services.PlayerService.GetData(player) or not isNear(player, npcId) then
		return
	end
	-- Turn to face the player.
	local npcRoot = npcRoots[npcId]
	local _, character = Services.PlayerService.GetHumanoid(player)
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if npcRoot and playerRoot and not World.NPCs[npcId].IsObject then
		local model = npcRoot.Parent
		Services.TownLifeService.Pause(model, 30)
		local pivot = model:GetPivot()
		model:PivotTo(
			CFrame.lookAt(pivot.Position, Vector3.new(playerRoot.Position.X, pivot.Position.Y, playerRoot.Position.Z))
		)
	end
	-- Some NPCs stand in for another (the city's notice board is also "the Bounty Board").
	local completed = Services.QuestService.OnTalk(player, World.NPCs[npcId].Alias or npcId)
	Remotes.Dialogue:FireClient(player, buildDialogue(player, npcId, completed))
end

-- Handles a dialogue button. Returns what the client should do next.
function NPCService.Choose(player, npcId, optionId)
	if type(npcId) ~= "string" or type(optionId) ~= "string" or not World.NPCs[npcId] then
		return { close = true }
	end
	if not isNear(player, npcId) then
		return { close = true, message = "You walked away." }
	end
	local data = Services.PlayerService.GetData(player)

	local questId = optionId:match("^quest:(.+)$")
	if questId and Quests[questId] and Quests[questId].Giver == npcId then
		local def = Quests[questId]
		local ok, reason = QuestRules.CanAccept(data, questId)
		local options = {}
		if ok then
			table.insert(options, { Id = "accept:" .. questId, Label = "I'll do it." })
		end
		table.insert(options, { Id = "back", Label = ok and "Not now." or "Back." })
		local text = (def.Dialogue and def.Dialogue.Offer) or def.Description
		if not ok then
			text ..= "\n\n(" .. reason .. ")"
		end
		return {
			dialogue = {
				NPC = npcId,
				Name = World.NPCs[npcId].Name,
				Role = World.NPCs[npcId].Role,
				Text = text,
				Options = options,
			},
		}
	end

	local acceptId = optionId:match("^accept:(.+)$")
	if acceptId and Quests[acceptId] and Quests[acceptId].Giver == npcId then
		local result = Services.QuestService.Accept(player, acceptId)
		return { close = true, message = result.message }
	end

	local npc = World.NPCs[npcId]
	if optionId == "shop" and (npcId == "Blacksmith" or npc.Shop) then
		return { open = npc.Shop or "Blacksmith" }
	elseif optionId == "rest" and npc.RestCost then
		Services.CraftingService.Rest(player, npc.RestCost)
		return { close = true }
	elseif optionId == "board" and (npcId == "Board" or npc.Alias == "Board") then
		return { open = "Board", board = Services.BountyService.GetBoard(player) }
	elseif optionId == "respec" and npcId == "Mystic" then
		local result = Services.SkillService.Respec(player)
		return { close = true, message = result.message }
	elseif optionId == "reshape" and npcId == "Mystic" then
		local result = Services.CharacterService.BeginReshape(player)
		return { close = true, message = result.message, open = result.open }
	elseif optionId == "trade" and npcId == "Trader" then
		return { open = "Trader" }
	elseif optionId == "seeds" and npcId == "Farmer" then
		return { open = "Seeds" }
	elseif optionId == "estate" and npcId == "LandSteward" then
		return { open = "Estate" }
	elseif optionId == "stable" and npcId == "Stablemaster" then
		return { open = "Stable" }
	elseif optionId == "hall" and npcId == "Herald" then
		return { open = "Government", args = Services.GovernmentService.GetState(player) }
	elseif optionId == "back" then
		return { dialogue = buildDialogue(player, npcId, nil) }
	end
	return { close = true }
end

NPCService.IsNear = isNear

function NPCService.Init(services)
	Services = services
end

function NPCService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = workspace

	for npcId, npc in pairs(World.NPCs) do
		local root = npc.IsObject and buildBoard(npcId, npc, folder) or buildPerson(npcId, npc, folder)
		root.Parent:SetAttribute("NPCId", npcId)
		npcRoots[npcId] = root

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = npc.IsObject and "Read" or "Talk"
		prompt.ObjectText = npc.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = GameConfig.NPCInteractDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			NPCService.Talk(player, npcId)
		end)
	end
end

return NPCService
