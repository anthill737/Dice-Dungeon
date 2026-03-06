extends GutTest
## Verifies SessionTrace export writes valid JSON and text files to user://.


func _make_trace_with_events() -> SessionTrace:
	var trace := SessionTrace.new()
	trace.reset(12345, "DeterministicRNG")
	trace.difficulty = "Normal"

	trace.record("run_started", {"difficulty": "Normal", "max_health": 50})
	trace.set_floor(1)
	trace.set_coord(Vector2i(0, 0))
	trace.record("room_entered", {
		"room_name": "Dark Cave",
		"room_type": "Easy",
		"tags": ["combat"],
		"has_combat": true,
		"chest": false,
		"store": false,
		"stairs": false,
		"miniboss": false,
		"boss": false,
		"blocked_exits": [],
	})
	trace.record("move_attempted", {"dir": "N", "success": true})
	trace.set_coord(Vector2i(0, 1))
	trace.record("combat_pending_started", {})
	trace.record("combat_started", {
		"enemies": [{"name": "Goblin", "hp": 20, "dice": 2}],
	})
	trace.record("dice_rolled", {"values": [3, 5, 2]})
	trace.record("attack_committed", {"target": "Goblin", "damage": 15, "combo": 0})
	trace.record("enemy_attack", {"enemy": "Goblin", "damage": 7})
	trace.record("combat_victory", {})
	trace.record("item_picked_up", {"source": "ground", "item_id": "Health Potion", "name": "Health Potion", "qty": 1})
	trace.record("saved", {"slot": 1, "name": "Test Save"})

	return trace


# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------

func test_export_json_creates_file():
	var trace := _make_trace_with_events()
	var path := trace.export_json_to_file()
	assert_ne(path, "", "export should return a path")
	assert_true(FileAccess.file_exists(path), "JSON file should exist at %s" % path)

	# Clean up
	DirAccess.remove_absolute(path)


func test_export_json_is_valid():
	var trace := _make_trace_with_events()
	var path := trace.export_json_to_file()

	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "should open JSON file")
	var content := f.get_as_text()
	f.close()

	assert_gt(content.length(), 0, "JSON content should be non-empty")

	var json := JSON.new()
	var err := json.parse(content)
	assert_eq(err, OK, "JSON should parse without errors: %s" % json.get_error_message())

	var data: Dictionary = json.data
	assert_true(data.has("run_id"), "JSON should have run_id")
	assert_true(data.has("start_time_utc"), "JSON should have start_time_utc")
	assert_true(data.has("seed"), "JSON should have seed")
	assert_true(data.has("rng_type"), "JSON should have rng_type")
	assert_true(data.has("events"), "JSON should have events array")
	assert_true(data.has("event_count"), "JSON should have event_count")
	assert_eq(data["rng_type"], "DeterministicRNG")
	assert_eq(int(data["seed"]), 12345)

	var events: Array = data["events"]
	assert_gt(events.size(), 0, "should have events")
	assert_eq(int(data["event_count"]), events.size(), "event_count should match events array")

	# Validate event schema
	for ev in events:
		assert_true(ev.has("t_ms"), "event must have t_ms")
		assert_true(ev.has("type"), "event must have type")
		assert_true(ev.has("floor"), "event must have floor")
		assert_true(ev.has("coord"), "event must have coord")
		assert_true(ev.has("payload"), "event must have payload")
		var coord = ev["coord"]
		assert_true(coord is Array, "coord should be an array")
		assert_eq(coord.size(), 2, "coord should have 2 elements")

	DirAccess.remove_absolute(path)


func test_export_text_creates_file():
	var trace := _make_trace_with_events()
	var path := trace.export_text_to_file()
	assert_ne(path, "", "export should return a path")
	assert_true(FileAccess.file_exists(path), "TXT file should exist at %s" % path)

	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "should open TXT file")
	var content := f.get_as_text()
	f.close()

	assert_gt(content.length(), 0, "text content should be non-empty")
	assert_true(content.contains("SESSION TRACE"), "should have header")
	assert_true(content.contains("Run ID"), "should have Run ID line")
	assert_true(content.contains("DeterministicRNG"), "should contain RNG type")
	assert_true(content.contains("run_started"), "should contain event types")
	assert_true(content.contains("combat_started"), "should contain combat_started event")

	DirAccess.remove_absolute(path)


func test_export_all_returns_both_paths():
	var trace := _make_trace_with_events()
	var result := trace.export_all()

	assert_true(result.has("json"), "should have json key")
	assert_true(result.has("txt"), "should have txt key")

	var json_path: String = result["json"]
	var txt_path: String = result["txt"]

	assert_ne(json_path, "", "json path should be non-empty")
	assert_ne(txt_path, "", "txt path should be non-empty")
	assert_true(FileAccess.file_exists(json_path), "JSON file should exist")
	assert_true(FileAccess.file_exists(txt_path), "TXT file should exist")

	# Both should reference the same run_id
	assert_true(json_path.contains(trace.run_id), "json path should contain run_id")
	assert_true(txt_path.contains(trace.run_id), "txt path should contain run_id")

	DirAccess.remove_absolute(json_path)
	DirAccess.remove_absolute(txt_path)


func test_json_event_types_match_recorded():
	var trace := _make_trace_with_events()
	var path := trace.export_json_to_file()

	var f := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	json.parse(f.get_as_text())
	f.close()

	var events: Array = json.data["events"]
	var expected_types := [
		"run_started", "room_entered", "move_attempted",
		"combat_pending_started", "combat_started",
		"dice_rolled", "attack_committed", "enemy_attack",
		"combat_victory", "item_picked_up", "saved",
	]

	var actual_types: Array = []
	for ev in events:
		actual_types.append(str(ev["type"]))

	for et in expected_types:
		assert_true(actual_types.has(et), "should contain event type: %s" % et)

	DirAccess.remove_absolute(path)


func test_empty_trace_exports_valid_json():
	var trace := SessionTrace.new()
	trace.reset(0, "PortableLCG")
	var json_str := trace.export_json()

	var json := JSON.new()
	var err := json.parse(json_str)
	assert_eq(err, OK, "empty trace should produce valid JSON")

	var data: Dictionary = json.data
	assert_eq(int(data["event_count"]), 0)
	assert_eq((data["events"] as Array).size(), 0)
