--!strict
-- Monetization catalogue. Replace each Id = 0 with the real asset id from Creator Hub
-- (Monetization > Passes / Developer Products). Items with Id = 0 show as "Soon" in the
-- store and can't be bought. Prices here are display-only; Roblox charges the price set
-- on the website, so keep them in sync.

export type Pass = { Key: string, Id: number, Price: number, Name: string, Icon: string, Description: string }
export type Product = {
	Key: string,
	Id: number,
	Price: number,
	Name: string,
	Icon: string,
	Description: string,
	CashPosts: number?, -- cash packs: grants PostValue * CashPosts
}

local Products = {}

Products.Passes = {
	{
		Key = "TwoXCash",
		Id = 0,
		Price = 199,
		Name = "2x Cash",
		Icon = "💵",
		Description = "Earn double cash from every post, forever.",
	},
	{
		Key = "AutoFilm",
		Id = 0,
		Price = 249,
		Name = "Auto-Film",
		Icon = "🤖",
		Description = "Posts a Good take for you every 2.5s. Toggle any time.",
	},
	{
		Key = "LongShelfLife",
		Id = 0,
		Price = 99,
		Name = "Long Shelf Life",
		Icon = "🌙",
		Description = "Offline earnings last 24 hours instead of 8.",
	},
	{
		Key = "VIP",
		Id = 0,
		Price = 399,
		Name = "VIP Creator",
		Icon = "👑",
		Description = "+20% followers, gold name and VIP tag.",
	},
} :: { Pass }

Products.DevProducts = {
	{
		Key = "ViewsBoost",
		Id = 0,
		Price = 29,
		Name = "Views Boost",
		Icon = "⚡",
		Description = "2x views for 15 minutes (real time). Stacks.",
	},
	{
		Key = "CashS",
		Id = 0,
		Price = 25,
		Name = "Cash Stack",
		Icon = "💰",
		Description = "Cash equal to 200 posts.",
		CashPosts = 200,
	},
	{
		Key = "CashM",
		Id = 0,
		Price = 99,
		Name = "Cash Bag",
		Icon = "💰",
		Description = "Cash equal to 1,000 posts.",
		CashPosts = 1_000,
	},
	{
		Key = "CashL",
		Id = 0,
		Price = 349,
		Name = "Cash Vault",
		Icon = "🏦",
		Description = "Cash equal to 5,000 posts.",
		CashPosts = 5_000,
	},
} :: { Product }

function Products.passByKey(key: string): Pass?
	for _, pass in Products.Passes do
		if pass.Key == key then
			return pass
		end
	end
	return nil
end

function Products.passById(id: number): Pass?
	if id == 0 then
		return nil
	end
	for _, pass in Products.Passes do
		if pass.Id == id then
			return pass
		end
	end
	return nil
end

function Products.productById(id: number): Product?
	if id == 0 then
		return nil
	end
	for _, product in Products.DevProducts do
		if product.Id == id then
			return product
		end
	end
	return nil
end

return Products
