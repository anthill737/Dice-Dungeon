extends GutTest

var _sfx_script := preload("res://game/services/sfx_service.gd")


func test_coin_cues_have_randomized_variant_pools() -> void:
	var service := _sfx_script.new()
	add_child(service)
	await get_tree().process_frame

	assert_true(service.has_cue("gold_pickup"), "gold_pickup cue exists")
	assert_true(service.has_cue("purchase"), "purchase cue exists")
	assert_true(service.has_cue("sell"), "sell cue exists")
	assert_eq(service.get_variant_paths("gold_pickup").size(), 7, "gold_pickup uses 7 interchangeable grounded variants")
	assert_eq(service.get_variant_paths("purchase").size(), 7, "purchase uses 7 interchangeable grounded variants")
	assert_eq(service.get_variant_paths("sell").size(), 7, "sell uses 7 interchangeable grounded variants")
	assert_eq(service.get_variant_paths("attack").size(), 3, "attack uses 3 grounded weapon variants")
	assert_eq(service.get_variant_paths("chest_open").size(), 2, "chest_open uses 2 grounded container variants")

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


func test_enemy_family_helper_maps_common_enemy_types() -> void:
	assert_eq(_sfx_script.enemy_family_for("Skeleton Archer"), "undead", "skeletons map to undead")
	assert_eq(_sfx_script.enemy_family_for("Gelatinous Slime"), "ooze", "slimes map to ooze")
	assert_eq(_sfx_script.enemy_family_for("Goblin Raider"), "humanoid", "goblins map to humanoid")
	assert_eq(_sfx_script.enemy_family_for("Giant Spider"), "insect", "spiders map to insect")
	assert_eq(_sfx_script.enemy_family_for("Dire Wolf"), "beast", "wolves map to beast")
	assert_eq(_sfx_script.enemy_family_for("Ash Elemental"), "spirit", "elementals map to spirit")


func test_item_use_helper_classifies_grounded_consumable_cues() -> void:
	assert_eq(_sfx_script.item_use_cue_for("Health Potion", "heal"), "drink_potion", "potions use drink cue")
	assert_eq(_sfx_script.item_use_cue_for("Bandages", "heal"), "heal_bandage", "bandages use bandage cue")
	assert_eq(_sfx_script.item_use_cue_for("Herb Bundle", "heal"), "heal_herb", "herbs use herb cue")
	assert_eq(_sfx_script.item_use_cue_for("Trail Rations", "heal"), "heal_food", "food uses food cue")
	assert_eq(_sfx_script.item_use_cue_for("Escape Token", "escape_token"), "use_token", "escape token uses token cue")
	assert_eq(_sfx_script.item_use_cue_for("Repair Kit", "repair"), "repair_kit", "repair items use repair cue")
	assert_eq(_sfx_script.item_use_cue_for("Strength Elixir", "buff"), "buff_tonic", "buff elixirs use tonic cue")


func test_equipment_action_helper_maps_slots() -> void:
	assert_eq(_sfx_script.equipment_action_cue_for("weapon", "equip"), "equip_weapon", "weapon equip uses equip_weapon cue")
	assert_eq(_sfx_script.equipment_action_cue_for("armor", "equip"), "equip_armor", "armor equip uses equip_armor cue")
	assert_eq(_sfx_script.equipment_action_cue_for("accessory", "equip"), "equip_accessory", "accessory equip uses equip_accessory cue")
	assert_eq(_sfx_script.equipment_action_cue_for("weapon", "unequip"), "unequip_item", "unequip uses shared unequip cue")
