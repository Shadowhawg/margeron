--!strict
-- The quality gate. Must pass before every commit.
--
--   format (StyLua) -> lint (selene) -> conventions -> types (luau-lsp) -> tests -> build (rojo)
--
-- Every step runs even if an earlier one fails, so one run shows every problem.
--
--   lune run check

local fs = require("@lune/fs")
local process = require("@lune/process")

local SOURCES = { "src", "lune", "tests", "tools" }
local BUILD_OUTPUT = "build/check.rbxl"

type Step = { name: string, program: string, args: { string } }

local function withSources(args: { string }): { string }
	local out = table.clone(args)
	table.move(SOURCES, 1, #SOURCES, #out + 1, out)
	return out
end

local steps: { Step } = {
	{ name = "format", program = "stylua", args = withSources({ "--check" }) },
	{ name = "lint", program = "selene", args = withSources({}) },
	{ name = "conventions", program = "lune", args = { "run", "conventions" } },
	{ name = "types", program = "lune", args = { "run", "analyze" } },
	{ name = "tests", program = "lune", args = { "run", "test" } },
	{ name = "build", program = "rojo", args = { "build", "default.project.json", "--output", BUILD_OUTPUT } },
}

if not fs.isDir("build") then
	fs.writeDir("build")
end

local results: { { name: string, ok: boolean } } = {}
for _, step in steps do
	print(`\n== {step.name}`)
	local ok, result = pcall(process.exec, step.program, step.args, { stdio = "inherit" })
	if not ok then
		print(`could not run {step.program}: {result}`)
	end
	table.insert(results, { name = step.name, ok = ok and result.ok })
end

-- The build is only a compile check; don't leave the place file around.
if fs.isFile(BUILD_OUTPUT) then
	fs.removeFile(BUILD_OUTPUT)
end

print("\n== summary")
local failed = 0
for _, result in results do
	print(`{if result.ok then "PASS" else "FAIL"}  {result.name}`)
	if not result.ok then
		failed += 1
	end
end
process.exit(if failed == 0 then 0 else 1)
