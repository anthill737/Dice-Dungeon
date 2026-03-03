extends GutTest
## Tests for ContentManager — centralised data loading.


func test_load_all_succeeds():
	var cm := ContentManager.new()
	assert_true(cm.load_all(), "load_all() should return true")


func test_is_loaded_after_load():
	var cm := ContentManager.new()
	assert_false(cm.is_loaded(), "should not be loaded initially")
	cm.load_all()
	assert_true(cm.is_loaded(), "should be loaded after load_all()")


# ----- Rooms -----

func test_room_templates_not_empty():
	var cm := ContentManager.new()
	cm.load_all()
	assert_gt(cm.get_room_templates().size(), 0, "room templates should not be empty")


func test_get_room_valid_index():
	var cm := ContentManager.new()
	cm.load_all()
	var room := cm.get_room(0)
	assert_true(room.has("name"), "first room should have 'name' key")


func test_get_room_invalid_index():
	var cm := ContentManager.new()
	cm.load_all()
	var room := cm.get_room(-1)
	assert_true(room.is_empty(), "invalid index returns empty dict")


# ----- Items -----

func test_items_db_not_empty():
	var cm := ContentManager.new()
	cm.load_all()
	assert_gt(cm.get_items_db().size(), 0, "items DB should not be empty")


func test_get_item_def_known():
	var cm := ContentManager.new()
	cm.load_all()
	var hp := cm.get_item_def("Health Potion")
	assert_eq(hp.get("type", ""), "heal", "Health Potion type should be 'heal'")


func test_get_item_def_unknown():
	var cm := ContentManager.new()
	cm.load_all()
	var missing := cm.get_item_def("Nonexistent Widget 9999")
	assert_true(missing.is_empty(), "unknown item returns empty dict")


# ----- Enemies -----

func test_enemy_types_db_not_empty():
	var cm := ContentManager.new()
	cm.load_all()
	assert_gt(cm.get_enemy_types_db().size(), 0, "enemy types DB should not be empty")


func test_get_enemy_def_known():
	var cm := ContentManager.new()
	cm.load_all()
	var slime := cm.get_enemy_def("Gelatinous Slime")
	assert_true(slime.get("splits_on_death", false), "Gelatinous Slime should split on death")


func test_get_enemy_def_unknown():
	var cm := ContentManager.new()
	cm.load_all()
	var missing := cm.get_enemy_def("Nonexistent Monster 9999")
	assert_true(missing.is_empty(), "unknown enemy returns empty dict")


# ----- Lore -----

func test_lore_db_not_empty():
	var cm := ContentManager.new()
	cm.load_all()
	assert_gt(cm.get_lore_db().size(), 0, "lore DB should not be empty")


func test_get_lore_entry_known():
	var cm := ContentManager.new()
	cm.load_all()
	var pages := cm.get_lore_entry("guards_journal_pages")
	assert_gt(pages.size(), 0, "guards_journal_pages should have entries")


func test_get_lore_entry_unknown():
	var cm := ContentManager.new()
	cm.load_all()
	var missing := cm.get_lore_entry("totally_fake_category")
	assert_true(missing.is_empty(), "unknown category returns empty array")


# ----- World Lore -----

func test_world_lore_not_empty():
	var cm := ContentManager.new()
	cm.load_all()
	assert_gt(cm.get_world_lore().size(), 0, "world lore should not be empty")


# ----- Containers -----

func test_container_db_not_empty():
	var cm := ContentManager.new()
	cm.load_all()
	assert_gt(cm.get_container_db().size(), 0, "container DB should not be empty")


func test_get_container_def_known():
	var cm := ContentManager.new()
	cm.load_all()
	var crate := cm.get_container_def("Old Crate")
	assert_true(crate.has("description"), "Old Crate should have 'description'")


func test_get_container_def_unknown():
	var cm := ContentManager.new()
	cm.load_all()
	var missing := cm.get_container_def("Nonexistent Container 9999")
	assert_true(missing.is_empty(), "unknown container returns empty dict")
