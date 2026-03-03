extends PanelContainer
## Combat Panel — shows dice, enemy list, and combat actions.
## All dice/combat logic delegated to CombatEngine via GameSession.

signal close_requested()

var _dice_labels: Array[Label] = []
var _dice_panels: Array[PanelContainer] = []
var _lock_buttons: Array[Button] = []
var _enemy_list: ItemList
var _status_label: Label
var _rolls_label: Label
var _result_label: Label
var _btn_roll: Button
var _btn_attack: Button
var _btn_flee: Button
var _btn_close: Button
var _log_text: RichTextLabel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(_on_state_changed)
	GameSession.combat_ended.connect(func(): close_requested.emit())


func _build_ui() -> void:
	var bg := DungeonTheme.make_panel_bg(
		Color(0.07, 0.05, 0.09, 0.97), DungeonTheme.COMBAT_ACCENT)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Title
	var title := DungeonTheme.make_header(
		"⚔ COMBAT ⚔", DungeonTheme.COMBAT_ACCENT, 24)
	root.add_child(title)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.COMBAT_ACCENT))

	# Enemy section
	var enemy_header := DungeonTheme.make_header(
		"Enemies", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_LABEL)
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(enemy_header)

	_enemy_list = DungeonTheme.make_item_list(90)
	root.add_child(_enemy_list)

	_status_label = Label.new()
	_status_label.text = "Statuses: none"
	_status_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_status_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_status_label)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.BORDER))

	# Dice header
	var dice_header := DungeonTheme.make_header(
		"Your Dice", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_LABEL)
	root.add_child(dice_header)

	# Dice display — larger cells
	var dice_hbox := HBoxContainer.new()
	dice_hbox.add_theme_constant_override("separation", 12)
	dice_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(dice_hbox)

	for i in 5:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)

		var die_panel := PanelContainer.new()
		die_panel.custom_minimum_size = Vector2(
			DungeonTheme.DICE_CELL_SIZE, DungeonTheme.DICE_CELL_SIZE)
		var die_style := StyleBoxFlat.new()
		die_style.bg_color = DungeonTheme.DICE_BG
		die_style.border_color = DungeonTheme.DICE_UNLOCKED_BORDER
		die_style.set_border_width_all(2)
		die_style.set_corner_radius_all(8)
		die_style.set_content_margin_all(4)
		die_panel.add_theme_stylebox_override("panel", die_style)
		_dice_panels.append(die_panel)

		var lbl := Label.new()
		lbl.text = "-"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", DungeonTheme.DICE_FONT_SIZE)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		_dice_labels.append(lbl)
		die_panel.add_child(lbl)

		vbox.add_child(die_panel)

		var lock_btn := DungeonTheme.make_styled_btn(
			"Lock", DungeonTheme.DICE_UNLOCKED_BORDER, 56)
		lock_btn.custom_minimum_size.y = 24
		lock_btn.toggle_mode = true
		lock_btn.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		lock_btn.pressed.connect(_on_lock_toggled.bind(i))
		_lock_buttons.append(lock_btn)
		vbox.add_child(lock_btn)

		dice_hbox.add_child(vbox)

	_rolls_label = Label.new()
	_rolls_label.text = "Rolls left: 3"
	_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolls_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_rolls_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_rolls_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	_btn_roll = DungeonTheme.make_styled_btn("Roll Dice", DungeonTheme.TEXT_GOLD)
	_btn_roll.pressed.connect(_on_roll)
	btn_row.add_child(_btn_roll)

	_btn_attack = DungeonTheme.make_styled_btn("Attack", DungeonTheme.COMBAT_ACCENT)
	_btn_attack.pressed.connect(_on_attack)
	btn_row.add_child(_btn_attack)

	_btn_flee = DungeonTheme.make_styled_btn("Flee", DungeonTheme.TEXT_CYAN)
	_btn_flee.pressed.connect(_on_flee)
	btn_row.add_child(_btn_flee)

	_btn_close = DungeonTheme.make_styled_btn("Close", DungeonTheme.TEXT_SECONDARY)
	_btn_close.pressed.connect(func(): close_requested.emit())
	btn_row.add_child(_btn_close)

	# Result
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	_result_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	root.add_child(_result_label)

	# Combat log
	_log_text = RichTextLabel.new()
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_log_text.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	root.add_child(_log_text)


func _on_state_changed() -> void:
	if not visible:
		return
	refresh()


func refresh() -> void:
	var ce := GameSession.combat
	if ce == null:
		_sync_close_flee_visibility()
		return

	_result_label.text = ""

	var dice := ce.dice
	for i in 5:
		if i < dice.num_dice:
			_dice_labels[i].text = str(dice.values[i]) if dice.values[i] > 0 else "-"
			_lock_buttons[i].visible = true
			_lock_buttons[i].button_pressed = dice.locked[i]
			_lock_buttons[i].text = "Locked" if dice.locked[i] else "Lock"
			_dice_panels[i].visible = true

			var die_style := StyleBoxFlat.new()
			die_style.bg_color = DungeonTheme.DICE_BG
			die_style.set_corner_radius_all(8)
			die_style.set_content_margin_all(4)
			if dice.locked[i]:
				die_style.border_color = DungeonTheme.DICE_LOCKED_BORDER
				die_style.set_border_width_all(3)
				_dice_labels[i].add_theme_color_override(
					"font_color", DungeonTheme.TEXT_GOLD)
			else:
				die_style.border_color = DungeonTheme.DICE_UNLOCKED_BORDER
				die_style.set_border_width_all(2)
				_dice_labels[i].add_theme_color_override(
					"font_color", Color.WHITE)
			_dice_panels[i].add_theme_stylebox_override("panel", die_style)
		else:
			_dice_labels[i].text = ""
			_lock_buttons[i].visible = false
			_dice_panels[i].visible = false

	_rolls_label.text = "Rolls left: %d" % dice.rolls_left

	# Enemy list
	_enemy_list.clear()
	var alive := ce.get_alive_enemies()
	for enemy in alive:
		var hp_pct := int(100.0 * float(enemy.health) / float(enemy.max_health)) if enemy.max_health > 0 else 0
		_enemy_list.add_item("☠ %s — HP: %d/%d (%d%%)" % [
			enemy.name, enemy.health, enemy.max_health, hp_pct])
	if not alive.is_empty() and _enemy_list.is_anything_selected() == false:
		_enemy_list.select(0)

	# Status effects
	var statuses: Array = GameSession.game_state.flags.get("statuses", [])
	_status_label.text = "Statuses: %s" % (", ".join(statuses) if not statuses.is_empty() else "none")

	# Button states
	_btn_roll.disabled = dice.rolls_left <= 0
	_btn_attack.disabled = not dice.has_rolled()

	var combat_over := alive.is_empty() or GameSession.game_state.health <= 0
	if alive.is_empty():
		_result_label.text = "⚔ Victory! ⚔"
		_result_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
		_btn_roll.disabled = true
		_btn_attack.disabled = true
	elif GameSession.game_state.health <= 0:
		_result_label.text = "☠ Defeated... ☠"
		_result_label.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
		_btn_roll.disabled = true
		_btn_attack.disabled = true

	_sync_close_flee_visibility(combat_over)


func _sync_close_flee_visibility(combat_over: bool = false) -> void:
	var pending := GameSession.is_pending_choice()
	var active := GameSession.is_combat_active()
	_btn_close.visible = combat_over or (not pending and not active)
	_btn_flee.visible = pending and not active
	_btn_flee.disabled = not pending


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

	var alive := ce.get_alive_enemies()
	if alive.is_empty():
		GameSession.end_combat(true)
		_result_label.text = "⚔ Victory! ⚔"
	elif GameSession.game_state.health <= 0:
		GameSession.end_combat(false)
		_result_label.text = "☠ Defeated... ☠"

	refresh()


func _on_flee() -> void:
	if not GameSession.is_pending_choice():
		return
	if GameSession.combat != null:
		return
	var ok := GameSession.attempt_flee_pending()
	if ok:
		_log_text.append_text("Fled successfully!\n")
	else:
		_log_text.append_text("Failed to flee!\n")
	refresh()
