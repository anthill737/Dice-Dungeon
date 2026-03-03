extends PanelContainer
## Save/Load Panel — 10 slots with Save, Load, Delete, Rename.
## All persistence delegated to SaveEngine via GameSession.

signal close_requested()

var _slot_list: ItemList
var _btn_save: Button
var _btn_load: Button
var _btn_delete: Button
var _btn_rename: Button
var _btn_close: Button
var _info_label: Label
var _rename_edit: LineEdit

var _slots_data: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := DungeonTheme.make_panel_bg(
		Color(0.04, 0.06, 0.12, 0.97), DungeonTheme.TEXT_BLUE)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := DungeonTheme.make_header(
		"💾 SAVE / LOAD", DungeonTheme.TEXT_BLUE, DungeonTheme.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_btn_close = DungeonTheme.make_styled_btn("✕ Close", DungeonTheme.TEXT_SECONDARY, 80)
	_btn_close.pressed.connect(func(): close_requested.emit())
	header.add_child(_btn_close)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.TEXT_BLUE))

	_slot_list = DungeonTheme.make_item_list(300)
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_slot_list)

	_info_label = Label.new()
	_info_label.text = "Select a slot."
	_info_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_info_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_info_label)

	var rename_row := HBoxContainer.new()
	rename_row.add_theme_constant_override("separation", 8)
	root.add_child(rename_row)

	var rename_lbl := Label.new()
	rename_lbl.text = "Name:"
	rename_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	rename_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	rename_row.add_child(rename_lbl)

	_rename_edit = LineEdit.new()
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_edit.placeholder_text = "Save name..."
	rename_row.add_child(_rename_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	root.add_child(btn_row)

	_btn_save = DungeonTheme.make_styled_btn("Save", DungeonTheme.TEXT_GREEN)
	_btn_save.pressed.connect(_on_save)
	btn_row.add_child(_btn_save)

	_btn_load = DungeonTheme.make_styled_btn("Load", DungeonTheme.TEXT_CYAN)
	_btn_load.pressed.connect(_on_load)
	btn_row.add_child(_btn_load)

	_btn_delete = DungeonTheme.make_styled_btn("Delete", DungeonTheme.TEXT_RED)
	_btn_delete.pressed.connect(_on_delete)
	btn_row.add_child(_btn_delete)

	_btn_rename = DungeonTheme.make_styled_btn("Rename", DungeonTheme.TEXT_GOLD)
	_btn_rename.pressed.connect(_on_rename)
	btn_row.add_child(_btn_rename)


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
			_slot_list.add_item("Slot %d: %s (Floor %d, HP %d, Gold %d) — %s" % [
				slot_info["slot"], name_str,
				int(slot_info.get("floor", 1)),
				int(slot_info.get("health", 50)),
				int(slot_info.get("gold", 0)),
				slot_info.get("save_time", ""),
			])


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
	refresh()
