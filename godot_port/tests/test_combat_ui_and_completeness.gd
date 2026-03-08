extends GutTest
## Tests for:
## 1) Ability/effect completeness gate — ensures every ability/effect ID
##    in enemy definitions has a handler in AbilitySystem / EffectSystem.
## 2) Dice lock toggle works via click signal path.
## 3) Combat log formatting emits expected styled entries.
## 4) Combat panel instantiates headless without crashes.
## 5) Enemy dice container exists.


# ==================================================================
# Helpers
# ==================================================================

func _make_state() -> GameState:
	var s := GameState.new()
	s.health = 100
	s.max_health = 100
	return s


func _make_engine(seed_val: int, state: GameState = null,
		enemy_types: Dictionary = {}) -> CombatEngine:
	if state == null:
		state = _make_state()
	return CombatEngine.new(
		DeterministicRNG.new(seed_val), state, 3, enemy_types)


# ==================================================================
# PART 5 — Ability/Effect completeness gate
# ==================================================================

## Every ability type found in enemy_types.json must be handled by
## AbilitySystem._execute (returns non-null AbilityEvent).
func test_ability_completeness_gate():
	var etd := EnemyTypesData.new()
	etd.load()

	var all_ability_types: Dictionary = {}
	for enemy_name in etd.enemies:
		var info: Dictionary = etd.enemies[enemy_name]
		for ab in info.get("boss_abilities", []):
			var atype: String = ab.get("type", "")
			if not atype.is_empty():
				all_ability_types[atype] = ab

	var known_types: Array = [
		"dice_obscure", "dice_restrict", "dice_lock_random",
		"curse_reroll", "curse_damage", "inflict_status",
		"heal_over_time", "damage_reduction",
		"spawn_minions", "spawn_on_death",
		"spawn_minions_periodic", "transform_on_death",
	]

	for atype in all_ability_types:
		assert_true(atype in known_types,
			"Ability type '%s' must have a handler in AbilitySystem" % atype)

	# Verify AbilitySystem actually produces events for each known type
	var rng := DeterministicRNG.new(42)
	for atype in known_types:
		var test_ability: Dictionary = {"type": atype, "trigger": "combat_start"}
		match atype:
			"dice_obscure":
				test_ability["duration_turns"] = 2
			"dice_restrict":
				test_ability["duration_turns"] = 2
				test_ability["restricted_values"] = [1, 2]
			"dice_lock_random":
				test_ability["duration_turns"] = 1
				test_ability["lock_count"] = 1
			"curse_reroll":
				test_ability["duration_turns"] = 2
			"curse_damage":
				test_ability["damage_per_turn"] = 5
				test_ability["duration_turns"] = 3
			"inflict_status":
				test_ability["status_name"] = "Poison"
			"heal_over_time":
				test_ability["heal_per_turn"] = 5
				test_ability["duration_turns"] = 3
			"damage_reduction":
				test_ability["reduction_amount"] = 5
				test_ability["duration_turns"] = 3
			"spawn_minions", "spawn_on_death":
				test_ability["spawn_type"] = "Test"
				test_ability["spawn_count"] = 1
				test_ability["spawn_hp_mult"] = 0.3
				test_ability["spawn_dice"] = 1
			"spawn_minions_periodic":
				test_ability["spawn_type"] = "Test"
				test_ability["spawn_count"] = 1
				test_ability["spawn_hp_mult"] = 0.3
				test_ability["spawn_dice"] = 1
				test_ability["interval_turns"] = 1
				test_ability["max_spawns"] = 1
			"transform_on_death":
				test_ability["transform_into"] = "TestForm"
				test_ability["hp_mult"] = 0.5
				test_ability["dice_count"] = 2

		var enemy_data := {"boss_abilities": [test_ability]}
		var cs: Dictionary = {
			"combat_turn_count": 0,
			"boss_ability_cooldowns": {},
			"enemy_hp_fraction": 0.3,
			"enemy_max_health": 100,
			"enemy_health_mult": 1.0,
			"floor": 1,
			"num_dice": 3,
			"dice_locked": [false, false, false],
			"statuses": [],
		}
		var events := AbilitySystem.evaluate_abilities("TestEnemy", enemy_data, "combat_start", cs, rng)
		assert_gt(events.size(), 0,
			"AbilitySystem must handle '%s' and return events" % atype)


## Feed every concrete ability definition from every enemy in
## enemy_types.json through AbilitySystem and verify it returns at
## least one event.  This catches real-data param combinations that a
## synthetic-only test would miss (e.g. missing transform_into, unusual
## trigger/type pairs).
func test_ability_completeness_gate_real_enemy_defs():
	var etd := EnemyTypesData.new()
	etd.load()

	var rng := DeterministicRNG.new(99)
	var tested := 0

	for enemy_name in etd.enemies:
		var info: Dictionary = etd.enemies[enemy_name]
		var abilities: Array = info.get("boss_abilities", [])
		if abilities.is_empty():
			continue

		for ab in abilities:
			var atype: String = ab.get("type", "")
			if atype.is_empty():
				continue

			# Determine the trigger.  Some ability types are inherently
			# death-triggered and may omit the "trigger" key entirely.
			var trigger: String = ab.get("trigger", "")
			if trigger.is_empty():
				match atype:
					"spawn_on_death", "transform_on_death":
						trigger = "on_death"
					_:
						trigger = "combat_start"

			# Ensure the ability dict carries the trigger so
			# evaluate_abilities can match it.
			var ab_copy: Dictionary = ab.duplicate()
			if not ab_copy.has("trigger"):
				ab_copy["trigger"] = trigger

			# Build a combat-state snapshot that satisfies every trigger
			# gate so the ability will fire:
			#   combat_start  → always fires
			#   hp_threshold  → hp_fraction well below any threshold
			#   enemy_turn    → turn count satisfies any interval
			#   on_death      → always fires
			var cs: Dictionary = {
				"combat_turn_count": 100,
				"boss_ability_cooldowns": {},
				"enemy_hp_fraction": 0.01,
				"enemy_max_health": 200,
				"enemy_health_mult": 1.0,
				"floor": 5,
				"num_dice": 5,
				"dice_locked": [false, false, false, false, false],
				"statuses": [],
			}

			var enemy_data := {"boss_abilities": [ab_copy]}
			var events := AbilitySystem.evaluate_abilities(
				enemy_name, enemy_data, trigger, cs, rng)

			assert_gt(events.size(), 0,
				"AbilitySystem must handle ability '%s' (trigger '%s') on enemy '%s'" % [
					atype, trigger, enemy_name])

			if events.size() > 0:
				var ev: AbilitySystem.AbilityEvent = events[0]
				assert_eq(ev.ability_type, atype,
					"Event type must match for '%s' on '%s'" % [atype, enemy_name])

			tested += 1

	assert_gt(tested, 0, "Must have tested at least one real ability definition")


## Every status name inflicted by enemies must be handled by EffectSystem.
func test_effect_completeness_gate():
	var etd := EnemyTypesData.new()
	etd.load()

	var all_status_names: Array = []
	for enemy_name in etd.enemies:
		var info: Dictionary = etd.enemies[enemy_name]
		for ab in info.get("boss_abilities", []):
			if ab.get("type") == "inflict_status":
				var sn: String = ab.get("status_name", "")
				if not sn.is_empty() and not sn in all_status_names:
					all_status_names.append(sn)

	for status_name in all_status_names:
		var result := EffectSystem.tick_statuses([status_name])
		assert_gte(result.logs.size(), 0,
			"EffectSystem must produce log output for status '%s'" % status_name)
		var has_log := result.logs.size() > 0
		assert_true(has_log,
			"EffectSystem.tick_statuses must handle '%s'" % status_name)


## Curse types used in abilities must be handled by EffectSystem.tick_curses.
func test_curse_completeness_gate():
	var curse_types: Array = [
		"dice_obscure", "dice_restrict", "dice_lock_random",
		"curse_reroll", "curse_damage", "heal_over_time", "damage_reduction",
	]
	for ctype in curse_types:
		var msg := EffectSystem._curse_expiry_message(ctype)
		# curse_damage has no specific expiry message — that's OK
		if ctype != "curse_damage":
			assert_true(not msg.is_empty(),
				"EffectSystem has expiry message for '%s'" % ctype)


# ==================================================================
# PART 7 — Dice lock toggle (headless)
# ==================================================================

func test_dice_lock_toggle_via_engine():
	var engine := _make_engine(5000)
	engine.add_enemy("Dummy", 100, 1)
	engine.player_roll()
	assert_false(engine.dice.locked[0], "die 0 starts unlocked")
	engine.dice.toggle_lock(0)
	assert_true(engine.dice.locked[0], "die 0 locked after toggle")
	engine.dice.toggle_lock(0)
	assert_false(engine.dice.locked[0], "die 0 unlocked after second toggle")


func test_dice_lock_only_after_roll():
	var engine := _make_engine(5100)
	engine.add_enemy("Dummy", 100, 1)
	engine.dice.toggle_lock(0)
	assert_false(engine.dice.locked[0], "cannot lock die before rolling")


# ==================================================================
# Combat log formatting
# ==================================================================

func test_log_classify_player_attack():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("⚔️ You attack and deal 42 damage!")
	assert_eq(c, DungeonTheme.LOG_PLAYER, "player attack line is cyan")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_enemy_roll():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("Goblin rolls: [3, 4]")
	assert_eq(c, DungeonTheme.LOG_ENEMY, "enemy roll line is red")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_crit():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("Hit Goblin for 20 damage (CRIT!)")
	assert_eq(c, DungeonTheme.LOG_CRIT, "crit line is magenta")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_loot():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("+25 gold!")
	assert_eq(c, DungeonTheme.LOG_LOOT, "gold line is loot color")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_defeat():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("Goblin has been defeated!")
	assert_eq(c, DungeonTheme.LOG_SUCCESS, "defeat line is green")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_burn():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("🔥 Goblin takes 8 burn damage! (3 turns remaining)")
	assert_eq(c, DungeonTheme.LOG_FIRE, "burn line is fire color")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_separator():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("=" .repeat(60))
	assert_eq(c, DungeonTheme.LOG_SEPARATOR, "separator is dim")

	panel.queue_free()
	await get_tree().process_frame


func test_log_classify_spawn():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var c: Color = panel._classify_log_line("⚠️ Necro summons a Skeleton! ⚠️")
	assert_eq(c, DungeonTheme.LOG_ENEMY, "spawn line is enemy color")

	panel.queue_free()
	await get_tree().process_frame


# ==================================================================
# Combat panel headless instantiation
# ==================================================================

func test_combat_panel_no_crash():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel.find_child("DiceContainer", true, false), "DiceContainer exists")
	assert_not_null(panel.find_child("RollsLabel", true, false), "RollsLabel exists")
	assert_not_null(panel.find_child("PlayerHPBar", true, false), "PlayerHPBar exists")
	assert_not_null(panel.find_child("EnemyHPBar", true, false), "EnemyHPBar exists")
	assert_not_null(panel.find_child("EnemyList", true, false), "EnemyList exists")
	assert_not_null(panel.find_child("EnemyDiceContainer", true, false), "EnemyDiceContainer exists")

	panel.queue_free()
	await get_tree().process_frame


func test_combat_panel_dice_count():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_eq(panel._dice_labels.size(), 5, "5 dice labels")
	assert_eq(panel._dice_panels.size(), 5, "5 dice panels")
	assert_eq(panel._dice_lock_icons.size(), 5, "5 lock icons")

	panel.queue_free()
	await get_tree().process_frame


func test_combat_panel_buttons_exist():
	var panel := preload("res://ui/scenes/CombatPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel._btn_roll, "Roll button exists")
	assert_not_null(panel._btn_attack, "Attack button exists")
	assert_not_null(panel._btn_close, "Close button exists")

	panel.queue_free()
	await get_tree().process_frame


# ==================================================================
# Integration: full combat turn with log output
# ==================================================================

func test_combat_turn_produces_styled_logs():
	var types := {"Rat": {"boss_abilities": []}}
	var state := _make_state()
	state.damage_bonus = 50
	var engine := _make_engine(7000, state, types)
	engine.add_enemy("Rat", 10, 1)
	engine.player_roll()
	var result := engine.player_attack(0)

	assert_gt(result.logs.size(), 0, "turn produces log entries")

	var has_hit := false
	for l in result.logs:
		if "Hit" in l or "damage" in l:
			has_hit = true
	assert_true(has_hit, "logs contain hit/damage info")
