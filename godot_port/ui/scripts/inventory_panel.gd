extends PanelContainer
## Inventory Panel — items list with Use / Read / Equip / Unequip / Drop.
## Hosted inside PopupFrame which provides title bar and close button.
## Delegates all logic to InventoryEngine via GameSession.

signal close_requested()

var _item_list: ItemList
var _equip_label: RichTextLabel
var _slots_label: Label
var _hint_label: Label
var _btn_use: Button
var _btn_read: Button
var _btn_equip: Button
var _btn_unequip: Button
var _btn_drop: Button
var _info_label: Label

var _search_box: LineEdit
var _lore_popup: PanelContainer
var _inv_index_map: Array[int] = []

const UNEQUIP_COLOR := Color(0.95, 0.61, 0.07)  # #f39c12


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(func(): if visible: refresh())


func _exit_tree() -> void:
	if is_instance_valid(_lore_popup):
		_lore_popup.queue_free()
		_lore_popup = null


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Slots counter at top
	_slots_label = Label.new()
	_slots_label.name = "SlotsLabel"
	_slots_label.text = "Slots: 0/20"
	_slots_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_slots_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_slots_label)

	# Equipment summary
	_equip_label = RichTextLabel.new()
	_equip_label.name = "EquipmentSummary"
	_equip_label.bbcode_enabled = true
	_equip_label.fit_content = true
	_equip_label.scroll_active = false
	_equip_label.custom_minimum_size = Vector2(0, 70)
	_equip_label.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_equip_label.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	root.add_child(_equip_label)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.TEXT_CYAN))

	# Search box
	_search_box = LineEdit.new()
	_search_box.name = "SearchBox"
	_search_box.placeholder_text = "Search inventory..."
	_search_box.clear_button_enabled = true
	_search_box.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_search_box.text_changed.connect(func(_t): refresh())
	root.add_child(_search_box)

	# Hint text
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "(Select an item for details)"
	_hint_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_hint_label.add_theme_color_override("font_color", DungeonTheme.TEXT_DIM)
	root.add_child(_hint_label)

	# Item list — scrollable region
	_item_list = DungeonTheme.make_item_list(200)
	_item_list.name = "ItemList"
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	root.add_child(_item_list)

	# Status / active effects info
	_info_label = Label.new()
	_info_label.text = ""
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_info_label.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	root.add_child(_info_label)

	# Action buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	root.add_child(btn_row)

	_btn_use = DungeonTheme.make_styled_btn("Use", DungeonTheme.TEXT_GREEN, 80)
	_btn_use.name = "BtnUse"
	_btn_use.pressed.connect(_on_use)
	btn_row.add_child(_btn_use)

	_btn_read = DungeonTheme.make_styled_btn("Read", DungeonTheme.TEXT_BLUE, 80)
	_btn_read.name = "BtnRead"
	_btn_read.pressed.connect(_on_read)
	btn_row.add_child(_btn_read)

	_btn_equip = DungeonTheme.make_styled_btn("Equip", DungeonTheme.TEXT_CYAN, 80)
	_btn_equip.name = "BtnEquip"
	_btn_equip.pressed.connect(_on_equip)
	btn_row.add_child(_btn_equip)

	_btn_unequip = DungeonTheme.make_styled_btn("Unequip", UNEQUIP_COLOR, 90)
	_btn_unequip.name = "BtnUnequip"
	_btn_unequip.pressed.connect(_on_unequip)
	btn_row.add_child(_btn_unequip)

	_btn_drop = DungeonTheme.make_styled_btn("Drop", DungeonTheme.TEXT_RED, 80)
	_btn_drop.name = "BtnDrop"
	_btn_drop.pressed.connect(_on_drop)
	btn_row.add_child(_btn_drop)


func refresh() -> void:
	var gs := GameSession.game_state
	if gs == null:
		return

	_slots_label.text = "Slots: %d/%d" % [gs.inventory.size(), gs.max_inventory]

	var eq := gs.equipped_items
	var eq_lines: PackedStringArray = ["[b]Equipment:[/b]"]
	for slot in eq:
		var item_name: String = eq[slot]
		if item_name.is_empty():
			eq_lines.append("  %s: [color=#%s](empty)[/color]" % [slot.capitalize(), DungeonTheme.TEXT_DIM.to_html(false)])
		else:
			var dur := GameSession.inventory_engine.get_durability_percent(item_name)
			eq_lines.append("  %s: [color=#%s]%s[/color] [%d%%]" % [slot.capitalize(), DungeonTheme.TEXT_CYAN.to_html(false), item_name, dur])
	_equip_label.text = "\n".join(eq_lines)

	_item_list.clear()
	_inv_index_map.clear()
	var search_filter := _search_box.text.strip_edges().to_lower() if _search_box != null else ""
	var seen: Dictionary = {}
	for i in gs.inventory.size():
		var item_name: String = gs.inventory[i]
		var normalized: String = item_name.split(" #")[0] if " #" in item_name else item_name
		if seen.has(normalized):
			continue
		seen[normalized] = true
		if not search_filter.is_empty() and not normalized.to_lower().contains(search_filter):
			continue
		_inv_index_map.append(i)

		var count := 0
		for inv_item in gs.inventory:
			var norm: String = inv_item.split(" #")[0] if " #" in inv_item else inv_item
			if norm == normalized:
				count += 1
		var display_text := item_name
		if count > 1:
			display_text += " ×%d" % count

		for slot in gs.equipped_items:
			if gs.equipped_items[slot] == item_name:
				display_text += " [EQUIPPED]"
				break

		if GameSession.inventory_engine != null:
			var item_def := GameSession.inventory_engine.get_item_def(item_name)
			if item_def.get("slot", "") != "":
				var dur := GameSession.inventory_engine.get_durability_percent(item_name)
				display_text += " [%d%%]" % dur

		var row_idx := _item_list.item_count
		var item_icon_tex = GameSession.assets.get_item_icon(item_name, 32) if GameSession.assets != null else null
		if item_icon_tex != null:
			_item_list.add_item(display_text, item_icon_tex)
		else:
			_item_list.add_item(display_text)

		if GameSession.inventory_engine != null:
			var item_def := GameSession.inventory_engine.get_item_def(item_name)
			_item_list.set_item_tooltip(row_idx, TooltipFormatter.format(item_name, item_def))
			_item_list.set_item_tooltip_enabled(row_idx, true)

	var statuses: Array = gs.flags.get("statuses", [])
	if not statuses.is_empty():
		_info_label.text = "Active effects: %s" % ", ".join(statuses)
	else:
		_info_label.text = ""

	_update_button_visibility()


func _on_item_selected(_index: int) -> void:
	_update_button_visibility()


func _update_button_visibility() -> void:
	var idx := _get_selected_index()
	var gs := GameSession.game_state
	if gs == null or idx < 0 or idx >= gs.inventory.size():
		_btn_use.visible = false
		_btn_read.visible = false
		_btn_equip.visible = false
		_btn_unequip.visible = false
		_btn_drop.visible = true
		_btn_drop.disabled = true
		return

	var item_name: String = gs.inventory[idx]
	var item_def: Dictionary = {}
	if GameSession.inventory_engine != null:
		item_def = GameSession.inventory_engine.get_item_def(item_name)

	var item_type: String = item_def.get("type", "")
	var item_slot: String = item_def.get("slot", "")
	var is_equipped := false
	for slot in gs.equipped_items:
		if gs.equipped_items[slot] == item_name:
			is_equipped = true
			break

	var usable_types := ["heal", "buff", "shield", "cleanse", "token", "tool", "repair", "consumable"]
	_btn_use.visible = item_type in usable_types
	_btn_read.visible = item_type in ["lore", "readable_lore"]
	_btn_equip.visible = not item_slot.is_empty() and not is_equipped
	_btn_unequip.visible = is_equipped
	_btn_drop.visible = true
	_btn_drop.disabled = is_equipped


func _get_selected_index() -> int:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return -1
	var display_idx: int = sel[0]
	if display_idx < 0 or display_idx >= _inv_index_map.size():
		return -1
	return _inv_index_map[display_idx]


func _on_use() -> void:
	var idx := _get_selected_index()
	if idx < 0:
		return
	var gs := GameSession.game_state
	var used_name: String = gs.inventory[idx] if idx < gs.inventory.size() else ""
	var before_count: int = gs.inventory.count(used_name) if not used_name.is_empty() else 0
	var result := GameSession.inventory_engine.use_item(idx)
	if result.get("ok", false) and not used_name.is_empty():
		GameSession.trace_item_used(used_name, str(result.get("type", "")))
		var after_count: int = gs.inventory.count(used_name)
		if after_count != before_count:
			GameSession.trace_inventory_qty_changed(used_name, before_count, after_count, "use")
	if result.get("type", "") == "readable_lore":
		_handle_readable_lore(result)
	GameSession._emit_logs(GameSession.inventory_engine.logs)
	GameSession.state_changed.emit()
	refresh()


func _on_read() -> void:
	var idx := _get_selected_index()
	if idx < 0:
		return
	var gs := GameSession.game_state
	var item_name: String = gs.inventory[idx]
	var item_def := GameSession.inventory_engine.get_item_def(item_name)
	var item_type: String = item_def.get("type", "")

	if item_type == "lore":
		var desc: String = item_def.get("desc", "An old document.")
		GameSession.log_message.emit("%s: %s" % [item_name, desc])
	elif item_type == "readable_lore":
		var result := GameSession.lore_engine.read_lore_item(item_name, idx)
		GameSession._emit_logs(GameSession.lore_engine.logs)
		if result.get("ok", false):
			_show_lore_popup(result["entry"])
		GameSession.state_changed.emit()
	else:
		GameSession.log_message.emit("Nothing to read on %s." % item_name)


func _handle_readable_lore(use_result: Dictionary) -> void:
	var item_name: String = use_result.get("item_name", "")
	var idx: int = int(use_result.get("idx", 0))
	if GameSession.lore_engine == null:
		return
	var result := GameSession.lore_engine.read_lore_item(item_name, idx)
	GameSession._emit_logs(GameSession.lore_engine.logs)
	if result.get("ok", false):
		_show_lore_popup(result["entry"])


func _show_lore_popup(entry: Dictionary) -> void:
	if _lore_popup != null:
		_lore_popup.queue_free()

	_lore_popup = PanelContainer.new()
	var style := DungeonTheme.make_panel_bg(
		Color(0.05, 0.07, 0.1, 0.98), DungeonTheme.TEXT_GOLD)
	_lore_popup.add_theme_stylebox_override("panel", style)
	_lore_popup.set_anchors_preset(Control.PRESET_CENTER)
	_lore_popup.anchor_left = 0.1
	_lore_popup.anchor_top = 0.1
	_lore_popup.anchor_right = 0.9
	_lore_popup.anchor_bottom = 0.9

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_lore_popup.add_child(vbox)

	var popup_title := DungeonTheme.make_header(
		entry.get("title", ""), DungeonTheme.TEXT_GOLD, 18)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(popup_title)

	var sub: String = str(entry.get("subtitle", ""))
	if not sub.is_empty():
		var popup_sub := Label.new()
		popup_sub.text = sub
		popup_sub.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
		vbox.add_child(popup_sub)

	var floor_lbl := Label.new()
	floor_lbl.text = "Discovered on Floor %s" % str(entry.get("floor_found", "?"))
	floor_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_DIM)
	vbox.add_child(floor_lbl)

	vbox.add_child(DungeonTheme.make_separator())

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.text = str(entry.get("content", ""))
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	vbox.add_child(content)

	var close_btn := DungeonTheme.make_styled_btn("Close", DungeonTheme.TEXT_SECONDARY)
	close_btn.pressed.connect(func():
		if _lore_popup != null:
			_lore_popup.queue_free()
			_lore_popup = null
	)
	vbox.add_child(close_btn)

	get_parent().add_child(_lore_popup)


func _on_equip() -> void:
	var idx := _get_selected_index()
	if idx < 0:
		return
	var gs := GameSession.game_state
	var item_name: String = gs.inventory[idx]
	var item_def := GameSession.inventory_engine.get_item_def(item_name)
	var slot: String = item_def.get("slot", "")
	if slot.is_empty():
		GameSession.log_message.emit("%s is not equippable." % item_name)
		return
	var result := GameSession.inventory_engine.equip_item(item_name, slot)
	if result.get("ok", false):
		GameSession.trace_item_equipped(item_name, slot)
	GameSession._emit_logs(GameSession.inventory_engine.logs)
	GameSession.state_changed.emit()
	refresh()


func _on_unequip() -> void:
	var gs := GameSession.game_state
	for slot in gs.equipped_items:
		var item_name: String = gs.equipped_items[slot]
		if item_name.is_empty():
			continue
		var sel := _get_selected_index()
		if sel >= 0 and sel < gs.inventory.size() and gs.inventory[sel] == item_name:
			GameSession.inventory_engine.unequip_item(slot)
			GameSession.trace_item_unequipped(item_name, slot)
			GameSession._emit_logs(GameSession.inventory_engine.logs)
			GameSession.state_changed.emit()
			refresh()
			return
	GameSession.log_message.emit("Select an equipped item to unequip.")


func _on_drop() -> void:
	var idx := _get_selected_index()
	if idx < 0:
		return
	var gs := GameSession.game_state
	var drop_name: String = gs.inventory[idx] if idx < gs.inventory.size() else ""
	var before_count: int = gs.inventory.count(drop_name) if not drop_name.is_empty() else 0
	var dropped := GameSession.inventory_engine.remove_item_at(idx)
	if not dropped.is_empty():
		GameSession.trace_item_dropped(dropped)
		var after_count: int = gs.inventory.count(dropped)
		GameSession.trace_inventory_qty_changed(dropped, before_count, after_count, "drop")
		GameSession.log_message.emit("Dropped %s." % dropped)
	GameSession.state_changed.emit()
	refresh()
