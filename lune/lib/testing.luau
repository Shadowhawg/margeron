--!strict
-- Minimal headless test runner for Lune: describe / it / expect.
--
-- Spec files call describe() and it() at the top level. Each `it` body runs
-- immediately inside a pcall and its result is recorded here; lune/test.luau
-- requires every spec file and then prints the summary.
--
--   local T = require("@testing")
--   local describe, it, expect = T.describe, T.it, T.expect
--
--   describe("Pricing", function()
--       it("doubles Shiny value", function()
--           expect(Pricing.value(10, "Shiny")).toBe(20)
--       end)
--   end)

export type Matcher = (...any) -> ()
export type Expectation = {
	toBe: Matcher,
	toEqual: Matcher,
	toBeNear: Matcher,
	toBeNil: Matcher,
	toBeTruthy: Matcher,
	toBeGreaterThan: Matcher,
	toBeLessThan: Matcher,
	toThrow: Matcher,
	never: Expectation,
}

export type Failure = { name: string, message: string }

local testing = {}

local scope: { string } = {}
local results = { passed = 0, failed = {} :: { Failure } }

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Each matcher returns whether it passed and a message describing the expectation.
local matchers: { [string]: (actual: any, ...any) -> (boolean, string) } = {
	toBe = function(actual, expected)
		return actual == expected, `expected {show(actual)} to be {show(expected)}`
	end,
	toEqual = function(actual, expected)
		return deepEqual(actual, expected), `expected {show(actual)} to deep-equal {show(expected)}`
	end,
	toBeNear = function(actual, expected, tolerance)
		local tol = tolerance or 1e-9
		return type(actual) == "number" and math.abs(actual - expected) <= tol,
			`expected {show(actual)} to be within {tol} of {show(expected)}`
	end,
	toBeNil = function(actual)
		return actual == nil, `expected {show(actual)} to be nil`
	end,
	toBeTruthy = function(actual)
		return not not actual, `expected {show(actual)} to be truthy`
	end,
	toBeGreaterThan = function(actual, expected)
		return type(actual) == "number" and actual > expected, `expected {show(actual)} to be > {show(expected)}`
	end,
	toBeLessThan = function(actual, expected)
		return type(actual) == "number" and actual < expected, `expected {show(actual)} to be < {show(expected)}`
	end,
	toThrow = function(actual, substring)
		local ok, err = pcall(actual)
		if ok then
			return false, "expected function to throw"
		end
		local message = tostring(err)
		if substring ~= nil and not string.find(message, substring, 1, true) then
			return false, `expected error containing {show(substring)}, got {show(message)}`
		end
		return true, `expected function not to throw, got {show(message)}`
	end,
}

local function build(actual: any, negate: boolean): { [string]: any }
	local api = {}
	for name, matcher in matchers do
		api[name] = function(...)
			local pass, message = matcher(actual, ...)
			if pass == negate then
				error(if negate then `not: {message}` else message, 2)
			end
		end
	end
	return api
end

function testing.expect(actual: any): Expectation
	local api = build(actual, false)
	api.never = build(actual, true)
	return (api :: any) :: Expectation
end

function testing.describe(name: string, body: () -> ())
	table.insert(scope, name)
	local ok, err = pcall(body)
	if not ok then
		table.insert(results.failed, { name = table.concat(scope, " > "), message = `describe body errored: {err}` })
	end
	table.remove(scope)
end

function testing.it(name: string, body: () -> ())
	local fullName = table.concat(scope, " > ") .. " > " .. name
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		table.insert(results.failed, { name = fullName, message = tostring(err) })
	end
end

-- Records a failure that happened outside any `it`, such as a spec file that failed to load.
function testing.recordFailure(name: string, message: string)
	table.insert(results.failed, { name = name, message = message })
end

function testing.results(): (number, { Failure })
	return results.passed, results.failed
end

return testing
