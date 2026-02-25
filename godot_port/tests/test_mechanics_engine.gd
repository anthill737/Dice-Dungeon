extends GutTest
## Deterministic tests for MechanicsEngine.
## Uses real room data from rooms_v2.json and DeterministicRNG where applicable.

var _engine: MechanicsEngine
var _state: GameState
var _logs: Array


func before_each() -> void:
	_logs = []
	_engine = MechanicsEngine.new(func(msg: String): _logs.append(msg))
	_state = GameState.new()


# ------------------------------------------------------------------
# Helper: build a room dict with mechanics
# ------------------------------------------------------------------

func _room(on_enter: Dictionary = {}, on_clear: Dictionary = {}, on_fail: Dictionary = {}) -> Dictionary:
	return {
		"name": "Test Room",
		"mechanics": {
			"on_enter": on_enter,
			"on_clear": on_clear,
			"on_fail": on_fail,
		}
	}


# ------------------------------------------------------------------
# on_enter effects
# ------------------------------------------------------------------

func test_on_enter_crit_bonus():
	# Room 1: Whispering Antechamber -> on_enter: crit_bonus 0.02
	var room := _room({"crit_bonus": 0.02})
	_engine.apply_on_enter(_state, room)
	assert_true(_state.temp_effects.has("crit_bonus"), "should have crit_bonus temp effect")
	assert_almost_eq(_state.temp_effects["crit_bonus"]["delta"], 0.02, 0.001, "delta should be 0.02")
	assert_eq(_state.temp_effects["crit_bonus"]["duration"], "combat", "default duration is combat")


func test_on_enter_extra_rolls():
	# Room 5: Lantern Row -> on_enter: extra_rolls 1
	var room := _room({"extra_rolls": 1})
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.temp_effects["extra_rolls"]["delta"], 1)


func test_on_enter_shield():
	var room := _room({"shield": 10})
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.temp_shield, 10, "shield should be applied")
	assert_true(_logs.has("+10 Shield"), "should log shield gain")


func test_on_enter_escape_token():
	var room := _room({"escape_token": true})
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.flags["escape_token"], 1)
	assert_true(_logs.has("Gained an escape token"))


func test_on_enter_disarm_token():
	var room := _room({"disarm_token": true})
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.flags["disarm_token"], 1)
	assert_true(_logs.has("Gained a disarm token"))


func test_on_enter_cleanse():
	_state.flags["statuses"] = ["poison", "burn"]
	var room := _room({"cleanse": true})
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.flags["statuses"].size(), 0, "statuses should be cleared")
	assert_true(_logs.has("Cleansed all negative statuses"))


func test_on_enter_item_to_ground():
	var room := _room({"item": "Lucky Chip"})
	_engine.apply_on_enter(_state, room)
	assert_true(_state.ground_items.has("Lucky Chip"), "item should be on ground")


# ------------------------------------------------------------------
# on_clear effects
# ------------------------------------------------------------------

func test_on_clear_item():
	# Room 1: Whispering Antechamber -> on_clear: item "Cracked Map Scrap"
	var room := _room({}, {"item": "Cracked Map Scrap"})
	_engine.apply_on_clear(_state, room)
	assert_true(_state.ground_items.has("Cracked Map Scrap"))


func test_on_clear_gold_mult():
	var room := _room({}, {"gold_mult": 0.5})
	_engine.apply_on_clear(_state, room)
	assert_true(_state.temp_effects.has("gold_mult"))
	assert_almost_eq(_state.temp_effects["gold_mult"]["delta"], 0.5, 0.001)


# ------------------------------------------------------------------
# on_fail effects
# ------------------------------------------------------------------

func test_on_fail_status():
	# Room 5: Lantern Row -> on_fail: status "soot-choke"
	var room := _room({}, {}, {"status": "soot-choke"})
	_engine.apply_on_fail(_state, room)
	assert_true(_state.flags["statuses"].has("soot-choke"))


func test_on_fail_status_no_duplicate():
	_state.flags["statuses"] = ["soot-choke"]
	var room := _room({}, {}, {"status": "soot-choke"})
	_engine.apply_on_fail(_state, room)
	assert_eq(_state.flags["statuses"].size(), 1, "should not duplicate status")


# ------------------------------------------------------------------
# Empty / missing mechanics
# ------------------------------------------------------------------

func test_no_mechanics_key():
	var room := {"name": "Empty Room"}
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.temp_effects.size(), 0, "no effects on room without mechanics")
	assert_eq(_logs.size(), 0)


func test_empty_mechanics():
	var room := {"name": "Boring Room", "mechanics": {}}
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.temp_effects.size(), 0)


func test_null_phase():
	var room := {"name": "Partial Room", "mechanics": {"on_enter": null, "on_clear": {"item": "Sword"}}}
	_engine.apply_on_enter(_state, room)
	assert_eq(_state.temp_effects.size(), 0)
	_engine.apply_on_clear(_state, room)
	assert_true(_state.ground_items.has("Sword"))


# ------------------------------------------------------------------
# Stacking temp effects
# ------------------------------------------------------------------

func test_temp_effects_stack():
	var room_a := _room({"crit_bonus": 0.02})
	var room_b := _room({"crit_bonus": 0.03})
	_engine.apply_on_enter(_state, room_a)
	_engine.apply_on_enter(_state, room_b)
	assert_almost_eq(_state.temp_effects["crit_bonus"]["delta"], 0.05, 0.001, "crit bonuses should stack")


func test_multiple_shield_stacks():
	var room_a := _room({"shield": 5})
	var room_b := _room({"shield": 7})
	_engine.apply_on_enter(_state, room_a)
	_engine.apply_on_enter(_state, room_b)
	assert_eq(_state.temp_shield, 12, "shields should stack")


# ------------------------------------------------------------------
# settle_temp_effects
# ------------------------------------------------------------------

func test_settle_after_combat():
	_state.temp_effects["crit_bonus"] = {"delta": 0.05, "duration": "combat"}
	_state.temp_effects["gold_mult"] = {"delta": 0.5, "duration": "floor"}
	_engine.settle_temp_effects(_state, "after_combat")
	assert_false(_state.temp_effects.has("crit_bonus"), "combat-duration effect should be removed")
	assert_true(_state.temp_effects.has("gold_mult"), "floor-duration effect should remain")


func test_settle_floor_transition():
	_state.temp_effects["crit_bonus"] = {"delta": 0.05, "duration": "combat"}
	_state.temp_effects["gold_mult"] = {"delta": 0.5, "duration": "floor"}
	_state.temp_shield = 10
	_state.shop_discount = 0.15
	_engine.settle_temp_effects(_state, "floor_transition")
	assert_eq(_state.temp_effects.size(), 0, "all temp effects cleared on floor transition")
	assert_eq(_state.temp_shield, 0, "shield reset on floor transition")
	assert_almost_eq(_state.shop_discount, 0.0, 0.001, "shop discount reset")


# ------------------------------------------------------------------
# get_effective_stats
# ------------------------------------------------------------------

func test_effective_stats_empty():
	var stats := _engine.get_effective_stats(_state)
	assert_eq(stats["crit_bonus"], 0.0)
	assert_eq(stats["damage_bonus"], 0)
	assert_eq(stats["extra_rolls"], 0)
	assert_eq(stats["temp_shield"], 0)
	assert_false(stats["has_disarm"])
	assert_false(stats["has_escape"])
	assert_eq(stats["statuses"].size(), 0)


func test_effective_stats_with_effects():
	_state.temp_effects["crit_bonus"] = {"delta": 0.05, "duration": "combat"}
	_state.temp_effects["damage_bonus"] = {"delta": 3, "duration": "combat"}
	_state.flags["disarm_token"] = 1
	_state.temp_shield = 8
	var stats := _engine.get_effective_stats(_state)
	assert_almost_eq(float(stats["crit_bonus"]), 0.05, 0.001)
	assert_eq(stats["damage_bonus"], 3)
	assert_eq(stats["temp_shield"], 8)
	assert_true(stats["has_disarm"])


# ------------------------------------------------------------------
# apply_effective_modifiers
# ------------------------------------------------------------------

func test_apply_effective_modifiers():
	_state.crit_chance = 0.1
	_state.damage_bonus = 5
	_state.multiplier = 1.0
	_state.temp_effects["crit_bonus"] = {"delta": 0.05, "duration": "combat"}
	_state.temp_effects["damage_bonus"] = {"delta": 3, "duration": "combat"}
	_state.temp_effects["gold_mult"] = {"delta": 0.25, "duration": "floor"}
	var mods := _engine.apply_effective_modifiers(_state)
	assert_almost_eq(float(mods["crit"]), 0.15, 0.001, "base 0.1 + temp 0.05")
	assert_eq(mods["damage_bonus"], 8, "base 5 + temp 3")
	assert_almost_eq(float(mods["gold_mult"]), 1.25, 0.001, "1.0 * (1.0 + 0.25)")


# ------------------------------------------------------------------
# Real room data integration
# ------------------------------------------------------------------

func test_real_room_whispering_antechamber():
	# Room id=1: on_enter crit_bonus 0.02, on_clear item Cracked Map Scrap
	var rooms := RoomsData.new()
	assert_true(rooms.load(), "should load rooms")
	var room: Dictionary = {}
	for r in rooms.rooms:
		if r["id"] == 1:
			room = r
			break
	assert_eq(room["name"], "Whispering Antechamber")

	_engine.apply_on_enter(_state, room)
	assert_almost_eq(_state.temp_effects["crit_bonus"]["delta"], 0.02, 0.001)

	_engine.apply_on_clear(_state, room)
	assert_true(_state.ground_items.has("Cracked Map Scrap"))


func test_real_room_lantern_row():
	# Room id=5: on_enter extra_rolls 1, on_fail status soot-choke
	var rooms := RoomsData.new()
	rooms.load()
	var room: Dictionary = {}
	for r in rooms.rooms:
		if r["id"] == 5:
			room = r
			break
	assert_eq(room["name"], "Lantern Row")

	_engine.apply_on_enter(_state, room)
	assert_eq(_state.temp_effects["extra_rolls"]["delta"], 1)

	_engine.apply_on_fail(_state, room)
	assert_true(_state.flags["statuses"].has("soot-choke"))


func test_real_room_full_lifecycle():
	# Simulate: enter room with crit bonus -> combat -> settle -> floor transition
	var room := _room({"crit_bonus": 0.03, "shield": 5}, {"item": "Old Key"})

	# Enter
	_engine.apply_on_enter(_state, room)
	assert_almost_eq(_state.temp_effects["crit_bonus"]["delta"], 0.03, 0.001)
	assert_eq(_state.temp_shield, 5)

	# Effective stats during combat
	var mods := _engine.apply_effective_modifiers(_state)
	assert_almost_eq(float(mods["crit"]), 0.13, 0.001, "0.10 + 0.03")

	# Clear combat
	_engine.apply_on_clear(_state, room)
	assert_true(_state.ground_items.has("Old Key"))

	# Settle after combat
	_engine.settle_temp_effects(_state, "after_combat")
	assert_false(_state.temp_effects.has("crit_bonus"), "combat effect expired")

	# Floor transition
	_engine.settle_temp_effects(_state, "floor_transition")
	assert_eq(_state.temp_shield, 0)


# ------------------------------------------------------------------
# Deterministic RNG integration (proves engine + RNG compose)
# ------------------------------------------------------------------

func test_deterministic_room_sequence():
	# Use DeterministicRNG to pick rooms and verify mechanics apply identically
	var rooms_data := RoomsData.new()
	rooms_data.load()

	var rng_a := DeterministicRNG.new(42)
	var rng_b := DeterministicRNG.new(42)

	var results_a := _simulate_room_sequence(rooms_data.rooms, rng_a)
	var results_b := _simulate_room_sequence(rooms_data.rooms, rng_b)

	assert_eq(results_a, results_b, "same seed should produce identical room effect sequences")


func _simulate_room_sequence(rooms: Array, rng: RNG) -> Array:
	var results: Array = []
	var state := GameState.new()
	var engine := MechanicsEngine.new()

	for i in 5:
		var room: Dictionary = rng.choice(rooms)
		engine.apply_on_enter(state, room)
		var stats := engine.get_effective_stats(state)
		results.append({
			"room": room["name"],
			"crit": stats["crit_bonus"],
			"dmg": stats["damage_bonus"],
			"shield": stats["temp_shield"],
			"statuses": stats["statuses"].duplicate(),
			"ground_items": state.ground_items.duplicate(),
		})
		engine.settle_temp_effects(state, "after_combat")

	return results
