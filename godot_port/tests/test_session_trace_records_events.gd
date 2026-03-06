extends GutTest
## Verifies SessionTrace records structured events in the correct order.
## Uses DeterministicRNG so all exploration/combat outcomes are reproducible.


func _make_session() -> Dictionary:
	var rng := DeterministicRNG.new(42)
	var gs := GameState.new()
	gs.reset()
	gs.health = 100
	gs.max_health = 100

	var rd := RoomsData.new()
	rd.load()
	var id := ItemsData.new()
	id.load()
	var ed := EnemyTypesData.new()
	ed.load()

	var exploration := ExplorationEngine.new(rng, gs, rd.rooms)
	var inventory := InventoryEngine.new(rng, gs, id.items)
	var combat_engine: CombatEngine = null

	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG")
	trace.difficulty = "Normal"

	return {
		"rng": rng,
		"gs": gs,
		"exploration": exploration,
		"inventory": inventory,
		"combat_engine": combat_engine,
		"trace": trace,
		"rooms_db": rd.rooms,
		"items_db": id.items,
		"enemy_types_db": ed.enemies,
	}


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func _event_types(trace: SessionTrace) -> Array:
	var types: Array = []
	for ev in trace.events:
		types.append(str(ev.get("type", "")))
	return types


# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------

func test_run_started_is_first_event():
	var s := _make_session()
	var trace: SessionTrace = s["trace"]
	trace.record("run_started", {"difficulty": "Normal"})

	assert_eq(trace.events.size(), 1, "should have 1 event")
	assert_eq(trace.events[0]["type"], "run_started")
	assert_true(trace.events[0].has("t_ms"), "event should have t_ms")
	assert_true(trace.events[0].has("floor"), "event should have floor")
	assert_true(trace.events[0].has("coord"), "event should have coord")
	assert_true(trace.events[0].has("payload"), "event should have payload")


func test_reset_clears_events():
	var trace := SessionTrace.new()
	trace.record("test_event", {})
	trace.record("test_event", {})
	assert_eq(trace.events.size(), 2)
	trace.reset(99, "PortableLCG")
	assert_eq(trace.events.size(), 0, "reset should clear events")
	assert_eq(trace.rng_type, "PortableLCG")
	assert_eq(trace.seed_value, 99)


func test_run_id_unique_on_reset():
	var trace := SessionTrace.new()
	var first_id := trace.run_id
	trace.reset()
	var second_id := trace.run_id
	assert_ne(first_id, second_id, "each reset should produce a new run_id")


func test_floor_and_coord_tracking():
	var trace := SessionTrace.new()
	trace.set_floor(3)
	trace.set_coord(Vector2i(5, -2))
	trace.record("test_event", {})
	assert_eq(trace.events[0]["floor"], 3)
	assert_eq(trace.events[0]["coord"], [5, -2])


func test_exploration_events_order():
	var s := _make_session()
	var trace: SessionTrace = s["trace"]
	var exploration: ExplorationEngine = s["exploration"]
	var gs: GameState = s["gs"]

	trace.record("run_started", {"difficulty": "Normal"})

	exploration.start_floor(1)
	exploration.logs.clear()
	trace.set_floor(1)
	trace.set_coord(exploration.floor.current_pos)

	var directions := ["N", "E", "S", "N"]
	var moved := 0
	for dir in directions:
		var room := exploration.move(dir)
		exploration.logs.clear()
		if room != null:
			trace.set_coord(exploration.floor.current_pos)
			trace.record("move_attempted", {"dir": dir, "success": true})
			trace.record("room_entered", {
				"room_name": room.data.get("name", "?"),
				"has_combat": room.has_combat,
			})
			if room.has_combat and not room.enemies_defeated:
				trace.record("combat_pending_started", {})
			moved += 1
		else:
			trace.record("move_attempted", {"dir": dir, "success": false, "reason": "blocked"})

	assert_gt(trace.events.size(), 1, "should have multiple events")

	var types := _event_types(trace)
	assert_true(types.has("run_started"), "must have run_started")
	assert_true(types.has("move_attempted"), "must have move_attempted")

	if moved > 0:
		assert_true(types.has("room_entered"), "must have room_entered for successful moves")


func test_combat_events_sequence():
	var s := _make_session()
	var trace: SessionTrace = s["trace"]
	var rng: DeterministicRNG = s["rng"]
	var gs: GameState = s["gs"]
	var enemy_types_db: Dictionary = s["enemy_types_db"]

	trace.record("run_started", {})

	trace.record("combat_pending_started", {})

	var ce := CombatEngine.new(rng, gs, 3, enemy_types_db)
	ce.add_enemy("Goblin", 20, 2)
	trace.record("combat_started", {
		"enemies": [{"name": "Goblin", "hp": 20, "dice": 2}],
	})

	ce.player_roll()
	trace.record("dice_rolled", {"values": ce.dice.values.duplicate()})

	var turn := ce.player_attack(0)
	trace.record("attack_committed", {
		"target": turn.target_name,
		"damage": turn.player_damage,
		"combo": ce.dice.calc_combo_bonus(),
	})
	for er in turn.enemy_rolls:
		trace.record("enemy_attack", {
			"enemy": str(er.get("name", "")),
			"damage": int(er.get("damage", 0)),
		})

	var types := _event_types(trace)
	assert_true(types.has("run_started"))
	assert_true(types.has("combat_pending_started"))
	assert_true(types.has("combat_started"))
	assert_true(types.has("dice_rolled"))
	assert_true(types.has("attack_committed"))
	assert_true(types.has("enemy_attack"))

	var started_idx := types.find("combat_started")
	var rolled_idx := types.find("dice_rolled")
	var attack_idx := types.find("attack_committed")
	assert_lt(started_idx, rolled_idx, "combat_started before dice_rolled")
	assert_lt(rolled_idx, attack_idx, "dice_rolled before attack_committed")


func test_payload_contains_expected_keys():
	var trace := SessionTrace.new()
	trace.record("room_entered", {
		"room_name": "Dark Passage",
		"room_type": "Easy",
		"tags": ["combat"],
		"has_combat": true,
		"chest": false,
		"store": false,
		"stairs": false,
		"miniboss": false,
		"boss": false,
		"blocked_exits": ["S"],
	})
	var ev: Dictionary = trace.events[0]
	var p: Dictionary = ev["payload"]
	assert_eq(p["room_name"], "Dark Passage")
	assert_eq(p["has_combat"], true)
	assert_eq(p["blocked_exits"], ["S"])


func test_event_timestamps_increase():
	var trace := SessionTrace.new()
	trace.record("a", {})
	OS.delay_msec(5)
	trace.record("b", {})
	OS.delay_msec(5)
	trace.record("c", {})
	var t0: int = trace.events[0]["t_ms"]
	var t1: int = trace.events[1]["t_ms"]
	var t2: int = trace.events[2]["t_ms"]
	assert_lte(t0, t1, "timestamps should be non-decreasing")
	assert_lte(t1, t2, "timestamps should be non-decreasing")
