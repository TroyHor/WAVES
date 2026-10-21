#!/usr/bin/env bash
# Prints bot win rate / fight length / HP lost per encounter. Usage: scripts/balance.sh [seeds]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="$(scripts/godot_bin.sh)"
"$GODOT_BIN" --headless --path . -s res://tests/balance_probe.gd -- "$@" 2>&1 | grep -v "^Godot Engine"
