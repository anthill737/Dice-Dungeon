extends GutTest

var _sfx_script := preload("res://game/services/sfx_service.gd")


func test_coin_cues_have_randomized_variant_pools() -> void:
	var service := _sfx_script.new()
	add_child(service)
	await get_tree().process_frame

	assert_true(service.has_cue("gold_pickup"), "gold_pickup cue exists")
	assert_true(service.has_cue("purchase"), "purchase cue exists")
	assert_true(service.has_cue("sell"), "sell cue exists")
	assert_eq(service.get_variant_paths("gold_pickup").size(), 3, "gold_pickup uses 3 interchangeable variants")
	assert_eq(service.get_variant_paths("purchase").size(), 3, "purchase uses 3 interchangeable variants")
	assert_eq(service.get_variant_paths("sell").size(), 3, "sell uses 3 interchangeable variants")

	service.queue_free()
	await get_tree().process_frame


func test_pick_variant_path_avoids_immediate_repeat_when_multiple_variants_exist() -> void:
	var service := _sfx_script.new()
	add_child(service)
	await get_tree().process_frame

	service.set_rng_seed(12345)
	var first := service.pick_variant_path("gold_pickup")
	var second := service.pick_variant_path("gold_pickup")

	assert_ne(first, second, "gold cue should not repeat the same variant back-to-back")

	service.queue_free()
	await get_tree().process_frame


func test_container_cue_mapping_prefers_specific_open_sounds() -> void:
	assert_eq(_sfx_script.container_cue_for("Wooden Barrel"), "barrel_open", "barrels use barrel_open")
	assert_eq(_sfx_script.container_cue_for("Iron Lockbox"), "lockbox_open", "lockboxes use lockbox_open")
	assert_eq(_sfx_script.container_cue_for("Dusty Chest"), "chest_open", "other containers default to chest_open")
