# Python Inventory Rules — Authoritative Reference

Source files: `dice_dungeon_explorer.py`, `explorer/store.py`, `explorer/inventory_display.py`, `explorer/inventory_equipment.py`, `explorer/inventory_usage.py`, `explorer/inventory_pickup.py`

## Internal Storage Model

```python
self.inventory = []      # flat list of item-name strings
self.max_inventory = 10  # base capacity (expanded by backpack equipment)
```

- Each item is a **string entry** in a flat Python list.
- There are NO native stack objects, no `stack_count` field, no merging.
- Two copies of "Health Potion" are two separate `"Health Potion"` strings in the list.
- Capacity: `len(self.inventory)` checked against `max_inventory`.

## Display Stacking (UI Only)

### Inventory Panel (`explorer/inventory_display.py`)

```python
normalized_inventory = [item.split(' #')[0] if ' #' in item else item
                        for item in self.game.inventory]
item_counts = Counter(normalized_inventory)
processed_items = set()

for i, item in enumerate(self.game.inventory):
    normalized_item = item.split(' #')[0] if ' #' in item else item
    if normalized_item in processed_items:
        continue
    processed_items.add(normalized_item)
    count_text = f" x{item_counts[normalized_item]}" if item_counts[normalized_item] > 1 else ""
    # Display ONE row per unique item, showing count
```

**Rules:**
- Items are normalized: lore item suffixes (` #N`) are stripped for grouping.
- `Counter` counts occurrences of each normalized name.
- `processed_items` set ensures each unique item appears **once**.
- The first-occurrence index (`i`) is used for operations on that row.
- Count label: `" x3"` shown only when count > 1.

### Store Sell Tab (`explorer/store.py`)

```python
item_counts = Counter(self.game.inventory)
processed_items = set()

for idx, item_name in enumerate(self.game.inventory):
    if item_name in processed_items:
        continue
    processed_items.add(item_name)
    sell_price = self._calculate_sell_price(item_name)
    count = item_counts[item_name]
    self._create_store_item_row(..., item_name, sell_price, ..., item_count=count)
```

**Rules:**
- Same grouping pattern as inventory panel.
- One row per unique item with count.
- Sell confirmation shows quantity slider when `item_count > 1`.
- Sell calls `self.game.inventory.remove(item_name)` in a loop for quantity times.

## Adding Items

All adds use `self.inventory.append(item_name)`:

| Context | Code |
|---------|------|
| Pickup (generic) | `try_add_to_inventory(item_name, source)` → `self.inventory.append(item_name)` |
| Buy equipment | `self.game.inventory.append(item_name)` |
| Buy consumable | `for _ in range(quantity): self.game.inventory.append(item_name)` |
| Chest loot | `try_add_to_inventory(item_name)` → directly to inventory |

**No merging** — each add appends a new entry.

When inventory is full, `try_add_to_inventory` places the item in `room.uncollected_items`.

## Removing Items

| Context | Method |
|---------|--------|
| Use consumable | `self.inventory.pop(idx)` — by first-occurrence index |
| Drop | `self.inventory.pop(idx)` |
| Sell (store) | `self.game.inventory.remove(item_name)` — by value, in loop |
| Key/lockpick use | `self.inventory.remove("Item Name")` — by value |

## Selling Logic

```python
def _sell_item(self, item_idx, price, item_frame=None, quantity=1):
    item_name = self.game.inventory[item_idx]
    for _ in range(quantity):
        if item_name in self.game.inventory:
            self.game.inventory.remove(item_name)
    self.game.gold += price * quantity
```

- Removes `quantity` instances of the item by value (first occurrence each time).
- Gold gained = `price * quantity`.
- Equipped items cannot be sold if they're the last copy.

## Buying Logic

```python
for _ in range(quantity):
    self.game.inventory.append(item_name)
```

- Appends `quantity` instances of the item name.
- Upgrades/Extra Die don't go into inventory.

## Capacity Check

```python
def get_unequipped_inventory_count(self):
    equipped_item_names = [item for item in self.equipped_items.values() if item]
    unequipped_count = sum(1 for item in self.inventory if item not in equipped_item_names)
    return unequipped_count
```

- Store uses `get_unequipped_inventory_count()` — equipped items excluded.
- Generic pickup uses `len(self.inventory) < self.max_inventory`.

## Item Delivery

### Chest / Ground Pickup
Items go **directly to inventory** via `try_add_to_inventory()`.
If inventory is full, items go to `room.uncollected_items`.

### Mechanics Engine (room effects)
Items go to `game.ground_items` staging area.
The game flow later drains `ground_items` into inventory.

## Save/Load Serialization

```python
# Save
'inventory': self.inventory.copy()  # flat list of strings

# Load
self.inventory = save_data['inventory']
```

- `max_inventory` is recalculated from equipment on load, not stored directly.

---

## Godot Deviations (Remaining)

### 1. max_inventory Default: Python 10, Godot 20

**Python:** `self.max_inventory = 10` (base, +10/+20 from backpack).

**Godot:** `var max_inventory: int = 20` (GameState default).

**Assessment:** May be intentional for the Godot port. Not changed.

### 2. Capacity Check: Python excludes equipped items for store, Godot doesn't

**Python:** Store buy checks `get_unequipped_inventory_count() >= max_inventory`.

**Godot:** Store buy checks `state.inventory.size() >= state.max_inventory`.

**Assessment:** Minor deviation — equipped items count toward limit in Godot. Matches Python's generic pickup behavior but not store-specific behavior.

---

## Fixed Deviations (This PR)

### A. Ground/Chest Items → Dead-End Staging (FIXED)

**Was:** `exploration_engine.pickup_ground_item()` and `open_chest()` put items into `state.ground_items` which was never transferred to inventory. Items were lost.

**Fix:** Both now add items directly to `state.inventory`. If inventory is full, items go to `room.uncollected_items`. The mechanics engine still uses `ground_items` as staging (matching Python parity tests); `game_session._drain_ground_to_inventory()` transfers them after room enter/combat clear.

### B. Lore Item Display Count (FIXED)

**Was:** `inventory_panel.gd` counted items using exact name (`gs.inventory.count(item_name)`) but deduplicated rows using normalized name. Lore items like "Ancient Scroll #1" and "Ancient Scroll #2" would show as one row but with count 1 instead of 2.

**Fix:** Count now uses normalized name matching, consistent with Python's `Counter(normalized_inventory)`.

### C. Trace Enhancement (ADDED)

Added `inventory_item_qty_changed` trace events for pickup operations (ground, chest, mechanic drain), complementing existing buy/sell/use/drop traces.
