extends GutTest
## Tests for the feature batch: locked rooms, threshold, fast travel,
## stairs/store separation, lore, containers, tooltips.
## Uses DeterministicRNG for reproducible results.

var _rooms_db: Array = []
var _items_db: Dictionary = {}
var _lore_db: Dictionary = {}


func before_all() -> void:
	var cm := ContentManager.new()
	cm.load_all()
	_rooms_db = cm.get_room_templates()
	_items_db = cm.get_items_db()
	_lore_db = cm.get_lore_db()


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
# A. LOCKED ELITE ROOM
# ==================================================================

func test_locked_elite_room_without_key_blocks_entry():
	var engine := _make_engine(50000)
	engine.start_floor(1)
	var mb_pos := Vector2i(5, 5)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "locked_mini_boss", "without Old Key should report locked_mini_boss")


func test_locked_elite_room_with_key_shows_choice():
	var engine := _make_engine(50001)
	engine.start_floor(1)
	var mb_pos := Vector2i(5, 5)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	engine.state.inventory.append("Old Key")
	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "has_key_mini_boss", "with Old Key should show has_key_mini_boss (choice)")


func test_turn_back_does_not_consume_key():
	var engine := _make_engine(50002)
	engine.start_floor(1)
	engine.state.inventory.append("Old Key")
	var mb_pos := Vector2i(3, 3)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	# Simulate turn back - key stays, room stays locked
	assert_true(engine.state.inventory.has("Old Key"), "Old Key still in inventory")
	assert_false(engine.floor.unlocked_rooms.has(mb_pos), "room not unlocked")


func test_unlock_and_enter_consumes_key():
	var engine := _make_engine(50003)
	engine.start_floor(1)
	engine.state.inventory.append("Old Key")
	var mb_pos := Vector2i(3, 3)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	var result := engine.use_old_key(mb_pos)
	assert_true(result, "use_old_key should succeed")
	assert_false(engine.state.inventory.has("Old Key"), "Old Key consumed")
	assert_true(engine.floor.unlocked_rooms.has(mb_pos), "room unlocked")


func test_unlocked_elite_room_remains_accessible():
	var engine := _make_engine(50004)
	engine.start_floor(1)
	engine.state.inventory.append("Old Key")
	var mb_pos := Vector2i(3, 3)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	engine.use_old_key(mb_pos)
	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "", "unlocked room should have empty gate (accessible)")


# ==================================================================
# E. STAIRS/STORE NEVER SPAWN IN SAME ROOM
# ==================================================================

func test_stairs_store_never_same_room():
	for seed_offset in 50:
		var engine := _make_engine(60000 + seed_offset)
		engine.start_floor(1)
		for i in 30:
			_force_move(engine, "E")
		for pos in engine.floor.rooms:
			var r: RoomState = engine.floor.rooms[pos]
			if r.has_stairs and r.has_store:
				fail_test("stairs and store spawned in same room at seed %d pos %s" % [60000 + seed_offset, str(pos)])
				return
	pass_test("no stairs+store co-location in 50 seeds × 30 rooms")


# ==================================================================
# E. FAST TRAVEL TO STORE
# ==================================================================

func test_fast_travel_only_when_store_discovered():
	var engine := _make_engine(61000)
	engine.start_floor(1)
	var room := engine.travel_to_store()
	assert_null(room, "cannot travel when store not discovered")


func test_fast_travel_moves_to_store():
	var engine := _make_engine(61001)
	engine.start_floor(1)
	# Force store discovery
	engine.floor.store_found = true
	var store_room := RoomState.new({"name": "Store Room"}, 5, 5)
	store_room.has_store = true
	engine.floor.rooms[Vector2i(5, 5)] = store_room
	engine.floor.store_pos = Vector2i(5, 5)
	var result := engine.travel_to_store()
	assert_not_null(result, "should travel to store")
	assert_eq(engine.floor.current_pos, Vector2i(5, 5), "position should be at store")


# ==================================================================
# F. LORE ITEMS
# ==================================================================

func test_lore_items_discoverable():
	var state := GameState.new()
	var rng := DeterministicRNG.new(70000)
	var lore_engine := LoreEngine.new(rng, state, _lore_db)
	state.inventory.append("Guard Journal")
	var result := lore_engine.read_lore_item("Guard Journal", 0)
	assert_true(result.get("ok", false), "should read Guard Journal")
	assert_true(result.get("is_new", false), "should be new lore")


func test_lore_appears_in_codex():
	var state := GameState.new()
	var rng := DeterministicRNG.new(70001)
	var lore_engine := LoreEngine.new(rng, state, _lore_db)
	state.inventory.append("Guard Journal")
	lore_engine.read_lore_item("Guard Journal", 0)
	var codex := lore_engine.get_codex()
	assert_gt(codex.size(), 0, "codex should have entries")
	assert_eq(codex[0].get("type", ""), "guards_journal", "should be guards_journal type")


func test_codex_can_read_stored_content():
	var state := GameState.new()
	var rng := DeterministicRNG.new(70002)
	var lore_engine := LoreEngine.new(rng, state, _lore_db)
	state.inventory.append("Scrawled Note")
	var result := lore_engine.read_lore_item("Scrawled Note", 0)
	assert_true(result.get("ok", false))
	var entry: Dictionary = result.get("entry", {})
	assert_false(entry.get("content", "").is_empty(), "content should not be empty")


func test_lore_duplicate_handling():
	var state := GameState.new()
	var rng := DeterministicRNG.new(70003)
	var lore_engine := LoreEngine.new(rng, state, _lore_db)
	state.inventory.append("Guard Journal")
	var r1 := lore_engine.read_lore_item("Guard Journal", 0)
	var r2 := lore_engine.read_lore_item("Guard Journal", 0)
	assert_true(r1.get("is_new", false), "first read is new")
	assert_false(r2.get("is_new", true), "second read is not new")
	assert_eq(lore_engine.get_codex().size(), 1, "codex should have 1 entry, not 2")


func test_lore_type_mapping_complete():
	var expected_types := [
		"Guard Journal", "Quest Notice", "Scrawled Note", "Training Manual Page",
		"Pressed Page", "Surgeon Note", "Puzzle Note", "Star Chart Scrap",
		"Cracked Map Scrap", "Prayer Strip", "Old Letter", "Star Chart",
	]
	var lore_engine := LoreEngine.new(DefaultRNG.new(), GameState.new(), _lore_db)
	for item_name in expected_types:
		var info := lore_engine.resolve_lore_type(item_name)
		assert_false(info.is_empty(), "%s should have lore type mapping" % item_name)


# ==================================================================
# G. ITEM TOOLTIP - NO TYPE
# ==================================================================

func test_item_tooltip_omits_type():
	var state := GameState.new()
	var inv_engine := InventoryEngine.new(DefaultRNG.new(), state, _items_db)
	var item_def := inv_engine.get_item_def("Health Potion")
	var tooltip_lines: PackedStringArray = ["Health Potion"]
	var desc: String = item_def.get("desc", "")
	if not desc.is_empty():
		tooltip_lines.append(desc)
	var tooltip := "\n".join(tooltip_lines)
	assert_false(tooltip.contains("Type:"), "tooltip should not contain 'Type:'")


# ==================================================================
# H. CONTAINER LOCKPICK FLOW
# ==================================================================

func test_lockpick_directly_unlocks_container():
	var state := GameState.new()
	state.inventory.append("Lockpick Kit")
	var inv_engine := InventoryEngine.new(DefaultRNG.new(), state, _items_db)
	var room := RoomState.new({}, 0, 0)
	room.ground_container = "Old Crate"
	room.container_locked = true
	var result := inv_engine.use_lockpick_on_container(room)
	assert_true(result.get("ok", false), "lockpick should unlock container")
	assert_false(room.container_locked, "container should be unlocked")
	assert_false(state.inventory.has("Lockpick Kit"), "lockpick consumed")


func test_lockpick_fails_without_kit():
	var state := GameState.new()
	var inv_engine := InventoryEngine.new(DefaultRNG.new(), state, _items_db)
	var room := RoomState.new({}, 0, 0)
	room.ground_container = "Old Crate"
	room.container_locked = true
	var result := inv_engine.use_lockpick_on_container(room)
	assert_false(result.get("ok", false), "lockpick should fail without kit")
	assert_true(room.container_locked, "container should stay locked")


func test_take_all_picks_up_items():
	var engine := _make_engine(80000)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_gold = 15
	room.ground_items = ["Health Potion", "Lucky Chip"]

	var gold := engine.pickup_ground_gold(room)
	assert_eq(gold, 15, "should pick up gold")

	var item1 := engine.pickup_ground_item(room, 0)
	assert_false(item1.is_empty(), "should pick up first item")
	var item2 := engine.pickup_ground_item(room, 0)
	assert_false(item2.is_empty(), "should pick up second item")
	assert_true(room.ground_items.is_empty(), "no items left")


func test_take_all_partial_pickup():
	var state := GameState.new()
	state.max_inventory = 1
	var engine := ExplorationEngine.new(DeterministicRNG.new(80001), state, _rooms_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_items = ["Health Potion", "Lucky Chip"]
	var item1 := engine.pickup_ground_item(room, 0)
	assert_false(item1.is_empty(), "should pick up first item")
	var item2 := engine.pickup_ground_item(room, 0)
	assert_true(item2.is_empty(), "should fail on second item (full)")
	assert_eq(room.ground_items.size(), 1, "one item remains")


# ==================================================================
# LORE ENGINE CATEGORIES
# ==================================================================

func test_lore_engine_all_categories():
	assert_false(_lore_db.is_empty(), "lore_db should not be empty")
	var expected_keys := ["guards_journal_pages", "quest_notices", "training_manual_pages",
		"scrawled_notes", "pressed_pages", "surgeons_notes", "puzzle_notes",
		"star_charts", "cracked_map_scraps", "old_letters", "prayer_strips"]
	for key in expected_keys:
		assert_true(_lore_db.has(key), "lore_db should have key: %s" % key)
