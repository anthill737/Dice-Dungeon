extends PanelContainer
## Ground Items Panel — renders room ground loot state and dispatches actions.
## All gameplay logic lives in ExplorationEngine / GameSession.
## This panel only reads state and requests actions.

signal close_requested()

var _content_vbox: VBoxContainer
var _scroll: ScrollContainer
var _btn_close: Button
var _btn_take_all: Button
var _container_popup: Control


func _ready() -> void:
	_build_ui()
	refresh()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content_vbox)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	_btn_take_all = DungeonTheme.make_styled_btn("Take All", DungeonTheme.TEXT_GREEN, 140)
	_btn_take_all.custom_minimum_size.y = 36
	_btn_take_all.pressed.connect(_on_take_all)
	footer.add_child(_btn_take_all)

	_btn_close = DungeonTheme.make_styled_btn("Close", DungeonTheme.BTN_SECONDARY, 140)
	_btn_close.custom_minimum_size.y = 36
	_btn_close.pressed.connect(func(): close_requested.emit())
	footer.add_child(_btn_close)


func refresh() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()

	var room := GameSession.get_current_room()
	if room == null:
		_btn_take_all.visible = false
		return

	var container_has_loot := room.container_gold > 0 or not room.container_item.is_empty()
	var show_container := not room.ground_container.is_empty() and (not room.container_searched or room.container_locked or container_has_loot)

	if show_container:
		_add_container_section(room)

	if room.ground_gold > 0:
		_add_gold_section(room)

	if not room.ground_items.is_empty():
		_add_items_section("Items:", room.ground_items, "_pickup_ground_item")

	if not room.uncollected_items.is_empty():
		_add_items_section("Left Behind:", room.uncollected_items, "_pickup_uncollected_item")

	if not room.dropped_items.is_empty():
		_add_items_section("Dropped:", room.dropped_items, "_pickup_dropped_item")

	var pickable_count := (1 if room.ground_gold > 0 else 0) + room.ground_items.size() + room.uncollected_items.size() + room.dropped_items.size()
	_btn_take_all.visible = pickable_count >= 2


func _add_container_section(room: RoomState) -> void:
	var header := Label.new()
	header.text = "Container:"
	header.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	header.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	_content_vbox.add_child(header)

	var cname: String = room.ground_container
	var cdef: Dictionary = GameSession.container_db.get(cname, {})
	var cdesc: String = cdef.get("description", "")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(row)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ip_style := StyleBoxFlat.new()
	ip_style.bg_color = DungeonTheme.BG_PANEL
	ip_style.set_corner_radius_all(4)
	ip_style.set_content_margin_all(8)
	info_panel.add_theme_stylebox_override("panel", ip_style)
	row.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_panel.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = cname
	name_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	name_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	info_vbox.add_child(name_lbl)

	if not cdesc.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = cdesc
		desc_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		desc_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		info_vbox.add_child(desc_lbl)

	if room.container_locked:
		if GameSession.game_state != null and GameSession.game_state.inventory.has("Lockpick Kit"):
			var btn := DungeonTheme.make_styled_btn("Use Lockpick", DungeonTheme.BTN_SECONDARY, 120)
			btn.pressed.connect(_on_use_lockpick)
			row.add_child(btn)
		else:
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒 LOCKED"
			lock_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
			lock_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
			row.add_child(lock_lbl)
	elif not room.container_searched:
		var btn := DungeonTheme.make_styled_btn("Search", DungeonTheme.BTN_SECONDARY, 100)
		btn.pressed.connect(_on_search_container)
		row.add_child(btn)
	elif room.container_gold > 0 or not room.container_item.is_empty():
		var btn := DungeonTheme.make_styled_btn("Open", DungeonTheme.BTN_SECONDARY, 100)
		btn.pressed.connect(_on_open_searched_container)
		row.add_child(btn)


func _add_gold_section(room: RoomState) -> void:
	var header := Label.new()
	header.text = "Gold Coins:"
	header.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	header.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	_content_vbox.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(row)

	var gold_panel := PanelContainer.new()
	gold_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gp_style := StyleBoxFlat.new()
	gp_style.bg_color = DungeonTheme.BG_PANEL
	gp_style.set_corner_radius_all(4)
	gp_style.set_content_margin_all(8)
	gold_panel.add_theme_stylebox_override("panel", gp_style)
	row.add_child(gold_panel)

	var gold_lbl := Label.new()
	gold_lbl.text = "◆ %d Gold" % room.ground_gold
	gold_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	gold_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	gold_panel.add_child(gold_lbl)

	var btn := DungeonTheme.make_styled_btn("Pick Up", DungeonTheme.BTN_PRIMARY, 100)
	btn.pressed.connect(_on_pickup_gold)
	row.add_child(btn)


func _add_items_section(section_title: String, items: Array, callback_name: String) -> void:
	var header := Label.new()
	header.text = section_title
	header.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	header.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	_content_vbox.add_child(header)

	for i in items.size():
		var item_name: String = str(items[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_content_vbox.add_child(row)

		# Item icon
		if GameSession.assets != null:
			var icon_tex = GameSession.assets.get_item_icon(item_name, 32)
			if icon_tex != null:
				var icon_rect := TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(32, 32)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(icon_rect)

		var item_panel := PanelContainer.new()
		item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ip_style := StyleBoxFlat.new()
		ip_style.bg_color = DungeonTheme.BG_PANEL
		ip_style.set_corner_radius_all(4)
		ip_style.set_content_margin_all(8)
		item_panel.add_theme_stylebox_override("panel", ip_style)
		row.add_child(item_panel)

		var name_lbl := Label.new()
		name_lbl.text = item_name
		name_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
		name_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_setup_tooltip(name_lbl, item_name)
		item_panel.add_child(name_lbl)

		var btn := DungeonTheme.make_styled_btn("Pick Up", DungeonTheme.TEXT_GREEN, 100)
		btn.pressed.connect(Callable(self, callback_name).bind(i))
		row.add_child(btn)


func _setup_tooltip(control: Control, item_name: String) -> void:
	var item_def: Dictionary = {}
	if GameSession.inventory_engine != null:
		item_def = GameSession.inventory_engine.get_item_def(item_name)
	control.tooltip_text = TooltipFormatter.format(item_name, item_def)


# --- Action handlers — delegate to engine, then re-render from state ---

func _on_pickup_gold() -> void:
	GameSession.pickup_ground_gold()
	GameSession.state_changed.emit()
	refresh()


func _pickup_ground_item(index: int) -> void:
	var result := GameSession.pickup_ground_item(index)
	if result.is_empty():
		GameSession.log_message.emit("Inventory full! Cannot pick up item.")
	GameSession.state_changed.emit()
	refresh()


func _pickup_uncollected_item(index: int) -> void:
	var room := GameSession.get_current_room()
	if room == null or index >= room.uncollected_items.size():
		return
	var item_name: String = room.uncollected_items[index]
	if GameSession.inventory_engine != null and GameSession.inventory_engine.add_item_to_inventory(item_name, "ground"):
		room.uncollected_items.remove_at(index)
	else:
		GameSession.log_message.emit("Inventory full! Cannot pick up %s." % item_name)
	GameSession.state_changed.emit()
	refresh()


func _pickup_dropped_item(index: int) -> void:
	var room := GameSession.get_current_room()
	if room == null or index >= room.dropped_items.size():
		return
	var item_name: String = room.dropped_items[index]
	if GameSession.inventory_engine != null and GameSession.inventory_engine.add_item_to_inventory(item_name, "ground"):
		room.dropped_items.remove_at(index)
	else:
		GameSession.log_message.emit("Inventory full! Cannot pick up %s." % item_name)
	GameSession.state_changed.emit()
	refresh()


func _on_search_container() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return
	var result := GameSession.exploration.search_container(room)
	GameSession._emit_logs(GameSession.exploration.logs)
	if not result.is_empty() and not result.get("locked", false):
		_show_container_contents(room)
	GameSession.state_changed.emit()
	refresh()


func _on_open_searched_container() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return
	_show_container_contents(room)


func _on_use_lockpick() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return
	var unlock_result := GameSession.inventory_engine.use_lockpick_on_container(room)
	GameSession._emit_logs(GameSession.inventory_engine.logs)
	if unlock_result.get("ok", false):
		var search_result := GameSession.exploration.search_container(room)
		GameSession._emit_logs(GameSession.exploration.logs)
		if not search_result.is_empty() and not search_result.get("locked", false):
			_show_container_contents(room)
	GameSession.state_changed.emit()
	refresh()


func _on_take_all() -> void:
	if GameSession.exploration == null:
		return
	var room := GameSession.get_current_room()
	if room == null:
		return
	GameSession.exploration.pickup_all_ground(room)
	GameSession._emit_logs(GameSession.exploration.logs)
	GameSession.state_changed.emit()
	refresh()


# --- Container contents popup ---

func _show_container_contents(room: RoomState) -> void:
	if is_instance_valid(_container_popup):
		_container_popup.queue_free()

	var gold: int = room.container_gold
	var item: String = room.container_item
	var cname: String = room.ground_container
	var cdef: Dictionary = GameSession.container_db.get(cname, {})
	var cdesc: String = cdef.get("description", "")

	# Use a CanvasLayer above the MenuOverlayManager (layer 100) so this
	# popup appears on top of the ground-items panel, not behind it.
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 110
	var root_node := get_tree().root if get_tree() != null else self
	(root_node as Node).add_child(canvas_layer)
	_container_popup = canvas_layer

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)

	var panel := PanelContainer.new()
	var style := DungeonTheme.make_panel_bg(DungeonTheme.BG_PRIMARY, DungeonTheme.BORDER_GOLD)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.2
	panel.anchor_top = 0.15
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.85
	canvas_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "▢ %s ▢" % cname.to_upper()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	header.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	vbox.add_child(header)

	if not cdesc.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = cdesc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		desc_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		vbox.add_child(desc_lbl)

	var contents_panel := PanelContainer.new()
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = DungeonTheme.BG_PANEL
	cp_style.border_color = DungeonTheme.BORDER
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(4)
	cp_style.set_content_margin_all(12)
	contents_panel.add_theme_stylebox_override("panel", cp_style)
	vbox.add_child(contents_panel)

	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 6)
	contents_panel.add_child(c_vbox)

	var found_lbl := Label.new()
	found_lbl.text = "You found:"
	found_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	found_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	found_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	c_vbox.add_child(found_lbl)

	if gold <= 0 and item.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "The container is empty."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		empty_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		c_vbox.add_child(empty_lbl)

	if gold > 0:
		_add_container_gold_row(c_vbox, room, gold)

	if not item.is_empty():
		_add_container_item_row(c_vbox, room, item)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_footer := HBoxContainer.new()
	btn_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_footer.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_footer)

	if gold > 0 and not item.is_empty():
		var take_all_btn := DungeonTheme.make_styled_btn("Take All", DungeonTheme.TEXT_GREEN, 120)
		take_all_btn.custom_minimum_size.y = 36
		take_all_btn.pressed.connect(func():
			GameSession.exploration.take_all_container(room)
			GameSession._emit_logs(GameSession.exploration.logs)
			GameSession.state_changed.emit()
			_dismiss_container_popup()
		)
		btn_footer.add_child(take_all_btn)

	var close_btn := DungeonTheme.make_styled_btn("Close", DungeonTheme.BTN_SECONDARY, 120)
	close_btn.custom_minimum_size.y = 36
	close_btn.pressed.connect(_dismiss_container_popup)
	btn_footer.add_child(close_btn)


func _add_container_gold_row(parent: VBoxContainer, room: RoomState, gold: int) -> void:
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	parent.add_child(gold_row)
	var g_panel := PanelContainer.new()
	g_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gs := StyleBoxFlat.new()
	gs.bg_color = DungeonTheme.BG_PANEL.lightened(0.05)
	gs.set_corner_radius_all(4)
	gs.set_content_margin_all(8)
	g_panel.add_theme_stylebox_override("panel", gs)
	gold_row.add_child(g_panel)
	var g_lbl := Label.new()
	g_lbl.text = "◆ %d Gold" % gold
	g_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	g_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	g_panel.add_child(g_lbl)
	var g_btn := DungeonTheme.make_styled_btn("Take", DungeonTheme.BTN_PRIMARY, 80)
	g_btn.pressed.connect(func():
		GameSession.exploration.take_container_gold(room)
		GameSession._emit_logs(GameSession.exploration.logs)
		GameSession.state_changed.emit()
		_dismiss_container_popup()
	)
	gold_row.add_child(g_btn)


func _add_container_item_row(parent: VBoxContainer, room: RoomState, item: String) -> void:
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 8)
	parent.add_child(item_row)
	var i_panel := PanelContainer.new()
	i_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var i_s := StyleBoxFlat.new()
	i_s.bg_color = DungeonTheme.BG_PANEL.lightened(0.05)
	i_s.set_corner_radius_all(4)
	i_s.set_content_margin_all(8)
	i_panel.add_theme_stylebox_override("panel", i_s)
	item_row.add_child(i_panel)
	var i_lbl := Label.new()
	i_lbl.text = "⚡ %s" % item
	i_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	i_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	i_panel.add_child(i_lbl)
	var i_btn := DungeonTheme.make_styled_btn("Take", DungeonTheme.BTN_SECONDARY, 80)
	i_btn.pressed.connect(func():
		GameSession.exploration.take_container_item(room)
		GameSession._emit_logs(GameSession.exploration.logs)
		GameSession.state_changed.emit()
		_dismiss_container_popup()
	)
	item_row.add_child(i_btn)


func _dismiss_container_popup() -> void:
	if is_instance_valid(_container_popup):
		_container_popup.queue_free()
	_container_popup = null
	refresh()
