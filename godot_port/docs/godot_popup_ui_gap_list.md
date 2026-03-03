# Godot Popup UI Gap List

Comparison of current Godot popup menus vs Python spec.
`[✓]` = matches, `[✗]` = gap (fixed in this PR), `[~]` = intentional difference.

---

## PopupFrame (wrapper)

### Fixed in this PR
- [✗] **Sizing**: Was using fixed anchor percentages (5%-95%) instead of
  viewport-relative clamped sizing → now uses `clamp(vp*0.70, 900, vp*0.92)`
- [✗] **Centering**: Was anchor-based, not truly centered → now uses
  computed offsets for exact centering
- [✗] **Title font**: Was FONT_LABEL (14) → now FONT_SUBHEADING (16)
  matching Python dialog title size
- [✗] **Content padding**: Was 0 → now 12px left/right, 8px top, 12px bottom
  matching Python `padx=10, pady=10` convention
- [✗] **Title bar height**: Was implicit → now minimum 36px
- [✗] **Close button**: Was "X" text → now "✕" (Unicode, cleaner)
- [✗] **Separator**: Added gold separator line between title bar and content

### Matches
- [✓] Red X close button with hover state
- [✓] Dim background (55% black)
- [✓] Gold border around popup panel
- [✓] Closable toggle for combat panel

---

## Inventory

### Fixed in this PR
- [✗] **Removed duplicate header/close**: Panel had its own title bar +
  close button → removed (PopupFrame provides these)
- [✗] **Removed panel background**: Had opaque green-tinted bg → now transparent
  (PopupFrame provides the container)
- [✗] **Separator**: Added separator between equipment summary and item list

### Already matching
- [✓] Slots counter "Slots: X/Y" at top
- [✓] Equipment summary with slot names
- [✓] Hint text "(Select an item for details)"
- [✓] Scrollable item list with per-item detail
- [✓] Context-sensitive buttons (Use/Read/Equip/Unequip/Drop)
- [✓] Drop disabled for equipped items
- [✓] Item tooltips

### Intentional differences
- [~] No per-item icons (no image assets in Godot port)
- [~] Uses ItemList instead of per-item Frame widgets

---

## Character Status

### Fixed in this PR
- [✗] **Removed duplicate header/close**: Had own title + close → removed
- [✗] **Removed panel background**: Had opaque purple bg → transparent
- [✗] **ScrollContainer**: Added ScrollContainer wrapping each tab's
  RichTextLabel for long content

### Already matching
- [✓] Three tabs: Character, Game Stats, Lore Codex
- [✓] Section headers with colored prefixes (cyan/red/purple/gold)
- [✓] Full stat list with values
- [✓] Active Effects section
- [✓] Resources section
- [✓] Game Stats categorized (Combat/Economy/Items/Exploration/Lore)
- [✓] Embedded Lore Codex panel in third tab

---

## Save/Load

### Fixed in this PR
- [✗] **Removed duplicate header/close**: Had own title + close → removed
- [✗] **Removed panel background**: Had opaque blue bg → transparent
- [✗] **Split ratio**: Left was 0.45/0.55 → now 0.40/0.60 (closer to
  Python's ~380px / expand ratio)
- [✗] **Button widths**: Were 100px → now 90px (better fit in row)

### Already matching
- [✓] Two-panel layout (slot list + detail view)
- [✓] Detail panel with slot title, save info, timestamp
- [✓] Rename row with LineEdit
- [✓] Action buttons: Save/Load/Delete/Rename
- [✓] Save disabled during combat

---

## Lore Codex

### Fixed in this PR
- [✗] **Removed duplicate header/close**: Had "=== LORE CODEX ===" title +
  close button → removed (PopupFrame provides title)
- [✗] **Removed panel background**: Had opaque dark bg → transparent
- [✗] **Search field**: Added `SIZE_EXPAND_FILL` to search edit for
  proper toolbar layout

### Already matching
- [✓] HSplitContainer with left list + right detail
- [✓] Category filter dropdown
- [✓] Search field
- [✓] Entry list with category tags
- [✓] Detail pane with title/subtitle/floor/content
- [✓] No-entries placeholder text

---

## Pause Menu

### Fixed in this PR
- [✗] **Removed duplicate header**: Had "☰ PAUSED" title + separator → removed
- [✗] **Removed panel background**: Was opaque → transparent
- [✗] **Button sizing**: Width 200→220, height now 36px minimum

### Already matching
- [✓] Resume (green), Settings (cyan), Quit to Main Menu (red)
- [✓] Confirmation dialog for quit
- [✓] Vertically centered button layout
