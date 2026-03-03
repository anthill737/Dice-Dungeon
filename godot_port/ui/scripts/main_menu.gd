extends Control
## Main Menu — entry point for the game. Built entirely in code.
## Buttons: Start Adventure, Load Game, Settings, Quit.

var _btn_start: Button
var _btn_load: Button
var _btn_settings: Button
var _btn_quit: Button
var _settings_panel: Control
var _settings_scene := preload("res://ui/scenes/SettingsPanel.tscn")


func _ready() -> void:
	_build_ui()
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

	_btn_load = DungeonTheme.make_styled_btn("📂  Load Game", DungeonTheme.BTN_SECONDARY, 260)
	_btn_load.name = "BtnLoad"
	_btn_load.custom_minimum_size.y = 44
	center.add_child(_btn_load)

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

	_settings_panel = _settings_scene.instantiate()
	_settings_panel.visible = false
	_settings_panel.modulate.a = 0.0
	add_child(_settings_panel)
	if _settings_panel.has_signal("close_requested"):
		_settings_panel.close_requested.connect(_close_settings)


func _connect_signals() -> void:
	_btn_start.pressed.connect(_on_start)
	_btn_load.pressed.connect(_on_load)
	_btn_settings.pressed.connect(_on_settings)
	_btn_quit.pressed.connect(_on_quit)


func _on_start() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file("res://ui/scenes/Explorer.tscn")


func _on_load() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file("res://ui/scenes/Explorer.tscn")
	GameSession.log_message.emit("Load panel opened — select a slot.")


func _on_settings() -> void:
	_settings_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_settings_panel, "modulate:a", 1.0, DungeonTheme.FADE_DURATION)
	if _settings_panel.has_method("refresh"):
		_settings_panel.refresh()


func _close_settings() -> void:
	var tw := create_tween()
	tw.tween_property(_settings_panel, "modulate:a", 0.0, DungeonTheme.FADE_DURATION)
	tw.tween_callback(func(): _settings_panel.visible = false)


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") and _settings_panel.visible:
			_close_settings()
			get_viewport().set_input_as_handled()
