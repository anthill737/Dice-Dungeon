# Python Locked Room Rules

Authoritative reference extracted from `explorer/navigation.py` and `dice_dungeon_explorer.py`.

## Room Types

### Miniboss Rooms
- Identified by `is_mini_boss_room = True` on the Room object.
- Tracked in `special_rooms` dict as `{(x, y): 'mini_boss'}`.
- Max 3 per floor.

### Boss Rooms
- Identified by `is_boss_room = True`.
- Tracked in `special_rooms` as `{(x, y): 'boss'}`.
- One per floor, spawns after all 3 minibosses defeated.

---

## Prerequisites Per Room Type

### Miniboss: Old Key
- **Check:** `"Old Key" in self.game.inventory`
- **Consumption:** Yes — `self.game.inventory.remove("Old Key")` on "Unlock & Enter".
- The Old Key is a physical inventory item obtained from room discoverables/containers.

### Boss: 3 Key Fragments
- **Check:** `self.game.key_fragments_collected >= 3`
- **Consumption:** Yes — `self.game.key_fragments_collected = 0` on "Unlock & Enter".
- Fragments are earned by defeating minibosses (1 per miniboss kill).
- Not a physical item; tracked as an integer on game state.

---

## Gating Flow (Two-Level)

### Level 1: explore_direction() — early block (no key at all)

Before any room creation or movement, `explore_direction()` checks:

```python
if new_pos in self.game.special_rooms and new_pos not in self.game.unlocked_rooms:
    room_type = self.game.special_rooms[new_pos]
    if room_type == 'mini_boss':
        if "Old Key" not in self.game.inventory:
            self.game.log("⚡ A locked door blocks your path!", 'enemy')
            self.game.log("You need an Old Key to proceed.", 'enemy')
            return
    elif room_type == 'boss':
        fragments_have = getattr(self.game, 'key_fragments_collected', 0)
        if fragments_have < 3:
            self.game.log("☠ A sealed boss door blocks your path!", 'enemy')
            self.game.log(f"You need 3 key fragments. You have {fragments_have}.", 'enemy')
            return
```

### Level 2: enter_room() — dialog when key IS present

Inside `enter_room()`, if the room is locked and the player HAS the key:

1. Pre-dialog log messages are emitted.
2. `show_key_usage_dialog()` is called.
3. `enter_room()` returns immediately — callback handles the rest.

---

## Exact Dialog Text

### Miniboss (Old Key)
- **Title:** `⚿ LOCKED ELITE ROOM`
- **Message:**
  ```
  The door is sealed with an ancient lock.

  You have an Old Key that fits!

  Use the key to unlock and enter,
  or turn back and save it for later?
  ```
- **Buttons:** `Unlock & Enter` | `Turn Back`

### Boss (Key Fragments)
- **Title:** `☠ LOCKED BOSS ROOM`
- **Message:**
  ```
  The boss chamber door is sealed shut.

  You have all 3 Boss Key Fragments!

  Forge them to unlock the door and
  face the floor boss, or turn back?
  ```
- **Buttons:** `Unlock & Enter` | `Turn Back`

---

## Unlock & Enter Behavior

### Miniboss
1. `self.game.inventory.remove("Old Key")` — key consumed.
2. `self.game.unlocked_rooms.add(new_pos)` — room permanently unlocked.
3. Log: `[KEY USED] The Old Key turns in the lock with a satisfying click!` (tag: `success`)
4. Log: `The elite room door swings open!` (tag: `success`)
5. `_complete_room_entry()` is called — room_entered fires, position updates, counters advance.

### Boss
1. `self.game.key_fragments_collected = 0` — all 3 fragments consumed.
2. `self.game.unlocked_rooms.add(new_pos)` — room permanently unlocked.
3. Log: `The 3 fragments merge into a complete key!` (tag: `success`)
4. Log: `The massive boss door grinds open!` (tag: `success`)
5. `_complete_room_entry()` is called — room_entered fires, position updates, counters advance.

---

## Turn Back Behavior

### Miniboss
1. Log: `You decide to save your Old Key for later.` (tag: `system`)
2. Log: `You turn back. The elite room remains locked.` (tag: `enemy`)
3. `update_display()` — re-render current room.
4. `show_exploration_options()` — return to normal navigation.
5. **No position change.** Player remains in previous room.
6. **No room_entered event.** `_complete_room_entry()` is never called.
7. **No exploration counters change.** `rooms_explored`, `rooms_explored_on_floor` unchanged.
8. **No RNG calls.** No random state consumed.

### Boss
1. Log: `You decide to prepare more before facing the boss.` (tag: `system`)
2. Log: `You turn back. The boss room remains sealed.` (tag: `enemy`)
3. Same no-op behavior as miniboss Turn Back.

---

## Pre-Dialog Log Messages

### Miniboss (before dialog appears)
1. `⚡ A reinforced door blocks your path! ⚡` (tag: `enemy`)
2. `The door is sealed with an ornate lock.` (tag: `system`)

### Boss (before dialog appears)
1. `☠ An enormous sealed door looms before you! ☠` (tag: `enemy`)
2. `Three keyhole slots glow faintly in the door.` (tag: `system`)

---

## No-Key Block Messages

When the player lacks the required key:

### Miniboss (no Old Key)
1. `⚡ A reinforced door blocks your path! ⚡` (tag: `enemy`)
2. `The door is sealed with an ornate lock.` (tag: `system`)
3. `You need an Old Key to unlock this door.` (tag: `enemy`)

### Boss (insufficient fragments)
1. `☠ An enormous sealed door looms before you! ☠` (tag: `enemy`)
2. `The door has 3 keyhole slots. You have {n} fragment(s).` (tag: `system`)
3. `You need {n} more key fragment(s) to unlock this door!` (tag: `enemy`)

---

## Adventure Log

All messages above are recorded to the adventure log via `self.game.log()`, which appends `(message, tag)` tuples to `self.game.adventure_log`. This includes:
- Pre-dialog messages
- Unlock messages
- Turn Back messages
- No-key block messages

There are no separate "interaction" entries — the log messages themselves ARE the adventure log entries.

---

## Unlocked Rooms Tracking

- `self.game.unlocked_rooms` is a `set()` of position tuples.
- Once a room is unlocked (via Unlock & Enter or combat victory), it stays unlocked for the rest of the floor.
- On new floor: `unlocked_rooms` is reset to an empty set.
