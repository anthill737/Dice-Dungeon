# Boss Abilities System Guide

## Overview
Mini-bosses and floor bosses now have unique special abilities that make combat more challenging and varied. Abilities can manipulate dice, apply curses, spawn enemies, or trigger transformations.

## Ability Types

### Dice Manipulation

#### `dice_obscure`
Hides dice values from the player for a duration.
- **Effect**: Dice show "?" with purple "CURSED" text instead of numbers
- **Player Impact**: Must attack without knowing exact dice values
- **Example**: Gelatinous Slime hides dice for 2 turns at combat start

#### `dice_restrict`
Limits dice rolls to specific values only.
- **Effect**: Dice can only roll from a restricted set (e.g., [1, 2])
- **Player Impact**: Severely limits damage potential
- **Example**: Shadow Hydra restricts to 1s and 2s for 2 turns every 4 turns

#### `dice_lock_random`
Force-locks random dice for a duration.
- **Effect**: Random dice become locked and cannot be toggled
- **Player Impact**: Reduces control over dice selection
- **Example**: Crystal Golem locks 2 random dice every 3 turns

### Status Effects / Curses

#### `curse_reroll`
Limits player rerolls per turn.
- **Effect**: Reduces rolls_left to 1 per turn
- **Player Impact**: Must commit to dice values quickly
- **Example**: Necromancer applies curse for 3 turns at 50% HP

#### `curse_damage`
Applies damage over time to the player.
- **Effect**: Player takes fixed damage at start of each turn
- **Player Impact**: Races against time, health drain
- **Example**: Demon Lord deals 3 damage per turn throughout combat

### Spawn Mechanics

#### `spawn_on_death`
Spawns additional enemies when boss dies.
- **Effect**: Summons new enemies before removal
- **Player Impact**: Must continue fighting after "defeating" boss
- **Example**: Necromancer spawns 3 Skeletons on death

### Transformation

#### `transform_on_death`
Boss transforms into a different, stronger form.
- **Effect**: Replaces boss with new enemy type with restored HP
- **Player Impact**: Extends combat significantly, surprise factor
- **Example**: Demon Lord transforms into Demon Prince with 60% HP and 6 dice

## Ability Triggers

### `combat_start`
Triggers immediately when combat begins.
- Use for: Initial debuffs, setting tone for fight
- Example: Gelatinous Slime obscures dice from the start

### `hp_threshold`
Triggers once when boss HP drops below threshold.
- Use for: Phase transitions, desperation moves
- Example: Necromancer curses player at 50% HP

### `enemy_turn`
Triggers on enemy turn based on interval.
- Use for: Recurring effects, rhythm-based challenges
- Example: Shadow Hydra restricts dice every 4 turns

### `on_death`
Triggers when boss health reaches 0.
- Use for: Final mechanics, transformations, spawns
- Example: Demon Lord transforms into Demon Prince

## Ability Configuration Format

```json
{
  "Enemy Name": {
    "boss_abilities": [
      {
        "type": "dice_obscure",
        "trigger": "combat_start",
        "duration_turns": 2,
        "message": "The boss shrouds your dice in darkness!"
      },
      {
        "type": "curse_damage",
        "trigger": "hp_threshold",
        "hp_threshold": 0.5,
        "damage_per_turn": 3,
        "duration_turns": 999,
        "message": "The boss curses you! You take 3 damage per turn."
      }
    ]
  }
}
```

## Current Boss Abilities

### Gelatinous Slime (Mini-Boss)
- **Combat Start**: Obscures dice for 2 turns
- **Strategy**: Attack blindly or wait out the curse

### Necromancer (Mini-Boss)
- **50% HP**: Limits rerolls to 1 per turn for 3 turns
- **On Death**: Spawns 3 Skeletons (40% HP, 3 dice each)
- **Strategy**: Burst damage before HP threshold, save resources for spawns

### Shadow Hydra (Mini-Boss)
- **Every 4 Turns**: Restricts dice to only 1s and 2s for 2 turns
- **Strategy**: Time attacks to avoid curse windows, use potions during curse

### Demon Lord (Floor Boss)
- **Combat Start**: Applies 3 damage per turn curse (permanent)
- **On Death**: Transforms into Demon Prince (60% HP, 6 dice)
- **Strategy**: Race against curse damage, prepare for transformation

### Demon Prince (Transformed Boss)
- **50% HP**: Obscures dice permanently for rest of combat
- **Strategy**: Memorize last roll values, high-damage burst

### Crystal Golem (Mini-Boss)
- **Every 3 Turns**: Force-locks 2 random dice for 1 turn
- **Strategy**: Don't rely on specific dice combinations, adapt quickly

## Implementation Details

### Combat Flow Integration
1. **Combat Start**: `trigger_combat()` initializes ability tracking and triggers combat_start abilities
2. **Player Turn Start**: `start_combat_turn()` processes active curses (damage, countdowns)
3. **Enemy Damage**: `_execute_player_attack()` checks hp_threshold triggers
4. **Enemy Turn**: `_start_enemy_turn_sequence()` triggers enemy_turn abilities
5. **Enemy Death**: `_finalize_enemy_defeat()` triggers on_death abilities

### Curse Processing
- Active curses stored in `game.active_curses` list
- Each curse has `turns_left` countdown
- Decremented at start of player turn
- Removed when `turns_left` reaches 0

### Dice Effects
- `game.dice_obscured`: Boolean flag for hiding values
- `game.dice_restricted_values`: List of allowed roll values (empty = all)
- `game.forced_dice_locks`: List of force-locked dice indices

### Cooldown System
- `game.boss_ability_cooldowns`: Dict tracking ability usage
- Prevents repeated triggers for hp_threshold abilities
- Tracks turn intervals for enemy_turn abilities

## Design Guidelines

### Balance Considerations
1. **Duration**: 2-3 turns for major effects, 1 turn for minor
2. **Frequency**: 3-4 turn intervals for recurring abilities
3. **HP Thresholds**: 50-75% for early, 25% for desperation
4. **Spawn Stats**: 30-40% HP multiplier, 2-3 dice for minions

### Player Counterplay
- Most curses have limited duration (wait it out)
- Potions and items work during curses
- Can still use mystic ring and combat abilities
- Fire potions bypass dice restrictions

### Difficulty Scaling
- Early floor mini-bosses: 1-2 simple abilities
- Mid-floor bosses: 2-3 abilities with combos
- Late-floor bosses: Multiple phases, transformations
- Difficulty multipliers affect spawned enemy HP

## Adding New Abilities

1. **Define in enemy_types.json**:
```json
{
  "New Boss": {
    "boss_abilities": [
      {
        "type": "new_ability_type",
        "trigger": "hp_threshold",
        "hp_threshold": 0.3,
        "parameter": "value",
        "message": "Boss uses special ability!"
      }
    ]
  }
}
```

2. **Implement in combat.py `_execute_boss_ability()`**:
```python
elif ability_type == "new_ability_type":
    parameter = ability.get("parameter", "default")
    # Apply effect to game state
    self.game.new_effect = parameter
    # Add to active curses if it has duration
    duration = ability.get("duration_turns", 2)
    self.game.active_curses.append({
        "type": "new_ability_type",
        "turns_left": duration,
        "message": "Effect active!"
    })
```

3. **Add curse cleanup in `_process_boss_curses()`** (if applicable)

4. **Test with various bosses and difficulty settings**

## Future Expansion Ideas

- Dice value swap (turn 6s into 1s)
- Forced re-rolls (player must reroll all dice)
- Dice theft (enemy steals highest die)
- Mirror damage (reflect some damage back to player)
- Dice freezing (prevent any rolls for 1 turn)
- Progressive curse (effect gets stronger each turn)
- Conditional abilities (trigger on specific dice combos)
