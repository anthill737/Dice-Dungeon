extends GutTest
## Tests for the data-loading layer.
## Each test loads a JSON file from the Python repo and validates structure.


# ---------- JsonLoader low-level ----------

func test_resolve_data_path_exists():
	var path := JsonLoader.resolve_data_path("rooms_v2.json")
	assert_true(FileAccess.file_exists(path),
		"rooms_v2.json should exist at: %s" % path)


func test_load_json_invalid_file_returns_null():
	var result = JsonLoader.load_json("nonexistent_file_12345.json")
	assert_null(result, "loading missing file should return null")


# ---------- RoomsData ----------

func test_rooms_loads():
	var rd := RoomsData.new()
	assert_true(rd.load(), "RoomsData.load() should succeed")


func test_rooms_not_empty():
	var rd := RoomsData.new()
	rd.load()
	assert_gt(rd.rooms.size(), 0, "rooms array should not be empty")


func test_rooms_count():
	var rd := RoomsData.new()
	rd.load()
	assert_gte(rd.rooms.size(), 100, "should have at least 100 rooms")


func test_rooms_required_keys():
	var rd := RoomsData.new()
	rd.load()
	var first: Dictionary = rd.rooms[0]
	for key in RoomsData.REQUIRED_KEYS:
		assert_true(first.has(key), "room should have key '%s'" % key)


func test_rooms_have_difficulty():
	var rd := RoomsData.new()
	rd.load()
	var difficulties := []
	for room in rd.rooms:
		var d: String = room["difficulty"]
		if d not in difficulties:
			difficulties.append(d)
	assert_true(difficulties.has("Easy"), "should have Easy rooms")
	assert_true(difficulties.has("Medium"), "should have Medium rooms")


# ---------- ItemsData ----------

func test_items_loads():
	var id := ItemsData.new()
	assert_true(id.load(), "ItemsData.load() should succeed")


func test_items_not_empty():
	var id := ItemsData.new()
	id.load()
	assert_gt(id.items.size(), 0, "items dict should not be empty")


func test_items_count():
	var id := ItemsData.new()
	id.load()
	assert_gte(id.items.size(), 200, "should have at least 200 items")


func test_items_health_potion_exists():
	var id := ItemsData.new()
	id.load()
	assert_true(id.items.has("Health Potion"), "should have Health Potion")
	var hp: Dictionary = id.items["Health Potion"]
	assert_eq(hp["type"], "heal", "Health Potion type should be 'heal'")


func test_items_have_type_or_desc():
	var id := ItemsData.new()
	id.load()
	for item_name in id.items:
		if item_name == "_meta":
			continue
		var entry: Dictionary = id.items[item_name]
		assert_true(entry.has("type") or entry.has("desc"),
			"item '%s' should have 'type' or 'desc'" % item_name)


# ---------- EnemyTypesData ----------

func test_enemies_loads():
	var ed := EnemyTypesData.new()
	assert_true(ed.load(), "EnemyTypesData.load() should succeed")


func test_enemies_not_empty():
	var ed := EnemyTypesData.new()
	ed.load()
	assert_gt(ed.enemies.size(), 0, "enemies dict should not be empty")


func test_enemies_count():
	var ed := EnemyTypesData.new()
	ed.load()
	assert_gte(ed.enemies.size(), 50, "should have at least 50 enemy types")


func test_enemies_slime_exists():
	var ed := EnemyTypesData.new()
	ed.load()
	assert_true(ed.enemies.has("Gelatinous Slime"), "should have Gelatinous Slime")


func test_enemies_slime_splits():
	var ed := EnemyTypesData.new()
	ed.load()
	var slime: Dictionary = ed.enemies["Gelatinous Slime"]
	assert_true(slime.get("splits_on_death", false), "Gelatinous Slime should split on death")


# ---------- ContainerData ----------

func test_containers_loads():
	var cd := ContainerData.new()
	assert_true(cd.load(), "ContainerData.load() should succeed")


func test_containers_not_empty():
	var cd := ContainerData.new()
	cd.load()
	assert_gt(cd.containers.size(), 0, "containers dict should not be empty")


func test_containers_count():
	var cd := ContainerData.new()
	cd.load()
	assert_gte(cd.containers.size(), 10, "should have at least 10 containers")


func test_containers_required_keys():
	var cd := ContainerData.new()
	cd.load()
	var crate: Dictionary = cd.containers["Old Crate"]
	for key in ContainerData.REQUIRED_KEYS:
		assert_true(crate.has(key), "Old Crate should have key '%s'" % key)


func test_containers_have_loot_pools():
	var cd := ContainerData.new()
	cd.load()
	for name in cd.containers:
		var entry: Dictionary = cd.containers[name]
		assert_true(entry["loot_pools"] is Dictionary,
			"container '%s' loot_pools should be a dict" % name)


# ---------- LoreData ----------

func test_lore_loads():
	var ld := LoreData.new()
	assert_true(ld.load(), "LoreData.load() should succeed")


func test_lore_not_empty():
	var ld := LoreData.new()
	ld.load()
	assert_gt(ld.lore.size(), 0, "lore dict should not be empty")


func test_lore_has_all_categories():
	var ld := LoreData.new()
	ld.load()
	for cat in LoreData.EXPECTED_CATEGORIES:
		assert_true(ld.lore.has(cat), "should have category '%s'" % cat)


func test_lore_categories_are_arrays():
	var ld := LoreData.new()
	ld.load()
	for cat in LoreData.EXPECTED_CATEGORIES:
		assert_true(ld.lore[cat] is Array,
			"category '%s' should be an array" % cat)


func test_lore_categories_not_empty():
	var ld := LoreData.new()
	ld.load()
	for cat in LoreData.EXPECTED_CATEGORIES:
		assert_gt(ld.lore[cat].size(), 0,
			"category '%s' should have at least one entry" % cat)


# ---------- WorldLoreData ----------

func test_world_lore_loads():
	var wl := WorldLoreData.new()
	assert_true(wl.load(), "WorldLoreData.load() should succeed")


func test_world_lore_not_empty():
	var wl := WorldLoreData.new()
	wl.load()
	assert_gt(wl.world_lore.size(), 0, "world_lore dict should not be empty")


func test_world_lore_required_keys():
	var wl := WorldLoreData.new()
	wl.load()
	for key in WorldLoreData.REQUIRED_KEYS:
		assert_true(wl.world_lore.has(key),
			"world_lore should have key '%s'" % key)


func test_world_lore_starting_area_has_name():
	var wl := WorldLoreData.new()
	wl.load()
	var sa: Dictionary = wl.world_lore["starting_area"]
	assert_true(sa.has("name"), "starting_area should have 'name'")
	assert_true(sa["name"].length() > 0, "starting_area name should not be empty")


func test_world_lore_flavor_text_is_dict():
	var wl := WorldLoreData.new()
	wl.load()
	assert_true(wl.world_lore["flavor_text_database"] is Dictionary,
		"flavor_text_database should be a dictionary")
