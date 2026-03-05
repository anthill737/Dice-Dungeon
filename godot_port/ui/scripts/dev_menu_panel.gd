extends PanelContainer
## Dev Menu — debug-only panel for testing and development.
## Only visible in debug/editor builds (OS.is_debug_build()).
## Provides: seed display, copy seed, spawn test combat, jump to floor.

signal close_requested()

var _seed_label: Label
var _floor_input: LineEdit
var _info_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := Label.new()
	header.text = "DEV MENU (Debug Only)"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	root.add_child(header)

	root.add_child(DungeonTheme.make_separator(Color(1.0, 0.5, 0.0)))

	_seed_label = Label.new()
	_seed_label.text = "Seed: --"
	_seed_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_seed_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_seed_label)

	var copy_seed_btn := DungeonTheme.make_styled_btn("Copy Seed to Clipboard", DungeonTheme.TEXT_CYAN, 220)
	copy_seed_btn.pressed.connect(_on_copy_seed)
	root.add_child(copy_seed_btn)

	root.add_child(DungeonTheme.make_separator())

	var spawn_normal_btn := DungeonTheme.make_styled_btn("Spawn Test Combat (Normal)", DungeonTheme.TEXT_RED, 220)
	spawn_normal_btn.pressed.connect(_on_spawn_normal)
	root.add_child(spawn_normal_btn)

	var spawn_miniboss_btn := DungeonTheme.make_styled_btn("Spawn Test Combat (Miniboss)", DungeonTheme.COMBAT_ACCENT, 220)
	spawn_miniboss_btn.pressed.connect(_on_spawn_miniboss)
	root.add_child(spawn_miniboss_btn)

	root.add_child(DungeonTheme.make_separator())

	var floor_row := HBoxContainer.new()
	floor_row.add_theme_constant_override("separation", 8)
	root.add_child(floor_row)

	var floor_lbl := Label.new()
	floor_lbl.text = "Jump to Floor:"
	floor_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	floor_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	floor_row.add_child(floor_lbl)

	_floor_input = LineEdit.new()
	_floor_input.text = "2"
	_floor_input.custom_minimum_size = Vector2(60, 0)
	floor_row.add_child(_floor_input)

	var jump_btn := DungeonTheme.make_styled_btn("Go", DungeonTheme.TEXT_GREEN, 60)
	jump_btn.pressed.connect(_on_jump_floor)
	floor_row.add_child(jump_btn)

	_info_label = Label.new()
	_info_label.text = ""
	_info_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_info_label.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var note := Label.new()
	note.text = "This panel is only available in debug/editor builds."
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", DungeonTheme.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)


func refresh() -> void:
	if _seed_label == null:
		return
	_seed_label.text = "Seed: %d  |  RNG: %s" % [GameSession.run_seed, GameSession.run_rng_mode]
	_info_label.text = ""


func _on_copy_seed() -> void:
	DisplayServer.clipboard_set(str(GameSession.run_seed))
	_info_label.text = "Seed copied: %d" % GameSession.run_seed


func _on_spawn_normal() -> void:
	if GameSession.game_state == null or GameSession.exploration == null:
		_info_label.text = "No active game."
		return
	if GameSession.is_combat_active() or GameSession.combat_pending:
		_info_label.text = "Already in combat."
		return
	var room := GameSession.get_current_room()
	if room == null:
		_info_label.text = "No room."
		return
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.threats = ["Skeleton"]
	GameSession.combat_pending = true
	GameSession.combat_pending_changed.emit()
	GameSession.state_changed.emit()
	_info_label.text = "Spawned normal combat (Skeleton)."
	close_requested.emit()


func _on_spawn_miniboss() -> void:
	if GameSession.game_state == null or GameSession.exploration == null:
		_info_label.text = "No active game."
		return
	if GameSession.is_combat_active() or GameSession.combat_pending:
		_info_label.text = "Already in combat."
		return
	var room := GameSession.get_current_room()
	if room == null:
		_info_label.text = "No room."
		return
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.is_mini_boss_room = true
	room.threats = ["Shadow Knight"]
	GameSession.combat_pending = true
	GameSession.combat_pending_changed.emit()
	GameSession.state_changed.emit()
	_info_label.text = "Spawned miniboss combat (Shadow Knight)."
	close_requested.emit()


func _on_jump_floor() -> void:
	if GameSession.game_state == null or GameSession.exploration == null:
		_info_label.text = "No active game."
		return
	if GameSession.is_combat_active() or GameSession.combat_pending:
		_info_label.text = "Cannot change floor during combat."
		return
	var raw := _floor_input.text.strip_edges()
	if not raw.is_valid_int():
		_info_label.text = "Enter a valid floor number."
		return
	var target_floor := int(raw)
	if target_floor < 1:
		_info_label.text = "Floor must be >= 1."
		return
	GameSession.game_state.floor = target_floor
	GameSession.exploration.start_floor(target_floor)
	GameSession._emit_logs(GameSession.exploration.logs)
	GameSession.state_changed.emit()
	_info_label.text = "Jumped to floor %d." % target_floor
