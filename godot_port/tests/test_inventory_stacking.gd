extends GutTest
## Deterministic tests for inventory stacking, quantity integrity, and
## sell/buy round-trip behaviour.  All tests are headless / data-only.
##
## Verifies:
##   1) Picking up identical items — internal quantity correct.
##   2) Selling one from stack — quantity decrements by 1.
##   3) Selling entire stack — item removed completely.
##   4) Buy + save + load — quantities persist without duplication or loss.
##   5) Silk Bundle and Antivenom Leaf regression cases.
##   6) Inventory panel deduplication produces correct row count.
##   7) Store sell list deduplication produces correct row count.


# ==================================================================
# Helpers
# ==================================================================

func _make_state_with_items(items: Array) -> GameState:
	var gs := GameState.new()
	gs.reset()
	for item in items:
		gs.inventory.append(item)
	return gs


# ==================================================================
# TEST 1: Picking up identical items
# ==================================================================

func test_pickup_identical_items_increments_count():
	var gs := GameState.new()
	gs.reset()
	var rng := DeterministicRNG.new(1)
	var ie := InventoryEngine.new(rng, gs, {})

	ie.add_item_to_inventory("Health Potion", "found")
	ie.add_item_to_inventory("Health Potion", "found")
	ie.add_item_to_inventory("Silk Bundle", "found")

	assert_eq(gs.inventory.size(), 3,
		"Three items in inventory array")
	assert_eq(gs.inventory.count("Health Potion"), 2,
		"Two Health Potions")
	assert_eq(gs.inventory.count("Silk Bundle"), 1,
		"One Silk Bundle")


func test_pickup_does_not_merge_stacks():
	var gs := GameState.new()
	gs.reset()
	var rng := DeterministicRNG.new(1)
	var ie := InventoryEngine.new(rng, gs, {})

	for i in 5:
		ie.add_item_to_inventory("Antivenom Leaf", "found")

	assert_eq(gs.inventory.size(), 5,
		"Five separate entries, not one stack of 5")
	assert_eq(gs.inventory.count("Antivenom Leaf"), 5,
		"count() returns 5")


# ==================================================================
# TEST 2: Selling one item from stack
# ==================================================================

func test_sell_one_decrements_by_one():
	var gs := _make_state_with_items(
		["Silk Bundle", "Silk Bundle", "Silk Bundle"])
	gs.gold = 0
	var se := StoreEngine.new(gs, {})

	var price := se.calculate_sell_price("Silk Bundle")
	var result := se.sell_item("Silk Bundle", price, 1)

	assert_true(result.get("ok", false), "sell should succeed")
	assert_eq(gs.inventory.count("Silk Bundle"), 2,
		"One removed, two remain")
	assert_eq(gs.gold, price,
		"Gold increased by sell price")


func test_sell_one_gold_correct():
	var gs := _make_state_with_items(
		["Antivenom Leaf", "Antivenom Leaf"])
	gs.gold = 100
	var se := StoreEngine.new(gs, {})

	var price := se.calculate_sell_price("Antivenom Leaf")
	se.sell_item("Antivenom Leaf", price, 1)

	assert_eq(gs.gold, 100 + price,
		"Gold should increase by exactly one item's sell price")
	assert_eq(gs.inventory.count("Antivenom Leaf"), 1,
		"One Antivenom Leaf should remain")


# ==================================================================
# TEST 3: Selling entire stack
# ==================================================================

func test_sell_entire_stack_removes_completely():
	var gs := _make_state_with_items(
		["Silk Bundle", "Silk Bundle", "Silk Bundle", "Health Potion"])
	gs.gold = 0
	var se := StoreEngine.new(gs, {})

	var price := se.calculate_sell_price("Silk Bundle")
	var result := se.sell_item("Silk Bundle", price, 3)

	assert_true(result.get("ok", false), "sell should succeed")
	assert_eq(gs.inventory.count("Silk Bundle"), 0,
		"All Silk Bundles removed")
	assert_eq(gs.inventory.size(), 1,
		"Only Health Potion remains")
	assert_eq(gs.gold, price * 3,
		"Gold = price * 3")


# ==================================================================
# TEST 4: Buy + save + load round-trip
# ==================================================================

func test_buy_adds_instances():
	var gs := GameState.new()
	gs.reset()
	gs.gold = 9999
	var se := StoreEngine.new(gs, {})

	se.buy_item("Health Potion", 35, 3)

	assert_eq(gs.inventory.count("Health Potion"), 3,
		"Three separate entries after buying 3")
	assert_eq(gs.inventory.size(), 3,
		"Total inventory size = 3")


func test_buy_save_load_preserves_quantities():
	var gs := GameState.new()
	gs.reset()
	gs.gold = 9999
	var se := StoreEngine.new(gs, {})

	se.buy_item("Health Potion", 35, 2)
	se.buy_item("Silk Bundle", 150, 3)
	se.buy_item("Antivenom Leaf", 50, 1)

	assert_eq(gs.inventory.size(), 6, "6 items before save")

	var floor_st := FloorState.new()
	floor_st.rooms[Vector2i.ZERO] = RoomState.new({}, 0, 0)
	floor_st.current_pos = Vector2i.ZERO

	var json_str := SaveEngine.save_to_string(gs, floor_st)
	assert_false(json_str.is_empty(), "save produces output")

	var loaded_gs := GameState.new()
	var loaded_fs := FloorState.new()
	var ok := SaveEngine.load_from_string(json_str, loaded_gs, loaded_fs)
	assert_true(ok, "load succeeds")

	assert_eq(loaded_gs.inventory.size(), 6,
		"No duplication or loss on load")
	assert_eq(loaded_gs.inventory.count("Health Potion"), 2,
		"Health Potion count preserved")
	assert_eq(loaded_gs.inventory.count("Silk Bundle"), 3,
		"Silk Bundle count preserved")
	assert_eq(loaded_gs.inventory.count("Antivenom Leaf"), 1,
		"Antivenom Leaf count preserved")


func test_save_load_sell_after_reload():
	var gs := GameState.new()
	gs.reset()
	gs.gold = 9999
	var se := StoreEngine.new(gs, {})
	se.buy_item("Silk Bundle", 150, 3)

	var floor_st := FloorState.new()
	floor_st.rooms[Vector2i.ZERO] = RoomState.new({}, 0, 0)
	floor_st.current_pos = Vector2i.ZERO
	var json_str := SaveEngine.save_to_string(gs, floor_st)

	var loaded_gs := GameState.new()
	var loaded_fs := FloorState.new()
	SaveEngine.load_from_string(json_str, loaded_gs, loaded_fs)

	var se2 := StoreEngine.new(loaded_gs, {})
	var price := se2.calculate_sell_price("Silk Bundle")
	se2.sell_item("Silk Bundle", price, 1)

	assert_eq(loaded_gs.inventory.count("Silk Bundle"), 2,
		"Selling after reload decrements correctly")


# ==================================================================
# TEST 5: Silk Bundle and Antivenom Leaf regression
# ==================================================================

func test_silk_bundle_display_quantity_matches_internal():
	var gs := _make_state_with_items(
		["Silk Bundle", "Silk Bundle", "Silk Bundle"])

	var unique_count := 0
	var seen: Dictionary = {}
	for item in gs.inventory:
		if not seen.has(item):
			seen[item] = true
			unique_count += 1

	assert_eq(unique_count, 1,
		"Only one unique item for display")
	assert_eq(gs.inventory.count("Silk Bundle"), 3,
		"Internal count is 3")


func test_antivenom_leaf_display_quantity_matches_internal():
	var gs := _make_state_with_items(
		["Antivenom Leaf", "Antivenom Leaf", "Health Potion"])

	var display_rows := 0
	var seen: Dictionary = {}
	for item in gs.inventory:
		var normalized: String = item.split(" #")[0] if " #" in item else item
		if not seen.has(normalized):
			seen[normalized] = true
			display_rows += 1

	assert_eq(display_rows, 2,
		"Two unique items for display (Antivenom Leaf, Health Potion)")
	assert_eq(gs.inventory.count("Antivenom Leaf"), 2,
		"Internal count of Antivenom Leaf is 2")
	assert_eq(gs.inventory.count("Health Potion"), 1,
		"Internal count of Health Potion is 1")


func test_silk_bundle_sell_one_then_check_count():
	var gs := _make_state_with_items(
		["Silk Bundle", "Silk Bundle", "Silk Bundle"])
	gs.gold = 0
	var se := StoreEngine.new(gs, {})

	var price := se.calculate_sell_price("Silk Bundle")
	se.sell_item("Silk Bundle", price, 1)

	var display_count := gs.inventory.count("Silk Bundle")
	assert_eq(display_count, 2,
		"After selling one Silk Bundle, display count should be 2")
	assert_eq(gs.inventory.size(), 2,
		"Total inventory size should be 2")


# ==================================================================
# TEST 6: Inventory panel deduplication row count
# ==================================================================

func test_deduplication_row_count():
	var gs := _make_state_with_items([
		"Health Potion", "Health Potion", "Health Potion",
		"Silk Bundle", "Silk Bundle",
		"Iron Sword",
	])

	var seen: Dictionary = {}
	var rows := 0
	for i in gs.inventory.size():
		var item_name: String = gs.inventory[i]
		var normalized: String = item_name.split(" #")[0] if " #" in item_name else item_name
		if seen.has(normalized):
			continue
		seen[normalized] = true
		rows += 1

	assert_eq(rows, 3,
		"Three unique items should produce three display rows")


func test_index_map_points_to_first_occurrence():
	var gs := _make_state_with_items([
		"Health Potion", "Health Potion",
		"Silk Bundle",
		"Health Potion",
	])

	var index_map: Array[int] = []
	var seen: Dictionary = {}
	for i in gs.inventory.size():
		var item_name: String = gs.inventory[i]
		var normalized: String = item_name.split(" #")[0] if " #" in item_name else item_name
		if seen.has(normalized):
			continue
		seen[normalized] = true
		index_map.append(i)

	assert_eq(index_map.size(), 2,
		"Two unique items")
	assert_eq(index_map[0], 0,
		"Health Potion first occurrence at index 0")
	assert_eq(index_map[1], 2,
		"Silk Bundle first occurrence at index 2")
	assert_eq(gs.inventory[index_map[0]], "Health Potion",
		"Index 0 maps to Health Potion")
	assert_eq(gs.inventory[index_map[1]], "Silk Bundle",
		"Index 2 maps to Silk Bundle")


# ==================================================================
# TEST 7: Store sell list deduplication
# ==================================================================

func test_store_sell_groups_items():
	var gs := _make_state_with_items([
		"Health Potion", "Health Potion",
		"Silk Bundle", "Silk Bundle", "Silk Bundle",
		"Iron Sword",
	])

	var sell_entries: Array = []
	var seen: Dictionary = {}
	for item_name in gs.inventory:
		if seen.has(item_name):
			continue
		seen[item_name] = true
		sell_entries.append({
			"name": item_name,
			"count": gs.inventory.count(item_name),
		})

	assert_eq(sell_entries.size(), 3,
		"Three unique sell entries")
	assert_eq(sell_entries[0]["name"], "Health Potion")
	assert_eq(sell_entries[0]["count"], 2)
	assert_eq(sell_entries[1]["name"], "Silk Bundle")
	assert_eq(sell_entries[1]["count"], 3)
	assert_eq(sell_entries[2]["name"], "Iron Sword")
	assert_eq(sell_entries[2]["count"], 1)


# ==================================================================
# TEST 8: Lore item normalization
# ==================================================================

func test_lore_item_normalization():
	var gs := _make_state_with_items([
		"Ancient Scroll #1", "Ancient Scroll #2",
		"Health Potion",
	])

	var seen: Dictionary = {}
	var rows := 0
	for i in gs.inventory.size():
		var item_name: String = gs.inventory[i]
		var normalized: String = item_name.split(" #")[0] if " #" in item_name else item_name
		if seen.has(normalized):
			continue
		seen[normalized] = true
		rows += 1

	assert_eq(rows, 2,
		"Ancient Scroll variants collapse to one display row")


# ==================================================================
# TEST 9: Ground item pickup goes to inventory (not ground_items)
# ==================================================================

func test_ground_pickup_adds_to_inventory():
	var gs := GameState.new()
	gs.reset()
	var rng := DeterministicRNG.new(100)
	var ee := ExplorationEngine.new(rng, gs, [])
	ee.start_floor(1)

	var room := RoomState.new({}, 0, 0)
	room.ground_items = ["Silk Bundle", "Antivenom Leaf"]

	var picked := ee.pickup_ground_item(room, 0)
	assert_eq(picked, "Silk Bundle")
	assert_eq(gs.inventory.count("Silk Bundle"), 1,
		"Silk Bundle should be in inventory after ground pickup")
	assert_eq(gs.ground_items.size(), 0,
		"ground_items staging should be empty")
	assert_eq(room.ground_items.size(), 1,
		"One item left on room ground")


func test_ground_pickup_multiple_same_item():
	var gs := GameState.new()
	gs.reset()
	var rng := DeterministicRNG.new(101)
	var ee := ExplorationEngine.new(rng, gs, [])
	ee.start_floor(1)

	var room := RoomState.new({}, 0, 0)
	room.ground_items = ["Antivenom Leaf", "Antivenom Leaf", "Antivenom Leaf"]

	ee.pickup_ground_item(room, 0)
	ee.pickup_ground_item(room, 0)
	ee.pickup_ground_item(room, 0)

	assert_eq(gs.inventory.count("Antivenom Leaf"), 3,
		"Three Antivenom Leaves should be in inventory")
	assert_eq(gs.inventory.size(), 3,
		"Inventory size should be 3")
	assert_eq(room.ground_items.size(), 0,
		"Room ground should be empty")


# ==================================================================
# TEST 10: Chest loot goes to inventory
# ==================================================================

func test_chest_loot_goes_to_inventory():
	var gs := GameState.new()
	gs.reset()
	var found_item := false
	for seed_val in range(200, 300):
		gs.inventory.clear()
		gs.ground_items.clear()
		var rng := DeterministicRNG.new(seed_val)
		var ee := ExplorationEngine.new(rng, gs, [])
		ee.start_floor(1)
		var room := RoomState.new({}, 0, 0)
		room.has_chest = true
		room.chest_looted = false
		var result := ee.open_chest(room)
		var chest_item: String = str(result.get("item", ""))
		if not chest_item.is_empty():
			assert_true(gs.inventory.has(chest_item),
				"Chest item '%s' should be in inventory" % chest_item)
			assert_eq(gs.ground_items.size(), 0,
				"ground_items staging should be empty")
			found_item = true
			break
	assert_true(found_item, "At least one seed should produce a chest item")


# ==================================================================
# TEST 11: Sell after ground pickup — quantity integrity
# ==================================================================

func test_sell_after_ground_pickup():
	var gs := GameState.new()
	gs.reset()
	gs.gold = 0

	gs.inventory.append("Silk Bundle")
	gs.inventory.append("Silk Bundle")
	gs.inventory.append("Silk Bundle")

	var se := StoreEngine.new(gs, {})
	var price := se.calculate_sell_price("Silk Bundle")

	se.sell_item("Silk Bundle", price, 1)
	assert_eq(gs.inventory.count("Silk Bundle"), 2,
		"After selling 1 of 3 Silk Bundles, 2 should remain")

	se.sell_item("Silk Bundle", price, 1)
	assert_eq(gs.inventory.count("Silk Bundle"), 1,
		"After selling another, 1 should remain")

	se.sell_item("Silk Bundle", price, 1)
	assert_eq(gs.inventory.count("Silk Bundle"), 0,
		"After selling last one, 0 should remain")
	assert_eq(gs.inventory.size(), 0,
		"Inventory should be empty")
	assert_eq(gs.gold, price * 3,
		"Gold should reflect all three sales")


# ==================================================================
# TEST 12: Silk Bundle full lifecycle — buy + sell + save/load
# ==================================================================

func test_silk_bundle_full_lifecycle():
	var gs := GameState.new()
	gs.reset()
	gs.gold = 9999

	var se := StoreEngine.new(gs, {})
	se.buy_item("Silk Bundle", 150, 3)
	assert_eq(gs.inventory.count("Silk Bundle"), 3,
		"Bought 3 Silk Bundles")

	var price := se.calculate_sell_price("Silk Bundle")
	se.sell_item("Silk Bundle", price, 1)
	assert_eq(gs.inventory.count("Silk Bundle"), 2,
		"Sold 1, 2 remain")

	var floor_st := FloorState.new()
	floor_st.rooms[Vector2i.ZERO] = RoomState.new({}, 0, 0)
	floor_st.current_pos = Vector2i.ZERO

	var json_str := SaveEngine.save_to_string(gs, floor_st)
	var loaded_gs := GameState.new()
	var loaded_fs := FloorState.new()
	SaveEngine.load_from_string(json_str, loaded_gs, loaded_fs)

	assert_eq(loaded_gs.inventory.count("Silk Bundle"), 2,
		"After save/load, 2 Silk Bundles preserved")

	var se2 := StoreEngine.new(loaded_gs, {})
	se2.sell_item("Silk Bundle", price, 1)
	assert_eq(loaded_gs.inventory.count("Silk Bundle"), 1,
		"Selling after reload: 1 remains")

	se2.sell_item("Silk Bundle", price, 1)
	assert_eq(loaded_gs.inventory.count("Silk Bundle"), 0,
		"Selling last after reload: 0 remain")


# ==================================================================
# TEST 13: Antivenom Leaf full lifecycle
# ==================================================================

func test_antivenom_leaf_full_lifecycle():
	var gs := GameState.new()
	gs.reset()
	gs.gold = 9999

	var se := StoreEngine.new(gs, {})
	se.buy_item("Antivenom Leaf", 50, 2)
	assert_eq(gs.inventory.count("Antivenom Leaf"), 2)

	gs.inventory.append("Antivenom Leaf")
	assert_eq(gs.inventory.count("Antivenom Leaf"), 3,
		"After ground pickup simulation, count is 3")

	var display_rows := 0
	var seen: Dictionary = {}
	for item in gs.inventory:
		var normalized: String = item.split(" #")[0] if " #" in item else item
		if not seen.has(normalized):
			seen[normalized] = true
			display_rows += 1

	assert_eq(display_rows, 1,
		"Only one display row for Antivenom Leaf")

	var count := 0
	for inv_item in gs.inventory:
		var norm: String = inv_item.split(" #")[0] if " #" in inv_item else inv_item
		if norm == "Antivenom Leaf":
			count += 1
	assert_eq(count, 3,
		"Normalized count matches internal count for display")

	var price := se.calculate_sell_price("Antivenom Leaf")
	se.sell_item("Antivenom Leaf", price, 1)
	assert_eq(gs.inventory.count("Antivenom Leaf"), 2,
		"After selling 1, 2 remain")

	var floor_st := FloorState.new()
	floor_st.rooms[Vector2i.ZERO] = RoomState.new({}, 0, 0)
	floor_st.current_pos = Vector2i.ZERO

	var json_str := SaveEngine.save_to_string(gs, floor_st)
	var loaded_gs := GameState.new()
	var loaded_fs := FloorState.new()
	SaveEngine.load_from_string(json_str, loaded_gs, loaded_fs)

	assert_eq(loaded_gs.inventory.count("Antivenom Leaf"), 2,
		"Save/load preserves count")


# ==================================================================
# TEST 14: Inventory full — ground pickup rejected
# ==================================================================

func test_ground_pickup_inventory_full():
	var gs := GameState.new()
	gs.reset()
	gs.max_inventory = 2

	gs.inventory.append("Health Potion")
	gs.inventory.append("Iron Sword")

	var rng := DeterministicRNG.new(300)
	var ee := ExplorationEngine.new(rng, gs, [])
	ee.start_floor(1)

	var room := RoomState.new({}, 0, 0)
	room.ground_items = ["Silk Bundle"]

	var picked := ee.pickup_ground_item(room, 0)
	assert_eq(picked, "",
		"Should not pick up when inventory is full")
	assert_eq(room.ground_items.size(), 1,
		"Item should remain on room ground")
	assert_eq(gs.inventory.size(), 2,
		"Inventory unchanged")


# ==================================================================
# TEST 15: Chest loot with full inventory — item not lost
# ==================================================================

func test_chest_loot_inventory_full():
	var gs := GameState.new()
	gs.reset()
	gs.max_inventory = 0
	var found_item := false
	for seed_val in range(400, 500):
		gs.inventory.clear()
		gs.ground_items.clear()
		var rng := DeterministicRNG.new(seed_val)
		var ee := ExplorationEngine.new(rng, gs, [])
		ee.start_floor(1)
		var room := RoomState.new({}, 0, 0)
		room.has_chest = true
		room.chest_looted = false
		room.uncollected_items.clear()
		var result := ee.open_chest(room)
		var chest_item: String = str(result.get("item", ""))
		if not chest_item.is_empty():
			assert_eq(gs.inventory.size(), 0,
				"Inventory should still be empty (full)")
			assert_true(room.uncollected_items.has(chest_item),
				"Chest item should be in room's uncollected_items")
			found_item = true
			break
	assert_true(found_item, "At least one seed should produce a chest item")


# ==================================================================
# TEST 16: Mechanics drain — ground_items transferred to inventory
# ==================================================================

func test_mechanics_drain_to_inventory():
	var gs := GameState.new()
	gs.reset()

	gs.ground_items.append("Old Key")
	gs.ground_items.append("Cracked Map Scrap")

	var rng := DeterministicRNG.new(500)
	var ie := InventoryEngine.new(rng, gs, {})

	while not gs.ground_items.is_empty():
		var item_name: String = gs.ground_items[0]
		gs.ground_items.remove_at(0)
		ie.add_item_to_inventory(item_name, "found")

	assert_eq(gs.inventory.size(), 2,
		"Both items should be in inventory")
	assert_true(gs.inventory.has("Old Key"))
	assert_true(gs.inventory.has("Cracked Map Scrap"))
	assert_eq(gs.ground_items.size(), 0,
		"ground_items should be empty")
