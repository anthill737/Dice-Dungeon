extends PanelContainer
## Start Adventure Panel — lets the player choose between a normal run
## or a deterministic seeded run.  Hosted inside PopupFrame.

signal close_requested()
signal start_run_requested(options: Dictionary)

var _btn_start: Button
var _btn_seeded_toggle: Button
var _seed_row: HBoxContainer
var _seed_input: LineEdit
var _btn_start_seeded: Button
var _error_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 8)
	root.add_child(spacer_top)

	_btn_start = DungeonTheme.make_styled_btn("⚔  Start Run", DungeonTheme.BTN_PRIMARY, 240)
	_btn_start.name = "BtnStartRun"
	_btn_start.custom_minimum_size.y = 44
	_btn_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_start.pressed.connect(_on_start_run)
	root.add_child(_btn_start)

	root.add_child(DungeonTheme.make_separator())

	_btn_seeded_toggle = DungeonTheme.make_styled_btn("🌱  Start Seeded Run", DungeonTheme.BTN_SECONDARY, 240)
	_btn_seeded_toggle.name = "BtnSeededToggle"
	_btn_seeded_toggle.custom_minimum_size.y = 44
	_btn_seeded_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_seeded_toggle.pressed.connect(_on_seeded_toggle)
	root.add_child(_btn_seeded_toggle)

	# Seed input row — hidden until toggle
	_seed_row = HBoxContainer.new()
	_seed_row.name = "SeedRow"
	_seed_row.add_theme_constant_override("separation", 8)
	_seed_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_seed_row.visible = false
	root.add_child(_seed_row)

	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:"
	seed_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	seed_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	_seed_row.add_child(seed_lbl)

	_seed_input = LineEdit.new()
	_seed_input.name = "SeedInput"
	_seed_input.text = "12345"
	_seed_input.custom_minimum_size = Vector2(140, 0)
	_seed_input.placeholder_text = "Enter integer seed..."
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_row.add_child(_seed_input)

	_btn_start_seeded = DungeonTheme.make_styled_btn("Start Seeded Run", DungeonTheme.TEXT_GREEN, 160)
	_btn_start_seeded.name = "BtnStartSeeded"
	_btn_start_seeded.visible = false
	_btn_start_seeded.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_start_seeded.pressed.connect(_on_start_seeded)
	root.add_child(_btn_start_seeded)

	_error_label = Label.new()
	_error_label.name = "ErrorLabel"
	_error_label.text = ""
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_error_label.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
	root.add_child(_error_label)


func _on_start_run() -> void:
	start_run_requested.emit({"rng_mode": "default"})


func _on_seeded_toggle() -> void:
	_seed_row.visible = not _seed_row.visible
	_btn_start_seeded.visible = _seed_row.visible
	_error_label.text = ""


func _on_start_seeded() -> void:
	var raw := _seed_input.text.strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		_error_label.text = "Seed must be a valid integer."
		return
	_error_label.text = ""
	var seed_val := int(raw)
	start_run_requested.emit({"rng_mode": "deterministic", "seed": seed_val})


func refresh() -> void:
	_seed_row.visible = false
	_btn_start_seeded.visible = false
	_error_label.text = ""
	_seed_input.text = "12345"
