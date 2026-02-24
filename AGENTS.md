# Dice Dungeon - Agent Instructions

## Cursor Cloud specific instructions

### Overview

Dice Dungeon is a standalone Python/Tkinter desktop roguelike game with two modes: Classic and Adventure. There are no backend services, databases, or network dependencies. See `README.md` for gameplay and project structure details.

### System dependencies

- **python3-tk** must be installed (`sudo apt-get install -y python3-tk`) for Tkinter GUI.
- A display server (X11 or Xvfb) is required to launch the game. The Cloud VM has `:1` display available by default.

### Running the game

- Launcher: `python3 dice_dungeon_launcher.py`
- Classic Mode directly: `python3 dice_dungeon_rpg.py`
- Adventure Mode directly: `python3 dice_dungeon_explorer.py`

### Testing and linting

This codebase has **no automated test suite** and **no linter configuration** (no pytest, flake8, mypy, ruff, etc.). Testing is manual: launch the game and interact with it. See `docs/ARCHITECTURE_RULES.md` for code organization conventions.

### Architecture

The codebase follows a manager pattern. Game logic lives in `explorer/` module files, not in the main `dice_dungeon_explorer.py`. See `docs/ARCHITECTURE_RULES.md` for the full pattern and rules.
