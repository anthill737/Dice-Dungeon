# UI Parity Summary

## What changed

### Combat Panel (`ui/scripts/combat_panel.gd`)
- Added player HP bar (`ProgressBar`) at top with label showing `HP/MaxHP`
- Added enemy HP bar (`ProgressBar`) below enemy list for selected enemy
- Added damage preview label (gold text, shows base + combo breakdown)
- Changed rolls label format to "Rolls Remaining: X/Y" (was "Rolls left: X")
- Increased dice cell size from 64×64 to 72×72 (matching Python's 72×72)
- Changed button colors to match Python: Roll Dice = cyan `#4ecdc4`, ATTACK! = red `#e74c3c`, Flee = orange `#f39c12`
- Renamed "Attack" button to "ATTACK!" matching Python
- Added target selection label for multi-enemy encounters
- Added enemy HP bar refresh on enemy list selection
- Named key nodes for test stability: `DiceContainer`, `DamagePreviewLabel`, `RollsLabel`, `PlayerHPBar`, `EnemyHPBar`, `CombatLog`, `EnemyList`

### Save/Load Panel (`ui/scripts/save_load_panel.gd`)
- Restructured from vertical layout to two-panel layout (left slot list + right detail view) matching Python
- Added detail panel with slot title, save info (name, floor, HP, gold, timestamp), rename field, and action buttons
- Added "Save Slots" header above slot list
- Added save-during-combat gating (Save button disabled when `is_combat_active()`)
- Simplified slot list items (just "Slot N: name") with full detail in right panel
- Slot selection now wires to detail panel refresh
- Added `max_length = 35` on rename LineEdit matching Python
- Named key nodes: `SlotList`, `DetailPanel`, `DetailTitle`, `DetailInfo`, `RenameEdit`, `BtnSave`, `BtnLoad`, `BtnDelete`, `BtnRename`

### Character Status Panel (`ui/scripts/character_status_panel.gd`)
- Added Python-matching section headers in Character tab: "◊ EQUIPPED GEAR" (cyan), "⚔ CHARACTER STATS" (red), "✨ ACTIVE EFFECTS" (purple), "◇ RESOURCES" (gold)
- Added Active Effects section showing shield, shop discount, statuses, tokens, temp combat bonuses
- Added Resources section grouping gold and inventory capacity
- Added Damage Multiplier and Healing Bonus stats
- Equipment display now shows item descriptions from items_db
- Categorized Game Stats tab into sections: Combat, Economy, Items, Exploration, Lore
- Renamed tabs from "Stats"/"Lore" to "Game Stats"/"Lore Codex" matching Python
- Named key nodes: `CharacterInfo`, `StatsInfo`

### Inventory Panel (`ui/scripts/inventory_panel.gd`)
- Added slots counter label at top-left showing "Slots: X/Y" matching Python
- Added per-item detail in list: count (×N), [EQUIPPED] tag, durability percentage
- Added item tooltips showing name, type, and description on hover
- Added context-sensitive button visibility: Use/Read/Equip/Unequip shown only when applicable for selected item type
- Drop button now disabled for equipped items matching Python
- Added hint label "(Select an item for details)"
- Changed Unequip button color to orange `#f39c12` matching Python
- Named key nodes: `SlotsLabel`, `EquipmentSummary`, `ItemList`, `HintLabel`, `BtnUse`, `BtnRead`, `BtnEquip`, `BtnUnequip`, `BtnDrop`

### Tests (`tests/test_ui_parity_nodes.gd`)
- 17 new GUT tests covering all 4 panels
- Tests verify headless instantiation, key node existence with stable names, button gating states, section content, and tab names

### Documentation (`docs/`)
- `python_ui_parity_spec.md`: Full reference spec from Python Tkinter source
- `ui_parity_gap_list.md`: Diff checklist of matches and gaps with changes needed
- `ui_parity_summary.md`: This file

## What's still intentionally different

| Area | Python | Godot | Reason |
|------|--------|-------|--------|
| Save/Load title | Separate "SAVE GAME" / "LOAD GAME" modes | Combined "SAVE / LOAD" | Single panel simplification; both actions available |
| Mystic Ring button | Conditional button in combat | Not implemented | Accessory mechanic not yet ported to combat engine |
| Per-enemy status text | Shows enemy statuses inline | Player statuses only | Enemy status data not exposed by CombatEngine |
| Item icons | Canvas icons per item | Text-only ItemList | No icon assets in Godot port |
| Read button color | Tan `#d4a574` | Blue `TEXT_BLUE` | Closer to dungeon palette |
| Hotkeys in Save/Load | Up/Down/Enter/Delete/F2/Esc | Escape only | Keyboard nav can be added later |
| Tooltips | Hover follow-cursor | Native Godot tooltip | Godot handles tooltip positioning |
| Scaling | Dynamic `scale_factor` | Fixed theme constants | Godot handles DPI via stretch settings |
| Boss Key Fragments | ★/☆ display in inventory | Not implemented | Boss key mechanic not yet fully ported |

## UI parity notes

- All UI changes are pure view/controller. No combat logic, RNG calls, or game state mutations were added.
- The `refresh()` methods only read from `GameSession.game_state` and `GameSession.combat`.
- No new signals were added that could alter execution order.
- HP bar styling uses the existing `DungeonTheme.style_hp_bar()` with green/yellow/red thresholds matching Python.
- No Python source files were modified.
