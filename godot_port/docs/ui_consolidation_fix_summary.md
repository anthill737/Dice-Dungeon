# UI Consolidation Fix Summary

## What was deleted

### Docs (5 files removed)
- `python_ui_parity_spec.md` — merged into `ui_python_parity.md`
- `python_menu_ui_spec.md` — merged into `ui_python_parity.md`
- `ui_parity_summary.md` — merged into `ui_parity_gap_list.md`
- `godot_popup_ui_gap_list.md` — merged into `ui_parity_gap_list.md`
- `ui_modal_menus_summary.md` — merged into `ui_modal_system.md`

### Tests (5 files removed)
- `test_ui_parity_nodes.gd` — merged into `test_popup_content.gd`
- `test_popup_overlay_system.gd` — merged into `test_overlay_manager.gd`
- `test_popup_sizing.gd` — merged into `test_popup_content.gd`
- `test_combat_panel_gating.gd` — merged into `test_overlay_manager.gd` + `test_popup_content.gd`
- `test_lore_ui_loads.gd` — merged into `test_popup_content.gd`

## What remains canonical

### Docs (3 files)
| File | Purpose |
|------|---------|
| `docs/ui_modal_system.md` | Architecture: node paths, size profiles, ESC rules, registration API |
| `docs/ui_python_parity.md` | Python reference per menu and how Godot matches |
| `docs/ui_parity_gap_list.md` | Match/gap checklist with ✓/~/ markers |

### Popup/UI tests (2 core files)
| File | Tests | Coverage |
|------|-------|----------|
| `tests/test_overlay_manager.gd` | 12 | PopupFrame basics, manager stack/LIFO, can_close gating, explorer integration, all-frames-have-close, combat blocking, pause buttons/confirm |
| `tests/test_popup_content.gd` | 12 | Table-driven panel node checks, status tabs/sections, inventory gating, combat pending/victory, sizing algorithm, size profiles, codex empty refresh, sidebar flee |

### Other UI test files kept (non-overlapping)
| File | Tests | Coverage |
|------|-------|----------|
| `tests/test_ui_load_scenes.gd` | 6 | Scene load smoke tests (MainMenu, Explorer, panels) |
| `tests/test_ui_basic_flow_no_clicks.gd` | ~10 | New game init, movement, multi-move, combat flow, inventory, store, save/load |

## Sizing authority

`MenuOverlayManager.SIZE_PROFILES` is the single source of truth for all popup sizes.
Both `explorer.gd` and `main_menu.gd` call `register_menu(key, title, content, profile_string)`.
`PopupFrame` receives `size_config` from the manager and applies it via `_apply_sizing()`.
No sizing parameters are hardcoded in explorer.gd or main_menu.gd.

## Test count
297 tests across 26 scripts, all passing headless.
