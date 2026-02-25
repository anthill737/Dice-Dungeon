extends GutTest
## Deterministic combat tests.
## Every test uses DeterministicRNG so outcomes are exact and reproducible.


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func _make_state() -> GameState:
	var s := GameState.new()
	s.health = 50
	s.max_health = 50
	return s


func _make_engine(seed_val: int, state: GameState = null,
		enemy_types: Dictionary = {}, statuses: Dictionary = {}) -> CombatEngine:
	if state == null:
		state = _make_state()
	return CombatEngine.new(
		DeterministicRNG.new(seed_val), state, 3, enemy_types, statuses)


# ------------------------------------------------------------------
# DiceRoller unit tests
# ------------------------------------------------------------------

func test_dice_roll_values_in_range():
	var rng := DeterministicRNG.new(100)
	var dr := DiceRoller.new(rng, 3, 3)
	dr.roll()
	for v in dr.values:
		assert_gte(v, 1)
		assert_lte(v, 6)


func test_dice_lock_preserves_value():
	var rng := DeterministicRNG.new(200)
	var dr := DiceRoller.new(rng, 3, 3)
	dr.roll()
	var first_val: int = dr.values[0]
	dr.lock(0)
	dr.roll()
	assert_eq(dr.values[0], first_val, "locked die should keep its value")


func test_dice_rolls_decrement():
	var rng := DeterministicRNG.new(300)
	var dr := DiceRoller.new(rng, 3, 3)
	assert_eq(dr.rolls_left, 3)
	dr.roll()
	assert_eq(dr.rolls_left, 2)
	dr.roll()
	assert_eq(dr.rolls_left, 1)
	dr.roll()
	assert_eq(dr.rolls_left, 0)
	assert_false(dr.roll(), "should return false when no rolls left")


func test_dice_reset_turn():
	var rng := DeterministicRNG.new(400)
	var dr := DiceRoller.new(rng, 3, 3)
	dr.roll()
	dr.lock(0)
	dr.reset_turn(1)
	assert_eq(dr.rolls_left, 4, "3 base + 1 bonus")
	assert_false(dr.locked[0], "lock should be cleared")
	assert_eq(dr.values[0], 0, "value should be reset")


func test_dice_deterministic():
	var dr_a := DiceRoller.new(DeterministicRNG.new(500), 3, 3)
	var dr_b := DiceRoller.new(DeterministicRNG.new(500), 3, 3)
	dr_a.roll()
	dr_b.roll()
	assert_eq(dr_a.values, dr_b.values, "same seed → same dice")


# ------------------------------------------------------------------
# Combo scoring
# ------------------------------------------------------------------

func test_combo_pair():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 3, 1)
	dr.values = [5, 5, 3]
	assert_eq(dr.calc_combo_bonus(), 10, "pair of 5s = 5*2 = 10")


func test_combo_triple():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 3, 1)
	dr.values = [4, 4, 4]
	assert_eq(dr.calc_combo_bonus(), 20, "triple 4s = 4*5 = 20")


func test_combo_four_of_a_kind():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 4, 1)
	dr.values = [6, 6, 6, 6]
	assert_eq(dr.calc_combo_bonus(), 60, "quad 6s = 6*10 = 60")


func test_combo_five_of_a_kind():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 5, 1)
	dr.values = [3, 3, 3, 3, 3]
	# five-of-a-kind (3*20=60) + flush (3*15=45, all same ≥5 dice) = 105
	assert_eq(dr.calc_combo_bonus(), 105, "five 3s = 60 + flush 45 = 105")


func test_combo_full_house():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 5, 1)
	dr.values = [6, 6, 6, 2, 2]
	# triple 6s (30) + pair 2s (4) + full house (50) = 84
	assert_eq(dr.calc_combo_bonus(), 84, "full house = triple + pair + 50")


func test_combo_flush():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 5, 1)
	dr.values = [4, 4, 4, 4, 4]
	# five-of-a-kind (80) + flush (60) = 140
	assert_eq(dr.calc_combo_bonus(), 140, "flush = five-of-a-kind + flush bonus")


func test_combo_straight_full():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 6, 1)
	dr.values = [1, 2, 3, 4, 5, 6]
	assert_eq(dr.calc_combo_bonus(), 40, "1-6 straight = 40")


func test_combo_small_straight():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 5, 1)
	dr.values = [2, 3, 4, 5, 2]
	# pair of 2s (4) + small straight 2345 (25) = 29
	assert_eq(dr.calc_combo_bonus(), 29, "small straight 2-3-4-5 = 25 + pair")


func test_combo_no_combo():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 3, 1)
	dr.values = [1, 3, 5]
	assert_eq(dr.calc_combo_bonus(), 0, "no combo")


func test_total_damage():
	var rng := DeterministicRNG.new(1)
	var dr := DiceRoller.new(rng, 3, 1)
	dr.values = [6, 6, 3]
	# base = 15, combo = pair of 6s = 12, mult = 1.0, bonus = 5
	# total = int(15 * 1.0) + 12 + 5 = 32
	assert_eq(dr.calc_total_damage(1.0, 5), 32)


# ------------------------------------------------------------------
# Combat engine — basic attack
# ------------------------------------------------------------------

func test_basic_attack_deterministic():
	var engine_a := _make_engine(1000)
	var engine_b := _make_engine(1000)
	engine_a.add_enemy("Goblin", 20, 2)
	engine_b.add_enemy("Goblin", 20, 2)

	engine_a.player_roll()
	engine_b.player_roll()
	assert_eq(engine_a.dice.values, engine_b.dice.values, "same seed → same rolls")

	var turn_a := engine_a.player_attack(0)
	var turn_b := engine_b.player_attack(0)
	assert_eq(turn_a.player_damage, turn_b.player_damage, "same damage")
	assert_eq(turn_a.enemy_rolls, turn_b.enemy_rolls, "same enemy rolls")


func test_enemy_takes_damage():
	var engine := _make_engine(2000)
	var enemy := engine.add_enemy("Rat", 10, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_gt(turn.player_damage, 0, "should deal positive damage")
	assert_eq(enemy.health, 10 - turn.player_damage, "enemy HP reduced")


func test_player_takes_damage():
	var state := _make_state()
	var engine := _make_engine(3000, state)
	engine.add_enemy("Orc", 100, 3)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_lt(state.health, 50, "player should take damage from enemy")


func test_enemy_killed():
	var engine := _make_engine(4000)
	engine.add_enemy("Weakling", 1, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_true(turn.target_killed, "enemy with 1 HP should die")
	assert_eq(engine.get_alive_enemies().size(), 0)


# ------------------------------------------------------------------
# Crit
# ------------------------------------------------------------------

func test_crit_increases_damage():
	# Run two combats: one with 0% crit, one with 100% crit, same seed
	var state_no := _make_state()
	state_no.crit_chance = 0.0
	var engine_no := _make_engine(5000, state_no)
	engine_no.add_enemy("Dummy", 1000, 0)
	engine_no.player_roll()
	var turn_no := engine_no.player_attack(0)
	assert_false(turn_no.was_crit, "should not crit with 0% chance")

	var state_yes := _make_state()
	state_yes.crit_chance = 1.0
	var engine_yes := _make_engine(5000, state_yes)
	engine_yes.add_enemy("Dummy", 1000, 0)
	engine_yes.player_roll()
	var turn_yes := engine_yes.player_attack(0)
	assert_true(turn_yes.was_crit, "should crit with 100% chance")
	# Crit does 1.5x, so crit damage > non-crit damage
	assert_gt(turn_yes.player_damage, turn_no.player_damage, "crit should deal more damage")


# ------------------------------------------------------------------
# Multi-enemy
# ------------------------------------------------------------------

func test_multi_enemy_targeting():
	var engine := _make_engine(6000)
	engine.add_enemy("GoblinA", 100, 1)
	engine.add_enemy("GoblinB", 100, 1)
	engine.player_roll()

	# Attack second enemy (index 1)
	var turn := engine.player_attack(1)
	assert_eq(turn.target_name, "GoblinB", "should target second enemy")


func test_multi_enemy_all_attack():
	var state := _make_state()
	var engine := _make_engine(7000, state)
	engine.add_enemy("A", 100, 1)
	engine.add_enemy("B", 100, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_eq(turn.enemy_rolls.size(), 2, "both enemies should attack")


# ------------------------------------------------------------------
# Splitting
# ------------------------------------------------------------------

func test_split_on_death():
	var types := {
		"Slime": {
			"splits_on_death": true,
			"split_into_type": "Slime Blob",
			"split_count": 3,
			"split_hp_percent": 0.4,
			"split_dice": -1,
			"boss_abilities": []
		}
	}
	var state := _make_state()
	state.damage_bonus = 100  # guarantee one-shot
	var engine := _make_engine(8000, state, types)
	engine.add_enemy("Slime", 10, 3)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_true(turn.target_killed, "slime should die")
	assert_eq(turn.split_into.size(), 3, "should split into 3 blobs")
	# 3 original died + 3 blobs spawned, but blobs skip attack on spawn turn
	assert_eq(engine.get_alive_enemies().size(), 3, "3 blobs alive")
	# Verify blob stats
	var blob: CombatEngine.Enemy = engine.get_alive_enemies()[0]
	assert_eq(blob.name, "Slime Blob")
	assert_eq(blob.health, 4, "10 * 0.4 = 4")
	assert_eq(blob.num_dice, 2, "3 - 1 = 2")


# ------------------------------------------------------------------
# Spawning (HP threshold)
# ------------------------------------------------------------------

func test_spawn_on_hp_threshold():
	var types := {
		"Necro": {
			"boss_abilities": [{
				"type": "spawn_minions",
				"trigger": "hp_threshold",
				"hp_threshold": 0.5,
				"spawn_type": "Skeleton",
				"spawn_count": 2,
				"spawn_hp_mult": 0.3,
				"spawn_dice": 2,
			}]
		}
	}
	var state := _make_state()
	state.damage_bonus = 60  # hit hard to drop below 50%
	var engine := _make_engine(9000, state, types)
	engine.add_enemy("Necro", 100, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	# Should have triggered spawn
	assert_eq(turn.spawned.size(), 2, "should spawn 2 skeletons")
	assert_gte(engine.get_alive_enemies().size(), 2, "necro + skeletons")


# ------------------------------------------------------------------
# Periodic spawning
# ------------------------------------------------------------------

func test_periodic_spawn():
	var types := {
		"DemonLord": {
			"boss_abilities": [{
				"type": "spawn_minions_periodic",
				"trigger": "enemy_turn",
				"interval_turns": 1,
				"max_spawns": 2,
				"spawn_type": "Imp",
				"spawn_count": 1,
				"spawn_hp_mult": 0.25,
				"spawn_dice": 1,
			}]
		}
	}
	var state := _make_state()
	state.health = 200
	state.max_health = 200
	var engine := _make_engine(10000, state, types)
	engine.add_enemy("DemonLord", 500, 1)

	# Turn 1
	engine.player_roll()
	var t1 := engine.player_attack(0)
	assert_eq(t1.spawned.size(), 1, "should spawn 1 imp on turn 1")

	# Turn 2
	engine.player_roll()
	var t2 := engine.player_attack(0)
	assert_eq(t2.spawned.size(), 1, "should spawn 1 imp on turn 2")

	# Turn 3 — max reached
	engine.player_roll()
	var t3 := engine.player_attack(0)
	assert_eq(t3.spawned.size(), 0, "max spawns reached, no more")


# ------------------------------------------------------------------
# Status effects
# ------------------------------------------------------------------

func test_status_tick_damage():
	var statuses := {
		"Poison": {"tick_damage": 5, "turns": 2}
	}
	var state := _make_state()
	state.flags["statuses"] = ["Poison"]
	var engine := _make_engine(11000, state, {}, statuses)
	engine.add_enemy("Dummy", 1000, 0)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_eq(turn.status_tick_damage, 5, "should take 5 poison damage")
	assert_eq(state.health, 50 - 5 - turn.player_damage * 0,  # no enemy damage (0 dice)
		"HP should be reduced by poison")


func test_status_expires():
	# Use a deep-copy of statuses so mutation doesn't leak between tests
	var statuses := {
		"Burn": {"tick_damage": 3, "turns": 1}
	}
	var state := _make_state()
	state.flags["statuses"] = ["Burn"]
	var engine := _make_engine(12000, state, {}, statuses)
	engine.add_enemy("Dummy", 1000, 0)

	engine.player_roll()
	engine.player_attack(0)
	# After 1 tick with turns=1, status should be removed
	assert_false(state.flags["statuses"].has("Burn"), "burn should expire after 1 turn")


func test_inflict_status_ability():
	var types := {
		"Poisoner": {
			"boss_abilities": [{
				"type": "inflict_status",
				"trigger": "enemy_turn",
				"interval_turns": 1,
				"status_name": "Poison",
			}]
		}
	}
	var state := _make_state()
	var engine := _make_engine(13000, state, types)
	engine.add_enemy("Poisoner", 100, 1)
	engine.player_roll()
	engine.player_attack(0)
	assert_true(state.flags["statuses"].has("Poison"), "should be poisoned")


# ------------------------------------------------------------------
# Shield absorb
# ------------------------------------------------------------------

func test_shield_absorbs_damage():
	var state := _make_state()
	state.temp_shield = 100  # big shield
	var engine := _make_engine(14000, state)
	engine.add_enemy("Hitter", 1000, 3)
	engine.player_roll()
	var turn := engine.player_attack(0)
	# All enemy damage should be absorbed by shield
	assert_eq(state.health, 50, "shield should absorb all enemy damage")
	assert_lt(state.temp_shield, 100, "shield should be reduced")


# ------------------------------------------------------------------
# Flee
# ------------------------------------------------------------------

func test_flee_deterministic():
	var engine_a := _make_engine(15000)
	var engine_b := _make_engine(15000)
	assert_eq(engine_a.attempt_flee(), engine_b.attempt_flee(), "same seed → same flee result")


# ------------------------------------------------------------------
# Full auto-combat determinism
# ------------------------------------------------------------------

func test_auto_combat_deterministic():
	var lock_high = func(dr: DiceRoller):
		for i in dr.num_dice:
			if dr.values[i] >= 5:
				dr.lock(i)

	var state_a := _make_state()
	state_a.health = 100
	state_a.max_health = 100
	var engine_a := _make_engine(20000, state_a)
	engine_a.add_enemy("Goblin", 30, 2)
	var result_a := engine_a.run_auto_combat(lock_high)

	var state_b := _make_state()
	state_b.health = 100
	state_b.max_health = 100
	var engine_b := _make_engine(20000, state_b)
	engine_b.add_enemy("Goblin", 30, 2)
	var result_b := engine_b.run_auto_combat(lock_high)

	assert_eq(result_a.victory, result_b.victory, "same outcome")
	assert_eq(result_a.turns.size(), result_b.turns.size(), "same turn count")
	assert_eq(result_a.total_damage_dealt, result_b.total_damage_dealt, "same total damage")
	assert_eq(result_a.total_damage_taken, result_b.total_damage_taken, "same total taken")


func test_auto_combat_different_seed_differs():
	var lock_high = func(dr: DiceRoller):
		for i in dr.num_dice:
			if dr.values[i] >= 5:
				dr.lock(i)

	var state_a := _make_state()
	state_a.health = 100
	state_a.max_health = 100
	var engine_a := _make_engine(30000, state_a)
	engine_a.add_enemy("Goblin", 30, 2)
	var result_a := engine_a.run_auto_combat(lock_high)

	var state_b := _make_state()
	state_b.health = 100
	state_b.max_health = 100
	var engine_b := _make_engine(30001, state_b)
	engine_b.add_enemy("Goblin", 30, 2)
	var result_b := engine_b.run_auto_combat(lock_high)

	# At least one metric should differ
	var differs := (result_a.total_damage_dealt != result_b.total_damage_dealt or
		result_a.total_damage_taken != result_b.total_damage_taken or
		result_a.turns.size() != result_b.turns.size())
	assert_true(differs, "different seeds should produce different combat")


# ------------------------------------------------------------------
# Real enemy_types.json integration
# ------------------------------------------------------------------

func test_real_slime_split():
	var etd := EnemyTypesData.new()
	etd.load()
	var state := _make_state()
	state.damage_bonus = 200
	var engine := CombatEngine.new(DeterministicRNG.new(40000), state, 3, etd.enemies)
	engine.add_enemy("Gelatinous Slime", 20, 2)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_true(turn.target_killed, "slime should die with 200 bonus damage")
	assert_eq(turn.split_into.size(), 3, "should split into 3 Slime Blobs")
	var blob: CombatEngine.Enemy = engine.get_alive_enemies()[0]
	assert_eq(blob.name, "Slime Blob")
