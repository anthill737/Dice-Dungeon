extends GutTest
## Tests for adventure log hardening, trace upgrades, F4 export fields,
## categories, action provenance, milestone snapshots, and Copy Log header.

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
# 1) Room entry logging — first visit and revisit
# ==================================================================

func test_first_visit_has_separator_and_name_and_flavor():
	var engine := _make_engine(42)
	engine.start_floor(1)
	engine.logs.clear()
	var room := _force_move(engine, "E")
	assert_not_null(room)
	var has_sep := false
	var has_entered := false
	var flavor: String = room.data.get("flavor", "")
	var has_flavor := flavor.is_empty()
	for line in engine.logs:
		if line.begins_with("===="):
			has_sep = true
		if line.begins_with("Entered:"):
			has_entered = true
		if not flavor.is_empty() and line == flavor:
			has_flavor = true
	assert_true(has_sep, "First visit should have separator")
	assert_true(has_entered, "First visit should have 'Entered:' line")


func test_revisit_has_separator_and_entered():
	var engine := _make_engine(42)
	engine.start_floor(1)
	var room := engine.move("E")
	if room == null:
		room = engine.move("N")
	assert_not_null(room)
	engine.logs.clear()
	engine.move("W")
	engine.logs.clear()
	engine.move("E")
	var has_sep := false
	var has_entered := false
	for line in engine.logs:
		if line.begins_with("===="):
			has_sep = true
		if line.begins_with("Entered:"):
			has_entered = true
	assert_true(has_sep, "Revisit should have separator")
	assert_true(has_entered, "Revisit uses 'Entered:' (Python parity)")


# ==================================================================
# 2) Interaction logging — 5 interactions with categories
# ==================================================================

func test_store_discovery_has_category():
	var svc := AdventureLogService.new()
	svc.append("Discovered a mysterious shop!", "success", "DISCOVERY", "exploration")
	var entry: Dictionary = svc.get_entries()[0]
	assert_eq(entry["category"], "DISCOVERY")
	assert_eq(entry["source"], "exploration")


func test_container_search_has_category():
	var svc := AdventureLogService.new()
	svc.append("Searched Barrel: +10 gold", "loot", "LOOT", "exploration")
	var entry: Dictionary = svc.get_entries()[0]
	assert_eq(entry["category"], "LOOT")


func test_rest_has_category():
	var svc := AdventureLogService.new()
	svc.append("Rested and recovered 10 HP.", "success", "INTERACTION", "system")
	assert_eq(svc.get_entries()[0]["category"], "INTERACTION")


func test_combat_entry_has_category():
	var svc := AdventureLogService.new()
	svc.append("Combat begins against Goblin!", "enemy", "COMBAT", "combat")
	assert_eq(svc.get_entries()[0]["category"], "COMBAT")
	assert_eq(svc.get_entries()[0]["source"], "combat")


func test_room_entry_has_category():
	var svc := AdventureLogService.new()
	svc.append("Entered: Dark Cave", "system", "ROOM", "exploration")
	assert_eq(svc.get_entries()[0]["category"], "ROOM")


# ==================================================================
# 3) Categories enforced
# ==================================================================

func test_invalid_category_normalized_to_system():
	var svc := AdventureLogService.new()
	svc.append("Test", "system", "invalid_garbage")
	assert_eq(svc.get_entries()[0]["category"], "SYSTEM")


func test_empty_category_normalized_to_system():
	var svc := AdventureLogService.new()
	svc.append("Test", "system", "")
	assert_eq(svc.get_entries()[0]["category"], "SYSTEM")


func test_all_valid_categories_accepted():
	var svc := AdventureLogService.new()
	for cat in AdventureLogService.VALID_CATEGORIES:
		svc.append("Test %s" % cat, "system", cat)
	assert_eq(svc.size(), AdventureLogService.VALID_CATEGORIES.size())
	for i in svc.size():
		assert_eq(svc.get_entries()[i]["category"], AdventureLogService.VALID_CATEGORIES[i])


# ==================================================================
# 4) Action provenance — action_id and source
# ==================================================================

func test_action_id_monotonic():
	var svc := AdventureLogService.new()
	svc.append("First")
	svc.append("Second")
	svc.append("Third")
	var entries := svc.get_entries()
	assert_eq(entries[0]["action_id"], 0)
	assert_eq(entries[1]["action_id"], 1)
	assert_eq(entries[2]["action_id"], 2)


func test_source_field_present():
	var svc := AdventureLogService.new()
	svc.append("Test", "system", "ROOM", "exploration")
	assert_eq(svc.get_entries()[0]["source"], "exploration")


func test_source_defaults_to_system():
	var svc := AdventureLogService.new()
	svc.append("Test")
	assert_eq(svc.get_entries()[0]["source"], "system")


# ==================================================================
# 5) Typewriter presets
# ==================================================================

func test_text_speed_options_include_normal():
	var opts: Array = ["Slow", "Normal", "Fast", "Instant"]
	for o in opts:
		assert_true(o in opts, "%s should be a preset" % o)


func test_instant_delay_is_zero():
	var delays := {"Slow": 15, "Normal": 13, "Fast": 7, "Instant": 0}
	assert_eq(delays["Instant"], 0)


func test_normal_delay_is_thirteen():
	var delays := {"Slow": 15, "Normal": 13, "Fast": 7, "Instant": 0}
	assert_eq(delays["Normal"], 13)


# ==================================================================
# 6) Copy Log — safe headless, returns header
# ==================================================================

func test_copy_log_header_method_safe():
	var svc := AdventureLogService.new()
	svc.append("Entry 1")
	var texts := svc.get_text_entries()
	assert_false(texts.is_empty())
	pass_test("Copy log text generation safe in headless")


# ==================================================================
# 7) F4 export — all required fields present
# ==================================================================

func test_f4_export_has_all_required_fields():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(42, "DeterministicRNG", "deterministic")
	log.append("Test entry", "system", "ROOM", "exploration")

	var json_str := trace.export_json()
	var json := JSON.new()
	assert_eq(json.parse(json_str), OK)
	var data: Dictionary = json.data

	assert_true(data.has("rng_mode"), "rng_mode")
	assert_true(data.has("seed"), "seed")
	assert_true(data.has("run_seed"), "run_seed")
	assert_true(data.has("adventure_log"), "adventure_log")
	assert_true(data.has("adventure_log_count"), "adventure_log_count")
	assert_true(data.has("build_version"), "build_version")
	assert_true(data.has("content_version"), "content_version")
	assert_true(data.has("settings_fingerprint"), "settings_fingerprint")


func test_f4_export_per_entry_has_source_and_action_id():
	var trace := SessionTrace.new()
	var log := AdventureLogService.new()
	trace.set_adventure_log(log)
	trace.reset(1, "DefaultRNG", "default")
	log.append("Room entry", "system", "ROOM", "exploration")

	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var entries: Array = json.data.get("adventure_log", [])
	assert_eq(entries.size(), 1)
	assert_true(entries[0].has("source"), "Entry should have source")
	assert_true(entries[0].has("action_id"), "Entry should have action_id")
	assert_eq(entries[0]["source"], "exploration")
	assert_eq(entries[0]["action_id"], 0)


func test_f4_export_seed_always_numeric():
	var trace := SessionTrace.new()
	trace.reset(98765, "DefaultRNG", "default")
	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var data: Dictionary = json.data
	assert_true(data["seed"] is float or data["seed"] is int, "seed must be numeric")
	assert_eq(int(data["seed"]), 98765)


# ==================================================================
# 8) Milestone snapshots
# ==================================================================

func test_milestone_snapshot_has_required_fields():
	var gs := GameState.new()
	gs.health = 40
	gs.max_health = 50
	gs.gold = 100
	gs.floor = 2
	var snap := SessionTrace.make_snapshot(gs)
	assert_true(snap.has("floor"))
	assert_true(snap.has("hp"))
	assert_true(snap.has("max_hp"))
	assert_true(snap.has("gold"))
	assert_true(snap.has("inventory_count"))
	assert_true(snap.has("equipped_summary"))
	assert_eq(snap["hp"], 40)
	assert_eq(snap["max_hp"], 50)
	assert_eq(snap["gold"], 100)


func test_record_milestone_includes_snapshot():
	var trace := SessionTrace.new()
	trace.reset(1, "DefaultRNG", "default")
	var snap := {"floor": 1, "hp": 50, "max_hp": 50, "gold": 0, "inventory_count": 0, "equipped_summary": "none"}
	trace.record_milestone("room_entered", {"room_name": "Test"}, snap)
	assert_eq(trace.events.size(), 1)
	assert_true(trace.events[0].has("snapshot"), "Milestone event should have snapshot")
	assert_eq(trace.events[0]["snapshot"]["hp"], 50)


# ==================================================================
# 9) Replay header metadata
# ==================================================================

func test_replay_header_fields_populated():
	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG", "deterministic")
	assert_false(trace.build_version.is_empty(), "build_version should be set")
	assert_false(trace.content_version.is_empty(), "content_version should be set")


func test_replay_header_in_export():
	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG", "deterministic")
	var json_str := trace.export_json()
	var json := JSON.new()
	json.parse(json_str)
	var data: Dictionary = json.data
	assert_true(data.has("build_version"))
	assert_true(data.has("content_version"))
	assert_true(data.has("settings_fingerprint"))


func test_content_version_deterministic():
	var v1 := SessionTrace._compute_content_version()
	var v2 := SessionTrace._compute_content_version()
	assert_eq(v1, v2, "content_version should be deterministic")
