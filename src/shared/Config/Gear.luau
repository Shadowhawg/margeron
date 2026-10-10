--!strict
-- Gear tracks. Tier 1 of each track is free and owned by default.
-- Multipliers stack multiplicatively across tracks. Mirror changes in tools/sim_economy.py.

export type Tier = { Name: string, Icon: string, Mult: number, Cost: number }
export type Track = { Id: string, Name: string, Icon: string, Tiers: { Tier } }

local Gear = {}

Gear.Order = { "Camera", "Lighting", "Set" }

Gear.Tracks = {
	Camera = {
		Id = "Camera",
		Name = "Camera",
		Icon = "📱",
		Tiers = {
			{ Name = "Cracked Phone", Icon = "📱", Mult = 1, Cost = 0 },
			{ Name = "Hand-me-down Phone", Icon = "📱", Mult = 1.6, Cost = 50 },
			{ Name = "Budget Phone", Icon = "📲", Mult = 2.5, Cost = 600 },
			{ Name = "Flagship Phone", Icon = "📲", Mult = 4, Cost = 6_000 },
			{ Name = "Vlog Camera", Icon = "📷", Mult = 6.5, Cost = 60_000 },
			{ Name = "Mirrorless Camera", Icon = "📸", Mult = 10, Cost = 600_000 },
			{ Name = "Cinema Rig", Icon = "🎥", Mult = 16, Cost = 6_000_000 },
			{ Name = "Drone Squad", Icon = "🚁", Mult = 25, Cost = 80_000_000 },
			{ Name = "Holo Cam", Icon = "🔮", Mult = 40, Cost = 1_500_000_000 },
			{ Name = "Quantum Lens", Icon = "🌌", Mult = 65, Cost = 30_000_000_000 },
		},
	} :: Track,
	Lighting = {
		Id = "Lighting",
		Name = "Lighting",
		Icon = "💡",
		Tiers = {
			{ Name = "No Light", Icon = "🌑", Mult = 1, Cost = 0 },
			{ Name = "Desk Lamp", Icon = "💡", Mult = 1.25, Cost = 200 },
			{ Name = "Ring Light", Icon = "⭕", Mult = 1.6, Cost = 3_000 },
			{ Name = "Softbox Kit", Icon = "🔆", Mult = 2.1, Cost = 35_000 },
			{ Name = "Studio Rig", Icon = "🎛️", Mult = 2.8, Cost = 400_000 },
			{ Name = "Stage Lights", Icon = "🎇", Mult = 3.8, Cost = 4_500_000 },
			{ Name = "Laser Show", Icon = "✨", Mult = 5.2, Cost = 80_000_000 },
			{ Name = "Aurora Array", Icon = "🌈", Mult = 7, Cost = 1_800_000_000 },
		},
	} :: Track,
	Set = {
		Id = "Set",
		Name = "Set",
		Icon = "🏠",
		Tiers = {
			{ Name = "Messy Bedroom", Icon = "🛏️", Mult = 1, Cost = 0 },
			{ Name = "Clean Bedroom", Icon = "🛋️", Mult = 1.3, Cost = 800 },
			{ Name = "Garage Studio", Icon = "🚗", Mult = 1.75, Cost = 12_000 },
			{ Name = "Downtown Loft", Icon = "🏙️", Mult = 2.4, Cost = 150_000 },
			{ Name = "Pro Studio", Icon = "🎬", Mult = 3.3, Cost = 1_800_000 },
			{ Name = "Penthouse", Icon = "🌆", Mult = 4.6, Cost = 20_000_000 },
			{ Name = "Mansion", Icon = "🏰", Mult = 6.5, Cost = 400_000_000 },
			{ Name = "Private Island", Icon = "🏝️", Mult = 9, Cost = 9_000_000_000 },
		},
	} :: Track,
} :: { [string]: Track }

function Gear.track(id: string): Track?
	return Gear.Tracks[id]
end

function Gear.tier(trackId: string, level: number): Tier?
	local track = Gear.Tracks[trackId]
	return if track then track.Tiers[level] else nil
end

function Gear.multiplier(levels: { [string]: number }): number
	local total = 1
	for _, id in Gear.Order do
		local tier = Gear.tier(id, levels[id] or 1)
		if tier then
			total *= tier.Mult
		end
	end
	return total
end

return Gear
