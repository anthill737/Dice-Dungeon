extends Control
## Threshold / Intro Area — floor 0 starter area before Floor 1.
## Ported from Python navigation.py show_starter_area.
## Loads content from world_lore.json starting_area.

const _SfxService := preload("res://game/services/sfx_service.gd")

signal enter_dungeon_requested()
signal show_tutorial_requested()

var _threshold_svc: ThresholdService
var _sign_popup: Control
var _chest_popup: Control
var _tutorial_overlay: Control
var _tutorial_scene := preload("res://ui/scenes/TutorialPanel.tscn")


func _ready() -> void:
	_SfxService.ensure_for(self)
	var cm := ContentManager.new()
	cm.load_all()
	_threshold_svc = ThresholdService.new(cm.get_world_lore())
	_build_ui()
	enter_dungeon_requested.connect(_on_enter_dungeon)
	show_tutorial_requested.connect(_on_show_tutorial)
	_sync_music_context()


func _on_enter_dungeon() -> void:
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file("res://ui/scenes/Explorer.tscn")


func _on_show_tutorial() -> void:
	_SfxService.play_for(self, "menu_open")
	if is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_tutorial_overlay = overlay
	_sync_music_context()

	var frame := PanelContainer.new()
	var style := DungeonTheme.make_panel_bg(DungeonTheme.BG_PRIMARY, DungeonTheme.BORDER_GOLD)
	style.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", style)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.anchor_left = 0.05
	frame.anchor_top = 0.05
	frame.anchor_right = 0.95
	frame.anchor_bottom = 0.95
	overlay.add_child(frame)

	var frame_vbox := VBoxContainer.new()
	frame_vbox.add_theme_constant_override("separation", 4)
	frame.add_child(frame_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	frame_vbox.add_child(header_row)

	var title := Label.new()
	title.text = "📜 HOW TO PLAY"
	title.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	header_row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	close_btn.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
	var cb_style := StyleBoxFlat.new()
	cb_style.bg_color = Color(0, 0, 0, 0)
	cb_style.set_content_margin_all(4)
	close_btn.add_theme_stylebox_override("normal", cb_style)
	close_btn.add_theme_stylebox_override("hover", cb_style)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_tutorial_overlay = null
		_sync_music_context()
	)
	header_row.add_child(close_btn)

	var tutorial := _tutorial_scene.instantiate()
	tutorial.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial.close_requested.connect(func():
		overlay.queue_free()
		_tutorial_overlay = null
		_sync_music_context()
	)
	frame_vbox.add_child(tutorial)


func _sync_music_context(immediate: bool = false) -> void:
	var options := {"immediate": immediate}
	if is_instance_valid(_tutorial_overlay):
		options["fallback_context"] = "threshold_area"
		MusicService.set_context("tutorial", options)
		return
	MusicService.set_context("threshold_area", options)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = DungeonTheme.BG_PRIMARY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var area_name: String = _threshold_svc.get_area_name()
	var description: String = _threshold_svc.get_description()
	var ambient: Array = _threshold_svc.get_ambient_details()
	var signs: Array = _threshold_svc.get_signs()
	var chests: Array = _threshold_svc.get_starter_chests()

	var root_scroll := ScrollContainer.new()
	root_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_scroll.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root_scroll)

	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 60)
	root_margin.add_theme_constant_override("margin_right", 60)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	root_scroll.add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	root_margin.add_child(root_vbox)

	var title := Label.new()
	title.text = area_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	root_vbox.add_child(title)

	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		desc.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
		root_vbox.add_child(desc)

	if not ambient.is_empty():
		var ambient_text := ""
		for detail in ambient:
			ambient_text += "• " + str(detail) + "\n"
		var ambient_lbl := Label.new()
		ambient_lbl.text = ambient_text.strip_edges()
		ambient_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ambient_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ambient_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		ambient_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		root_vbox.add_child(ambient_lbl)

	var sep1 := DungeonTheme.make_separator(DungeonTheme.BORDER_GOLD)
	root_vbox.add_child(sep1)

	var welcome_panel := PanelContainer.new()
	var wp_style := StyleBoxFlat.new()
	wp_style.bg_color = DungeonTheme.BG_PANEL
	wp_style.border_color = DungeonTheme.BORDER_GOLD
	wp_style.set_border_width_all(1)
	wp_style.set_corner_radius_all(4)
	wp_style.set_content_margin_all(16)
	welcome_panel.add_theme_stylebox_override("panel", wp_style)
	root_vbox.add_child(welcome_panel)

	var welcome_vbox := VBoxContainer.new()
	welcome_vbox.add_theme_constant_override("separation", 8)
	welcome_panel.add_child(welcome_vbox)

	var welcome_text := Label.new()
	welcome_text.text = "Welcome, Adventurer. Study these teachings before your journey begins.\n\nIn the dungeon, you'll encounter interactive elements like chests, signs, floor buttons, and containers.\nClick on them to search for items and discover secrets. Open the chests below to get a few starter items."
	welcome_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	welcome_text.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	welcome_text.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	welcome_vbox.add_child(welcome_text)

	var tutorial_btn_row := HBoxContainer.new()
	tutorial_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	welcome_vbox.add_child(tutorial_btn_row)

	var btn_tutorial := DungeonTheme.make_styled_btn("📜 Show Tutorial - How to Play", DungeonTheme.TEXT_BONE, 280)
	btn_tutorial.custom_minimum_size.y = 36
	btn_tutorial.pressed.connect(func(): show_tutorial_requested.emit())
	tutorial_btn_row.add_child(btn_tutorial)

	if not signs.is_empty():
		var signs_header := Label.new()
		signs_header.text = "Signs & Inscriptions:"
		signs_header.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
		signs_header.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
		root_vbox.add_child(signs_header)

		for sign_data in signs:
			var sign_title: String = sign_data.get("title", "Sign")
			var btn := DungeonTheme.make_styled_btn(sign_title, DungeonTheme.BTN_PRIMARY, 400)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size.y = 32
			btn.pressed.connect(_on_sign_pressed.bind(sign_data))
			root_vbox.add_child(btn)

	if not chests.is_empty():
		var chests_header := Label.new()
		chests_header.text = "Chests:"
		chests_header.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
		chests_header.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
		root_vbox.add_child(chests_header)

		for chest_data in chests:
			var chest_desc: String = chest_data.get("description", "Chest")
			var chest_id: int = int(chest_data.get("id", 0))
			var btn := DungeonTheme.make_styled_btn(chest_desc, DungeonTheme.BTN_SECONDARY, 400)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size.y = 32
			if _threshold_svc.is_chest_opened(chest_id, GameSession.game_state):
				btn.disabled = true
				btn.text = chest_desc + " (Opened)"
			btn.pressed.connect(_on_chest_pressed.bind(chest_data, btn))
			root_vbox.add_child(btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	root_vbox.add_child(spacer)

	var enter_row := HBoxContainer.new()
	enter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(enter_row)

	var btn_enter := DungeonTheme.make_styled_btn("ENTER THE DUNGEON - FLOOR 1", DungeonTheme.TEXT_RED, 300)
	btn_enter.custom_minimum_size.y = 44
	btn_enter.pressed.connect(func(): enter_dungeon_requested.emit())
	enter_row.add_child(btn_enter)


func _on_sign_pressed(sign_data: Dictionary) -> void:
	_SfxService.play_for(self, "menu_open")
	if is_instance_valid(_sign_popup):
		_sign_popup.queue_free()

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_sign_popup = overlay

	var panel := PanelContainer.new()
	var style := DungeonTheme.make_panel_bg(DungeonTheme.BG_PRIMARY, DungeonTheme.BORDER_GOLD)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.15
	panel.anchor_top = 0.15
	panel.anchor_right = 0.85
	panel.anchor_bottom = 0.85
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = sign_data.get("title", "Sign")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	vbox.add_child(title)

	var sep := DungeonTheme.make_separator(DungeonTheme.BORDER_GOLD)
	vbox.add_child(sep)

	var text_scroll := ScrollContainer.new()
	text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(text_scroll)

	var text := RichTextLabel.new()
	text.text = sign_data.get("text", "")
	text.bbcode_enabled = false
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	text.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	text_scroll.add_child(text)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_close := DungeonTheme.make_styled_btn("Continue", DungeonTheme.BTN_PRIMARY, 160)
	btn_close.custom_minimum_size.y = 36
	btn_close.pressed.connect(func():
		overlay.queue_free()
		_sign_popup = null
	)
	btn_row.add_child(btn_close)


func _on_chest_pressed(chest_data: Dictionary, btn: Button) -> void:
	var result := _threshold_svc.open_chest(chest_data, GameSession.game_state, GameSession.inventory_engine)
	if result.is_empty():
		return
	btn.disabled = true
	btn.text = chest_data.get("description", "Chest") + " (Opened)"
	_SfxService.play_for(self, "chest_open")
	if int(result.get("gold", 0)) > 0:
		_SfxService.play_for(self, "gold_pickup")
	if not (result.get("items", []) as Array).is_empty():
		_SfxService.play_for(self, "item_pickup")
	GameSession.state_changed.emit()
	_show_chest_popup(chest_data, result.get("items", []), int(result.get("gold", 0)), result.get("lore", ""))


func _show_chest_popup(chest_data: Dictionary, items: Array, gold: int, lore_text: String) -> void:
	if is_instance_valid(_chest_popup):
		_chest_popup.queue_free()

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_chest_popup = overlay

	var panel := PanelContainer.new()
	var style := DungeonTheme.make_panel_bg(DungeonTheme.BG_PRIMARY, DungeonTheme.BORDER_GOLD)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.2
	panel.anchor_top = 0.2
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.8
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "CHEST OPENED"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	header.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
	vbox.add_child(header)

	var chest_name := Label.new()
	chest_name.text = chest_data.get("description", "Chest")
	chest_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_name.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	chest_name.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	vbox.add_child(chest_name)

	var contents_panel := PanelContainer.new()
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = DungeonTheme.BG_PANEL
	cp_style.border_color = DungeonTheme.BORDER
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(4)
	cp_style.set_content_margin_all(12)
	contents_panel.add_theme_stylebox_override("panel", cp_style)
	vbox.add_child(contents_panel)

	var contents_vbox := VBoxContainer.new()
	contents_vbox.add_theme_constant_override("separation", 4)
	contents_panel.add_child(contents_vbox)

	var found_label := Label.new()
	found_label.text = "You found:"
	found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	found_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	found_label.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	contents_vbox.add_child(found_label)

	for item_name in items:
		var item_lbl := Label.new()
		item_lbl.text = "• " + str(item_name)
		item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		item_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
		contents_vbox.add_child(item_lbl)

	if gold > 0:
		var gold_lbl := Label.new()
		gold_lbl.text = "• %d Gold" % gold
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		gold_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
		contents_vbox.add_child(gold_lbl)

	if not lore_text.is_empty():
		var lore_lbl := Label.new()
		lore_lbl.text = lore_text
		lore_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		lore_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		vbox.add_child(lore_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_close := DungeonTheme.make_styled_btn("Continue", DungeonTheme.BTN_PRIMARY, 160)
	btn_close.custom_minimum_size.y = 36
	btn_close.pressed.connect(func():
		overlay.queue_free()
		_chest_popup = null
	)
	btn_row.add_child(btn_close)
