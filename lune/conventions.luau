--!strict
-- Static checks for project rules that StyLua, selene and luau-lsp don't cover
-- (BUILD_SPEC §0, §2.7, Part 4).
--
--   lune run conventions

local fs = require("@lune/fs")
local process = require("@lune/process")

type Rule = { pattern: string, message: string }

-- Applied to src/ and tools/. Patterns run on each line with comments removed
-- and a leading space added, so "[^%w_%.:]wait" matches `wait(` but not `task.wait(`.
local BANNED: { Rule } = {
	{ pattern = "[^%w_%.:]wait%s*%(", message = "use task.wait, not wait" },
	{ pattern = "[^%w_%.:]spawn%s*%(", message = "use task.spawn, not spawn" },
	{ pattern = "[^%w_%.:]delay%s*%(", message = "use task.delay, not delay" },
	{ pattern = "[^%w_%.:]tick%s*%(", message = "use os.clock or workspace:GetServerTimeNow, not tick" },
	{ pattern = "loadstring", message = "loadstring is banned" },
	{ pattern = "[:%.]GetMouse%s*%(", message = "use UserInputService or ContextActionService, not Mouse" },
	{ pattern = "GetProductInfo%s*%(", message = "use GetProductInfoAsync" },
	{ pattern = "[:%.]InvokeClient%s*%(", message = "never use InvokeClient" },
	{ pattern = "GetService%(%s*[\"']Chat[\"']", message = "use TextChatService, not legacy Chat" },
}

-- Applied to src/shared/Logic/ only: time and randomness must be injected.
local LOGIC_BANNED: { Rule } = {
	{ pattern = "os%.time", message = "Logic must take `now` as a parameter, not call os.time" },
	{ pattern = "os%.clock", message = "Logic must take `now` as a parameter, not call os.clock" },
	{ pattern = "os%.date", message = "Logic must take `now` as a parameter, not call os.date" },
	{ pattern = "math%.random", message = "Logic must take `rng` as a parameter, not call math.random" },
}

local problems: { string } = {}

local function report(path: string, line: number, message: string)
	table.insert(problems, `{path}:{line}: {message}`)
end

local function walk(dir: string, out: { string })
	if not fs.isDir(dir) then
		return
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, entry in entries do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			walk(path, out)
		else
			table.insert(out, path)
		end
	end
end

local function isVendored(path: string): boolean
	return string.find(path, "/Vendor/", 1, true) ~= nil or string.find(path, "/Packages/", 1, true) ~= nil
end

local function scan(path: string, rules: { Rule })
	local lineNumber = 0
	for line in string.gmatch(fs.readFile(path) .. "\n", "([^\n]*)\n") do
		lineNumber += 1
		local code = " " .. string.gsub(line, "%-%-.*$", "")
		for _, rule in rules do
			if string.find(code, rule.pattern) then
				report(path, lineNumber, rule.message)
			end
		end
	end
end

local srcFiles = {}
walk("src", srcFiles)
local toolFiles = {}
walk("tools", toolFiles)

for _, path in srcFiles do
	if isVendored(path) or string.sub(path, -8) == ".gitkeep" then
		continue
	end
	if string.sub(path, -4) == ".lua" then
		report(path, 1, "use the .luau extension")
		continue
	end
	if string.sub(path, -5) ~= ".luau" then
		continue
	end

	local source = fs.readFile(path)
	if string.match(source, "^%s*([^\n]*)") ~= "--!strict" then
		report(path, 1, "first line must be --!strict")
	end

	-- .luaurc aliases exist only for Lune and luau-lsp; Roblox only understands
	-- relative string requires (./, ../, @self/) and instance requires.
	local lineNumber = 0
	for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
		lineNumber += 1
		local alias = string.match(line, "require%s*%(%s*[\"'](@[%w_]+)")
		if alias and alias ~= "@self" then
			report(path, lineNumber, `require alias {alias} does not exist in Roblox; use a relative path`)
		end
	end

	scan(path, BANNED)
	if string.find(path, "src/shared/Logic/", 1, true) == 1 then
		scan(path, LOGIC_BANNED)
	end
end

for _, path in toolFiles do
	if string.sub(path, -5) == ".luau" then
		scan(path, BANNED)
	end
end

for _, problem in problems do
	print(problem)
end
print(`conventions: {#problems} problem(s)`)
process.exit(if #problems == 0 then 0 else 1)
