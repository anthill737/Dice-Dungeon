extends "res://addons/gut/test.gd"
## Deterministic tests for combat encounter, pending-choice state,
## flee mechanics, and movement blocking.


# ── helpers ──────────────────────────────────────────────────────────

func _setup_combat_room() -> void:
	GameSession._load_data()
	GameSession.start_new_game()
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}


# ── A) enter combat room => pending, movement blocked, no engine ─────

func test_A_enter_combat_room_pending() -> void:
	_setup_combat_room()

	# Simulate entering the room via _check_combat_pending
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	assert_true(GameSession.combat_pending, "combat_pending is true")
	assert_true(GameSession.is_pending_choice(), "is_pending_choice()")
	assert_true(GameSession.is_combat_blocking(), "movement blocked")
	assert_null(GameSession.combat, "CombatEngine NOT created yet")
	assert_false(GameSession.is_combat_active(), "combat NOT active")

	# Movement should be refused
	var result := GameSession.move_direction("N")
	assert_null(result, "move_direction returns null while pending")


# ── B) flee success => stay same coord, unblocked, escaped ──────────

func test_B_flee_success_stays_in_room() -> void:
	_setup_combat_room()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	var pos_before := GameSession.get_floor_state().current_pos

	# Try flee up to 20 times (50 % chance each, virtually certain to hit)
	var succeeded := false
	for i in 20:
		var flee_result := GameSession.attempt_flee_pending()
		if flee_result.get("success", false):
			succeeded = true
			break
		GameSession.combat_pending = true

	assert_true(succeeded, "Flee succeeded within 20 attempts")

	var pos_after := GameSession.get_floor_state().current_pos
	assert_eq(pos_after, pos_before, "Player stays in same coord")
	assert_false(GameSession.combat_pending, "combat_pending cleared")
	assert_false(GameSession.is_combat_blocking(), "movement unblocked")
	assert_true(room.combat_escaped, "room marked combat_escaped")


# ── C) escaped room does not re-block on re-enter / refresh ─────────

func test_C_escaped_room_no_reblock() -> void:
	_setup_combat_room()
	var room := GameSession.get_current_room()
	room.combat_escaped = true

	# Simulate entering the same room again
	GameSession._check_combat_pending(room)

	assert_false(GameSession.combat_pending, "pending NOT set for escaped room")
	assert_false(GameSession.is_combat_blocking(), "movement NOT blocked")


# ── D) attack => combat starts and victory unblocks ─────────────────

func test_D_attack_starts_combat_victory_unblocks() -> void:
	_setup_combat_room()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	assert_true(GameSession.is_pending_choice(), "pending before Attack")

	GameSession.accept_combat()

	assert_false(GameSession.combat_pending, "pending cleared after accept")
	assert_not_null(GameSession.combat, "CombatEngine created")
	assert_true(GameSession.is_combat_active(), "combat active")
	assert_true(GameSession.is_combat_blocking(), "movement still blocked")

	var alive := GameSession.combat.get_alive_enemies()
	assert_gt(alive.size(), 0, "Enemies present")

	# Kill the enemy to get victory
	alive[0].health = 0
	GameSession.end_combat(true)

	assert_null(GameSession.combat, "CombatEngine cleared")
	assert_false(GameSession.is_combat_blocking(), "movement unblocked after victory")
	assert_true(room.enemies_defeated, "room.enemies_defeated set")


# ── E) flee failure keeps pending (Python parity: retry allowed) ────

func test_E_flee_failure_stays_pending() -> void:
	_setup_combat_room()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	# Force flee failure by making RNG always >= 0.5
	# DeterministicRNG with a specific seed; we call until we get failure
	var original_rng := GameSession.rng
	# Temporarily override with a failing stub
	var fail_count := 0
	for i in 20:
		var flee_result := GameSession.attempt_flee_pending()
		if not flee_result.get("success", false):
			fail_count += 1
			break
		# If it succeeded, undo and retry
		room.combat_escaped = false
		GameSession.combat_pending = true
		GameSession.game_state.health = GameSession.game_state.max_health

	assert_gt(fail_count, 0, "Got at least one flee failure")
	assert_true(GameSession.combat_pending, "still pending after fail")
	assert_true(GameSession.is_combat_blocking(), "movement still blocked")
	assert_false(room.combat_escaped, "room NOT escaped on failure")


# ── deterministic: combat rooms appear with fixed seeds ──────────────

func test_deterministic_combat_encounter_seed_100() -> void:
	var rng := DeterministicRNG.new(100)
	var gs := GameState.new()
	gs.reset()

	var rd := RoomsData.new()
	rd.load()
	var ed := EnemyTypesData.new()
	ed.load()

	var exploration := ExplorationEngine.new(rng, gs, rd.rooms)
	exploration.start_floor(1)

	var directions := ["E", "E", "E", "E", "E", "N", "N", "N", "N", "N",
					   "W", "W", "W", "W", "W", "S", "S", "S", "S", "S",
					   "E", "E", "N", "N", "W", "W", "S", "S", "E", "N"]
	var combat_rooms := 0

	for dir in directions:
		var room := exploration.move(dir)
		if room == null:
			continue
		if room.has_combat and not room.enemies_defeated:
			combat_rooms += 1

	assert_gt(combat_rooms, 0, "At least one combat room in 30 moves (seed 100)")


func test_deterministic_combat_encounter_seed_42() -> void:
	var rng := DeterministicRNG.new(42)
	var gs := GameState.new()
	gs.reset()

	var rd := RoomsData.new()
	rd.load()

	var exploration := ExplorationEngine.new(rng, gs, rd.rooms)
	exploration.start_floor(1)

	var directions := ["N", "N", "N", "N", "N", "E", "E", "E", "E", "E",
					   "S", "S", "S", "S", "S", "W", "W", "W", "W", "W",
					   "N", "N", "E", "E", "S", "S", "W", "N", "E", "N"]
	var combat_rooms := 0

	for dir in directions:
		var room := exploration.move(dir)
		if room == null:
			continue
		if room.has_combat and not room.enemies_defeated:
			combat_rooms += 1

	assert_gt(combat_rooms, 0, "At least one combat room in 30 moves (seed 42)")


# ── pending choice triggers on move_direction ────────────────────────

func test_pending_triggers_on_move_into_combat_room() -> void:
	GameSession._load_data()

	GameSession.rng = DeterministicRNG.new(300)
	GameSession.game_state = GameState.new()
	GameSession.game_state.reset()
	GameSession.exploration = ExplorationEngine.new(GameSession.rng, GameSession.game_state, GameSession.rooms_db)
	GameSession.inventory_engine = InventoryEngine.new(GameSession.rng, GameSession.game_state, GameSession.items_db)
	GameSession.store_engine = StoreEngine.new(GameSession.game_state, GameSession.items_db)
	GameSession.combat = null
	GameSession.combat_pending = false
	GameSession.exploration.start_floor(1)

	var directions: Array[String] = ["N", "E", "S", "W", "N", "N"]

	var found_pending := false
	for dir in directions:
		var room := GameSession.move_direction(dir)
		if room == null:
			continue
		if GameSession.combat_pending:
			found_pending = true
			assert_true(GameSession.is_pending_choice(), "is_pending_choice")
			assert_null(GameSession.combat, "no CombatEngine yet")
			break

	assert_true(found_pending, "combat_pending triggered within fixed move sequence (seed 300)")


# ── starter rooms + floor-2 parity ───────────────────────────────────

func test_starter_rooms_only_floor1_first3() -> void:
	var rng := DeterministicRNG.new(7)
	var gs := GameState.new()
	gs.reset()

	var rd := RoomsData.new()
	rd.load()

	var exploration := ExplorationEngine.new(rng, gs, rd.rooms)
	exploration.start_floor(1)

	assert_true(exploration.floor.starter_rooms.has(Vector2i.ZERO),
		"Entrance is starter on floor 1")

	var new_rooms := 0
	var starter_count := 0
	var directions := ["N", "E", "S", "W", "N", "N", "E", "E", "S", "S",
					   "W", "W", "N", "E", "N", "E", "S", "W", "S", "E"]
	for dir in directions:
		var room := exploration.move(dir)
		if room == null:
			continue
		var pos := exploration.floor.current_pos
		if room.visited and exploration.floor.rooms_explored > new_rooms:
			new_rooms = exploration.floor.rooms_explored
			if exploration.floor.starter_rooms.has(pos):
				starter_count += 1

	assert_lte(starter_count, 3, "At most 3 starter rooms on floor 1")

	exploration.floor.boss_defeated = true
	var room := exploration.floor.get_current_room()
	if room != null:
		room.has_stairs = true
	exploration.descend_floor()
	assert_true(exploration.floor.starter_rooms.is_empty(),
		"Floor 2 has no starter rooms")
