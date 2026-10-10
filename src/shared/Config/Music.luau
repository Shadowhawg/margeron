-- Adaptive music. The game picks a context (town, wilds, combat, boss, cutscene...) and crossfades
-- between tracks.
--
-- HOW TO ADD MUSIC (Roblox Studio):
--   1. View > Toolbox > Audio (the dropdown), search e.g. "medieval", "fantasy village", "epic battle".
--      Roblox's licensed music is free to use in any experience.
--   2. Right-click a track > Copy Asset ID, then paste it as Id below.
-- A track with Id 0 falls back to its Fallback context (and is silent if none is set).
return {
	CrossfadeSeconds = 2.5,
	MasterVolume = 0.5,

	Tracks = {
		Prologue = { Id = 0, Volume = 0.6, Fallback = "Wilds" }, -- haunting, sparse (opening + memories)
		Echo = { Id = 0, Volume = 0.6, Fallback = "Prologue" },
		Town = { Id = 0, Volume = 0.45, Fallback = "Wilds" }, -- warm village theme
		City = { Id = 0, Volume = 0.5, Fallback = "Town" }, -- grand, regal (Aurelion)
		Night = { Id = 0, Volume = 0.4, Fallback = "Wilds" }, -- quiet nocturne for the wilds after dark
		Farmlands = { Id = 0, Volume = 0.45, Fallback = "Town" }, -- pastoral, lute/flute
		Wilds = { Id = 0, Volume = 0.4 }, -- open-world exploration
		Forest = { Id = 0, Volume = 0.4, Fallback = "Wilds" },
		Snow = { Id = 0, Volume = 0.4, Fallback = "Wilds" },
		Marsh = { Id = 0, Volume = 0.4, Fallback = "Wilds" },
		Ruins = { Id = 0, Volume = 0.4, Fallback = "Wilds" }, -- eerie (crypt, ruins)
		Combat = { Id = 0, Volume = 0.5, Fallback = "Wilds" }, -- drums, tension
		Boss = { Id = 0, Volume = 0.6, Fallback = "Combat" }, -- full epic
	},

	-- Optional ambience loops layered under the music (wind, birds, crickets...).
	Ambience = {
		Day = { Id = 0, Volume = 0.25 },
		Snow = { Id = 0, Volume = 0.3 },
		Marsh = { Id = 0, Volume = 0.3 },
	},

	-- Which music each zone biome uses.
	Biomes = {
		Forest = "Forest",
		Camp = "Combat",
		Crypt = "Ruins",
		Ruins = "Ruins",
		Marsh = "Marsh",
		Snow = "Snow",
		Volcano = "Boss",
	},
}
