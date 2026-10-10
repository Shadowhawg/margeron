#!/usr/bin/env bash
# Fallback toolchain installer for environments where Rokit can't reach the
# GitHub API (for example, Claude Code cloud sessions). It installs the exact
# versions pinned in rokit.toml from GitHub release downloads.
#
# On a normal dev machine, use `rokit install` instead.
#
# Usage: tools/install-toolchain.sh            (installs into .toolchain/bin)
#        TOOLCHAIN_DIR=/some/dir tools/install-toolchain.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${TOOLCHAIN_DIR:-$ROOT/.toolchain/bin}"
mkdir -p "$BIN"

if [[ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]]; then
	echo "install-toolchain.sh only supports Linux x86_64. Use 'rokit install' instead." >&2
	exit 1
fi

# Prints "<tag> <asset>" for a tool name and version. Release asset names are
# not uniform across these projects, so they are listed explicitly.
release_of() {
	local name="$1" v="$2"
	case "$name" in
	rojo) echo "v$v rojo-$v-linux-x86_64.zip" ;;
	wally) echo "v$v wally-v$v-linux.zip" ;;
	stylua) echo "v$v stylua-linux-x86_64.zip" ;;
	selene) echo "$v selene-$v-linux.zip" ;;
	luau-lsp) echo "$v luau-lsp-linux-x86_64.zip" ;;
	lune) echo "v$v lune-$v-linux-x86_64.zip" ;;
	*) return 1 ;;
	esac
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Reads lines like: rojo = "rojo-rbx/rojo@7.7.1"
grep -E '^[a-z-]+ *= *"[^"]+@[^"]+"' "$ROOT/rokit.toml" | while IFS= read -r line; do
	name="$(sed -E 's/^([a-z-]+).*/\1/' <<<"$line")"
	repo="$(sed -E 's/.*"([^@"]+)@.*/\1/' <<<"$line")"
	version="$(sed -E 's/.*@([^"]+)".*/\1/' <<<"$line")"

	if [[ -x "$BIN/$name" ]] && "$BIN/$name" --version 2>/dev/null | grep -qF "$version"; then
		echo "ok    $name $version"
		continue
	fi

	if ! read -r tag asset < <(release_of "$name" "$version"); then
		echo "error $name: no release mapping in install-toolchain.sh" >&2
		exit 1
	fi

	url="https://github.com/$repo/releases/download/$tag/$asset"
	echo "fetch $name $version"
	curl -fsSL --retry 4 --retry-delay 2 -o "$tmp/$asset" "$url"
	rm -rf "$tmp/unzipped"
	unzip -q -o "$tmp/$asset" -d "$tmp/unzipped"
	install -m 0755 "$(find "$tmp/unzipped" -type f -name "$name" | head -n 1)" "$BIN/$name"
done

echo
echo "Installed into $BIN"
case ":$PATH:" in
*":$BIN:"*) ;;
*) echo "Add it to your PATH:  export PATH=\"$BIN:\$PATH\"" ;;
esac
