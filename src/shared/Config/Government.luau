-- Local government of Riverwatch. Shared by every server.
--
-- Each term lasts CycleSeconds. During a term, eligible players can register as candidates for
-- the next term (pledging a decree) and everyone can vote once. When the term ends, the candidate
-- with the most votes becomes Lord (or Lady) of Riverwatch for the next term.
--
-- The Lord sets the tax rate, chooses an active decree, appoints a Steward and a Captain, and
-- can claim the treasury (taxes collected on purchases across all servers).
return {
	-- Live: 3-day terms. In Studio terms are short so you can test elections quickly.
	CycleSeconds = 3 * 24 * 60 * 60,
	StudioCycleSeconds = 10 * 60,
	Epoch = 1767225600, -- 2026-01-01 UTC; term numbers count from here

	RunFee = 2000,
	RunLevelReq = 8,
	RunRenownReq = 10,
	VoteLevelReq = 3,

	DefaultTax = 0.05,
	MaxTax = 0.15,

	-- Who rules when nobody won an election.
	RegentName = "Elder Maren (Regent)",

	Offices = {
		Lord = { Male = "Lord of Riverwatch", Female = "Lady of Riverwatch" },
		Steward = { Male = "Steward of Riverwatch", Female = "Steward of Riverwatch" },
		Captain = { Male = "Captain of the Watch", Female = "Captain of the Watch" },
	},

	-- Officials get a discount at Riverwatch shops.
	OfficialDiscount = { Lord = 0.15, Steward = 0.1, Captain = 0.05 },

	-- Decrees: the Lord picks one; it applies to everyone on every server.
	Decrees = {
		Order = { "None", "HarvestFestival", "BountyEdict", "OpenMarkets", "ArtisansCharter", "VeteransDue" },
		None = { Name = "No Decree", Description = "Business as usual." },
		HarvestFestival = { Name = "Harvest Festival", Description = "+50% crop and livestock yields." },
		BountyEdict = { Name = "Bounty Edict", Description = "+25% gold from bounties." },
		OpenMarkets = { Name = "Open Markets", Description = "Merchants pay 20% more for goods." },
		ArtisansCharter = { Name = "Artisans' Charter", Description = "+30% crafting experience." },
		VeteransDue = { Name = "Veterans' Due", Description = "+10% experience from combat." },
	},
}
