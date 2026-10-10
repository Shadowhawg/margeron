-- Quest journal: active quests on the left, details on the right.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Items = require(Shared.Config.Items)
local QuestRules = require(Shared.QuestRules)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local New = Create.New

local QuestsPanel = {}

local selected = nil

local TYPE_COLORS = {
	Main = Theme.Gold,
	Side = Theme.Accent,
	Bounty = Color3.fromRGB(180, 140, 220),
}

local function render(content)
	local data = State.Data
	local keys = QuestRules.ActiveKeys(data)
	if not selected or not data.Quests.Active[selected] then
		selected = data.TrackedQuest ~= "" and data.Quests.Active[data.TrackedQuest] and data.TrackedQuest or keys[1]
	end

	local list = New("ScrollingFrame", {
		Size = UDim2.fromScale(0.38, 1),
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(8), Create.List(6) })

	if #keys == 0 then
		Create.Label("No active quests. Talk to people in Riverwatch, or check the Bounty Board.", {
			TextColor3 = Theme.Muted,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		})
	end
	for i, key in ipairs(keys) do
		local def = QuestRules.GetDef(data, key)
		local ready = QuestRules.IsReady(data, key)
		local label = def.Name .. (ready and "  ✓" or "") .. (data.TrackedQuest == key and "  ◆" or "")
		local button = Create.Button(label, key == selected and Theme.PanelLight or Theme.Background, function()
			selected = key
			Windows.Render()
		end, {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TYPE_COLORS[def.Type] or Theme.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = list,
		})
		New("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = button })
	end

	local detail = New("Frame", {
		Position = UDim2.new(0.38, 12, 0, 0),
		Size = UDim2.new(0.62, -12, 1, 0),
		BackgroundColor3 = Theme.Panel,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(14), Create.List(10) })

	local stats = data.Stats
	if not selected then
		Create.Label(
			"Quests completed: "
				.. stats.QuestsCompleted
				.. "\nBounties completed: "
				.. data.Bounties.Completed
				.. "\nRenown: "
				.. data.Renown,
			{
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = detail,
			}
		)
		return
	end

	local def = QuestRules.GetDef(data, selected)
	Create.Label(def.Name, {
		Font = Theme.TitleFont,
		TextSize = 28,
		TextColor3 = TYPE_COLORS[def.Type] or Theme.Accent,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = detail,
	})
	Create.Label((def.Type == "Bounty" and (def.Daily and "Daily Contract" or "Bounty") or (def.Type .. " Quest")), {
		TextSize = 13,
		TextColor3 = Theme.Muted,
		LayoutOrder = 2,
		Parent = detail,
	})
	Create.Label(def.Description, { AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = detail })

	for i, objective in ipairs(def.Objectives) do
		local progress = QuestRules.GetProgress(data, selected, i)
		local done = progress >= objective.Count
		Create.Label((done and "✓ " or "• ") .. objective.Text .. "  " .. progress .. "/" .. objective.Count, {
			TextColor3 = done and Theme.Good or Theme.Text,
			Font = Theme.BoldFont,
			LayoutOrder = 3 + i,
			Parent = detail,
		})
	end
	local turnIn = def.TurnIn == "Board" and "the Bounty Board" or World.NPCs[def.TurnIn].Name
	Create.Label("Turn in: " .. turnIn, { TextColor3 = Theme.Muted, TextSize = 14, LayoutOrder = 20, Parent = detail })

	local rewards = {}
	local r = def.Rewards or {}
	if r.XP then
		table.insert(rewards, r.XP .. " XP")
	end
	if r.Gold then
		table.insert(rewards, r.Gold .. " gold")
	end
	if r.Weapon then
		table.insert(rewards, Items.Weapons[r.Weapon].Name)
	end
	if r.Cosmetic then
		table.insert(rewards, Items.Cosmetics[r.Cosmetic].Name)
	end
	Create.Label("Rewards: " .. table.concat(rewards, ", "), {
		TextColor3 = Theme.Gold,
		LayoutOrder = 21,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = detail,
	})

	local buttons = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 30,
		Parent = detail,
	}, { Create.List(8, Enum.FillDirection.Horizontal) })
	local key = selected
	Create.Button(data.TrackedQuest == key and "Tracking ◆" or "Track", Theme.PanelLight, function()
		Net.Request("TrackQuest", key)
	end, { Parent = buttons })
	if def.Type ~= "Main" then
		Create.Button("Abandon", Theme.Bad, function()
			Net.Request("AbandonQuest", key)
		end, { Parent = buttons })
	end
end

function QuestsPanel.Init()
	Windows.Register("Quests", "Journal", render)
end

return QuestsPanel
