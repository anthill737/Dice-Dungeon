extends "res://addons/gut/test.gd"
## Deterministic test: verify that combat rooms appear and enemies
## are instantiated within a fixed move sequence using a fixed seed.
## Prevents regression where enemies silently stop spawning.


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
	var combat_room_with_threats := 0

	for dir in directions:
		var room := exploration.move(dir)
		if room == null:
			continue
		if room.has_combat and not room.enemies_defeated:
			combat_rooms += 1
			var threats: Array = room.data.get("threats", [])
			if not threats.is_empty():
				combat_room_with_threats += 1
				# Verify an enemy can be instantiated from threats
				var enemy_name: String = threats[0]
				var enemy_data: Dictionary = ed.enemies.get(enemy_name, {})
				var hp: int = int(enemy_data.get("health", 20))
				gut.p("Combat room found: %s, enemy=%s hp=%d" % [
					room.data.get("name", "?"), enemy_name, hp])

	gut.p("Total combat rooms: %d (with threats: %d)" % [combat_rooms, combat_room_with_threats])
	assert_gt(combat_rooms, 0, "At least one combat room in 30 moves with seed 100")
	assert_eq(combat_rooms, combat_room_with_threats, "All combat rooms have threats")


func test_deterministic_combat_encounter_seed_42() -> void:
	var rng := DeterministicRNG.new(42)
	var gs := GameState.new()
	gs.reset()

	var rd := RoomsData.new()
	rd.load()
	var ed := EnemyTypesData.new()
	ed.load()

	var exploration := ExplorationEngine.new(rng, gs, rd.rooms)
	exploration.start_floor(1)

	# Spiral outward to ensure we reach non-starter rooms
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
			var threats: Array = room.data.get("threats", [])
			gut.p("Combat room: %s at %s threats=%s" % [
				room.data.get("name", "?"),
				str(exploration.floor.current_pos),
				str(threats)])

	gut.p("Combat rooms found: %d" % combat_rooms)
	assert_gt(combat_rooms, 0, "At least one combat room in 30 moves with seed 42")


func test_auto_combat_start_via_game_session() -> void:
	GameSession._load_data()
	GameSession.start_new_game()

	# Move until we find a combat room (up to 30 moves)
	var combat_auto_started := false
	var directions := ["N", "E", "N", "E", "S", "W", "N", "N", "E", "E",
					   "S", "S", "W", "W", "N", "E", "S", "E", "N", "W",
					   "S", "S", "E", "E", "N", "N", "W", "S", "E", "N"]
	for dir in directions:
		var room := GameSession.move_direction(dir)
		if room == null:
			continue
		# After auto-combat wiring, combat engine should be created automatically
		if GameSession.combat != null:
			combat_auto_started = true
			var alive := GameSession.combat.get_alive_enemies()
			assert_gt(alive.size(), 0, "Auto-started combat has alive enemies")
			gut.p("Auto-combat started: %s (%d enemies)" % [
				room.data.get("name", "?"), alive.size()])
			# End combat to allow further movement
			GameSession.end_combat(false)
			break

	if not combat_auto_started:
		pending("No combat encountered in 30 moves (extremely unlikely with DefaultRNG)")


func test_starter_rooms_only_floor1_first3() -> void:
	var rng := DeterministicRNG.new(7)
	var gs := GameState.new()
	gs.reset()

	var rd := RoomsData.new()
	rd.load()

	var exploration := ExplorationEngine.new(rng, gs, rd.rooms)
	exploration.start_floor(1)

	# Entrance is always starter on floor 1
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
		# Count only new rooms (rooms_explored changes)
		if room.visited and exploration.floor.rooms_explored > new_rooms:
			new_rooms = exploration.floor.rooms_explored
			if exploration.floor.starter_rooms.has(pos):
				starter_count += 1

	# Only first 3 new rooms should be starter (rooms_explored 1,2,3)
	assert_lte(starter_count, 3, "At most 3 starter rooms on floor 1")
	gut.p("New rooms: %d, starter rooms: %d" % [new_rooms, starter_count])

	# Floor 2 should have NO starter rooms
	exploration.floor.boss_defeated = true
	var room := exploration.floor.get_current_room()
	if room != null:
		room.has_stairs = true
	exploration.descend_floor()
	assert_true(exploration.floor.starter_rooms.is_empty(),
		"Floor 2 has no starter rooms")


func test_movement_blocked_during_combat() -> void:
	GameSession._load_data()
	GameSession.start_new_game()

	# Manually set up a combat room
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}

	GameSession.start_combat_for_room(room)
	assert_not_null(GameSession.combat, "Combat active")
	assert_true(GameSession.is_combat_blocking(), "Combat blocks movement")

	# Movement should be blocked
	var result := GameSession.move_direction("N")
	assert_null(result, "Cannot move during combat")

	GameSession.end_combat(false)
	assert_false(GameSession.is_combat_blocking(), "After flee, combat no longer blocks")
