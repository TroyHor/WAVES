#!/usr/bin/env bash
# Runs all automated tests headlessly. Usage: scripts/test.sh [name-filter]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="$(scripts/godot_bin.sh)" || exit 1

# Import first so class_name globals are registered on a fresh checkout.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
"$GODOT_BIN" --headless --path . -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

# GDScript runtime errors don't abort the calling test, so a crashing test
# would otherwise look like a pass. Treat any script error as a failure.
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG"; then
  echo "Script errors detected — failing the run." >&2
  exit 1
fi
exit "$status"
