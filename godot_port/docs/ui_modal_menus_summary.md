# UI Modal Menus Summary

## What was done

Converted all Explorer Mode submenus from direct-child overlay panels into
modal popups managed by a centralized `MenuOverlayManager`. Added a new
Pause menu with "Quit to Main Menu" functionality.

## Scenes converted to popup content

| Menu | Key | Existing scene | Notes |
|------|-----|----------------|-------|
| Combat | `combat` | `CombatPanel.tscn` | Close blocked during active combat |
| Inventory | `inventory` | `InventoryPanel.tscn` | Opened via I key or sidebar button |
| Character Status | `character_status` | `CharacterStatusPanel.tscn` | Opened via G key or top-bar button |
| Save/Load | `save_load` | `SaveLoadPanel.tscn` | Opened via sidebar button |
| Store | `store` | `StorePanel.tscn` | Opened when room has store |
| Settings | `settings` | `SettingsPanel.tscn` | Opened via top-bar button or pause menu |
| Lore Codex | `lore_codex` | `LoreCodexPanel.tscn` | Now wired into Explorer (was disconnected) |
| Pause | `pause` | `PauseMenu.tscn` (new) | Resume, Settings, Quit to Main Menu |

## New files

| File | Purpose |
|------|---------|
| `ui/scripts/popup_frame.gd` | Shared modal wrapper with title bar + red X close button |
| `ui/scripts/menu_overlay_manager.gd` | LIFO stack-based popup manager on CanvasLayer 100 |
| `ui/scripts/pause_menu.gd` | Pause menu content (Resume, Settings, Quit to Main Menu) |
| `ui/scenes/PauseMenu.tscn` | Pause menu scene |
| `tests/test_popup_overlay_system.gd` | 19 GUT tests for the popup system |
| `docs/ui_modal_menus_summary.md` | This file |

## Modified files

| File | Change |
|------|--------|
| `ui/scripts/explorer.gd` | Replaced direct panel management with `MenuOverlayManager`. Added pause menu. ESC now opens pause when no popup is open. |
| `tests/test_combat_panel_gating.gd` | Updated victory test to check via `_overlay_manager.is_menu_open()` instead of `_combat_panel.visible` |

## Node paths

- Overlay manager: `Explorer/MenuOverlayManager` (CanvasLayer, layer 100)
- Popup root: `Explorer/MenuOverlayManager/PopupRoot`
- Each popup: `Explorer/MenuOverlayManager/PopupRoot/<PopupFrame>`
- Close button per popup: `<PopupFrame>/PopupPanel/.../TitleBar/.../BtnPopupClose`

## Architecture

### PopupFrame (`popup_frame.gd`)
- `PanelContainer` with full-rect dim background + centered popup panel
- Title bar with label + red X close button
- Content container where submenu panels are nested
- `closable` property controls X button visibility
- Emits `close_requested` signal

### MenuOverlayManager (`menu_overlay_manager.gd`)
- Extends `CanvasLayer` (layer 100, above all game UI)
- `register_menu(key, title, content, can_close_fn)` — registers a popup
- `open_menu(key)` / `close_menu(key)` — fade in/out with tween
- `close_top_menu()` — LIFO stack pop, respects `can_close` overrides
- `is_any_open()` / `is_menu_open(key)` — query state
- Combat panel has `can_close_fn` that returns `false` during active combat

### ESC behavior
1. If any popup is open → close topmost (LIFO), respecting combat gating
2. If no popup is open → open Pause menu
3. Both `ui_cancel` (Q) and `open_menu` (Escape) trigger this logic

### Pause menu
- Resume → closes pause popup
- Settings → closes pause, opens settings popup
- Quit to Main Menu → shows confirm dialog, then calls `get_tree().change_scene_to_file()` to return to `MainMenu.tscn`

## Intentional differences from previous behavior

- **ESC with no popup open**: Previously did nothing. Now opens Pause menu.
- **Menu button (☰)**: Previously opened Save/Load. Now opens Pause menu. Save/Load is accessed via sidebar button.
- **Lore Codex**: Previously not wired into Explorer. Now registered as a popup menu (accessible programmatically; no sidebar button yet).
- **Popup visual**: Each menu now has a PopupFrame wrapper adding a title bar and dim background. The submenu content is nested inside.
- **Modal input blocking**: The PopupFrame's dim background has `MOUSE_FILTER_STOP`, preventing clicks through to gameplay.

## Determinism

No changes to combat logic, RNG, game state mutations, or combat resolution order.
All popup operations are pure view/controller. The `MenuOverlayManager` never calls
game logic — it only manages UI visibility and signals.
