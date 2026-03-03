extends PanelContainer
## Save/Load Panel — two-panel layout: slot list (left) + detail view (right).
## Hosted inside PopupFrame which provides title bar and close button.

signal close_requested()

var _slot_list: ItemList
var _btn_save: Button
var _btn_load: Button
var _btn_delete: Button
var _btn_rename: Button
var _info_label: Label
var _rename_edit: LineEdit

var _detail_panel: VBoxContainer
var _detail_title: Label
var _detail_info: RichTextLabel

var _slots_data: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Two-panel layout
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# --- Left panel: slot list ---
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.40
	split.add_child(left_panel)

	var slots_header := DungeonTheme.make_header(
		"Save Slots", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_LABEL)
	slots_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_panel.add_child(slots_header)

	_slot_list = DungeonTheme.make_item_list(300)
	_slot_list.name = "SlotList"
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_list.item_selected.connect(_on_slot_selected)
	left_panel.add_child(_slot_list)

	# --- Right panel: detail view ---
	_detail_panel = VBoxContainer.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 0.60
	_detail_panel.add_theme_constant_override("separation", 6)
	split.add_child(_detail_panel)

	var detail_bg := PanelContainer.new()
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.06, 0.08, 0.14, 0.9)
	detail_style.border_color = DungeonTheme.BORDER.darkened(0.3)
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(4)
	detail_style.set_content_margin_all(14)
	detail_bg.add_theme_stylebox_override("panel", detail_style)
	detail_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(detail_bg)

	var detail_inner := VBoxContainer.new()
	detail_inner.add_theme_constant_override("separation", 6)
	detail_bg.add_child(detail_inner)

	_detail_title = Label.new()
	_detail_title.name = "DetailTitle"
	_detail_title.text = "Select a slot"
	_detail_title.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	_detail_title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	detail_inner.add_child(_detail_title)

	detail_inner.add_child(DungeonTheme.make_separator())

	_detail_info = RichTextLabel.new()
	_detail_info.name = "DetailInfo"
	_detail_info.bbcode_enabled = true
	_detail_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_info.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_detail_info.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	detail_inner.add_child(_detail_info)

	# Rename row
	var rename_row := HBoxContainer.new()
	rename_row.add_theme_constant_override("separation", 8)
	detail_inner.add_child(rename_row)

	var rename_lbl := Label.new()
	rename_lbl.text = "Name:"
	rename_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	rename_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	rename_row.add_child(rename_lbl)

	_rename_edit = LineEdit.new()
	_rename_edit.name = "RenameEdit"
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_edit.placeholder_text = "Save name..."
	_rename_edit.max_length = 35
	rename_row.add_child(_rename_edit)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	detail_inner.add_child(btn_row)

	_btn_save = DungeonTheme.make_styled_btn("Save", DungeonTheme.TEXT_GREEN, 90)
	_btn_save.name = "BtnSave"
	_btn_save.pressed.connect(_on_save)
	btn_row.add_child(_btn_save)

	_btn_load = DungeonTheme.make_styled_btn("Load", DungeonTheme.TEXT_CYAN, 90)
	_btn_load.name = "BtnLoad"
	_btn_load.pressed.connect(_on_load)
	btn_row.add_child(_btn_load)

	_btn_delete = DungeonTheme.make_styled_btn("Delete", DungeonTheme.TEXT_RED, 90)
	_btn_delete.name = "BtnDelete"
	_btn_delete.pressed.connect(_on_delete)
	btn_row.add_child(_btn_delete)

	_btn_rename = DungeonTheme.make_styled_btn("Rename", DungeonTheme.TEXT_GOLD, 90)
	_btn_rename.name = "BtnRename"
	_btn_rename.pressed.connect(_on_rename)
	btn_row.add_child(_btn_rename)

	# Info label
	_info_label = Label.new()
	_info_label.text = "Select a slot."
	_info_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_info_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_info_label)


func refresh() -> void:
	var saves_dir := GameSession.get_saves_dir()
	_slots_data = SaveEngine.list_slots(saves_dir)
	_slot_list.clear()
	for slot_info in _slots_data:
		if slot_info.get("empty", false):
			_slot_list.add_item("Slot %d: [empty]" % slot_info["slot"])
		else:
			var name_str: String = slot_info.get("save_name", "")
			if name_str.is_empty():
				name_str = "Unnamed"
			_slot_list.add_item("Slot %d: %s" % [slot_info["slot"], name_str])

	var in_combat := GameSession.is_combat_active()
	_btn_save.disabled = in_combat
	if in_combat:
		_btn_save.text = "Cannot Save"
	else:
		_btn_save.text = "Save"

	_refresh_detail()


func _on_slot_selected(_index: int) -> void:
	_refresh_detail()


func _refresh_detail() -> void:
	var sel := _slot_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _slots_data.size():
		_detail_title.text = "Select a slot"
		_detail_info.text = ""
		_btn_load.disabled = true
		_btn_delete.disabled = true
		_btn_rename.disabled = true
		return

	var slot_info: Dictionary = _slots_data[sel[0]]
	var slot_num: int = int(slot_info["slot"])

	if slot_info.get("empty", false):
		_detail_title.text = "Save Slot %d" % slot_num
		_detail_info.text = "[color=#%s](Empty slot)[/color]" % DungeonTheme.TEXT_DIM.to_html(false)
		_btn_load.disabled = true
		_btn_delete.disabled = true
		_btn_rename.disabled = true
		return

	var name_str: String = slot_info.get("save_name", "Unnamed")
	if name_str.is_empty():
		name_str = "Unnamed"

	_detail_title.text = "Save Slot %d" % slot_num

	var gold_hex := DungeonTheme.TEXT_GOLD.to_html(false)
	var cyan_hex := DungeonTheme.TEXT_CYAN.to_html(false)

	var lines: PackedStringArray = []
	lines.append("[b]Name:[/b] [color=#%s]%s[/color]" % [gold_hex, name_str])
	lines.append("[b]Floor:[/b] [color=#%s]%d[/color]" % [cyan_hex, int(slot_info.get("floor", 1))])
	lines.append("[b]HP:[/b] %d" % int(slot_info.get("health", 50)))
	lines.append("[b]Gold:[/b] [color=#%s]%d[/color]" % [gold_hex, int(slot_info.get("gold", 0))])
	var save_time: String = slot_info.get("save_time", "")
	if not save_time.is_empty():
		lines.append("[b]Last Saved:[/b] %s" % save_time)

	_detail_info.text = "\n".join(lines)

	_btn_load.disabled = false
	_btn_delete.disabled = false
	_btn_rename.disabled = false


func _get_selected_slot() -> int:
	var sel := _slot_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _slots_data.size():
		return -1
	return int(_slots_data[sel[0]]["slot"])


func _on_save() -> void:
	var slot := _get_selected_slot()
	if slot < 0:
		_info_label.text = "Select a slot first."
		return
	if GameSession.is_combat_active():
		_info_label.text = "Cannot save during combat!"
		return
	var gs := GameSession.game_state
	var fs := GameSession.get_floor_state()
	if gs == null or fs == null:
		_info_label.text = "No active game to save."
		return
	var save_name := _rename_edit.text.strip_edges()
	if save_name.is_empty():
		save_name = "Save Slot %d" % slot
	var ok := SaveEngine.save_to_slot(gs, fs, GameSession.get_saves_dir(), slot, save_name)
	_info_label.text = "Saved to slot %d!" % slot if ok else "Save failed!"
	GameSession.log_message.emit(_info_label.text)
	if ok:
		GameSession.trace_saved(slot, save_name)
	refresh()


func _on_load() -> void:
	var slot := _get_selected_slot()
	if slot < 0:
		_info_label.text = "Select a slot first."
		return
	var gs := GameSession.game_state
	if gs == null:
		gs = GameState.new()
		GameSession.game_state = gs
	var fs := FloorState.new()
	var ok := SaveEngine.load_from_slot(GameSession.get_saves_dir(), slot, gs, fs)
	if ok:
		GameSession.game_state = gs
		GameSession.rng = DefaultRNG.new()
		GameSession.exploration = ExplorationEngine.new(GameSession.rng, gs, GameSession.rooms_db)
		GameSession.exploration.floor = fs
		GameSession.inventory_engine = InventoryEngine.new(GameSession.rng, gs, GameSession.items_db)
		GameSession.store_engine = StoreEngine.new(gs, GameSession.items_db)
		GameSession.lore_engine = LoreEngine.new(GameSession.rng, gs, GameSession.lore_db)
		GameSession.combat = null
		GameSession.trace.reset(-1, "DefaultRNG")
		GameSession.trace.difficulty = gs.difficulty
		GameSession.trace.record("loaded", {"slot": slot, "name": ""})
		GameSession.trace.set_floor(fs.floor_index)
		GameSession.trace.set_coord(fs.current_pos)
		_info_label.text = "Loaded slot %d!" % slot
		GameSession.log_message.emit(_info_label.text)
		GameSession.state_changed.emit()
	else:
		_info_label.text = "Load failed (slot may be empty)."
	refresh()


func _on_delete() -> void:
	var slot := _get_selected_slot()
	if slot < 0:
		_info_label.text = "Select a slot first."
		return
	var ok := SaveEngine.delete_slot(GameSession.get_saves_dir(), slot)
	_info_label.text = "Deleted slot %d." % slot if ok else "Nothing to delete."
	if ok:
		GameSession.trace_deleted_slot(slot)
	refresh()


func _on_rename() -> void:
	var slot := _get_selected_slot()
	if slot < 0:
		_info_label.text = "Select a slot first."
		return
	var new_name := _rename_edit.text.strip_edges()
	if new_name.is_empty():
		_info_label.text = "Enter a name first."
		return
	var ok := SaveEngine.rename_slot(GameSession.get_saves_dir(), slot, new_name)
	_info_label.text = "Renamed slot %d to '%s'." % [slot, new_name] if ok else "Rename failed."
	if ok:
		GameSession.trace_renamed_slot(slot, new_name)
	refresh()
