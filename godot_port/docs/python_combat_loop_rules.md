# Python Combat Loop Rules (Authoritative Reference)

Extracted from `explorer/combat.py` — CombatManager class.

## Phase Ordering

### 1. Start of Combat (`trigger_combat`)
- `in_combat = True`, `combat_turn_count = 0`
- Reset rolls: `rolls_left = 3 + reroll_bonus`
- Reset dice values to `[0] * num_dice`, locks to `[False] * num_dice`
- Scale enemy HP: `base_hp = 50 + (floor * 10)`, apply multiplier from `enemy_hp_multipliers` table
- HP variation: `enemy_hp = base_hp + rng.randint(-5, 10)`
- Boss: `enemy_hp *= 8`, dice = `min(5 + floor//2, 8)`
- Mini-boss: `enemy_hp *= 3`, dice = `min(4 + floor//2, 7)`
- Normal: dice = `min(3 + floor//2, 6)`
- Apply difficulty mult: `enemy_hp *= difficulty_multipliers[difficulty]["enemy_health_mult"]`
- Apply dev mult: `enemy_hp *= dev_config["enemy_hp_mult"]`
- Initialize: `active_curses = []`, `dice_obscured = False`, `dice_restricted_values = []`, `forced_dice_locks = []`, `boss_ability_cooldowns = {}`
- **RNG calls**: `rng.randint(-5, 10)` for HP variation
- Run `_trigger_boss_abilities(enemy, "combat_start")` for all enemies
- Log: boss → `"☠ FLOOR BOSS ☠"`, `"⚔️ {NAME} ⚔️"`; mini-boss → `"⚡ {NAME} ⚡ (MINI-BOSS)"`, `"A powerful guardian blocks your path!"`; normal → `"{name} blocks your path!"`
- Log: `"Enemy HP: {hp} | Dice: {dice}"`

### 2. Start of Turn (`start_combat_turn`)
- `combat_turn_count += 1`
- Check for reroll curse: if active → `rolls_left = 1`; else → `rolls_left = 3 + reroll_bonus`
- Reset dice values (preserve forced_dice_locks values), reset locks (preserve forced_dice_locks)
- **Process boss curses** (`_process_boss_curses`):
  - For each curse: check if target enemy died → remove
  - `curse_damage`: `health -= damage`, log `"☠ Curse damage! You lose {n} HP. ({message})"`
  - `heal_over_time`: heal enemy `min(health + heal, max_health)`, log `"💚 {name} regenerates {heal} HP!"`
  - Decrement `turns_left`; if ≤ 0 → remove + log expiry message
- If player dies from curse → end
- **NO status effect processing here** (happens during enemy turn)

### 3. Player Rolls (`roll_dice`)
- For each unlocked die:
  - If `dice_restricted_values` not empty: `rng.choice(restricted_values)`
  - Else: `rng.randint(1, 6)`
- `rolls_left -= 1`
- **RNG calls per roll**: one per unlocked die

### 4. Player Attack (`attack_enemy` → `_calculate_and_announce_player_damage`)
- `combat_state = "resolving_player_attack"`
- **Fumble check**: if `combat_fumble_chance > 0` → `rng.random() < fumble_chance` → remove lowest die
- **Damage calc**: `dice_manager.calculate_damage()` (base + combos)
- Apply difficulty: `damage *= difficulty_multipliers[difficulty]["player_damage_mult"]`
- **Crit check**: `rng.random() < crit_chance` → `damage *= 1.5`, log `rng.choice(player_crits)`
- **Damage reduction** from boss abilities: `damage = max(1, damage - reduction)`
  - Log: `"🛡️ Enemy's defenses reduce {n} damage! ({orig} → {new})"`
- Log: `"⚔️ You attack and deal {damage} damage!"`
- **RNG call order**: fumble check → crit check → crit message choice (if crit)

### 5. Damage Application (`_apply_player_damage_and_animate`)
- `target["health"] -= damage`
- Trigger `_trigger_boss_abilities(target, "hp_threshold")` AFTER damage applied
- Check if target dead

### 6. Post-Hit (`_check_enemy_status_after_damage`)
- If target alive: `check_split_conditions(target)` (split-on-HP threshold)
- If target dead:
  - If `splits_on_death` and not already split → `split_enemy()` → continue to enemy turn
  - Else → `_handle_enemy_defeat(target)` → `_finalize_enemy_defeat(target)`
- `_finalize_enemy_defeat`:
  - Log: `"{name} has been defeated!"`
  - Trigger `_trigger_boss_abilities(target, "on_death")` BEFORE removing
  - If transform_on_death → enemy replaced, continue combat
  - Remove from enemies list
  - If no more enemies → `enemy_defeated()` (rewards)
  - Else → adjust target index, continue to enemy turn

### 7. Enemy Turn (`_start_enemy_turn_sequence`)
1. `_check_boss_ability_triggers("enemy_turn")` — triggers periodic spawns, inflict_status, etc.
2. `process_status_effects()` — poison/bleed/burn/rot deal 5 damage each to player
3. `_apply_burn_damage()` — enemy burn: turn 3→8dmg, turn 2→5dmg, turn 1→2dmg
4. `_check_burn_deaths()` if any enemies died from burn
5. Legacy `combat_poison_damage` (if present)
6. `check_spawn_conditions()` — HP threshold / multi-threshold / turn-count spawns
7. `_announce_enemy_attack()` — enemy dice rolls and attacks

### 8. Enemy Attack (`_announce_enemy_attack` → `_announce_enemy_attacks_sequentially`)
- For each alive enemy (skip if `turn_spawned == combat_turn_count`):
  - Roll dice: `[rng.randint(1, 6) for _ in range(num_dice)]`
  - Log: `"{name} rolls: [{dice_str}]"`
  - Damage: `base = sum(dice) + (floor * 2)`
  - Apply mults: `enemy_damage_mult * player_damage_taken_mult * 0.95`
  - If `floor <= 3`: `*= 1.15`
  - Log: `"⚔️ {name} attacks for {damage} damage!"`
- Just-spawned enemies: log `"{name} is too dazed to attack (just spawned)!"`
- **RNG calls**: `rng.randint(1, 6)` per die per enemy, in order of enemies list
- Note: enemy dice animation also consumes RNG (`rng.randint(1,6)` per die per animation frame × 8 frames) — but this is UI-only

### 9. Damage to Player (`_apply_armor_and_announce_final_damage`)
- Total damage = sum of all enemy damages
- Shield absorb first: `absorbed = min(temp_shield, total_damage)`
  - Log: `"Your shield absorbs {n} damage! (Shield: {left} remaining)"`
- Armor reduction: `reduction = min(armor * 0.15, 0.60)`, `damage *= (1 - reduction)`
  - Log: `"Your armor blocks {n} damage!"`
- Log: `"You take {n} damage!"` or `"All damage blocked!"`

### 10. Death Resolution
- Player: `health <= 0` → `game_over()`
- Enemy burn death: `_check_burn_deaths()` → remove → check if combat ends

### 11. Rewards (`enemy_defeated`)
- Occurs when ALL enemies are defeated
- See `python_rewards_rules.md` for details

## Edge Cases
- Death during curse tick: combat ends immediately, no further processing
- Death during status tick: `game_over()` called, combat ends
- Spawn during enemy turn: spawned enemies skip attack this turn (`turn_spawned == combat_turn_count`)
- Split on death: original removed, splits inserted at same index; target index adjusted
- Transform on death: enemy replaced in-place, triggers `combat_start` abilities for new form
- Split on HP threshold: checked when enemy is alive after damage, prevents split if `has_split` is True
