# Python Combat UI QoL Rules — Authoritative Reference

Extracted from: `explorer/combat.py`, `explorer/dice.py`, `dice_dungeon_explorer.py`

## A) Enemy Dice Visibility Timing

- **Enemy dice are NOT shown at combat start.**
- **Enemy dice are NOT shown when player clicks Attack** (i.e., `start_combat_turn`).
- Enemy dice appear **only after the player attacks** and the enemy takes its turn.
  - Exact call chain: `attack_enemy()` → player damage resolves → `_start_enemy_turn_sequence()` → `_announce_enemy_attack()` → `_show_and_animate_enemy_dice()` (line 2317 of `explorer/combat.py`).
- Enemy dice are **hidden** after combat ends (`enemy_defeated`, `attempt_flee`) and on exploration (`show_exploration_options` → `enemy_dice_frame.pack_forget`).
- Enemy dice display shows only the **current** enemies' dice rolls — there is no "prior monsters list."

### Godot parity status
The Godot `combat_panel.gd` correctly shows enemy dice only in `_on_attack()` after `ce.player_attack()` returns, and clears them in `_on_combat_started_reset()`. This matches Python.

### Animation Timing (enemy dice)
- 8 frames × 25 ms = 200 ms total roll animation.

### Animation Timing (player dice)
- Explorer dice: 15 frames × 25 ms = 375 ms.
- Combat dice: 8 frames × 25 ms = 200 ms.

## B) Enemy Dice Persistence Across Turns

- Enemy dice are **recreated each turn** the enemy attacks. The display is cleared and rebuilt with new values each attack round. They persist visually until the next attack or combat end.

## C) Prior Monsters List

- Python does **not** have a "prior monsters list" UI. Only the current encounter's enemies are shown.

## D) Combat Log Clearing

- The adventure log (`adventure_log`) is a **single append-only list** for the entire run. It is **never cleared between encounters**.
- It is only reset on `start_new_game()` (`self.adventure_log = []`).
- The **combat panel's log** (internal to the combat UI area) also does not explicitly clear between encounters in Python — combat messages are part of the main adventure log.

### Godot parity decision
Since the Godot combat panel has its own separate `_log_text` RichTextLabel, it should be **cleared on each new combat start** to avoid showing stale lines from prior encounters in the combat panel. The main adventure log (bottom of screen) keeps full history.

## E) Inventory During Combat

- **Inventory IS accessible during combat** via the Tab key.
- There is no `in_combat` check on the Tab keybinding:
  ```python
  if action == 'inventory':
      if self.game_active:
          self.show_inventory()
      return
  ```
- The visible "Inv" button in the action panel is only in exploration mode. During combat, inventory is only via Tab hotkey.
- Items that require combat (buff, shield, combat_consumable, throwable) check `in_combat` individually.

## F) Pacing / Animation Timing Rules

### Text Speed (adventure log typewriter)
- Per-character delays: `Slow: 15ms`, `Medium: 13ms`, `Fast: 7ms`, `Instant: 0ms`.
- Revisited rooms use `instant_mode`.

### Combat-specific timing
- Dice roll animation: 8 frames × 25 ms = 200 ms (combat), 15 frames × 25 ms = 375 ms (exploration).
- Failed flee delay: 1000 ms before `start_combat_turn`.
- Enemy attack announcements: 700 ms spacing.
- HP bar flash: 700 ms before color restore.
- Enemy death animations: 400–900 ms delays.

### No "instant mode" toggle for combat pacing in Python
Python does not have a combat pacing setting. Only text speed is configurable. The Godot port adds combat pacing as a new QoL feature (Instant / Fast / Normal / Slow) — this is a Godot-only enhancement.
