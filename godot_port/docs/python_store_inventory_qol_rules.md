# Python Store/Inventory QoL Rules — Authoritative Reference

Extracted from: `explorer/store.py`, `explorer/inventory_display.py`, `explorer/inventory_equipment.py`, `explorer/inventory_pickup.py`

## A) Buy/Sell Multiple — Quantity Selection

### Buy
- **Consumables** (non-upgrade, non-equipment) show a quantity slider when `max_quantity > 1`.
- `max_affordable = gold // price`
- `max_inventory_space = max_inventory - unequipped_inventory_count` (if item needs inventory space).
- `max_quantity = min(max_affordable, max_inventory_space)` for consumables; 1 for others.
- If `max_quantity > 1`: slider from 1 to `max_quantity`.
- Equipment and upgrades: always quantity 1.

### Sell
- When holding `item_count > 1` of an item: slider from 1 to `item_count`.
- Otherwise: single sell.
- Sell price: `max(5, buy_price // 2)`.
- Cannot sell equipped items (must unequip first).

### Pricing
- Buy: base price + `effective_floor * scaling` (per-item formula).
- Sell: 50% of buy price, minimum 5 gold.

## B) Search Behavior

- **Python has NO search/filter** in the inventory, store, or container UI.
- Filters exist only in the Lore Codex / Character Info panel, not for gameplay lists.
- The Godot port adds search as a **new QoL feature** — case-insensitive substring match on item name.

## C) Take All Behavior

### Ground items (non-container)
- `pickup_all_ground_items()` in `inventory_equipment.py`:
  - Takes: gold, `ground_items`, `uncollected_items`, `dropped_items`.
  - Does **NOT** auto-search containers.
  - Respects inventory capacity — stops if inventory full.

### Container contents
- `take_all_from_container()` in `inventory_pickup.py`:
  - Only shown when container has **2+ items** (gold + item).
  - Takes gold first, then item.
  - If inventory is full when trying to take the item, gold is still taken.

### Capacity rules
- `max_inventory` (default 10, can be increased by equipment).
- Equipment items occupy inventory slots.
- Equipped items count separately from inventory.
- If inventory is full: log "Inventory full! Cannot add [item_name]."

## D) Lockpick Workflow

### Python behavior (`explorer/inventory_pickup.py`)
1. Player enters room with a locked container.
2. Player clicks "Search container" on the locked container.
3. Python checks `container_locked`:
   - If locked: logs `"The {container_name} is locked! You need a Lockpick Kit to open it."` and returns.
4. Player must separately call `use_lockpick_on_container(container_name)`:
   - Checks if `"Lockpick Kit"` is in inventory.
   - If not: logs `"You don't have a Lockpick Kit!"` and returns.
   - If yes: removes one `"Lockpick Kit"` from inventory, sets `container_locked = False`.
   - Logs: `"Used Lockpick Kit! Container unlocked."`
5. Player can then search the container normally.

### Key rules
- Lockpick Kit is **consumed** on use (one kit per locked container).
- The lockpick is a direct action on the locked container — no "disarm token" intermediate step.
- If Python has a `disarm_token` mechanism, it is for a **different purpose** (trap disarming), not for locked containers.

### Messages (Python parity)
- Locked container: `"The {container_name} is locked! You need a Lockpick Kit to open it."`
- No lockpick: `"You don't have a Lockpick Kit!"`
- Success: `"Used Lockpick Kit! Container unlocked."`
