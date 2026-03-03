# UI Parity Gap List

Checklist comparing current Godot UI to the Python reference for each screen.
`[✓]` = matches, `[✗]` = gap, `[~]` = partial / intentional deviation.

---

## 1. Combat Panel

### What matches
- [✓] Title "⚔ COMBAT ⚔" header
- [✓] Enemy list (ItemList) showing name + HP + percentage
- [✓] 5 dice panels with lock toggle buttons
- [✓] Roll / Attack / Flee button row
- [✓] Combat log (RichTextLabel, scroll-following)
- [✓] Lock button toggles border color (gold when locked)
- [✓] Rolls-left label
- [✓] Victory / Defeat result labels
- [✓] Close/Flee visibility gating (pending vs active vs over)

### Gaps — exact changes needed
- [✗] **Missing HP bar for enemies**: Python shows a gradient-filled HP bar per enemy. Godot only shows text in ItemList. → Add a `ProgressBar` per-enemy or show an HP bar section below the enemy list for the selected enemy.
- [✗] **Missing damage preview**: Python shows gold text "Damage Preview: X" above dice. → Add `_damage_preview_label` (Label, gold, FONT_BODY) between rolls_label and dice row.
- [✗] **Missing status effects on enemies**: Python shows per-enemy statuses. Godot shows player statuses only. → Append enemy status text to enemy list items.
- [✗] **Rolls label text format**: Python says "Rolls Remaining: X/Y" (current/max). Godot says "Rolls left: X". → Change to "Rolls Remaining: X/Y".
- [✗] **Button colors don't match Python**: Python uses `#e74c3c` (red) for Attack, `#f39c12` (orange) for Flee, `#4ecdc4` (cyan) for Roll. Godot uses `COMBAT_ACCENT` (red) for Attack, `TEXT_CYAN` for Flee, `TEXT_GOLD` for Roll. → Change Roll to `TEXT_CYAN`, Flee to dedicated orange color.
- [✗] **Missing Mystic Ring button**: Python shows a Mystic Ring button when accessory is equipped. → Add conditional `_btn_mystic_ring` (purple accent).
- [✗] **Missing target selection for multi-enemy**: Python shows explicit target buttons per enemy. Godot uses ItemList selection (functional but not visually matching). → Keep ItemList selection but add visual highlight and "Select Target" label.
- [✗] **Dice cell size**: Python uses 72×72. Godot uses 64×64 (`DICE_CELL_SIZE`). → Update to 72.
- [✗] **No player HP display in combat panel**: Python shows player HP/frame. → Add player HP label/bar at top.

### Node name stability needed
- `DiceContainer` (HBoxContainer holding dice)
- `DamagePreviewLabel`
- `RollsLabel`
- `PlayerHPBar`
- `EnemyHPBar`
- `CombatLog`

---

## 2. Save / Load Panel

### What matches
- [✓] Title "💾 SAVE / LOAD"
- [✓] Close button (top-right)
- [✓] Slot list (ItemList) with 10 slots
- [✓] Save / Load / Delete / Rename buttons
- [✓] Rename line edit
- [✓] Info label for status messages

### Gaps — exact changes needed
- [✗] **Missing two-panel layout**: Python has left panel (slot list) + right panel (detail view). Godot stacks everything vertically. → Restructure with `HSplitContainer` or `HBoxContainer`: left = slot list, right = detail panel.
- [✗] **Missing detail panel**: Python shows detailed slot info (save name, floor, HP, gold, score, timestamp) in a right panel. → Add `_detail_panel` VBoxContainer with labels for each field.
- [✗] **Slot item text formatting**: Python uses multi-line per slot (name, floor, HP/gold, timestamp). Godot uses single-line. → Enhance slot display with richer text or use custom drawing.
- [✗] **Missing save-during-combat gating**: Python disables Save when `in_combat`. → Add `_btn_save.disabled = GameSession.is_combat_active()` in refresh.
- [✗] **Slot selection not wired to detail refresh**: → Connect `_slot_list.item_selected` to `_refresh_detail()`.
- [✗] **Missing hotkeys**: Python supports Up/Down/Enter/Delete/F2/Escape. → Add `_unhandled_input` for keyboard navigation.
- [✗] **Title doesn't reflect mode**: Python shows "💾 SAVE GAME 💾" vs "📂 LOAD GAME 📂". Godot always says "💾 SAVE / LOAD". → Keep combined title (intentional simplification).

### Node name stability needed
- `SlotList`
- `DetailPanel`
- `DetailTitle`
- `DetailInfo`
- `RenameEdit`
- `BtnSave`
- `BtnLoad`
- `BtnDelete`
- `BtnRename`

---

## 3. Character Status Panel

### What matches
- [✓] Title "⚙ CHARACTER STATUS"
- [✓] Close button (top-right)
- [✓] Three tabs via TabContainer: Character, Stats, Lore
- [✓] Character tab shows health, gold, floor, dice, damage bonus, crit, reroll, armor, equipment, inventory
- [✓] Stats tab shows game statistics
- [✓] Lore tab embeds LoreCodexPanel

### Gaps — exact changes needed
- [✗] **Character tab lacks section headers**: Python has colored section headers ("◊ EQUIPPED GEAR", "⚔ CHARACTER STATS", "✨ ACTIVE EFFECTS", "◇ RESOURCES"). Godot renders everything as a flat BBCode list. → Add section headers with colored formatting.
- [✗] **Missing Active Effects section**: Python shows shield, shop discount, accuracy penalty, tokens, temp effects, statuses. Godot doesn't show effects. → Add effects section in `_refresh_character()`.
- [✗] **Missing Resources section**: Python shows gold, inventory capacity, rest cooldown. Godot shows these inline without section grouping. → Group under "◇ RESOURCES" header.
- [✗] **Equipment display lacks detail**: Python shows per-slot with icon, effects, durability bar. Godot shows name + durability % only. → Add item effects/descriptions from items_db.
- [✗] **Stats tab lacks categorization**: Python groups stats under Combat, Economy, Items, Equipment, Lore, Exploration. Godot shows a flat list. → Add section headers with separators.
- [✗] **Missing stat: Damage Multiplier**: Python shows it. → Add from `gs.damage_multiplier` if available.
- [✗] **Missing stat: Healing Bonus**: Python shows it. → Add from `gs.healing_bonus` if available.
- [✗] **Char info not scrollable**: Python uses Canvas+Scrollbar. Godot uses RichTextLabel (has built-in scroll). → Already works, no change needed.
- [~] **Tab names**: Python uses "Character", "Game Stats", "Lore Codex". Godot uses "Character", "Stats", "Lore". → Rename tabs to match.

### Node name stability needed
- `StatusTabs` (already named)
- `CharacterInfo`
- `StatsInfo`

---

## 4. Inventory Panel

### What matches
- [✓] Title "🎒 INVENTORY"
- [✓] Close button (top-right)
- [✓] Equipment summary (RichTextLabel)
- [✓] Item list (ItemList)
- [✓] Action buttons: Use, Read, Equip, Unequip, Drop
- [✓] Lore popup overlay

### Gaps — exact changes needed
- [✗] **Missing slots counter**: Python shows "Slots: X/Y" at top-left. Godot shows it in `_info_label` at bottom only when no effects active. → Add dedicated `_slots_label` at top.
- [✗] **Missing per-item detail**: Python shows count (×N), [EQUIPPED] tag, durability % in item text. Godot shows raw item name only. → Enhance item text in `refresh()`.
- [✗] **Missing item tooltip on hover**: Python shows detailed tooltip (name, type, desc, bonuses). → Add tooltip text via `_item_list.set_item_tooltip()`.
- [✗] **Button visibility not context-sensitive**: Python shows/hides buttons per item type (Use only for consumables, Read only for lore, Equip only for equipment). Godot shows all buttons always. → Update button visibility on item selection.
- [✗] **Drop disabled for equipped**: Python disables Drop for equipped items. → Gate `_btn_drop.disabled` when selected item is equipped.
- [✗] **Missing hint text**: Python shows "(Hover over items for details)" in italic. → Add small hint label.
- [✗] **Missing Boss Key Fragments**: Python shows boss key fragment progress (★/☆). → Add conditional boss key display.
- [✗] **Button color mismatch**: Python uses orange `#f39c12` for Unequip; Godot uses `TEXT_SECONDARY`. → Use orange accent for Unequip.
- [~] **Read button color**: Python uses tan `#d4a574`; Godot uses `TEXT_BLUE`. → Keep `TEXT_BLUE` (close enough in dungeon palette).

### Node name stability needed
- `SlotsLabel`
- `EquipmentSummary`
- `ItemList`
- `HintLabel`
- `BtnUse`
- `BtnRead`
- `BtnEquip`
- `BtnUnequip`
- `BtnDrop`
