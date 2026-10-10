--!strict
-- Robux store. Every price is shown in exact Robux, cash packs show the exact cash amount
-- you'll receive right now, and there are no timers, "limited" labels or random items.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Products = require(Shared.Config.Products)
local Types = require(Shared.Types)
local Panels = require(script.Parent.Parent.Panels)
local Row = require(script.Parent.Parent.Row)
local Theme = require(script.Parent.Parent.Theme)
local Toasts = require(script.Parent.Parent.Toasts)

local player = Players.LocalPlayer

local passRows: { [string]: Row.Row } = {}
local productRows: { [string]: Row.Row } = {}
local premiumRow: Row.Row? = nil

local function update(state: Types.ClientState)
	for _, pass in Products.Passes do
		local row = passRows[pass.Key]
		if row then
			if state.Passes[pass.Key] then
				Row.setButton(row, "OWNED ✓", Theme.Cash, false)
			elseif pass.Id == 0 then
				Row.setButton(row, "SOON", Theme.Disabled, false)
			else
				Row.setButton(row, `R$ {pass.Price}`, Theme.Cash, true)
			end
		end
	end
	for _, product in Products.DevProducts do
		local row = productRows[product.Key]
		if row then
			if product.CashPosts then
				row.Sub.Text = `Get ${Format.commas(state.PostValue * product.CashPosts)} right now`
			end
			if product.Id == 0 then
				Row.setButton(row, "SOON", Theme.Disabled, false)
			else
				Row.setButton(row, `R$ {product.Price}`, Theme.Cash, true)
			end
		end
	end
	local premium = premiumRow
	if premium then
		premium.Frame.Visible = not state.IsPremium
	end
end

local StorePanel: Panels.PanelDef = {
	Name = "Store",
	Title = "💎 STORE",
	Build = function(body)
		local list = Panels.scrollList(body)
		local order = 0
		for _, product in Products.DevProducts do
			order += 1
			local row = Row.new(list, order, function()
				if product.Id ~= 0 then
					MarketplaceService:PromptProductPurchase(player, product.Id)
				end
			end)
			row.Icon.Text = product.Icon
			row.Title.Text = product.Name
			row.Sub.Text = product.Description
			productRows[product.Key] = row
		end
		for _, pass in Products.Passes do
			order += 1
			local row = Row.new(list, order, function()
				if pass.Id ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end
			end)
			row.Icon.Text = pass.Icon
			row.Title.Text = pass.Name
			row.Sub.Text = pass.Description
			passRows[pass.Key] = row
		end
		order += 1
		local premium = Row.new(list, order, function()
			local ok = pcall(function()
				MarketplaceService:PromptPremiumPurchase(player)
			end)
			if not ok then
				Toasts.error("Premium isn't available right now")
			end
		end)
		premium.Icon.Text = "⭐"
		premium.Title.Text = "Roblox Premium"
		premium.Sub.Text = "+10% cash in Go Viral"
		Row.setButton(premium, "LEARN MORE", Theme.Gold, true)
		premiumRow = premium
	end,
	Update = update,
	FirstSelectable = function()
		local first = productRows[Products.DevProducts[1].Key]
		return if first then first.Button else nil
	end,
}

return StorePanel
