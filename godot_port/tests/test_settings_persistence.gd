extends GutTest
## Test that settings persist across save/load cycles via ConfigFile.

const CFG_PATH := "user://settings.cfg"


func before_each() -> void:
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func after_all() -> void:
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func test_default_difficulty_is_normal() -> void:
	var sm := _make_manager()
	assert_eq(sm.difficulty, "Normal", "default difficulty")
	sm.queue_free()


func test_save_and_reload_difficulty() -> void:
	var sm := _make_manager()
	sm.set_difficulty("Hard")
	sm.save_settings()
	sm.queue_free()

	var sm2 := _make_manager()
	sm2.load_settings()
	assert_eq(sm2.difficulty, "Hard", "difficulty persisted after reload")
	sm2.queue_free()


func test_save_and_reload_color_scheme() -> void:
	var sm := _make_manager()
	sm.set_color_scheme("Dark")
	sm.save_settings()
	sm.queue_free()

	var sm2 := _make_manager()
	sm2.load_settings()
	assert_eq(sm2.color_scheme, "Dark", "color scheme persisted")
	sm2.queue_free()


func test_save_and_reload_text_speed() -> void:
	var sm := _make_manager()
	sm.set_text_speed("Fast")
	sm.save_settings()
	sm.queue_free()

	var sm2 := _make_manager()
	sm2.load_settings()
	assert_eq(sm2.text_speed, "Fast", "text speed persisted")
	sm2.queue_free()


func test_save_and_reload_keybinding() -> void:
	var sm := _make_manager()
	sm.set_keybinding("move_north", KEY_UP)
	sm.save_settings()
	sm.queue_free()

	var sm2 := _make_manager()
	sm2.load_settings()
	assert_eq(sm2.keybindings["move_north"], KEY_UP, "keybinding persisted")
	sm2.queue_free()


func test_all_settings_persist_together() -> void:
	var sm := _make_manager()
	sm.set_difficulty("Nightmare")
	sm.set_color_scheme("Light")
	sm.set_text_speed("Slow")
	sm.set_music_enabled(false)
	sm.set_music_volume(0.42)
	sm.set_keybinding("move_east", KEY_RIGHT)
	sm.save_settings()
	sm.queue_free()

	var sm2 := _make_manager()
	sm2.load_settings()
	assert_eq(sm2.difficulty, "Nightmare", "difficulty")
	assert_eq(sm2.color_scheme, "Light", "color scheme")
	assert_eq(sm2.text_speed, "Slow", "text speed")
	assert_false(sm2.music_enabled, "music enabled")
	assert_eq(sm2.music_volume, 0.42, "music volume")
	assert_eq(sm2.keybindings["move_east"], KEY_RIGHT, "keybinding")
	sm2.queue_free()


func test_save_and_reload_music_settings() -> void:
	var sm := _make_manager()
	sm.set_music_enabled(false)
	sm.set_music_volume(0.25)
	sm.save_settings()
	sm.queue_free()

	var sm2 := _make_manager()
	sm2.load_settings()
	assert_false(sm2.music_enabled, "music toggle persisted")
	assert_eq(sm2.music_volume, 0.25, "music volume persisted")
	sm2.queue_free()


func _make_manager() -> Node:
	var script := load("res://game/core/settings/settings_manager.gd")
	var sm := Node.new()
	sm.set_script(script)
	add_child(sm)
	return sm
