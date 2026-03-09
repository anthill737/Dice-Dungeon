extends GutTest

var _music_script := preload("res://game/services/music_service.gd")


func test_manifest_exposes_core_music_contexts() -> void:
	var service = _music_script.new()
	add_child(service)
	await get_tree().process_frame

	assert_true(service.has_context("main_menu"), "main menu context is registered")
	assert_true(service.has_context("exploration"), "exploration context is registered")
	assert_true(service.has_context("combat"), "combat context is registered")
	assert_true(service.has_context("shop"), "shop context is registered")
	assert_true(service.has_context("game_over"), "game over context is registered")
	assert_eq(service.get_context_cue("boss_combat"), "music_boss_combat", "boss combat resolves to the boss cue")

	service.queue_free()
	await get_tree().process_frame


func test_room_music_candidates_prioritize_explicit_overrides_before_generic_room_keys() -> void:
	var room := RoomState.new({
		"id": 119,
		"name": "Music Chamber",
		"difficulty": "Easy",
		"tags": ["lore", "rest"],
		"music": {
			"combat": "custom_combat_track",
			"default": "custom_default_track",
		},
	}, 0, 0)

	var candidates: PackedStringArray = _music_script.room_music_candidates_for(room, "combat")

	assert_eq(candidates[0], "custom_combat_track", "explicit combat override wins")
	assert_eq(candidates[1], "custom_default_track", "default explicit override follows")
	assert_eq(candidates[2], "room_119_combat", "room id combat cue comes next")
	assert_true(candidates.has("room_music_chamber_combat"), "room name slug cue is included")
	assert_true(candidates.has("tag_lore_combat"), "tag-based cue is included")
	assert_true(candidates.has("difficulty_easy_combat"), "difficulty-based cue is included")


func test_room_context_key_prefers_boss_and_difficulty_specific_music_buckets() -> void:
	var normal_room := RoomState.new({"name": "Whispering Antechamber", "difficulty": "Medium"}, 0, 0)
	assert_eq(_music_script.resolve_room_context_key(normal_room, "exploration"), "exploration_medium", "difficulty rooms map to exploration buckets")
	assert_eq(_music_script.resolve_room_context_key(normal_room, "combat"), "combat", "normal combat maps to combat")

	var elite_room := RoomState.new({"name": "Thunder Cage", "difficulty": "Elite"}, 0, 0)
	elite_room.is_mini_boss_room = true
	assert_eq(_music_script.resolve_room_context_key(elite_room, "exploration"), "exploration_elite", "elite room maps to elite exploration")
	assert_eq(_music_script.resolve_room_context_key(elite_room, "combat"), "elite_combat", "elite combat maps to elite combat")

	var boss_room := RoomState.new({"name": "Dragon's Casting", "difficulty": "Boss"}, 0, 0)
	boss_room.is_boss_room = true
	assert_eq(_music_script.resolve_room_context_key(boss_room, "exploration"), "exploration_boss", "boss room maps to boss exploration")
	assert_eq(_music_script.resolve_room_context_key(boss_room, "combat"), "boss_combat", "boss combat maps to boss combat")
