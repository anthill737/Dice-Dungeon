extends "res://addons/gut/test.gd"
## Consolidated tests for the popup overlay system:
## - MenuOverlayManager stack behavior (LIFO, open, close)
## - ESC / close-top-menu
## - can_close gating (combat lockout)
## - PopupFrame instantiation, close button, closable toggle
## - Explorer + MainMenu integration (menus open via manager)
## - Pause menu buttons and signals

var _explorer_scene := preload("res://ui/scenes/Explorer.tscn")
var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
var OverlayManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
var _pause_scene := preload("res://ui/scenes/PauseMenu.tscn")


func before_each() -> void:
	GameSession._load_data()


# ------------------------------------------------------------------
# PopupFrame basics
# ------------------------------------------------------------------

func test_popup_frame_has_close_button() -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var btn = frame.find_child("BtnPopupClose", true, false)
	assert_not_null(btn, "Close button exists")
	assert_true(btn is Button, "Close is a Button")

	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_closable_toggle() -> void:
	var frame = PopupFrameScript.new()
	add_child(frame)
	await get_tree().process_frame

	var btn = frame.find_child("BtnPopupClose", true, false)
	assert_true(btn.visible, "Close visible by default")
	frame.closable = false
	assert_false(btn.visible, "Close hidden when closable=false")
	frame.closable = true
	assert_true(btn.visible, "Close visible again")

	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_content_slot() -> void:
	var frame = PopupFrameScript.new()
	var lbl := Label.new()
	lbl.text = "content"
	frame.set_content(lbl)
	add_child(frame)
	await get_tree().process_frame

	assert_eq(frame.get_content(), lbl, "get_content returns set content")
	assert_not_null(frame.find_child("ContentContainer", true, false),
		"ContentContainer exists")

	frame.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# MenuOverlayManager stack
# ------------------------------------------------------------------

func test_manager_open_close() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	mgr.register_menu("t", "T", Label.new(), "inventory")
	assert_false(mgr.is_any_open(), "Nothing open initially")

	mgr.open_menu("t")
	assert_true(mgr.is_menu_open("t"), "Menu opens")

	mgr.close_menu("t")
	await get_tree().create_timer(0.2).timeout
	assert_false(mgr.is_menu_open("t"), "Menu closes after tween")

	mgr.queue_free()
	await get_tree().process_frame


func test_manager_lifo_stack() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	mgr.register_menu("a", "A", Label.new(), "pause")
	mgr.register_menu("b", "B", Label.new(), "inventory")
	mgr.register_menu("c", "C", Label.new(), "status")

	mgr.open_menu("a")
	mgr.open_menu("b")
	mgr.open_menu("c")
	assert_eq(mgr.get_top_menu_key(), "c", "Top is last opened")

	mgr.close_top_menu()
	await get_tree().create_timer(0.2).timeout
	assert_eq(mgr.get_top_menu_key(), "b", "Top after closing c")

	mgr.close_top_menu()
	await get_tree().create_timer(0.2).timeout
	assert_eq(mgr.get_top_menu_key(), "a", "Top after closing b")

	mgr.close_top_menu()
	await get_tree().create_timer(0.2).timeout
	assert_false(mgr.is_any_open(), "All closed")

	mgr.queue_free()
	await get_tree().process_frame


func test_manager_can_close_blocks() -> void:
	var mgr = OverlayManagerScript.new()
	add_child(mgr)
	await get_tree().process_frame

	var state := {"allow": false}
	mgr.register_menu("locked", "L", Label.new(), "combat",
		func() -> bool: return state["allow"])
	mgr.open_menu("locked")
	await get_tree().create_timer(0.2).timeout

	mgr.close_top_menu()
	assert_true(mgr.is_menu_open("locked"), "Close blocked")

	state["allow"] = true
	mgr.close_all_menus()
	assert_false(mgr.is_menu_open("locked"), "Closes when allowed")

	mgr.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Explorer integration
# ------------------------------------------------------------------

func test_explorer_has_overlay_manager() -> void:
	GameSession.start_new_game()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame
	assert_not_null(ex._overlay_manager, "Explorer has _overlay_manager")
	ex.queue_free()
	await get_tree().process_frame


func test_explorer_menus_open() -> void:
	GameSession.start_new_game()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame

	for key in ["inventory", "character_status", "save_load", "settings", "pause"]:
		ex._overlay_manager.open_menu(key)
		assert_true(ex._overlay_manager.is_menu_open(key), "%s opens" % key)
		ex._overlay_manager.close_all_menus()

	ex.queue_free()
	await get_tree().process_frame


func test_all_frames_have_close_button() -> void:
	GameSession.start_new_game()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame

	for key in ["inventory", "character_status", "save_load",
			"settings", "lore_codex", "pause"]:
		var frame = ex._overlay_manager.get_frame(key)
		assert_not_null(frame, "%s frame exists" % key)
		if frame != null:
			var btn = frame.find_child("BtnPopupClose", true, false)
			assert_not_null(btn, "%s has close button" % key)

	ex.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Combat gating through overlay
# ------------------------------------------------------------------

func test_combat_popup_blocked_during_active() -> void:
	GameSession.start_new_game()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()

	ex._overlay_manager.open_menu("combat")
	assert_true(ex._overlay_manager.is_menu_open("combat"), "Combat open")

	ex._overlay_manager.close_top_menu()
	assert_true(ex._overlay_manager.is_menu_open("combat"),
		"Combat stays open — close blocked")

	GameSession.end_combat(true)
	await get_tree().process_frame
	ex.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Pause menu
# ------------------------------------------------------------------

func test_pause_menu_buttons_exist() -> void:
	var pause := _pause_scene.instantiate()
	add_child(pause)
	await get_tree().process_frame

	assert_not_null(pause.find_child("BtnResume", true, false), "Resume exists")
	assert_not_null(pause.find_child("BtnSaveLoad", true, false), "SaveLoad exists")
	assert_not_null(pause.find_child("BtnSettings", true, false), "Settings exists")
	assert_not_null(pause.find_child("BtnQuit", true, false), "Quit exists")

	pause.queue_free()
	await get_tree().process_frame


func test_pause_quit_shows_confirm() -> void:
	var pause := _pause_scene.instantiate()
	add_child(pause)
	await get_tree().process_frame

	var btn_quit = pause.find_child("BtnQuit", true, false)
	pause._on_quit_pressed()
	await get_tree().process_frame

	var confirm = pause.find_child("ConfirmQuitPanel", true, false)
	assert_not_null(confirm, "Confirm panel appears")

	pause.queue_free()
	await get_tree().process_frame
