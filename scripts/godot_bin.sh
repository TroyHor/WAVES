#!/usr/bin/env bash
# Resolves the Godot executable. Override with: export GODOT=/path/to/godot
if [[ -n "${GODOT:-}" ]]; then
  echo "$GODOT"
elif command -v godot >/dev/null 2>&1; then
  command -v godot
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  echo /Applications/Godot.app/Contents/MacOS/Godot
else
  echo "Godot not found; set GODOT=/path/to/godot" >&2
  exit 1
fi
