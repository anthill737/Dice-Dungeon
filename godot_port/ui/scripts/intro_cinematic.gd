extends Control
## Intro cinematic — text-driven narrative intro before the threshold.
## Ported from Python show_narrative_intro in dice_dungeon_explorer.py.
## Shown only on new game, not on load.

signal intro_finished()

var _threshold_scene := preload("res://ui/scenes/ThresholdArea.tscn")
const _SfxService := preload("res://game/services/sfx_service.gd")

const INTRO_TEXT := """Your eyes snap open.

Cold stone presses against your back as you sit up, heart racing, breath shallow. For a moment, you don't know where you are. The air smells damp and old, like rain-soaked earth and rusted iron.

You push yourself to your feet and look around.

A structure rises from the forest floor around you—stone walls half-swallowed by roots and moss, as if the ground tried and failed to reclaim it. You remember finding it just before nightfall. Remember brushing away vines. Remember thinking you'd only step inside for a moment.

There's a strange pressure behind your eyes, like the tail end of a dream you can't quite shake. A fleeting sense that something is… off. Familiar. You frown and force the thought away. You're tired. That's all.

At your feet lies a small set of dice. Clean. Unmarked. Dry, despite the damp air. You're not sure where they came from, only that seeing them there feels… correct.

You pocket them.

Somewhere deeper within the structure, stone grinds against stone. A passage opens."""


func _ready() -> void:
	_SfxService.ensure_for(self)
	intro_finished.connect(_on_intro_finished)
	var options: Dictionary = GameSession.pending_run_options
	if not options.is_empty():
		GameSession.pending_run_options = {}
		GameSession.start_new_run(options)
	elif GameSession.game_state == null:
		GameSession.start_new_game()
	MusicService.set_context("intro_cinematic")
	_build_ui()


func _on_intro_finished() -> void:
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file("res://ui/scenes/ThresholdArea.tscn")


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = DungeonTheme.BG_PRIMARY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	center.add_theme_constant_override("separation", 0)
	add_child(center)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.size_flags_stretch_ratio = 0.3
	center.add_child(spacer_top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	scroll.add_child(margin)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(text_vbox)

	var paragraphs := INTRO_TEXT.strip_edges().split("\n\n")
	for paragraph in paragraphs:
		var lbl := Label.new()
		lbl.text = paragraph.strip_edges()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
		lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
		text_vbox.add_child(lbl)

	var spacer_mid := Control.new()
	spacer_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_mid.size_flags_stretch_ratio = 0.2
	center.add_child(spacer_mid)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_row)

	var btn_continue := DungeonTheme.make_styled_btn("Continue", DungeonTheme.BTN_PRIMARY, 200)
	btn_continue.custom_minimum_size.y = 42
	btn_continue.pressed.connect(func(): intro_finished.emit())
	btn_row.add_child(btn_continue)

	var spacer_bottom := Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 40)
	center.add_child(spacer_bottom)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			intro_finished.emit()
			get_viewport().set_input_as_handled()
