#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../godot_port" && pwd)"
EXPORT_DIR="$PROJECT_DIR/exports"

GODOT="${GODOT_BIN:-godot}"

if ! command -v "$GODOT" &>/dev/null; then
    echo "ERROR: Godot binary not found."
    echo "  Install Godot 4.3+ and ensure 'godot' is on PATH,"
    echo "  or set GODOT_BIN to the full path of the Godot executable."
    exit 1
fi

echo "==> Using Godot: $GODOT"
"$GODOT" --version

mkdir -p "$EXPORT_DIR"

echo ""
echo "==> Importing project resources (headless)..."
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1 || true
echo "    Import complete."

echo ""
echo "==> Exporting Linux/X11..."
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Linux/X11" "$EXPORT_DIR/DiceDungeon_linux.x86_64"
echo "    -> $EXPORT_DIR/DiceDungeon_linux.x86_64"

echo ""
echo "==> Exporting Windows Desktop..."
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Windows Desktop" "$EXPORT_DIR/DiceDungeon_windows.exe"
echo "    -> $EXPORT_DIR/DiceDungeon_windows.exe"

echo ""
echo "=== Export complete ==="
echo "Builds are in: $EXPORT_DIR/"
ls -lh "$EXPORT_DIR/"
