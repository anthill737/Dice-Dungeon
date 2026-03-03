extends PanelContainer
## Combat Panel — shows dice, enemy list, and combat actions.
## All dice/combat logic delegated to CombatEngine via GameSession.

signal close_requested()

const COLOR_GOLD := Color(0.83, 0.69, 0.22)
const COLOR_RED := Color(0.78, 0.33, 0.31)
const COLOR_BONE := Color(0.91, 0.86, 0.77)
const COLOR_BG := Color(0.08, 0.06, 0.10)
const COLOR_DICE_BG := Color(0.15, 0.12, 0.10)
const COLOR_DICE_LOCKED := Color(0.83, 0.69, 0.22)
const COLOR_DICE_UNLOCKED := Color(0.40, 0.35, 0.30)
const COLOR_ENEMY_SEL := Color(0.78, 0.33, 0.31, 0.3)

var _dice_labels: Array[Label] = []
var _dice_panels: Array[PanelContainer] = []
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
	GameSession.combat_ended.connect(func(): close_requested.emit())


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.05, 0.09, 0.97)
	bg.border_color = Color(0.6, 0.2, 0.2)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(16)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "⚔ COMBAT ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_RED)
	root.add_child(title)

	# Enemy list
	var enemy_header := Label.new()
	enemy_header.text = "Enemies"
	enemy_header.add_theme_font_size_override("font_size", 14)
	enemy_header.add_theme_color_override("font_color", COLOR_GOLD)
	root.add_child(enemy_header)

	_enemy_list = ItemList.new()
	_enemy_list.custom_minimum_size = Vector2(0, 80)
	_enemy_list.max_columns = 1
	_enemy_list.add_theme_font_size_override("font_size", 14)
	var el_style := StyleBoxFlat.new()
	el_style.bg_color = Color(0.06, 0.04, 0.07, 0.9)
	el_style.set_corner_radius_all(4)
	el_style.set_content_margin_all(4)
	_enemy_list.add_theme_stylebox_override("panel", el_style)
	root.add_child(_enemy_list)

	# Status effects
	_status_label = Label.new()
	_status_label.text = "Statuses: none"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", COLOR_BONE)
	root.add_child(_status_label)

	# Dice header
	var dice_header := Label.new()
	dice_header.text = "Your Dice"
	dice_header.add_theme_font_size_override("font_size", 14)
	dice_header.add_theme_color_override("font_color", COLOR_GOLD)
	root.add_child(dice_header)

	# Dice display
	var dice_hbox := HBoxContainer.new()
	dice_hbox.add_theme_constant_override("separation", 10)
	dice_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(dice_hbox)

	for i in 5:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)

		var die_panel := PanelContainer.new()
		die_panel.custom_minimum_size = Vector2(52, 52)
		var die_style := StyleBoxFlat.new()
		die_style.bg_color = COLOR_DICE_BG
		die_style.border_color = COLOR_DICE_UNLOCKED
		die_style.set_border_width_all(2)
		die_style.set_corner_radius_all(6)
		die_style.set_content_margin_all(4)
		die_panel.add_theme_stylebox_override("panel", die_style)
		_dice_panels.append(die_panel)

		var lbl := Label.new()
		lbl.text = "-"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		_dice_labels.append(lbl)
		die_panel.add_child(lbl)

		vbox.add_child(die_panel)

		var lock_btn := Button.new()
		lock_btn.text = "Lock"
		lock_btn.toggle_mode = true
		lock_btn.custom_minimum_size = Vector2(52, 24)
		lock_btn.add_theme_font_size_override("font_size", 11)
		lock_btn.pressed.connect(_on_lock_toggled.bind(i))
		_lock_buttons.append(lock_btn)
		vbox.add_child(lock_btn)

		dice_hbox.add_child(vbox)

	_rolls_label = Label.new()
	_rolls_label.text = "Rolls left: 3"
	_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolls_label.add_theme_font_size_override("font_size", 14)
	_rolls_label.add_theme_color_override("font_color", COLOR_BONE)
	root.add_child(_rolls_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	_btn_roll = _styled_btn("Roll Dice", COLOR_GOLD)
	_btn_roll.pressed.connect(_on_roll)
	btn_row.add_child(_btn_roll)

	_btn_attack = _styled_btn("Attack", COLOR_RED)
	_btn_attack.pressed.connect(_on_attack)
	btn_row.add_child(_btn_attack)

	var btn_flee := _styled_btn("Flee", Color(0.37, 0.65, 0.65))
	btn_flee.pressed.connect(_on_flee)
	btn_row.add_child(btn_flee)

	_btn_close = _styled_btn("Close", Color(0.5, 0.5, 0.5))
	_btn_close.pressed.connect(func(): close_requested.emit())
	btn_row.add_child(_btn_close)

	# Result / log
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.add_theme_color_override("font_color", COLOR_GOLD)
	root.add_child(_result_label)

	_log_text = RichTextLabel.new()
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.add_theme_font_size_override("normal_font_size", 13)
	root.add_child(_log_text)


func _styled_btn(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 34)
	btn.add_theme_font_size_override("font_size", 14)

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.5)
	normal.border_color = accent
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", accent.lightened(0.4))

	var hover := StyleBoxFlat.new()
	hover.bg_color = accent.darkened(0.3)
	hover.border_color = accent.lightened(0.2)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent.darkened(0.6)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.2, 0.18, 0.15)
	disabled.set_corner_radius_all(4)
	disabled.set_content_margin_all(6)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.35, 0.3))

	return btn


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
			_dice_panels[i].visible = true

			# Highlight locked dice border
			var die_style := StyleBoxFlat.new()
			die_style.bg_color = COLOR_DICE_BG
			die_style.set_corner_radius_all(6)
			die_style.set_content_margin_all(4)
			if dice.locked[i]:
				die_style.border_color = COLOR_DICE_LOCKED
				die_style.set_border_width_all(3)
			else:
				die_style.border_color = COLOR_DICE_UNLOCKED
				die_style.set_border_width_all(2)
			_dice_panels[i].add_theme_stylebox_override("panel", die_style)
		else:
			_dice_labels[i].text = ""
			_lock_buttons[i].visible = false
			_dice_panels[i].visible = false

	_rolls_label.text = "Rolls left: %d" % dice.rolls_left

	# Update enemy list
	_enemy_list.clear()
	var alive := ce.get_alive_enemies()
	for enemy in alive:
		_enemy_list.add_item("☠ %s — HP: %d/%d" % [enemy.name, enemy.health, enemy.max_health])
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
		_result_label.text = "⚔ Victory! ⚔"
		_btn_close.visible = true
		_btn_roll.disabled = true
		_btn_attack.disabled = true
	elif GameSession.game_state.health <= 0:
		_result_label.text = "☠ Defeated... ☠"
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
		_result_label.text = "⚔ Victory! ⚔"
	elif GameSession.game_state.health <= 0:
		GameSession.end_combat(false)
		_result_label.text = "☠ Defeated... ☠"

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
