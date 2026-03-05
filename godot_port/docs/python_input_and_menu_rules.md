# Python Input and Menu Rules

Extracted from: `dice_dungeon_explorer.py` lines 730–1012

## Default Keybindings

| Action          | Default Key | Customizable |
|-----------------|-------------|--------------|
| Open Inventory  | Tab         | Yes          |
| Open Menu       | m           | Yes          |
| Rest            | r           | Yes          |
| Move North      | w           | Yes          |
| Move South      | s           | Yes          |
| Move East       | d           | Yes          |
| Move West       | a           | Yes          |
| Character Status| g           | Hardcoded    |
| Inventory (alt) | i           | Hardcoded    |
| Escape          | Escape      | Always menu  |

## Toggle Behavior

### Menu (Escape / m)
- If `dialog_frame` is open → `close_dialog()` (close topmost).
- Otherwise → `show_pause_menu()` (open pause).
- Same key CLOSES if menu is already open (toggle behavior).

### Inventory (Tab / i)
- Opens inventory panel.
- Python does NOT have explicit toggle-to-close for Tab: close is via Escape or close button.
- However, for Godot parity: pressing the same menu hotkey when that menu is the topmost should close it (better UX).

## Tab Focus Prevention
- Python uses Tkinter which does not have a Tab-focus-cycle issue.
- In Godot, Tab is a built-in focus navigation key. Must be consumed/handled before Godot's UI focus traversal.
- The input event must call `get_viewport().set_input_as_handled()` to prevent Tab from cycling focus.

## Blocking Rules
- All hotkeys ignored while focus is on an `Entry` widget (text input).
- Movement/rest ignored when `dialog_frame` (any popup) is open.
- Movement ignored when `in_combat` or `in_interaction`.
- Rest ignored when `in_combat`.

## Godot Implementation
- Use `_unhandled_input` to intercept keys AFTER UI controls.
- Tab must be handled as first priority and consumed.
- Toggle logic: if menu X is the topmost open menu and X's hotkey is pressed → close X.
