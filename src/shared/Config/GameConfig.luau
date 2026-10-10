-- Global tuning knobs. Most balance changes happen here or in the other Config modules.
return {
	GameName = "Margeron",

	-- Progression
	MaxLevel = 50,
	BaseHealth = 100,
	HealthPerLevel = 8,
	SkillPointsPerLevel = 1,
	StartingGold = 25,
	BaseWalkSpeed = 16,

	-- Skill tree: levels required to buy nodes in each tier
	TierLevelRequirements = { 1, 3, 6, 10 },
	RespecCostPerPoint = 40,

	-- Persistence
	DataStoreName = "MargeronPlayerData_v1",
	AutosaveInterval = 120,

	-- Radiant (repeatable) quests
	MaxActiveBounties = 3,
	BountyBoardSize = 4,
	BountyBoardRefreshSeconds = 60 * 30,
	DailyContractRewardMultiplier = 2.5,

	-- Renown: earned from completed bounties, unlocks titles
	RenownTitles = {
		{ Renown = 5, Title = "Sellsword" },
		{ Renown = 15, Title = "Bounty Hunter" },
		{ Renown = 35, Title = "Warden of Riverwatch" },
		{ Renown = 75, Title = "Legend of Margeron" },
	},

	-- Combat
	XPShareRadius = 150,
	NPCInteractDistance = 14,
}
