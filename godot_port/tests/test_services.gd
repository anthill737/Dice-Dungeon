extends GutTest
## Tests for TooltipFormatter, ThresholdService, and fast travel safety.


# ==================================================================
# TooltipFormatter
# ==================================================================

func test_tooltip_no_type_field():
	var item_def := {"type": "heal", "heal": 20, "desc": "A standard healing potion."}
	var result := TooltipFormatter.format("Health Potion", item_def)
	assert_false(result.contains("Type:"), "tooltip should not contain 'Type:'")
	assert_true(result.contains("Health Potion"), "should contain item name")
	assert_true(result.contains("A standard healing potion"), "should contain desc")


func test_tooltip_includes_effects():
	var item_def := {"type": "buff", "damage_bonus": 3, "crit_bonus": 0.05, "desc": "A buff."}
	var result := TooltipFormatter.format("Power Stone", item_def)
	assert_true(result.contains("+3 Damage"), "should show damage bonus")
	assert_true(result.contains("+5% Crit"), "should show crit bonus")


func test_tooltip_heal_effect():
	var item_def := {"type": "heal", "heal": 30, "desc": "Herbs."}
	var result := TooltipFormatter.format("Healing Poultice", item_def)
	assert_true(result.contains("Heals 30 HP"), "should show heal amount")


func test_tooltip_equipment_effects():
	var item_def := {"type": "equipment", "slot": "weapon", "damage_bonus": 4, "max_durability": 100, "desc": "A weapon."}
	var result := TooltipFormatter.format("Iron Sword", item_def)
	assert_true(result.contains("+4 Damage"), "should show damage")
	assert_false(result.contains("Type:"), "no type in equipment tooltip")


func test_tooltip_armor_effects():
	var item_def := {"type": "equipment", "slot": "armor", "max_hp_bonus": 20, "armor_bonus": 2, "desc": "Armor."}
	var result := TooltipFormatter.format("Chain Vest", item_def)
	assert_true(result.contains("+20 Max HP"), "should show HP bonus")
	assert_true(result.contains("+2 Armor"), "should show armor bonus")


func test_tooltip_empty_def():
	var result := TooltipFormatter.format("Unknown Item", {})
	assert_eq(result, "Unknown Item", "should just return name for empty def")


func test_tooltip_stable_formatting():
	var item_def := {"type": "heal", "heal": 20, "desc": "A potion."}
	var r1 := TooltipFormatter.format("Health Potion", item_def)
	var r2 := TooltipFormatter.format("Health Potion", item_def)
	assert_eq(r1, r2, "formatting should be deterministic")


# ==================================================================
# ThresholdService
# ==================================================================

func test_threshold_loads_data():
	var cm := ContentManager.new()
	cm.load_all()
	var svc := ThresholdService.new(cm.get_world_lore())
	assert_eq(svc.get_area_name(), "The Threshold Chamber")
	assert_false(svc.get_description().is_empty(), "should have description")


func test_threshold_signs():
	var cm := ContentManager.new()
	cm.load_all()
	var svc := ThresholdService.new(cm.get_world_lore())
	var signs := svc.get_signs()
	assert_gte(signs.size(), 4, "should have at least 4 signs")
	for sign_data in signs:
		assert_true(sign_data.has("title"), "sign should have title")
		assert_true(sign_data.has("text"), "sign should have text")


func test_threshold_starter_chests():
	var cm := ContentManager.new()
	cm.load_all()
	var svc := ThresholdService.new(cm.get_world_lore())
	var chests := svc.get_starter_chests()
	assert_eq(chests.size(), 2, "should have 2 starter chests")
	for chest_data in chests:
		assert_true(chest_data.has("id"), "chest should have id")
		assert_true(chest_data.has("items"), "chest should have items")
		assert_true(chest_data.has("gold"), "chest should have gold")


func test_threshold_open_chest():
	var cm := ContentManager.new()
	cm.load_all()
	var svc := ThresholdService.new(cm.get_world_lore())
	var state := GameState.new()
	var inv := InventoryEngine.new(DefaultRNG.new(), state, cm.get_items_db())
	var chests := svc.get_starter_chests()
	var result := svc.open_chest(chests[0], state, inv)
	assert_false(result.is_empty(), "should return result")
	assert_gt(int(result.get("gold", 0)), 0, "should have gold")
	assert_gt(result.get("items", []).size(), 0, "should have items")
	assert_eq(state.gold, int(result["gold"]), "gold applied to state")


func test_threshold_chest_cannot_reopen():
	var cm := ContentManager.new()
	cm.load_all()
	var svc := ThresholdService.new(cm.get_world_lore())
	var state := GameState.new()
	var inv := InventoryEngine.new(DefaultRNG.new(), state, cm.get_items_db())
	var chests := svc.get_starter_chests()
	svc.open_chest(chests[0], state, inv)
	var result2 := svc.open_chest(chests[0], state, inv)
	assert_true(result2.is_empty(), "second open should return empty")


func test_threshold_chest_opened_tracking():
	var cm := ContentManager.new()
	cm.load_all()
	var svc := ThresholdService.new(cm.get_world_lore())
	var chests := svc.get_starter_chests()
	var chest_id: int = int(chests[0].get("id", 0))
	assert_false(svc.is_chest_opened(chest_id), "chest not opened yet")
	svc.open_chest(chests[0], GameState.new(), null)
	assert_true(svc.is_chest_opened(chest_id), "chest should be opened")


# ==================================================================
# Fast Travel Safety
# ==================================================================

func test_fast_travel_blocked_when_undiscovered():
	var cm := ContentManager.new()
	cm.load_all()
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(100000), state, cm.get_room_templates(), cm.get_container_db())
	engine.start_floor(1)
	assert_false(engine.floor.store_found, "store not found initially")
	var result := engine.travel_to_store()
	assert_null(result, "should not travel when store undiscovered")


func test_fast_travel_blocked_at_store():
	var cm := ContentManager.new()
	cm.load_all()
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(100001), state, cm.get_room_templates(), cm.get_container_db())
	engine.start_floor(1)
	engine.floor.store_found = true
	engine.floor.store_pos = Vector2i.ZERO
	var result := engine.travel_to_store()
	assert_null(result, "should not travel when already at store")


func test_fast_travel_works_when_valid():
	var cm := ContentManager.new()
	cm.load_all()
	var state := GameState.new()
	var engine := ExplorationEngine.new(DeterministicRNG.new(100002), state, cm.get_room_templates(), cm.get_container_db())
	engine.start_floor(1)
	var store_room := RoomState.new({"name": "Store Room"}, 5, 5)
	store_room.has_store = true
	engine.floor.rooms[Vector2i(5, 5)] = store_room
	engine.floor.store_found = true
	engine.floor.store_pos = Vector2i(5, 5)
	var result := engine.travel_to_store()
	assert_not_null(result, "should travel successfully")
	assert_eq(engine.floor.current_pos, Vector2i(5, 5))


func test_stairs_store_never_same_room():
	var cm := ContentManager.new()
	cm.load_all()
	for seed_offset in 30:
		var state := GameState.new()
		var engine := ExplorationEngine.new(DeterministicRNG.new(101000 + seed_offset), state, cm.get_room_templates(), cm.get_container_db())
		engine.start_floor(1)
		for i in 25:
			var room := engine.move("E")
			if room == null:
				for alt in ["N", "S", "W"]:
					room = engine.move(alt)
					if room != null:
						break
		for pos in engine.floor.rooms:
			var r: RoomState = engine.floor.rooms[pos]
			if r.has_stairs and r.has_store:
				fail_test("stairs+store in same room at seed %d" % (101000 + seed_offset))
				return
	pass_test("no stairs+store co-location in 30 seeds")


# ==================================================================
# Lore Name Alignment
# ==================================================================

func test_lore_type_map_primary_keys_exist_in_items_db():
	var cm := ContentManager.new()
	cm.load_all()
	var items_db := cm.get_items_db()
	var primary_lore_items := [
		"Guard Journal", "Quest Notice", "Scrawled Note",
		"Training Manual Page", "Pressed Page", "Surgeon Note",
		"Puzzle Note", "Star Chart Scrap", "Cracked Map Scrap",
		"Prayer Strip", "Old Letter", "Star Chart",
	]
	for key in primary_lore_items:
		assert_true(items_db.has(key), "primary lore item '%s' should exist in items_db" % key)


func test_lore_category_keys_exist_in_lore_db():
	var cm := ContentManager.new()
	cm.load_all()
	var lore_db := cm.get_lore_db()
	for key in LoreEngine.LORE_TYPE_MAP:
		var info: Array = LoreEngine.LORE_TYPE_MAP[key]
		var lore_key: String = info[1]
		assert_true(lore_db.has(lore_key), "lore_key '%s' (from '%s') should exist in lore_db" % [lore_key, key])


func test_container_lore_items_trackable():
	var cm := ContentManager.new()
	cm.load_all()
	var container_db := cm.get_container_db()
	var lore_pools_found := 0
	for cname in container_db:
		var cdef: Dictionary = container_db[cname]
		var pools: Dictionary = cdef.get("loot_pools", {})
		if pools.has("lore"):
			lore_pools_found += 1
			var lore_pool: Array = pools["lore"]
			for item_name in lore_pool:
				var info := LoreEngine.new(DefaultRNG.new(), GameState.new(), cm.get_lore_db()).resolve_lore_type(str(item_name))
				assert_false(info.is_empty(), "container lore item '%s' should have lore type mapping" % str(item_name))
	assert_gt(lore_pools_found, 0, "at least some containers should have lore pools")
