local Util = {}

function Util.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = Util.DeepCopy(v)
	end
	return copy
end

-- Fill in any keys present in template but missing from target (used when the save format grows).
function Util.Reconcile(target, template)
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			Util.Reconcile(target[k], v)
		end
	end
	return target
end

function Util.FormatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Util.Pluralize(word)
	if word:sub(-1) == "f" then
		return word:sub(1, -2) .. "ves"
	elseif word:sub(-1) == "s" then
		return word
	end
	return word .. "s"
end

function Util.Count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function Util.FlatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

return Util
