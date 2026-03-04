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
