extends GutTest
## Tests for Combat UX QoL changes:
## 1) Enemy dice appear only on attack (not at combat start)
## 2) Starting a second combat clears combat panel state
## 3) Inventory accessible during combat (Python parity)
## 4) Combat pacing setting (Instant / Fast / Normal / Slow)


func _make_combat_session() -> void:
	GameSession._load_data()
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 42})
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}


# ── Test 1: Enemy dice only appear after player attacks, not at combat start ──

func test_enemy_dice_not_shown_at_combat_start() -> void:
	_make_combat_session()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()
	var ce := GameSession.combat
	assert_not_null(ce, "CombatEngine created")
	assert_eq(ce.turn_count, 0, "No turns executed yet — no attack happened")
	# Python parity: enemy dice are only shown after player_attack(),
	# which triggers the enemy turn. Before that, no enemy_rolls exist.


func test_enemy_dice_appear_after_attack() -> void:
	_make_combat_session()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()
	var ce := GameSession.combat
	assert_not_null(ce, "CombatEngine exists")

	ce.player_roll()
	var result := ce.player_attack(0)
	# Python parity: _announce_enemy_attack() calls _show_and_animate_enemy_dice()
	# after player attack resolves. The TurnResult should contain enemy_rolls.
	assert_not_null(result.enemy_rolls, "Attack result has enemy_rolls")
	assert_true(result.enemy_rolls.size() > 0, "Enemy rolled dice after player attack")


# ── Test 2: Second combat clears prior state ──

func test_second_combat_resets_state() -> void:
	_make_combat_session()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()

	var ce1 := GameSession.combat
	assert_not_null(ce1, "First combat engine exists")
	ce1.player_roll()
	var result := ce1.player_attack(0)
	var turn_count_1 := ce1.turn_count

	# End combat and start a new one
	GameSession.end_combat(true)
	assert_null(GameSession.combat, "Combat cleared after end")

	# Set up second combat in another room
	var room2 := GameSession.get_current_room()
	room2.has_combat = true
	room2.enemies_defeated = false
	room2.combat_escaped = false
	room2.data["threats"] = ["Skeleton"]
	GameSession.enemy_types_db["Skeleton"] = {"health": 15, "num_dice": 2}
	GameSession._check_combat_pending(room2)
	GameSession.accept_combat()

	var ce2 := GameSession.combat
	assert_not_null(ce2, "Second combat engine exists")
	assert_eq(ce2.turn_count, 0, "Second combat starts fresh at turn 0")
	assert_ne(ce1, ce2, "Different combat engine instance")


# ── Test 3: Inventory accessible during combat ──

func test_inventory_accessible_during_combat() -> void:
	_make_combat_session()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()
	assert_true(GameSession.is_combat_active(), "Combat is active")

	# Python parity: inventory should be accessible via Tab during combat
	# The inventory engine should still work — items can be used
	var ie := GameSession.inventory_engine
	assert_not_null(ie, "Inventory engine available during combat")
	assert_not_null(GameSession.game_state, "Game state accessible")

	# Verify that we CAN read inventory (not blocked)
	var inv := GameSession.game_state.inventory
	assert_not_null(inv, "Inventory array accessible during combat")


# ── Test 4: Combat pacing settings ──

func test_combat_pacing_instant_values() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		pending("SettingsManager autoload not available in test")
		return
	sm.combat_pacing = "Instant"
	assert_eq(CombatUIPacing.dice_roll_frames(), 0, "Instant: 0 dice frames")
	assert_lte(CombatUIPacing.dice_roll_interval(), 0.001, "Instant: near-zero interval")
	assert_lte(CombatUIPacing.damage_float_duration(), 0.15, "Instant: very short float")
	assert_lte(CombatUIPacing.hit_flash_duration(), 0.1, "Instant: very short flash")
	sm.combat_pacing = "Normal"


func test_combat_pacing_slow_values() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		pending("SettingsManager autoload not available in test")
		return
	sm.combat_pacing = "Slow"
	assert_gt(CombatUIPacing.dice_roll_frames(), 8, "Slow: more than Normal frames")
	assert_gt(CombatUIPacing.dice_roll_interval(), 0.025, "Slow: longer interval")
	assert_gt(CombatUIPacing.damage_float_duration(), 0.8, "Slow: longer float")
	assert_gt(CombatUIPacing.hit_flash_duration(), 0.5, "Slow: longer flash")
	sm.combat_pacing = "Normal"


func test_combat_pacing_normal_defaults() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		pending("SettingsManager autoload not available in test")
		return
	sm.combat_pacing = "Normal"
	assert_eq(CombatUIPacing.dice_roll_frames(), 8, "Normal: 8 frames")
	assert_eq(CombatUIPacing.dice_roll_interval(), 0.025, "Normal: 25ms interval")
	assert_eq(CombatUIPacing.damage_float_duration(), 0.8, "Normal: 0.8s float")
	assert_eq(CombatUIPacing.hit_flash_duration(), 0.5, "Normal: 0.5s flash")


func test_combat_pacing_fast_values() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		pending("SettingsManager autoload not available in test")
		return
	sm.combat_pacing = "Fast"
	assert_lt(CombatUIPacing.dice_roll_frames(), 8, "Fast: fewer than Normal frames")
	assert_lt(CombatUIPacing.dice_roll_interval(), 0.025, "Fast: shorter interval")
	assert_lt(CombatUIPacing.damage_float_duration(), 0.8, "Fast: shorter float")
	assert_lt(CombatUIPacing.hit_flash_duration(), 0.5, "Fast: shorter flash")
	sm.combat_pacing = "Normal"


func test_combat_pacing_setting_persists() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		pending("SettingsManager autoload not available in test")
		return
	sm.set_combat_pacing("Fast")
	assert_eq(sm.combat_pacing, "Fast", "Pacing set to Fast")
	sm.set_combat_pacing("Normal")
	assert_eq(sm.combat_pacing, "Normal", "Pacing reset to Normal")
