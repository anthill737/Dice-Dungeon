# Python Enemy Stats Rules — Authoritative Reference

Source: `explorer/combat.py` lines 354–469

## HP Source

Enemy HP is NOT defined in `enemy_types.json`. It is calculated at runtime in
`trigger_combat()`. The JSON only contains behavior data (abilities, splits, spawning).

## HP Calculation Formula

```
base_hp = 50 + (floor * 10)
multiplier = lookup enemy_hp_multipliers dict (partial name match, default 1.0)
base_hp = int(base_hp * multiplier)
enemy_hp = base_hp + rng.randint(-5, 10)          # random variation
if is_boss:      enemy_hp = int(enemy_hp * 8.0)
elif is_mini_boss: enemy_hp = int(enemy_hp * 3.0)
enemy_hp = int(enemy_hp * difficulty_multipliers[difficulty]["enemy_health_mult"])
enemy_hp = int(enemy_hp * dev_config["enemy_hp_mult"])   # always 1.0 in normal play
```

## Enemy HP Multipliers (partial name match, first match wins)

| Key | Mult | Category |
|-----|------|----------|
| Goblin | 0.7 | Regular |
| Spider | 0.6 | Regular |
| Bat | 0.5 | Regular |
| Grub | 0.4 | Regular |
| Slime | 0.8 | Regular |
| Skeleton | 1.0 | Regular |
| Orc | 1.0 | Regular |
| Troll | 1.5 | Regular |
| Ogre | 1.4 | Regular |
| Knight | 1.3 | Regular |
| Demon | 2.0 | Elite |
| Dragon | 2.5 | Elite |
| Crystal Golem | 1.8 | Boss |
| Gelatinous Slime | 1.3 | Mini-boss |
| (status enemies) | 1.375 | Status-effect enemies |
| (default) | 1.0 | Unmatched names |

Full table in `explorer/combat.py` lines 360–396.

## Dice Count

```
if is_boss:      dice = min(5 + floor//2, 8)
elif is_mini_boss: dice = min(4 + floor//2, 7)
else:            dice = min(3 + floor//2, 6)
```

## Difficulty Multipliers (enemy_health_mult)

| Difficulty | Mult |
|------------|------|
| Easy | 0.7 |
| Normal | 1.0 |
| Hard | 1.3 |
| Nightmare (Brutal) | 1.8 |

## Sample Values (Floor 1, Normal, no dev mult)

| Enemy | Mult | base_hp | After mult | HP range |
|-------|------|---------|-----------|----------|
| Goblin | 0.7 | 60 | 42 | 37–52 |
| Skeleton | 1.0 | 60 | 60 | 55–70 |
| Ogre | 1.4 | 60 | 84 | 79–94 |
| Dragon | 2.5 | 60 | 150 | 145–160 |

## Spawn/Split HP

Spawned minions: `int(spawner.max_health * spawn_hp_mult)`, min 10, then × difficulty.
Split enemies: `int(original.max_health * split_hp_percent)`, min 10.
Transform on death: `int((50 + floor*10) * hp_mult * 1.5)`, then × difficulty.
