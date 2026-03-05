# Python Abilities Catalog (Authoritative Reference)

Extracted from `explorer/combat.py` — `_trigger_boss_abilities` / `_execute_boss_ability`.

## Trigger System

### Trigger Types
- `combat_start`: fires once when combat begins (always triggers)
- `hp_threshold`: fires once when `current_hp / max_health <= threshold`
  - Key: `"{enemy_name}_{ability_type}_hp_{threshold}"` in `boss_ability_cooldowns`
  - Only fires once per unique key
- `enemy_turn`: fires periodically based on `interval_turns`
  - Key: `"{enemy_name}_{ability_type}_turn"` in `boss_ability_cooldowns`
  - Fires when `combat_turn_count - last_trigger >= interval_turns`
  - `last_trigger` defaults to `-interval` (so first eligible turn fires)
- `on_death`: fires when enemy dies (always triggers)

### Trigger Evaluation
```
_trigger_boss_abilities(enemy, trigger_type):
  for ability in enemy.config.boss_abilities:
    if ability.trigger != trigger_type: continue
    check trigger-specific conditions
    if should_trigger: _execute_boss_ability(enemy, ability)
```

## Ability Types

### 1. `dice_obscure`
- **Triggers**: combat_start, hp_threshold, enemy_turn
- **Params**: `duration_turns`, `message`
- **Effect**: Sets `dice_obscured = True`, adds curse with `turns_left = duration`
- **Expiry log**: `"Your vision clears! Dice values are visible again."`
- **RNG calls**: none

### 2. `dice_restrict`
- **Triggers**: combat_start, hp_threshold, enemy_turn
- **Params**: `duration_turns`, `restricted_values`, `message`
- **Effect**: Sets `dice_restricted_values = restricted_values`, adds curse
- **Expiry log**: `"The curse fades! Your dice roll normally again."`
- **RNG calls**: none at trigger; affects roll RNG (uses `rng.choice(restricted_values)` instead of `rng.randint(1,6)`)

### 3. `dice_lock_random`
- **Triggers**: combat_start, hp_threshold, enemy_turn
- **Params**: `duration_turns`, `lock_count`, `message`
- **Effect**:
  1. Find unlocked dice indices
  2. `to_lock = rng.sample(unlocked_indices, min(lock_count, len(unlocked)))`
  3. For each locked index: `dice_values[idx] = rng.randint(1, 6)`
  4. Set `forced_dice_locks = to_lock`, lock those dice
- **Expiry log**: `"The binding breaks! Your dice are unlocked."`
- **RNG calls**: `rng.sample()` for indices, then `rng.randint(1,6)` per locked die

### 4. `curse_reroll`
- **Triggers**: combat_start, hp_threshold
- **Params**: `duration_turns`, `message`
- **Effect**: Adds curse, immediately sets `rolls_left = min(rolls_left, 1)`
- **Expiry log**: `"The curse fades! You can reroll normally again."`
- **RNG calls**: none

### 5. `curse_damage`
- **Triggers**: combat_start, hp_threshold
- **Params**: `damage_per_turn`, `duration_turns`, `message`
- **Effect**: Adds curse with `damage = damage_per_turn`
- **Tick** (at start of player turn via `_process_boss_curses`):
  - `health -= damage`
  - Log: `"☠ Curse damage! You lose {n} HP. ({message})"`
  - Can kill player
- **RNG calls**: none

### 6. `inflict_status`
- **Triggers**: combat_start, hp_threshold, enemy_turn
- **Params**: `status_name`, `interval_turns` (for enemy_turn trigger), `message`
- **Effect**: If status not already in `flags["statuses"]` → append it
- **Status damage**: processed during enemy turn via `process_status_effects()`
- **RNG calls**: none

### 7. `heal_over_time`
- **Triggers**: combat_start, hp_threshold
- **Params**: `heal_per_turn`, `duration_turns`, `message`
- **Effect**: Adds curse targeting the enemy
- **Tick** (at start of player turn via `_process_boss_curses`):
  - `enemy.health = min(health + heal_amount, max_health)`
  - Log: `"💚 {name} regenerates {heal} HP!"`
  - If enemy dead → remove curse
- **Expiry log**: `"The enemy's regeneration ends."`
- **RNG calls**: none

### 8. `damage_reduction`
- **Triggers**: combat_start
- **Params**: `reduction_amount`, `duration_turns`, `message`
- **Effect**: Sets `enemy["damage_reduction"] = reduction`, adds curse
- **Application**: During player damage calc: `damage = max(1, damage - reduction)`
  - Log: `"🛡️ Enemy's defenses reduce {n} damage! ({orig} → {new})"`
- **Expiry**: Removes `damage_reduction` from enemy
  - Log: `"The enemy's defenses fade!"`
- **RNG calls**: none

### 9. `spawn_minions`
- **Triggers**: hp_threshold, on_death
- **Params**: `spawn_type`, `spawn_count`, `spawn_hp_mult`, `spawn_dice`
- **Effect**: Calls `spawn_additional_enemy()` × `spawn_count`
  - `spawn_hp = max(10, int(spawner.max_health * hp_mult))`
  - Apply difficulty mult to spawn HP
  - `spawn_dice = max(1, spawn_dice)`
  - Log: `"⚠️ {spawner} summons a {type}! ⚠️"`
  - Log: `"[SPAWNED] {type} - HP: {hp} | Dice: {dice}"`
- **RNG calls**: none directly; spawn uses spawner stats

### 10. `spawn_minions_periodic`
- **Triggers**: enemy_turn
- **Params**: `interval_turns`, `max_spawns`, `spawn_type`, `spawn_count`, `spawn_hp_mult`, `spawn_dice`
- **Effect**: Same as spawn_minions but tracks spawn count against max_spawns
  - Uses `boss_ability_cooldowns["{name}_periodic_spawns_count"]` to track
- **RNG calls**: none

### 11. `spawn_on_death`
- **Triggers**: on_death
- **Params**: `spawn_type`, `spawn_count`, `spawn_hp_mult`, `spawn_dice`
- **Effect**: Same mechanics as `spawn_minions`
- **RNG calls**: none

### 12. `transform_on_death`
- **Triggers**: on_death
- **Params**: `transform_into`, `hp_mult`, `dice_count`
- **Effect**:
  - `transform_hp = int((50 + floor * 10) * hp_mult * 1.5)`
  - Apply difficulty mult
  - Replace dead enemy in enemies list with new form
  - Log: `"[TRANSFORMED] {name} - HP: {hp} | Dice: {dice}"`
  - Trigger `combat_start` abilities for new form
- **RNG calls**: none

## Ability Message Logging
All abilities with a `message` field log: `"⚠️ {message}"` when triggered.

## Curse Processing Order (`_process_boss_curses`, called at start of player turn)
1. Check if target enemy died → mark for removal
2. Apply curse_damage → can kill player
3. Apply heal_over_time → heal enemy
4. Decrement turns_left
5. If expired → remove + log expiry message
6. Remove expired curses in reverse index order

## Status Effect Processing (`process_status_effects`, called during enemy turn)
- poison/rot → 5 damage, log `"☠ [{status}] You take {damage} damage!"`
- bleed → 5 damage, log `"▪ [{status}] You take {damage} bleed damage!"`
- burn/heat → 5 damage, log `"✹ [{status}] You take {damage} fire damage!"`
- choke/soot → no damage, log `"≋ [{status}] Your attacks are weakened!"`
- hunger → no damage, log `"◆ [{status}] You feel weakened from hunger..."`
- Statuses are permanent within combat (no duration tick-down); cleared on combat end
