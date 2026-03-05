# Python Durability Rules

Extracted from: `dice_dungeon_explorer.py`, `explorer/combat.py`, `explorer/inventory_usage.py`, `explorer/inventory_equipment.py`, `dice_dungeon_content/data/items_definitions.json`

## Durability Storage
- `equipment_durability` dict: `{item_name: current_durability}`
- Default max durability if missing from item def: 100
- Stored in GameState, persisted in save files.

## Degradation Triggers and Amounts

### Weapon (on player attack)
- Location: `explorer/combat.py` lines 1692–1693 and 2863–2864
- Trigger: every time the player performs an attack action
- Amount: **3** durability per attack
- Call: `self.game._damage_equipment_durability("weapon", 3)`

### Armor (on taking damage)
- Location: `explorer/combat.py` lines 2575–2576, 2681, 2729
- Trigger: every time the player takes damage from an enemy attack
- Amount: **5** durability per hit taken
- Call: `self.game._damage_equipment_durability("armor", 5)`

## Break Rules
From `_damage_equipment_durability()` (lines 3317–3379):

1. Reduce durability by the given amount.
2. Low durability warning at `current_dur <= 20` and `current_dur > 0`.
3. When `current_dur <= 0`:
   - Item becomes `"Broken {item_name}"`
   - Stats updated: `weapons_broken` or `armor_broken`
   - Bonuses removed, item unequipped
   - Inventory entry replaced with broken version
   - New `broken_equipment` definition created if needed
   - Removed from `equipment_durability`
   - Broken item kept for repair or sale

## Repair Kits (from items_definitions.json)
- **Weapon Repair Kit**: `repair_type: "weapon"`, `repair_percent: 0.40` (40%)
- **Armor Repair Kit**: `repair_type: "armor"`, `repair_percent: 0.40` (40%)
- **Master Repair Kit**: `repair_type: "any"`, `repair_percent: 0.60` (60%) — Floor 5+

## Repair Logic (inventory_usage.py)
- **Broken items**: `restored_dur = int(max_dur * repair_percent)`
- **Damaged (non-broken) items**: `new_dur = min(current_dur + int(max_dur * repair_percent), max_dur)`
- Default `max_durability` if not in definition: 100

## Dev Multiplier
- `dev_config["durability_loss_mult"]` scales durability loss (default 1.0).

## Constants Summary
| Constant | Value |
|----------|-------|
| WEAPON_DEGRADE_AMOUNT | 3 |
| ARMOR_DEGRADE_AMOUNT | 5 |
| LOW_DURABILITY_THRESHOLD | 20 |
| DEFAULT_MAX_DURABILITY | 100 |
| WEAPON_REPAIR_PERCENT | 0.40 |
| ARMOR_REPAIR_PERCENT | 0.40 |
| MASTER_REPAIR_PERCENT | 0.60 |
