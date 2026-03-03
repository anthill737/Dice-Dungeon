extends PanelContainer
## Settings panel — difficulty, color scheme, text speed, keybindings.
## Built entirely in code to match the project's existing UI pattern.

signal close_requested()

var _difficulty_dropdown: OptionButton
var _color_dropdown: OptionButton
var _text_speed_dropdown: OptionButton
var _keybind_container: VBoxContainer
var _waiting_action: String = ""
var _waiting_button: Button = null
var _keybind_buttons: Dictionary = {}  # action_name -> Button


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

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.97)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
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

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_add_separator(vbox)

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

	_add_separator(vbox)

	# Keybindings header
	var kb_header := Label.new()
	kb_header.text = "KEYBINDINGS"
	kb_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kb_header.add_theme_font_size_override("font_size", 18)
	vbox.add_child(kb_header)

	var kb_hint := Label.new()
	kb_hint.text = "Click a key to rebind, then press the new key."
	kb_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kb_hint.add_theme_font_size_override("font_size", 12)
	kb_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(kb_hint)

	_keybind_container = VBoxContainer.new()
	_keybind_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_keybind_container)

	_build_keybind_rows()

	# Reset keybindings button
	var reset_btn := Button.new()
	reset_btn.text = "Reset Keybindings to Defaults"
	reset_btn.custom_minimum_size = Vector2(0, 36)
	reset_btn.pressed.connect(_on_reset_keybindings)
	vbox.add_child(reset_btn)

	_add_separator(vbox)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func(): close_requested.emit(); visible = false)
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
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var keycode: int = SettingsManager.get_key_for_action(action)
		btn.text = SettingsManager.key_name(keycode)
		btn.pressed.connect(_on_keybind_clicked.bind(action, btn))
		row.add_child(btn)

		_keybind_buttons[action] = btn


func _populate_from_settings() -> void:
	_select_option(_difficulty_dropdown, SettingsManager.DIFFICULTY_OPTIONS, SettingsManager.difficulty)
	_select_option(_color_dropdown, SettingsManager.COLOR_SCHEME_OPTIONS, SettingsManager.color_scheme)
	_select_option(_text_speed_dropdown, SettingsManager.TEXT_SPEED_OPTIONS, SettingsManager.text_speed)
	_refresh_keybind_labels()


func refresh() -> void:
	_populate_from_settings()


# ------------------------------------------------------------------
# Callbacks
# ------------------------------------------------------------------

func _on_difficulty_changed(idx: int) -> void:
	SettingsManager.set_difficulty(SettingsManager.DIFFICULTY_OPTIONS[idx])


func _on_color_changed(idx: int) -> void:
	SettingsManager.set_color_scheme(SettingsManager.COLOR_SCHEME_OPTIONS[idx])


func _on_text_speed_changed(idx: int) -> void:
	SettingsManager.set_text_speed(SettingsManager.TEXT_SPEED_OPTIONS[idx])


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


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func _make_row(parent: Node, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(lbl)

	return row


func _add_separator(parent: Node) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)


static func _select_option(dropdown: OptionButton, options: Array, value: String) -> void:
	for i in options.size():
		if options[i] == value:
			dropdown.selected = i
			return
	dropdown.selected = 0
