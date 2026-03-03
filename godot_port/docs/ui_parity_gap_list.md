# UI Parity Gap List

What matches Python, what differs intentionally, and what remains.
`[✓]` match  `[~]` intentional difference  `[✗]` gap (not yet addressed)

## PopupFrame Wrapper
- [✓] Per-menu responsive sizing (Python formula)
- [✓] Centered via anchor ratios
- [✓] Red ✕ close button top-right
- [✓] Title bar with gold label
- [~] Dim overlay (Python uses raised frame border instead)

## Inventory
- [✓] Slots counter, equipment summary, item list, tooltips
- [✓] Context-sensitive buttons (Use/Read/Equip/Unequip/Drop)
- [✓] Drop disabled for equipped items
- [~] No per-item icons (no image assets)
- [~] Uses ItemList instead of per-item Frame widgets

## Character Status
- [✓] Three tabs: Character, Game Stats, Lore Codex
- [✓] Section headers with colored prefixes
- [✓] Active Effects, Resources sections
- [✓] ScrollContainer per tab for long content
- [~] No hover tooltips on stat labels (Python shows breakdowns)

## Save/Load
- [✓] Two-panel layout (slot list + detail)
- [✓] Detail shows name, floor, HP, gold, timestamp
- [✓] Save disabled during combat
- [~] Combined Save/Load mode (Python has separate mode titles)
- [~] Slightly smaller sizing than Python (70% vs 85%)

## Combat
- [✓] Player/enemy HP bars, damage preview, dice, rolls label
- [✓] Lock toggle, button gating, combat log
- [✓] Close blocked during pending/active
- [~] No Mystic Ring button (not ported)
- [~] No per-item icons on enemies

## Lore Codex
- [✓] HSplit: entry list + detail pane
- [✓] Category filter + search
- [~] No collapsible categories (Python uses expand/collapse)

## Pause Menu
- [✓] Resume, Save/Load, Settings, Quit to Main Menu
- [✓] Quit confirmation dialog
- [~] No Python equivalent (Godot-only feature)
