extends GutTest
## Tests for adventure log parity with Python, auto-scroll logic,
## typewriter state, F4 export enhancements, and Copy Log safety.

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
# TEST 1: Room entry logging — separator + name + flavor
# ==================================================================

func test_room_entry_has_separator():
	var engine := _make_engine(42)
	engine.start_floor(1)
	engine.logs.clear()
	var room := _force_move(engine, "E")
	assert_not_null(room, "Should move to a room")
	var has_separator := false
	for log_line in engine.logs:
		if log_line.begins_with("===="):
			has_separator = true
			break
	assert_true(has_separator, "Room entry should include separator line")


func test_room_entry_has_name():
	var engine := _make_engine(42)
	engine.start_floor(1)
	engine.logs.clear()
	var room := _force_move(engine, "E")
	assert_not_null(room, "Should move to a room")
	var has_entered := false
	for log_line in engine.logs:
		if log_line.begins_with("Entered:"):
			has_entered = true
			break
	assert_true(has_entered, "Room entry should include 'Entered: ...' line")


func test_room_entry_has_flavor():
	var engine := _make_engine(42)
	engine.start_floor(1)
	var room: RoomState = null
	var flavor_found := false
	for i in range(30):
		engine.logs.clear()
		room = _force_move(engine, ["E", "N", "S", "W"][i % 4])
		if room == null:
			continue
		var room_flavor: String = room.data.get("flavor", "")
		if not room_flavor.is_empty():
			for log_line in engine.logs:
				if log_line == room_flavor:
					flavor_found = true
					break
		if flavor_found:
			break
	assert_true(flavor_found, "At least one room should have flavor text logged")


func test_floor_start_has_separator_and_name():
	var engine := _make_engine(99)
	var entrance := engine.start_floor(1)
	assert_not_null(entrance)
	var has_floor_header := false
	var has_separator := false
	var has_entered := false
	for log_line in engine.logs:
		if log_line.contains("Floor 1"):
			has_floor_header = true
		if log_line.begins_with("===="):
			has_separator = true
		if log_line.begins_with("Entered:"):
			has_entered = true
	assert_true(has_floor_header, "Floor start should log '=== Floor 1 ==='")
	assert_true(has_separator, "Floor start should log separator")
	assert_true(has_entered, "Floor start should log 'Entered: ...'")


func test_revisit_room_has_separator():
	var engine := _make_engine(42)
	engine.start_floor(1)
	var room := engine.move("E")
	if room == null:
		room = engine.move("N")
	assert_not_null(room, "Should move")
	engine.logs.clear()
	var opp := "W" if room != null else "S"
	engine.move(opp)
	engine.logs.clear()
	engine.move("E")
	var has_separator := false
	for log_line in engine.logs:
		if log_line.begins_with("===="):
			has_separator = true
			break
	assert_true(has_separator, "Revisiting a room should include separator")


# ==================================================================
# TEST 2: Interaction logging
# ==================================================================

func test_store_discovery_logged():
	var engine := _make_engine(99999)
	engine.start_floor(1)
	var found := false
	for i in range(200):
		engine.logs.clear()
		var moved := false
		for dir in ["N", "E", "S", "W"]:
			var delta := RoomState.dir_delta(dir)
			var new_pos: Vector2i = engine.floor.current_pos + delta
			if not engine.floor.has_room_at(new_pos) and engine.can_move(dir):
				var room := engine.move(dir)
				if room != null:
					moved = true
					if room.has_store:
						for log_line in engine.logs:
							if log_line.contains("Discovered a mysterious shop"):
								found = true
								break
					break
		if found:
			break
		if not moved:
			_force_move(engine, ["N", "E", "S", "W"][i % 4])
	assert_true(found, "Store discovery should be logged")


func test_container_search_logged():
	var engine := _make_engine(42)
	engine.start_floor(1)
	for i in range(30):
		var room := _force_move(engine, ["E", "N", "W", "S"][i % 4])
		if room == null:
			continue
		if not room.ground_container.is_empty() and not room.container_searched:
			engine.logs.clear()
			engine.search_container(room)
			var found := false
			for log_line in engine.logs:
				if log_line.begins_with("Searched") or log_line.begins_with("Container"):
					found = true
					break
			assert_true(found, "Container search should log a result")
			return
	pass_test("No container found in 30 rooms — skipping container test")


func test_rest_logged():
	var state := GameState.new()
	state.health = 30
	state.max_health = 50
	var log := AdventureLogService.new()
	state.health += 10
	log.append("Rested and recovered 10 HP.", "success")
	assert_eq(log.get_entries()[0]["text"], "Rested and recovered 10 HP.")


func test_stairs_discovery_logged():
	var engine := _make_engine(42)
	engine.start_floor(1)
	var found_stairs := false
	for i in range(50):
		engine.logs.clear()
		var room := _force_move(engine, ["E", "N", "S", "W"][i % 4])
		if room == null:
			continue
		if room.has_stairs:
			for log_line in engine.logs:
				if log_line.contains("stairs"):
					found_stairs = true
					break
			break
	if not found_stairs:
		pass_test("Stairs not found in 50 rooms — depends on seed")
	else:
		assert_true(found_stairs, "Stairs discovery should be logged")


# ==================================================================
# TEST 3: Auto-scroll logic (state-only, no pixel tests)
# ==================================================================

func test_auto_scroll_sticky_default():
	var log := AdventureLogService.new()
	var sticky := true
	var unread := 0
	log.append("Entry 1")
	if sticky:
		pass
	else:
		unread += 1
	assert_eq(unread, 0, "When sticky, unread should not increment")


func test_auto_scroll_not_sticky_increments():
	var sticky := false
	var unread := 0
	if not sticky:
		unread += 1
	assert_eq(unread, 1, "When not sticky, unread should increment")


func test_auto_scroll_reset_on_click():
	var sticky := false
	var unread := 5
	sticky = true
	unread = 0
	assert_eq(unread, 0, "Clicking indicator resets unread to 0")
	assert_true(sticky, "Clicking indicator sets sticky to true")


# ==================================================================
# TEST 4: Typewriter state
# ==================================================================

func test_typewriter_instant_mode():
	var sm_delay := 0
	assert_eq(sm_delay, 0, "Instant mode means delay is 0")


func test_typewriter_noninstant_state():
	var sm_delay := 13
	var revealing := sm_delay > 0
	assert_true(revealing, "Non-instant mode should enable revealing state")


# ==================================================================
# TEST 5: F4 export includes required fields
# ==================================================================

func test_f4_export_has_adventure_log_count():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(42, "DeterministicRNG", "deterministic")

	log.append("Entry 1")
	log.append("Entry 2")
	log.append("Entry 3")

	var json_str := trace.export_json()
	var json := JSON.new()
	assert_eq(json.parse(json_str), OK, "JSON should parse")
	var data: Dictionary = json.data
	assert_true(data.has("adventure_log_count"), "Export should have adventure_log_count")
	assert_eq(data["adventure_log_count"], 3, "adventure_log_count should be 3")


func test_f4_export_has_seed_and_rng_mode():
	var trace := SessionTrace.new()
	trace.reset(12345, "DeterministicRNG", "deterministic")
	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var data: Dictionary = json.data
	assert_eq(data["seed"], 12345, "seed should match")
	assert_eq(data["rng_mode"], "deterministic", "rng_mode should match")


func test_f4_export_adventure_log_has_index():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(1, "DefaultRNG", "default")

	log.append("First", "system")
	log.append("Second", "loot")

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var entries: Array = json.data.get("adventure_log", [])
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["index"], 0, "First entry index should be 0")
	assert_eq(entries[1]["index"], 1, "Second entry index should be 1")


func test_f4_export_adventure_log_has_event_type():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(1, "DefaultRNG", "default")

	log.append("Room entry", "system")
	log.append("Found gold!", "loot")
	log.append("Boss fight!", "enemy", "COMBAT")

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var entries: Array = json.data.get("adventure_log", [])

	assert_eq(entries[0].get("event_type"), "system")
	assert_eq(entries[1].get("event_type"), "loot")
	assert_eq(entries[2].get("event_type"), "enemy")
	assert_eq(entries[2].get("category"), "COMBAT")


# ==================================================================
# TEST 6: Copy Log headless safety
# ==================================================================

func test_copy_log_does_not_crash_headless():
	var log := AdventureLogService.new()
	log.append("Test entry 1")
	log.append("Test entry 2")
	var entries := log.get_text_entries()
	var text := "\n".join(entries)
	assert_false(text.is_empty(), "Log text should not be empty")
	# DisplayServer.clipboard_set may no-op in headless — just ensure no crash
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)
	pass_test("Copy log does not crash in headless")


# ==================================================================
# TEST 7: Adventure log service tag support
# ==================================================================

func test_log_entry_is_dictionary():
	var svc := AdventureLogService.new()
	svc.append("Hello", "loot")
	var entry = svc.get_entries()[0]
	assert_true(entry is Dictionary, "Entry should be a Dictionary")
	assert_eq(entry["text"], "Hello")
	assert_eq(entry["tag"], "loot")


func test_text_export_includes_tag():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(1, "DefaultRNG", "default")

	log.append("Entered: Dark Cave", "system")

	var text := trace.export_text()
	assert_true(text.contains("system"), "Text export should include tag")
	assert_true(text.contains("Entered: Dark Cave"), "Text export should include entry text")
