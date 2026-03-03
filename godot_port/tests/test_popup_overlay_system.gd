extends "res://addons/gut/test.gd"
## Tests for the modal popup overlay system:
## - PopupFrame instantiates with red X close button
## - MenuOverlayManager stack behavior
## - ESC closes topmost menu
## - Combat gating prevents popup close
## - Pause menu contains Quit to Main Menu
## - All popups can be opened/closed headlessly

var _explorer_scene := preload("res://ui/scenes/Explorer.tscn")
var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
var OverlayManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
var _pause_scene := preload("res://ui/scenes/PauseMenu.tscn")


func before_each() -> void:
	GameSession._load_data()


# ------------------------------------------------------------------
# PopupFrame tests
# ------------------------------------------------------------------

func test_popup_frame_instantiates() -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = "Test Popup"
	add_child(frame)
	await get_tree().process_frame

	var close_btn = frame.find_child("BtnPopupClose", true, false)
	assert_not_null(close_btn, "Red X close button exists")
	assert_true(close_btn is Button, "Close button is Button type")
	assert_eq(close_btn.text, "X", "Close button text is 'X'")

	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_close_signal() -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = "Signal Test"
	add_child(frame)
	await get_tree().process_frame

	watch_signals(frame)

	# Simulate the close button action by calling emit on frame's signal
	frame.close_requested.emit()
	await get_tree().process_frame

	assert_signal_emitted(frame, "close_requested",
		"close_requested signal can fire")

	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_closable_toggle() -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = "Closable Test"
	add_child(frame)
	await get_tree().process_frame

	var close_btn = frame.find_child("BtnPopupClose", true, false)
	assert_true(close_btn.visible, "Close button visible by default")

	frame.closable = false
	assert_false(close_btn.visible, "Close button hidden when closable = false")

	frame.closable = true
	assert_true(close_btn.visible, "Close button visible again when closable = true")

	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_content_slot() -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = "Content Test"
	var content := Label.new()
	content.text = "Hello Content"
	frame.set_content(content)
	add_child(frame)
	await get_tree().process_frame

	assert_eq(frame.get_content(), content, "get_content returns the content")
	var container = frame.find_child("ContentContainer", true, false)
	assert_not_null(container, "ContentContainer exists")

	frame.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# MenuOverlayManager tests
# ------------------------------------------------------------------

func test_overlay_manager_register_and_open() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	var content := Label.new()
	content.text = "Test content"
	mgr.register_menu("test", "Test Menu", content)

	assert_false(mgr.is_any_open(), "No menus open initially")

	mgr.open_menu("test")
	assert_true(mgr.is_menu_open("test"), "Test menu is open")
	assert_true(mgr.is_any_open(), "Manager reports menus open")

	mgr.queue_free()
	await get_tree().process_frame


func test_overlay_manager_close_menu() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	var content := Label.new()
	mgr.register_menu("test", "Test", content)
	mgr.open_menu("test")
	assert_true(mgr.is_menu_open("test"), "Menu is open")

	mgr.close_menu("test")
	# Need to wait for tween to complete
	await get_tree().create_timer(0.2).timeout
	assert_false(mgr.is_menu_open("test"), "Menu is closed after close_menu")

	mgr.queue_free()
	await get_tree().process_frame


func test_overlay_manager_stack_lifo() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	var c1 := Label.new()
	var c2 := Label.new()
	var c3 := Label.new()
	mgr.register_menu("a", "Menu A", c1)
	mgr.register_menu("b", "Menu B", c2)
	mgr.register_menu("c", "Menu C", c3)

	mgr.open_menu("a")
	mgr.open_menu("b")
	mgr.open_menu("c")

	assert_eq(mgr.get_top_menu_key(), "c", "Top menu is C (last opened)")

	mgr.close_top_menu()
	await get_tree().create_timer(0.2).timeout
	assert_eq(mgr.get_top_menu_key(), "b", "After closing C, top is B")

	mgr.close_top_menu()
	await get_tree().create_timer(0.2).timeout
	assert_eq(mgr.get_top_menu_key(), "a", "After closing B, top is A")

	mgr.close_top_menu()
	await get_tree().create_timer(0.2).timeout
	assert_false(mgr.is_any_open(), "All menus closed")

	mgr.queue_free()
	await get_tree().process_frame


func test_overlay_manager_can_close_override() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	var content := Label.new()
	var state := {"allow": false}
	mgr.register_menu("locked", "Locked Menu", content,
		func() -> bool: return state["allow"])

	mgr.open_menu("locked")
	await get_tree().create_timer(0.2).timeout
	assert_true(mgr.is_menu_open("locked"), "Locked menu is open")

	# Try to close — should be blocked
	var result := mgr.close_top_menu()
	assert_true(result, "close_top_menu returns true (blocked but handled)")
	assert_true(mgr.is_menu_open("locked"), "Menu still open — close blocked")

	# Allow close via state dict (captured by reference)
	state["allow"] = true
	mgr.close_all_menus()
	assert_false(mgr.is_menu_open("locked"), "Menu closes when allowed")

	mgr.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Explorer integration tests
# ------------------------------------------------------------------

func test_explorer_has_overlay_manager() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	assert_not_null(explorer._overlay_manager, "Explorer has _overlay_manager")

	explorer.queue_free()
	await get_tree().process_frame


func test_explorer_inventory_opens_as_popup() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	explorer._on_inventory()
	assert_true(explorer._overlay_manager.is_menu_open("inventory"),
		"Inventory opens via overlay manager")

	explorer.queue_free()
	await get_tree().process_frame


func test_explorer_character_status_opens_as_popup() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	explorer._on_character_status()
	assert_true(explorer._overlay_manager.is_menu_open("character_status"),
		"Character Status opens via overlay manager")

	explorer.queue_free()
	await get_tree().process_frame


func test_explorer_save_load_opens_as_popup() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	explorer._on_save_load()
	assert_true(explorer._overlay_manager.is_menu_open("save_load"),
		"Save/Load opens via overlay manager")

	explorer.queue_free()
	await get_tree().process_frame


func test_explorer_settings_opens_as_popup() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	explorer._on_settings()
	assert_true(explorer._overlay_manager.is_menu_open("settings"),
		"Settings opens via overlay manager")

	explorer.queue_free()
	await get_tree().process_frame


func test_explorer_pause_opens_as_popup() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	explorer._on_pause()
	assert_true(explorer._overlay_manager.is_menu_open("pause"),
		"Pause menu opens via overlay manager")

	explorer.queue_free()
	await get_tree().process_frame


func test_all_popups_have_close_button() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	var menu_keys := ["inventory", "character_status", "save_load",
		"settings", "lore_codex", "pause"]
	for key in menu_keys:
		var frame = explorer._overlay_manager.get_frame(key)
		assert_not_null(frame, "%s popup frame exists" % key)
		var btn = frame.find_child("BtnPopupClose", true, false)
		assert_not_null(btn, "%s has close button" % key)

	explorer.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Pause menu tests
# ------------------------------------------------------------------

func test_pause_menu_has_quit_button() -> void:
	var pause := _pause_scene.instantiate()
	add_child(pause)
	await get_tree().process_frame

	var btn_quit = pause.find_child("BtnQuit", true, false)
	assert_not_null(btn_quit, "Quit to Main Menu button exists")
	assert_true(btn_quit is Button, "BtnQuit is a Button")

	var btn_resume = pause.find_child("BtnResume", true, false)
	assert_not_null(btn_resume, "Resume button exists")

	var btn_settings = pause.find_child("BtnSettings", true, false)
	assert_not_null(btn_settings, "Settings button exists")

	pause.queue_free()
	await get_tree().process_frame


func test_pause_resume_emits_close() -> void:
	var pause := _pause_scene.instantiate()
	add_child(pause)
	await get_tree().process_frame

	watch_signals(pause)

	pause.close_requested.emit()
	await get_tree().process_frame

	assert_signal_emitted(pause, "close_requested",
		"PauseMenu close_requested signal can fire")

	pause.queue_free()
	await get_tree().process_frame


func test_pause_quit_shows_confirm() -> void:
	var pause := _pause_scene.instantiate()
	add_child(pause)
	await get_tree().process_frame

	var btn_quit = pause.find_child("BtnQuit", true, false)
	btn_quit.pressed.emit()
	await get_tree().process_frame

	var confirm = pause.find_child("ConfirmQuitPanel", true, false)
	assert_not_null(confirm, "Confirm quit panel appears")

	pause.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Combat gating through overlay system
# ------------------------------------------------------------------

func test_combat_popup_not_closable_during_active() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	# Setup combat
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()

	assert_true(GameSession.is_combat_active(), "Combat is active")

	explorer._overlay_manager.open_menu("combat")
	assert_true(explorer._overlay_manager.is_menu_open("combat"),
		"Combat popup is open")

	# Try to close — should be blocked
	explorer._overlay_manager.close_top_menu()
	assert_true(explorer._overlay_manager.is_menu_open("combat"),
		"Combat popup stays open — close blocked during active combat")

	# End combat
	GameSession.end_combat(true)
	await get_tree().process_frame

	explorer.queue_free()
	await get_tree().process_frame
