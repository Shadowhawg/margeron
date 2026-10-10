--!strict
-- Sample spec: exercises the test runner's own matchers.

local T = require("@testing")
local describe, it, expect = T.describe, T.it, T.expect

describe("testing", function()
	it("compares with toBe", function()
		expect(1 + 1).toBe(2)
		expect("a").never.toBe("b")
	end)

	it("deep-compares tables with toEqual", function()
		expect({ a = 1, b = { 2, 3 } }).toEqual({ a = 1, b = { 2, 3 } })
		expect({ a = 1 }).never.toEqual({ a = 1, b = 2 })
	end)

	it("compares numbers within a tolerance", function()
		expect(0.1 + 0.2).toBeNear(0.3)
		expect(0.5).toBeNear(0.52, 0.05)
		expect(0 / 0).never.toBeNear(0)
		expect(3).toBeGreaterThan(2)
		expect(2).toBeLessThan(3)
	end)

	it("checks nil and truthiness", function()
		expect(nil).toBeNil()
		expect(false).never.toBeTruthy()
		expect(0).toBeTruthy()
	end)

	it("checks thrown errors", function()
		expect(function()
			error("boom")
		end).toThrow("boom")
		expect(function() end).never.toThrow()
	end)

	it("reports a failing expectation as an error", function()
		expect(function()
			expect(1).toBe(2)
		end).toThrow("expected 1 to be 2")
	end)
end)
