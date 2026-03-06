extends GutTest
## Deterministic tests for store logic and F4 export.
##
## Store Logic:
##   1) Given seed X and floor Y, store spawns exactly as Python dictates.
##   2) Store never shares room with stairs if Python forbids it (Python allows it).
##   3) Store persists correctly through save/load.
##   4) Store inventory deterministic for given seed + floor.
##
## F4 Export:
##   5) F4 export includes rng_mode, seed, non-empty adventure_log.
##   6) Adventure log order preserved.

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
# TEST 1: Store spawns deterministically for a given seed and floor
# ==================================================================

func test_store_spawn_deterministic_seed_42_floor_1():
	var engine_a := _make_engine(42)
	engine_a.start_floor(1)
	var store_room_a: int = -1
	for i in range(20):
		var room := _force_move(engine_a, ["E", "N", "S", "W"][i % 4])
		if room == null:
			break
		if room.has_store:
			store_room_a = i
			break

	var engine_b := _make_engine(42)
	engine_b.start_floor(1)
	var store_room_b: int = -1
	for i in range(20):
		var room := _force_move(engine_b, ["E", "N", "S", "W"][i % 4])
		if room == null:
			break
		if room.has_store:
			store_room_b = i
			break

	assert_eq(store_room_a, store_room_b,
		"Same seed should produce store at same room index")


func test_store_spawns_once_per_floor():
	var engine := _make_engine(100)
	engine.start_floor(1)
	var store_positions: Dictionary = {}
	for i in range(30):
		var room := _force_move(engine, ["E", "N", "W", "S"][i % 4])
		if room == null:
			break
		if room.has_store:
			store_positions[room.coords()] = true
	assert_eq(store_positions.size(), 1,
		"Exactly one unique store room per floor")


# ==================================================================
# TEST 2: Store min rooms threshold
# ==================================================================

func test_store_never_spawns_before_min_rooms():
	for seed_val in [10, 20, 30, 40, 50]:
		var engine := _make_engine(seed_val)
		engine.start_floor(1)
		var room := engine.move("E")
		if room != null:
			assert_false(room.has_store,
				"Store must not spawn at rooms_explored=1 (seed=%d)" % seed_val)


func test_store_guaranteed_by_room_15():
	var engine := _make_engine(99999)
	engine.start_floor(1)
	var found := false
	var attempts := 0
	while not found and attempts < 200:
		var moved := false
		for dir in ["N", "E", "S", "W"]:
			var delta := RoomState.dir_delta(dir)
			var new_pos: Vector2i = engine.floor.current_pos + delta
			if not engine.floor.has_room_at(new_pos) and engine.can_move(dir):
				var room := engine.move(dir)
				if room != null:
					moved = true
					if room.has_store:
						found = true
					break
		if not moved:
			_force_move(engine, ["N", "E", "S", "W"][attempts % 4])
		attempts += 1
	assert_true(found, "Store must appear (guaranteed by rooms_explored >= 15)")
	assert_true(engine.floor.store_found, "floor.store_found must be true")


# ==================================================================
# TEST 3: Store persists through save/load
# ==================================================================

func test_store_persists_through_save_load():
	var rng := DeterministicRNG.new(555)
	var state := GameState.new()
	var engine := ExplorationEngine.new(rng, state, _rooms_db)
	engine.start_floor(1)

	var store_pos := Vector2i(-999, -999)
	for i in range(20):
		var room := _force_move(engine, ["E", "N", "W", "S"][i % 4])
		if room == null:
			break
		if room.has_store:
			store_pos = room.coords()
			break

	assert_true(engine.floor.store_found, "Store should be found before save")
	assert_ne(store_pos, Vector2i(-999, -999), "Store position should be set")

	var save_json := SaveEngine.save_to_string(state, engine.floor)
	assert_false(save_json.is_empty(), "Save should produce output")

	var new_state := GameState.new()
	var new_floor := FloorState.new()
	var ok := SaveEngine.load_from_string(save_json, new_state, new_floor)
	assert_true(ok, "Load should succeed")

	assert_true(new_floor.store_found, "store_found preserved after load")
	assert_eq(new_floor.store_pos, store_pos, "store_pos preserved after load")

	assert_true(new_floor.rooms.has(store_pos),
		"Room at store_pos should exist after load")
	if new_floor.rooms.has(store_pos):
		var loaded_room: RoomState = new_floor.rooms[store_pos]
		assert_true(loaded_room.has_store,
			"has_store must be true on the store room after load")


func test_store_has_store_serialized_in_room():
	var state := GameState.new()
	var floor_st := FloorState.new()
	var room := RoomState.new({"name": "Test"}, 1, 2)
	room.has_store = true
	room.visited = true
	floor_st.rooms[Vector2i(1, 2)] = room
	floor_st.current_pos = Vector2i(1, 2)
	floor_st.store_found = true
	floor_st.store_pos = Vector2i(1, 2)

	var save_json := SaveEngine.save_to_string(state, floor_st)
	var new_state := GameState.new()
	var new_floor := FloorState.new()
	SaveEngine.load_from_string(save_json, new_state, new_floor)

	assert_true(new_floor.rooms.has(Vector2i(1, 2)), "Room should load")
	if new_floor.rooms.has(Vector2i(1, 2)):
		assert_true(new_floor.rooms[Vector2i(1, 2)].has_store,
			"has_store should round-trip through save/load")


# ==================================================================
# TEST 4: Store inventory deterministic for given seed + floor
# ==================================================================

func test_store_inventory_deterministic():
	var state_a := GameState.new()
	state_a.floor = 2
	var store_a := StoreEngine.new(state_a, {})
	var inv_a := store_a.generate_store_inventory()

	var state_b := GameState.new()
	state_b.floor = 2
	var store_b := StoreEngine.new(state_b, {})
	var inv_b := store_b.generate_store_inventory()

	assert_eq(inv_a.size(), inv_b.size(),
		"Same floor should produce same inventory size")
	for i in inv_a.size():
		assert_eq(inv_a[i][0], inv_b[i][0],
			"Item name at index %d should match" % i)
		assert_eq(inv_a[i][1], inv_b[i][1],
			"Item price at index %d should match" % i)


func test_store_inventory_floor_0_treated_as_floor_1():
	var state := GameState.new()
	state.floor = 0
	var store := StoreEngine.new(state, {})
	var inv := store.generate_store_inventory()

	var state_f1 := GameState.new()
	state_f1.floor = 1
	var store_f1 := StoreEngine.new(state_f1, {})
	var inv_f1 := store_f1.generate_store_inventory()

	assert_eq(inv.size(), inv_f1.size(),
		"Floor 0 inventory should match floor 1")
	for i in inv.size():
		assert_eq(inv[i][0], inv_f1[i][0],
			"Item at index %d should match" % i)
		assert_eq(inv[i][1], inv_f1[i][1],
			"Price at index %d should match" % i)


func test_store_inventory_excludes_purchased_upgrades():
	var state := GameState.new()
	state.floor = 1
	state.purchased_upgrades_this_floor = {"Max HP Upgrade": true}
	var store := StoreEngine.new(state, {})
	var inv := store.generate_store_inventory()

	var names: Array = []
	for item in inv:
		names.append(item[0])

	assert_false(names.has("Max HP Upgrade"),
		"Purchased upgrades should not appear")
	assert_true(names.has("Damage Upgrade"),
		"Non-purchased upgrades should still appear")


func test_store_inventory_scales_with_floor():
	var state_f1 := GameState.new()
	state_f1.floor = 1
	var inv_f1 := StoreEngine.new(state_f1, {}).generate_store_inventory()

	var state_f4 := GameState.new()
	state_f4.floor = 4
	var inv_f4 := StoreEngine.new(state_f4, {}).generate_store_inventory()

	assert_true(inv_f4.size() > inv_f1.size(),
		"Higher floors should have more items (floor 4 >= floor 1)")

	var names_f1: Array = []
	for item in inv_f1:
		names_f1.append(item[0])
	var names_f4: Array = []
	for item in inv_f4:
		names_f4.append(item[0])

	assert_false(names_f1.has("Cooled Ember"),
		"Floor 1 should not have floor 4+ items")
	assert_true(names_f4.has("Cooled Ember"),
		"Floor 4 should have floor 4+ items")


# ==================================================================
# TEST 5: Store chance per floor matches Python
# ==================================================================

func test_store_chance_floor_values():
	assert_eq(ExplorationRules.store_chance_for_floor(1), 0.35, "Floor 1 = 35%")
	assert_eq(ExplorationRules.store_chance_for_floor(2), 0.25, "Floor 2 = 25%")
	assert_eq(ExplorationRules.store_chance_for_floor(3), 0.20, "Floor 3 = 20%")
	assert_eq(ExplorationRules.store_chance_for_floor(4), 0.15, "Floor 4+ = 15%")
	assert_eq(ExplorationRules.store_chance_for_floor(10), 0.15, "Floor 10 = 15%")
	assert_eq(ExplorationRules.store_chance_for_floor(0), 0.15, "Floor 0 = 15%")


# ==================================================================
# TEST 6: state.floor synced during floor transitions
# ==================================================================

func test_state_floor_synced_on_start_floor():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(1), state, _rooms_db)
	engine.start_floor(3)
	assert_eq(state.floor, 3, "state.floor should sync with floor_index on start_floor")


# ==================================================================
# TEST 7: F4 export includes rng_mode, seed, and adventure_log
# ==================================================================

func test_f4_export_includes_rng_mode_and_seed():
	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG", "deterministic")
	trace.record("test_event", {"key": "value"})

	var json_str := trace.export_json()
	assert_false(json_str.is_empty(), "JSON export should not be empty")

	var json := JSON.new()
	assert_eq(json.parse(json_str), OK, "JSON should parse")

	var data: Dictionary = json.data
	assert_eq(data.get("seed"), 42, "seed in export")
	assert_eq(data.get("rng_mode"), "deterministic", "rng_mode in export")
	assert_eq(data.get("rng_type"), "DeterministicRNG", "rng_type in export")


func test_f4_export_default_mode():
	var trace := SessionTrace.new()
	trace.reset(-1, "DefaultRNG", "default")

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var data: Dictionary = json.data

	assert_eq(data.get("seed"), -1, "seed should be -1 for default")
	assert_eq(data.get("rng_mode"), "default", "rng_mode should be default")


func test_f4_export_rng_mode_inferred_from_type():
	var trace := SessionTrace.new()
	trace.reset(99, "DeterministicRNG")
	assert_eq(trace.rng_mode, "deterministic",
		"rng_mode should be inferred from rng_type")

	var trace2 := SessionTrace.new()
	trace2.reset(-1, "DefaultRNG")
	assert_eq(trace2.rng_mode, "default",
		"rng_mode should be inferred from rng_type")


func test_f4_export_includes_adventure_log():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(42, "DeterministicRNG", "deterministic")

	log.append("You entered the dungeon.")
	log.append("Found a mysterious shop!", "loot")
	log.append("Defeated a goblin.", "enemy")

	var json_str := trace.export_json()
	var json := JSON.new()
	assert_eq(json.parse(json_str), OK, "JSON should parse")

	var data: Dictionary = json.data
	assert_true(data.has("adventure_log"), "Export should have adventure_log key")
	var entries: Array = data.get("adventure_log", [])
	assert_eq(entries.size(), 3, "Should have 3 log entries")
	assert_eq(entries[0]["text"], "You entered the dungeon.", "First entry matches")
	assert_eq(entries[1]["text"], "Found a mysterious shop!", "Second entry matches")
	assert_eq(entries[2]["text"], "Defeated a goblin.", "Third entry matches")


func test_f4_export_empty_adventure_log():
	var trace := SessionTrace.new()
	trace.reset(1, "DefaultRNG", "default")

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var data: Dictionary = json.data

	assert_true(data.has("adventure_log"), "Export should have adventure_log")
	var entries: Array = data.get("adventure_log", [])
	assert_eq(entries.size(), 0, "No log without adventure log service")


# ==================================================================
# TEST 8: Adventure log order preserved
# ==================================================================

func test_adventure_log_order_preserved():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(1, "DefaultRNG", "default")

	var messages := [
		"=== Floor 1 ===",
		"Entered: Dark Cave",
		"Found stairs to the next floor!",
		"Discovered a mysterious shop!",
		"Combat begins!",
	]
	for msg in messages:
		log.append(msg)

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var entries: Array = json.data.get("adventure_log", [])

	assert_eq(entries.size(), messages.size(), "Entry count matches")
	for i in messages.size():
		assert_eq(entries[i]["text"], messages[i],
			"Entry %d should be '%s'" % [i, messages[i]])


func test_adventure_log_in_text_export():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(42, "DeterministicRNG", "deterministic")

	log.append("Test entry 1")
	log.append("Test entry 2")

	var text := trace.export_text()
	assert_true(text.contains("=== ADVENTURE LOG"),
		"Text export should have adventure log section")
	assert_true(text.contains("Test entry 1"),
		"Text export should contain entry 1")
	assert_true(text.contains("Test entry 2"),
		"Text export should contain entry 2")
	assert_true(text.contains("RNG Mode    : deterministic"),
		"Text export should contain RNG Mode")


# ==================================================================
# TEST 9: Seed consistency across trace and run_started event
# ==================================================================

func test_seed_consistency_in_trace():
	var trace := SessionTrace.new()
	trace.reset(12345, "DeterministicRNG", "deterministic")
	trace.record("run_started", {
		"rng_mode": "deterministic",
		"seed": 12345,
	})

	assert_eq(trace.seed_value, 12345, "Trace seed_value matches")
	assert_eq(trace.rng_mode, "deterministic", "Trace rng_mode matches")

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var data: Dictionary = json.data

	assert_eq(data.get("seed"), 12345, "Export seed matches")
	assert_eq(data.get("rng_mode"), "deterministic", "Export rng_mode matches")

	var found_run_started := false
	for ev in data.get("events", []):
		if ev.get("type") == "run_started":
			var payload: Dictionary = ev.get("payload", {})
			assert_eq(payload.get("seed"), 12345, "run_started event seed matches")
			assert_eq(payload.get("rng_mode"), "deterministic",
				"run_started event rng_mode matches")
			found_run_started = true
			break
	assert_true(found_run_started, "run_started event should exist")
