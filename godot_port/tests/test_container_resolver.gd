extends GutTest
## Tests for ContainerResolver and container loot system.
## Verifies JSON-driven per-container loot pools, determinism, and flows.

var _container_db: Dictionary = {}
var _items_db: Dictionary = {}
var _rooms_db: Array = []


func before_all() -> void:
	var cm := ContentManager.new()
	cm.load_all()
	_container_db = cm.get_container_db()
	_items_db = cm.get_items_db()
	_rooms_db = cm.get_room_templates()


# ==================================================================
# ContainerResolver — JSON-driven loot pools
# ==================================================================

func test_container_db_loads():
	assert_false(_container_db.is_empty(), "container_db should load")
	assert_true(_container_db.has("Old Crate"), "should have Old Crate")
	assert_true(_container_db.has("Dusty Chest"), "should have Dusty Chest")
	assert_true(_container_db.has("Treasure Chest"), "should have Treasure Chest")


func test_container_def_has_required_keys():
	for cname in _container_db:
		var cdef: Dictionary = _container_db[cname]
		assert_true(cdef.has("description"), "%s missing description" % cname)
		assert_true(cdef.has("loot_table"), "%s missing loot_table" % cname)
		assert_true(cdef.has("loot_pools"), "%s missing loot_pools" % cname)


func test_resolve_loot_returns_gold_and_item():
	var rng := DeterministicRNG.new(90000)
	var cdef: Dictionary = _container_db["Old Crate"]
	var result := ContainerResolver.resolve_loot(rng, cdef)
	assert_true(result.has("gold"), "result should have gold key")
	assert_true(result.has("item"), "result should have item key")


func test_resolve_loot_deterministic():
	var cdef: Dictionary = _container_db["Dusty Chest"]
	var result_a := ContainerResolver.resolve_loot(DeterministicRNG.new(91000), cdef)
	var result_b := ContainerResolver.resolve_loot(DeterministicRNG.new(91000), cdef)
	assert_eq(result_a["gold"], result_b["gold"], "gold should be deterministic")
	assert_eq(result_a["item"], result_b["item"], "item should be deterministic")


func test_resolve_loot_different_seeds():
	var cdef: Dictionary = _container_db["Treasure Chest"]
	var results: Array = []
	for i in 20:
		var result := ContainerResolver.resolve_loot(DeterministicRNG.new(92000 + i), cdef)
		results.append(result)
	var any_gold := false
	var any_item := false
	for r in results:
		if int(r["gold"]) > 0:
			any_gold = true
		if not str(r["item"]).is_empty():
			any_item = true
	assert_true(any_gold, "some seeds should produce gold")
	assert_true(any_item, "some seeds should produce items")


func test_container_gold_ranges_from_json():
	var cdef: Dictionary = _container_db["Merchant's Strongbox"]
	var gold_data: Dictionary = cdef["loot_pools"]["gold"]
	var gold_min: int = int(gold_data["min"])
	var gold_max: int = int(gold_data["max"])
	for i in 50:
		var result := ContainerResolver.resolve_loot(DeterministicRNG.new(93000 + i), cdef)
		var g: int = int(result["gold"])
		if g > 0:
			assert_gte(g, gold_min, "gold >= container min (%d)" % gold_min)
			assert_lte(g, gold_max, "gold <= container max (%d)" % gold_max)


func test_container_items_from_correct_pool():
	var cdef: Dictionary = _container_db["Old Crate"]
	var common_pool: Array = cdef["loot_pools"]["common_item"]
	for i in 50:
		var result := ContainerResolver.resolve_loot(DeterministicRNG.new(94000 + i), cdef)
		var item: String = str(result["item"])
		if not item.is_empty():
			assert_true(common_pool.has(item),
				"item '%s' should be from Old Crate's common_item pool" % item)


func test_dusty_chest_can_produce_lore():
	var cdef: Dictionary = _container_db["Dusty Chest"]
	var lore_pool: Array = cdef["loot_pools"]["lore"]
	var found_lore := false
	for i in 200:
		var result := ContainerResolver.resolve_loot(DeterministicRNG.new(95000 + i), cdef)
		var item: String = str(result["item"])
		if not item.is_empty() and lore_pool.has(item):
			found_lore = true
			break
	assert_true(found_lore, "Dusty Chest should occasionally produce lore items")


# ==================================================================
# ExplorationEngine.search_container — uses ContainerResolver
# ==================================================================

func test_search_container_uses_json_pools():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(96000), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_container = "Old Crate"
	var result := engine.search_container(room)
	assert_true(room.container_searched, "should mark as searched")
	assert_true(result.has("gold"), "result has gold")
	assert_true(result.has("item"), "result has item")


func test_search_container_locked_blocks():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(96001), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_container = "Iron Lockbox"
	room.container_locked = true
	var result := engine.search_container(room)
	assert_true(result.get("locked", false), "locked container should report locked")
	assert_false(room.container_searched, "should not mark as searched when locked")


func test_search_container_persists_contents():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(96002), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_container = "Treasure Chest"
	var result1 := engine.search_container(room)
	var result2 := engine.search_container(room)
	assert_eq(result1["gold"], result2["gold"], "re-searching returns same gold")
	assert_eq(result1["item"], result2["item"], "re-searching returns same item")


func test_search_container_no_reroll_on_reopen():
	var state := GameState.new()
	var rng := DeterministicRNG.new(96003)
	var engine := ExplorationEngine.new(rng, state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_container = "Hidden Nook"
	engine.search_container(room)
	var gold_after_search := room.container_gold
	var item_after_search := room.container_item
	# Calling again should not change contents
	engine.search_container(room)
	assert_eq(room.container_gold, gold_after_search, "gold should not change on re-search")
	assert_eq(room.container_item, item_after_search, "item should not change on re-search")


# ==================================================================
# Container take actions via ExplorationEngine
# ==================================================================

func test_take_container_gold():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(97000), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.container_gold = 15
	var taken := engine.take_container_gold(room)
	assert_eq(taken, 15, "should take 15 gold")
	assert_eq(room.container_gold, 0, "room gold cleared")
	assert_eq(state.gold, 15, "state gold increased")


func test_take_container_item():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(97001), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.container_item = "Health Potion"
	var taken := engine.take_container_item(room)
	assert_eq(taken, "Health Potion", "should take item")
	assert_true(room.container_item.is_empty(), "room item cleared")
	assert_true(state.inventory.has("Health Potion"), "added to inventory")


func test_take_container_item_inventory_full():
	var state := GameState.new()
	state.max_inventory = 0
	var engine := ExplorationEngine.new(DeterministicRNG.new(97002), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.container_item = "Lucky Chip"
	var taken := engine.take_container_item(room)
	assert_true(taken.is_empty(), "should fail when full")
	assert_true(room.container_item.is_empty(), "item moved to uncollected")
	assert_true(room.uncollected_items.has("Lucky Chip"), "item in uncollected")


func test_take_all_container():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(97003), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.container_gold = 10
	room.container_item = "Bandages"
	var result := engine.take_all_container(room)
	assert_eq(int(result["gold"]), 10)
	assert_eq(str(result["item"]), "Bandages")
	assert_eq(room.container_gold, 0)
	assert_true(room.container_item.is_empty())


# ==================================================================
# Pickup all ground items via engine
# ==================================================================

func test_pickup_all_ground():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(98000), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_gold = 20
	room.ground_items = ["Health Potion", "Lucky Chip"]
	room.uncollected_items = ["Bandages"]
	var picked := engine.pickup_all_ground(room)
	assert_eq(picked, 4, "should pick up gold + 2 items + 1 uncollected")
	assert_eq(room.ground_gold, 0)
	assert_true(room.ground_items.is_empty())
	assert_true(room.uncollected_items.is_empty())


func test_pickup_all_ground_partial_full():
	var state := GameState.new()
	state.max_inventory = 1
	var engine := ExplorationEngine.new(DeterministicRNG.new(98001), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_gold = 5
	room.ground_items = ["Health Potion", "Lucky Chip", "Bandages"]
	var picked := engine.pickup_all_ground(room)
	assert_gte(picked, 2, "should pick up gold + at least 1 item")
	assert_eq(room.ground_gold, 0, "gold always collected")
	assert_gt(room.ground_items.size(), 0, "some items should remain")


# ==================================================================
# inspect_ground_items includes searched containers with remaining loot
# ==================================================================

func test_inspect_shows_searched_container_with_loot():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(99000), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_container = "Old Crate"
	room.container_searched = true
	room.container_gold = 10
	var items := engine.inspect_ground_items(room)
	var has_container := false
	for item in items:
		if item.get("type") == "container":
			has_container = true
	assert_true(has_container, "searched container with gold should appear")


func test_inspect_hides_empty_searched_container():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(99001), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.ground_container = "Old Crate"
	room.container_searched = true
	room.container_gold = 0
	room.container_item = ""
	var items := engine.inspect_ground_items(room)
	var has_container := false
	for item in items:
		if item.get("type") == "container":
			has_container = true
	assert_false(has_container, "empty searched container should not appear")


func test_inspect_includes_uncollected_and_dropped():
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(99002), state, _rooms_db, _container_db)
	engine.start_floor(1)
	var room := RoomState.new({}, 1, 0)
	room.uncollected_items = ["Bandages"]
	room.dropped_items = ["Lucky Chip"]
	var items := engine.inspect_ground_items(room)
	assert_eq(items.size(), 2, "should include uncollected + dropped")
	assert_eq(items[0]["type"], "uncollected")
	assert_eq(items[1]["type"], "dropped")
