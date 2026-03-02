extends PanelContainer
## Inventory Panel — list items with Use / Equip / Unequip / Drop.
## Delegates all logic to InventoryEngine via GameSession.

signal close_requested()

var _item_list: ItemList
var _equip_label: Label
var _btn_use: Button
var _btn_equip: Button
var _btn_unequip: Button
var _btn_drop: Button
var _btn_close: Button
var _info_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(func(): if visible: refresh())


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.1, 0.95)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var title := Label.new()
	title.text = "=== INVENTORY ==="
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	# Equipment slots
	_equip_label = Label.new()
	_equip_label.text = "Equipment: ---"
	_equip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_equip_label)

	# Item list
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.custom_minimum_size = Vector2(0, 200)
	root.add_child(_item_list)

	_info_label = Label.new()
	_info_label.text = ""
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_info_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_btn_use = Button.new()
	_btn_use.text = "Use"
	_btn_use.pressed.connect(_on_use)
	btn_row.add_child(_btn_use)

	_btn_equip = Button.new()
	_btn_equip.text = "Equip"
	_btn_equip.pressed.connect(_on_equip)
	btn_row.add_child(_btn_equip)

	_btn_unequip = Button.new()
	_btn_unequip.text = "Unequip"
	_btn_unequip.pressed.connect(_on_unequip)
	btn_row.add_child(_btn_unequip)

	_btn_drop = Button.new()
	_btn_drop.text = "Drop"
	_btn_drop.pressed.connect(_on_drop)
	btn_row.add_child(_btn_drop)

	_btn_close = Button.new()
	_btn_close.text = "Close"
	_btn_close.pressed.connect(func(): close_requested.emit(); visible = false)
	btn_row.add_child(_btn_close)


func refresh() -> void:
	var gs := GameSession.game_state
	if gs == null:
		return

	# Equipment display
	var eq := gs.equipped_items
	var eq_lines: PackedStringArray = []
	for slot in eq:
		var item_name: String = eq[slot]
		if item_name.is_empty():
			eq_lines.append("%s: (empty)" % slot)
		else:
			var dur := GameSession.inventory_engine.get_durability_percent(item_name)
			eq_lines.append("%s: %s [%d%%]" % [slot, item_name, dur])
	_equip_label.text = "Equipment:\n" + "\n".join(eq_lines)

	# Inventory list
	_item_list.clear()
	for item_name in gs.inventory:
		_item_list.add_item(item_name)

	# Active buffs
	var statuses: Array = gs.flags.get("statuses", [])
	if not statuses.is_empty():
		_info_label.text = "Active effects: %s" % ", ".join(statuses)
	else:
		_info_label.text = "Inventory: %d / %d" % [gs.inventory.size(), gs.max_inventory]


func _get_selected_index() -> int:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return -1
	return sel[0]


func _on_use() -> void:
	var idx := _get_selected_index()
	if idx < 0:
		return
	var result := GameSession.inventory_engine.use_item(idx)
	GameSession._emit_logs(GameSession.inventory_engine.logs)
	GameSession.state_changed.emit()
	refresh()


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
			GameSession._emit_logs(GameSession.inventory_engine.logs)
			GameSession.state_changed.emit()
			refresh()
			return
	GameSession.log_message.emit("Select an equipped item to unequip.")


func _on_drop() -> void:
	var idx := _get_selected_index()
	if idx < 0:
		return
	var dropped := GameSession.inventory_engine.remove_item_at(idx)
	if not dropped.is_empty():
		GameSession.log_message.emit("Dropped %s." % dropped)
	GameSession.state_changed.emit()
	refresh()
