extends GutTest
## Headless test: room templates load via res://data/ path used by exports.
## Asserts the full loading pipeline produces a non-empty template pool.


func test_rooms_v2_json_exists_at_res_data():
	var path := JsonLoader.resolve_data_path("rooms_v2.json")
	assert_true(FileAccess.file_exists(path),
		"rooms_v2.json must exist at res://data/ path: %s" % path)


func test_rooms_v2_json_is_nonempty_file():
	var path := JsonLoader.resolve_data_path("rooms_v2.json")
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "must be able to open rooms_v2.json")
	if f != null:
		assert_gt(f.get_length(), 0, "rooms_v2.json must not be empty")
		f.close()


func test_loaded_room_template_count_gt_zero():
	var rd := RoomsData.new()
	var ok := rd.load()
	assert_true(ok, "RoomsData.load() must succeed")
	assert_gt(rd.rooms.size(), 0,
		"loaded room templates must be > 0 (got %d)" % rd.rooms.size())


func test_room_binding_produces_valid_fields():
	var rd := RoomsData.new()
	rd.load()
	assert_gt(rd.rooms.size(), 0, "need at least one room template")
	var template: Dictionary = rd.rooms[0]
	var room := RoomState.new(template, 0, 0)
	assert_ne(room.room_name, "Unknown",
		"room_name must bind from template (got '%s')" % room.room_name)
	assert_ne(room.room_type, "",
		"room_type must bind from template (got '%s')" % room.room_type)
	assert_true(room.threats is Array, "threats must be an Array")
	assert_true(room.tags is Array, "tags must be an Array")


func test_exploration_engine_receives_nonempty_pool():
	var rd := RoomsData.new()
	rd.load()
	var state := GameState.new()
	var engine := ExplorationEngine.new(DefaultRNG.new(), state, rd.rooms)
	assert_gt(engine.rooms_db.size(), 0,
		"ExplorationEngine.rooms_db must not be empty")
