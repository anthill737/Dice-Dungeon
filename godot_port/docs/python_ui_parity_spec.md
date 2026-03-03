# Python UI Parity Spec

Reference document derived from the Python (Tkinter) source for Dice Dungeon
Adventure Mode. Covers the four screens being ported to Godot:
Combat, Save/Load, Character Status, and Inventory.

---

## 1. Combat Screen

### Hierarchy (Adventure Mode)

```
action_panel
└─ action_inner (Frame)
   ├─ player_frame (LEFT, ~140px)
   │  ├─ "Player" label (Arial 9pt bold, cyan)
   │  └─ player_sprite_box (110×110, hidden during combat)
   ├─ vs_frame (CENTER, expand)
   │  └─ dice_section
   │     ├─ rolls_label ("Rolls Remaining: X/Y", bold cyan)
   │     ├─ damage_preview_label (gold)
   │     ├─ dice_frame (grid of clickable dice canvases, 72×72)
   │     └─ combat_buttons_frame
   │        ├─ Roll Dice button
   │        ├─ Mystic Ring button (if equipped)
   │        └─ ATTACK! button
   └─ enemy_column (RIGHT, ~160px)
      ├─ enemy_name label (Arial 9pt bold, red)
      ├─ enemy_hp_frame (Canvas HP bar, gradient fill)
      └─ enemy_sprite container
```

### Element ordering (top to bottom within dice_section)

1. Rolls remaining counter (bold, cyan)
2. Damage preview (gold text)
3. Dice row (horizontal, 72×72 canvases, clickable for lock toggle)
4. Combat buttons row: Roll Dice │ Mystic Ring │ ATTACK!
5. Target selection (if multi-enemy): label + target buttons

### Fonts

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Rolls remaining | Arial | 10pt | bold |
| Damage preview | Arial | 9pt | normal |
| Dice face | (canvas) | — | — |
| Button text | Arial | 9–13pt | bold |
| Enemy name | Arial | 9pt | bold |

### Colors

| Element | Color | Hex |
|---------|-------|-----|
| Attack button | red | `#e74c3c` |
| Flee button | orange | `#f39c12` |
| Roll Dice button | cyan | `#4ecdc4` |
| Attack disabled bg | dark gray | `#666666` / `#333333` |
| Flee disabled | gray | `#999999` / `#555555` |
| Selected target | light red | `#ff6b6b` |
| Unselected target | dark red | `#8b0000` |
| Mystic Ring | purple | `#9b59b6` |
| Mystic Ring used | dark gray | `#555555` |
| HP bar >60% | green | via `hp_full` |
| HP bar 30–60% | yellow | via `hp_mid` |
| HP bar <30% | red | via `hp_low` |

### Button states

- **Roll Dice**: disabled when `rolls_left == 0` or during attack animation
- **ATTACK!**: disabled until at least one die has a value; disabled during attack
- **Flee**: hidden in boss fights; disabled during attack animation
- **Mystic Ring**: disabled after use (`mystic_ring_used`), text changes to "◊ Used"
- **Lock (per die)**: toggle; border changes to gold when locked

### Scrolling / Log

- Adventure log (separate pane) scrolls with mousewheel
- Combat panel itself is not scrollable

### HP Bar

- Canvas-based, gradient fill
- Color thresholds: green (>60%), yellow (30–60%), red (<30%)
- Shows `HP: X/Y (Z%)` text

---

## 2. Save / Load Screen

### Hierarchy

```
dialog_frame (85–90% of window, centered)
├─ Title ("💾 SAVE GAME 💾" or "📂 LOAD GAME 📂", Arial 18pt bold)
├─ Red X close button (top-right, #ff4444, hover #ff0000)
├─ content_frame
│  ├─ left_panel (width ~380px, SUNKEN border)
│  │  ├─ "Save Slots" header
│  │  ├─ list_canvas + scrollbar (10 slot entries)
│  │  └─ slots_list_frame
│  └─ details_container (SUNKEN, expand)
│     ├─ details_canvas + scrollbar
│     └─ details_panel (selected slot info)
```

### Slot item layout (occupied)

1. "Save N: [name]" — Arial 10pt bold, gold
2. "Floor X — The Depths" — Consolas 8pt, cyan
3. "HP: X/Y | Gold: Z" — Consolas 8pt, white
4. Timestamp — Consolas 7pt, gray

### Details panel (occupied slot)

1. "Save Slot N" — Arial 16pt bold, gold
2. Save name
3. Current location
4. Character stats (HP, gold, score)
5. Last saved timestamp
6. Rename section: label, Entry (35 chars), Rename button
7. Action buttons: Load │ Save/Overwrite │ Delete

### Colors

| Element | Color |
|---------|-------|
| Selected slot bg | `#5d3425` |
| Unselected slot bg | `#3d2415` |
| Save mode btn | `#ff9f43` |
| Load mode btn | `#3a9b93` / `#4ecdc4` |
| Delete btn | `#ff6b6b` |
| Rename btn | `#ffd700` |
| Disabled (combat) | `#8B0000` |
| Disabled (no game) | `#666666` |

### Button states

- **Save/Overwrite**: disabled during combat (`in_combat`); shows "Cannot Save During Combat"
- **Load**: enabled only for occupied slots
- **Delete**: enabled for occupied slots
- **Rename**: enabled when slot occupied

### Hotkeys

- Up/Down: change slot
- Enter: Load or Save
- Delete: delete slot
- F2: focus rename entry
- Escape: close dialog

### Two-panel layout

- Left: scrollable list of 10 slots
- Right: detail view for selected slot (stats, rename, action buttons)

---

## 3. Character Status Screen

### Hierarchy

```
dialog_frame (75% × 90% of window)
├─ title_bar
│  ├─ "CHARACTER STATUS" label (centered, Arial 16pt bold)
│  └─ Red X close (top-right)
├─ ttk.Notebook (tabs)
│  ├─ "Character" tab
│  │  └─ scrollable frame
│  │     ├─ "◊ EQUIPPED GEAR" section (cyan header, Arial 14pt bold)
│  │     │  └─ Equipment slots: Weapon, Armor, Accessory, Backpack
│  │     │     (each: icon, name, effects, durability)
│  │     ├─ "⚔ CHARACTER STATS" section (red header)
│  │     │  └─ Health, Dice Pool, Base Damage Bonus, Damage Multiplier,
│  │     │     Crit Chance, Healing Bonus, Bonus Rerolls
│  │     ├─ "✨ ACTIVE EFFECTS" section (purple header)
│  │     │  └─ Shield, Shop Discount, Accuracy Penalty, tokens, etc.
│  │     └─ "◇ RESOURCES" section (gold header)
│  │        └─ Gold, Inventory space, Rest cooldown
│  ├─ "Game Stats" tab
│  │  └─ Combat, Economy, Items, Equipment, Lore, Exploration sections
│  │     └─ Sortable codex lists (Items Collected, Enemies Defeated)
│  └─ "Lore Codex" tab
│     └─ Collapsible lore categories with Read buttons
```

### Character tab sections (top to bottom)

1. **Equipped Gear** — cyan header "◊ EQUIPPED GEAR"
   - Weapon, Armor, Accessory, Backpack (each with name, effects, durability)
2. **Character Stats** — red header "⚔ CHARACTER STATS"
   - Health, Dice Pool, Base Damage Bonus, Damage Multiplier, Crit Chance, Healing Bonus, Bonus Rerolls
3. **Active Effects** — purple header "✨ ACTIVE EFFECTS"
   - Shield, Shop Discount, Accuracy Penalty, tokens, temporary effects, status conditions
4. **Resources** — gold header "◇ RESOURCES"
   - Gold, Inventory capacity, Rest cooldown

### Fonts

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Dialog title | Arial | 16pt | bold |
| Section headers | Arial | 14pt | bold |
| Stat labels | Arial | 10pt | normal |
| Stat values | Arial | 10pt | bold |

### Colors

- Section headers: cyan (gear), red (stats), purple (effects), gold (resources)
- Stat values: cyan
- Rest cooldown: green (ready), red (cooling down)
- Tooltip bg: `#ffffe0`, Arial 9pt

### Tabs

Three tabs: Character, Game Stats, Lore Codex

### Scrolling

- Each tab has its own Canvas + Scrollbar
- Mousewheel-based scrolling

### Tooltips

- Hover over stats: shows breakdown (base, permanent, equipment bonuses)

---

## 4. Inventory Screen

### Hierarchy

```
dialog_frame (45% × 75% of window)
├─ slots_frame (top-left): "Slots: X/Y" (Arial 10pt bold)
├─ Red X close (top-right)
├─ "INVENTORY" title (centered, Arial 18pt bold, gold)
├─ Boss Key Fragments (if present, with ★/☆ symbols)
├─ "(Hover over items for details)" hint (Arial 8pt italic)
└─ list_container (Canvas + Scrollbar)
   └─ inv_frame
      └─ item_frame (per item)
         ├─ icon (optional)
         ├─ item_label (name, ×count, [EQUIPPED], [X%] durability)
         └─ button_container
            ├─ Equip / Unequip
            ├─ Use / Read
            └─ Drop
```

### Per-item row

1. Icon (if available)
2. Item name + count (e.g. `×2`) + `[EQUIPPED]` tag + `[X%]` durability
3. Action buttons: Equip/Unequip │ Use/Read │ Drop

### Fonts

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Title | Arial | 18pt | bold |
| Slots counter | Arial | 10pt | bold |
| Item names | Arial | 10pt | normal |
| Boss Key label | Arial | 10pt | bold |
| Hint text | Arial | 8pt | italic |

### Colors

| Element | Color | Hex |
|---------|-------|-----|
| Title | gold | `#ffd700` |
| Background | dark brown | `#1a0f08` / `#2c1810` / `#3d2415` |
| Equip button | cyan | `#4ecdc4` |
| Unequip button | orange | `#f39c12` |
| Use button | purple | `#9b59b6` |
| Read button | tan | `#d4a574` |
| Drop button | red | `#ff6b6b` |
| Drop disabled | gray | `#666666` |
| Boss Key complete | gold | `#ffd700` |
| Boss Key incomplete | white | `#ffffff` |
| Empty text | gray | `#666666` |

### Button states

- **Drop**: disabled for equipped items
- **Equip**: shown only for equipment-type items
- **Unequip**: shown only when item is currently equipped
- **Use**: shown for consumables (heal, buff, shield, cleanse, token, tool, repair)
- **Read**: shown for lore items

### Scrolling

- Mousewheel on item list
- Scrollbar width 10px

### Equipment summary

- Shown above item list
- Lists: Weapon, Armor, Accessory, Backpack slots with equipped item names

---

## Cross-cutting Conventions

### Red X close button

All dialogs (Save/Load, Character Status, Inventory, Store) use a top-right red "X" close button:
- Color: `#ff4444`, hover: `#ff0000`
- Cursor changes to hand

### Scaling

- `scale_font(base)` → `base × scale_factor × 1.15`
- `scale_padding(base)` → `base × scale_factor`
- `get_responsive_dialog_size()` for dialog dimensions
- `get_scaled_wraplength()` for text wrap

### Mousewheel scrolling

- `setup_mousewheel_scrolling(canvas)` with `event.delta/120`
- Propagated to children via `bind_mousewheel_to_tree`

### Color schemes

Defined in `explorer/color_schemes.py` (Classic, Dark, Light, Neon, Forest):
- Keys: `bg_*`, `text_*`, `button_*`, `hp_*`, `border_*`
- Default scheme: Classic (dark brown tones)
