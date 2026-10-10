-- Minimal Roblox-style module loader for running pure shared modules under Lune.
-- Emulates `script`, `script.Parent.X` and `require(instance)` over the src/ folder so the
-- exact files shipped to Roblox are the ones under test. Only pure modules (no services)
-- are supported.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

-- Deterministic stand-in for Roblox's Random (tests only check our logic, not PCG values).
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	local state = math.floor(math.abs(seed or os.clock() * 1e6)) % 2147483647
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state }, Random)
end
function Random:NextNumber(min: number?, max: number?): number
	self.state = (self.state * 48271) % 2147483647
	local unit = self.state / 2147483647
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * unit
end
function Random:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber(min, max + 1 - 1e-9))
end

local Harness = {}

local cache: { [string]: any } = {}
local load

-- Builds the whole instance-like tree up front (fs calls yield, which isn't allowed
-- inside metamethods). Folders map to dirs, ModuleScripts to .luau/.lua files.
local function node(path: string, parent: any, isDir: boolean)
	local children: { [string]: any } = {}
	local self = setmetatable({ __path = path }, {
		__index = function(_, key)
			if key == "Parent" then
				return parent
			end
			local child = children[key]
			if child == nil then
				error(`No child '{key}' under {path}`, 2)
			end
			return child
		end,
	})
	if isDir then
		for _, name in fs.readDir(path) do
			local childPath = `{path}/{name}`
			if fs.isDir(childPath) then
				children[name] = node(childPath, self, true)
			else
				local stem = string.match(name, "^(.-)%.luau?$")
				if stem and not string.find(stem, "%.") then
					children[stem] = node(childPath, self, false)
				end
			end
		end
	end
	return self
end

local function makeRequire()
	return function(target: any)
		if type(target) == "table" and rawget(target, "__path") then
			return load(rawget(target, "__path"), target)
		end
		error("Harness require expects a script node")
	end
end

function load(path: string, scriptNode: any)
	if cache[path] ~= nil then
		return cache[path]
	end
	local env = {
		script = scriptNode,
		require = makeRequire(),
		Random = Random,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		CFrame = roblox.CFrame,
		Enum = roblox.Enum,
		warn = print,
	}
	setmetatable(env, { __index = _G })
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	cache[path] = if result == nil then false else result
	return result
end

-- Harness.require("src/shared/Economy") -> module table
function Harness.require(path: string): any
	local parts = string.split(path, "/")
	local current = node(parts[1], nil, true)
	for i = 2, #parts do
		current = current[parts[i]]
	end
	return load(rawget(current, "__path"), current)
end

local failures, passes = 0, 0

function Harness.eq(label: string, actual: any, expected: any)
	if actual == expected then
		passes += 1
	else
		failures += 1
		print(`FAIL {label}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end

function Harness.ok(label: string, condition: boolean)
	Harness.eq(label, condition, true)
end

function Harness.finish()
	print(`{passes} passed, {failures} failed`)
	if failures > 0 then
		error("tests failed")
	end
end

return Harness
