--!strict
-- Number formatting for a young audience: short, consistent and never scientific notation.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		return (if negative then "-" else "") .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	-- Trim trailing decimal zeros: "1.50K" -> "1.5K", "2.00M" -> "2M" (never touches "150K")
	if string.find(text, ".", 1, true) then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[tier + 1]
end

function Format.commas(n: number): string
	local s = string.format("%.0f", math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (if n < 0 then "-" else "") .. out
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.multiplier(n: number): string
	if n == math.floor(n) then
		return string.format("×%d", n)
	end
	return (string.gsub(string.gsub(string.format("×%.2f", n), "0+$", ""), "%.$", ""))
end

return Format
