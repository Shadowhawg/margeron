-- Skill tree window: three trees side by side, click a node to see details and learn it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skills = require(Shared.Config.Skills)
local GameConfig = require(Shared.Config.GameConfig)
local Stats = require(Shared.Stats)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local New = Create.New

local SkillsPanel = {}

local selected = nil

local function render(content)
	local data = State.Data

	Create.Label("Skill Points: " .. data.SkillPoints, {
		Font = Theme.BoldFont,
		TextSize = 18,
		TextColor3 = data.SkillPoints > 0 and Theme.Gold or Theme.Muted,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})

	local treesFrame = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -150),
		Parent = content,
	}, { Create.List(12, Enum.FillDirection.Horizontal) })

	for treeIndex, treeId in ipairs(Skills.Order) do
		local tree = Skills.Trees[treeId]
		local column = New("Frame", {
			LayoutOrder = treeIndex,
			Size = UDim2.new(1 / 3, -8, 1, 0),
			BackgroundColor3 = Theme.Panel,
			Parent = treesFrame,
		}, { Create.Corner(8), Create.Stroke(tree.Color, 2) })
		Create.Label(tree.Name, {
			Font = Theme.TitleFont,
			TextSize = 26,
			TextColor3 = tree.Color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 4),
			Parent = column,
		})
		Create.Label(tree.Description, {
			TextSize = 12,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 34),
			Parent = column,
		})

		for nodeId, node in pairs(tree.Nodes) do
			local rank = data.Skills[nodeId] or 0
			local canUnlock = Stats.CanUnlock(data, nodeId)
			local color = Theme.PanelLight
			if rank >= node.MaxRank then
				color = tree.Color:Lerp(Color3.new(0, 0, 0), 0.25)
			elseif rank > 0 then
				color = tree.Color:Lerp(Color3.new(0, 0, 0), 0.55)
			end
			local button = Create.Button(node.Name .. "\n" .. rank .. "/" .. node.MaxRank, color, function()
				selected = nodeId
				Windows.Render()
			end, {
				Size = UDim2.new(0.5, -16, 0, 50),
				Position = UDim2.new((node.Column - 1) * 0.5, 8, 0, 56 + (node.Tier - 1) * 62),
				TextSize = 13,
				TextWrapped = true,
				Parent = column,
			})
			if canUnlock then
				button:FindFirstChildOfClass("UIStroke").Color = Theme.Gold
				button:FindFirstChildOfClass("UIStroke").Thickness = 2
			end
			if selected == nodeId then
				button:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
				button:FindFirstChildOfClass("UIStroke").Thickness = 3
			end
			if node.Ability then
				button.Text = "★ " .. button.Text
			end
		end
	end

	-- Detail panel
	local detail = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = Theme.Panel,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(10) })

	local node = selected and Stats.FindNode(selected)
	if not node then
		Create.Label("Select a skill to see what it does. ★ = active ability. Every level grants 1 skill point; "
			.. "deeper tiers unlock at levels "
			.. table.concat(GameConfig.TierLevelRequirements, ", ")
			.. ". Seer Ilsa in Riverwatch can reset your skills.", {
			TextColor3 = Theme.Muted,
			Size = UDim2.fromScale(1, 1),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = detail,
		})
		return
	end

	local rank = data.Skills[selected] or 0
	local canUnlock, reason = Stats.CanUnlock(data, selected)
	Create.Label(node.Name .. "  (Rank " .. rank .. "/" .. node.MaxRank .. ")", {
		Font = Theme.BoldFont,
		TextSize = 18,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, -150, 0, 24),
		Parent = detail,
	})
	Create.Label(node.Description, {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, -150, 0, 40),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = detail,
	})
	local reqText = "Tier " .. node.Tier .. " (Lv " .. (GameConfig.TierLevelRequirements[node.Tier] or 1) .. ")"
	if node.Requires then
		local names = {}
		for _, req in ipairs(node.Requires) do
			table.insert(names, Stats.FindNode(req).Name)
		end
		reqText ..= "  ·  Requires: " .. table.concat(names, ", ")
	end
	Create.Label(reqText, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, -150, 0, 20),
		TextSize = 13,
		TextColor3 = Theme.Muted,
		Parent = detail,
	})
	local button = Create.Button(canUnlock and "Learn" or (reason or "Locked"), canUnlock and Theme.Good or Theme.PanelLight, function()
		if canUnlock then
			Net.Request("UnlockSkill", selected)
		end
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(140, 44),
		TextWrapped = true,
		TextSize = 13,
		Parent = detail,
	})
	button.AutoButtonColor = canUnlock
end

function SkillsPanel.Init()
	Windows.Register("Skills", "Skills", render)
end

return SkillsPanel
