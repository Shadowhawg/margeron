-- Character creation: turns a player's chosen appearance (race, gender, body, skin, hair, outfit)
-- into a HumanoidDescription, spawns characters with it, and handles the creator's live preview.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Races = require(Shared.Config.Races)
local World = require(Shared.Config.World)

local CharacterService = {}
local Services

local applying = {} -- [Player] = true while ApplyDescription runs
local pendingPreview = {} -- [Player] = appearance waiting to be applied

local RESHAPE_COST = 250

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Clean up and clamp an appearance table that came from the client.
function CharacterService.Sanitize(input, fallback)
	if type(input) ~= "table" then
		return nil
	end
	local out = table.clone(fallback)
	local race = Races.Races[input.Race] and input.Race or fallback.Race
	out.Race = race
	out.Gender = table.find(Races.Genders, input.Gender) and input.Gender or fallback.Gender
	local function unit(v, default)
		return type(v) == "number" and v == v and math.clamp(v, 0, 1) or default
	end
	local function index(v, max, default)
		return type(v) == "number" and v == v and math.clamp(math.floor(v), 1, max) or default
	end
	out.Height = unit(input.Height, fallback.Height)
	out.Weight = unit(input.Weight, fallback.Weight)
	out.SkinTone = index(input.SkinTone, #Races.Races[race].SkinTones, 1)
	out.Hair = Races.Hair.Styles[input.Hair] and input.Hair or fallback.Hair
	out.HairColor = index(input.HairColor, #Races.HairColors, 1)
	out.Beard = Races.Beards.Styles[input.Beard] and input.Beard or "None"
	out.Outfit = index(input.Outfit, #Races.Outfits, 1)
	return out
end

function CharacterService.BuildDescription(appearance)
	local race = Races.Races[appearance.Race] or Races.Races.Riverfolk
	local female = appearance.Gender == "Female"
	local desc = Instance.new("HumanoidDescription")

	local width = lerp(race.Width[1], race.Width[2], appearance.Weight)
	desc.HeightScale = lerp(race.Height[1], race.Height[2], appearance.Height)
	desc.WidthScale = width * (female and 0.92 or 1)
	desc.DepthScale = width * (female and 0.92 or 1)
	desc.HeadScale = race.Head
	desc.BodyTypeScale = female and 0.35 or 0.1
	desc.ProportionScale = female and 0.6 or 0

	local skin = race.SkinTones[appearance.SkinTone] or race.SkinTones[1]
	local outfit = Races.Outfits[appearance.Outfit] or Races.Outfits[1]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = outfit.Tunic
	desc.LeftLegColor = outfit.Trousers
	desc.RightLegColor = outfit.Trousers
	return desc
end

local function introCFrame()
	local ground = Services.WorldService.Ground(World.IntroPoint.X, World.IntroPoint.Z)
	-- Face the river (north).
	return CFrame.lookAt(ground + Vector3.new(0, 4, 0), ground + Vector3.new(0, 4, -10))
end

-- Spawns (or respawns) the player's character with their appearance.
function CharacterService.Spawn(player)
	local data = Services.PlayerService.GetData(player)
	if not data or not player.Parent then
		return
	end
	local desc = CharacterService.BuildDescription(data.Appearance)
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(desc)
	end)
	if not ok then
		warn("[CharacterService] LoadCharacterWithHumanoidDescription failed:", err)
		player:LoadCharacter()
	end
	local character = player.Character
	if character and not (data.Appearance.Created and data.Story.PrologueSeen) then
		character:PivotTo(introCFrame())
	end
end

local function applyNow(player)
	local data = Services.PlayerService.GetData(player)
	local humanoid = Services.PlayerService.GetHumanoid(player)
	if not data or not humanoid then
		return
	end
	applying[player] = true
	local ok, err = pcall(function()
		humanoid:ApplyDescription(CharacterService.BuildDescription(data.Appearance))
	end)
	applying[player] = nil
	if not ok then
		warn("[CharacterService] ApplyDescription failed:", err)
	end
	Services.AppearanceService.Apply(player)
	Services.PlayerService.RefreshStats(player)

	-- A preview arrived while we were busy: apply the newest one.
	local pending = pendingPreview[player]
	if pending then
		pendingPreview[player] = nil
		data.Appearance = pending
		applyNow(player)
	end
end

-- Live preview from the character creator (not final until Confirm).
function CharacterService.Preview(player, input)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return { ok = false }
	end
	local appearance = CharacterService.Sanitize(input, data.Appearance)
	if not appearance then
		return { ok = false }
	end
	appearance.Created = data.Appearance.Created
	if applying[player] then
		pendingPreview[player] = appearance
		return { ok = true }
	end
	data.Appearance = appearance
	task.spawn(applyNow, player)
	return { ok = true }
end

-- Finishes character creation (or a paid reshaping at Seer Ilsa's).
function CharacterService.Confirm(player, input)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return { ok = false }
	end
	local appearance = CharacterService.Sanitize(input, data.Appearance)
	if not appearance then
		return { ok = false }
	end
	local firstTime = not data.Appearance.Created
	if not firstTime and not data.Story.ReshapePaid then
		return { ok = false, message = "Visit Seer Ilsa to change your appearance." }
	end
	data.Story.ReshapePaid = nil
	appearance.Created = true
	data.Appearance = appearance
	task.spawn(applyNow, player)
	Services.PlayerService.Changed(player)
	return { ok = true, firstTime = firstTime }
end

-- Seer Ilsa offers to reshape you for gold.
function CharacterService.BeginReshape(player)
	local data = Services.PlayerService.GetData(player)
	if not data then
		return { ok = false }
	end
	if not Services.PlayerService.SpendGold(player, RESHAPE_COST) then
		return { ok = false, message = "Reshaping costs " .. RESHAPE_COST .. " gold." }
	end
	data.Story.ReshapePaid = true
	return { ok = true, open = "Creator" }
end

-- Called when the intro cutscenes have finished on the client.
function CharacterService.FinishIntro(player)
	local data = Services.PlayerService.GetData(player)
	if not data or not data.Appearance.Created then
		return { ok = false }
	end
	if not data.Story.PrologueSeen then
		data.Story.PrologueSeen = true
		Services.PlayerService.Changed(player)
		Services.QuestService.GrantAutomaticQuests(player)
	end
	return { ok = true }
end

CharacterService.ReshapeCost = RESHAPE_COST

function CharacterService.Init(services)
	Services = services
	Players.PlayerRemoving:Connect(function(player)
		applying[player] = nil
		pendingPreview[player] = nil
	end)
end

return CharacterService
