extends GutTest
## Tests for GameContext — service registry instantiation.


func test_content_manager_not_null():
	var ctx := GameContext.new()
	assert_not_null(ctx.content, "content manager should be created")


func test_save_load_not_null():
	var ctx := GameContext.new()
	assert_not_null(ctx.save_load, "save_load service should be created")


func test_log_not_null():
	var ctx := GameContext.new()
	assert_not_null(ctx.log, "adventure log service should be created")


func test_content_loaded():
	var ctx := GameContext.new()
	assert_true(ctx.content.is_loaded(), "content should be loaded after context init")


func test_content_rooms_available():
	var ctx := GameContext.new()
	assert_gt(ctx.content.get_room_templates().size(), 0,
		"room templates should be available via context")


func test_content_items_available():
	var ctx := GameContext.new()
	assert_gt(ctx.content.get_items_db().size(), 0,
		"items DB should be available via context")


func test_content_enemies_available():
	var ctx := GameContext.new()
	assert_gt(ctx.content.get_enemy_types_db().size(), 0,
		"enemy types DB should be available via context")


func test_set_menus():
	var ctx := GameContext.new()
	var fake_menus := RefCounted.new()
	ctx.set_menus(fake_menus)
	assert_eq(ctx.menus, fake_menus, "menus should be set")


func test_log_service_works():
	var ctx := GameContext.new()
	ctx.log.append("test entry")
	assert_eq(ctx.log.size(), 1)
	assert_eq(ctx.log.get_entries()[0], "test entry")
