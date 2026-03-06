extends PanelContainer
## Ground Items Panel — shows items on ground, containers, and gold.
## Ported from Python inventory_display.py show_ground_items flow.
## Containers show "Search" button; locked ones show "Use Lockpick".
## Includes Take All for multiple pickable items.

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

	var has_container := not room.ground_container.is_empty() and not room.container_searched
	var has_gold := room.ground_gold > 0
	var has_items := not room.ground_items.is_empty()
	var has_uncollected := not room.uncollected_items.is_empty()
	var has_dropped := not room.dropped_items.is_empty()
	var has_container_loot := room.container_searched and (room.container_gold > 0 or not room.container_item.is_empty())

	if has_container or room.container_locked:
		_add_container_section(room)

	if has_gold:
		_add_gold_section(room)

	if has_items:
		_add_items_section(room, "Items:", room.ground_items, "_pickup_ground_item")

	if has_uncollected:
		_add_items_section(room, "Left Behind:", room.uncollected_items, "_pickup_uncollected_item")

	if has_dropped:
		_add_items_section(room, "Dropped:", room.dropped_items, "_pickup_dropped_item")

	var pickable_count := (1 if has_gold else 0) + room.ground_items.size() + room.uncollected_items.size() + room.dropped_items.size()
	_btn_take_all.visible = pickable_count >= 2


func _add_container_section(room: RoomState) -> void:
	var header := Label.new()
	header.text = "Container:"
	header.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	header.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	_content_vbox.add_child(header)

	var container_db: Dictionary = {}
	var cm := ContentManager.new()
	cm.load_all()
	container_db = cm.get_container_db()

	var cname: String = room.ground_container
	var cdef: Dictionary = container_db.get(cname, {})
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


func _add_items_section(room: RoomState, section_title: String, items: Array, callback_name: String) -> void:
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
	var desc: String = item_def.get("desc", "")
	if not desc.is_empty():
		control.tooltip_text = "%s\n%s" % [item_name, desc]
	else:
		control.tooltip_text = item_name


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
		_show_container_contents(room, result)
	GameSession.state_changed.emit()
	refresh()


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
			_show_container_contents(room, search_result)
	GameSession.state_changed.emit()
	refresh()


func _on_take_all() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return

	if room.ground_gold > 0:
		GameSession.pickup_ground_gold()

	var picked := 0
	while not room.ground_items.is_empty():
		var result := GameSession.pickup_ground_item(0)
		if result.is_empty():
			GameSession.log_message.emit("Inventory full! Cannot pick up remaining items.")
			break
		picked += 1

	while not room.uncollected_items.is_empty():
		var item_name: String = room.uncollected_items[0]
		if GameSession.inventory_engine.add_item_to_inventory(item_name, "ground"):
			room.uncollected_items.remove_at(0)
			picked += 1
		else:
			GameSession.log_message.emit("Inventory full! Cannot pick up remaining items.")
			break

	while not room.dropped_items.is_empty():
		var item_name: String = room.dropped_items[0]
		if GameSession.inventory_engine.add_item_to_inventory(item_name, "ground"):
			room.dropped_items.remove_at(0)
			picked += 1
		else:
			GameSession.log_message.emit("Inventory full! Cannot pick up remaining items.")
			break

	if picked > 0:
		GameSession.log_message.emit("Collected %d item(s)." % picked)

	GameSession.state_changed.emit()
	refresh()


func _show_container_contents(room: RoomState, result: Dictionary) -> void:
	if is_instance_valid(_container_popup):
		_container_popup.queue_free()

	var gold: int = int(result.get("gold", 0))
	var item: String = str(result.get("item", ""))
	var cname: String = room.ground_container

	var container_db: Dictionary = {}
	var cm := ContentManager.new()
	cm.load_all()
	container_db = cm.get_container_db()
	var cdef: Dictionary = container_db.get(cname, {})
	var cdesc: String = cdef.get("description", "")

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var parent := get_parent()
	while parent != null and not (parent is Control and parent.get_parent() == parent.get_tree().root):
		parent = parent.get_parent()
	if parent == null:
		parent = self
	(parent as Control).add_child(overlay)
	_container_popup = overlay

	var panel := PanelContainer.new()
	var style := DungeonTheme.make_panel_bg(DungeonTheme.BG_PRIMARY, DungeonTheme.BORDER_GOLD)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.2
	panel.anchor_top = 0.15
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.85
	overlay.add_child(panel)

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
		empty_lbl.text = "Nothing of value..."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
		empty_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		c_vbox.add_child(empty_lbl)

	if gold > 0:
		var gold_row := HBoxContainer.new()
		gold_row.add_theme_constant_override("separation", 8)
		c_vbox.add_child(gold_row)
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
			if room.container_gold > 0:
				GameSession.game_state.gold += room.container_gold
				GameSession.game_state.total_gold_earned += room.container_gold
				GameSession.log_message.emit("Collected %d gold!" % room.container_gold)
				room.container_gold = 0
				GameSession.state_changed.emit()
				_refresh_container_popup(overlay, room, item)
		)
		gold_row.add_child(g_btn)

	if not item.is_empty():
		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 8)
		c_vbox.add_child(item_row)
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
			if not room.container_item.is_empty():
				if GameSession.inventory_engine.add_item_to_inventory(room.container_item, "container"):
					GameSession.log_message.emit("Picked up %s!" % room.container_item)
					room.container_item = ""
				else:
					room.uncollected_items.append(room.container_item)
					GameSession.log_message.emit("Inventory full! %s left behind." % room.container_item)
					room.container_item = ""
				GameSession.state_changed.emit()
				_refresh_container_popup(overlay, room, "")
		)
		item_row.add_child(i_btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	if gold > 0 and not item.is_empty():
		var take_all_btn := DungeonTheme.make_styled_btn("Take All", DungeonTheme.TEXT_GREEN, 120)
		take_all_btn.custom_minimum_size.y = 36
		take_all_btn.pressed.connect(func():
			if room.container_gold > 0:
				GameSession.game_state.gold += room.container_gold
				GameSession.game_state.total_gold_earned += room.container_gold
				GameSession.log_message.emit("Collected %d gold!" % room.container_gold)
				room.container_gold = 0
			if not room.container_item.is_empty():
				if GameSession.inventory_engine.add_item_to_inventory(room.container_item, "container"):
					GameSession.log_message.emit("Picked up %s!" % room.container_item)
				else:
					room.uncollected_items.append(room.container_item)
					GameSession.log_message.emit("Inventory full! %s left behind." % room.container_item)
				room.container_item = ""
			GameSession.state_changed.emit()
			overlay.queue_free()
			_container_popup = null
			refresh()
		)
		footer.add_child(take_all_btn)

	var close_btn := DungeonTheme.make_styled_btn("Close", DungeonTheme.BTN_SECONDARY, 120)
	close_btn.custom_minimum_size.y = 36
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_container_popup = null
		refresh()
	)
	footer.add_child(close_btn)


func _refresh_container_popup(overlay: Control, _room: RoomState, _remaining_item: String) -> void:
	overlay.queue_free()
	_container_popup = null
	refresh()
