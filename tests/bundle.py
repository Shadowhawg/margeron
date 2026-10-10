# Bundles Luau modules into one file with a fake `script` hierarchy so they can run in the
# standalone Luau CLI (no Roblox needed). Used by tests/run.sh.
import os, sys
repo, test, out = sys.argv[1:4]
mods = {}
for root_name, folder in (("Shared", "src/shared"), ("Server", "src/server")):
    base = os.path.join(repo, folder)
    for dp, _, files in os.walk(base):
        for f in files:
            if not f.endswith(".luau") or f.startswith("init."):
                continue
            rel = os.path.relpath(os.path.join(dp, f), base)[:-5]
            mods[root_name + "/" + rel.replace(os.sep, "/")] = open(os.path.join(dp, f)).read()
parts = ["local __src = {}"]
for path, src in mods.items():
    parts.append("__src[%r] = function(script)\n%s\nend" % (path, src))
parts.append(open(os.path.join(os.path.dirname(__file__), "prelude.luau")).read())
parts.append(open(test).read())
open(out, "w").write("\n".join(parts))
