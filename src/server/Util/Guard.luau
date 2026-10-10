--!strict
-- Argument validation for remote payloads. Everything a client sends is untrusted:
-- wrong types, NaN, infinities, huge strings and unknown ids all get rejected here.

local Guard = {}

function Guard.finite(value: unknown): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function Guard.integer(value: unknown, min: number, max: number): number?
	local n = Guard.finite(value)
	if n == nil or n % 1 ~= 0 or n < min or n > max then
		return nil
	end
	return n
end

function Guard.fraction(value: unknown): number?
	local n = Guard.finite(value)
	if n == nil or n < 0 or n > 1 then
		return nil
	end
	return n
end

function Guard.str(value: unknown, maxLength: number): string?
	if type(value) ~= "string" or #value == 0 or #value > maxLength then
		return nil
	end
	return value
end

function Guard.bool(value: unknown): boolean?
	if type(value) ~= "boolean" then
		return nil
	end
	return value
end

-- Returns the value only if it's one of the allowed keys of `set`.
function Guard.oneOf<T>(value: unknown, set: { [string]: T }): string?
	if type(value) ~= "string" or #value > 64 then
		return nil
	end
	if set[value] == nil then
		return nil
	end
	return value
end

return Guard
