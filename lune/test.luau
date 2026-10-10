--!strict
-- Runs every tests/**/*.spec.luau file and prints a summary.
--
--   lune run test            run all specs
--   lune run test -- Trade   run only spec files whose path contains "Trade"

local fs = require("@lune/fs")
local process = require("@lune/process")
local testing = require("@testing")

local TESTS_DIR = "tests"

local function collect(dir: string, out: { string })
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, entry in entries do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			collect(path, out)
		elseif string.sub(entry, -10) == ".spec.luau" then
			table.insert(out, path)
		end
	end
end

local filter = process.args[1]
local specs = {}
collect(TESTS_DIR, specs)

local ran = 0
for _, path in specs do
	if filter == nil or string.find(path, filter, 1, true) then
		ran += 1
		-- Paths are relative to the repo root; this script lives one level below it.
		local modulePath = "../" .. string.sub(path, 1, -6)
		local ok, err = pcall(require, modulePath)
		if not ok then
			testing.recordFailure(path, `failed to load: {err}`)
		end
	end
end

local passed, failed = testing.results()
for _, failure in failed do
	print(`FAIL {failure.name}\n     {failure.message}`)
end
print(`{ran} spec file(s), {passed} passed, {#failed} failed`)

if ran == 0 then
	print("No spec files matched.")
	process.exit(1)
end
process.exit(if #failed == 0 then 0 else 1)
