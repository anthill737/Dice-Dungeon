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
	assert_true(service.has_cue("music_main_menu"), "main menu cue has at least one track")
	assert_true(service.has_cue("music_adventure_playlist"), "adventure playlist cue has tracks")
	assert_eq(service.get_context_cue("boss_combat"), "music_adventure_playlist", "boss combat now uses the shared adventure playlist")
	assert_eq(
		service.get_variant_paths("music_main_menu")[0],
		"res://assets/audio/music/Dice Dungeon.wav",
		"main menu cue uses Dice Dungeon.wav"
	)
	assert_eq(service.get_context_cue("exploration"), "music_adventure_playlist", "exploration uses the shared adventure playlist")
	assert_true(service.is_playlist_cue("music_adventure_playlist"), "adventure cue is configured as a playlist")
	assert_eq(service.get_variant_paths("music_adventure_playlist").size(), 7, "playlist includes all seven available tracks")

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


func test_playlist_context_starts_playback_and_selects_a_track() -> void:
	var service = _music_script.new()
	add_child(service)
	await get_tree().process_frame

	service.set_rng_seed(7)
	service.set_context("exploration", {"immediate": true})
	await get_tree().process_frame

	assert_eq(service.get_active_cue(), "music_adventure_playlist", "exploration activates the adventure playlist")
	assert_true(service.is_playing(), "playlist begins playback")
	assert_ne(service.get_active_track_path(), "", "playlist exposes the active track path")

	service.queue_free()
	await get_tree().process_frame


func test_main_menu_context_starts_with_dice_dungeon_theme() -> void:
	var service = _music_script.new()
	add_child(service)
	await get_tree().process_frame

	service.set_context("main_menu", {"immediate": true})
	await get_tree().process_frame

	assert_eq(service.get_active_context(), "main_menu", "main menu context stays active")
	assert_eq(service.get_active_cue(), "music_main_menu", "main menu uses its dedicated cue")
	assert_true(service.is_playing(), "main menu music begins playing immediately")
	assert_eq(
		service.get_active_track_path(),
		"res://assets/audio/music/Dice Dungeon.wav",
		"main menu always starts with Dice Dungeon.wav"
	)

	service.queue_free()
	await get_tree().process_frame


func test_overlay_context_keeps_active_playlist_track_when_overlay_has_no_music() -> void:
	var service = _music_script.new()
	add_child(service)
	await get_tree().process_frame

	var room := {
		"id": 7,
		"name": "Music Test Room",
		"difficulty": "Easy",
	}

	service.set_rng_seed(7)
	service.set_room_context(room, "exploration", "exploration", {"immediate": true})
	await get_tree().process_frame
	var adventure_track: String = service.get_active_track_path()

	service.set_overlay_context("pause", room, "exploration", "exploration", {"immediate": true})
	await get_tree().process_frame
	assert_eq(service.get_active_cue(), "music_adventure_playlist", "pause overlay reuses the adventure playlist")
	assert_eq(service.get_active_track_path(), adventure_track, "pause overlay does not reshuffle the active track")

	service.set_overlay_context("settings", room, "exploration", "exploration", {"immediate": true})
	await get_tree().process_frame
	assert_eq(service.get_active_cue(), "music_adventure_playlist", "settings overlay keeps the adventure playlist")
	assert_eq(service.get_active_track_path(), adventure_track, "settings overlay does not restart or reshuffle")

	service.set_overlay_context("save_load", room, "exploration", "exploration", {"immediate": true})
	await get_tree().process_frame
	assert_eq(service.get_active_cue(), "music_adventure_playlist", "save/load overlay keeps the adventure playlist")
	assert_eq(service.get_active_track_path(), adventure_track, "save/load overlay does not restart or reshuffle")

	service.queue_free()
	await get_tree().process_frame
