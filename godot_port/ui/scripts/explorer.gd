extends Control
## Explorer Scene — core gameplay screen.
## Displays room info, player stats, movement, action buttons, and adventure log.
## Hosts embedded overlay panels for Combat, Inventory, Store, SaveLoad.

# --- Info labels ---
var _floor_label: Label
var _hp_label: Label
var _gold_label: Label
var _room_name_label: Label
var _room_flags_label: Label

# --- Adventure log ---
var _log_text: RichTextLabel

# --- Movement buttons ---
var _btn_north: Button
var _btn_south: Button
var _btn_east: Button
var _btn_west: Button

# --- Action buttons ---
var _btn_attack: Button
var _btn_flee: Button
var _btn_chest: Button
var _btn_ground: Button
var _btn_inventory: Button
var _btn_store: Button
var _btn_rest: Button
var _btn_save_load: Button
var _btn_descend: Button

# --- Overlay panels ---
var _combat_panel: Control
var _inventory_panel: Control
var _store_panel: Control
var _save_load_panel: Control

var _combat_scene := preload("res://ui/scenes/CombatPanel.tscn")
var _inventory_scene := preload("res://ui/scenes/InventoryPanel.tscn")
var _store_scene := preload("res://ui/scenes/StorePanel.tscn")
var _save_load_scene := preload("res://ui/scenes/SaveLoadPanel.tscn")


func _ready() -> void:
	_build_ui()
	_instantiate_panels()
	_connect_signals()
	_refresh_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 12)
	add_child(main_hbox)

	# --- Left panel: info + log ---
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	left.add_theme_constant_override("separation", 6)
	main_hbox.add_child(left)

	var title := Label.new()
	title.text = "DICE DUNGEON — Explorer"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)

	_floor_label = _add_label(left, "Floor: 1 | Pos: (0,0)")
	_hp_label = _add_label(left, "HP: 50/50")
	_gold_label = _add_label(left, "Gold: 0")
	_room_name_label = _add_label(left, "Room: ---")
	_room_flags_label = _add_label(left, "")

	var log_header := Label.new()
	log_header.text = "— Adventure Log —"
	left.add_child(log_header)

	_log_text = RichTextLabel.new()
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	left.add_child(_log_text)

	# --- Right panel: movement + actions ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	main_hbox.add_child(right)

	var move_header := Label.new()
	move_header.text = "Movement"
	right.add_child(move_header)

	var grid := GridContainer.new()
	grid.columns = 3
	right.add_child(grid)

	grid.add_child(_spacer())
	_btn_north = _make_btn("N")
	grid.add_child(_btn_north)
	grid.add_child(_spacer())

	_btn_west = _make_btn("W")
	grid.add_child(_btn_west)
	grid.add_child(_spacer())
	_btn_east = _make_btn("E")
	grid.add_child(_btn_east)

	grid.add_child(_spacer())
	_btn_south = _make_btn("S")
	grid.add_child(_btn_south)
	grid.add_child(_spacer())

	var action_header := Label.new()
	action_header.text = "Actions"
	right.add_child(action_header)

	var actions := VBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(actions)

	_btn_attack = _make_btn("Attack")
	actions.add_child(_btn_attack)
	_btn_flee = _make_btn("Flee")
	actions.add_child(_btn_flee)
	_btn_chest = _make_btn("Open Chest")
	actions.add_child(_btn_chest)
	_btn_ground = _make_btn("Ground Items")
	actions.add_child(_btn_ground)
	_btn_inventory = _make_btn("Inventory")
	actions.add_child(_btn_inventory)
	_btn_store = _make_btn("Store")
	actions.add_child(_btn_store)
	_btn_rest = _make_btn("Rest")
	actions.add_child(_btn_rest)
	_btn_save_load = _make_btn("Save/Load")
	actions.add_child(_btn_save_load)
	_btn_descend = _make_btn("Descend Stairs")
	actions.add_child(_btn_descend)


func _instantiate_panels() -> void:
	_combat_panel = _combat_scene.instantiate()
	_combat_panel.visible = false
	add_child(_combat_panel)

	_inventory_panel = _inventory_scene.instantiate()
	_inventory_panel.visible = false
	add_child(_inventory_panel)

	_store_panel = _store_scene.instantiate()
	_store_panel.visible = false
	add_child(_store_panel)

	_save_load_panel = _save_load_scene.instantiate()
	_save_load_panel.visible = false
	add_child(_save_load_panel)


func _connect_signals() -> void:
	_btn_north.pressed.connect(_move.bind("N"))
	_btn_south.pressed.connect(_move.bind("S"))
	_btn_east.pressed.connect(_move.bind("E"))
	_btn_west.pressed.connect(_move.bind("W"))

	_btn_attack.pressed.connect(_on_attack)
	_btn_flee.pressed.connect(_on_flee)
	_btn_chest.pressed.connect(_on_chest)
	_btn_ground.pressed.connect(_on_ground_items)
	_btn_inventory.pressed.connect(_on_inventory)
	_btn_store.pressed.connect(_on_store)
	_btn_rest.pressed.connect(_on_rest)
	_btn_save_load.pressed.connect(_on_save_load)
	_btn_descend.pressed.connect(_on_descend)

	GameSession.state_changed.connect(_refresh_ui)
	GameSession.log_message.connect(_append_log)
	GameSession.combat_started.connect(func(): _combat_panel.visible = true)
	GameSession.combat_ended.connect(func(): _combat_panel.visible = false; _refresh_ui())

	if _combat_panel.has_signal("close_requested"):
		_combat_panel.close_requested.connect(func(): _combat_panel.visible = false)
	if _inventory_panel.has_signal("close_requested"):
		_inventory_panel.close_requested.connect(func(): _inventory_panel.visible = false)
	if _store_panel.has_signal("close_requested"):
		_store_panel.close_requested.connect(func(): _store_panel.visible = false)
	if _save_load_panel.has_signal("close_requested"):
		_save_load_panel.close_requested.connect(func(): _save_load_panel.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W: _move("N")
			KEY_S: _move("S")
			KEY_A: _move("W")
			KEY_D: _move("E")


# -------------------------------------------------------------------
# Actions
# -------------------------------------------------------------------

func _move(direction: String) -> void:
	if _any_panel_open():
		return
	var room := GameSession.move_direction(direction)
	if room == null:
		_append_log("Cannot move %s." % direction)
	_refresh_ui()


func _on_attack() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return
	if room.has_combat and not room.enemies_defeated:
		if GameSession.combat == null:
			GameSession.start_combat_for_room(room)
		_combat_panel.visible = true


func _on_flee() -> void:
	if GameSession.combat != null:
		if GameSession.combat.attempt_flee():
			_append_log("Fled from combat!")
			GameSession.end_combat(false)
		else:
			_append_log("Failed to flee!")


func _on_chest() -> void:
	var result := GameSession.open_chest()
	if result.is_empty():
		_append_log("No chest to open.")


func _on_ground_items() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return
	var items := GameSession.exploration.inspect_ground_items(room)
	if items.is_empty():
		_append_log("Nothing on the ground.")
		return
	for item in items:
		if item.get("type") == "gold":
			GameSession.pickup_ground_gold()
		elif item.get("type") == "item":
			GameSession.pickup_ground_item(0)
		elif item.get("type") == "container":
			var result := GameSession.exploration.search_container(room)
			GameSession._emit_logs(GameSession.exploration.logs)
			if result.get("locked", false):
				_append_log("Container is locked!")
			elif not result.is_empty():
				var g: int = int(result.get("gold", 0))
				if g > 0:
					GameSession.game_state.gold += g
				var it: String = str(result.get("item", ""))
				if not it.is_empty():
					GameSession.inventory_engine.add_item_to_inventory(it, "ground")
	GameSession.state_changed.emit()


func _on_inventory() -> void:
	_inventory_panel.visible = true
	if _inventory_panel.has_method("refresh"):
		_inventory_panel.refresh()


func _on_store() -> void:
	var room := GameSession.get_current_room()
	if room == null or not room.has_store:
		_append_log("No store here.")
		return
	_store_panel.visible = true
	if _store_panel.has_method("refresh"):
		_store_panel.refresh()


func _on_rest() -> void:
	GameSession.attempt_rest()


func _on_save_load() -> void:
	_save_load_panel.visible = true
	if _save_load_panel.has_method("refresh"):
		_save_load_panel.refresh()


func _on_descend() -> void:
	var result := GameSession.descend_stairs()
	if result == null:
		_append_log("Cannot descend. Defeat the boss first or find stairs.")


# -------------------------------------------------------------------
# UI refresh
# -------------------------------------------------------------------

func _refresh_ui() -> void:
	var gs := GameSession.game_state
	var room := GameSession.get_current_room()
	var fs := GameSession.get_floor_state()

	if gs == null:
		return

	var pos := fs.current_pos if fs != null else Vector2i.ZERO
	_floor_label.text = "Floor: %d | Pos: (%d, %d)" % [gs.floor, pos.x, pos.y]
	_hp_label.text = "HP: %d / %d" % [gs.health, gs.max_health]
	_gold_label.text = "Gold: %d" % gs.gold

	if room != null:
		_room_name_label.text = "Room: %s" % room.data.get("name", "Unknown")
		var flags: PackedStringArray = []
		if room.has_combat and not room.enemies_defeated:
			flags.append("COMBAT")
		if room.has_chest and not room.chest_looted:
			flags.append("CHEST")
		if room.ground_items.size() > 0 or room.ground_gold > 0:
			flags.append("GROUND ITEMS")
		if room.has_store:
			flags.append("STORE")
		if room.has_stairs:
			flags.append("STAIRS")
		if room.is_mini_boss_room:
			flags.append("MINI-BOSS")
		if room.is_boss_room:
			flags.append("BOSS")
		_room_flags_label.text = " | ".join(flags) if not flags.is_empty() else "(safe)"
	else:
		_room_name_label.text = "Room: ---"
		_room_flags_label.text = ""

	_update_button_visibility(room)


func _update_button_visibility(room: RoomState) -> void:
	var in_combat := GameSession.combat != null
	var has_enemies := room != null and room.has_combat and not room.enemies_defeated

	_btn_north.disabled = in_combat
	_btn_south.disabled = in_combat
	_btn_east.disabled = in_combat
	_btn_west.disabled = in_combat

	_btn_attack.visible = has_enemies
	_btn_flee.visible = has_enemies
	_btn_chest.visible = room != null and room.has_chest and not room.chest_looted
	_btn_ground.visible = room != null and (room.ground_items.size() > 0 or room.ground_gold > 0 or (not room.ground_container.is_empty() and not room.container_searched))
	_btn_store.visible = room != null and room.has_store
	_btn_descend.visible = room != null and room.has_stairs


func _any_panel_open() -> bool:
	return (_combat_panel != null and _combat_panel.visible) or \
		   (_inventory_panel != null and _inventory_panel.visible) or \
		   (_store_panel != null and _store_panel.visible) or \
		   (_save_load_panel != null and _save_load_panel.visible)


# -------------------------------------------------------------------
# Log
# -------------------------------------------------------------------

func _append_log(msg: String) -> void:
	if _log_text != null:
		_log_text.append_text(msg + "\n")


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

func _add_label(parent: Node, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)
	return lbl


func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 32)
	return btn


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(100, 32)
	return c
