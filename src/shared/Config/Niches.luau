--!strict
-- Content niches, in unlock order. The first niche is free and owned by default.
-- Niches persist through Rebrands. Mirror changes in tools/sim_economy.py.

export type Niche = {
	Id: string,
	Name: string,
	Icon: string,
	Mult: number,
	Followers: number, -- followers required to unlock
	Cost: number, -- cash cost to unlock
	Color: Color3,
}

local Niches = {}

Niches.List = {
	{ Id = "Vlogs", Name = "Vlogs", Icon = "🤳", Mult = 1, Followers = 0, Cost = 0, Color = Color3.fromRGB(255, 170, 60) },
	{ Id = "Gaming", Name = "Gaming", Icon = "🎮", Mult = 1.5, Followers = 250, Cost = 500, Color = Color3.fromRGB(120, 110, 255) },
	{ Id = "Dance", Name = "Dance", Icon = "💃", Mult = 2.2, Followers = 5_000, Cost = 10_000, Color = Color3.fromRGB(255, 90, 170) },
	{ Id = "Cooking", Name = "Cooking", Icon = "🍳", Mult = 3.2, Followers = 60_000, Cost = 150_000, Color = Color3.fromRGB(255, 120, 70) },
	{ Id = "Challenges", Name = "Challenges", Icon = "🏆", Mult = 4.5, Followers = 500_000, Cost = 2_000_000, Color = Color3.fromRGB(255, 210, 60) },
	{ Id = "Fitness", Name = "Fitness", Icon = "💪", Mult = 6.5, Followers = 5_000_000, Cost = 25_000_000, Color = Color3.fromRGB(80, 220, 140) },
	{ Id = "Music", Name = "Music", Icon = "🎤", Mult = 9.5, Followers = 50_000_000, Cost = 300_000_000, Color = Color3.fromRGB(80, 200, 255) },
} :: { Niche }

Niches.ById = {} :: { [string]: Niche }
for _, niche in Niches.List do
	assert(Niches.ById[niche.Id] == nil, `Duplicate niche id {niche.Id}`)
	Niches.ById[niche.Id] = niche
end

Niches.Default = Niches.List[1].Id

function Niches.get(id: string): Niche?
	return Niches.ById[id]
end

function Niches.indexOf(id: string): number?
	for index, niche in Niches.List do
		if niche.Id == id then
			return index
		end
	end
	return nil
end

return Niches
