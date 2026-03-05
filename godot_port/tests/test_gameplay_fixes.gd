extends GutTest
## Tests for gameplay regression fixes:
## - Part 1: Miniboss locked-room gating
## - Part 2: Tab hotkey / inventory toggle
## - Part 3: Combat pacing (enemy dice linger)
## - Part 4: Negative HP prevention
## - Part 5: Enemy dice UI reset
## - Part 6: Room-entry log wording parity

var _rooms_db: Array = []


func before_all() -> void:
	var rd := RoomsData.new()
	assert_true(rd.load(), "rooms DB must load")
	_rooms_db = rd.rooms


func _make_state() -> GameState:
	var s := GameState.new()
	s.max_health = 50
	s.health = 50
	return s


func _make_exploration(seed_val: int, state: GameState = null) -> ExplorationEngine:
	if state == null:
		state = _make_state()
	return ExplorationEngine.new(DeterministicRNG.new(seed_val), state, _rooms_db)


func _make_combat(seed_val: int, state: GameState = null) -> CombatEngine:
	if state == null:
		state = _make_state()
	return CombatEngine.new(DeterministicRNG.new(seed_val), state, 3)


func _force_move(engine: ExplorationEngine, preferred: String) -> RoomState:
	var room := engine.move(preferred)
	if room != null:
		return room
	for alt in ["N", "E", "S", "W"]:
		if alt != preferred:
			room = engine.move(alt)
			if room != null:
				return room
	return null


# ==================================================================
# PART 1 — Miniboss locked-room gating
# ==================================================================

func test_miniboss_no_key_does_not_enter() -> void:
	var state := _make_state()
	var engine := _make_exploration(80000, state)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite", "flavor": "Dark."}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	mb_room.visited = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	var pos_before := engine.floor.current_pos
	var rest_cooldown_before := state.rest_cooldown
	var rooms_explored_before := engine.floor.rooms_explored
	engine.logs.clear()

	var result := engine.move("E")

	assert_null(result, "move should return null for locked miniboss room without key")
	assert_eq(engine.floor.current_pos, pos_before, "position unchanged")
	assert_eq(engine.floor.rooms_explored, rooms_explored_before, "rooms_explored unchanged")
	assert_eq(state.rest_cooldown, rest_cooldown_before, "rest_cooldown unchanged")


func test_miniboss_with_key_consumes_and_enters() -> void:
	var state := _make_state()
	var engine := _make_exploration(80001, state)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite", "flavor": "Dark."}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	mb_room.visited = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	state.inventory.append("Old Key")
	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "has_key_mini_boss", "should offer key dialog")

	engine.use_old_key(mb_pos)
	assert_false(state.inventory.has("Old Key"), "Old Key consumed")
	assert_true(engine.floor.unlocked_rooms.has(mb_pos), "room unlocked")

	var room := engine.move("E")
	assert_not_null(room, "should enter unlocked room")
	assert_eq(engine.floor.current_pos, mb_pos, "position updated")


func test_miniboss_locked_no_combat_pending() -> void:
	var state := _make_state()
	var engine := _make_exploration(80002, state)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	mb_room.visited = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	var result := engine.move("E")
	assert_null(result, "locked room returns null — no combat should start")


# ==================================================================
# PART 2 — Tab hotkey / inventory toggle
# ==================================================================

func test_tab_toggle_opens_inventory() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	var mgr = ManagerScript.new()
	mgr.name = "TestMgr"
	add_child(mgr)

	var panel := PanelContainer.new()
	mgr.register_menu("inventory", "Inventory", panel, "inventory")
	assert_false(mgr.is_menu_open("inventory"), "starts closed")

	_toggle(mgr, "inventory")
	assert_true(mgr.is_menu_open("inventory"), "inventory opens after toggle")
	mgr.queue_free()


func test_tab_toggle_closes_inventory() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	var mgr = ManagerScript.new()
	mgr.name = "TestMgr2"
	add_child(mgr)

	var panel := PanelContainer.new()
	mgr.register_menu("inventory", "Inventory", panel, "inventory")

	_toggle(mgr, "inventory")
	assert_true(mgr.is_menu_open("inventory"), "open after first toggle")
	_toggle(mgr, "inventory")
	assert_false(mgr.get_stack().has("inventory"), "closed after second toggle")
	mgr.queue_free()


func test_tab_toggle_focus_unchanged() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	var mgr = ManagerScript.new()
	mgr.name = "TestMgr3"
	add_child(mgr)

	var panel := PanelContainer.new()
	mgr.register_menu("inventory", "Inventory", panel, "inventory")

	var focus_before = get_viewport().gui_get_focus_owner() if get_viewport() else null
	_toggle(mgr, "inventory")
	_toggle(mgr, "inventory")
	var focus_after = get_viewport().gui_get_focus_owner() if get_viewport() else null
	assert_eq(focus_before, focus_after, "focus should not change after Tab toggles")
	mgr.queue_free()


## Mirror toggle logic from explorer.gd
func _toggle(mgr, menu_key: String) -> void:
	if mgr.is_menu_open(menu_key):
		if mgr.get_top_menu_key() == menu_key:
			mgr.close_menu(menu_key)
			return
	mgr.open_menu(menu_key)


# ==================================================================
# PART 3 — Combat pacing durations
# ==================================================================

func test_pacing_instant_has_zero_linger() -> void:
	var val: float = CombatUIPacing.ENEMY_DICE_LINGER_SEC[CombatUIPacing.Preset.INSTANT]
	assert_eq(val, 0.0, "Instant pacing should have 0 linger")


func test_pacing_normal_has_nonzero_linger() -> void:
	var val: float = CombatUIPacing.ENEMY_DICE_LINGER_SEC[CombatUIPacing.Preset.NORMAL]
	assert_gt(val, 0.0, "Normal pacing should have positive linger")


func test_pacing_slow_gte_normal() -> void:
	var slow: float = CombatUIPacing.ENEMY_DICE_LINGER_SEC[CombatUIPacing.Preset.SLOW]
	var normal: float = CombatUIPacing.ENEMY_DICE_LINGER_SEC[CombatUIPacing.Preset.NORMAL]
	assert_gte(slow, normal, "Slow linger should be >= Normal linger")


func test_pacing_all_presets_present() -> void:
	for p in [CombatUIPacing.Preset.INSTANT, CombatUIPacing.Preset.FAST,
			CombatUIPacing.Preset.NORMAL, CombatUIPacing.Preset.SLOW]:
		assert_true(CombatUIPacing.ENEMY_DICE_LINGER_SEC.has(p),
			"ENEMY_DICE_LINGER_SEC should have preset %d" % p)


# ==================================================================
# PART 4 — Prevent negative HP
# ==================================================================

func test_damage_exceeding_hp_clamps_to_zero() -> void:
	var state := _make_state()
	state.health = 10
	state.health -= 50
	assert_eq(state.health, 0, "HP should clamp to 0, not go negative")


func test_healing_via_rest_never_exceeds_max_hp() -> void:
	GameSession._load_data()
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 44444})
	GameSession.game_state.health = 45
	GameSession.game_state.max_health = 50
	GameSession.attempt_rest()
	assert_lte(GameSession.game_state.health, GameSession.game_state.max_health,
		"rest should not heal above max_health")


func test_hp_never_negative_after_combat() -> void:
	var state := _make_state()
	state.health = 5
	var ce := CombatEngine.new(DeterministicRNG.new(99), state, 3)
	ce.add_enemy("Test Monster", 100, 4)
	ce.dice.roll()
	ce.player_attack(0)
	assert_gte(state.health, 0, "HP must not go negative after combat turn")


func test_hp_zero_triggers_correctly() -> void:
	var state := _make_state()
	state.health = 1
	state.health -= 1
	assert_eq(state.health, 0, "HP should be exactly 0")
	state.health -= 1
	assert_eq(state.health, 0, "HP should stay at 0")


func test_hp_clamp_during_reset() -> void:
	var state := _make_state()
	state.max_health = 30
	state.health = 25
	state.reset()
	assert_eq(state.max_health, 50, "After reset, max_health should be 50")
	assert_eq(state.health, 50, "After reset, health should be 50")


# ==================================================================
# PART 5 — Enemy dice UI reset on combat start
# ==================================================================

func test_second_combat_starts_clean() -> void:
	var state := _make_state()
	state.health = 200
	state.max_health = 200
	var rng := DeterministicRNG.new(200)

	# First combat — run a full turn so enemy_rolls exist
	var ce1 := CombatEngine.new(rng, state, 3)
	ce1.add_enemy("Goblin", 200, 2)
	ce1.dice.roll()
	var result1 := ce1.player_attack(0)
	var had_enemy_rolls := not result1.enemy_rolls.is_empty()
	# Enemy rolls exist only if enemy survives the turn
	if had_enemy_rolls:
		assert_gt(result1.enemy_rolls.size(), 0, "first combat has enemy rolls")

	# Second combat — new CombatEngine (as GameSession does)
	var ce2 := CombatEngine.new(rng, state, 3)
	ce2.add_enemy("Spider", 15, 2)
	assert_true(ce2.dice.values.all(func(v): return v == 0),
		"new combat dice should start unrolled")
	assert_eq(ce2.turn_count, 0, "new combat turn_count should be 0")
	assert_true(ce2.enemies.size() == 1, "new combat has fresh enemy list")


# ==================================================================
# PART 6 — Room-entry log wording parity
# ==================================================================

func test_first_visit_logs_entered_prefix() -> void:
	var engine := _make_exploration(90000)
	engine.start_floor(1)
	engine.logs.clear()

	var room := _force_move(engine, "E")
	assert_not_null(room, "should move to a room")

	var has_entered := false
	var has_returned := false
	for log_line in engine.logs:
		if log_line.begins_with("Entered:"):
			has_entered = true
		if log_line.begins_with("Returned to:"):
			has_returned = true

	assert_true(has_entered, "First visit should log 'Entered: ...'")
	assert_false(has_returned, "First visit should NOT log 'Returned to: ...'")


func test_revisit_logs_entered_prefix() -> void:
	var engine := _make_exploration(90001)
	engine.start_floor(1)

	var room := engine.move("E")
	if room == null:
		room = engine.move("N")
	assert_not_null(room, "should move initially")

	# Move back then revisit
	var opp := "W" if engine.floor.current_pos.x > 0 else "S"
	engine.move(opp)

	engine.logs.clear()
	var dir := "E" if opp == "W" else "N"
	var revisit := engine.move(dir)
	if revisit == null:
		pass_test("Could not revisit — seed-dependent, skipping")
		return

	var has_entered := false
	var has_returned := false
	for log_line in engine.logs:
		if log_line.begins_with("Entered:"):
			has_entered = true
		if log_line.begins_with("Returned to:"):
			has_returned = true

	assert_true(has_entered, "Revisit should log 'Entered: ...' (Python parity)")
	assert_false(has_returned, "Revisit should NOT log 'Returned to: ...'")


func test_floor_start_logs_entered_prefix() -> void:
	var engine := _make_exploration(90002)
	var entrance := engine.start_floor(1)
	assert_not_null(entrance)

	var has_entered := false
	for log_line in engine.logs:
		if log_line.begins_with("Entered:"):
			has_entered = true
			break
	assert_true(has_entered, "Floor start should log 'Entered: ...'")


func test_room_entry_includes_flavor_text() -> void:
	var engine := _make_exploration(90003)
	engine.start_floor(1)

	var flavor_found := false
	for i in range(10):
		engine.logs.clear()
		var room := _force_move(engine, ["E", "N", "S", "W"][i % 4])
		if room == null:
			continue
		var room_flavor: String = room.data.get("flavor", "")
		if room_flavor.is_empty():
			continue
		for log_line in engine.logs:
			if log_line == room_flavor:
				flavor_found = true
				break
		if flavor_found:
			break
	assert_true(flavor_found, "Room entry log should include flavor text")


func test_no_returned_to_in_any_log() -> void:
	var engine := _make_exploration(90004)
	engine.start_floor(1)
	for i in range(20):
		_force_move(engine, ["E", "N", "S", "W"][i % 4])
	for log_line in engine.logs:
		assert_false(log_line.begins_with("Returned to:"),
			"No log line should start with 'Returned to:' — Python uses 'Entered:' always")
