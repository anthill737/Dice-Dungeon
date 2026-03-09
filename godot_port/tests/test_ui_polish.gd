extends GutTest
## Tests for UI polish changes:
## - Minimap follow behavior (Python parity)
## - PopupFrame border consistency
## - Top-bar icon button standardization

var _minimap_scene := preload("res://ui/scenes/MinimapPanel.tscn")


func before_each() -> void:
	GameSession._load_data()


# ==================================================================
# PART 1 — Minimap follow behavior
# ==================================================================

func test_minimap_follow_active_by_default() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_true(panel.model_follow_active, "follow should be active by default")
	panel.queue_free()
	await get_tree().process_frame


func test_minimap_center_target_tracks_player_on_move() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_eq(panel.model_center_target, Vector2i.ZERO,
		"center target starts at origin")

	var moved := false
	for dir in ["N", "E", "S", "W"]:
		var result := GameSession.move_direction(dir)
		if result != null:
			if GameSession.combat_pending:
				var r := GameSession.get_current_room()
				if r != null:
					r.combat_escaped = true
				GameSession.combat_pending = false
				GameSession.state_changed.emit()
			moved = true
			break

	if moved:
		await get_tree().process_frame
		assert_eq(panel.model_center_target, panel.model_player_room,
			"center target matches player room after move")
	else:
		pending("All directions blocked")

	panel.queue_free()
	await get_tree().process_frame


func test_minimap_user_pan_starts_zero() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_eq(panel._user_pan, Vector2.ZERO,
		"user pan starts at zero (centered on player)")
	panel.queue_free()
	await get_tree().process_frame


func test_minimap_center_button_resets_pan() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	panel._user_pan = Vector2(3.0, -2.0)
	panel._center_on_player()

	assert_eq(panel._user_pan, Vector2.ZERO,
		"center button resets user pan to zero")
	panel.queue_free()
	await get_tree().process_frame


func test_minimap_floor_change_resets_pan() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	panel._user_pan = Vector2(5.0, 5.0)
	panel._last_floor_index = 0
	var fs := GameSession.get_floor_state()
	if fs != null:
		fs.floor_index = 2
	GameSession.state_changed.emit()
	await get_tree().process_frame

	assert_eq(panel._user_pan, Vector2.ZERO,
		"floor change resets user pan")
	panel.queue_free()
	await get_tree().process_frame


func test_minimap_stride_positive() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var stride: float = panel._stride()
	assert_gt(stride, 0.0, "stride must be positive")
	panel.queue_free()
	await get_tree().process_frame


# ==================================================================
# PART 2 — PopupFrame border tests
# ==================================================================

func test_popup_frame_instantiates() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test Popup"
	add_child(frame)
	await get_tree().process_frame

	assert_not_null(frame, "PopupFrame instantiates")
	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_has_title_bar() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var title_bar := frame.find_child("TitleBar", true, false)
	assert_not_null(title_bar, "TitleBar node exists in PopupFrame")
	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_has_panel_root() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var panel_root := frame.find_child("PanelRoot", true, false)
	assert_not_null(panel_root, "PanelRoot node exists in PopupFrame")
	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_has_separator() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var separator := frame.find_child("TitleSeparator", true, false)
	assert_not_null(separator, "TitleSeparator exists between title bar and content")
	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_has_content_container() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var cc := frame.find_child("ContentContainer", true, false)
	assert_not_null(cc, "ContentContainer exists for content padding")
	assert_true(cc is MarginContainer, "ContentContainer is a MarginContainer")
	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_has_dim_background() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var dim := frame.find_child("DimBackground", true, false)
	assert_not_null(dim, "DimBackground exists")
	frame.queue_free()
	await get_tree().process_frame


func test_popup_frame_close_button_exists() -> void:
	var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	var close_btn := frame.find_child("BtnPopupClose", true, false)
	assert_not_null(close_btn, "Close button exists")
	assert_true(close_btn is Button, "Close button is a Button")
	frame.queue_free()
	await get_tree().process_frame


# ==================================================================
# PART 3 — Top-bar icon button standardization
# ==================================================================

func test_icon_btn_factory_creates_button() -> void:
	var btn := DungeonTheme.make_icon_btn("⚙", "Test")
	assert_not_null(btn, "make_icon_btn creates a button")
	assert_eq(btn.text, "⚙", "icon text matches")
	assert_eq(btn.tooltip_text, "Test", "tooltip matches")


func test_icon_btn_has_consistent_size() -> void:
	var btn := DungeonTheme.make_icon_btn("♚", "Char")
	assert_eq(btn.custom_minimum_size, DungeonTheme.ICON_BTN_SIZE,
		"icon button uses standard size")


func test_icon_btn_has_all_states() -> void:
	var btn := DungeonTheme.make_icon_btn("☰", "Menu")
	assert_not_null(btn.get_theme_stylebox("normal"),
		"normal stylebox exists")
	assert_not_null(btn.get_theme_stylebox("hover"),
		"hover stylebox exists")
	assert_not_null(btn.get_theme_stylebox("pressed"),
		"pressed stylebox exists")
	assert_not_null(btn.get_theme_stylebox("disabled"),
		"disabled stylebox exists")


func test_explorer_icon_buttons_exist() -> void:
	GameSession.start_new_game()
	var explorer := preload("res://ui/scenes/Explorer.tscn").instantiate()
	add_child(explorer)
	await get_tree().process_frame

	assert_not_null(explorer._btn_character, "Character button exists")
	assert_not_null(explorer._btn_pause, "Menu/Pause button exists")

	assert_eq(explorer._btn_character.text, DungeonTheme.ICON_CHARACTER,
		"Character button uses standard glyph")
	assert_eq(explorer._btn_pause.text, DungeonTheme.ICON_MENU,
		"Menu button uses standard glyph")

	explorer.queue_free()
	await get_tree().process_frame


func test_explorer_icon_buttons_have_signals() -> void:
	GameSession.start_new_game()
	var explorer := preload("res://ui/scenes/Explorer.tscn").instantiate()
	add_child(explorer)
	await get_tree().process_frame

	assert_gt(explorer._btn_character.pressed.get_connections().size(), 0,
		"Character button has pressed signal connected")
	assert_gt(explorer._btn_pause.pressed.get_connections().size(), 0,
		"Menu button has pressed signal connected")

	explorer.queue_free()
	await get_tree().process_frame


func test_icon_glyphs_are_distinct() -> void:
	assert_ne(DungeonTheme.ICON_CHARACTER, DungeonTheme.ICON_SETTINGS,
		"Character and Settings use different glyphs")
	assert_ne(DungeonTheme.ICON_CHARACTER, DungeonTheme.ICON_MENU,
		"Character and Menu use different glyphs")
	assert_ne(DungeonTheme.ICON_MENU, DungeonTheme.ICON_SETTINGS,
		"Menu and Settings use different glyphs")
