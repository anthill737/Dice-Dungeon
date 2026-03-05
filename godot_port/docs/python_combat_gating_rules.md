# Python Combat Gating Rules

Extracted from: `dice_dungeon_explorer.py`, `explorer/combat.py`

## Saving During Combat
- Location: `dice_dungeon_explorer.py` lines 5167–5222
- Rule: `can_save = in_game and not self.in_combat`
- When `in_combat`:
  - Save buttons show "Cannot Save During Combat"
  - Buttons are disabled (bg `#8B0000` dark red)
- This applies to both manual save and auto-save.

## Fleeing During Combat
- Location: `explorer/combat.py` `attempt_flee()` lines 285–324
- Boss/mini-boss fights: Cannot flee
  - Message: `"❌ You cannot flee from a boss fight! Fight or die!"`
- With Escape Token: Consume token, guaranteed flee, no damage
- Without token: 50% flee chance
  - On success: Take `rng.randint(5, 15)` damage; if death, game over; otherwise flee
  - On failure: `"❌ Can't escape! Enemy blocks the way!"`; combat continues after 1000ms
- Flee IS allowed during the pre-combat pending choice (before combat engine starts)
  - Uses same 50% chance
  - No damage on success during pending

## Inventory During Combat
- Python allows opening inventory during combat (to use items like potions)
- No explicit block on inventory access during combat

## Godot Implementation
- CombatGatingPolicy module should centralize these decisions:
  - `can_save()`: false when combat is active
  - `can_flee_from_boss()`: false for boss/mini-boss fights
  - Pending flee uses 50% chance via RNG
