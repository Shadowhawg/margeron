--!strict
-- Strict type-checking with luau-lsp, in two passes:
--
--   1. All of src/ against the Roblox type definitions and the Rojo sourcemap.
--   2. src/shared/Logic/ with NO Roblox definitions. Any Roblox global (game,
--      Instance, Random, task, ...) is then an error, which keeps Logic pure.
--
-- Roblox definitions are downloaded once per luau-lsp version into .cache/.
--
--   lune run analyze

local fs = require("@lune/fs")
local process = require("@lune/process")

local CACHE_DIR = ".cache/luau-lsp"
local IGNORES = { "--ignore=**/Packages/**", "--ignore=src/server/Vendor/**" }

local function exec(program: string, args: { string }): boolean
	return process.exec(program, args, { stdio = "inherit" }).ok
end

local function append(list: { string }, extra: { string }): { string }
	local out = table.clone(list)
	table.move(extra, 1, #extra, #out + 1, out)
	return out
end

local function ensureDefinitions(): string?
	local version = process.exec("luau-lsp", { "--version" })
	if not version.ok then
		print("luau-lsp not found. Run `rokit install` (or tools/install-toolchain.sh).")
		return nil
	end
	local tag = string.gsub(version.stdout, "%s+", "")
	local path = `{CACHE_DIR}/globalTypes.None-{tag}.d.luau`
	if fs.isFile(path) then
		return path
	end

	-- Lune's HTTP client doesn't use the system certificate store, so curl is
	-- more reliable behind proxies. It ships with macOS, Windows 10+ and Linux.
	local url = `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{tag}/scripts/globalTypes.None.d.luau`
	print(`Downloading Roblox type definitions for luau-lsp {tag}`)
	if not fs.isDir(CACHE_DIR) then
		fs.writeDir(CACHE_DIR)
	end
	local partial = path .. ".partial"
	if not exec("curl", { "-fsSL", "--retry", "3", "-o", partial, url }) then
		print(`Failed to download {url}`)
		return nil
	end
	fs.move(partial, path, true)
	return path
end

local definitions = ensureDefinitions()
if definitions == nil then
	process.exit(1)
end

local ok = exec("rojo", { "sourcemap", "default.project.json", "--output", "sourcemap.json" })

ok = exec(
	"luau-lsp",
	append({
		"analyze",
		`--definitions=@roblox={definitions}`,
		"--sourcemap=sourcemap.json",
		"--base-luaurc=.luaurc",
	}, append(IGNORES, { "src" }))
) and ok

local function luauFiles(dir: string, out: { string }): { string }
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(entry, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

local logicFiles = luauFiles("src/shared/Logic", {})
if #logicFiles == 0 then
	print("Purity pass: no Logic modules yet, skipped")
else
	print("Purity pass: src/shared/Logic without Roblox definitions")
	ok = exec("luau-lsp", append({ "analyze", "--platform=standard", "--base-luaurc=.luaurc" }, logicFiles)) and ok
end

process.exit(if ok then 0 else 1)
