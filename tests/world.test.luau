-- Builds the entire generated world (terrain, Riverwatch, the Crown City, zones, landmarks,
-- scenery) against stand-in Roblox objects, to catch runtime errors and measure part counts.

-- Extra Vector3 helpers ------------------------------------------------------------------
local V3 = getmetatable(Vector3.new(0, 0, 0))
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)

-- CFrame: position + 3x3 rotation (columns = right, up, back) ----------------------------
local CF = {}
local function cf(px, py, pz, r)
	return setmetatable({ P = Vector3.new(px, py, pz), R = r }, CF)
end
local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 } -- row-major
local function matmul(a, b)
	local out = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local sum = 0
			for k = 0, 2 do
				sum += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			out[i * 3 + j + 1] = sum
		end
	end
	return out
end
local function rotate(r, v)
	return Vector3.new(
		r[1] * v.X + r[2] * v.Y + r[3] * v.Z,
		r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z
	)
end
CF.__index = function(self, k)
	local r = rawget(self, "R")
	if k == "Position" then
		return rawget(self, "P")
	elseif k == "Rotation" then
		return cf(0, 0, 0, r)
	elseif k == "LookVector" then
		return Vector3.new(-r[3], -r[6], -r[9])
	elseif k == "RightVector" then
		return Vector3.new(r[1], r[4], r[7])
	elseif k == "UpVector" then
		return Vector3.new(r[2], r[5], r[8])
	elseif k == "X" or k == "Y" or k == "Z" then
		return rawget(self, "P")[k]
	end
	return rawget(CF, k)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local p = a.P + rotate(a.R, b.P)
		return setmetatable({ P = p, R = matmul(a.R, b.R) }, CF)
	end
	return a.P + rotate(a.R, b)
end
CF.__add = function(a, v)
	return setmetatable({ P = a.P + v, R = a.R }, CF)
end
CF.__sub = function(a, v)
	return setmetatable({ P = a.P - v, R = a.R }, CF)
end
local function axisAngles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return matmul(matmul(X, Y), Z)
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return setmetatable({ P = x, R = IDENTITY }, CF)
		end
		return setmetatable({ P = Vector3.new(x or 0, y or 0, z or 0), R = IDENTITY }, CF)
	end,
	Angles = function(rx, ry, rz)
		return setmetatable({ P = Vector3.zero, R = axisAngles(rx, ry, rz) }, CF)
	end,
	lookAt = function(pos, target)
		local look = target - pos
		assert(look.Magnitude == look.Magnitude, "lookAt got NaN")
		if look.Magnitude < 1e-6 then
			return setmetatable({ P = pos, R = IDENTITY }, CF)
		end
		look = look.Unit
		local right = look:Cross(Vector3.yAxis)
		if right.Magnitude < 1e-6 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		local up = right:Cross(look)
		return setmetatable(
			{ P = pos, R = { right.X, up.X, -look.X, right.Y, up.Y, -look.Y, right.Z, up.Z, -look.Z } },
			CF
		)
	end,
}

-- Instances --------------------------------------------------------------------------------
local counts = {}
local total = 0
local PART_CLASSES = { Part = true, WedgePart = true, SpawnLocation = true, MeshPart = true }
local I = {}
local methods = {}
I.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	local props = rawget(self, "_props")
	if props[k] ~= nil then
		return props[k]
	end
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == k then
			return child
		end
	end
	return nil
end
I.__newindex = function(self, k, v)
	if k == "Parent" then
		local props = rawget(self, "_props")
		local old = props.Parent
		if old then
			local list = rawget(old, "_children")
			local at = table.find(list, self)
			if at then
				table.remove(list, at)
			end
		end
		props.Parent = v
		if v then
			table.insert(rawget(v, "_children"), self)
		end
		return
	end
	if
		(k == "CFrame" or k == "Position" or k == "Size")
		and v ~= nil
		and PART_CLASSES[rawget(self, "_props").ClassName]
	then
		local t = typeof and typeof(v) or type(v)
		assert(type(v) == "table", "bad " .. k .. " value: " .. tostring(t))
		if k ~= "CFrame" then
			assert(v.X == v.X and v.Y == v.Y and v.Z == v.Z, k .. " is NaN")
		else
			assert(v.P.X == v.P.X and v.P.Y == v.P.Y, "CFrame is NaN")
		end
	end
	rawget(self, "_props")[k] = v
end
function methods.IsA(self, class)
	local c = self.ClassName
	return c == class or (class == "BasePart" and PART_CLASSES[c]) or class == "Instance"
end
function methods.FindFirstChild(self, name, recursive)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == name then
			return child
		end
		if recursive then
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, class)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function methods.GetDescendants(self)
	local out = {}
	for _, child in ipairs(rawget(self, "_children")) do
		table.insert(out, child)
		for _, d in ipairs(child:GetDescendants()) do
			table.insert(out, d)
		end
	end
	return out
end
function methods.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
end
function methods.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function methods.Destroy(self)
	self.Parent = nil
end
function methods.ClearAllChildren(self)
	for _, child in ipairs(self:GetChildren()) do
		child.Parent = nil
	end
end
function methods.PivotTo(self, target)
	rawget(self, "_props").Pivot = target
end
function methods.GetPivot(self)
	return rawget(self, "_props").Pivot or CFrame.new()
end
function methods.WriteVoxels() end
function methods.SetStateEnabled() end

Instance = {
	new = function(className)
		local obj =
			setmetatable({ _props = { ClassName = className, Name = className }, _children = {}, _attrs = {} }, I)
		counts[className] = (counts[className] or 0) + 1
		if PART_CLASSES[className] then
			total += 1
		end
		if className == "Part" or className == "WedgePart" then
			obj.Size = Vector3.new(4, 1, 2)
			obj.CFrame = CFrame.new()
		end
		return obj
	end,
}
local function simple(name)
	return {
		new = function(...)
			return { Kind = name, Args = { ... } }
		end,
	}
end
ColorSequence = simple("ColorSequence")
NumberSequence = simple("NumberSequence")
NumberSequenceKeypoint = simple("NumberSequenceKeypoint")
NumberRange = simple("NumberRange")
Vector2 = simple("Vector2")
UDim = simple("UDim")
UDim2 = {
	new = function(...)
		return { ... }
	end,
	fromScale = function(...)
		return { ... }
	end,
	fromOffset = function(...)
		return { ... }
	end,
}
Region3 = simple("Region3")

workspace = Instance.new("Workspace")
workspace.Name = "Workspace"
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
workspace.GetServerTimeNow = function()
	return 1800000000
end
local lighting = Instance.new("Lighting")
local tags = {}
local collection = {
	AddTag = function(_, inst, tag)
		tags[tag] = (tags[tag] or 0) + 1
		local _ = inst
	end,
}
local oldGetService = game.GetService
game.GetService = function(self, name)
	if name == "Lighting" then
		return lighting
	elseif name == "CollectionService" then
		return collection
	end
	return oldGetService(self, name)
end

-- Build the world -------------------------------------------------------------------------
local NodeMt = getmetatable(game:GetService("ReplicatedStorage"):WaitForChild("Shared"))
local WorldService = require(setmetatable({ Path = "Server/Services/WorldService" }, NodeMt))
local started = os.clock()
local ok, err = xpcall(WorldService.Init, function(e)
	return tostring(e) .. "\n" .. debug.traceback()
end)
check(ok, "world generation runs without errors: " .. tostring(err))
print(
	string.format(
		"World built in %.1fs: %d parts (%d WedgeParts), %d lights, %d models",
		os.clock() - started,
		total,
		counts.WedgePart or 0,
		counts.PointLight or 0,
		counts.Model or 0
	)
)
print(
	string.format(
		"Gather nodes: %d, crafting stations: %d, rest spots: %d",
		tags.GatherNode or 0,
		tags.CraftingStation or 0,
		tags.RestSpot or 0
	)
)
check(total < 40000, "part count is reasonable (" .. total .. ")")
check((tags.CraftingStation or 0) >= 7, "town and city stations built")
check((tags.RestSpot or 0) >= 2, "inn beds built")
check(workspace:FindFirstChild("GeneratedWorld") ~= nil, "generated world folder exists")
summary()
