extends PanelContainer
## Store Panel — buy/sell interface with quantity selection and search.
## All transactions delegated to StoreEngine via GameSession.

signal close_requested()

var _buy_list: ItemList
var _sell_list: ItemList
var _gold_label: Label
var _btn_buy: Button
var _btn_sell: Button
var _btn_close: Button
var _info_label: Label
var _buy_search: LineEdit
var _sell_search: LineEdit

var _qty_label: Label
var _qty_spinbox: SpinBox
var _qty_container: HBoxContainer

var _store_items: Array = []
var _sell_items: Array = []
var _filtered_buy_indices: Array[int] = []
var _filtered_sell_indices: Array[int] = []
var _active_mode: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := DungeonTheme.make_panel_bg(
		Color(0.10, 0.08, 0.04, 0.97), DungeonTheme.TEXT_GOLD)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := DungeonTheme.make_header(
		"🏪 STORE", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_btn_close = DungeonTheme.make_styled_btn("✕ Close", DungeonTheme.TEXT_SECONDARY, 80)
	_btn_close.pressed.connect(func(): close_requested.emit())
	header.add_child(_btn_close)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.TEXT_GOLD))

	_gold_label = Label.new()
	_gold_label.text = "◆ Gold: 0"
	_gold_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_gold_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	root.add_child(_gold_label)

	# Buy / Sell columns
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	root.add_child(hbox)

	var buy_vbox := VBoxContainer.new()
	buy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(buy_vbox)

	var buy_header := DungeonTheme.make_header(
		"Buy", DungeonTheme.TEXT_GREEN, DungeonTheme.FONT_LABEL)
	buy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	buy_vbox.add_child(buy_header)

	_buy_search = LineEdit.new()
	_buy_search.placeholder_text = "Search..."
	_buy_search.clear_button_enabled = true
	_buy_search.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_buy_search.text_changed.connect(_on_buy_search_changed)
	buy_vbox.add_child(_buy_search)

	_buy_list = DungeonTheme.make_item_list(150)
	_buy_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buy_list.item_selected.connect(_on_buy_item_selected)
	buy_vbox.add_child(_buy_list)

	var sell_vbox := VBoxContainer.new()
	sell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(sell_vbox)

	var sell_header := DungeonTheme.make_header(
		"Sell", DungeonTheme.TEXT_RED, DungeonTheme.FONT_LABEL)
	sell_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sell_vbox.add_child(sell_header)

	_sell_search = LineEdit.new()
	_sell_search.placeholder_text = "Search..."
	_sell_search.clear_button_enabled = true
	_sell_search.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_sell_search.text_changed.connect(_on_sell_search_changed)
	sell_vbox.add_child(_sell_search)

	_sell_list = DungeonTheme.make_item_list(150)
	_sell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_list.item_selected.connect(_on_sell_item_selected)
	sell_vbox.add_child(_sell_list)

	_info_label = Label.new()
	_info_label.text = ""
	_info_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_info_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_info_label)

	# Quantity selector row
	_qty_container = HBoxContainer.new()
	_qty_container.add_theme_constant_override("separation", 8)
	_qty_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_qty_container)

	_qty_label = Label.new()
	_qty_label.text = "Qty:"
	_qty_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_qty_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	_qty_container.add_child(_qty_label)

	_qty_spinbox = SpinBox.new()
	_qty_spinbox.min_value = 1
	_qty_spinbox.max_value = 1
	_qty_spinbox.value = 1
	_qty_spinbox.step = 1
	_qty_spinbox.custom_minimum_size = Vector2(100, 0)
	_qty_spinbox.value_changed.connect(_on_qty_changed)
	_qty_container.add_child(_qty_spinbox)

	_qty_container.visible = false

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_btn_buy = DungeonTheme.make_styled_btn("Buy", DungeonTheme.TEXT_GREEN)
	_btn_buy.pressed.connect(_on_buy)
	btn_row.add_child(_btn_buy)

	_btn_sell = DungeonTheme.make_styled_btn("Sell", DungeonTheme.TEXT_RED)
	_btn_sell.pressed.connect(_on_sell)
	btn_row.add_child(_btn_sell)


func refresh() -> void:
	var gs := GameSession.game_state
	if gs == null:
		return
	GameSession.trace_store_entered()

	_gold_label.text = "◆ Gold: %d" % gs.gold

	_store_items = GameSession.store_engine.generate_store_inventory()
	_rebuild_buy_list()

	_sell_items = []
	var seen: Dictionary = {}
	for item_name in gs.inventory:
		if seen.has(item_name):
			continue
		seen[item_name] = true
		var count: int = gs.inventory.count(item_name)
		var sell_price := GameSession.store_engine.calculate_sell_price(item_name)
		_sell_items.append({"name": item_name, "price": sell_price, "count": count})
	_rebuild_sell_list()

	_qty_container.visible = false
	_active_mode = ""


func _rebuild_buy_list() -> void:
	_buy_list.clear()
	_filtered_buy_indices.clear()
	var filter := _buy_search.text.strip_edges().to_lower() if _buy_search != null else ""
	for i in _store_items.size():
		var item_name: String = _store_items[i][0]
		if not filter.is_empty() and not item_name.to_lower().contains(filter):
			continue
		var price: int = int(_store_items[i][1])
		_filtered_buy_indices.append(i)
		var buy_icon = GameSession.assets.get_item_icon(item_name, 24) if GameSession.assets != null else null
		if buy_icon != null:
			_buy_list.add_item("%s — %d gold" % [item_name, price], buy_icon)
		else:
			_buy_list.add_item("%s — %d gold" % [item_name, price])


func _rebuild_sell_list() -> void:
	_sell_list.clear()
	_filtered_sell_indices.clear()
	var filter := _sell_search.text.strip_edges().to_lower() if _sell_search != null else ""
	for i in _sell_items.size():
		var entry: Dictionary = _sell_items[i]
		var item_name: String = entry["name"]
		if not filter.is_empty() and not item_name.to_lower().contains(filter):
			continue
		_filtered_sell_indices.append(i)
		var sell_price: int = int(entry["price"])
		var count: int = int(entry["count"])
		var label := "%s — %d gold" % [item_name, sell_price]
		if count > 1:
			label = "%s ×%d — %d gold" % [item_name, count, sell_price]
		var sell_icon = GameSession.assets.get_item_icon(item_name, 24) if GameSession.assets != null else null
		if sell_icon != null:
			_sell_list.add_item(label, sell_icon)
		else:
			_sell_list.add_item(label)


func _on_buy_search_changed(_text: String) -> void:
	_rebuild_buy_list()
	_qty_container.visible = false
	_active_mode = ""


func _on_sell_search_changed(_text: String) -> void:
	_rebuild_sell_list()
	_qty_container.visible = false
	_active_mode = ""


func _on_buy_item_selected(display_idx: int) -> void:
	_sell_list.deselect_all()
	_active_mode = "buy"
	if display_idx < 0 or display_idx >= _filtered_buy_indices.size():
		_qty_container.visible = false
		return
	var real_idx: int = _filtered_buy_indices[display_idx]
	var item_name: String = _store_items[real_idx][0]
	var price: int = int(_store_items[real_idx][1])

	var item_def: Dictionary = GameSession.store_engine.items_db.get(item_name, {})
	var item_type: String = item_def.get("type", "")
	var is_consumable: bool = item_type not in ["upgrade", "equipment"]

	if is_consumable:
		var gs := GameSession.game_state
		var max_affordable: int = gs.gold / price if price > 0 else 0
		var space: int = gs.max_inventory - gs.inventory.size()
		var max_qty: int = mini(max_affordable, space)
		if max_qty > 1:
			_qty_spinbox.max_value = max_qty
			_qty_spinbox.value = 1
			_qty_container.visible = true
			_info_label.text = "%s — %d gold each (max %d)" % [item_name, price, max_qty]
			return

	_qty_container.visible = false
	_info_label.text = "%s — %d gold" % [item_name, price]


func _on_sell_item_selected(display_idx: int) -> void:
	_buy_list.deselect_all()
	_active_mode = "sell"
	if display_idx < 0 or display_idx >= _filtered_sell_indices.size():
		_qty_container.visible = false
		return
	var real_idx: int = _filtered_sell_indices[display_idx]
	var entry: Dictionary = _sell_items[real_idx]
	var count: int = int(entry["count"])

	if count > 1:
		_qty_spinbox.max_value = count
		_qty_spinbox.value = 1
		_qty_container.visible = true
		_info_label.text = "%s — %d gold each (have %d)" % [entry["name"], int(entry["price"]), count]
	else:
		_qty_container.visible = false
		_info_label.text = "%s — %d gold" % [entry["name"], int(entry["price"])]


func _on_qty_changed(_value: float) -> void:
	if _active_mode == "buy":
		var sel := _buy_list.get_selected_items()
		if sel.is_empty():
			return
		var display_idx: int = sel[0]
		if display_idx >= _filtered_buy_indices.size():
			return
		var real_idx: int = _filtered_buy_indices[display_idx]
		var price: int = int(_store_items[real_idx][1])
		var total: int = price * int(_qty_spinbox.value)
		_info_label.text = "%s — %d × %d = %d gold" % [_store_items[real_idx][0], int(_qty_spinbox.value), price, total]
	elif _active_mode == "sell":
		var sel := _sell_list.get_selected_items()
		if sel.is_empty():
			return
		var display_idx: int = sel[0]
		if display_idx >= _filtered_sell_indices.size():
			return
		var real_idx: int = _filtered_sell_indices[display_idx]
		var entry: Dictionary = _sell_items[real_idx]
		var price: int = int(entry["price"])
		var total: int = price * int(_qty_spinbox.value)
		_info_label.text = "%s — %d × %d = %d gold" % [entry["name"], int(_qty_spinbox.value), price, total]


func _on_buy() -> void:
	var sel := _buy_list.get_selected_items()
	if sel.is_empty():
		return
	var display_idx: int = sel[0]
	if display_idx >= _filtered_buy_indices.size():
		return
	var real_idx: int = _filtered_buy_indices[display_idx]
	if real_idx >= _store_items.size():
		return
	var item_name: String = _store_items[real_idx][0]
	var price: int = int(_store_items[real_idx][1])
	var quantity: int = int(_qty_spinbox.value) if _qty_container.visible and _active_mode == "buy" else 1

	var before_count: int = GameSession.game_state.inventory.count(item_name)
	var result := GameSession.store_engine.buy_item(item_name, price, quantity)
	GameSession._emit_logs(GameSession.store_engine.logs)
	if result.get("ok", false):
		if quantity > 1:
			_info_label.text = "Purchased %d× %s!" % [quantity, item_name]
		else:
			_info_label.text = "Purchased %s!" % item_name
		var rtype: String = str(result.get("type", ""))
		if rtype == "upgrade":
			GameSession.trace_upgrade_bought(item_name, price,
				result.get("max_hp_bonus", result.get("damage_bonus", result.get("crit_bonus", ""))))
		else:
			GameSession.trace_store_bought(item_name, price * quantity)
		var after_count: int = GameSession.game_state.inventory.count(item_name)
		if after_count != before_count:
			GameSession.trace_inventory_qty_changed(item_name, before_count, after_count, "buy")
	else:
		_info_label.text = "Cannot buy: %s" % result.get("reason", "unknown")
	GameSession.state_changed.emit()
	refresh()


func _on_sell() -> void:
	var sel := _sell_list.get_selected_items()
	if sel.is_empty():
		return
	var display_idx: int = sel[0]
	if display_idx >= _filtered_sell_indices.size():
		return
	var real_idx: int = _filtered_sell_indices[display_idx]
	if real_idx >= _sell_items.size():
		return
	var entry: Dictionary = _sell_items[real_idx]
	var item_name: String = entry["name"]
	var price: int = int(entry["price"])
	var quantity: int = int(_qty_spinbox.value) if _qty_container.visible and _active_mode == "sell" else 1

	var before_count: int = GameSession.game_state.inventory.count(item_name)
	var result := GameSession.store_engine.sell_item(item_name, price, quantity)
	GameSession._emit_logs(GameSession.store_engine.logs)
	if result.get("ok", false):
		var gained: int = int(result.get("gold_gained", 0))
		if quantity > 1:
			_info_label.text = "Sold %d× %s for %d gold!" % [quantity, item_name, gained]
		else:
			_info_label.text = "Sold %s for %d gold!" % [item_name, gained]
		GameSession.trace_store_sold(item_name, gained)
		var after_count: int = GameSession.game_state.inventory.count(item_name)
		GameSession.trace_inventory_qty_changed(item_name, before_count, after_count, "sell")
	else:
		_info_label.text = "Cannot sell: %s" % result.get("reason", "unknown")
	GameSession.state_changed.emit()
	refresh()
