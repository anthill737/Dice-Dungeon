extends Control
## Main Menu — entry point for the game. Built entirely in code.
## Buttons: Start Adventure, Save/Load, Settings, Quit.
## Settings and Save/Load open as proper modal popups using the same
## MenuOverlayManager + PopupFrame system as the Explorer scene.

const _SfxService := preload("res://game/services/sfx_service.gd")

var _btn_start: Button
var _btn_save_load: Button
var _btn_settings: Button
var _btn_quit: Button

var _overlay_manager  # MenuOverlayManager
var _settings_panel: Control
var _save_load_panel: Control
var _start_adventure_panel: Control
var _context: GameContext

var _settings_scene := preload("res://ui/scenes/SettingsPanel.tscn")
var _save_load_scene := preload("res://ui/scenes/SaveLoadPanel.tscn")
var _start_adventure_scene := preload("res://ui/scenes/StartAdventurePanel.tscn")


func _ready() -> void:
	_SfxService.ensure_for(self)
	_context = GameContext.new()
	_build_ui()
	_setup_overlay_manager()
	_context.set_menus(_overlay_manager)
	_connect_signals()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = DungeonTheme.BG_PRIMARY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -180
	center.offset_top = -200
	center.offset_right = 180
	center.offset_bottom = 200
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	var title := Label.new()
	title.name = "Title"
	title.text = "⚔ DICE DUNGEON ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	center.add_child(title)

	var sep := DungeonTheme.make_separator(DungeonTheme.BORDER_GOLD)
	center.add_child(sep)

	var subtitle := Label.new()
	subtitle.text = "Explorer Mode"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	subtitle.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer)

	_btn_start = DungeonTheme.make_styled_btn("⚔  Start Adventure", DungeonTheme.BTN_PRIMARY, 260)
	_btn_start.name = "BtnStart"
	_btn_start.custom_minimum_size.y = 44
	center.add_child(_btn_start)

	_btn_save_load = DungeonTheme.make_styled_btn("💾  Save / Load", DungeonTheme.BTN_SECONDARY, 260)
	_btn_save_load.name = "BtnLoad"
	_btn_save_load.custom_minimum_size.y = 44
	center.add_child(_btn_save_load)

	_btn_settings = DungeonTheme.make_styled_btn("⚙  Settings", DungeonTheme.TEXT_SECONDARY, 260)
	_btn_settings.name = "BtnSettings"
	_btn_settings.custom_minimum_size.y = 44
	center.add_child(_btn_settings)

	_btn_quit = DungeonTheme.make_styled_btn("✕  Quit", DungeonTheme.TEXT_RED, 260)
	_btn_quit.name = "BtnQuit"
	_btn_quit.custom_minimum_size.y = 44
	center.add_child(_btn_quit)

	var footer := Label.new()
	footer.text = "v0.13 [%s]  —  A dice-driven dungeon crawler" % BuildInfo.version_label()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	footer.add_theme_color_override("font_color", DungeonTheme.TEXT_DIM)
	center.add_child(footer)


func _setup_overlay_manager() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	_overlay_manager = ManagerScript.new()
	_overlay_manager.name = "MenuOverlayManager"
	add_child(_overlay_manager)

	_settings_panel = _settings_scene.instantiate()
	_save_load_panel = _save_load_scene.instantiate()
	_save_load_panel.panel_context = _save_load_panel.PanelContext.MAIN_MENU
	_start_adventure_panel = _start_adventure_scene.instantiate()

	_overlay_manager.register_menu("settings", "⚙ SETTINGS", _settings_panel, "settings")
	_overlay_manager.register_menu("save_load", "💾 SAVE / LOAD", _save_load_panel, "save_load")
	_overlay_manager.register_menu("start_adventure", "⚔ START ADVENTURE", _start_adventure_panel, "start_adventure")

	if _settings_panel.has_signal("close_requested"):
		_settings_panel.close_requested.connect(func(): _overlay_manager.close_menu("settings"))
	if _save_load_panel.has_signal("close_requested"):
		_save_load_panel.close_requested.connect(func(): _overlay_manager.close_menu("save_load"))
	if _save_load_panel.has_signal("load_into_game_requested"):
		_save_load_panel.load_into_game_requested.connect(_on_load_save)
	if _start_adventure_panel.has_signal("close_requested"):
		_start_adventure_panel.close_requested.connect(func(): _overlay_manager.close_menu("start_adventure"))
	if _start_adventure_panel.has_signal("start_run_requested"):
		_start_adventure_panel.start_run_requested.connect(_on_start_run)


func _connect_signals() -> void:
	_btn_start.pressed.connect(_on_start)
	_btn_save_load.pressed.connect(_on_save_load)
	_btn_settings.pressed.connect(_on_settings)
	_btn_quit.pressed.connect(_on_quit)


func _on_start() -> void:
	_overlay_manager.open_menu("start_adventure")


func _on_start_run(options: Dictionary) -> void:
	_overlay_manager.close_all_menus()
	GameSession.pending_run_options = options
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file("res://ui/scenes/IntroCinematic.tscn")


func _on_save_load() -> void:
	_overlay_manager.open_menu("save_load")


func _on_settings() -> void:
	_overlay_manager.open_menu("settings")


func _on_load_save(slot_id: int) -> void:
	if _context.session == null:
		return
	var ok := _context.session.start_run_from_save(slot_id)
	if ok:
		_overlay_manager.close_all_menus()
		var tree := get_tree()
		if tree != null:
			tree.change_scene_to_file("res://ui/scenes/Explorer.tscn")


func _on_quit() -> void:
	var tree := get_tree()
	if tree != null:
		tree.quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu"):
			if _overlay_manager.is_any_open():
				_overlay_manager.close_top_menu()
				get_viewport().set_input_as_handled()
