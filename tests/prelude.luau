-- Minimal Roblox stand-ins for running pure logic outside Roblox.
local cache = {}
local Node = {}
Node.__index = function(self, key)
	if key == "Parent" then
		local parent = self.Path:match("^(.*)/[^/]+$")
		return parent and setmetatable({ Path = parent }, Node) or nil
	end
	local method = rawget(Node, key)
	if method then
		return method
	end
	return setmetatable({ Path = self.Path .. "/" .. key }, Node)
end
function Node.WaitForChild(self, name)
	return setmetatable({ Path = self.Path .. "/" .. name }, Node)
end
Node.FindFirstChild = Node.WaitForChild

function require(node)
	local path = node.Path
	if cache[path] == nil then
		local fn = __src[path]
		assert(fn, "no module " .. path)
		cache[path] = fn(setmetatable({ Path = path }, Node))
	end
	return cache[path]
end

local Color3Mt = {}
Color3Mt.__index = Color3Mt
function Color3Mt.Lerp(a, b, t)
	return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, Color3Mt)
end
Color3 = {
	fromRGB = function(r, g, b)
		return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Color3Mt)
	end,
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b }, Color3Mt)
	end,
}

local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return rawget(V3, k)
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return rawget(V3, k)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end,
}

local function enumProxy(prefix)
	return setmetatable({}, {
		__index = function(t, k)
			local v = setmetatable({ Name = k, Path = prefix .. "." .. k }, {
				__index = function(_, k2)
					return prefix .. "." .. k .. "." .. k2
				end,
			})
			rawset(t, k, v)
			return v
		end,
	})
end
Enum = enumProxy("Enum")

local RandomMt = {}
RandomMt.__index = RandomMt
function RandomMt:NextInteger(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	return a + self.s % (b - a + 1)
end
function RandomMt:NextNumber(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	local f = self.s / 2147483648
	return (a or 0) + f * ((b or 1) - (a or 0))
end
Random = {
	new = function(seed)
		return setmetatable({ s = math.floor(seed or 1) % 2147483648 }, RandomMt)
	end,
}

-- Roblox's task scheduler: run spawned work immediately, ignore delayed work.
task = {
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	delay = function() end,
	wait = function()
		return 0
	end,
}

local fakeClock = 1800000000
workspace = {
	GetServerTimeNow = function()
		return fakeClock
	end,
}
function advanceTime(seconds)
	fakeClock += seconds
end

local noop = function() end
local remoteStub = { FireClient = noop, FireAllClients = noop }
-- Networking isn't available outside Roblox; tests use inert remotes.
cache["Shared/Remotes"] = setmetatable({}, {
	__index = function()
		return remoteStub
	end,
})

local services = {
	RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return true
		end,
	},
	CollectionService = {
		GetTagged = function()
			return {}
		end,
	},
}
game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return {
				WaitForChild = function(_, child)
					return setmetatable({ Path = child }, Node)
				end,
			}
		end
		return services[name] or {}
	end,
}

-- Perlin-style gradient noise standing in for math.noise (same range, roughly -0.5..0.5).
do
	local perm = {}
	local rng = Random.new(7)
	for i = 0, 255 do
		perm[i] = i
	end
	for i = 255, 1, -1 do
		local j = rng:NextInteger(0, i)
		perm[i], perm[j] = perm[j], perm[i]
	end
	local function p(i)
		return perm[i % 256]
	end
	local function fade(t)
		return t * t * t * (t * (t * 6 - 15) + 10)
	end
	local function grad(h, x, y, z)
		h = h % 16
		local u = h < 8 and x or y
		local v = h < 4 and y or ((h == 12 or h == 14) and x or z)
		return ((h % 2 == 0) and u or -u) + ((math.floor(h / 2) % 2 == 0) and v or -v)
	end
	local function lerp(a, b, t)
		return a + (b - a) * t
	end
	local function noise(x, y, z)
		y, z = y or 0, z or 0
		local X, Y, Z = math.floor(x), math.floor(y), math.floor(z)
		x, y, z = x - X, y - Y, z - Z
		local u, v, w = fade(x), fade(y), fade(z)
		local A, B = p(X) + Y, p(X + 1) + Y
		local AA, AB, BA, BB = p(A) + Z, p(A + 1) + Z, p(B) + Z, p(B + 1) + Z
		return 0.5
			* lerp(
				lerp(
					lerp(grad(p(AA), x, y, z), grad(p(BA), x - 1, y, z), u),
					lerp(grad(p(AB), x, y - 1, z), grad(p(BB), x - 1, y - 1, z), u),
					v
				),
				lerp(
					lerp(grad(p(AA + 1), x, y, z - 1), grad(p(BA + 1), x - 1, y, z - 1), u),
					lerp(grad(p(AB + 1), x, y - 1, z - 1), grad(p(BB + 1), x - 1, y - 1, z - 1), u),
					v
				),
				w
			)
	end
	-- The CLI's math library is read-only, so wrap it.
	math = setmetatable({ noise = noise }, { __index = math })
end

-- Tiny assertion helpers
local passed, failed = 0, 0
function check(cond, label)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. label)
	end
end
function summary()
	print(string.format("%d passed, %d failed", passed, failed))
end
