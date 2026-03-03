extends PanelContainer
## Store Panel — buy/sell interface.
## All transactions delegated to StoreEngine via GameSession.

signal close_requested()

var _buy_list: ItemList
var _sell_list: ItemList
var _gold_label: Label
var _btn_buy: Button
var _btn_sell: Button
var _btn_close: Button
var _info_label: Label

var _store_items: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.04, 0.97)
	bg.border_color = Color(0.83, 0.69, 0.22)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(16)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "🏪 STORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))
	root.add_child(title)

	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	root.add_child(_gold_label)

	# Buy section
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	root.add_child(hbox)

	var buy_vbox := VBoxContainer.new()
	buy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(buy_vbox)
	var buy_header := Label.new()
	buy_header.text = "Buy:"
	buy_vbox.add_child(buy_header)
	_buy_list = ItemList.new()
	_buy_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_vbox.add_child(_buy_list)

	# Sell section
	var sell_vbox := VBoxContainer.new()
	sell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sell_vbox)
	var sell_header := Label.new()
	sell_header.text = "Sell:"
	sell_vbox.add_child(sell_header)
	_sell_list = ItemList.new()
	_sell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_vbox.add_child(_sell_list)

	_info_label = Label.new()
	_info_label.text = ""
	root.add_child(_info_label)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_btn_buy = Button.new()
	_btn_buy.text = "Buy"
	_btn_buy.pressed.connect(_on_buy)
	btn_row.add_child(_btn_buy)

	_btn_sell = Button.new()
	_btn_sell.text = "Sell"
	_btn_sell.pressed.connect(_on_sell)
	btn_row.add_child(_btn_sell)

	_btn_close = Button.new()
	_btn_close.text = "Close"
	_btn_close.pressed.connect(func(): close_requested.emit())
	btn_row.add_child(_btn_close)


func refresh() -> void:
	var gs := GameSession.game_state
	if gs == null:
		return

	_gold_label.text = "Gold: %d" % gs.gold

	# Buy list
	_store_items = GameSession.store_engine.generate_store_inventory()
	_buy_list.clear()
	for entry in _store_items:
		var item_name: String = entry[0]
		var price: int = int(entry[1])
		_buy_list.add_item("%s — %d gold" % [item_name, price])

	# Sell list
	_sell_list.clear()
	for item_name in gs.inventory:
		var sell_price := GameSession.store_engine.calculate_sell_price(item_name)
		_sell_list.add_item("%s — %d gold" % [item_name, sell_price])


func _on_buy() -> void:
	var sel := _buy_list.get_selected_items()
	if sel.is_empty():
		return
	var idx: int = sel[0]
	if idx >= _store_items.size():
		return
	var item_name: String = _store_items[idx][0]
	var price: int = int(_store_items[idx][1])
	var result := GameSession.store_engine.buy_item(item_name, price)
	GameSession._emit_logs(GameSession.store_engine.logs)
	if result.get("ok", false):
		_info_label.text = "Purchased %s!" % item_name
	else:
		_info_label.text = "Cannot buy: %s" % result.get("reason", "unknown")
	GameSession.state_changed.emit()
	refresh()


func _on_sell() -> void:
	var sel := _sell_list.get_selected_items()
	if sel.is_empty():
		return
	var idx: int = sel[0]
	var gs := GameSession.game_state
	if idx >= gs.inventory.size():
		return
	var item_name: String = gs.inventory[idx]
	var price := GameSession.store_engine.calculate_sell_price(item_name)
	var result := GameSession.store_engine.sell_item(item_name, price)
	GameSession._emit_logs(GameSession.store_engine.logs)
	if result.get("ok", false):
		_info_label.text = "Sold %s for %d gold!" % [item_name, result.get("gold_gained", 0)]
	else:
		_info_label.text = "Cannot sell: %s" % result.get("reason", "unknown")
	GameSession.state_changed.emit()
	refresh()
