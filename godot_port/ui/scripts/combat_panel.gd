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
signal player_hit(damage: int, hp_before: int)

const _SfxService := preload("res://game/services/sfx_service.gd")

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
var _btn_close: Button
var _dice_container: HBoxContainer
var _target_label: Label
var _enemy_dice_container: HBoxContainer
var _enemy_dice_labels: Array[Label] = []
var _enemy_dice_panels: Array[PanelContainer] = []
var _player_hp_section: HBoxContainer
var _enemy_hp_section: HBoxContainer
var _enemy_sprite_rect: TextureRect
var _player_sprite_placeholder: PanelContainer
var _log_text: RichTextLabel

var _roll_anim_timer: float = 0.0
var _roll_anim_frame: int = 0
var _roll_anim_active: bool = false
var _enemy_roll_anim_timer: float = 0.0
var _enemy_roll_anim_frame: int = 0
var _enemy_roll_anim_active: bool = false
var _pending_enemy_rolls: Array = []
var _last_turn_count: int = -1
var _active_tweens: Array[Tween] = []
var _turn_sequence_active: bool = false
var _deferred_refresh_requested: bool = false

const COMBAT_ROLL_COLOR := Color(0.31, 0.80, 0.77)
const COMBAT_ATTACK_COLOR := Color(0.91, 0.30, 0.24)


func _ready() -> void:
	_build_ui()
	GameSession.state_changed.connect(_on_state_changed)
	GameSession.combat_ended.connect(func(): close_requested.emit())
	GameSession.combat_started.connect(_on_combat_started_reset)


func _notification(what: int) -> void:
	# Refresh sprite whenever this panel becomes visible — fixes the timing bug
	# where state_changed fires before the panel is shown (guard `if not visible`
	# causes the sprite to never load on first open).
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_enemy_sprite()


func _process(delta: float) -> void:
	if _roll_anim_active:
		var interval := CombatUIPacing.dice_roll_interval()
		var max_frames := CombatUIPacing.dice_roll_frames()
		if max_frames <= 0:
			_roll_anim_active = false
			_finish_player_roll_animation()
			return
		_roll_anim_timer += delta
		if _roll_anim_timer >= interval:
			_roll_anim_timer -= interval
			_roll_anim_frame += 1
			if _roll_anim_frame >= max_frames:
				_roll_anim_active = false
				_finish_player_roll_animation()
			else:
				_show_random_dice()

	if _enemy_roll_anim_active:
		var interval := CombatUIPacing.dice_roll_interval() * 1.5  # Slightly slower for enemy
		var max_frames: int = maxi(CombatUIPacing.dice_roll_frames() / 2, 4)
		if max_frames <= 0:
			_enemy_roll_anim_active = false
			_reveal_enemy_dice_final()
			return
		_enemy_roll_anim_timer += delta
		if _enemy_roll_anim_timer >= interval:
			_enemy_roll_anim_timer -= interval
			_enemy_roll_anim_frame += 1
			if _enemy_roll_anim_frame >= max_frames:
				_enemy_roll_anim_active = false
				_reveal_enemy_dice_final()
			else:
				_show_random_enemy_dice()
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
	# Inline panel — styled with its own background and border.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.08, 0.06)
	bg.border_color = DungeonTheme.COMBAT_ACCENT
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.set_content_margin_all(8)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var title := DungeonTheme.make_header(
		"⚔ COMBAT ⚔", DungeonTheme.COMBAT_ACCENT, 20)
	root.add_child(title)

	# --- Sprite row: player placeholder (left) | enemy list (center) | enemy sprite (right) ---
	var sprite_row := HBoxContainer.new()
	sprite_row.add_theme_constant_override("separation", 8)
	root.add_child(sprite_row)

	# Player sprite placeholder (left side)
	_player_sprite_placeholder = PanelContainer.new()
	_player_sprite_placeholder.name = "PlayerSpritePlaceholder"
	_player_sprite_placeholder.custom_minimum_size = Vector2(120, 120)
	var placeholder_style := StyleBoxFlat.new()
	placeholder_style.bg_color = Color(0.1, 0.08, 0.12, 0.5)
	placeholder_style.border_color = DungeonTheme.TEXT_CYAN.darkened(0.5)
	placeholder_style.set_border_width_all(1)
	placeholder_style.set_corner_radius_all(4)
	placeholder_style.set_content_margin_all(4)
	_player_sprite_placeholder.add_theme_stylebox_override("panel", placeholder_style)
	sprite_row.add_child(_player_sprite_placeholder)
	var placeholder_lbl := Label.new()
	placeholder_lbl.text = "⚔"
	placeholder_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_lbl.add_theme_font_size_override("font_size", 32)
	placeholder_lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN.darkened(0.3))
	_player_sprite_placeholder.add_child(placeholder_lbl)

	# Enemy list (center, expands)
	var enemy_col := VBoxContainer.new()
	enemy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_col.add_theme_constant_override("separation", 2)
	sprite_row.add_child(enemy_col)

	var enemy_header := DungeonTheme.make_header(
		"Enemies", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_SMALL)
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_col.add_child(enemy_header)

	_enemy_list = DungeonTheme.make_item_list(64)
	_enemy_list.name = "EnemyList"
	_enemy_list.item_selected.connect(_on_enemy_selected)
	enemy_col.add_child(_enemy_list)

	_status_label = Label.new()
	_status_label.text = "Statuses: none"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_status_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	enemy_col.add_child(_status_label)

	# Enemy sprite + HP bar (right side)
	var enemy_sprite_col := VBoxContainer.new()
	enemy_sprite_col.add_theme_constant_override("separation", 4)
	sprite_row.add_child(enemy_sprite_col)

	_enemy_sprite_rect = TextureRect.new()
	_enemy_sprite_rect.name = "EnemySpriteRect"
	_enemy_sprite_rect.custom_minimum_size = Vector2(120, 120)
	_enemy_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_sprite_rect.visible = false
	enemy_sprite_col.add_child(_enemy_sprite_rect)

	_enemy_hp_section = HBoxContainer.new()
	_enemy_hp_section.add_theme_constant_override("separation", 4)
	enemy_sprite_col.add_child(_enemy_hp_section)

	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.name = "EnemyHPBar"
	_enemy_hp_bar.custom_minimum_size = Vector2(100, 12)
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

	# Enemy dice display (read-only, dark red theme) — near enemy sprite
	_enemy_dice_container = HBoxContainer.new()
	_enemy_dice_container.name = "EnemyDiceContainer"
	_enemy_dice_container.add_theme_constant_override("separation", 3)
	_enemy_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_dice_container.visible = false
	enemy_sprite_col.add_child(_enemy_dice_container)

	# Hidden player HP elements — we keep them for mid-sequence updates
	# but they are not displayed in combat (the main top-bar HP bar is used instead)
	_player_hp_section = HBoxContainer.new()
	_player_hp_section.visible = false
	root.add_child(_player_hp_section)
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.name = "PlayerHPBar"
	_player_hp_bar.max_value = 100
	_player_hp_bar.value = 100
	_player_hp_bar.show_percentage = false
	_player_hp_section.add_child(_player_hp_bar)
	_player_hp_label = Label.new()
	_player_hp_label.text = ""
	_player_hp_section.add_child(_player_hp_label)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.BORDER))

	# --- Dice section: info row + dice + buttons in compact layout ---
	var dice_info_row := HBoxContainer.new()
	dice_info_row.add_theme_constant_override("separation", 12)
	dice_info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(dice_info_row)

	var dice_header := Label.new()
	dice_header.text = "Your Dice"
	dice_header.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	dice_header.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	dice_info_row.add_child(dice_header)

	_rolls_label = Label.new()
	_rolls_label.name = "RollsLabel"
	_rolls_label.text = "Rolls: 3/3"
	_rolls_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_rolls_label.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
	dice_info_row.add_child(_rolls_label)

	_damage_preview_label = Label.new()
	_damage_preview_label.name = "DamagePreviewLabel"
	_damage_preview_label.text = ""
	_damage_preview_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_damage_preview_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	dice_info_row.add_child(_damage_preview_label)

	# Dice display — click-to-lock (no separate Lock button, Python parity)
	_dice_container = HBoxContainer.new()
	_dice_container.name = "DiceContainer"
	_dice_container.add_theme_constant_override("separation", 6)
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_dice_container)

	for i in 5:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 1)

		var die_panel := PanelContainer.new()
		die_panel.custom_minimum_size = Vector2(56, 56)
		die_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		die_panel.gui_input.connect(_on_die_clicked.bind(i))
		die_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_die_style(die_panel, false)
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

		var lock_icon := Label.new()
		lock_icon.text = ""
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.add_theme_font_size_override("font_size", 10)
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

	# Action buttons + result on same row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	_btn_roll = DungeonTheme.make_styled_btn("Roll Dice", COMBAT_ROLL_COLOR)
	_btn_roll.pressed.connect(_on_roll)
	btn_row.add_child(_btn_roll)

	_btn_attack = DungeonTheme.make_styled_btn("ATTACK!", COMBAT_ATTACK_COLOR)
	_btn_attack.pressed.connect(_on_attack)
	btn_row.add_child(_btn_attack)

	_btn_close = DungeonTheme.make_styled_btn("Close", DungeonTheme.TEXT_SECONDARY)
	_btn_close.pressed.connect(func(): close_requested.emit())
	btn_row.add_child(_btn_close)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_result_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	btn_row.add_child(_result_label)

	# Combat log — BBCode enabled for color styling
	_log_text = RichTextLabel.new()
	_log_text.name = "CombatLog"
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_SMALL)
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
		if _combat_controls_locked():
			return
		if not ce.dice.has_rolled():
			return
		ce.dice.toggle_lock(index)
		if ce.dice.locked[index]:
			GameSession.trace_dice_locked(index, ce.dice.values[index])
			_SfxService.play_for(self, "dice_lock")
		_sync_dice_display()
		_update_damage_preview()
# ------------------------------------------------------------------
# Enemy dice
# ------------------------------------------------------------------

## Show enemy dice with a brief rolling animation (visually distinct from player dice).
## Enemy dice persist until the next call or combat ends.
func _show_enemy_dice(rolls: Array) -> void:
	_clear_enemy_dice()

	if rolls.is_empty():
		return

	# Store final values for reveal after animation
	_pending_enemy_rolls = rolls.duplicate(true)

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
			dl.text = "?"  # Start with placeholder during animation
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

	# Start enemy dice rolling animation
	_start_enemy_dice_animation(rolls)


# ------------------------------------------------------------------
# Roll animation (player dice)
# ------------------------------------------------------------------

func _start_roll_animation() -> void:
	var interval := CombatUIPacing.dice_roll_interval()
	var max_frames := CombatUIPacing.dice_roll_frames()
	if interval <= 0.0 or max_frames <= 0:
		_roll_anim_active = false
		_roll_anim_frame = 0
		_roll_anim_timer = 0.0
		return
	_roll_anim_active = true
	_roll_anim_frame = 0
	_roll_anim_timer = 0.0
	_show_random_dice()
func _show_random_dice() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	for i in 5:
		if i < ce.dice.num_dice and not ce.dice.locked[i]:
			_dice_labels[i].text = str(randi_range(1, 6))


# ------------------------------------------------------------------
# Roll animation (enemy dice — visually distinct, slightly slower)
# ------------------------------------------------------------------

func _start_enemy_dice_animation(rolls: Array) -> void:
	var interval := CombatUIPacing.dice_roll_interval()
	if interval <= 0.0:
		# Instant pacing — skip animation, show final values immediately
		_reveal_enemy_dice_final()
		return
	_enemy_roll_anim_active = true
	_enemy_roll_anim_frame = 0
	_enemy_roll_anim_timer = 0.0


func _show_random_enemy_dice() -> void:
	for dl in _enemy_dice_labels:
		if is_instance_valid(dl):
			dl.text = str(randi_range(1, 6))


func _reveal_enemy_dice_final() -> void:
	var label_idx := 0
	for er in _pending_enemy_rolls:
		var dice_arr: Array = er.get("dice", [])
		for val in dice_arr:
			if label_idx < _enemy_dice_labels.size():
				var dl := _enemy_dice_labels[label_idx]
				if is_instance_valid(dl):
					dl.text = str(val)
				label_idx += 1


func _sync_dice_display() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	if _dice_labels.size() < 5 or _dice_panels.size() < 5 or _dice_lock_icons.size() < 5:
		return
	var dice := ce.dice
	for i in 5:
		if i < dice.num_dice:
			_dice_labels[i].text = str(dice.values[i]) if dice.values[i] > 0 else "-"
			_dice_panels[i].visible = true
			_apply_die_style(_dice_panels[i], dice.locked[i])
			_dice_labels[i].add_theme_color_override(
				"font_color", DungeonTheme.TEXT_GOLD if dice.locked[i] else Color.WHITE)
			_dice_lock_icons[i].text = "L" if dice.locked[i] else ""
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
	# Add to the panel itself (not the HBox) so it doesn't affect layout.
	# Convert section's screen position to local coordinates (Control nodes
	# don't have to_local(); subtract global origins instead).
	add_child(lbl)
	var start_pos := section.global_position - global_position
	lbl.position = start_pos
	var tween := create_tween()
	_track_tween(tween)
	tween.set_parallel(true)
	tween.tween_property(lbl, "modulate:a", 0.0, duration)
	tween.tween_property(lbl, "position:y", start_pos.y - 20, duration)
	tween.chain().tween_callback(lbl.queue_free)


func _track_tween(tw: Tween) -> void:
	_active_tweens.append(tw)
	tw.finished.connect(func(): _active_tweens.erase(tw))


# ------------------------------------------------------------------
# Combat log styling — Python-parity colors
# ------------------------------------------------------------------

func _classify_log_line(line: String) -> Color:
	var lower := line.to_lower()
	if line.begins_with("="):
		return DungeonTheme.LOG_SEPARATOR
	if "crit" in lower or "critical" in lower:
		return DungeonTheme.LOG_CRIT
	if "you attack" in lower or line.begins_with("Hit "):
		return DungeonTheme.LOG_PLAYER
	if line.begins_with("+") and "gold" in lower:
		return DungeonTheme.LOG_LOOT
	if "boss key fragment" in lower:
		return DungeonTheme.LOG_LOOT
	if "defeated" in lower or "blocked" in lower or "absorbs" in lower:
		return DungeonTheme.LOG_SUCCESS
	if "burn damage" in lower or "fire damage" in lower:
		return DungeonTheme.LOG_FIRE
	if "summons" in lower or "splits" in lower or "spawned" in lower:
		return DungeonTheme.LOG_ENEMY
	if "attacks for" in lower or "rolls:" in lower or " takes " in lower:
		return DungeonTheme.LOG_ENEMY
	if "rolls remaining" in lower or "dazed" in lower or "target" in lower:
		return DungeonTheme.LOG_SYSTEM
	if "[split]" in lower or "[spawned]" in lower or "[transformed]" in lower:
		return DungeonTheme.LOG_ENEMY
	if "victory" in lower or "mini-boss" in lower:
		return DungeonTheme.LOG_SUCCESS
	return DungeonTheme.TEXT_BONE


func _append_styled_log(_line: String) -> void:
	# Combat log is no longer embedded in the panel — all messages go to the
	# adventure log via GameSession.log_message.emit() at the call sites.
	pass


# ------------------------------------------------------------------
# State sync
# ------------------------------------------------------------------

func _combat_controls_locked() -> bool:
	return _turn_sequence_active or _roll_anim_active or _enemy_roll_anim_active


func _sync_combat_controls(combat_over: bool = false) -> void:
	if _btn_roll == null or _btn_attack == null:
		return
	var ce := GameSession.combat
	if ce == null or combat_over or _combat_controls_locked():
		_btn_roll.disabled = true
		_btn_attack.disabled = true
		return
	_btn_roll.disabled = ce.dice.rolls_left <= 0
	_btn_attack.disabled = not ce.dice.has_rolled()


func _finish_player_roll_animation() -> void:
	_deferred_refresh_requested = false
	if not is_inside_tree():
		return
	refresh()


func _finish_turn_sequence() -> void:
	_turn_sequence_active = false
	_deferred_refresh_requested = false
	if not is_inside_tree():
		return
	refresh()
func _on_combat_started_reset() -> void:
	# Clear stale enemy dice from prior encounter
	_turn_sequence_active = false
	_deferred_refresh_requested = false
	_roll_anim_active = false
	_roll_anim_timer = 0.0
	_roll_anim_frame = 0
	_dice_container.visible = true
	_rolls_label.visible = true
	_damage_preview_label.visible = true
	_clear_enemy_dice()
	_last_turn_count = -1
	_result_label.text = ""
	# Load the sprite for the new encounter immediately rather than waiting for
	# the next state_changed (which may fire before the panel is visible).
	call_deferred("_refresh_enemy_sprite")
func _clear_enemy_dice() -> void:
	_enemy_roll_anim_active = false
	_enemy_roll_anim_timer = 0.0
	_enemy_roll_anim_frame = 0
	_pending_enemy_rolls.clear()
	for p in _enemy_dice_panels:
		if is_instance_valid(p):
			p.queue_free()
	_enemy_dice_panels.clear()
	_enemy_dice_labels.clear()
	if _enemy_dice_container != null:
		for child in _enemy_dice_container.get_children():
			child.queue_free()
		_enemy_dice_container.visible = false
func _on_state_changed() -> void:
	if not visible:
		return
	if _combat_controls_locked():
		_deferred_refresh_requested = true
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


func _refresh_enemy_sprite() -> void:
	if _enemy_sprite_rect == null:
		return
	var ce := GameSession.combat
	if ce == null or GameSession.assets == null:
		_enemy_sprite_rect.visible = false
		return
	var alive := ce.get_alive_enemies()
	var selected := _enemy_list.get_selected_items()
	if selected.is_empty() or selected[0] >= alive.size():
		_enemy_sprite_rect.visible = false
		return
	var enemy = alive[selected[0]]
	var tex = GameSession.assets.get_enemy_sprite(enemy.name)
	if tex != null:
		_enemy_sprite_rect.texture = tex
		_enemy_sprite_rect.visible = true
	else:
		_enemy_sprite_rect.visible = false


func refresh() -> void:
	var ce := GameSession.combat
	if ce == null:
		_sync_close_flee_visibility()
		return

	_result_label.text = ""
	if not _turn_sequence_active:
		_dice_container.visible = true
		_rolls_label.visible = true
		_damage_preview_label.visible = true

	var gs := GameSession.game_state
	if gs != null:
		var hp_ratio: float = float(gs.health) / float(gs.max_health) if gs.max_health > 0 else 0.0
		_player_hp_bar.max_value = gs.max_health
		_player_hp_bar.value = gs.health
		_player_hp_label.text = "%d/%d" % [gs.health, gs.max_health]
		DungeonTheme.style_hp_bar(_player_hp_bar, hp_ratio)

	_sync_dice_display()
	_rolls_label.text = "Rolls: %d/%d" % [ce.dice.rolls_left, ce.dice.max_rolls]
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
	_refresh_enemy_sprite()

	var statuses: Array = GameSession.game_state.flags.get("statuses", [])
	_status_label.text = "Statuses: %s" % (", ".join(statuses) if not statuses.is_empty() else "none")

	var combat_over := alive.is_empty() or GameSession.game_state.health <= 0
	_sync_combat_controls(combat_over)
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


# ------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------

func _on_roll() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	if _combat_controls_locked():
		return
	if not ce.player_roll():
		return
	_SfxService.play_for(self, "dice_roll")
	GameSession.trace_dice_rolled(ce.dice.values)
	GameSession.trace_reroll_used(ce.dice.rolls_left)
	_start_roll_animation()
	if _roll_anim_active:
		_rolls_label.text = "Rolls: %d/%d" % [ce.dice.rolls_left, ce.dice.max_rolls]
		_damage_preview_label.text = ""
		_sync_combat_controls()
	else:
		refresh()
func _on_lock_toggled(index: int) -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	if _combat_controls_locked():
		return
	ce.dice.toggle_lock(index)
	if ce.dice.locked[index]:
		GameSession.trace_dice_locked(index, ce.dice.values[index])
	refresh()
func _on_attack() -> void:
	var ce := GameSession.combat
	if ce == null:
		return
	if _combat_controls_locked():
		return
	if not ce.dice.has_rolled():
		return

	var target_idx := 0
	var selected := _enemy_list.get_selected_items()
	if not selected.is_empty():
		target_idx = selected[0]

	# Snapshot player HP before the engine mutates state.
	var hp_before := GameSession.game_state.health
	var shield_before := GameSession.game_state.temp_shield
	var combo_bonus := ce.dice.calc_combo_bonus()

	# Disable controls for the full duration of the sequence.
	_turn_sequence_active = true
	_deferred_refresh_requested = false
	_sync_combat_controls()

	_append_styled_log("-- Round %d --" % (ce.turn_count + 1))

	# Engine resolves everything synchronously; we only control when the UI
	# reveals each phase of the result.
	var result := ce.player_attack(target_idx)

	# --- Telemetry ---
	GameSession.trace_attack_committed(
		result.target_name, result.player_damage,
		combo_bonus)
	for er in result.enemy_rolls:
		GameSession.trace_enemy_attack(str(er.get("name", "")), int(er.get("damage", 0)))
	if result.status_tick_damage > 0:
		GameSession.trace_status_tick("combined", result.status_tick_damage)
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

	# Partition logs: player-side vs enemy-side.
	var player_logs: Array = []
	var enemy_logs: Array = []
	for log_line in result.logs:
		if _is_enemy_attack_log(log_line):
			enemy_logs.append(log_line)
		else:
			player_logs.append(log_line)

	# ================================================================
	# PHASE 1 — Player attacks: show log immediately.
	# ================================================================
	for log_line in player_logs:
		_append_styled_log(log_line)
		GameSession.log_message.emit(log_line)

	# Beat before impact shows on enemy.
	await _combat_pause(CombatUIPacing.phase_pause_sec())
	if not is_inside_tree():
		return

	# ================================================================
	# PHASE 2 — Enemy hit: update HP bar, flash, floating number.
	# ================================================================
	_refresh_enemy_hp_bar()
	if result.player_damage > 0:
		if result.target_killed:
			_SfxService.play_enemy_event_for(self, result.target_name, "die")
		else:
			if result.was_crit and (result.player_damage >= 30 or combo_bonus >= 10):
				_SfxService.play_for(self, "legendary_hit")
			elif result.was_crit:
				_SfxService.play_for(self, "crit")
			else:
				_SfxService.play_for(self, "attack")
			_SfxService.play_enemy_event_for(self, result.target_name, "hit")
		_flash_hp_bar(_enemy_hp_bar, _enemy_hp_section)
		_show_floating_damage(result.player_damage, _enemy_hp_section, DungeonTheme.LOG_PLAYER)

	# Hold long enough for the hit animation to settle.
	await _combat_pause(CombatUIPacing.post_hit_pause_sec())
	if not is_inside_tree():
		return

	# ================================================================
	# PHASE 3 — Enemy turn begins: hide player dice, show enemy dice.
	# ================================================================
	_dice_container.visible = false
	_rolls_label.visible = false
	_damage_preview_label.visible = false

	if not result.enemy_rolls.is_empty():
		var first_enemy_name := str(result.enemy_rolls[0].get("name", ""))
		_SfxService.play_enemy_event_for(self, first_enemy_name, "dice_roll")
		_show_enemy_dice(result.enemy_rolls)
		await _combat_pause(CombatUIPacing.enemy_dice_linger_sec())
		if not is_inside_tree():
			return

	# ================================================================
	# PHASE 4 — Enemy attacks revealed one line at a time.
	# ================================================================
	var stagger := CombatUIPacing.enemy_attack_stagger_sec()
	for log_line in enemy_logs:
		_append_styled_log(log_line)
		GameSession.log_message.emit(log_line)
		await _combat_pause(stagger)
		if not is_inside_tree():
			return

	# Brief beat before player takes damage.
	await _combat_pause(CombatUIPacing.phase_pause_sec())
	if not is_inside_tree():
		return

	# ================================================================
	# PHASE 5 — Player hit: signal top bar to flash HP.
	# ================================================================
	var player_dmg_taken := hp_before - GameSession.game_state.health
	if shield_before > GameSession.game_state.temp_shield:
		_SfxService.play_for(self, "shield_block")
	for dur_ev in result.durability_events:
		if bool(dur_ev.get("broken", false)) and str(dur_ev.get("slot", "")) == "armor":
			_SfxService.play_for(self, "armor_break")
			break
	_refresh_player_hp_bar()
	player_hit.emit(player_dmg_taken, hp_before)
	# Also emit state_changed so the main top-bar HP bar updates visually
	GameSession.state_changed.emit()

	# Hold for player hit animation.
	await _combat_pause(CombatUIPacing.post_hit_pause_sec())
	if not is_inside_tree():
		return

	# ================================================================
	# PHASE 6 — Enemy turn ends: clear enemy dice, restore player dice.
	# ================================================================
	_clear_enemy_dice()
	_dice_container.visible = true
	_rolls_label.visible = true
	_damage_preview_label.visible = true
	var alive := ce.get_alive_enemies()
	if alive.is_empty():
		GameSession.end_combat(true)
		_result_label.text = "⚔ Victory! ⚔"
	elif GameSession.game_state.health <= 0:
		GameSession.end_combat(false)
		_result_label.text = "☠ Defeated... ☠"

	_finish_turn_sequence()
## Awaitable pause helper. Returns immediately when seconds <= 0 so callers
## don't need to guard every await site against the Instant pacing preset.
func _combat_pause(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


## Targeted player HP bar refresh used mid-sequence to avoid re-enabling
## buttons or resetting other UI state that refresh() would touch.
func _refresh_player_hp_bar() -> void:
	var gs := GameSession.game_state
	if gs == null:
		return
	var ratio: float = float(gs.health) / float(gs.max_health) if gs.max_health > 0 else 0.0
	_player_hp_bar.max_value = gs.max_health
	_player_hp_bar.value = gs.health
	_player_hp_label.text = "%d/%d" % [gs.health, gs.max_health]
	DungeonTheme.style_hp_bar(_player_hp_bar, ratio)


static func _is_enemy_attack_log(line: String) -> bool:
	return line.contains("rolls [") or line.contains("rolls:") or (line.contains(" for ") and line.contains(" damage"))


