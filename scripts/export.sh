#!/usr/bin/env bash
# Headless release export. Usage: scripts/export.sh [macos|windows|linux|all]  (default: current OS)
# Requires the Godot export templates matching the engine version.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="$(scripts/godot_bin.sh)"

target="${1:-}"
if [[ -z "$target" ]]; then
  case "$(uname -s)" in
    Darwin) target=macos ;;
    Linux) target=linux ;;
    *) target=windows ;;
  esac
fi

export_one() {
  local preset="$1" path="$2"
  mkdir -p "$(dirname "$path")"
  echo "== Exporting $preset -> $path"
  "$GODOT_BIN" --headless --path . --export-release "$preset" "$path"
}

"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
case "$target" in
  macos) export_one "macOS" "builds/macos/WAVES.zip" ;;
  windows) export_one "Windows" "builds/windows/WAVES.exe" ;;
  linux) export_one "Linux" "builds/linux/WAVES.x86_64" ;;
  all)
    export_one "macOS" "builds/macos/WAVES.zip"
    export_one "Windows" "builds/windows/WAVES.exe"
    export_one "Linux" "builds/linux/WAVES.x86_64"
    ;;
  *) echo "unknown target: $target" >&2; exit 1 ;;
esac
