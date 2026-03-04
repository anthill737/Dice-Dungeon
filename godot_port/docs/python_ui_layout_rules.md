# Python UI Layout Rules

Reference document for Godot port layout proportions.

## Base Resolution

- Base window: `950x700`
- Minimum: `900x650`
- Scale factor derived from actual size relative to base

## Main Layout

Two-column layout using `pack()`:

```
game_frame (fill=BOTH, expand=True)
└── main_container (fill=BOTH, expand=True)
    ├── left_frame (side=LEFT, fill=BOTH, expand=True)
    └── right_frame (side=RIGHT, fill=Y, padx=5, pady=5)
```

## Left Column (Vertical Stack)

From top to bottom, using `pack(side=TOP)`:

| Region         | Pack args                           | Sizing         |
|----------------|-------------------------------------|----------------|
| Header         | `fill=X, side=TOP`                  | Shrink-wrap    |
| Stats bar      | `fill=X, side=TOP`                  | Shrink-wrap    |
| Room panel     | `fill=X, side=TOP`                  | Shrink-wrap    |
| Action panel   | `fill=X, side=TOP`                  | Shrink-wrap    |
| Actions bar    | `fill=X, side=TOP`                  | Shrink-wrap    |
| Adventure log  | `fill=BOTH, expand=True, side=BOTTOM` | **Flex fill** |

The adventure log takes **all remaining vertical space** after fixed-height
elements. There is no explicit ratio — it's "fixed top + flex bottom."

## Adventure Log

```python
log_outer.pack(fill=tk.BOTH, expand=True, side=tk.BOTTOM)
log_frame.pack(fill=tk.BOTH, expand=True)
log_text.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)
```

- Font: `Consolas, scale_font(10)` (roughly 10-14px depending on resolution)
- Word wrap: `wrap=WORD`
- Padding: `padx=8, pady=8` inside Text widget; `padx=4, pady=4` on pack
- Line spacing: `spacing1=2, spacing3=4`

## Sidebar (Right Column)

```python
right_frame.pack(side=tk.RIGHT, fill=tk.Y, padx=5, pady=5)
```

- `fill=Y` only (no horizontal expand) — width from content
- Minimap canvas: fixed `180x180` pixels
- Effective width: ~200px (canvas + padding)
- Fills available height

## Godot Equivalent

| Python                    | Godot                                          |
|---------------------------|-------------------------------------------------|
| `fill=BOTH, expand=True`  | `size_flags = SIZE_EXPAND_FILL`                |
| `fill=X`                  | `size_flags_horizontal = SIZE_EXPAND_FILL`     |
| `fill=Y`                  | `size_flags_vertical = SIZE_EXPAND_FILL`       |
| Pack order (top then bottom) | VBoxContainer child order + stretch_ratio    |
| Fixed-height top panels   | No SIZE_EXPAND_FILL (natural shrink-wrap)      |
| Flex bottom (log)         | `size_flags_vertical = SIZE_EXPAND_FILL`       |

Recommended Godot layout:

```
RootVBox
├── TopBar (shrink)
├── MiddleHBox (expand, ratio=1.0)
│   ├── CenterPanel (expand horizontal, ratio=3.0)
│   └── Sidebar (fixed 220px width, expand vertical)
└── LogPanel (expand, ratio=0.7)
```

The log panel uses `SIZE_EXPAND_FILL` with `stretch_ratio=0.7` relative to the
middle content area's `1.0`, giving the log roughly 40% of vertical space.
