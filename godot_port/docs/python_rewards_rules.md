# Python Rewards Rules (Authoritative Reference)

Extracted from `explorer/combat.py` — `enemy_defeated()`.

## Reward Timing
- Rewards are granted in `enemy_defeated()`, called when ALL enemies are defeated
- After `_finalize_enemy_defeat()` removes last enemy → `enemy_defeated()`
- Rewards happen BEFORE `complete_room_success()` (which applies room on_clear mechanics)

## Reward Composition by Enemy Type

### Boss Rewards
```python
gold_reward = rng.randint(200, 350) + (floor * 100)
gold += gold_reward
total_gold_earned += gold_reward
stats["gold_found"] += gold_reward
run_score += 1000 + (floor * 200)
```

**Items**: 3–5 items from rare pool:
```python
rare_equipment = [
    "Greatsword", "War Axe", "Assassin's Blade",
    "Plate Armor", "Dragon Scale", "Enchanted Cloak",
    "Greater Health Potion", "Greater Health Potion", "Greater Health Potion",
    "Strength Elixir", "Strength Elixir"
]
num_rewards = rng.randint(3, 5)
for _ in range(num_rewards):
    boss_drop = rng.choice(rare_equipment)
    try_add_to_inventory(boss_drop, "reward")
```

**Log messages** (in order):
1. `"{'='*60}"` (category: success)
2. `"☠ FLOOR BOSS DEFEATED! ☠"` (success)
3. `"+{gold} gold!"` (loot)
4. Item grant messages
5. `"[BOSS DEFEATED] The path forward is clear!"` (success)
6. `"[STAIRS] Continue exploring to find the stairs to the next floor."` (system)
7. `"{'='*60}"` (success)

**RNG calls**: `rng.randint(200, 350)`, `rng.randint(3, 5)`, then `rng.choice(rare_equipment)` × num_rewards

### Mini-Boss Rewards
```python
gold_reward = rng.randint(50, 80) + (floor * 20)
gold += gold_reward
total_gold_earned += gold_reward
stats["gold_found"] += gold_reward
run_score += 500 + (floor * 50)
```

**Key Fragment**: Always grants +1 Boss Key Fragment
```python
key_fragments_collected += 1
```

**Items**: 1 item from floor-scaled pool:
```python
# Floor >= 8 (high)
useful_loot = [
    "Greater Health Potion", "Greater Health Potion",
    "Strength Elixir",
    "Greatsword", "War Axe", "Assassin's Blade",
    "Plate Armor", "Dragon Scale", "Enchanted Cloak"
]
# Floor >= 5 (mid)
useful_loot = [
    "Health Potion", "Greater Health Potion",
    "Strength Elixir",
    "Iron Sword", "Battle Axe", "Steel Sword",
    "Chain Vest", "Scale Mail", "Iron Shield"
]
# Floor < 5 (early)
useful_loot = [
    "Health Potion", "Health Potion",
    "Strength Elixir",
    "Steel Dagger", "Iron Sword", "Hand Axe",
    "Leather Armor", "Chain Vest", "Wooden Shield"
]
bonus_loot = rng.choice(useful_loot)
try_add_to_inventory(bonus_loot, "reward")
```

**Log messages** (in order):
1. `"Mini-boss defeated!"` (success)
2. `"+{gold} gold!"` (loot)
3. `"Obtained Boss Key Fragment! ({n}/3)"` (loot)
4. Item grant message

**RNG calls**: `rng.randint(50, 80)`, `rng.choice(useful_loot)`

### Normal Enemy Rewards
```python
gold_reward = rng.randint(10, 30) + (floor * 5)
gold += gold_reward
total_gold_earned += gold_reward
stats["gold_found"] += gold_reward
run_score += 100 + (floor * 20)
```

**Log messages**:
1. `"+{gold} gold!"` (loot)

**RNG calls**: `rng.randint(10, 30)`

## Pre-Reward Processing
Before rewards, in `enemy_defeated()`:
1. `in_combat = False`
2. `enemies_killed += 1`
3. Clear status effects: `flags['statuses'] = []`
4. Track stats: `stats["enemies_defeated"] += 1`, `enemy_kills[name] += 1`
5. If mini-boss: `stats["mini_bosses_defeated"] += 1`
6. If boss: `stats["bosses_defeated"] += 1`
7. Enemy death flavor text: `rng.choice(enemy_death[type])` (if available)
8. `clear_combat_buffs()`

**RNG calls before rewards**: `rng.choice(enemy_death[type])` if applicable

## Post-Reward Processing
After rewards, in `enemy_defeated()`:
1. Reset `is_boss_fight = False`
2. `complete_room_success(game, log)` → applies room on_clear mechanics
3. `update_display()`, `show_exploration_options()`

## Mini-Boss Counting
```python
mini_bosses_defeated += 1
if mini_bosses_defeated == 3:
    next_boss_at = rooms_explored_on_floor + rng.randint(4, 6)
    log("The floor boss will appear soon...", 'enemy')
```

## Room Clear Mechanics (`apply_on_clear`)
Applied after combat rewards via `complete_room_success`:
- `gold_flat`: add flat gold
- `gold_mult`: temp effect multiplier
- `item`: add item to ground_items
- `heal`: heal player
- Other mechanics from `rooms_v2.json`

## Score Formulas
| Type | Score |
|---|---|
| Normal | `100 + (floor * 20)` |
| Mini-boss | `500 + (floor * 50)` |
| Boss | `1000 + (floor * 200)` |

## Gold Multiplier
Gold earned is NOT explicitly multiplied by `gold_mult` temp effect in `enemy_defeated()`.
The `gold_mult` effect applies elsewhere (e.g., chest loot).

## Save/Load Persistence
- `gold`, `total_gold_earned`, `inventory`, `key_fragments_collected` all persist in save data
- `stats` dictionary persists
- `run_score` persists
