-- Robux products. Create each one on the Creator Dashboard (creator.roblox.com) for your published
-- experience, then paste its ID here.
--
--   DevProducts  -> "Developer Products" (can be bought repeatedly; we record one-time unlocks in save data)
--   GamePasses   -> "Passes" (permanent, Roblox tracks ownership)
--
-- While an ID is 0, the item can be "bought" for free when play-testing in Studio so you can test the flow.
-- In a live server an ID of 0 is hidden from the store.
--
-- Grant fields: Gold = number | Weapon = Items.Weapons key | Cosmetic = Items.Cosmetics key
return {
	DevProducts = {
		{ Key = "GoldPouch", Id = 0, Name = "Pouch of Gold", Description = "500 gold", Robux = 49, Grant = { Gold = 500 } },
		{ Key = "GoldChest", Id = 0, Name = "Chest of Gold", Description = "3,000 gold", Robux = 199, Grant = { Gold = 3000 } },
		{ Key = "CrimsonCape", Id = 0, Name = "Crimson Cape", Description = "Cosmetic cape", Robux = 75, Grant = { Cosmetic = "CrimsonCape" } },
		{ Key = "ShadowCape", Id = 0, Name = "Shadow Cape", Description = "Cosmetic cape", Robux = 75, Grant = { Cosmetic = "ShadowCape" } },
		{ Key = "GoldenAura", Id = 0, Name = "Golden Aura", Description = "Cosmetic aura", Robux = 150, Grant = { Cosmetic = "GoldenAura" } },
		{ Key = "FrostAura", Id = 0, Name = "Frost Aura", Description = "Cosmetic aura", Robux = 150, Grant = { Cosmetic = "FrostAura" } },
	},
	GamePasses = {
		{ Key = "EmberBrand", Id = 0, Name = "Emberbrand", Description = "Premium sword (Lv 4)", Robux = 249, Grant = { Weapon = "EmberBrand" } },
		{ Key = "FrostfangStaff", Id = 0, Name = "Frostfang Staff", Description = "Premium staff (Lv 6)", Robux = 249, Grant = { Weapon = "FrostfangStaff" } },
		{ Key = "FounderTitle", Id = 0, Name = "Founder's Title", Description = "Show you were here first", Robux = 99, Grant = { Cosmetic = "TitleFounder" } },
	},
}
