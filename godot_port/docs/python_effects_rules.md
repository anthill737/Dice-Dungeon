# Python Effects Rules (Authoritative Reference)

Extracted from `explorer/combat.py`, `dice_dungeon_content/engine/mechanics_engine.py`.

## Effect Categories

### 1. Boss Curses (`game.active_curses`)
Managed as a list of dictionaries in `active_curses`. Processed at START of player turn.

#### Curse Structure
```python
{
    "type": str,          # curse type ID
    "turns_left": int,    # remaining duration
    "message": str,       # display message
    # type-specific fields:
    "damage": int,        # curse_damage only
    "heal_amount": int,   # heal_over_time only
    "target_enemy": dict, # heal_over_time, damage_reduction
    "restricted_values": list,  # dice_restrict
    "locked_indices": list,     # dice_lock_random
    "reduction_amount": int,    # damage_reduction
}
```

#### Tick Timing
- Processed at `_process_boss_curses()`, called at start of `start_combat_turn()`
- After `combat_turn_count += 1` and rolls reset, BEFORE dice UI shown
- Order: check target death → apply effects → decrement duration → remove expired

#### Duration Rules
- `turns_left` decremented by 1 each player turn
- Removed when `turns_left <= 0`
- Also removed if `target_enemy` is no longer in `enemies` list

#### Stacking
- Multiple curses of the same type CAN coexist (each is a separate entry)
- No explicit stacking prevention

#### Expiry Messages
| Curse Type | Expiry Log |
|---|---|
| `dice_obscure` | `"Your vision clears! Dice values are visible again."` |
| `dice_restrict` | `"The curse fades! Your dice roll normally again."` |
| `dice_lock_random` | `"The binding breaks! Your dice are unlocked."` |
| `curse_reroll` | `"The curse fades! You can reroll normally again."` |
| `heal_over_time` | `"The enemy's regeneration ends."` |
| `damage_reduction` | `"The enemy's defenses fade!"` |
| `curse_damage` | (no specific expiry message) |

### 2. Player Status Effects (`game.flags["statuses"]`)
A simple list of status name strings. No duration tracking — persist until combat end or cleanse.

#### Tick Timing
- Processed during enemy turn in `_start_enemy_turn_sequence()` → `process_status_effects()`
- After boss ability enemy_turn triggers
- Before enemy burn damage and enemy attacks

#### Damage Rules
All DoT statuses deal fixed 5 damage per tick:
| Status Contains | Damage | Log |
|---|---|---|
| `"poison"` or `"rot"` | 5 | `"☠ [{status}] You take {damage} damage!"` |
| `"bleed"` | 5 | `"▪ [{status}] You take {damage} bleed damage!"` |
| `"burn"` or `"heat"` | 5 | `"✹ [{status}] You take {damage} fire damage!"` |
| `"choke"` or `"soot"` | 0 | `"≋ [{status}] Your attacks are weakened!"` |
| `"hunger"` | 0 | `"◆ [{status}] You feel weakened from hunger..."` |

String matching is case-insensitive (`status.lower()`).

#### Stacking
- Duplicate statuses are prevented at infliction (`if status not in statuses: append`)
- Multiple different statuses can coexist

#### Cleanse
- `"cleanse": true` in mechanics clears `flags["statuses"]` entirely
- All statuses cleared on combat end (`enemy_defeated()` or flee)

#### Immunity
- No explicit immunity system in Python
- `dev_invincible` blocks all damage but still logs

### 3. Enemy Burn (`game.enemy_burn_status`)
Dictionary keyed by enemy index: `{initial_damage, turns_remaining}`.

#### Tick Timing
- Processed during enemy turn in `_start_enemy_turn_sequence()` → `_apply_burn_damage()`
- After status effects, before spawn checks and enemy attacks

#### Damage Sequence (Fixed)
| `turns_remaining` | Damage |
|---|---|
| 3 | 8 |
| 2 | 5 |
| 1 | 2 |
| 0 | 0 |

#### Log Messages
- Tick: `"🔥 {name} takes {damage} burn damage! ({turns} turns remaining)"`
- Expire: `"🔥 {name}'s burn fades away."`
- Death: `"💀 {name} burned to death!"`

#### Duration
- `turns_remaining` decremented by 1 each tick
- Removed when `turns_remaining <= 0`

### 4. Temp Effects (`game.temp_effects`)
Managed by MechanicsEngine. Dictionary: key → `{"delta": number, "duration": "combat"|"floor"|"run"}`.

#### Supported Keys
| Key | Type | Description |
|---|---|---|
| `extra_rolls` | int | Additional rerolls per turn |
| `crit_bonus` | float | Added to crit chance |
| `damage_bonus` | int | Added to damage |
| `gold_mult` | float | Gold multiplier |
| `shop_discount` | float | Shop price reduction |

#### Settlement (`settle_temp_effects`)
- `"after_combat"` phase: clears effects with `duration == "combat"`
- `"floor_transition"` phase: clears `"combat"` and `"floor"` duration effects, resets `temp_shield` and `shop_discount`

## Effect Application in Combat

### Player Damage Calculation
```
base_damage = sum(dice_values)
combo_bonus = calculate_combos(dice_values)
total = int(base * multiplier) + combo_bonus + damage_bonus + temp_damage_bonus + status_damage_bonus
total *= difficulty_player_damage_mult
if crit: total *= 1.5  (Explorer) or 2.0 (Classic)
total -= enemy.damage_reduction (min 1)
```

### Enemy Damage Calculation
```
base = sum(enemy_dice) + (floor * 2)
damage = int(base * enemy_damage_mult * player_damage_taken_mult * 0.95)
if floor <= 3: damage *= 1.15
# shield absorbs first
# armor reduces: reduction = min(armor * 0.15, 0.60)
```

## RNG Usage Points in Effects
1. `dice_lock_random`: `rng.sample()` for indices, `rng.randint(1,6)` per locked die
2. All other effects: NO RNG usage
3. Status infliction: NO RNG usage
4. Curse ticks: NO RNG usage
