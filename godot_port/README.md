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

## Running tests

Tests use [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) v9.3.0, vendored in `addons/gut/`.

### Quick run

```bash
cd godot_port
./run_tests.sh
```

### Manual command

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gexit
```

### Run a specific test script

```bash
./run_tests.sh -gselect=test_sanity
```

### Writing new tests

Create files in `tests/` with the `test_` prefix. Each test file must `extends GutTest` and contain functions prefixed with `test_`.

## Project structure

```
godot_port/
├── project.godot          # Godot 4 project file
├── icon.svg               # Project icon
├── .gitignore             # Ignores .godot/ cache
├── .gutconfig.json        # GUT test runner config
├── run_tests.sh           # Headless test runner script
├── addons/gut/            # GUT v9.3.0 (vendored)
├── scenes/
│   └── Main.tscn          # Main scene (Control root)
├── scripts/
│   └── Main.gd            # Main scene script
├── tests/
│   └── test_sanity.gd     # Sanity tests (arithmetic, arrays, dicts)
└── README.md              # This file
```

## What's next

Gameplay porting will add scenes, scripts, and assets under this directory. The original Python/Tkinter game lives in the repository root — see the top-level `README.md` for details.
