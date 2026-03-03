# Save/Load — Main Menu Flow & Overwrite Confirmation

## Overview

This document describes the load-from-main-menu entry point and the
overwrite-save confirmation dialog added in Step 19.

## Load from Main Menu

### Run-State Handoff

When the user selects a filled slot and clicks **Load** on the Main Menu's
Save/Load popup, the following sequence executes:

```
MainMenu._on_load_save(slot_id)
  → SessionService.start_run_from_save(slot_id)
      → SaveEngine.load_from_slot(...)        # deserialise save file
      → rebuild GameSession engines            # rng, exploration, inventory, …
      → GameSession.pending_run_state = {...}  # store handoff dict
      → emit run_started
  → change_scene_to_file("Explorer.tscn")

Explorer._ready()
  → _consume_pending_run_state()
      → GameSession.consume_pending_run_state()  # read & clear handoff
  → _refresh_ui()                                 # UI reflects loaded state
```

### Canonical Entry Point

```gdscript
SessionService.start_run_from_save(slot_id: int) -> bool
```

This is the **single** entry point for loading a saved run.  It:

1. Calls `SaveEngine.load_from_slot()` to deserialise the JSON save file.
2. Assigns the loaded `GameState` and `FloorState` to `GameSession`.
3. Creates fresh engine instances (`ExplorationEngine`, `InventoryEngine`,
   `StoreEngine`, `LoreEngine`) seeded from the loaded state.
4. Clears `combat` and `combat_pending`.
5. Resets the session trace and records a `"loaded"` event.
6. Stores a handoff dictionary in `GameSession.pending_run_state`.
7. Emits `run_started`.

Returns `true` on success, `false` if the slot is empty or unreadable.

### Handoff Object

`GameSession.pending_run_state` is a plain `Dictionary`:

```gdscript
{
    "source": "save",
    "slot_id": <int>,
}
```

Explorer calls `GameSession.consume_pending_run_state()` in `_ready()`.
After consumption the dictionary is cleared to prevent stale reloads.

If Explorer enters via **Start Adventure** (new game), the dictionary is
empty and `_consume_pending_run_state()` is a no-op.

### SaveLoadPanel Context

`SaveLoadPanel.panel_context` controls behaviour:

| Context       | Save        | Load                                     |
|---------------|-------------|------------------------------------------|
| `IN_GAME`     | Normal save | Reload into current session              |
| `MAIN_MENU`   | Disabled    | Emits `load_into_game_requested(slot_id)`|

Main Menu sets `panel_context = PanelContext.MAIN_MENU` at panel creation.
Explorer leaves it at the default `IN_GAME`.

## Overwrite-Save Confirmation

When saving to a slot that already contains data:

1. `SaveLoadPanel._on_save()` detects the slot is occupied via
   `_is_slot_occupied(slot)`.
2. A confirmation overlay appears: *"Overwrite existing save in Slot X?"*
   with **Confirm** and **Cancel** buttons.
3. **Confirm** → `_on_overwrite_confirmed()` → `_perform_save(slot)`.
4. **Cancel** → `_on_overwrite_cancelled()` → overlay dismissed, no save.

Saving to an empty slot proceeds immediately without confirmation.

The "cannot save during combat" check runs *before* the overwrite check
and is unaffected.

### SaveLoadService Helper

```gdscript
SaveLoadService.slot_has_save(slot_id: int) -> bool
```

Returns `true` if a save file exists for the given slot.  Useful for
programmatic checks outside the panel UI.

## Test Coverage

Tests live in `tests/test_save_load_flow.gd`:

- `start_run_from_save` succeeds on filled slot, fails on empty slot
- Handoff dict is set on success, cleared after consume
- `start_new_game()` is NOT called during save-load
- `slot_has_save` returns correct values for empty/filled/deleted slots
- Overwrite confirm overlay visibility and cancel behaviour
- Main Menu context: save disabled, load emits signal for filled slot,
  load is no-op for empty slot
