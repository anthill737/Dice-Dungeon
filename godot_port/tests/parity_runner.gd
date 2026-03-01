class_name ParityRunner
extends RefCounted
## Godot-side parity runner.
## Runs the same scenarios as tools/parity/python_runner.py using pre-scripted
## dice values so results are directly comparable despite different PRNG algorithms.


static func run_scenario(scenario_id: String, seed_val: int) -> Dictionary:
	match scenario_id:
		"S1": return _scenario_s1(seed_val)
		"S2": return _scenario_s2(seed_val)
		"S3": return _scenario_s3(seed_val)
		_:
			push_error("ParityRunner: unknown scenario '%s'" % scenario_id)
			return {}


# ------------------------------------------------------------------
# S1: Dice roll/lock/reroll + damage calculation
# ------------------------------------------------------------------

static func _scenario_s1(seed_val: int) -> Dictionary:
	var rng := DeterministicRNG.new(seed_val)
	var dr := DiceRoller.new(rng, 3, 3)

	# Scripted values (matching Python)
	var dice_roll1: Array[int] = [2, 6, 5]
	dr.values = dice_roll1.duplicate()

	var combo_r1 := dr.calc_combo_bonus()
	var damage_r1 := dr.calc_total_damage(1.0, 0)

	# Lock indices 1, 2
	dr.lock(1)
	dr.lock(2)

	# Scripted reroll: first die becomes 4
	var dice_roll2: Array[int] = [4, 6, 5]
	dr.values = dice_roll2.duplicate()

	var combo_r2 := dr.calc_combo_bonus()
	var damage_r2 := dr.calc_total_damage(1.0, 0)
	var damage_r2_boosted := dr.calc_total_damage(1.5, 3)

	return {
		"scenario_id": "S1",
		"seed": seed_val,
		"initial_state": {"dice": [0, 0, 0]},
		"actions": [
			{"action": "roll", "result": dice_roll1},
			{"action": "lock", "indices": [1, 2]},
			{"action": "roll", "result": dice_roll2},
		],
		"final_state": {
			"dice_after_roll1": dice_roll1,
			"combo_roll1": combo_r1,
			"damage_roll1": damage_r1,
			"dice_after_roll2": dice_roll2,
			"combo_roll2": combo_r2,
			"damage_roll2": damage_r2,
			"damage_roll2_boosted": damage_r2_boosted,
		},
		"log": [
			"Roll 1: %s, combo=%d, damage=%d" % [str(dice_roll1), combo_r1, damage_r1],
			"Locked indices [1, 2]",
			"Roll 2: %s, combo=%d, damage=%d" % [str(dice_roll2), combo_r2, damage_r2],
			"Boosted (mult=1.5, bonus=3): %d" % damage_r2_boosted,
		],
	}


# ------------------------------------------------------------------
# S2: Mechanics effects on enter/clear
# ------------------------------------------------------------------

static func _scenario_s2(seed_val: int) -> Dictionary:
	var state := GameState.new()
	state.health = 50
	state.max_health = 50
	state.crit_chance = 0.1
	state.damage_bonus = 0
	state.temp_shield = 0

	var initial_state := {
		"health": 50,
		"max_health": 50,
		"crit_chance": 0.1,
		"damage_bonus": 0,
		"temp_shield": 0,
		"temp_effects": {},
		"statuses": [],
		"ground_items": [],
		"disarm_token": 0,
		"escape_token": 0,
	}

	var room := {
		"name": "Test Chamber",
		"mechanics": {
			"on_enter": {"crit_bonus": 0.05, "shield": 8, "extra_rolls": 1},
			"on_clear": {"item": "Old Key", "escape_token": true},
			"on_fail": {"status": "poison"},
		},
	}

	var logs: Array = []
	var engine := MechanicsEngine.new(func(msg: String): logs.append(msg))

	# on_enter
	engine.apply_on_enter(state, room)

	var state_after_enter := {
		"temp_effects": _clone_temp_effects(state.temp_effects),
		"temp_shield": state.temp_shield,
		"ground_items": state.ground_items.duplicate(),
	}

	# on_clear
	engine.apply_on_clear(state, room)

	return {
		"scenario_id": "S2",
		"seed": seed_val,
		"initial_state": initial_state,
		"actions": [
			{"action": "apply_on_enter", "effects": room["mechanics"]["on_enter"]},
			{"action": "apply_on_clear", "effects": room["mechanics"]["on_clear"]},
		],
		"final_state": {
			"temp_effects": _clone_temp_effects(state.temp_effects),
			"temp_shield": state.temp_shield,
			"ground_items": state.ground_items.duplicate(),
			"escape_token": int(state.flags.get("escape_token", 0)),
			"statuses": state.flags.get("statuses", []).duplicate(),
			"state_after_enter": state_after_enter,
		},
		"log": logs,
	}


# ------------------------------------------------------------------
# S3: 1-enemy combat, 2 turns, scripted dice
# ------------------------------------------------------------------

static func _scenario_s3(seed_val: int) -> Dictionary:
	var enemy_hp := 40
	var player_hp := 50
	var damage_bonus := 0
	var multiplier := 1.0
	var rng := DeterministicRNG.new(seed_val)
	var dr := DiceRoller.new(rng, 3, 3)

	var scripted_turns := [
		{"player_dice": [5, 6, 4], "enemy_dice": [3, 2]},
		{"player_dice": [6, 6, 3], "enemy_dice": [5, 1]},
	]

	var current_enemy_hp := enemy_hp
	var current_player_hp := player_hp
	var turn_results: Array = []
	var logs: Array = []

	for i in scripted_turns.size():
		var turn: Dictionary = scripted_turns[i]
		var pd: Array = turn["player_dice"]
		var ed: Array = turn["enemy_dice"]

		dr.values = [pd[0], pd[1], pd[2]]
		var p_combo := dr.calc_combo_bonus()
		var p_damage := dr.calc_total_damage(multiplier, damage_bonus)
		current_enemy_hp -= p_damage
		var enemy_killed := current_enemy_hp <= 0

		var e_damage := 0
		if not enemy_killed:
			for d in ed:
				e_damage += int(d)
			current_player_hp -= e_damage

		var turn_result := {
			"turn": i + 1,
			"player_dice": pd,
			"player_combo": p_combo,
			"player_damage": p_damage,
			"enemy_dice": ed,
			"enemy_damage": e_damage,
			"enemy_hp_after": maxi(0, current_enemy_hp),
			"player_hp_after": current_player_hp,
			"enemy_killed": enemy_killed,
		}
		turn_results.append(turn_result)
		logs.append("Turn %d: player %s=%ddmg, enemy %s=%ddmg" % [
			i + 1, str(pd), p_damage, str(ed), e_damage])

		if enemy_killed:
			logs.append("Enemy defeated on turn %d" % (i + 1))
			break

	return {
		"scenario_id": "S3",
		"seed": seed_val,
		"initial_state": {
			"player_hp": player_hp,
			"enemy_hp": enemy_hp,
			"enemy_dice": 2,
		},
		"actions": turn_results.map(func(t): return {
			"turn": t["turn"],
			"player_dice": t["player_dice"],
			"enemy_dice": t["enemy_dice"],
		}),
		"final_state": {
			"player_hp": current_player_hp,
			"enemy_hp": maxi(0, current_enemy_hp),
			"enemy_killed": current_enemy_hp <= 0,
			"turns_played": turn_results.size(),
			"turn_results": turn_results,
		},
		"log": logs,
	}


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

static func _clone_temp_effects(te: Dictionary) -> Dictionary:
	var clone := {}
	for key in te:
		var entry: Dictionary = te[key]
		clone[key] = {"delta": entry["delta"], "duration": entry["duration"]}
	return clone
