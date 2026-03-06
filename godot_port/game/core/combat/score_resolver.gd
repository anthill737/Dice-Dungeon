class_name ScoreResolver
extends RefCounted
## Deterministic scoring — mirrors Python run_score logic exactly.
## Score is computed from authoritative run state; UI never computes score directly.
## Scoring does NOT consume RNG calls.

## Score awards — Python combat.py parity
const BOSS_KILL_BASE := 1000
const BOSS_KILL_PER_FLOOR := 200
const MINIBOSS_KILL_BASE := 500
const MINIBOSS_KILL_PER_FLOOR := 50
const NORMAL_KILL_BASE := 100
const NORMAL_KILL_PER_FLOOR := 20
const FLOOR_DESCENT_MULT := 100
const VICTORY_BONUS := 5000


## Award score for defeating a normal enemy.
static func score_normal_kill(floor_num: int) -> int:
	return NORMAL_KILL_BASE + (floor_num * NORMAL_KILL_PER_FLOOR)


## Award score for defeating a mini-boss.
static func score_miniboss_kill(floor_num: int) -> int:
	return MINIBOSS_KILL_BASE + (floor_num * MINIBOSS_KILL_PER_FLOOR)


## Award score for defeating a floor boss.
static func score_boss_kill(floor_num: int) -> int:
	return BOSS_KILL_BASE + (floor_num * BOSS_KILL_PER_FLOOR)


## Award score for descending to a new floor.
static func score_floor_descent(new_floor: int) -> int:
	return FLOOR_DESCENT_MULT * new_floor


## Victory bonus for completing the dungeon.
static func score_victory() -> int:
	return VICTORY_BONUS
