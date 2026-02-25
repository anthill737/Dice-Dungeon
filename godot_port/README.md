# Dice Dungeon — Godot 4 Port

Scaffold workspace for the Godot 4 port of Dice Dungeon. No gameplay has been ported yet — this contains only the project skeleton and a minimal main scene.

## Requirements

- **Godot 4.3+** (standard or .NET build)
- Download from https://godotengine.org/download

## Opening the project

1. Launch the Godot editor.
2. Click **Import** → browse to this `godot_port/` directory → select `project.godot` → **Import & Edit**.
3. The project opens with `Main.tscn` set as the main scene.
4. Press **F5** (or the Play button) to run.

## Running from the command line

### With the editor UI (default)

```bash
# Linux / macOS
godot --path godot_port

# Windows
godot.exe --path godot_port
```

### Headless (no window — CI / validation only)

```bash
godot --path godot_port --headless --quit
```

This imports resources, validates the project, and exits. Exit code 0 means the project parsed without errors.

### Running the main scene without the editor

```bash
godot --path godot_port --main-loop SceneTree
```

## Project structure

```
godot_port/
├── project.godot          # Godot 4 project file
├── icon.svg               # Project icon
├── .gitignore             # Ignores .godot/ cache
├── scenes/
│   └── Main.tscn          # Main scene (Control root)
├── scripts/
│   └── Main.gd            # Main scene script
└── README.md              # This file
```

## What's next

Gameplay porting will add scenes, scripts, and assets under this directory. The original Python/Tkinter game lives in the repository root — see the top-level `README.md` for details.
