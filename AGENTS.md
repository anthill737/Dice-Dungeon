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

## Git workflow

- For any new feature branch that is expected to become a PR, always `git fetch origin` first and branch from `origin/main`, not from an older feature branch or a local branch that predates recent merges.
- Prefer creating a fresh `git worktree` from `origin/main` for larger features, especially when touching many Godot assets or generated binary files, so the new branch has a clean base and does not inherit unrelated local changes.
- Publish the branch early with `git push -u origin <branch>` so GitHub tracks the correct branch tip from the start.
- If earlier work on the same topic was already merged to `main` by squash/merge, do not branch from the old feature branch again. Start a new branch from `origin/main` and reapply only the new commits there to avoid massive add/add and content conflicts in the PR.
