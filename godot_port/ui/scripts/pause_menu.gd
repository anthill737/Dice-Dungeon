extends PanelContainer
## Pause Menu — Resume, Settings, Quit to Main Menu.
## Hosted inside a PopupFrame via MenuOverlayManager.

signal close_requested()
signal open_settings_requested()
signal quit_to_menu_requested()

var _btn_resume: Button
var _btn_settings: Button
var _btn_quit: Button
var _confirm_panel: PanelContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := DungeonTheme.make_panel_bg(
		Color(0.06, 0.05, 0.08, 0.97), DungeonTheme.TEXT_GOLD)
	bg.set_border_width_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(root)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer_top)

	var title := DungeonTheme.make_header(
		"☰ PAUSED", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_HEADING)
	root.add_child(title)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.BORDER_GOLD))

	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 8)
	btn_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(btn_container)

	_btn_resume = DungeonTheme.make_styled_btn("Resume", DungeonTheme.TEXT_GREEN, 200)
	_btn_resume.name = "BtnResume"
	_btn_resume.pressed.connect(func(): close_requested.emit())
	btn_container.add_child(_btn_resume)

	_btn_settings = DungeonTheme.make_styled_btn("Settings", DungeonTheme.TEXT_CYAN, 200)
	_btn_settings.name = "BtnSettings"
	_btn_settings.pressed.connect(func(): open_settings_requested.emit())
	btn_container.add_child(_btn_settings)

	_btn_quit = DungeonTheme.make_styled_btn("Quit to Main Menu", DungeonTheme.TEXT_RED, 200)
	_btn_quit.name = "BtnQuit"
	_btn_quit.pressed.connect(_on_quit_pressed)
	btn_container.add_child(_btn_quit)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer_bottom)


func _on_quit_pressed() -> void:
	_show_confirm()


func _show_confirm() -> void:
	if _confirm_panel != null:
		_confirm_panel.queue_free()

	_confirm_panel = PanelContainer.new()
	_confirm_panel.name = "ConfirmQuitPanel"
	var style := DungeonTheme.make_panel_bg(
		Color(0.05, 0.04, 0.06, 0.98), DungeonTheme.TEXT_RED)
	_confirm_panel.add_theme_stylebox_override("panel", style)
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.anchor_left = 0.2
	_confirm_panel.anchor_top = 0.3
	_confirm_panel.anchor_right = 0.8
	_confirm_panel.anchor_bottom = 0.7

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_confirm_panel.add_child(vbox)

	var spacer1 := Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer1)

	var msg := Label.new()
	msg.text = "Quit to Main Menu?\nUnsaved progress will be lost."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	msg.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_yes := DungeonTheme.make_styled_btn("Yes, Quit", DungeonTheme.TEXT_RED, 120)
	btn_yes.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
		quit_to_menu_requested.emit()
	)
	btn_row.add_child(btn_yes)

	var btn_no := DungeonTheme.make_styled_btn("Cancel", DungeonTheme.TEXT_GREEN, 120)
	btn_no.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
	)
	btn_row.add_child(btn_no)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer2)

	add_child(_confirm_panel)
