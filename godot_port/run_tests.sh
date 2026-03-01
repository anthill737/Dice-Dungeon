#!/usr/bin/env bash
# Run GUT tests headlessly for Dice Dungeon Godot port.
# Requires: godot 4.3+ on PATH.
#
# Usage:
#   ./run_tests.sh            # run all tests
#   ./run_tests.sh -gselect=test_sanity  # run specific test script

set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"

# Ensure resources are imported (needed on first run / CI)
"$GODOT" --headless --import 2>/dev/null || true

# Run GUT
"$GODOT" --headless \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/ \
  -gprefix=test_ \
  -gsuffix=.gd \
  -gexit \
  "$@"
