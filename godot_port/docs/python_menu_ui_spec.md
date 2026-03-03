# Python Menu UI Spec

Concrete layout and styling rules derived from the Python (Tkinter) source
for each target popup menu. Used as reference for Godot UI parity.

---

## 1. Inventory (`explorer/inventory_display.py`)

### Sections (top to bottom)
1. **Slots counter**: "Slots: X/Y" — top-left, Arial 10pt bold
2. **Title**: "INVENTORY" — centered, Arial 18pt bold, gold `#ffd700`
3. **Red X close**: top-right, `#ff4444` / hover `#ff0000`
4. **Equipment summary**: Weapon/Armor/Accessory/Backpack with name + durability
5. **Hint**: "(Hover over items for details)" — Arial 8pt italic, gray
6. **Scrollable item list**: Each row shows icon + name + ×count + [EQUIPPED] + [X%]
7. **Action buttons**: context-sensitive per selected item type

### Per-item row format
`[icon] Item Name ×2 [EQUIPPED] [85%]`

### Button colors (Python)
| Button | Color |
|--------|-------|
| Equip | `#4ecdc4` (cyan) |
| Unequip | `#f39c12` (orange) |
| Use | `#9b59b6` (purple) |
| Read | `#d4a574` (tan) |
| Drop | `#ff6b6b` (red) |
| Drop disabled | `#666666` |

### Button visibility rules
- Drop: always shown, disabled for equipped items
- Equip: shown for equipment not currently equipped
- Unequip: shown for equipped items
- Use: shown for consumables (heal/buff/shield/cleanse/token/tool/repair)
- Read: shown for lore/readable_lore items

### Spacing
- `padx=10`, `pady=10` around content
- Items: `pady=2`, `padx=5`
- Scrollbar width: 10px

---

## 2. Character Status (`explorer/ui_character_menu.py`)

### Dialog size: 75% × 90% of window

### Three tabs: Character | Game Stats | Lore Codex

### Character tab sections
1. **◊ EQUIPPED GEAR** (cyan header, Arial 14pt bold)
   - Weapon, Armor, Accessory, Backpack — each with name, effects, durability
2. **⚔ CHARACTER STATS** (red header)
   - Health, Dice Pool, Base Damage Bonus, Damage Multiplier, Crit Chance,
     Healing Bonus, Bonus Rerolls, Armor, Floor
3. **✨ ACTIVE EFFECTS** (purple header)
   - Shield, Shop Discount, Statuses, Tokens, Temp combat bonuses
4. **◇ RESOURCES** (gold header)
   - Gold, Inventory capacity

### Game Stats tab sections
- ⚔ Combat, ◇ Economy, 🎒 Items, 🗺 Exploration, 📜 Lore

### Fonts
- Section headers: Arial 14pt bold with colored prefix symbol
- Stat labels: Arial 10pt
- Stat values: Arial 10pt bold, cyan

### Scrolling
- Each tab has its own Canvas + Scrollbar

---

## 3. Save/Load (`dice_dungeon_explorer.py` `show_unified_save_load_menu`)

### Dialog size: 85% × 90% of window

### Two-panel layout
- **Left panel** (~380px, 40%): scrollable slot list with 10 entries
- **Right panel** (expand, 60%): detail view for selected slot

### Slot item format (occupied)
```
Save N: [name]          (Arial 10pt bold, gold)
Floor X — The Depths    (Consolas 8pt, cyan)
HP: X/Y | Gold: Z      (Consolas 8pt, white)
2024-01-15 14:30        (Consolas 7pt, gray)
```

### Detail panel (occupied slot)
1. "Save Slot N" — Arial 16pt bold, gold
2. Save name, location, HP/gold/score
3. Last saved timestamp
4. Rename section: label + Entry (35 chars) + Rename button
5. Action buttons: Load | Save/Overwrite | Delete

### Colors
- Selected slot: `#5d3425`
- Unselected slot: `#3d2415`
- Save button: `#ff9f43` (orange)
- Load button: `#4ecdc4` (cyan)
- Delete button: `#ff6b6b` (red)
- Rename button: `#ffd700` (gold)

### Gating
- Save disabled during combat with "Cannot Save During Combat" text

---

## 4. Lore Codex (embedded in Character Status `_populate_lore_tab`)

### Split layout
- **Left**: scrollable list of discovered entries with category tags
- **Right**: full lore text with title, subtitle, floor discovered

### Toolbar
- Category filter dropdown
- Search text field

### Entry list format
`Title #uid  [Category]`

### Detail pane
1. Title + uid
2. Subtitle
3. Floor discovered
4. Separator
5. Full content text (RichTextLabel / scrollable)

---

## 5. Pause Menu (no Python equivalent)

The Python game has no pause menu. The Godot pause menu is a new feature with:
- Resume (green)
- Settings (cyan)
- Quit to Main Menu (red) with confirmation dialog

---

## Cross-cutting conventions

### Red X close button
- Top-right corner, `#ff4444`, hover `#ff0000`
- All dialogs use this pattern

### Typography hierarchy
| Level | Python | Godot equivalent |
|-------|--------|-----------------|
| Dialog title | Arial 16-18pt bold | FONT_SUBHEADING (16) in title bar |
| Section header | Arial 14pt bold | BBCode `[b]` with color |
| Body text | Arial 10pt | FONT_BODY (13) |
| Small/hint | Arial 8pt | FONT_SMALL (11) |
| Button text | Arial 9-13pt bold | FONT_BUTTON (13) |

### Spacing
- Dialog padding: 10-16px all around
- Section gap: 8-12px
- Element gap: 4-6px
- Button row gap: 6px

### Scrolling
- Lists use Canvas + Scrollbar in Python
- Godot: ItemList has built-in scroll; long content uses ScrollContainer
