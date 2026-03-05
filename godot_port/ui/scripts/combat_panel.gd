extends PanelContainer
## Combat Panel — shows dice, enemy list, HP bars, and combat actions.
## Mirrors Python adventure mode combat layout.
## All dice/combat logic delegated to CombatEngine via GameSession.
##
## Improvements over initial version:
## - Click-to-lock dice (no separate Lock button; Python parity)
## - Roll animation on dice (8 frames, ~200ms)
## - Enemy dice display (read-only, dark-red theme)
## - Damage flash on HP bars (red flash for hits)
## - Combat log color styling by message category (Python parity)
## - Round separators in log
## - Floating damage numbers on enemy/player HP

signal close_requested()

var _dice_labels: Array[Label] = []
var _dice_panels: Array[PanelContainer] = []
var _dice_lock_icons: Array[Label] = []
var _enemy_list: ItemList
var _status_label: Label
var _rolls_label: Label
var _damage_preview_label: Label
var _result_label: Label
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_label: Label
var _btn_roll: Button
var _btn_attack: Button
var _btn_flee: Button
var _btn_close: Button
var _log_text: RichTextLabel
var _dice_container: HBoxContainer
var _target_label: Label
var _enemy_dice_container: HBoxContainer
var _enemy_dice_labels: Array[Label] = []
var _enemy_dice_panels: Array[PanelContainer] = []
var _player_hp_section: HBoxContainer
var _enemy_hp_section: HBoxContainer

var _roll_anim_timer: float = 0.0
var _roll_anim_frame: int = 0
var _roll_anim_active: bool = false
var _last_turn_count: int = -1
var _active_tweens: Array[Tween] = []

const COMBAT_ROLL_COLOR := Color(0.31, 0.80, 0.77)
const COMBAT_FLEE_COLOR := Color(0.95, 0.61, 0.07)
const COMBAT_ATTACK_COLOR := Color(0.91, 0.30, 0.24)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(_on_state_changed)
	GameSession.combat_ended.connect(func(): close_requested.emit())
	GameSession.combat_started.connect(_on_combat_started_reset)


func _process(delta: float) -> void:
	if _roll_anim_active:
		var interval := CombatUIPacing.dice_roll_interval()
		var max_frames := CombatUIPacing.dice_roll_frames()
		if max_frames <= 0:
			_roll_anim_active = false
			_sync_dice_display()
			return
		_roll_anim_timer += delta
		if _roll_anim_timer >= interval:
			_roll_anim_timer -= interval
			_roll_anim_frame += 1
			if _roll_anim_frame >= max_frames:
				_roll_anim_active = false
				_sync_dice_display()
			else:
				_show_random_dice()


func _exit_tree() -> void:
	_roll_anim_active = false
	for tw in _active_tweens:
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
	_active_tweens.clear()
	_dice_labels.clear()
	_dice_panels.clear()
	_dice_lock_icons.clear()
	_enemy_dice_labels.clear()
	_enemy_dice_panels.clear()


func _build_ui() -> void:
	var bg := DungeonTheme.make_panel_bg(
		Color(0.07, 0.05, 0.09, 0.97), DungeonTheme.COMBAT_ACCENT)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var title := DungeonTheme.make_header(
		"⚔ COMBAT ⚔", DungeonTheme.COMBAT_ACCENT, 24)
	root.add_child(title)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.COMBAT_ACCENT))

	# --- Player HP ---
	_player_hp_section = HBoxContainer.new()
	_player_hp_section.add_theme_constant_override("separation", 8)
	root.add_child(_player_hp_section)

	var player_lbl := Label.new()
	player_lbl.text = "Player HP:"
	player_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	player_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	_player_hp_section.add_child(player_lbl)

	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.name = "PlayerHPBar"
	_player_hp_bar.custom_minimum_size = Vector2(200, 20)
	_player_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_hp_bar.max_value = 100
	_player_hp_bar.value = 100
	_player_hp_bar.show_percentage = false
	DungeonTheme.style_hp_bar(_player_hp_bar, 1.0)
	_player_hp_section.add_child(_player_hp_bar)

	_player_hp_label = Label.new()
	_player_hp_label.text = "50/50"
	_player_hp_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_player_hp_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	_player_hp_section.add_child(_player_hp_label)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.BORDER))

	# --- Enemy section ---
	var enemy_header := DungeonTheme.make_header(
		"Enemies", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_LABEL)
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(enemy_header)

	_enemy_list = DungeonTheme.make_item_list(80)
	_enemy_list.name = "EnemyList"
	_enemy_list.item_selected.connect(_on_enemy_selected)
	root.add_child(_enemy_list)

	_enemy_hp_section = HBoxContainer.new()
	_enemy_hp_section.add_theme_constant_override("separation", 8)
	root.add_child(_enemy_hp_section)

	var enemy_hp_lbl := Label.new()
	enemy_hp_lbl.text = "Enemy HP:"
	enemy_hp_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	enemy_hp_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
	_enemy_hp_section.add_child(enemy_hp_lbl)

	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.name = "EnemyHPBar"
	_enemy_hp_bar.custom_minimum_size = Vector2(180, 16)
	_enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_hp_bar.max_value = 100
	_enemy_hp_bar.value = 100
	_enemy_hp_bar.show_percentage = false
	DungeonTheme.style_hp_bar(_enemy_hp_bar, 1.0)
	_enemy_hp_section.add_child(_enemy_hp_bar)

	_enemy_hp_label = Label.new()
	_enemy_hp_label.text = ""
	_enemy_hp_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_enemy_hp_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	_enemy_hp_section.add_child(_enemy_hp_label)

	# Enemy dice display (read-only, dark red theme)
	_enemy_dice_container = HBoxContainer.new()
	_enemy_dice_container.name = "EnemyDiceContainer"
	_enemy_dice_container.add_theme_constant_override("separation", 4)
	_enemy_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_dice_container.visible = false
	root.add_child(_enemy_dice_container)

	_status_label = Label.new()
	_status_label.text = "Statuses: none"
	_status_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_status_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	root.add_child(_status_label)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.BORDER))

	# --- Dice header ---
	var dice_header := DungeonTheme.make_header(
		"Your Dice", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_LABEL)
	root.add_child(dice_header)

	_rolls_label = Label.new()
	_rolls_label.name = "RollsLabel"
	_rolls_label.text = "Rolls Remaining: 3/3"
	_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolls_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_rolls_label.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	root.add_child(_rolls_label)

	_damage_preview_label = Label.new()
	_damage_preview_label.name = "DamagePreviewLabel"
	_damage_preview_label.text = ""
	_damage_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_preview_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	_damage_preview_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	root.add_child(_damage_preview_label)

	# Dice display — click-to-lock (no separate Lock button, Python parity)
	_dice_container = HBoxContainer.new()
	_dice_container.name = "DiceContainer"
	_dice_container.add_theme_constant_override("separation", 10)
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_dice_container)

	for i in 5:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var die_panel := PanelContainer.new()
		die_panel.custom_minimum_size = Vector2(72, 72)
		die_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		die_panel.gui_input.connect(_on_die_clicked.bind(i))
		die_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_die_style(die_panel, false)
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

		var lock_icon := Label.new()
		lock_icon.text = ""
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		lock_icon.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
		_dice_lock_icons.append(lock_icon)
		vbox.add_child(lock_icon)

		_dice_container.add_child(vbox)

	_target_label = Label.new()
	_target_label.text = ""
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_target_label.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	root.add_child(_target_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	_btn_roll = DungeonTheme.make_styled_btn("Roll Dice", COMBAT_ROLL_COLOR)
	_btn_roll.pressed.connect(_on_roll)
	btn_row.add_child(_btn_roll)

	_btn_attack = DungeonTheme.make_styled_btn("ATTACK!", COMBAT_ATTACK_COLOR)
	_btn_attack.pressed.connect(_on_attack)
	btn_row.add_child(_btn_attack)

	_btn_flee = DungeonTheme.make_styled_btn("Flee", COMBAT_FLEE_COLOR)
	_btn_flee.pressed.connect(_on_flee)
	btn_row.add_child(_btn_flee)

	_btn_close = DungeonTheme.make_styled_btn("Close", DungeonTheme.TEXT_SECONDARY)
	_btn_close.pressed.connect(func(): close_requested.emit())
	btn_row.add_child(_btn_close)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	_result_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	root.add_child(_result_label)

	# Combat log — BBCode enabled for color styling
	_log_text = RichTextLabel.new()
	_log_text.name = "CombatLog"
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_log_text.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	root.add_child(_log_text)


# ------------------------------------------------------------------
# Dice styling
# ------------------------------------------------------------------

func _apply_die_style(panel: PanelContainer, locked: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = DungeonTheme.DICE_BG
	s.set_corner_radius_all(8)
	s.set_content_margin_all(4)
	if locked:
		s.border_color = DungeonTheme.DICE_LOCKED_BORDER
		s.set_border_width_all(3)
	else:
		s.border_color = DungeonTheme.DICE_UNLOCKED_BORDER
		s.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", s)


func _on_die_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ce := GameSession.combat
		if ce == null:
			return
		if not ce.dice.has_rolled():
			return
		ce.dice.toggle_lock(index)
		if ce.dice.locked[index]:
			GameSession.trace_dice_locked(index, ce.dice.values[index])
		_sync_dice_display()
		_update_damage_preview()


# ------------------------------------------------------------------
# Enemy dice
# ------------------------------------------------------------------

func _show_enemy_dice(rolls: Array) -> void:
	for p in _enemy_dice_panels:
		p.queue_free()
	_enemy_dice_panels.clear()
	_enemy_dice_labels.clear()

	if rolls.is_empty():
		_enemy_dice_container.visible = false
		return

	_enemy_dice_container.visible = true
	for er in rolls:
		var dice_arr: Array = er.get("dice", [])
		var ename: String = er.get("name", "")

		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 2)
		var name_lbl := Label.new()
		name_lbl.text = ename
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		name_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
		group.add_child(name_lbl)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for val in dice_arr:
			var dp := PanelContainer.new()
			dp.custom_minimum_size = Vector2(DungeonTheme.ENEMY_DICE_SIZE, DungeonTheme.ENEMY_DICE_SIZE)
			var ds := StyleBoxFlat.new()
			ds.bg_color = DungeonTheme.ENEMY_DICE_BG
			ds.border_color = DungeonTheme.ENEMY_DICE_BORDER
			ds.set_border_width_all(2)
			ds.set_corner_radius_all(4)
			ds.set_content_margin_all(2)
			dp.add_theme_stylebox_override("panel", ds)

			var dl := Label.new()
			dl.text = str(val)
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dl.add_theme_font_size_override("font_size", DungeonTheme.ENEMY_DICE_FONT)
			dl.add_theme_color_override("font_color", Color.WHITE)
			dp.add_child(dl)

			_enemy_dice_panels.append(dp)
			_enemy_dice_labels.append(dl)
			row.add_child(dp)

		group.add_child(row)
		_enemy_dice_container.add_child(group)


# ------------------------------------------------------------------
# Roll animation
# ------------------------------------------------------------------

func _start_roll_animation() -> void:
	_roll_anim_active = true
	_roll_anim_frame = 0
	_roll_anim_timer = 0.0


func _show_random_dice() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	for i in 5:
		if i < ce.dice.num_dice and not ce.dice.locked[i]:
			_dice_labels[i].text = str(randi_range(1, 6))


func _sync_dice_display() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	var dice := ce.dice
	for i in 5:
		if i < dice.num_dice:
			_dice_labels[i].text = str(dice.values[i]) if dice.values[i] > 0 else "-"
			_dice_panels[i].visible = true
			_apply_die_style(_dice_panels[i], dice.locked[i])
			_dice_labels[i].add_theme_color_override(
				"font_color", DungeonTheme.TEXT_GOLD if dice.locked[i] else Color.WHITE)
			_dice_lock_icons[i].text = "🔒" if dice.locked[i] else ""
		else:
			_dice_labels[i].text = ""
			_dice_panels[i].visible = false
			_dice_lock_icons[i].text = ""


func _update_damage_preview() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	var gs := GameSession.game_state
	if ce.dice.has_rolled():
		var base := ce.dice.calc_base_damage()
		var combo := ce.dice.calc_combo_bonus()
		var total := ce.dice.calc_total_damage(
			gs.multiplier if gs != null else 1.0,
			gs.damage_bonus if gs != null else 0)
		if combo > 0:
			_damage_preview_label.text = "Damage Preview: %d (base %d + combo %d)" % [total, base, combo]
		else:
			_damage_preview_label.text = "Damage Preview: %d" % total
	else:
		_damage_preview_label.text = ""


# ------------------------------------------------------------------
# HP flash feedback
# ------------------------------------------------------------------

func _flash_hp_bar(bar: ProgressBar, section: HBoxContainer) -> void:
	if not is_inside_tree():
		return
	var duration := CombatUIPacing.hit_flash_duration()
	if duration <= 0.01:
		return
	var tween := create_tween()
	_track_tween(tween)
	tween.tween_method(func(v: float):
		var flash_color := DungeonTheme.FLASH_RED.lerp(DungeonTheme.HP_BG, v)
		var s := StyleBoxFlat.new()
		s.bg_color = flash_color
		s.set_corner_radius_all(3)
		s.border_color = DungeonTheme.BORDER
		s.set_border_width_all(1)
		bar.add_theme_stylebox_override("background", s),
		0.0, 1.0, duration)


func _show_floating_damage(value: int, section: HBoxContainer, color: Color) -> void:
	if not is_inside_tree():
		return
	var duration := CombatUIPacing.damage_float_duration()
	if duration <= 0.01:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % value if value > 0 else "+%d" % absi(value)
	lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 10
	section.add_child(lbl)
	var tween := create_tween()
	_track_tween(tween)
	tween.set_parallel(true)
	tween.tween_property(lbl, "modulate:a", 0.0, duration)
	tween.tween_property(lbl, "position:y", lbl.position.y - 20, duration)
	tween.chain().tween_callback(lbl.queue_free)


func _track_tween(tw: Tween) -> void:
	_active_tweens.append(tw)
	tw.finished.connect(func(): _active_tweens.erase(tw))


# ------------------------------------------------------------------
# Combat log styling — Python-parity colors
# ------------------------------------------------------------------

func _classify_log_line(line: String) -> Color:
	if line.begins_with("="):
		return DungeonTheme.LOG_SEPARATOR
	if "CRIT" in line or "critical" in line.to_lower():
		return DungeonTheme.LOG_CRIT
	if line.begins_with("⚔️ You") or line.begins_with("Hit ") or line.begins_with("⚄ "):
		return DungeonTheme.LOG_PLAYER
	if line.begins_with("+") and "gold" in line:
		return DungeonTheme.LOG_LOOT
	if "Boss Key Fragment" in line:
		return DungeonTheme.LOG_LOOT
	if "defeated" in line or "DEFEATED" in line or "blocked" in line or "absorbs" in line:
		return DungeonTheme.LOG_SUCCESS
	if "🔥" in line or "✹" in line or "fire damage" in line:
		return DungeonTheme.LOG_FIRE
	if line.begins_with("⚠️") or "summons" in line or "splits" in line:
		return DungeonTheme.LOG_ENEMY
	if "☠" in line or "attacks for" in line or "rolls:" in line or "take" in line.to_lower():
		return DungeonTheme.LOG_ENEMY
	if "💚" in line:
		return DungeonTheme.LOG_ENEMY
	if "Rolls Remaining" in line or "dazed" in line or "Target" in line:
		return DungeonTheme.LOG_SYSTEM
	if "spawned" in line.to_lower() or "[SPLIT]" in line or "[SPAWNED]" in line:
		return DungeonTheme.LOG_ENEMY
	if "[TRANSFORMED]" in line:
		return DungeonTheme.LOG_ENEMY
	if "Victory" in line or "Mini-boss" in line:
		return DungeonTheme.LOG_SUCCESS
	return DungeonTheme.TEXT_BONE


func _append_styled_log(line: String) -> void:
	var color := _classify_log_line(line)
	var hex := "#" + color.to_html(false)

	var is_bold := (color == DungeonTheme.LOG_PLAYER or color == DungeonTheme.LOG_ENEMY
		or color == DungeonTheme.LOG_CRIT or color == DungeonTheme.LOG_SUCCESS
		or color == DungeonTheme.LOG_FIRE)

	if is_bold:
		_log_text.append_text("[color=%s][b]%s[/b][/color]\n" % [hex, line])
	else:
		_log_text.append_text("[color=%s]%s[/color]\n" % [hex, line])


# ------------------------------------------------------------------
# State sync
# ------------------------------------------------------------------

func _on_combat_started_reset() -> void:
	# Clear stale combat log from prior encounter (Python parity)
	if _log_text != null:
		_log_text.clear()
	# Clear stale enemy dice from prior encounter
	_clear_enemy_dice()
	_last_turn_count = -1
	_result_label.text = ""


func _clear_enemy_dice() -> void:
	for p in _enemy_dice_panels:
		if is_instance_valid(p):
			p.queue_free()
	_enemy_dice_panels.clear()
	_enemy_dice_labels.clear()
	if _enemy_dice_container != null:
		_enemy_dice_container.visible = false


func _on_state_changed() -> void:
	if not visible:
		return
	refresh()


func _on_enemy_selected(_index: int) -> void:
	_refresh_enemy_hp_bar()


func _refresh_enemy_hp_bar() -> void:
	var ce := GameSession.combat
	if ce == null:
		_enemy_hp_bar.value = 0
		_enemy_hp_label.text = ""
		return
	var alive := ce.get_alive_enemies()
	var selected := _enemy_list.get_selected_items()
	if selected.is_empty() or selected[0] >= alive.size():
		_enemy_hp_bar.value = 0
		_enemy_hp_label.text = ""
		return
	var enemy = alive[selected[0]]
	var ratio: float = enemy.hp_fraction()
	_enemy_hp_bar.max_value = enemy.max_health
	_enemy_hp_bar.value = enemy.health
	_enemy_hp_label.text = "%d/%d (%d%%)" % [enemy.health, enemy.max_health, int(ratio * 100)]
	DungeonTheme.style_hp_bar(_enemy_hp_bar, ratio)


func refresh() -> void:
	var ce := GameSession.combat
	if ce == null:
		_sync_close_flee_visibility()
		return

	_result_label.text = ""

	var gs := GameSession.game_state
	if gs != null:
		var hp_ratio: float = float(gs.health) / float(gs.max_health) if gs.max_health > 0 else 0.0
		_player_hp_bar.max_value = gs.max_health
		_player_hp_bar.value = gs.health
		_player_hp_label.text = "%d/%d" % [gs.health, gs.max_health]
		DungeonTheme.style_hp_bar(_player_hp_bar, hp_ratio)

	_sync_dice_display()
	_rolls_label.text = "Rolls Remaining: %d/%d" % [ce.dice.rolls_left, ce.dice.max_rolls]
	_update_damage_preview()

	# Enemy list
	_enemy_list.clear()
	var alive := ce.get_alive_enemies()
	for enemy in alive:
		var hp_pct := int(100.0 * float(enemy.health) / float(enemy.max_health)) if enemy.max_health > 0 else 0
		_enemy_list.add_item("☠ %s — HP: %d/%d (%d%%)" % [
			enemy.name, enemy.health, enemy.max_health, hp_pct])
	if not alive.is_empty() and _enemy_list.is_anything_selected() == false:
		_enemy_list.select(0)

	if alive.size() > 1:
		_target_label.text = "Select Target (click enemy above)"
	else:
		_target_label.text = ""

	_refresh_enemy_hp_bar()

	var statuses: Array = GameSession.game_state.flags.get("statuses", [])
	_status_label.text = "Statuses: %s" % (", ".join(statuses) if not statuses.is_empty() else "none")

	_btn_roll.disabled = ce.dice.rolls_left <= 0
	_btn_attack.disabled = not ce.dice.has_rolled()

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
	_btn_flee.visible = pending or active
	_btn_flee.disabled = combat_over


# ------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------

func _on_roll() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	ce.player_roll()
	GameSession.trace_dice_rolled(ce.dice.values)
	GameSession.trace_reroll_used(ce.dice.rolls_left)
	_start_roll_animation()
	refresh()


func _on_lock_toggled(index: int) -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	ce.dice.toggle_lock(index)
	if ce.dice.locked[index]:
		GameSession.trace_dice_locked(index, ce.dice.values[index])
	refresh()


func _on_attack() -> void:
	var ce := GameSession.combat
	if ce == null:
		return

	var target_idx := 0
	var selected := _enemy_list.get_selected_items()
	if not selected.is_empty():
		target_idx = selected[0]

	var hp_before := GameSession.game_state.health
	var enemy_hp_before: int = 0
	var alive_before := ce.get_alive_enemies()
	if target_idx < alive_before.size():
		enemy_hp_before = alive_before[target_idx].health

	# Round separator in log
	_append_styled_log("── Round %d ──" % ce.turn_count)

	var result := ce.player_attack(target_idx)

	GameSession.trace_attack_committed(
		result.target_name, result.player_damage,
		ce.dice.calc_combo_bonus())
	for er in result.enemy_rolls:
		GameSession.trace_enemy_attack(str(er.get("name", "")), int(er.get("damage", 0)))
	if result.status_tick_damage > 0:
		GameSession.trace_status_tick("combined", result.status_tick_damage)

	# Durability events are now resolved in CombatEngine core; UI just reads them
	for dur_ev in result.durability_events:
		var item_name: String = dur_ev.get("item_name", "")
		var dur_val: int = int(dur_ev.get("durability", 0))
		var broken: bool = dur_ev.get("broken", false)
		var warning: bool = dur_ev.get("warning", false)
		GameSession.trace_durability_changed(item_name, dur_val, broken)
		if warning:
			var dur_msg := "%s durability low (%d)" % [item_name, dur_val]
			_append_styled_log(dur_msg)
			GameSession.log_message.emit(dur_msg)

	var player_dmg_taken := hp_before - GameSession.game_state.health

	for log_line in result.logs:
		_append_styled_log(log_line)
		GameSession.log_message.emit(log_line)

	# Enemy dice display
	if not result.enemy_rolls.is_empty():
		_show_enemy_dice(result.enemy_rolls)
	else:
		_enemy_dice_container.visible = false

	# Damage feedback: flash bars and show floating numbers
	if result.player_damage > 0:
		_flash_hp_bar(_enemy_hp_bar, _enemy_hp_section)
		_show_floating_damage(result.player_damage, _enemy_hp_section, DungeonTheme.LOG_PLAYER)

	if player_dmg_taken > 0:
		_flash_hp_bar(_player_hp_bar, _player_hp_section)
		_show_floating_damage(player_dmg_taken, _player_hp_section, DungeonTheme.LOG_ENEMY)

	var alive := ce.get_alive_enemies()
	if alive.is_empty():
		GameSession.end_combat(true)
		_result_label.text = "⚔ Victory! ⚔"
	elif GameSession.game_state.health <= 0:
		GameSession.end_combat(false)
		_result_label.text = "☠ Defeated... ☠"

	refresh()


func _on_flee() -> void:
	if GameSession.is_pending_choice() and GameSession.combat == null:
		var result := GameSession.attempt_flee_pending()
		if result.get("success", false):
			var dmg: int = int(result.get("damage", 0))
			if dmg > 0:
				_append_styled_log("[FLEE] Fled! Lost %d HP." % dmg)
			else:
				_append_styled_log("Fled safely!")
		elif result.get("reason", "") == "boss_fight":
			_append_styled_log(CombatGatingPolicy.flee_blocked_message())
		else:
			_append_styled_log("Can't escape! Enemy blocks the way!")
		refresh()
		return
	if GameSession.is_combat_active():
		var result := GameSession.flee_from_combat()
		if result.get("success", false):
			var dmg: int = int(result.get("damage", 0))
			if dmg > 0:
				_append_styled_log("[FLEE] Fled! Lost %d HP." % dmg)
			else:
				_append_styled_log("Fled safely!")
		elif result.get("reason", "") == "boss_fight":
			_append_styled_log(CombatGatingPolicy.flee_blocked_message())
		else:
			_append_styled_log("Can't escape! Enemy blocks the way!")
		refresh()
