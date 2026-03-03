# Python Store Rules — Authoritative Reference

Source files: `explorer/navigation.py`, `explorer/store.py`, `dice_dungeon_explorer.py`

## Store Spawn Logic

**File:** `explorer/navigation.py` lines 373-390, inside `_continue_room_entry()`

### Conditions

Store roll only fires when ALL of these are true:
- `not skip_effects` (not loading a save)
- `is_first_visit` (room not previously visited)
- `not self.game.store_found` (no store yet on this floor)
- `self.game.rooms_explored >= 2` (at least 2 rooms explored)

### Spawn Threshold

- **Minimum:** `rooms_explored >= 2`
- **Guaranteed:** `rooms_explored >= 15` (store spawns with no RNG roll)

### Per-Floor Probabilities

```python
store_chance = 0.15  # Default for floor 4+
if self.game.floor == 1:
    store_chance = 0.35
elif self.game.floor == 2:
    store_chance = 0.25
elif self.game.floor == 3:
    store_chance = 0.20
```

| Floor | Chance |
|-------|--------|
| 0     | 0.15 (hits default, floor 0 not matched) |
| 1     | 0.35 |
| 2     | 0.25 |
| 3     | 0.20 |
| 4+    | 0.15 |

### RNG Usage Pattern

```python
# store_chance is computed BEFORE the conditional block
# RNG call: self.game.rng.random() is consumed ONLY when:
#   rooms_explored >= 2 AND NOT store_found AND rooms_explored < 15
# When rooms_explored >= 15: NO RNG call, guaranteed spawn
if self.game.rooms_explored >= 15 or self.game.rng.random() < store_chance:
```

Python short-circuits: if `rooms_explored >= 15`, the `rng.random()` call is **never made**.

### One Store Per Floor

`store_found` is set to `True` on spawn and reset when a new floor starts (`start_new_floor()`). Only one store per floor.

## Collision Rules (Store vs Stairs)

Stairs check (line 367-371) and store check (line 385-390) are **independent**. There is **no mutual exclusion**. A room CAN have both stairs and a store.

Order:
1. Stairs roll (line 367)
2. Store roll (line 385)

## Floor 0 Behavior

- **Spawn probability:** Floor 0 does not match any `elif` branch, so `store_chance = 0.15`.
- **Inventory generation:** `effective_floor = max(1, self.game.floor)` — floor 0 is treated as floor 1 for pricing and item availability.

## Store Inventory Generation

**File:** `explorer/store.py` method `_generate_store_inventory()`

### Key Rules

- **No RNG** used in inventory generation. Deterministic based on floor and purchased upgrades.
- `effective_floor = max(1, self.game.floor)`
- All items for the current floor tier are shown (no random filtering).
- Upgrades already in `self.game.purchased_upgrades_this_floor` are excluded.
- Inventory is generated **once per floor** (lazy, on first store visit) and cached in `self.game.floor_store_inventory`.

### Item Categories (by effective_floor gate)

| Gate | Items |
|------|-------|
| Always | Health Potion, Weapon Repair Kit, Armor Repair Kit |
| ≥ 5 | Master Repair Kit |
| Always (upgrades) | Max HP Upgrade, Damage Upgrade, Fortune Upgrade |
| ≥ 2 (upgrade) | Critical Upgrade |
| ≥ 1 (consumable) | Lucky Chip, Honey Jar, Healing Poultice |
| ≥ 2 (consumable) | Weighted Die, Lockpick Kit, Conductor Rod |
| ≥ 3 (consumable) | Hourglass Shard, Tuner's Hammer, Antivenom Leaf |
| ≥ 4 (consumable) | Cooled Ember, Smoke Pot, Black Candle |
| ≥ 1 (weapon) | Iron Sword, Steel Dagger |
| ≥ 2 (weapon) | War Axe, Rapier |
| ≥ 4 (weapon) | Greatsword, Assassin's Blade |
| ≥ 1 (armor) | Leather Armor, Chain Vest |
| ≥ 3 (armor) | Plate Armor, Dragon Scale |
| ≥ 1 (accessory) | Traveler's Pack |
| ≥ 2 (accessory) | Lucky Coin, Mystic Ring, Merchant's Satchel, Extra Die |
| ≥ 4 (accessory) | Crown of Fortune, Timekeeper's Watch |
| ≥ 3 (valuable) | Blue Quartz, Silk Bundle |

## Store State Persistence

### Save (Python `dice_dungeon_explorer.py` lines ~5511-5548)

Saved fields:
- `store_found` (bool)
- `store_position` (list or null)
- `purchased_upgrades_this_floor` (list)

### Load (Python `dice_dungeon_explorer.py` lines ~5797-5937)

Loaded fields:
- `store_found` (bool, with default False)
- `store_position` (tuple or None)
- `store_room` is reconstructed: if `store_found` and `store_position` in `dungeon`, set `store_room = dungeon[store_position]`

### NOT Loaded

- `purchased_upgrades_this_floor` — Python saves it but **does not load it**. After loading, the set is empty, meaning previously purchased upgrades can be re-purchased. This appears to be a Python bug, but it is the actual behavior.
- `floor_store_inventory` — not saved. Regenerated on first store visit after load (lazy generation).

---

## Godot Deviations

### 1. `has_store` Not Serialized in Room State

**Python:** After load, `store_room` is reconstructed from `store_position` + `dungeon` dict lookup. The room at `store_position` is identified as the store room.

**Godot:** `_serialize_room()` and `_deserialize_room()` in `save_engine.gd` do NOT include `has_store`. After save/load, `room.has_store` is `false` for all rooms, even the store room. The floor-level `store_found` and `store_pos` are preserved, but the room-level flag is lost.

**Impact:** After loading a save, the store room won't render its store icon and the store interaction won't be available, even though `floor.store_found` is true and `floor.store_pos` is set.

**Fix:** Add `has_store` to room serialization AND/OR reconstruct it from `floor_st.store_pos` after deserialization.

### 2. `purchased_upgrades_this_floor` Loaded in Godot (Differs from Python)

**Python:** Does not load this field (bug — saved but never loaded).

**Godot:** Loads it correctly from save data.

**Assessment:** The Godot behavior is arguably more correct. This is an improvement over Python, not a regression. No fix needed — keep the Godot behavior.

### 3. F4 Export Missing Adventure Log

**Python:** N/A (Python has no F4 export).

**Godot:** Session trace JSON/text export does not include adventure log entries. The `AdventureLogService` has `get_entries()` but it is not called during export.

**Fix:** Include `adventure_log` array in both JSON and text exports.

### 4. F4 Export Missing Explicit `rng_mode` Field

**Godot:** The session trace JSON includes `seed` and `rng_type` (e.g. "DeterministicRNG"), but does not include a normalized `rng_mode` field ("default" | "deterministic"). The `run_started` event payload does include `rng_mode`, but it should also be a top-level export field for easy access.

**Fix:** Add `rng_mode` to `SessionTrace` and include it in export output.
