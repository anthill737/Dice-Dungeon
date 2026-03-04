# Python Minimap Reference Rules

Authoritative reference for minimap behavior as implemented in the Python Tkinter
version (`dice_dungeon_explorer.py`). The Godot port must match these rules unless
an intentional enhancement is explicitly documented.

---

## 1. Visibility Rules

- **Data source:** `self.dungeon` — a `dict` keyed by `(x, y)` tuples.
- **Rooms drawn:** Every room present in `self.dungeon` is drawn, regardless of the
  `visited` flag. In practice, rooms are added to `self.dungeon` only when the
  player enters them (see `navigation.py` `explore_direction`), so only
  discovered rooms appear.
- **Starting state:** At floor start, `self.dungeon` contains only the entrance at
  `(0, 0)`. The minimap therefore shows exactly one room with the player marker
  on it immediately.
- **Adjacent rooms:** Adjacent rooms are *not* shown until they are entered. There
  is no fog-of-war "preview" of unvisited neighbours.

## 2. Room Colors

| Condition               | Fill Color   | Hex        |
|--------------------------|-------------|------------|
| Current room (player)    | Gold        | `#ffd700`  |
| Visited room             | Medium gray | `#4a4a4a`  |
| Unvisited room           | Light gray  | `#666666`  |

- All rooms have a white outline (`#ffffff`, width 1).

## 3. Player Indicator

- The current room is drawn with fill color `#ffd700` (gold).
- No separate marker dot or sprite; the room square itself changes color.
- The legend labels it as "You" with color `#d4af37`.

## 4. Special Room Icons

Icons are drawn as text glyphs on top of the room square. All icons require
`minimap_zoom >= 0.5` to be rendered.

| Room Type                    | Symbol | Color     | Condition                                  |
|------------------------------|--------|-----------|--------------------------------------------|
| Stairs                       | `∩`    | `#00ff00` | `room.has_stairs`                          |
| Store                        | `$`    | `#00ff00` | `store_found and pos == store_position`    |
| Mini-boss (locked)           | `💀`   | `#ff3333` | `pos in special_rooms and pos not in unlocked_rooms` |
| Mini-boss (active, visited)  | `💀`   | `#ff0000` | `visited and not enemies_defeated`         |
| Mini-boss (defeated)         | `✓`    | `#00ff00` | `visited and enemies_defeated`             |
| Boss (locked)                | `💀`   | `#ff3333` | `pos in special_rooms and pos not in unlocked_rooms` |
| Boss (active, visited)       | `💀`   | `#ff0000` | `visited and not enemies_defeated`         |
| Boss (defeated)              | `✓`    | `#00ff00` | `visited and enemies_defeated`             |

- Font sizes scale with zoom (`max(10, int(14 * zoom))` or `16 * zoom` for skulls).
- Locked rooms are shown even when not yet visited (they are in `special_rooms`).

## 5. Connections (Exit Lines)

### Open exits
- A dashed line (`#3a3a3a`, width 1, dash `(2, 3)`) connects two rooms that
  share an open exit.
- Both rooms must exist in `self.dungeon` and the exit must *not* be blocked.

### Blocked exits (red bars)
- If a room has a blocked exit, a red bar is drawn at the room edge in that
  direction.
- Color: `#ff3333`, width 3.
- Bar length: `half_size * 1.5` (extends beyond the room square slightly).
- Bars are drawn for *every* blocked exit direction, not just those with
  adjacent rooms.

## 6. Hover / Tooltip

- **Not implemented in Python.** The only canvas binding is `<MouseWheel>` for
  zoom. No `Enter`, `Motion`, or `Leave` events are handled.

## 7. Centering and Follow

- **Default center:** The view center is `current_pos + (pan_x, pan_y)` in room
  coordinates. Since `pan_x` and `pan_y` default to `0`, the view is centered
  on the player by default.
- **No auto-recenter on move:** When the player moves to a new room, the pan
  offsets are *not* reset. The player may drift off-center if they have panned.
- **Recenter button ("⊙"):** Pressing the center button resets
  `pan_x = pan_y = 0`, re-centering on the player.
- **Pan step:** 2 room units per button press (N/S/E/W buttons).

## 8. Zoom

- Range: 0.25 – 3.0 (step 0.25).
- Mouse wheel: scroll up = zoom in, scroll down = zoom out.
- Button controls: `+` and `−`.
- Special room icons hidden when `zoom < 0.5`.

## 9. Canvas and Sizing

- Canvas: 180×180 pixels (default), background `#0a0604`.
- Resized on resolution change: `max(120, int(180 * scale_factor))`.
- Base cell size: 20 pixels.
- Room half-size: `max(6, min(18, cell_size * 0.45))`.
- Cell size in pixels: `base_cell_size * zoom`.

---

## Godot Deviations

Mismatches found between the current Godot minimap (`minimap_panel.gd`) and
the Python reference:

| Feature | Python | Godot (current) | Status |
|---------|--------|-----------------|--------|
| Initial room visibility | Starting room shown immediately (gold) | Starting room shown, but only if `visited == true`; `_pan_offset` init is lazy | Minor — works but centering is a side-effect of `_draw_minimap` |
| Player room color | Gold fill `#ffd700` | White outline only; room uses type color | **Mismatch** |
| Blocked exits | Red bars at room edges (`#ff3333`) | Blocked exits silently skipped — no visual | **Missing** |
| Special room icons | Text glyphs (∩, $, 💀, ✓) with color coding | Custom drawn shapes (skull, diamond, stairs, coin, chest) | Partial parity — different rendering but equivalent intent |
| Locked rooms visible | Locked boss/mini-boss rooms drawn before visited | Only visited rooms drawn | **Missing** |
| Hover/tooltip | Not present | Not present | Match (both absent) |
| Auto-center on move | No auto-recenter (but default view tracks player) | No auto-recenter; floor change resets pan but doesn't center on player | **Mismatch** — should center on player by default |
| Connection lines | Dashed gray lines between open exits | Solid semi-transparent lines | Minor style difference |
| Zoom range | 0.25 – 3.0 | 0.5 – 3.0 | Minor difference |
| Room outline | White 1px on all rooms | White 2px only on current room | **Mismatch** |
