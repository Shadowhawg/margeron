-- Health/XP bars, gold, ability hotbar, tracked quest and menu buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local World = require(Shared.Config.World)
local Items = require(Shared.Config.Items)
local Leveling = require(Shared.Leveling)
local QuestRules = require(Shared.QuestRules)
local Util = require(Shared.Util)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Windows = require(script.Parent.Windows)
local New = Create.New

local player = Players.LocalPlayer

local HUD = {}

local gui
local hpFill, hpText, xpFill, levelText, goldText, saveWarning
local slots = {} -- [abilityId or "Attack"] = { Frame, Overlay, Label }
local cooldownEnds = {} -- [abilityId] = { Ends, Duration }
local questFrame, questTitle, questList
local skillBadge

local function bar(parent, position, size, color)
	local back = New("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(25, 20, 18),
		BorderSizePixel = 0,
		Parent = parent,
	}, { Create.Corner(5), Create.Stroke(Theme.Border) })
	local fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	}, { Create.Corner(5) })
	local text = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.BoldFont,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
		Parent = back,
	})
	return fill, text
end

local function buildVitals()
	local frame = New("Frame", {
		Name = "Vitals",
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(330, 92),
		Parent = gui,
	}, { Create.Corner(8) })

	local badge = New("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Theme.PanelLight,
		Parent = frame,
	}, { Create.Corner(28), Create.Stroke(Theme.Accent, 2) })
	levelText = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.TitleFont,
		TextSize = 28,
		TextColor3 = Theme.Accent,
		Text = "1",
		Parent = badge,
	})

	hpFill, hpText = bar(frame, UDim2.fromOffset(78, 12), UDim2.fromOffset(240, 20), Theme.Health)
	xpFill, _ = bar(frame, UDim2.fromOffset(78, 38), UDim2.fromOffset(240, 10), Theme.XP)
	goldText = Create.Label("0 gold", {
		Position = UDim2.fromOffset(78, 56),
		Size = UDim2.fromOffset(240, 20),
		TextColor3 = Theme.Gold,
		Font = Theme.BoldFont,
		Parent = frame,
	})
	saveWarning = Create.Label("TEST MODE: progress is not saved", {
		Position = UDim2.fromOffset(10, 72),
		Size = UDim2.fromOffset(310, 16),
		TextSize = 12,
		TextColor3 = Theme.Bad,
		Visible = false,
		Parent = frame,
	})
end

local function buildHotbar()
	local frame = New("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(4 * 70 + 3 * 8, 70),
		Parent = gui,
	}, { Create.List(8, Enum.FillDirection.Horizontal) })

	local entries = { { Id = "Attack", Name = "Attack", Key = "Click", Color = Theme.Accent } }
	for _, abilityId in ipairs(Abilities.Order) do
		local ability = Abilities[abilityId]
		table.insert(entries, {
			Id = abilityId,
			Name = ability.Name,
			Key = UserInputService:GetStringForKeyCode(ability.Key),
			Color = ability.Color,
		})
	end

	for i, entry in ipairs(entries) do
		local slot = New("Frame", {
			Name = entry.Id,
			LayoutOrder = i,
			Size = UDim2.fromOffset(70, 70),
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.15,
			Parent = frame,
		}, { Create.Corner(8), Create.Stroke(entry.Color, 2) })
		local label = Create.Label(entry.Name, {
			Size = UDim2.new(1, -6, 0, 30),
			Position = UDim2.fromOffset(3, 22),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 12,
			Font = Theme.BoldFont,
			Parent = slot,
		})
		Create.Label(entry.Key, {
			Size = UDim2.new(1, -6, 0, 14),
			Position = UDim2.fromOffset(4, 3),
			TextSize = 11,
			TextColor3 = Theme.Muted,
			Parent = slot,
		})
		local overlay = New("Frame", {
			Name = "Cooldown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = slot,
		}, { Create.Corner(8) })
		slots[entry.Id] = { Frame = slot, Overlay = overlay, Label = label }
	end
end

local function buildQuestTracker()
	questFrame = New("Frame", {
		Name = "QuestTracker",
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, { Create.Corner(8), Create.Padding(10), Create.List(4) })
	questTitle = Create.Label("", {
		Font = Theme.BoldFont,
		TextColor3 = Theme.Accent,
		TextSize = 16,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = questFrame,
	})
	questList = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = questFrame,
	}, { Create.List(2) })
end

local function buildMenu()
	local frame = New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(4 * 92 + 3 * 6, 44),
		Parent = gui,
	}, { Create.List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
	local buttons = {
		{ "Skills", "K", "Skills" },
		{ "Quests", "J", "Quests" },
		{ "Inventory", "I", "Inventory" },
		{ "Store", "B", "Store" },
	}
	for i, b in ipairs(buttons) do
		local button = Create.Button(b[1] .. " (" .. b[2] .. ")", b[1] == "Store" and Theme.Robux or Theme.Panel, function()
			Windows.Toggle(b[3])
		end, { LayoutOrder = i, Size = UDim2.fromOffset(92, 40), TextSize = 13 })
		button.Parent = frame
		if b[1] == "Skills" then
			skillBadge = New("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Theme.Bad,
				TextColor3 = Color3.new(1, 1, 1),
				Font = Theme.BoldFont,
				TextSize = 13,
				Visible = false,
				ZIndex = 3,
				Parent = button,
			}, { Create.Corner(11) })
		end
	end
end

local function objectiveText(data, key, i, objective)
	local progress = QuestRules.GetProgress(data, key, i)
	local done = progress >= objective.Count
	local text = objective.Text
	if objective.Count > 1 then
		text ..= "  " .. progress .. "/" .. objective.Count
	end
	return (done and "✓ " or "• ") .. text, done
end

local function renderQuestTracker(data)
	local key = data.TrackedQuest
	if key == "" or not data.Quests.Active[key] then
		key = QuestRules.ActiveKeys(data)[1]
	end
	Create.Clear(questList)
	if not key then
		questTitle.Text = "No active quests"
		Create.Label("Visit the Bounty Board in Riverwatch for work.", {
			TextSize = 13,
			TextColor3 = Theme.Muted,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = questList,
		})
		return
	end
	local def = QuestRules.GetDef(data, key)
	questTitle.Text = def.Name
	if QuestRules.IsReady(data, key) then
		local where = def.TurnIn == "Board" and "the Bounty Board" or World.NPCs[def.TurnIn].Name
		Create.Label("✓ Return to " .. where, {
			TextSize = 14,
			TextColor3 = Theme.Good,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = questList,
		})
		return
	end
	for i, objective in ipairs(def.Objectives) do
		local text, done = objectiveText(data, key, i, objective)
		Create.Label(text, {
			TextSize = 14,
			LayoutOrder = i,
			TextColor3 = done and Theme.Good or Theme.Text,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = questList,
		})
	end
end

local function render(data)
	local stats = State.Stats
	levelText.Text = tostring(data.Level)
	goldText.Text = Util.FormatNumber(data.Gold) .. " gold"
	local needed = Leveling.XPToNext(data.Level)
	xpFill.Size = UDim2.fromScale(math.clamp(data.XP / needed, 0, 1), 1)
	saveWarning.Visible = not data.Persistent

	for _, abilityId in ipairs(Abilities.Order) do
		local slot = slots[abilityId]
		local unlocked = stats.Abilities[abilityId] == true
		slot.Frame.BackgroundTransparency = unlocked and 0.15 or 0.7
		slot.Label.TextColor3 = unlocked and Theme.Text or Theme.Muted
		slot.Label.Text = unlocked and Abilities[abilityId].Name or "Locked"
	end
	local weapon = Items.Weapons[data.EquippedWeapon]
	slots.Attack.Label.Text = weapon and weapon.Name or "Attack"

	skillBadge.Visible = data.SkillPoints > 0
	skillBadge.Text = tostring(data.SkillPoints)
	renderQuestTracker(data)
end

function HUD.StartCooldown(abilityId, duration)
	if duration and duration > 0 then
		cooldownEnds[abilityId] = { Ends = os.clock() + duration, Duration = duration }
	else
		cooldownEnds[abilityId] = nil
	end
end

function HUD.ResetCooldown(abilityId)
	cooldownEnds[abilityId] = nil
end

function HUD.IsOnCooldown(abilityId)
	local cd = cooldownEnds[abilityId]
	return cd ~= nil and os.clock() < cd.Ends
end

function HUD.Init()
	gui = Create.Screen("HUD", 1)
	buildVitals()
	buildHotbar()
	buildQuestTracker()
	buildMenu()
end

function HUD.Start()
	State.Observe(render)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			hpFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
			hpText.Text = math.ceil(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
		end
		local now = os.clock()
		for id, slot in pairs(slots) do
			local cd = cooldownEnds[id]
			if cd and now < cd.Ends then
				slot.Overlay.Size = UDim2.fromScale(1, (cd.Ends - now) / cd.Duration)
			else
				slot.Overlay.Size = UDim2.fromScale(1, 0)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			Windows.Toggle("Skills")
		elseif input.KeyCode == Enum.KeyCode.J then
			Windows.Toggle("Quests")
		elseif input.KeyCode == Enum.KeyCode.I then
			Windows.Toggle("Inventory")
		elseif input.KeyCode == Enum.KeyCode.B then
			Windows.Toggle("Store")
		end
	end)
end

return HUD
