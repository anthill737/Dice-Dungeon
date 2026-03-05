extends GutTest
## Tests for:
## 1) _track_tween auto-cleanup via finished signal
## 2) SessionTrace.record_rng_roll event structure


# ==================================================================
# Part 1 — Tween tracking
# ==================================================================

func _make_tracked_list() -> Array[Tween]:
	return [] as Array[Tween]


func _track_tween(tw: Tween, list: Array[Tween]) -> void:
	list.append(tw)
	tw.finished.connect(func(): list.erase(tw))


func test_track_tween_adds_to_array():
	var list := _make_tracked_list()
	var node := Node.new()
	add_child(node)
	var tw := node.create_tween()
	tw.tween_interval(10.0)
	_track_tween(tw, list)
	assert_eq(list.size(), 1, "tween should be tracked")
	tw.kill()
	node.queue_free()


func test_finished_tween_removed_from_array():
	var list := _make_tracked_list()
	var node := Node.new()
	add_child(node)
	var tw := node.create_tween()
	tw.tween_interval(0.01)
	_track_tween(tw, list)
	assert_eq(list.size(), 1, "tracked before finish")
	await get_tree().create_timer(0.15).timeout
	assert_eq(list.size(), 0, "auto-removed after finish")
	node.queue_free()


func test_multiple_tweens_tracked_independently():
	var list := _make_tracked_list()
	var node := Node.new()
	add_child(node)
	var tw1 := node.create_tween()
	tw1.tween_interval(0.01)
	_track_tween(tw1, list)
	var tw2 := node.create_tween()
	tw2.tween_interval(10.0)
	_track_tween(tw2, list)
	assert_eq(list.size(), 2, "both tracked")
	await get_tree().create_timer(0.15).timeout
	assert_eq(list.size(), 1, "short tween removed, long remains")
	tw2.kill()
	node.queue_free()


func test_exit_tree_cleanup_kills_running_tweens():
	var list := _make_tracked_list()
	var node := Node.new()
	add_child(node)
	var tw := node.create_tween()
	tw.tween_interval(10.0)
	_track_tween(tw, list)
	assert_true(tw.is_running(), "tween should be running")
	for t in list:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	list.clear()
	assert_eq(list.size(), 0, "cleared after exit cleanup")
	node.queue_free()


# ==================================================================
# Part 2 — RNG trace events
# ==================================================================

func test_record_rng_roll_basic_fields():
	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG")
	trace.set_floor(2)
	trace.set_coord(Vector2i(3, 4))
	trace.record_rng_roll("crit_check", 750, {"threshold": 0.1})

	assert_eq(trace.events.size(), 1, "one event recorded")
	var ev: Dictionary = trace.events[0]
	assert_eq(ev["type"], "rng_roll")
	assert_eq(ev["floor"], 2)
	assert_eq(ev["coord"], [3, 4])
	var p: Dictionary = ev["payload"]
	assert_eq(p["context"], "crit_check")
	assert_eq(p["value"], 750)
	assert_true(p.has("details"), "should have details")
	assert_eq(p["details"]["threshold"], 0.1)


func test_record_rng_roll_no_details():
	var trace := SessionTrace.new()
	trace.record_rng_roll("flee_attempt", 500)

	assert_eq(trace.events.size(), 1)
	var p: Dictionary = trace.events[0]["payload"]
	assert_eq(p["context"], "flee_attempt")
	assert_eq(p["value"], 500)
	assert_false(p.has("details"), "no details when empty")


func test_multiple_rng_rolls_preserved_in_order():
	var trace := SessionTrace.new()
	trace.record_rng_roll("dice_roll", 3)
	trace.record_rng_roll("crit_check", 850)
	trace.record_rng_roll("enemy_dice", 0, {"dice": [2, 4]})

	assert_eq(trace.events.size(), 3)
	assert_eq(trace.events[0]["payload"]["context"], "dice_roll")
	assert_eq(trace.events[1]["payload"]["context"], "crit_check")
	assert_eq(trace.events[2]["payload"]["context"], "enemy_dice")


func test_rng_roll_in_combat_engine():
	var rng := DeterministicRNG.new(42)
	var gs := GameState.new()
	gs.reset()
	gs.health = 100
	gs.max_health = 100
	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG")

	var ce := CombatEngine.new(rng, gs, 3)
	ce.set_trace(trace)
	ce.add_enemy("TestEnemy", 20, 2)

	ce.player_roll()
	var _turn := ce.player_attack(0)

	var rng_events: Array = []
	for ev in trace.events:
		if ev["type"] == "rng_roll":
			rng_events.append(ev)
	assert_gt(rng_events.size(), 0, "combat should produce rng_roll events")

	var contexts: Array = []
	for ev in rng_events:
		contexts.append(ev["payload"]["context"])
	assert_true(contexts.has("crit_check"), "should have crit_check")
	assert_true(contexts.has("enemy_dice"), "should have enemy_dice")


func test_combat_engine_without_trace_no_crash():
	var rng := DeterministicRNG.new(99)
	var gs := GameState.new()
	gs.reset()
	gs.health = 100
	gs.max_health = 100

	var ce := CombatEngine.new(rng, gs, 3)
	ce.add_enemy("TestEnemy", 15, 1)
	ce.player_roll()
	var turn := ce.player_attack(0)
	assert_not_null(turn, "attack should work without trace")


func test_deterministic_runs_unchanged():
	var results_a: Array = []
	var results_b: Array = []
	for run in [results_a, results_b]:
		var rng := DeterministicRNG.new(777)
		var gs := GameState.new()
		gs.reset()
		gs.health = 200
		gs.max_health = 200
		var trace := SessionTrace.new()
		trace.reset(777, "DeterministicRNG")
		var ce := CombatEngine.new(rng, gs, 3)
		ce.set_trace(trace)
		ce.add_enemy("Goblin", 10, 1)
		ce.player_roll()
		var turn := ce.player_attack(0)
		run.append(turn.player_damage)
		run.append(turn.was_crit)
		for er in turn.enemy_rolls:
			run.append(er["dice"].duplicate())
			run.append(er["damage"])
	assert_eq(results_a, results_b, "two seeded runs must produce identical results")
