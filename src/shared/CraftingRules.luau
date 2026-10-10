-- Crafting rules shared by server (authoritative) and client (UI previews).
local Config = script.Parent.Config
local Crafting = require(Config.Crafting)
local Items = require(Config.Items)

local CraftingRules = {}

-- Effects that appear in at least two of the given ingredients, in a stable order.
function CraftingRules.SharedEffects(ingredientIds)
	local counts = {}
	for _, id in ipairs(ingredientIds) do
		local def = Items.Materials[id]
		for _, effect in ipairs(def and def.Effects or {}) do
			counts[effect] = (counts[effect] or 0) + 1
		end
	end
	local result = {}
	for effect, n in pairs(counts) do
		if n >= 2 then
			table.insert(result, effect)
		end
	end
	table.sort(result)
	return result
end

function CraftingRules.IsIngredient(id)
	local def = Items.Materials[id]
	return def ~= nil and def.Effects ~= nil
end

function CraftingRules.PotionKey(effects, tier)
	return "P:" .. table.concat(effects, ",") .. ":" .. tier
end

-- Describes a consumable key ("P:Effect,Effect:tier" or "F:FoodId").
-- Returns { Name, Kind = "Potion"|"Food", Effects = { { Id, Magnitude, Duration } }, Value } or nil.
function CraftingRules.Describe(key)
	if type(key) ~= "string" then
		return nil
	end
	local kind, rest = key:match("^(%a):(.+)$")
	if kind == "P" then
		local list, tierText = rest:match("^(.+):(%d+)$")
		local tier = tonumber(tierText)
		if not list or not tier then
			return nil
		end
		local effects = {}
		local names = {}
		for effectId in list:gmatch("[^,]+") do
			if not Crafting.Effects[effectId] then
				return nil
			end
			table.insert(effects, {
				Id = effectId,
				Magnitude = Crafting.Magnitude(effectId, tier),
				Duration = Crafting.Duration(effectId, tier),
			})
			table.insert(names, Crafting.Effects[effectId].Name)
		end
		local prefix = ({ "Weak ", "", "Strong ", "Potent ", "Exquisite " })[tier] or ""
		local name = #names == 1 and (prefix .. "Potion of " .. names[1])
			or (prefix .. "Elixir of " .. table.concat(names, " & "))
		return { Name = name, Kind = "Potion", Tier = tier, Effects = effects, Value = 15 * #effects * tier }
	elseif kind == "F" then
		local food = Crafting.Foods[rest]
		if not food then
			return nil
		end
		local effects = {}
		for effectId, duration in pairs(food.Effects) do
			table.insert(effects, { Id = effectId, Magnitude = Crafting.Magnitude(effectId, 1), Duration = duration })
		end
		table.sort(effects, function(a, b)
			return a.Id < b.Id
		end)
		return { Name = food.Name, Kind = "Food", Effects = effects, Value = food.Value }
	end
	return nil
end

function CraftingRules.EffectSummary(info)
	local parts = {}
	for _, e in ipairs(info.Effects) do
		local def = Crafting.Effects[e.Id]
		local m = e.Magnitude
		local amount = def.Percent and (math.floor(m * 100 + 0.5) .. "%") or tostring(math.floor(m + 0.5))
		local text = (def.Description:gsub("{m}", amount))
		if not def.Instant then
			text ..= " (" .. math.floor(e.Duration / 60 * 10 + 0.5) / 10 .. " min)"
		end
		table.insert(parts, text)
	end
	return table.concat(parts, ", ")
end

-- Can the player afford these inputs? Returns ok, missing material name.
function CraftingRules.HasInputs(data, inputs)
	for id, count in pairs(inputs) do
		if id == "Gold" then
			if data.Gold < count then
				return false, "gold"
			end
		elseif (data.Materials[id] or 0) < count then
			local def = Items.Materials[id]
			return false, def and def.Name or id
		end
	end
	return true
end

return CraftingRules
