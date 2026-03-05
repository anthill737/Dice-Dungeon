class_name CombatTrace
extends RefCounted
## Structured trace events for combat debugging.
##
## Emits high-signal events at the same semantic level as Python logs.
## Additive only — never breaks existing behaviour.

# ------------------------------------------------------------------
# Event constructors
# ------------------------------------------------------------------

static func combat_phase_started(phase: String, round_num: int, turn: int, action_id: String = "") -> Dictionary:
	return {
		"event": "combat_phase_started",
		"phase": phase,
		"round": round_num,
		"turn": turn,
		"action_id": action_id,
	}

static func ability_triggered(enemy_id: String, ability_id: String, phase: String,
		target: String = "", rng_rolls: Array = []) -> Dictionary:
	return {
		"event": "ability_triggered",
		"enemy_id": enemy_id,
		"ability_id": ability_id,
		"phase": phase,
		"target": target,
		"rng_rolls": rng_rolls,
	}

static func effect_applied(effect_id: String, target: String, amount: int,
		duration_before: int = -1, duration_after: int = -1) -> Dictionary:
	return {
		"event": "effect_applied",
		"effect_id": effect_id,
		"target": target,
		"amount": amount,
		"duration_before": duration_before,
		"duration_after": duration_after,
	}

static func effect_ticked(effect_id: String, target: String, amount: int,
		duration_before: int = -1, duration_after: int = -1) -> Dictionary:
	return {
		"event": "effect_ticked",
		"effect_id": effect_id,
		"target": target,
		"amount": amount,
		"duration_before": duration_before,
		"duration_after": duration_after,
	}

static func effect_expired(effect_id: String, target: String) -> Dictionary:
	return {
		"event": "effect_expired",
		"effect_id": effect_id,
		"target": target,
	}

static func enemy_spawned(source_enemy_id: String, spawned_enemy_ids: Array) -> Dictionary:
	return {
		"event": "enemy_spawned",
		"source_enemy_id": source_enemy_id,
		"spawned_enemy_ids": spawned_enemy_ids,
	}

static func rewards_granted(gold_delta: int, items: Array, reason: String) -> Dictionary:
	return {
		"event": "rewards_granted",
		"gold_delta": gold_delta,
		"items": items,
		"reason": reason,
	}

static func player_attack_resolved(damage: int, was_crit: bool, was_fumble: bool,
		target: String, target_killed: bool) -> Dictionary:
	return {
		"event": "player_attack_resolved",
		"damage": damage,
		"was_crit": was_crit,
		"was_fumble": was_fumble,
		"target": target,
		"target_killed": target_killed,
	}

static func enemy_attack_resolved(enemy_name: String, dice: Array,
		damage: int) -> Dictionary:
	return {
		"event": "enemy_attack_resolved",
		"enemy_name": enemy_name,
		"dice": dice,
		"damage": damage,
	}
