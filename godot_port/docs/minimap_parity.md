# Minimap Parity — Godot vs Python

Reference document for the minimap implementation in the Godot port.
See `python_minimap_rules.md` for the authoritative Python behavior.

---

## Node Paths

```
Explorer (root)
└── RightSidebar / VBoxContainer
    └── MinimapPanel (PanelContainer) [minimap_panel.gd]
        └── VBoxContainer
            ├── Label ("Minimap" header)
            ├── MinimapCanvas (Control) — custom draw + gui_input
            │   └── MinimapTooltip (Label) — hover room name
            └── HBoxContainer (button row)
                ├── Button "−" (zoom out)
                ├── Button "◎" (center on player)
                └── Button "+" (zoom in)
```

## Room Representation

| Attribute | Implementation |
|-----------|---------------|
| Shape | Filled rectangle on 2D canvas |
| Current room | Gold fill (`#ffd700`) + extra gold outline |
| Visited room | Medium gray fill (`#4a4a4a`) |
| Every room | White 1px outline (`#ffffff`) |

**Python match:** ✅ Room fills match Python colors exactly.

## Blocked Edges

- Red bars drawn at the room edge for each direction in `room.blocked_exits`.
- Color: `#ff3333`, width scales with zoom.
- Bar extends 1.5× half-size beyond room center in both perpendicular directions.

**Python match:** ✅ Same color, same position logic.

## Special Room Markers

| Type | Icon | Color | Condition |
|------|------|-------|-----------|
| Stairs | 3-step staircase shape | Green `#00ff00` | `room.has_stairs` |
| Store | Circle (coin) | Green `#00ff00` | `room.has_store` |
| Boss/Mini-boss (locked) | Skull | Red `#ff3333` | In `special_rooms` and not in `unlocked_rooms` |
| Boss/Mini-boss (active) | Skull | Red `#ff0000` | `visited` and not `enemies_defeated` |
| Boss/Mini-boss (defeated) | Checkmark (✓) | Green `#00ff00` | `enemies_defeated` |
| Chest (unlooted) | Chest rectangle | Gold | `has_chest and not chest_looted` |
| Escaped combat | Cross (X) | Dark red | `combat_escaped` |

Icons only render when `zoom >= 0.5` (matches Python).

**Python match:** ✅ Same classification logic. Rendering uses drawn shapes
instead of text glyphs, but the semantic mapping is identical.

## Connections

| Type | Style | Color |
|------|-------|-------|
| Open exit | Thin line between rooms | `#3a3a3a` |
| Blocked exit | Red bar at room edge | `#ff3333` |

**Python match:** ✅ Open exits use the same color. Python uses dashed lines;
Godot uses solid (Godot's `draw_line` doesn't support dash natively). This is
a minor visual difference with no functional impact.

## Hover Tooltip (Godot Enhancement)

- **Python:** Does not implement hover tooltips on the minimap.
- **Godot:** Shows a small tooltip label with the room name and type tag
  (e.g., "[Store]", "[Boss]", "[Locked]") when the mouse hovers over a room
  rectangle on the minimap canvas.
- Label: `MinimapTooltip`, positioned near cursor, clamped to canvas bounds.
- This is an intentional Godot-only enhancement for readability.

## Centering / Follow

| Behavior | Python | Godot |
|----------|--------|-------|
| Default view | Centered on player | Centered on player |
| Auto-recenter on move | No | No (pan offset preserved) |
| Floor change | N/A (rebuilds) | Centers on player |
| Manual recenter | "⊙" button resets pan | "◎" button resets pan |
| Pan | N/S/E/W buttons (2 room units) | Mouse drag |
| Zoom | 0.25–3.0 (0.25 step) | 0.25–3.0 (0.25 step) |

**Python match:** ✅ Functional parity. UI controls differ (drag vs buttons)
but the centering behavior matches.

## MinimapModel (Testable Data)

The minimap exposes pure-data model fields for headless testing:

| Field | Type | Description |
|-------|------|-------------|
| `model_player_room` | `Vector2i?` | Current player room position |
| `model_visible_rooms` | `Array[Vector2i]` | All rooms drawn on minimap |
| `model_blocked_edges` | `Array[Dict]` | `{pos: Vector2i, dir: String}` |
| `model_special_markers` | `Dict[Vector2i, String]` | Room → marker type |
| `model_center_target` | `Vector2i?` | What the minimap centers on |

Marker type values: `"stairs"`, `"store"`, `"locked"`, `"boss_active"`,
`"miniboss_active"`, `"defeated"`, `"chest"`, `"escaped"`.

## Tests

Test file: `tests/test_minimap.gd` (15 tests)

| # | Test | What it validates |
|---|------|-------------------|
| 1 | `test_explorer_has_minimap_panel` | MinimapPanel in Explorer scene |
| 2 | `test_minimap_instantiates` | Standalone instantiation + canvas |
| 3 | `test_explored_rooms_increment` | Room count grows on movement |
| 4 | `test_current_room_updates` | Player pos changes on movement |
| 5 | `test_save_load_rebuild` | State survives save/load cycle |
| 6 | `test_player_marker_at_start` | Player marker at (0,0) on new game |
| 7 | `test_starting_room_visible` | Starting room in visible list |
| 8 | `test_special_marker_stairs` | Stairs marker classification |
| 9 | `test_special_marker_store` | Store marker classification |
| 10 | `test_special_marker_boss_locked` | Locked boss marker |
| 11 | `test_special_marker_boss_defeated` | Defeated boss marker |
| 12 | `test_blocked_edges_in_model` | Blocked edge in model data |
| 13 | `test_follow_center_target_updates` | Center target follows player |
| 14 | `test_tooltip_node_exists` | Tooltip label present and hidden |
| 15 | `test_visible_rooms_grow_after_moves` | Visible rooms increase |
