--!strict
-- Game passes, developer products and Premium perks.
--
-- Developer products use ProfileStore's PurchaseId-cache pattern: the grant and the
-- PurchaseId are written to the profile together, and we only return PurchaseGranted
-- once that PurchaseId shows up in LastSavedData. A server crash between grant and save
-- therefore re-delivers the purchase instead of losing it, and a re-delivery after a
-- successful save is ignored instead of granting twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Game = require(Shared.Config.Game)
local Products = require(Shared.Config.Products)
local Types = require(Shared.Types)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local PURCHASE_ID_CACHE_SIZE = 100

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local ready: { [Player]: boolean } = {}

local function refreshPass(player: Player, pass: Products.Pass)
	if pass.Id == 0 then
		return
	end
	local ok, has = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
	end)
	if ok and has then
		owned[player] = owned[player] or {}
		owned[player][pass.Key] = true
		if pass.Key == "VIP" then
			player:SetAttribute("VIP", true)
		end
		DataService.markDirty(player)
	end
end

function MonetizationService.owns(player: Player, key: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

function MonetizationService.ownedPasses(player: Player): { [string]: boolean }
	local copy: { [string]: boolean } = {}
	local passes = owned[player]
	if passes then
		for key, value in passes do
			copy[key] = value
		end
	end
	return copy
end

-- Yields until this player's pass ownership has been fetched (or timeout).
function MonetizationService.awaitReady(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	while not ready[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
end

function MonetizationService.isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

function MonetizationService.cashMultiplier(player: Player): number
	return (if MonetizationService.owns(player, "TwoXCash") then 2 else 1)
		* (if MonetizationService.isPremium(player) then 1 + Game.PremiumCashBonus else 1)
end

function MonetizationService.followerMultiplier(player: Player): number
	return if MonetizationService.owns(player, "VIP") then 1 + Game.VipFollowerBonus else 1
end

function MonetizationService.offlineCapHours(player: Player): number
	return if MonetizationService.owns(player, "LongShelfLife") then Game.OfflineCapHoursPass else Game.OfflineCapHours
end

-- Product grant functions. They must only mutate profile data (no yielding), so the
-- grant and the PurchaseId cache entry land in the same save.
local grants: { [string]: (player: Player, data: Types.PlayerData) -> () } = {
	ViewsBoost = function(_player, data)
		data.BoostEndsAt = math.max(data.BoostEndsAt, os.time()) + Game.BoostDuration
	end,
}

local function cashPackGrant(product: Products.Product): (Player, Types.PlayerData) -> ()
	return function(player, data)
		local amount = Economy.postValue(data) * (product.CashPosts or 0)
		data.Cash += amount
		Analytics.economy(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			amount,
			data.Cash,
			Enum.AnalyticsEconomyTransactionType.IAP,
			product.Key
		)
	end
end

for _, product in Products.DevProducts do
	if product.CashPosts then
		grants[product.Key] = cashPackGrant(product)
	end
end

local function purchaseIdCheckAsync(
	profile: DataService.Profile,
	data: Types.PlayerData,
	purchaseId: string,
	grant: () -> ()
): Enum.ProductPurchaseDecision
	if not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local cache = data.PurchaseIdCache
	if table.find(cache, purchaseId) == nil then
		local ok, err = pcall(grant :: () -> any)
		if not ok then
			warn(`[Monetization] grant failed {profile.Key} {purchaseId}: {err}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #cache >= PURCHASE_ID_CACHE_SIZE do
			table.remove(cache, 1)
		end
		table.insert(cache, purchaseId)
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData :: Types.PlayerData?
		return saved ~= nil and saved.PurchaseIdCache ~= nil and table.find(saved.PurchaseIdCache, purchaseId) ~= nil
	end

	while profile:IsActive() do
		if isSaved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local before = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == before then
			local saved = false
			local connection = profile.OnAfterSave:Connect(function()
				saved = true
			end)
			local deadline = os.clock() + 15
			while not saved and os.clock() < deadline and profile:IsActive() do
				task.wait(0.1)
			end
			connection:Disconnect()
		end
		if isSaved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		task.wait(5)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Products.productById(receipt.ProductId)
	local grant = product and grants[product.Key]
	if not product or not grant then
		warn(`[Monetization] No handler for product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.await(player)
	local profile = DataService.getProfile(player)
	if not data or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local decision = purchaseIdCheckAsync(profile, data, tostring(receipt.PurchaseId), function()
		grant(player, data)
	end)
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		DataService.markDirty(player)
		Analytics.custom(player, `Purchase_{product.Key}`, product.Price)
	end
	return decision
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	local function onPlayerAdded(player: Player)
		owned[player] = owned[player] or {}
		for _, pass in Products.Passes do
			refreshPass(player, pass)
		end
		ready[player] = true
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		ready[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Products.passById(passId)
		if purchased and pass then
			owned[player] = owned[player] or {}
			owned[player][pass.Key] = true
			if pass.Key == "VIP" then
				player:SetAttribute("VIP", true)
			end
			DataService.markDirty(player)
			Analytics.custom(player, `Purchase_{pass.Key}`, pass.Price)
		end
	end)

	Players.PlayerMembershipChanged:Connect(function(player)
		DataService.markDirty(player)
	end)
end

return MonetizationService
