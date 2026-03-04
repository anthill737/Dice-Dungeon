# Python Minimap Icon Rules

Authoritative reference extracted from `dice_dungeon_explorer.py` lines 2560–2733.

## Cell Size

```
base_cell_size = 20
cell_size = base_cell_size * minimap_zoom
```

| Zoom  | cell_size |
|-------|-----------|
| 0.25  | 5         |
| 0.50  | 10        |
| 1.00  | 20        |
| 1.50  | 30        |
| 2.00  | 40        |
| 3.00  | 60        |

## Room Half-Size (visual square)

```
half_size = max(6, min(18, cell_size * 0.45))
```

Room side length = `2 * half_size`.

| Zoom  | cell_size | half_size | Room side |
|-------|-----------|-----------|-----------|
| 0.25  | 5         | 6 (min)   | 12        |
| 0.50  | 10        | 6 (min)   | 12        |
| 1.00  | 20        | 9         | 18        |
| 1.50  | 30        | 13.5      | 27        |
| 2.00  | 40        | 18 (max)  | 36        |
| 3.00  | 60        | 18 (max)  | 36        |

## Icon Font Size

Python uses Tkinter `create_text` with font size computed as:

```python
font=('Arial', max(10, int(base_size * minimap_zoom)), 'bold')
```

| Icon type                         | base_size | Formula                           |
|-----------------------------------|-----------|-----------------------------------|
| Stairs (∩)                        | 14        | max(10, int(14 * minimap_zoom))   |
| Store ($)                         | 14        | max(10, int(14 * minimap_zoom))   |
| Boss room – locked (💀)           | 14        | max(10, int(14 * minimap_zoom))   |
| Boss room – defeated (✓)          | 14        | max(10, int(14 * minimap_zoom))   |
| Boss room – visited, active (💀)  | 16        | max(10, int(16 * minimap_zoom))   |
| Mini-boss – locked (💀)           | 16        | max(10, int(16 * minimap_zoom))   |
| Mini-boss – defeated (✓)          | 14        | max(10, int(14 * minimap_zoom))   |
| Mini-boss – visited, active (💀)  | 16        | max(10, int(16 * minimap_zoom))   |

## Icon Visibility Threshold

Icons are only drawn when `minimap_zoom >= 0.5`.

## Zoom Range

- Min zoom: **0.25** (25%)
- Max zoom: **3.0** (300%)
- Step: **0.25**
- Default: **1.0**

## Icon Sizing at Extremes

### Minimum zoom (0.25)
- cell_size = 5, half_size = 6 (clamped)
- Room side = 12 px
- Font size = max(10, 3) = **10** for base-14; max(10, 4) = **10** for base-16
- Icons NOT drawn (zoom < 0.5)

### Maximum zoom (3.0)
- cell_size = 60, half_size = 18 (clamped)
- Room side = 36 px
- Font size = max(10, 42) = **42** for base-14; max(10, 48) = **48** for base-16
- **Problem:** font 48 in a 36×36 room cell → icon overflows room square

## Margin / Padding

- Icons are centered at the room center `(x, y)`.
- No explicit margin/padding in the Python code.
- At high zoom, icons can and do overflow the room square boundary.

## Godot Port Clamping Rules

Since Godot uses geometric drawing (not text glyphs), we define:

```
icon_size = clamp(half * 0.85, MIN_ICON_SIZE, half - ICON_MARGIN)
```

Where:
- `MIN_ICON_SIZE = 3.0` — minimum readable threshold
- `ICON_MARGIN = 1.0` — pixel clearance from cell edge
- `half = cell / 2.0`

This ensures:
1. `icon_size <= half - margin` → icon never clips outside room square
2. `icon_size >= MIN_ICON_SIZE` → icon remains visible at low zoom
3. Icon is always centered in the room square

## Icon Symbols (Godot)

Godot uses geometric primitives instead of text glyphs:

| Room type                  | Godot shape     | Color    |
|----------------------------|-----------------|----------|
| Locked boss/miniboss       | Skull (circles) | #ff3333  |
| Boss active (not defeated) | Skull           | #ff0000  |
| Miniboss active            | Skull           | #ff0000  |
| Defeated                   | Checkmark       | #00ff00  |
| Stairs                     | Step blocks     | #00ff00  |
| Store                      | Circles ($)     | #00ff00  |
| Chest                      | Rectangle       | gold     |
| Escaped                    | X cross         | red-ish  |
