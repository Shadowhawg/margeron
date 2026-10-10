-- Active abilities unlocked through the skill tree. Bound to keys 1-3 (and on-screen buttons on mobile).
return {
	Order = { "Whirlwind", "Firebolt", "Shadowstep" },

	Whirlwind = {
		Name = "Whirlwind",
		Key = Enum.KeyCode.One,
		Cooldown = 8,
		WeaponMultiplier = 1.8, -- x your weapon's damage
		Radius = 12,
		Color = Color3.fromRGB(220, 80, 60),
	},
	Firebolt = {
		Name = "Firebolt",
		Key = Enum.KeyCode.Two,
		Cooldown = 5,
		BaseDamage = 28,
		DamagePerLevel = 3,
		Range = 80,
		SplashRadius = 7,
		Color = Color3.fromRGB(255, 120, 40),
	},
	Shadowstep = {
		Name = "Shadowstep",
		Key = Enum.KeyCode.Three,
		Cooldown = 7,
		Distance = 22,
		EmpowerDuration = 3,
		Color = Color3.fromRGB(150, 90, 200),
	},
}
