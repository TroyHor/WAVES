#!/usr/bin/env bash
# Runs all automated tests headlessly. Usage: scripts/test.sh [name-filter]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="$(scripts/godot_bin.sh)"

# Import first so class_name globals are registered on a fresh checkout.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . -s res://tests/run_tests.gd -- "$@"
