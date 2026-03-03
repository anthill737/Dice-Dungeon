extends GutTest
## Tests for room template binding, enemy instantiation,
## miniboss timing, and stairs gating in special rooms.

var _rooms_db: Array = []


func before_all() -> void:
	var rd := RoomsData.new()
	assert_true(rd.load(), "rooms DB must load")
	_rooms_db = rd.rooms


func _make_engine(seed_val: int) -> ExplorationEngine:
	var state := GameState.new()
	return ExplorationEngine.new(DeterministicRNG.new(seed_val), state, _rooms_db)


func _force_move(engine: ExplorationEngine, preferred: String) -> RoomState:
	var room := engine.move(preferred)
	if room != null:
		return room
	for alt in ["N", "E", "S", "W"]:
		if alt != preferred:
			room = engine.move(alt)
			if room != null:
				return room
	return null


# ==================================================================
# STEP 1: Room template binding
# ==================================================================

func test_room_name_populated_from_template():
	var engine := _make_engine(42)
	engine.start_floor(1)
	for i in 10:
		var room := _force_move(engine, "E")
		if room != null:
			assert_ne(room.room_name, "Unknown",
				"room_name must not be 'Unknown' (got '%s')" % room.room_name)
			assert_eq(room.room_name, room.data.get("name", ""),
				"room_name must match data['name']")


func test_room_type_populated_from_template():
	var engine := _make_engine(42)
	engine.start_floor(1)
	for i in 10:
		var room := _force_move(engine, "E")
		if room != null:
			assert_ne(room.room_type, "",
				"room_type must not be empty (got '%s')" % room.room_type)
			assert_eq(room.room_type, room.data.get("difficulty", ""),
				"room_type must match data['difficulty']")


func test_tags_populated_from_template():
	var engine := _make_engine(42)
	engine.start_floor(1)
	for i in 10:
		var room := _force_move(engine, "E")
		if room != null:
			assert_true(room.tags is Array, "tags must be an Array")
			var data_tags: Array = room.data.get("tags", [])
			assert_eq(room.tags, data_tags,
				"tags must match data['tags']")


func test_threats_populated_from_template():
	var engine := _make_engine(42)
	engine.start_floor(1)
	for i in 10:
		var room := _force_move(engine, "E")
		if room != null:
			assert_true(room.threats is Array, "threats must be an Array")
			var data_threats: Array = room.data.get("threats", [])
			assert_eq(room.threats, data_threats,
				"threats must match data['threats']")


# ==================================================================
# STEP 2: Enemy instantiation — combat rooms have threats
# ==================================================================

func test_first_combat_room_has_threats():
	var engine := _make_engine(99)
	engine.start_floor(1)
	var found := false
	for i in 50:
		var room := _force_move(engine, "E")
		if room != null and room.has_combat:
			found = true
			assert_gt(room.threats.size(), 0,
				"combat room '%s' must have threats" % room.room_name)
			break
	assert_true(found, "must find at least one combat room in 50 moves")


func test_elite_rooms_have_threats():
	var elite_rooms := _rooms_db.filter(func(r): return r.get("difficulty") == "Elite")
	assert_gt(elite_rooms.size(), 0, "Elite rooms must exist in data")
	for r in elite_rooms:
		var room := RoomState.new(r, 0, 0)
		assert_gt(room.threats.size(), 0,
			"Elite room '%s' must have threats" % room.room_name)


func test_boss_rooms_have_threats():
	var boss_rooms := _rooms_db.filter(func(r): return r.get("difficulty") == "Boss")
	assert_gt(boss_rooms.size(), 0, "Boss rooms must exist in data")
	for r in boss_rooms:
		var room := RoomState.new(r, 0, 0)
		assert_gt(room.threats.size(), 0,
			"Boss room '%s' must have threats" % room.room_name)


func test_miniboss_room_has_threats_at_generation():
	for seed_offset in 20:
		var engine := _make_engine(60000 + seed_offset)
		engine.start_floor(1)
		for i in 30:
			var room := _force_move(engine, "E")
			if room != null and room.is_mini_boss_room:
				assert_gt(room.threats.size(), 0,
					"miniboss room '%s' must have threats (seed=%d)" % [room.room_name, 60000 + seed_offset])
				assert_true(room.has_combat,
					"miniboss room must have has_combat=true")
				return
	pending("no miniboss room found across 20 seeds in 30 moves each")


# ==================================================================
# STEP 3: Miniboss timing — first miniboss >= threshold
# ==================================================================

func test_first_miniboss_after_threshold():
	for seed_offset in 10:
		var engine := _make_engine(70000 + seed_offset)
		engine.start_floor(1)
		var threshold := engine.floor.next_mini_boss_at
		assert_gte(threshold, ExplorationRules.MINIBOSS_INTERVAL_MIN,
			"threshold must be >= %d" % ExplorationRules.MINIBOSS_INTERVAL_MIN)
		var miniboss_at := -1
		for i in 30:
			_force_move(engine, "E")
			if engine.floor.mini_bosses_spawned >= 1 and miniboss_at == -1:
				miniboss_at = engine.floor.rooms_explored_on_floor
				break
		if miniboss_at > 0:
			assert_gte(miniboss_at, threshold,
				"first miniboss at room %d must be >= threshold %d (seed=%d)" % [
					miniboss_at, threshold, 70000 + seed_offset])
			return
	pending("no miniboss spawned across 10 seeds")


# ==================================================================
# STEP 4: Stairs not in miniboss/boss rooms
# ==================================================================

func test_stairs_not_in_miniboss_room():
	var engine := _make_engine(80000)
	engine.start_floor(1)
	for i in 50:
		var room := _force_move(engine, "E")
		if room != null and room.is_mini_boss_room:
			assert_false(room.has_stairs,
				"miniboss room '%s' must not have stairs" % room.room_name)


func test_stairs_not_in_boss_room():
	var engine := _make_engine(81000)
	engine.start_floor(1)
	engine.floor.next_boss_at = 3
	for i in 20:
		var room := _force_move(engine, "E")
		if room != null and room.is_boss_room:
			assert_false(room.has_stairs,
				"boss room '%s' must not have stairs" % room.room_name)


func test_stairs_allowed_in_normal_room():
	var rng := DeterministicRNG.new(82000)
	var room_data := {"name": "Normal Room", "difficulty": "Easy", "threats": ["Rat"],
		"tags": [], "discoverables": [], "flavor": ""}
	var room := RoomState.new(room_data, 5, 5)
	var is_special := room.is_mini_boss_room or room.is_boss_room
	assert_false(is_special, "normal room should not be special (stairs allowed)")
