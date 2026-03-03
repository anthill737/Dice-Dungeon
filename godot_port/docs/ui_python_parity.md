# UI Python Parity Reference

What the Python (Tkinter) game does for each menu, and how the Godot port matches it.

## Inventory (Python: `explorer/inventory_display.py`)

- Dialog: 45%×75% of window (base 450×500)
- Slots counter "Slots: X/Y" top-left
- Equipment summary: Weapon/Armor/Accessory/Backpack with durability
- Scrollable item list: name + ×count + [EQUIPPED] + [X%]
- Context-sensitive buttons: Use (green), Read (blue), Equip (cyan), Unequip (orange #f39c12), Drop (red, disabled for equipped)
- Godot: matches layout, uses ItemList with tooltips

## Character Status (Python: `explorer/ui_character_menu.py`)

- Dialog: 75%×90% of window (base 700×700)
- Three tabs: Character, Game Stats, Lore Codex
- Character tab sections with colored headers: ◊ EQUIPPED GEAR (cyan), ⚔ CHARACTER STATS (red), ✨ ACTIVE EFFECTS (purple), ◇ RESOURCES (gold)
- Game Stats: Combat / Economy / Items / Exploration / Lore sections
- Godot: matches sections, tabs, headers via BBCode RichTextLabel

## Save/Load (Python: `dice_dungeon_explorer.py` `show_unified_save_load_menu`)

- Dialog: 85%×90% (base 950×700)
- Two-panel: left slot list (40%), right detail view (60%)
- Per-slot: name, floor, HP/gold, timestamp
- Buttons: Save/Load/Delete/Rename
- Save disabled during combat
- Godot: uses 70%×80% (base 700×550) — slightly smaller, otherwise matches

## Lore Codex (embedded in Character Status in Python)

- HSplitContainer: left entry list + right detail pane
- Category filter dropdown + search field
- Detail: title, subtitle, floor discovered, content
- Godot: matches layout, also available as standalone popup

## Pause Menu (no Python equivalent)

- Godot-only: Resume, Save/Load, Settings, Quit to Main Menu
- Quit shows inline confirm dialog

## Cross-cutting

| Convention | Python | Godot |
|-----------|--------|-------|
| Close button | Red X (#ff4444) top-right | Red ✕ via PopupFrame |
| Dialog sizing | `get_responsive_dialog_size()` | Same formula in PopupFrame._apply_sizing() |
| Centering | `place(relx=0.5, rely=0.5, anchor=CENTER)` | Anchor ratios centered |
| Dim overlay | None (Python uses raised frame) | 45% black dim behind popup |
| Scroll | Canvas+Scrollbar per region | ItemList / ScrollContainer |
