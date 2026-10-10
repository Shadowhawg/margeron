-- The Hall of Riverwatch: current ruler, election ballot, standing for office and the Lord's powers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gov = require(Shared.Config.Government)
local Util = require(Shared.Util)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local Net = require(script.Parent.Parent.Controllers.Net)
local Windows = require(script.Parent.Parent.Controllers.Windows)
local InventoryPanel = require(script.Parent.InventoryPanel)
local New = Create.New

local GovernmentPanel = {}

local pledge = "HarvestFestival"

local function apply(result)
	if result and result.ok and result.state then
		Windows.SetArgs(result.state)
	end
end

local function duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if d > 0 then
		return d .. "d " .. h .. "h"
	elseif h > 0 then
		return h .. "h " .. m .. "m"
	end
	return m .. "m " .. seconds % 60 .. "s"
end

local function render(content, s)
	if not s then
		Create.Label("Loading the Hall's records...", { TextColor3 = Theme.Muted, Parent = content })
		task.spawn(function()
			apply(Net.Request("GetGovernment"))
		end)
		return
	end

	-- Left: the realm
	local left = New("Frame", {
		Size = UDim2.new(0.42, -6, 1, 0),
		BackgroundColor3 = Theme.Panel,
		Parent = content,
	}, { Create.Corner(8), Create.Padding(14), Create.List(6) })
	Create.Label(
		s.LordTitle,
		{ Font = Theme.BoldFont, TextColor3 = Theme.Muted, TextSize = 14, LayoutOrder = 1, Parent = left }
	)
	Create.Label(s.LordName, {
		Font = Theme.TitleFont,
		TextSize = 30,
		TextColor3 = Theme.Gold,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 2,
		Parent = left,
	})
	local decree = Gov.Decrees[s.Decree] or Gov.Decrees.None
	local lines = {
		"Decree: " .. decree.Name .. " - " .. decree.Description,
		"Tax on purchases: " .. math.floor(s.Tax * 100 + 0.5) .. "%",
		"Steward: " .. (s.Steward ~= "" and s.Steward or "vacant"),
		"Captain of the Watch: " .. (s.Captain ~= "" and s.Captain or "vacant"),
		"Term ends in " .. duration(s.EndsIn),
	}
	for i, text in ipairs(lines) do
		Create.Label(text, { TextSize = 14, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 + i, Parent = left })
	end

	if s.MyOffice == "Lord" then
		Create.Label(
			"YOUR POWERS",
			{ Font = Theme.BoldFont, TextColor3 = Theme.Accent, LayoutOrder = 20, Parent = left }
		)
		local taxRow = New(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 21, Parent = left },
			{
				Create.List(6, Enum.FillDirection.Horizontal),
			}
		)
		Create.Button("Tax -1%", Theme.PanelLight, function()
			apply(Net.Request("SetTax", s.Tax - 0.01))
		end, { Size = UDim2.fromOffset(90, 30), Parent = taxRow })
		Create.Button("Tax +1%", Theme.PanelLight, function()
			apply(Net.Request("SetTax", s.Tax + 0.01))
		end, { Size = UDim2.fromOffset(90, 30), Parent = taxRow })
		local decreeRow = New(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 22, Parent = left },
			{
				Create.List(6, Enum.FillDirection.Horizontal),
			}
		)
		local index = table.find(Gov.Decrees.Order, s.Decree) or 1
		local nextDecree = Gov.Decrees.Order[index % #Gov.Decrees.Order + 1]
		Create.Button("Decree: " .. Gov.Decrees[nextDecree].Name, Theme.Gold, function()
			apply(Net.Request("SetDecree", nextDecree))
		end, { Size = UDim2.fromOffset(250, 30), TextColor3 = Color3.new(0.1, 0.08, 0.05), Parent = decreeRow })
		for k, office in ipairs({ "Steward", "Captain" }) do
			local appointRow = New(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 22 + k, Parent = left },
				{
					Create.List(6, Enum.FillDirection.Horizontal),
				}
			)
			local box = New("TextBox", {
				Size = UDim2.fromOffset(150, 30),
				PlaceholderText = office .. " username",
				Text = "",
				ClearTextOnFocus = false,
				BackgroundColor3 = Theme.Background,
				TextColor3 = Theme.Text,
				Font = Theme.BodyFont,
				TextSize = 14,
				Parent = appointRow,
			}, { Create.Corner(6) })
			Create.Button("Appoint", Theme.PanelLight, function()
				apply(Net.Request("Appoint", office, box.Text))
			end, { Size = UDim2.fromOffset(90, 30), Parent = appointRow })
		end
		Create.Button("Claim treasury (" .. Util.FormatNumber(s.Treasury or 0) .. "g)", Theme.Good, function()
			apply(Net.Request("ClaimTreasury"))
		end, { Size = UDim2.fromOffset(250, 32), LayoutOrder = 30, Parent = left })
	end

	-- Right: the election for the next term
	local right = New("Frame", {
		Position = UDim2.new(0.42, 6, 0, 0),
		Size = UDim2.new(0.58, -6, 1, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Create.Label("Election for the next term", {
		Font = Theme.TitleFont,
		TextSize = 24,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = right,
	})
	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -120),
		BackgroundColor3 = Theme.Panel,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = right,
	}, { Create.Corner(8), Create.Padding(8), Create.List(6) })
	for i, c in ipairs(s.Candidates) do
		local p = Gov.Decrees[c.Pledge]
		InventoryPanel.Row(
			list,
			i,
			c.Name .. "   (" .. c.Votes .. " votes)",
			"Pledges: " .. (p and p.Name or "?"),
			s.HasVoted and "Voted" or "Vote",
			s.HasVoted and Theme.PanelLight or Theme.Good,
			(not s.HasVoted) and function()
				apply(Net.Request("Vote", c.UserId))
			end or nil
		)
	end
	if #s.Candidates == 0 then
		Create.Label(
			"No one has stood yet. If nobody does, the Elder rules as Regent.",
			{ TextColor3 = Theme.Muted, AutomaticSize = Enum.AutomaticSize.Y, Parent = list }
		)
	end

	local runBox = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundColor3 = Theme.Panel,
		Parent = right,
	}, { Create.Corner(8), Create.Padding(10) })
	if s.HasRun then
		Create.Label(
			"You are standing in this election. Rally your supporters!",
			{ TextColor3 = Theme.Good, Parent = runBox }
		)
	else
		Create.Label(
			"Stand for office: level "
				.. Gov.RunLevelReq
				.. ", "
				.. Gov.RunRenownReq
				.. " Renown, "
				.. Gov.RunFee
				.. " gold fee. Pick the decree you pledge:",
			{
				TextSize = 13,
				TextColor3 = Theme.Muted,
				Size = UDim2.new(1, 0, 0, 20),
				Parent = runBox,
			}
		)
		local index = table.find(Gov.Decrees.Order, pledge) or 2
		Create.Button("Pledge: " .. Gov.Decrees[pledge].Name, Theme.PanelLight, function()
			repeat
				index = index % #Gov.Decrees.Order + 1
			until Gov.Decrees.Order[index] ~= "None"
			pledge = Gov.Decrees.Order[index]
			Windows.Render()
		end, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0.62, 0, 0, 32), Parent = runBox })
		Create.Button("Stand for Lord", Theme.Gold, function()
			apply(Net.Request("RunForOffice", pledge))
		end, {
			Position = UDim2.new(0.64, 0, 0, 26),
			Size = UDim2.new(0.36, 0, 0, 32),
			TextColor3 = Color3.new(0.1, 0.08, 0.05),
			Parent = runBox,
		})
	end
end

function GovernmentPanel.Init()
	Windows.Register("Government", "Hall of Riverwatch", render)
end

return GovernmentPanel
