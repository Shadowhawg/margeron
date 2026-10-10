-- The opening: prologue cutscene -> character creation -> awakening, then the story begins.
-- Also plays memory cutscenes ("Echoes") sent by the server when main quests are completed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Net)
local Cinematic = require(script.Parent.Cinematic)
local Creator = require(script.Parent.Parent.Panels.Creator)
local DayNight = require(script.Parent.DayNight)

local player = Players.LocalPlayer

local Intro = {}
local running = false
local finished = false -- set once the intro completes, so it can never replay

local function waitForCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	task.wait(1)
end

local function run()
	-- The story opens at night, whatever the server's clock says.
	DayNight.Override = 22.5
	waitForCharacter()
	local data = State.Data
	if not data.Appearance.Created then
		Cinematic.Play("Prologue")
		Creator.Open(true)
		Creator.Confirmed:Wait()
		task.wait(1.5) -- let the final look apply
	end
	Cinematic.Play("Awakening")
	local result = Net.Request("FinishIntro")
	finished = result.ok == true
	running = false
	DayNight.Override = nil
end

function Intro.Start()
	State.Observe(function(data)
		if not running and not finished and not data.Story.PrologueSeen then
			running = true
			task.spawn(run)
		end
	end)
	Remotes.Cutscene.OnClientEvent:Connect(function(cutsceneId)
		while Cinematic.Playing or Cinematic.Active do
			task.wait(0.5)
		end
		Cinematic.Play(cutsceneId)
	end)
end

return Intro
