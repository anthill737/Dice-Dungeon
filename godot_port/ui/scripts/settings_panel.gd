extends PanelContainer
## Settings panel — difficulty, color scheme, text speed, keybindings.
## Built entirely in code to match the project's existing UI pattern.

signal close_requested()

var _difficulty_dropdown: OptionButton
var _color_dropdown: OptionButton
var _text_speed_dropdown: OptionButton
var _combat_pacing_dropdown: OptionButton
var _music_enabled_check: CheckBox
var _music_volume_slider: HSlider
var _music_volume_value: Label
var _keybind_container: VBoxContainer
var _waiting_action: String = ""
var _waiting_button: Button = null
var _keybind_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_populate_from_settings()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(520, 500)
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -260
	offset_top = -250
	offset_right = 260
	offset_bottom = 250

	var style := DungeonTheme.make_panel_bg(
		Color(0.12, 0.10, 0.08, 0.97), DungeonTheme.BORDER)
	add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var title := DungeonTheme.make_header(
		"⚙ SETTINGS", DungeonTheme.TEXT_BONE, DungeonTheme.FONT_TITLE)
	vbox.add_child(title)

	vbox.add_child(DungeonTheme.make_separator())

	# Difficulty
	var diff_row := _make_row(vbox, "Difficulty")
	_difficulty_dropdown = OptionButton.new()
	_difficulty_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in SettingsManager.DIFFICULTY_OPTIONS:
		_difficulty_dropdown.add_item(opt)
	_difficulty_dropdown.item_selected.connect(_on_difficulty_changed)
	diff_row.add_child(_difficulty_dropdown)

	# Color Scheme
	var color_row := _make_row(vbox, "Color Scheme")
	_color_dropdown = OptionButton.new()
	_color_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in SettingsManager.COLOR_SCHEME_OPTIONS:
		_color_dropdown.add_item(opt)
	_color_dropdown.item_selected.connect(_on_color_changed)
	color_row.add_child(_color_dropdown)

	# Text Speed
	var speed_row := _make_row(vbox, "Text Speed")
	_text_speed_dropdown = OptionButton.new()
	_text_speed_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in SettingsManager.TEXT_SPEED_OPTIONS:
		_text_speed_dropdown.add_item(opt)
	_text_speed_dropdown.item_selected.connect(_on_text_speed_changed)
	speed_row.add_child(_text_speed_dropdown)

	# Combat Pacing
	var pacing_row := _make_row(vbox, "Combat Pacing")
	_combat_pacing_dropdown = OptionButton.new()
	_combat_pacing_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in SettingsManager.COMBAT_PACING_OPTIONS:
		_combat_pacing_dropdown.add_item(opt)
	_combat_pacing_dropdown.item_selected.connect(_on_combat_pacing_changed)
	pacing_row.add_child(_combat_pacing_dropdown)

	vbox.add_child(DungeonTheme.make_separator())

	var audio_header := DungeonTheme.make_header(
		"AUDIO", DungeonTheme.TEXT_BONE, DungeonTheme.FONT_SUBHEADING)
	vbox.add_child(audio_header)

	var music_toggle_row := _make_row(vbox, "Music")
	_music_enabled_check = CheckBox.new()
	_music_enabled_check.text = "Enabled"
	_music_enabled_check.toggled.connect(_on_music_enabled_toggled)
	music_toggle_row.add_child(_music_enabled_check)

	var music_volume_row := _make_row(vbox, "Music Volume")
	var music_volume_box := HBoxContainer.new()
	music_volume_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_volume_box.add_theme_constant_override("separation", 8)
	music_volume_row.add_child(music_volume_box)

	_music_volume_slider = HSlider.new()
	_music_volume_slider.min_value = 0
	_music_volume_slider.max_value = 100
	_music_volume_slider.step = 1
	_music_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_volume_slider.value_changed.connect(_on_music_volume_changed)
	music_volume_box.add_child(_music_volume_slider)

	_music_volume_value = Label.new()
	_music_volume_value.custom_minimum_size = Vector2(52, 0)
	_music_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_music_volume_value.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_music_volume_value.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	music_volume_box.add_child(_music_volume_value)

	vbox.add_child(DungeonTheme.make_separator())

	# Keybindings header
	var kb_header := DungeonTheme.make_header(
		"KEYBINDINGS", DungeonTheme.TEXT_BONE, DungeonTheme.FONT_SUBHEADING)
	vbox.add_child(kb_header)

	var kb_hint := Label.new()
	kb_hint.text = "Click a key to rebind, then press the new key."
	kb_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kb_hint.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	kb_hint.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	vbox.add_child(kb_hint)

	_keybind_container = VBoxContainer.new()
	_keybind_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_keybind_container)

	_build_keybind_rows()

	var reset_btn := DungeonTheme.make_styled_btn(
		"Reset Keybindings to Defaults", DungeonTheme.TEXT_RED, 200)
	reset_btn.custom_minimum_size.y = 36
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset_keybindings)
	vbox.add_child(reset_btn)

	vbox.add_child(DungeonTheme.make_separator())

	var close_btn := DungeonTheme.make_styled_btn(
		"Close", DungeonTheme.TEXT_SECONDARY, 200)
	close_btn.custom_minimum_size.y = 40
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): close_requested.emit())
	vbox.add_child(close_btn)


func _build_keybind_rows() -> void:
	for child in _keybind_container.get_children():
		child.queue_free()
	_keybind_buttons.clear()

	for action in SettingsManager.BINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_keybind_container.add_child(row)

		var lbl := Label.new()
		lbl.text = SettingsManager.ACTION_DISPLAY_NAMES.get(action, action)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(180, 0)
		lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
		row.add_child(lbl)

		var btn := DungeonTheme.make_styled_btn("", DungeonTheme.TEXT_CYAN, 120)
		var keycode: int = SettingsManager.get_key_for_action(action)
		btn.text = SettingsManager.key_name(keycode)
		btn.pressed.connect(_on_keybind_clicked.bind(action, btn))
		row.add_child(btn)

		_keybind_buttons[action] = btn


func _populate_from_settings() -> void:
	_select_option(_difficulty_dropdown, SettingsManager.DIFFICULTY_OPTIONS, SettingsManager.difficulty)
	_select_option(_color_dropdown, SettingsManager.COLOR_SCHEME_OPTIONS, SettingsManager.color_scheme)
	_select_option(_text_speed_dropdown, SettingsManager.TEXT_SPEED_OPTIONS, SettingsManager.text_speed)
	_select_option(_combat_pacing_dropdown, SettingsManager.COMBAT_PACING_OPTIONS, SettingsManager.combat_pacing)
	_music_enabled_check.button_pressed = SettingsManager.music_enabled
	_music_volume_slider.value = roundi(SettingsManager.music_volume * 100.0)
	_music_volume_slider.editable = SettingsManager.music_enabled
	_update_music_volume_label()
	_refresh_keybind_labels()


func refresh() -> void:
	_populate_from_settings()


func _on_difficulty_changed(idx: int) -> void:
	SettingsManager.set_difficulty(SettingsManager.DIFFICULTY_OPTIONS[idx])


func _on_color_changed(idx: int) -> void:
	SettingsManager.set_color_scheme(SettingsManager.COLOR_SCHEME_OPTIONS[idx])


func _on_text_speed_changed(idx: int) -> void:
	SettingsManager.set_text_speed(SettingsManager.TEXT_SPEED_OPTIONS[idx])


func _on_combat_pacing_changed(idx: int) -> void:
	SettingsManager.set_combat_pacing(SettingsManager.COMBAT_PACING_OPTIONS[idx])


func _on_music_enabled_toggled(enabled: bool) -> void:
	_music_volume_slider.editable = enabled
	SettingsManager.set_music_enabled(enabled)


func _on_music_volume_changed(value: float) -> void:
	_update_music_volume_label()
	SettingsManager.set_music_volume(value / 100.0)


func _on_keybind_clicked(action: String, btn: Button) -> void:
	if _waiting_button != null:
		_waiting_button.text = SettingsManager.key_name(SettingsManager.get_key_for_action(_waiting_action))
	_waiting_action = action
	_waiting_button = btn
	btn.text = "... press key ..."


func _on_reset_keybindings() -> void:
	_waiting_action = ""
	_waiting_button = null
	SettingsManager.reset_keybindings_to_defaults()
	_refresh_keybind_labels()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_action.is_empty() or _waiting_button == null:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key_event := event as InputEventKey
	SettingsManager.set_keybinding(_waiting_action, key_event.keycode)
	_waiting_button.text = SettingsManager.key_name(key_event.keycode)
	_waiting_action = ""
	_waiting_button = null
	get_viewport().set_input_as_handled()


func _refresh_keybind_labels() -> void:
	for action in _keybind_buttons:
		var btn: Button = _keybind_buttons[action]
		btn.text = SettingsManager.key_name(SettingsManager.get_key_for_action(action))


func _update_music_volume_label() -> void:
	if _music_volume_value == null or _music_volume_slider == null:
		return
	_music_volume_value.text = "%d%%" % int(_music_volume_slider.value)


func _make_row(parent: Node, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	row.add_child(lbl)

	return row


static func _select_option(dropdown: OptionButton, options: Array, value: String) -> void:
	for i in options.size():
		if options[i] == value:
			dropdown.selected = i
			return
	dropdown.selected = 0
