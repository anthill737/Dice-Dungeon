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

### Python behavior — explicit "Use Lockpick" button, NOT auto-use

Source: `explorer/inventory_display.py` lines 372-397, `explorer/inventory_pickup.py` lines 23-43.

Python presents a **two-step** interaction for locked containers. It does NOT auto-use the lockpick.

#### Step 1: Encounter locked container
When the player opens the ground items dialog (`show_ground_items`), a locked container is displayed with:
- "🔒 LOCKED" label
- If player has Lockpick Kit: a **"Use Lockpick" button** (line 382)
- If player lacks Lockpick Kit: "Need Lockpick Kit" label (line 387)

The player must **explicitly click "Use Lockpick"** to consume the kit.

#### Step 2: Lockpick consumption
`use_lockpick_on_container(container_name)` (inventory_pickup.py line 23):
1. Checks `"Lockpick Kit" not in self.game.inventory` → logs `"You don't have a Lockpick Kit!"`, returns.
2. Removes one `"Lockpick Kit"` from inventory.
3. Sets `self.game.current_room.container_locked = False`.
4. Logs: `"🔓 Used Lockpick Kit! The {container_name} is now unlocked."` (success tag).
5. Refreshes ground items dialog — container now shows "Search" button.

#### Step 3: Search
Player clicks "Search" on the now-unlocked container → `search_container()` runs normally.

### Key rules
- Lockpick Kit is consumed **only after explicit player click**, not on first interaction.
- No confirmation dialog — single click on "Use Lockpick" consumes it.
- The lockpick is a direct action on the locked container — no "disarm token" intermediate step.

### Messages (Python parity)
- Locked container (attempting search): `"The {container_name} is locked! You need a Lockpick Kit to open it."`
- No lockpick available: `"You don't have a Lockpick Kit!"`
- Lockpick used: `"🔓 Used Lockpick Kit! The {container_name} is now unlocked."`

### Godot parity status
The Godot port must NOT auto-use the lockpick. When the player clicks Ground Items and a locked container is found, the first interaction should show the locked message. A separate action (clicking Ground Items again, or a prompt) must let the player choose to use the lockpick.
