#!/usr/bin/env sh
# Runs the logic tests outside Roblox using the standalone `luau` CLI.
# Install it once with:  rokit add luau-lang/luau
set -e
cd "$(dirname "$0")/.."
mkdir -p build
status=0
for test in tests/*.test.luau; do
	echo "== $test"
	python3 tests/bundle.py . "$test" "build/$(basename "$test")"
	output=$(luau "build/$(basename "$test")")
	echo "$output" | tail -n 3
	echo "$output" | grep -q " 0 failed" || status=1
done
exit $status
