# Exporting Dice Dungeon (Godot 4)

## Required Godot Version

**Godot 4.3** (stable) or later. The project uses `gl_compatibility` rendering and Godot 4.3 features. Download from https://godotengine.org/download/.

## Installing Export Templates

Before exporting you must install the export templates that match your Godot version.

### Via the Editor

1. Open Godot and go to **Editor > Manage Export Templates…**
2. Click **Download and Install** for the version shown.
3. Wait for the download to finish — templates are stored per-user and only need to be installed once per Godot version.

### Headless / CI

Download the templates archive from https://github.com/godotengine/godot/releases and extract to the templates directory:

```bash
# Linux example for Godot 4.3-stable
GODOT_VERSION="4.3.stable"
mkdir -p ~/.local/share/godot/export_templates/$GODOT_VERSION
cd ~/.local/share/godot/export_templates/$GODOT_VERSION
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
unzip Godot_v4.3-stable_export_templates.tpz
mv templates/* .
rmdir templates
```

## Running the Export

### Linux / macOS (Bash)

```bash
# From the repository root:
./scripts/export_builds.sh
```

If `godot` is not on your `PATH`, set the `GODOT_BIN` environment variable:

```bash
GODOT_BIN=/path/to/godot ./scripts/export_builds.sh
```

### Windows (PowerShell)

```powershell
# From the repository root:
.\scripts\export_builds.ps1

# Or with a custom Godot path:
.\scripts\export_builds.ps1 -GodotBin "C:\Godot\Godot_v4.3-stable_win64.exe"
```

## Build Output

Exported builds are written to `godot_port/exports/`:

| File | Platform |
|------|----------|
| `DiceDungeon_linux.x86_64` | Linux x86_64 |
| `DiceDungeon_windows.exe` | Windows x86_64 |

The `exports/` directory is git-ignored — build artifacts are never committed.

## Common Errors

### Missing export templates

```
ERROR: No export template found at expected path...
```

Install export templates for your exact Godot version (see above). The template version must match your editor version exactly (e.g. `4.3.stable`).

### Permission denied on Linux build

```bash
chmod +x godot_port/exports/DiceDungeon_linux.x86_64
```

The export script produces an executable, but if your filesystem strips execute bits, set it manually.

### "Godot binary not found"

The export scripts look for `godot` on `PATH`. Either add Godot to `PATH` or use the `GODOT_BIN` / `-GodotBin` parameter.

### Preset not found

```
ERROR: Export preset "Linux/X11" not found.
```

Ensure `godot_port/export_presets.cfg` exists and has not been modified. Re-checkout the file from version control if needed.

### Windows cross-compilation from Linux

To export a Windows build from a Linux host you need the `mingw-w64` toolchain and the `rcedit` tool:

```bash
sudo apt-get install -y mingw-w64
# Place rcedit in the Godot editor settings or alongside the Godot binary
```

Without these, the Windows export may still succeed but the resulting `.exe` will lack a custom icon and version metadata.
