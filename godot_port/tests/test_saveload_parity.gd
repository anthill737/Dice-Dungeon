extends GutTest
## Cross-language parity test: Python save/load trace vs Godot save/load trace.
##
## Both sides use PortableLCG so given the same seed they produce identical
## RNG sequences. Tests verify:
##   1) State snapshots match exactly before save
##   2) State snapshots match exactly after load (round-trip fidelity)
##   3) State snapshots match exactly after continuing execution post-load
##   4) Save JSON schema/fields are compatible
##
## Test cases:
##   1) Early floor, simple inventory
##   2) Mid floor with equipment durability + status effects
##   3) After miniboss fragment gating state changes

const SNAPSHOT_FIELDS := [
	"inventory", "equipped", "durability",
	"gold", "health", "max_health",
	"damage_bonus", "crit_chance", "reroll_bonus",
	"armor", "temp_shield", "max_inventory",
	"num_dice", "floor",
	"current_pos", "rooms_explored", "rooms_explored_on_floor",
	"stairs_found", "store_found",
	"boss_defeated", "mini_bosses_defeated", "key_fragments",
	"next_mini_boss_at", "next_boss_at",
	"room_count", "statuses",
]

const SAVE_JSON_REQUIRED_FIELDS := [
	"gold", "health", "max_health", "floor", "inventory",
	"equipped_items", "equipment_durability", "equipment_floor_level",
	"num_dice", "multiplier", "damage_bonus", "reroll_bonus", "crit_chance",
	"flags", "temp_effects", "temp_shield", "shop_discount",
	"stairs_found", "current_pos", "rooms",
	"store_found", "store_position",
	"mini_bosses_defeated", "boss_defeated",
	"mini_bosses_spawned_this_floor", "boss_spawned_this_floor",
	"rooms_explored_on_floor", "next_mini_boss_at", "next_boss_at",
	"key_fragments_collected", "special_rooms", "unlocked_rooms",
	"stats",
]


func _python_trace_path() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var repo_root := project_dir.get_base_dir()
	return repo_root.path_join("tools/parity/trace_saveload.py")


func _run_python_trace(
		seed_val: int,
		moves_csv: String,
		inv_actions_csv: String,
		save_at_step: int,
		floor_num: int = 1
) -> Dictionary:
	var script := _python_trace_path()
	var output: Array = []
	var args := [script, str(seed_val), moves_csv, inv_actions_csv, str(save_at_step), str(floor_num)]
	var exit_code := OS.execute("python3", args, output, true)
	assert_eq(exit_code, 0, "Python trace should exit 0 (seed=%d)" % seed_val)
	var stdout_text: String = output[0] if output.size() > 0 else ""
	if stdout_text.is_empty():
		fail_test("Python trace produced no output (seed=%d)" % seed_val)
		return {}
	var json := JSON.new()
	var err := json.parse(stdout_text)
	if err != OK:
		fail_test("Python trace is not valid JSON (seed=%d): %s\nOutput: %s" % [
			seed_val, json.get_error_message(), stdout_text.substr(0, 500)])
		return {}
	if not json.data is Dictionary:
		fail_test("Python trace is not a Dictionary (seed=%d)" % seed_val)
		return {}
	return json.data


func _run_godot_trace(
		seed_val: int,
		moves_arr: Array,
		inv_actions_arr: Array,
		save_at_step: int,
		floor_num: int = 1
) -> Dictionary:
	return SaveLoadTrace.generate(seed_val, moves_arr, inv_actions_arr, save_at_step, floor_num)


# ------------------------------------------------------------------
# Comparison helpers
# ------------------------------------------------------------------

func _compare_snapshots(py_snap: Dictionary, gd_snap: Dictionary, label: String) -> bool:
	var all_ok := true
	for field in SNAPSHOT_FIELDS:
		var py_val = py_snap.get(field)
		var gd_val = gd_snap.get(field)
		if not _values_equal(py_val, gd_val):
			fail_test("%s field '%s': MISMATCH\n  python = %s\n  godot  = %s" % [
				label, field, str(py_val), str(gd_val)])
			all_ok = false
	return all_ok


func _compare_save_json_schema(py_save: Dictionary, gd_save: Dictionary, label: String) -> bool:
	var all_ok := true
	for field in SAVE_JSON_REQUIRED_FIELDS:
		if not py_save.has(field):
			fail_test("%s: Python save JSON missing field '%s'" % [label, field])
			all_ok = false
		if not gd_save.has(field):
			fail_test("%s: Godot save JSON missing field '%s'" % [label, field])
			all_ok = false
	return all_ok


func _values_equal(a: Variant, b: Variant) -> bool:
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false

	if a is bool and b is bool:
		return a == b
	if a is bool or b is bool:
		return bool(a) == bool(b)

	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.01

	if a is String and b is String:
		return a == b

	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _values_equal(a[i], b[i]):
				return false
		return true

	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k):
				return false
			if not _values_equal(a[k], b[k]):
				return false
		return true

	return str(a) == str(b)


# ------------------------------------------------------------------
# Parity runner
# ------------------------------------------------------------------

func _run_parity_case(
		seed_val: int,
		moves_csv: String,
		inv_actions_csv: String,
		save_at_step: int,
		floor_num: int,
		label: String
) -> void:
	# Parse move arrays
	var moves_arr: Array = []
	for m in moves_csv.split(","):
		var s := m.strip_edges().to_upper()
		if not s.is_empty():
			moves_arr.append(s)

	var inv_arr: Array = []
	for a in inv_actions_csv.split(","):
		var s := a.strip_edges()
		if not s.is_empty():
			inv_arr.append(s)

	# Run Python trace
	var py_result := _run_python_trace(seed_val, moves_csv, inv_actions_csv, save_at_step, floor_num)
	if py_result.is_empty():
		return

	# Run Godot trace
	var gd_result := _run_godot_trace(seed_val, moves_arr, inv_arr, save_at_step, floor_num)
	assert_false(gd_result.is_empty(), "%s: Godot trace should produce results" % label)
	if gd_result.is_empty():
		return

	# Compare save JSON schema
	var py_save: Dictionary = py_result.get("save_json", {})
	var gd_save: Dictionary = gd_result.get("save_json", {})
	var schema_ok := _compare_save_json_schema(py_save, gd_save, "%s/save_schema" % label)

	# Compare snapshot before save
	var py_before: Dictionary = py_result.get("snapshot_before_save", {})
	var gd_before: Dictionary = gd_result.get("snapshot_before_save", {})
	var before_ok := _compare_snapshots(py_before, gd_before, "%s/before_save" % label)

	# Compare snapshot after load
	var py_after: Dictionary = py_result.get("snapshot_after_load", {})
	var gd_after: Dictionary = gd_result.get("snapshot_after_load", {})
	var after_ok := _compare_snapshots(py_after, gd_after, "%s/after_load" % label)

	# Compare snapshot at end
	var py_end: Dictionary = py_result.get("snapshot_end", {})
	var gd_end: Dictionary = gd_result.get("snapshot_end", {})
	var end_ok := _compare_snapshots(py_end, gd_end, "%s/end" % label)

	# Before-save should match after-load (round-trip fidelity)
	var rt_ok := _compare_snapshots(gd_before, gd_after, "%s/round_trip" % label)

	if schema_ok and before_ok and after_ok and end_ok and rt_ok:
		pass_test("%s: all checkpoints match" % label)


# ------------------------------------------------------------------
# Test case 1: Early floor, simple inventory
# ------------------------------------------------------------------

func test_parity_early_floor_simple():
	_run_parity_case(
		100,
		"E,E,N,W,S",
		"pickup:Iron Sword,equip:Iron Sword:weapon",
		3,
		1,
		"early_floor_simple"
	)


# ------------------------------------------------------------------
# Test case 2: Mid floor with equipment durability + status effects
# ------------------------------------------------------------------

func test_parity_mid_floor_durability_status():
	var moves: Array = []
	for i in 8:
		moves.append("E" if i % 2 == 0 else "N")
	var moves_csv := ",".join(moves)

	_run_parity_case(
		200,
		moves_csv,
		"pickup:Iron Sword,equip:Iron Sword:weapon,degrade:Iron Sword:30,pickup:Leather Armor,equip:Leather Armor:armor,add_status:poison",
		5,
		1,
		"mid_floor_durability_status"
	)


# ------------------------------------------------------------------
# Test case 3: After miniboss fragment gating state changes
# ------------------------------------------------------------------

func test_parity_miniboss_gating():
	var moves: Array = []
	for i in 12:
		moves.append("E" if i % 2 == 0 else "N")
	var moves_csv := ",".join(moves)

	_run_parity_case(
		999,
		moves_csv,
		"set_gold:500,pickup:Health Potion,pickup:Lucky Chip",
		7,
		1,
		"miniboss_gating"
	)


# ------------------------------------------------------------------
# Standalone save/load API tests (no Python needed)
# ------------------------------------------------------------------

func test_save_to_string_load_from_string():
	var rng := PortableLCG.new(42)
	var rooms_data := RoomsData.new()
	assert_true(rooms_data.load(), "rooms DB should load")

	var state := GameState.new()
	state.gold = 123
	state.health = 35
	state.max_health = 60
	state.inventory = ["Health Potion", "Iron Sword"]
	state.equipped_items = {"weapon": "Iron Sword", "armor": "", "accessory": "", "backpack": ""}
	state.equipment_durability = {"Iron Sword": 80}
	state.equipment_floor_level = {"Iron Sword": 1}
	state.damage_bonus = 5
	state.crit_chance = 0.15
	state.flags = {"disarm_token": 1, "escape_token": 0, "statuses": ["poison"]}
	state.temp_effects = {"crit_bonus": {"delta": 0.05, "duration": "combat"}}

	var engine := ExplorationEngine.new(rng, state, rooms_data.rooms)
	engine.start_floor(1)
	engine.move("E")
	engine.move("E")

	# Save
	var json_str := SaveEngine.save_to_string(state, engine.floor, 1, "Test Save")
	assert_false(json_str.is_empty(), "save_to_string should produce output")

	# Load into fresh state
	var new_state := GameState.new()
	var new_floor := FloorState.new()
	var ok := SaveEngine.load_from_string(json_str, new_state, new_floor)
	assert_true(ok, "load_from_string should succeed")

	# Verify key fields survived
	assert_eq(new_state.gold, 123, "gold round-trip")
	assert_eq(new_state.health, 35, "health round-trip")
	assert_eq(new_state.max_health, 60, "max_health round-trip")
	assert_eq(new_state.inventory.size(), 2, "inventory size round-trip")
	assert_eq(new_state.equipped_items["weapon"], "Iron Sword", "equipped weapon round-trip")
	assert_eq(int(new_state.equipment_durability.get("Iron Sword", 0)), 80, "durability round-trip")
	assert_eq(new_state.damage_bonus, 5, "damage_bonus round-trip")
	assert_true(absf(new_state.crit_chance - 0.15) < 0.001, "crit_chance round-trip")
	assert_eq(int(new_state.flags.get("disarm_token", 0)), 1, "flags round-trip")
	var statuses: Array = new_state.flags.get("statuses", [])
	assert_true(statuses.has("poison"), "statuses round-trip")

	# Verify floor state
	assert_eq(new_floor.current_pos, engine.floor.current_pos, "current_pos round-trip")
	assert_eq(new_floor.rooms.size(), engine.floor.rooms.size(), "room count round-trip")
	assert_eq(new_floor.stairs_found, engine.floor.stairs_found, "stairs_found round-trip")

	pass_test("save_to_string/load_from_string round-trip passed")


func test_serialize_deserialize_rooms_fidelity():
	var rng := PortableLCG.new(77)
	var rooms_data := RoomsData.new()
	assert_true(rooms_data.load(), "rooms DB should load")

	var state := GameState.new()
	var engine := ExplorationEngine.new(rng, state, rooms_data.rooms)
	engine.start_floor(1)

	# Explore several rooms to build dungeon
	for d in ["E", "E", "N", "N", "W", "S", "E"]:
		engine.move(d)

	var save_dict := SaveEngine.serialize(state, engine.floor)

	var new_state := GameState.new()
	var new_floor := FloorState.new()
	SaveEngine.deserialize(save_dict, new_state, new_floor)

	# Verify every room round-tripped
	assert_eq(new_floor.rooms.size(), engine.floor.rooms.size(), "room count match")
	for pos_key in engine.floor.rooms:
		assert_true(new_floor.rooms.has(pos_key), "room at %s exists" % str(pos_key))
		var orig: RoomState = engine.floor.rooms[pos_key]
		var loaded: RoomState = new_floor.rooms[pos_key]
		assert_eq(loaded.x, orig.x, "room x at %s" % str(pos_key))
		assert_eq(loaded.y, orig.y, "room y at %s" % str(pos_key))
		assert_eq(loaded.visited, orig.visited, "room visited at %s" % str(pos_key))
		assert_eq(loaded.has_combat, orig.has_combat, "room has_combat at %s" % str(pos_key))
		assert_eq(loaded.has_stairs, orig.has_stairs, "room has_stairs at %s" % str(pos_key))
		assert_eq(loaded.ground_container, orig.ground_container, "room container at %s" % str(pos_key))
		assert_eq(loaded.ground_gold, orig.ground_gold, "room gold at %s" % str(pos_key))

	pass_test("room fidelity round-trip passed")


func test_slot_management():
	var state := GameState.new()
	state.gold = 42
	var floor_st := FloorState.new()
	floor_st.rooms[Vector2i.ZERO] = RoomState.new({}, 0, 0)
	floor_st.current_pos = Vector2i.ZERO

	var tmp_dir := "user://test_saves_" + str(randi())
	DirAccess.make_dir_recursive_absolute(tmp_dir)

	# Valid slot range
	assert_true(SaveEngine.is_valid_slot(1), "slot 1 valid")
	assert_true(SaveEngine.is_valid_slot(10), "slot 10 valid")
	assert_false(SaveEngine.is_valid_slot(0), "slot 0 invalid")
	assert_false(SaveEngine.is_valid_slot(11), "slot 11 invalid")

	# Save
	var ok := SaveEngine.save_to_slot(state, floor_st, tmp_dir, 1, "My Save")
	assert_true(ok, "save_to_slot should succeed")

	# List
	var slots := SaveEngine.list_slots(tmp_dir)
	assert_eq(slots.size(), 10, "list should return 10 slots")
	var slot1 = null
	for s in slots:
		if s.get("slot") == 1 and not s.get("empty", false):
			slot1 = s
	assert_not_null(slot1, "slot 1 should be populated")
	if slot1 != null:
		assert_eq(slot1.get("save_name"), "My Save", "save_name correct")
		assert_eq(int(slot1.get("gold", 0)), 42, "gold in listing")

	# Load
	var load_state := GameState.new()
	var load_floor := FloorState.new()
	ok = SaveEngine.load_from_slot(tmp_dir, 1, load_state, load_floor)
	assert_true(ok, "load_from_slot should succeed")
	assert_eq(load_state.gold, 42, "loaded gold correct")

	# Rename
	ok = SaveEngine.rename_slot(tmp_dir, 1, "Renamed Save")
	assert_true(ok, "rename should succeed")
	slots = SaveEngine.list_slots(tmp_dir)
	for s in slots:
		if s.get("slot") == 1 and not s.get("empty", false):
			assert_eq(s.get("save_name"), "Renamed Save", "rename applied")

	# Delete
	ok = SaveEngine.delete_slot(tmp_dir, 1)
	assert_true(ok, "delete should succeed")
	slots = SaveEngine.list_slots(tmp_dir)
	for s in slots:
		if s.get("slot") == 1:
			assert_true(s.get("empty", false), "slot 1 empty after delete")

	# Cleanup
	DirAccess.remove_absolute(tmp_dir)
	pass_test("slot management passed")


func test_deterministic_continuation():
	var rooms_data := RoomsData.new()
	assert_true(rooms_data.load(), "rooms DB should load")

	# Uninterrupted run
	var rng1 := PortableLCG.new(555)
	var state1 := GameState.new()
	var engine1 := ExplorationEngine.new(rng1, state1, rooms_data.rooms)
	engine1.start_floor(1)
	var all_moves := ["E", "E", "N", "W", "E", "N", "E", "E"]
	for d in all_moves:
		engine1.move(d)
	var end_snapshot_uninterrupted := _snapshot(state1, engine1.floor)

	# Save-load run: do 4 steps, save, load, continue 4 more
	var rng2 := PortableLCG.new(555)
	var state2 := GameState.new()
	var engine2 := ExplorationEngine.new(rng2, state2, rooms_data.rooms)
	engine2.start_floor(1)
	for i in 4:
		engine2.move(all_moves[i])

	var rng_state_at_save: int = rng2._state
	var save_json := SaveEngine.save_to_string(state2, engine2.floor)

	var state3 := GameState.new()
	var floor3 := FloorState.new()
	SaveEngine.load_from_string(save_json, state3, floor3)
	rng2._state = rng_state_at_save

	var engine3 := ExplorationEngine.new(rng2, state3, rooms_data.rooms)
	engine3.floor = floor3
	for i in range(4, 8):
		engine3.move(all_moves[i])
	var end_snapshot_reloaded := _snapshot(state3, engine3.floor)

	# Compare
	var all_ok := true
	for field in SNAPSHOT_FIELDS:
		var v1 = end_snapshot_uninterrupted.get(field)
		var v2 = end_snapshot_reloaded.get(field)
		if not _values_equal(v1, v2):
			fail_test("deterministic continuation: field '%s' mismatch\n  uninterrupted = %s\n  reloaded      = %s" % [
				field, str(v1), str(v2)])
			all_ok = false
	if all_ok:
		pass_test("deterministic continuation: uninterrupted matches save-load-continue")


func _snapshot(state: GameState, floor_st: FloorState) -> Dictionary:
	var equipped := {}
	for slot in state.equipped_items:
		equipped[slot] = state.equipped_items[slot] if not (state.equipped_items[slot] as String).is_empty() else ""

	var durability := {}
	for item in state.equipment_durability:
		durability[item] = int(state.equipment_durability[item])

	return {
		"inventory": state.inventory.duplicate(),
		"equipped": equipped,
		"durability": durability,
		"gold": state.gold,
		"health": state.health,
		"max_health": state.max_health,
		"damage_bonus": state.damage_bonus,
		"crit_chance": snapped(state.crit_chance, 0.0001),
		"reroll_bonus": state.reroll_bonus,
		"armor": state.armor,
		"temp_shield": state.temp_shield,
		"max_inventory": state.max_inventory,
		"num_dice": state.num_dice,
		"floor": state.floor,
		"current_pos": [floor_st.current_pos.x, floor_st.current_pos.y],
		"rooms_explored": floor_st.rooms_explored,
		"rooms_explored_on_floor": floor_st.rooms_explored_on_floor,
		"stairs_found": floor_st.stairs_found,
		"store_found": floor_st.store_found,
		"boss_defeated": floor_st.boss_defeated,
		"mini_bosses_defeated": floor_st.mini_bosses_defeated,
		"key_fragments": floor_st.key_fragments,
		"next_mini_boss_at": floor_st.next_mini_boss_at,
		"next_boss_at": floor_st.next_boss_at if floor_st.next_boss_at >= 0 else null,
		"room_count": floor_st.rooms.size(),
		"statuses": (state.flags.get("statuses", []) as Array).duplicate(),
	}


# ------------------------------------------------------------------
# Utility
# ------------------------------------------------------------------

func test_python_trace_script_exists():
	var path := _python_trace_path()
	assert_true(FileAccess.file_exists(path),
		"trace_saveload.py should exist at %s" % path)
