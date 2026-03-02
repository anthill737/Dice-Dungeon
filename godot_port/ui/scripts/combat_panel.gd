extends PanelContainer
## Combat Panel — shows dice, enemy list, and combat actions.
## All dice/combat logic delegated to CombatEngine via GameSession.

signal close_requested()

var _dice_labels: Array[Label] = []
var _lock_buttons: Array[Button] = []
var _enemy_list: ItemList
var _status_label: Label
var _rolls_label: Label
var _result_label: Label
var _btn_roll: Button
var _btn_attack: Button
var _btn_close: Button
var _log_text: RichTextLabel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(_on_state_changed)
	GameSession.combat_ended.connect(func(): visible = false)


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "=== COMBAT ==="
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	# Enemy list
	var enemy_header := Label.new()
	enemy_header.text = "Enemies:"
	root.add_child(enemy_header)
	_enemy_list = ItemList.new()
	_enemy_list.custom_minimum_size = Vector2(0, 80)
	_enemy_list.max_columns = 1
	root.add_child(_enemy_list)

	# Status effects
	_status_label = Label.new()
	_status_label.text = "Statuses: none"
	root.add_child(_status_label)

	# Dice display
	var dice_header := Label.new()
	dice_header.text = "Your Dice:"
	root.add_child(dice_header)

	var dice_hbox := HBoxContainer.new()
	dice_hbox.add_theme_constant_override("separation", 8)
	root.add_child(dice_hbox)

	for i in 5:
		var vbox := VBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "-"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		_dice_labels.append(lbl)
		vbox.add_child(lbl)

		var lock_btn := Button.new()
		lock_btn.text = "Lock"
		lock_btn.toggle_mode = true
		lock_btn.pressed.connect(_on_lock_toggled.bind(i))
		_lock_buttons.append(lock_btn)
		vbox.add_child(lock_btn)

		dice_hbox.add_child(vbox)

	_rolls_label = Label.new()
	_rolls_label.text = "Rolls left: 3"
	root.add_child(_rolls_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_btn_roll = Button.new()
	_btn_roll.text = "Roll"
	_btn_roll.pressed.connect(_on_roll)
	btn_row.add_child(_btn_roll)

	_btn_attack = Button.new()
	_btn_attack.text = "Attack"
	_btn_attack.pressed.connect(_on_attack)
	btn_row.add_child(_btn_attack)

	var btn_flee := Button.new()
	btn_flee.text = "Flee"
	btn_flee.pressed.connect(_on_flee)
	btn_row.add_child(btn_flee)

	_btn_close = Button.new()
	_btn_close.text = "Close"
	_btn_close.pressed.connect(func(): close_requested.emit(); visible = false)
	btn_row.add_child(_btn_close)

	# Result / log
	_result_label = Label.new()
	_result_label.text = ""
	root.add_child(_result_label)

	_log_text = RichTextLabel.new()
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	root.add_child(_log_text)


func _on_state_changed() -> void:
	if not visible:
		return
	refresh()


func refresh() -> void:
	var ce := GameSession.combat
	if ce == null:
		return

	_result_label.text = ""

	# Update dice display
	var dice := ce.dice
	for i in 5:
		if i < dice.num_dice:
			_dice_labels[i].text = str(dice.values[i]) if dice.values[i] > 0 else "-"
			_lock_buttons[i].visible = true
			_lock_buttons[i].button_pressed = dice.locked[i]
			_lock_buttons[i].text = "Locked" if dice.locked[i] else "Lock"
		else:
			_dice_labels[i].text = ""
			_lock_buttons[i].visible = false

	_rolls_label.text = "Rolls left: %d" % dice.rolls_left

	# Update enemy list
	_enemy_list.clear()
	var alive := ce.get_alive_enemies()
	for enemy in alive:
		_enemy_list.add_item("%s — HP: %d/%d" % [enemy.name, enemy.health, enemy.max_health])
	if not alive.is_empty() and _enemy_list.is_anything_selected() == false:
		_enemy_list.select(0)

	# Update status effects
	var statuses: Array = GameSession.game_state.flags.get("statuses", [])
	_status_label.text = "Statuses: %s" % (", ".join(statuses) if not statuses.is_empty() else "none")

	# Button states
	_btn_roll.disabled = dice.rolls_left <= 0
	_btn_attack.disabled = not dice.has_rolled()

	# Check for combat end
	if alive.is_empty():
		_result_label.text = "Victory!"
		_btn_close.visible = true
		_btn_roll.disabled = true
		_btn_attack.disabled = true
	elif GameSession.game_state.health <= 0:
		_result_label.text = "Defeated..."
		_btn_close.visible = true
		_btn_roll.disabled = true
		_btn_attack.disabled = true


func _on_roll() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	ce.player_roll()
	refresh()


func _on_lock_toggled(index: int) -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	ce.dice.toggle_lock(index)
	refresh()


func _on_attack() -> void:
	var ce := GameSession.combat
	if ce == null:
		return

	var target_idx := 0
	var selected := _enemy_list.get_selected_items()
	if not selected.is_empty():
		target_idx = selected[0]

	var result := ce.player_attack(target_idx)
	for log_line in result.logs:
		_log_text.append_text(log_line + "\n")
		GameSession.log_message.emit(log_line)

	# Check combat end
	var alive := ce.get_alive_enemies()
	if alive.is_empty():
		GameSession.end_combat(true)
		_result_label.text = "Victory!"
	elif GameSession.game_state.health <= 0:
		GameSession.end_combat(false)
		_result_label.text = "Defeated..."

	refresh()


func _on_flee() -> void:
	if GameSession.combat == null:
		return
	var ok := GameSession.flee_from_combat()
	if ok:
		_log_text.append_text("Fled successfully!\n")
	else:
		_log_text.append_text("Failed to flee!\n")
	refresh()
