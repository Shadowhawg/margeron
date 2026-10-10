-- Templates for the endless, procedurally generated bounties on the Bounty Board.
-- This is the "evergreen" layer: every board refresh rolls new contracts, scaled to the player's level.
-- Add a template, a client or a flavor line and the board starts using it.
--
-- {enemy} enemy name, {enemies} plural, {material} material name, {zone} zone name, {client} quest giver
-- RewardMultiplier scales the bounty's payout relative to the XP/gold of the kills it needs
-- (kills already pay out on their own, so ~0.7 means the bounty adds about 70% on top).
return {
	Clients = {
		"a worried farmer",
		"the Riverwatch guard",
		"a travelling merchant",
		"the Hunters' Lodge",
		"an anonymous patron",
		"the Temple of the Dawn",
		"a grieving widow",
		"the caravan guild",
	},

	Templates = {
		{
			Kind = "Hunt",
			Names = { "Cull the {enemies}", "{enemies} at the Door", "Thin the Herd", "A Price on {enemies}" },
			Description = "{client} is paying to have {count} {enemies} cleared out of {zone}.",
			Count = { 5, 10 },
			RewardMultiplier = 0.7,
		},
		{
			Kind = "Gather",
			Names = { "Supplies Needed: {material}", "A Peculiar Request", "Stock the Stores" },
			Description = "{client} needs {count} {material}. They can be taken from {enemies} in {zone}.",
			Count = { 3, 6 },
			RewardMultiplier = 0.8,
		},
		{
			Kind = "Elite",
			Names = { "Wanted: {enemy}", "Dead or Dead: {enemy}", "The Head of {enemy}" },
			Description = "{client} has posted a bounty for {enemy}, last seen in {zone}.",
			Count = { 1, 1 },
			RewardMultiplier = 0.9,
		},
	},

	-- Daily Contract: one per day for everyone, bigger rewards.
	DailyNames = { "The Daily Contract", "Today's Warrant", "Order of the Watch" },
}
