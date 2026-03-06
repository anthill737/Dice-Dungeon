# Python Adventure Log — Reference Specification

This document describes the authoritative Python implementation of the adventure
log. The Godot port MUST match these rules for what gets logged, the text
content, and timing of each entry.

---

## 1  Architecture

| Component | Role |
|-----------|------|
| `DiceDungeonExplorer.log(message, tag)` | Central log function — appends `(message, tag)` to `self.adventure_log`, writes to debug file, queues for typewriter display. |
| `self.adventure_log` | In-memory `list[(str, str)]` — persisted in save files. |
| `self.typewriter_queue` | Display queue — character-by-character reveal. |

Tags define colour in the Tkinter Text widget: `player`, `enemy`, `system`,
`crit`, `loot`, `success`, `damage_dealt`, `damage_taken`, `healing`,
`gold_gained`, `warning`, `fire`, `burn`, `lore`.

---

## 2  Typewriter Effect

Python **does** use a typewriter effect.

- **Speed presets (ms/char):** `{'Slow': 15, 'Medium': 13, 'Fast': 7, 'Instant': 0}`
- Controlled by `self.text_speed` setting.
- **Instant mode:** `self.instant_text_mode` is set True when re-entering a
  previously visited room (`navigation.py` line 317). This makes log entries
  appear instantly without character-by-character animation.
- Movement is blocked while typewriter is active.

---

## 3  Room Entry Logging

Source: `explorer/navigation.py`

When entering any room the following are logged in order:

| # | Text | Tag | Condition |
|---|------|-----|-----------|
| 1 | `"\n" + "="*50` | system | Always on new room |
| 2 | `"Entered: {room_name}"` | system | Always |
| 3 | `"{room_flavor}"` | system | If `room.data['flavor']` exists |

On revisit, Python sets `instant_text_mode = True` so all entries appear
instantly. The same log entries are emitted.

### Special room-entry discoveries (first visit only)

| Text | Tag | Condition |
|------|-----|-----------|
| `"⚡ You found stairs to the next floor!"` | success | Stairs spawned |
| `"You discovered a mysterious shop!"` | loot | Store spawned |
| `"✨ There's a chest here!"` | loot | Chest spawned (dead code) |
| `"You notice on the ground: {items}"` | system | Ground items present |
| Peaceful message (one of 5, random) | system | Combat room rolled no combat |

**Peaceful messages:**
- `"The room is quiet. You explore cautiously..."`
- `"You sense danger but nothing attacks."`
- `"The threats here seem to have moved on."`
- `"You carefully avoid any lurking dangers."`
- `"The room appears safe for now."`

---

## 4  Interaction Logging

### 4.1  Containers (`explorer/inventory_pickup.py`)

| Text | Tag | When |
|------|-----|------|
| `"🔓 Used Lockpick Kit! The {container} is now unlocked."` | success | Lockpick used |
| `"[SEARCH] You can't figure out how to open the {container}."` | system | Search fails |
| `"The {container} is locked! You need a Lockpick Kit to open it."` | system | Locked, no kit |
| `"You don't have a Lockpick Kit!"` | system | No kit in inventory |

### 4.2  Store (`explorer/store.py`)

Python does **not** log explicit "entered store" or "left store" messages.
Store interactions are logged per-transaction:

| Text | Tag |
|------|-----|
| `"Not enough gold!"` | system |
| `"Inventory is full!"` | system |
| `"Purchased {item}! Now have {N} dice."` | loot |
| `"Purchased {item}! (Equip it from inventory for {slot} slot)"` | loot |
| `"Purchased {quantity}x {item}!"` | loot |
| `"Sold {qty}x {item} for {gold} gold!"` | loot |
| `"Turned in {qty}x {item}! Claimed {gold} gold reward!"` | success |
| `"Cannot sell equipped item! Unequip {item} first."` | system |

Fast-travel to store: `"Traveled to the store from {old_room_name}!"` (main file).

### 4.3  Rest (`dice_dungeon_explorer.py`)

| Text | Tag | Condition |
|------|-----|-----------|
| `"⛔ Cannot rest yet! Explore {N} more room(s) to rest again."` | enemy | Cooldown active |
| `"⛔ Cannot rest during combat!"` | enemy | In combat |
| `"[REST] Rested and recovered {N} HP. Must explore 3 rooms before resting again."` | success | Heal applied |
| `"You're already at full health!"` | system | Full HP |

### 4.4  Stairs (`explorer/navigation.py`)

| Text | Tag | Condition |
|------|-----|-----------|
| `"No stairs here! Keep exploring."` | system | No stairs in room |
| `"The stairs are blocked..."` | system | Boss not defeated |
| `"\n[STAIRS] Descending deeper to Floor {N}..."` | success | Descend |

### 4.5  Chests (`dice_dungeon_explorer.py`)

| Text | Tag |
|------|-----|
| `"[CHEST] Opened chest: +{amount} gold!"` | loot |
| `"[CHEST] Opened chest: Health Potion! +{heal} HP"` | loot |
| `"[CHEST] Opened chest: {item}!"` | loot |
| `"[CHEST] Opened chest: {item}! But inventory is full."` | system |

### 4.6  Doors / Navigation Blocks (`explorer/navigation.py`)

| Text | Tag |
|------|-----|
| `"That path is blocked!"` | system |
| `"That direction is blocked!"` | system |
| `"That path is blocked from the other side!"` | system |
| Locked elite door messages | enemy/system |
| Sealed boss door messages | enemy |
| `"Old Key used — door opens!"` | success |
| `"Key fragments merged — boss door opened!"` | success |

### 4.7  Hazards / Room Mechanics (`mechanics_engine.py`)

| Text | Tag |
|------|-----|
| `"Cleansed all negative statuses"` | system |
| `"Gained a disarm token"` | system |
| `"Gained an escape token"` | system |
| `"Found item: {item} (on ground)"` | system |
| `"Found item: {item}"` | system |
| `"Status applied: {status}"` | system |
| `"+{N} Shield"` | system |

---

## 5  Combat Logging

### 5.1  Combat Start (`explorer/combat.py`)

| Text | Tag | Type |
|------|-----|------|
| `"\n" + "="*60` | system | Boss |
| `"{boss_title}"` | enemy | Boss |
| `"⚔️ {name} ⚔️"` | enemy | Boss |
| `"="*60` | system | Boss |
| `"⚡ {name} ⚡ (MINI-BOSS)"` | enemy | Mini-boss |
| `"A powerful guardian blocks your path!"` | enemy | Mini-boss |
| `"{name} blocks your path!"` | enemy | Regular |
| `"Enemy HP: {hp} \| Dice: {dice}"` | system | All |

### 5.2  Player Actions

| Text | Tag |
|------|-----|
| `"⚄ You rolled: [{dice}] - Potential: {N} damage"` | player |
| `"⚔️ You attack and deal {damage} damage!"` | player |
| `"🛡️ Enemy's defenses reduce {N} damage! (X → Y)"` | enemy |
| `"⚠️ You fumble! Lost a {die} from your attack."` | enemy |
| Critical hit flavor text (random from pool) | crit |

### 5.3  Enemy Actions

| Text | Tag |
|------|-----|
| `"{name} rolls: [{dice}]"` | enemy |
| `"⚔️ {name} attacks for {N} damage!"` | enemy |
| `"⚠️ {name} summons a {type}! ⚠️"` | enemy |
| `"✸ {name} splits into {N} {type}s! ✸"` | enemy |
| `"💚 {name} regenerates {N} HP!"` | enemy |
| `"☠ Curse damage! You lose {N} HP."` | enemy |
| Enemy taunts (random from per-enemy pool) | enemy |

### 5.4  Combat Resolution

| Text | Tag |
|------|-----|
| Enemy death flavor (random from per-enemy pool) | enemy |
| `"☠ FLOOR BOSS DEFEATED! ☠"` | success |
| `"Mini-boss defeated!"` | success |
| `"+{gold} gold!"` | loot |
| `"Obtained Boss Key Fragment! (N/3)"` | loot |
| `"The floor boss will appear soon..."` | enemy |
| `"❌ You cannot flee from a boss fight!"` | enemy |
| `"✨ Used Escape Token — fled safely!"` | success |
| `"[FLEE] You fled! Lost {damage} HP in the escape."` | system |

---

## 6  Game End

| Text | Tag | When |
|------|-----|------|
| `"\n" + "="*70` | system | Victory |
| `"★ VICTORY! YOU DEFEATED THE DUNGEON BOSS! ★"` | success | Victory |
| Score lines | system/loot | Victory |
| `"\n" + "="*50` | system | Death |
| `"☠ YOU DIED"` | enemy | Death |
| Final score | system | Death |

---

## 7  Formatting Conventions

- **Room entry separator:** `"\n" + "=" * 50` (50 equals, preceded by newline)
- **Boss combat separator:** `"\n" + "=" * 60`
- **Victory/death separator:** `"=" * 50` or `"=" * 70`
- **Each log entry** ends with `'\n'` (added by typewriter after text completes).
- **No explicit blank-line entries** — the `"\n"` prefix on separator strings
  creates visual spacing.

---

## 8  Filtering Rules

- **No filtering:** Every call to `log(message, tag)` is appended.
- **No deduplication:** If the same message is logged twice, it appears twice.
- **Revisited rooms:** Same messages are emitted, but with `instant_text_mode`.
- **Early return:** If the log Text widget doesn't exist, the entry is still
  persisted to `adventure_log` and the debug file.

---

## 9  Godot Deviations (Audit)

### 9.1  Missing Room Entry Header

- **Python** logs `"="*50` separator + `"Entered: {name}"` + flavor text for
  every room entry.
- **Godot** logs `"Entered: {name}"` only, with no separator and no flavor text.
- **Fix needed:** Add separator and flavor text to room entry logging.

### 9.2  Missing Interaction Flavor

- **Store enter/leave:** Neither Python nor Godot logs "entered store" / "left
  store" explicitly. Godot does log `"Browsing store..."` which Python does not.
  This is harmless but non-parity. Keep Godot's version as a Godot enhancement.
- **Container search:** Godot logs `"Searched {container}: ..."` — matches
  Python pattern.
- **Rest:** Godot logs `"Rested and recovered {N} HP."` — close to Python but
  missing the rest cooldown text (`"Must explore 3 rooms before resting again"`).
- **Stairs/descend:** Godot logs `"Cannot descend: boss not defeated or no
  stairs here."` — acceptable simplification.

### 9.3  Readability / Visibility Issues

- **Contrast:** `BG_LOG = Color(0.08, 0.05, 0.03)` with `TEXT_BONE` text is
  adequate but could be improved with slightly lighter background or higher
  contrast text.
- **Line spacing:** `separation = 2` on the VBoxContainer is tight.
- **Padding:** Content margin is only 6px — minimal.
- **No subtle background** behind individual log entries.
- **Font size:** 13px (`FONT_LOG`) is small for dense text.

### 9.4  Auto-Scroll

- Godot uses `scroll_following = true` — always auto-scrolls.
- **Missing:** No "scroll up preserves position" or "new messages" indicator.

### 9.5  Duplicate Logging

- No duplicate logging observed on redraw/recenter/load. `_emit_logs()` clears
  the `logs` array after emitting, preventing duplicates.

### 9.6  F4 Export Gaps

- Missing `adventure_log_count` field.
- Missing per-entry `event_type`/`category` (optional).
- `rng_mode` and `seed` are already present.
