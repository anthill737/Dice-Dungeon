# Python Room Header Presentation Rules

Reference for how the Python UI renders the room title and flavor text in the
main game panel (not the adventure log).

## Source

`dice_dungeon_explorer.py` lines 2138-2165, updated by
`explorer/navigation.py` lines 341-342.

## Container

- Panel: `bg_room` (#2a1810), border `border_gold` (#b8932e), width=2,
  `relief=RIDGE`
- Inner padding: `padx=scale_padding(8)`, `pady=scale_padding(3)`
- Outer margin: `padx=scale_padding(3)`, `pady=(scale_padding(1),
  scale_padding(1))`
- Layout: `fill=X, side=TOP` (no vertical expand)

## Room Title

- Font: `Georgia, scale_font(12), bold`
- Color: `text_gold` (#d4af37)
- Alignment: centered (default for Tkinter Label)
- Padding: `pady=scale_padding(1)`
- Content: `room.data['name']` — used as-is from JSON (title case in data)

## Separator

- 1px horizontal line between title and flavor
- Color: `border_gold` (#b8932e)
- Full width: `fill=X`
- Padding: `pady=scale_padding(1)` above and below

## Room Flavor / Description

- Font: `Georgia, scale_font(9), italic`
- Color: `text_light` (#f5e6d3)
- Alignment: `justify=LEFT`
- Word wrap: `wraplength=get_scaled_wraplength(600)` (~70% of window width,
  min 500px)
- Padding: `pady=scale_padding(1)`
- Content: `room.data['flavor']` — used as-is from JSON

## Room-Type / Safe Indicator

Python does **not** show a "Safe" or room-type indicator in the room header
panel. Room type/difficulty and starter-room status are used in game logic
only — never displayed in this panel.

## Formatting Rules

1. Room name is shown as-is from `room.data['name']` (already title case in
   JSON)
2. Room flavor is shown as-is from `room.data['flavor']`
3. No "Entered:" or "Returned to:" prefix — those appear only in the
   adventure log
4. No emoji prefixes in the room header
5. Title is centered, description is left-aligned

## Godot Deviations (Pre-Fix)

| Aspect | Python | Godot (current) |
|--------|--------|-----------------|
| Title alignment | Centered | Left-aligned |
| Title font | Georgia 12pt bold | FONT_HEADING (20px) — too large |
| Flavor font | Georgia 9pt italic | FONT_LABEL (14px), not italic |
| Flavor color | text_light (#f5e6d3) | TEXT_BONE (lighter) |
| Safe indicator | Not shown | Shows "✓ Safe" / emoji flags |
| Separator | 1px gold line | 1px gold line (matches) |
