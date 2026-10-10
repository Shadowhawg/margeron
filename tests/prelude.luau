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

local services = {
	ReplicatedStorage = setmetatable({ Path = "Shared/.." }, Node),
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
