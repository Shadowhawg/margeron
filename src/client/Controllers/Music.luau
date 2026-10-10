-- Adaptive music: picks a track for where you are and what's happening, and crossfades.
-- Tracks are configured in Config/Music (paste Roblox audio IDs there).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MusicConfig = require(Shared.Config.Music)
local World = require(Shared.Config.World)
local Enemies = require(Shared.Config.Enemies)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local Cinematic = require(script.Parent.Cinematic)

local player = Players.LocalPlayer

local Music = {}

local channels = {} -- two Sounds for crossfading
local current = 1
local currentTrack = nil
local ambience
local lastCombat = 0

-- Follow the fallback chain until a track with an ID is found.
local function resolve(context)
	local seen = {}
	while context and not seen[context] do
		seen[context] = true
		local track = MusicConfig.Tracks[context]
		if track and track.Id ~= 0 then
			return context, track
		end
		context = track and track.Fallback
	end
	return nil, nil
end

local function play(context)
	local name, track = resolve(context)
	if name == currentTrack then
		return
	end
	currentTrack = name
	local fadeTime = MusicConfig.CrossfadeSeconds
	local old = channels[current]
	TweenService:Create(old, TweenInfo.new(fadeTime), { Volume = 0 }):Play()
	if not track then
		return
	end
	current = current % 2 + 1
	local new = channels[current]
	new.SoundId = "rbxassetid://" .. track.Id
	new.Volume = 0
	new.TimePosition = 0
	new:Play()
	TweenService:Create(new, TweenInfo.new(fadeTime), { Volume = (track.Volume or 0.5) * MusicConfig.MasterVolume })
		:Play()
end

local function bossNearby(position)
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return false
	end
	for _, model in ipairs(folder:GetChildren()) do
		local def = Enemies[model:GetAttribute("EnemyId")]
		if def and def.Boss and model.PrimaryPart and (model.PrimaryPart.Position - position).Magnitude < 110 then
			return true
		end
	end
	return false
end

local function locationContext(position)
	if Util.FlatDistance(position, World.Town.Position) <= World.Town.Radius then
		return "Town"
	end
	if Util.FlatDistance(position, World.Farmlands.Position) <= World.Farmlands.Radius then
		return "Farmlands"
	end
	for _, zone in pairs(World.Zones) do
		if Util.FlatDistance(position, zone.Position) <= zone.Radius * 1.3 then
			return MusicConfig.Biomes[zone.Biome] or "Wilds"
		end
	end
	return "Wilds"
end

local function pickContext()
	if Cinematic.Playing then
		return Cinematic.CurrentMusic or "Prologue"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return currentTrack
	end
	if bossNearby(root.Position) then
		return "Boss"
	end
	if os.clock() - lastCombat < 8 then
		return "Combat"
	end
	return locationContext(root.Position)
end

local function updateAmbience()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local key = "Day"
	if root then
		local context = locationContext(root.Position)
		if context == "Snow" then
			key = "Snow"
		elseif context == "Marsh" then
			key = "Marsh"
		end
	end
	local amb = MusicConfig.Ambience[key] or MusicConfig.Ambience.Day
	local id = amb and amb.Id ~= 0 and ("rbxassetid://" .. amb.Id) or ""
	if ambience.SoundId ~= id then
		ambience.SoundId = id
		ambience.Volume = amb and amb.Volume or 0
		if id ~= "" then
			ambience:Play()
		end
	end
end

function Music.Init()
	for i = 1, 2 do
		local sound = Instance.new("Sound")
		sound.Name = "Music" .. i
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		channels[i] = sound
	end
	ambience = Instance.new("Sound")
	ambience.Name = "Ambience"
	ambience.Looped = true
	ambience.Parent = SoundService
end

function Music.Start()
	Remotes.Effect.OnClientEvent:Connect(function(kind)
		if kind == "Hurt" or kind == "DamageNumber" then
			lastCombat = os.clock()
		end
	end)
	while true do
		local ok, err = pcall(function()
			play(pickContext())
			updateAmbience()
		end)
		if not ok then
			warn("[Music]", err)
		end
		task.wait(1)
	end
end

return Music
