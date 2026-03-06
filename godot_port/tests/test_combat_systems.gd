extends GutTest
## Deterministic tests for modular combat systems:
## AbilitySystem, EffectSystem, RewardResolver, EnemySpawnResolver,
## CombatLogFormatter.
##
## Every test uses DeterministicRNG and fixed seeds.


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func _make_state() -> GameState:
	var s := GameState.new()
	s.health = 100
	s.max_health = 100
	return s


func _make_engine(seed_val: int, state: GameState = null,
		enemy_types: Dictionary = {}, statuses: Dictionary = {}) -> CombatEngine:
	if state == null:
		state = _make_state()
	return CombatEngine.new(
		DeterministicRNG.new(seed_val), state, 3, enemy_types, statuses)


# ==================================================================
# AbilitySystem tests
# ==================================================================

# -- dice_obscure --

func test_ability_dice_obscure_combat_start():
	var ability := {
		"type": "dice_obscure",
		"trigger": "combat_start",
		"duration_turns": 3,
		"message": "Shadows cloud your vision!",
	}
	var types := {"Shadow": {"boss_abilities": [ability]}}
	var engine := _make_engine(100, null, types)
	engine.add_enemy("Shadow", 100, 2)
	var logs := engine.trigger_combat_start_abilities()
	assert_true(engine.dice_obscured, "dice should be obscured")
	assert_eq(engine.active_curses.size(), 1, "one curse active")
	assert_eq(engine.active_curses[0]["type"], "dice_obscure")
	assert_eq(engine.active_curses[0]["turns_left"], 3)
	assert_true(logs.size() > 0, "should produce log entries")
	var has_msg := false
	for l in logs:
		if "Shadows cloud your vision" in l:
			has_msg = true
	assert_true(has_msg, "ability message logged")


# -- dice_restrict --

func test_ability_dice_restrict():
	var ability := {
		"type": "dice_restrict",
		"trigger": "combat_start",
		"duration_turns": 2,
		"restricted_values": [1, 2],
		"message": "Only low values!",
	}
	var types := {"Curse Mage": {"boss_abilities": [ability]}}
	var engine := _make_engine(200, null, types)
	engine.add_enemy("Curse Mage", 100, 2)
	engine.trigger_combat_start_abilities()
	assert_eq(engine.dice_restricted_values, [1, 2])
	engine.player_roll()
	for v in engine.dice.values:
		assert_true(v == 1 or v == 2, "dice value %d must be 1 or 2" % v)


# -- dice_lock_random --

func test_ability_dice_lock_random():
	var ability := {
		"type": "dice_lock_random",
		"trigger": "combat_start",
		"duration_turns": 2,
		"lock_count": 2,
		"message": "Two dice are bound!",
	}
	var types := {"Binder": {"boss_abilities": [ability]}}
	var engine := _make_engine(300, null, types)
	engine.add_enemy("Binder", 100, 2)
	engine.trigger_combat_start_abilities()
	assert_eq(engine.forced_dice_locks.size(), 2, "2 dice locked")
	for idx in engine.forced_dice_locks:
		assert_true(engine.dice.locked[idx], "die %d should be locked" % idx)
		assert_gt(engine.dice.values[idx], 0, "locked die %d should have value" % idx)


# -- curse_reroll --

func test_ability_curse_reroll():
	var ability := {
		"type": "curse_reroll",
		"trigger": "combat_start",
		"duration_turns": 3,
		"message": "Cursed rerolls!",
	}
	var types := {"Necro": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.reroll_bonus = 2
	var engine := _make_engine(400, state, types)
	engine.add_enemy("Necro", 100, 1)
	engine.trigger_combat_start_abilities()
	assert_lte(engine.dice.rolls_left, 1, "rolls limited to 1")


# -- curse_damage --

func test_ability_curse_damage():
	var ability := {
		"type": "curse_damage",
		"trigger": "combat_start",
		"damage_per_turn": 7,
		"duration_turns": 3,
		"message": "Cursed! 7 dmg/turn",
	}
	var types := {"Demon": {"boss_abilities": [ability]}}
	var state := _make_state()
	var engine := _make_engine(500, state, types)
	engine.add_enemy("Demon", 200, 1)
	engine.trigger_combat_start_abilities()
	assert_eq(engine.active_curses.size(), 1)
	assert_eq(engine.active_curses[0]["damage"], 7)

	var hp_before := state.health
	engine.player_roll()
	var turn := engine.player_attack(0)
	var enemy_dmg := 0
	for er in turn.enemy_rolls:
		enemy_dmg += int(er["damage"])
	assert_eq(state.health, hp_before - 7 - enemy_dmg,
		"curse damage + enemy damage should be applied")
	var has_curse_log := false
	for l in turn.logs:
		if "Curse damage" in l and "7" in l:
			has_curse_log = true
	assert_true(has_curse_log, "curse damage log present")


# -- inflict_status --

func test_ability_inflict_status_combat_start():
	var ability := {
		"type": "inflict_status",
		"trigger": "combat_start",
		"status_name": "Burn",
		"message": "You catch fire!",
	}
	var types := {"Fire Imp": {"boss_abilities": [ability]}}
	var state := _make_state()
	var engine := _make_engine(600, state, types)
	engine.add_enemy("Fire Imp", 100, 1)
	engine.trigger_combat_start_abilities()
	assert_true(state.flags["statuses"].has("Burn"), "should have Burn status")


func test_ability_inflict_status_no_duplicate():
	var ability := {
		"type": "inflict_status",
		"trigger": "combat_start",
		"status_name": "Poison",
		"message": "Poisoned!",
	}
	var types := {"Snake": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.flags["statuses"] = ["Poison"]
	var engine := _make_engine(700, state, types)
	engine.add_enemy("Snake", 100, 1)
	engine.trigger_combat_start_abilities()
	var count := 0
	for s in state.flags["statuses"]:
		if s == "Poison":
			count += 1
	assert_eq(count, 1, "should not duplicate Poison")


# -- heal_over_time --

func test_ability_heal_over_time():
	var ability := {
		"type": "heal_over_time",
		"trigger": "combat_start",
		"heal_per_turn": 10,
		"duration_turns": 3,
		"message": "Regenerating!",
	}
	var types := {"Troll": {"boss_abilities": [ability]}}
	var state := _make_state()
	var engine := _make_engine(800, state, types)
	var enemy := engine.add_enemy("Troll", 100, 1)
	engine.trigger_combat_start_abilities()
	enemy.health = 80

	engine.player_roll()
	var turn := engine.player_attack(0)
	var has_regen := false
	for l in turn.logs:
		if "regenerates" in l:
			has_regen = true
	assert_true(has_regen, "should log regeneration")


# -- damage_reduction --

func test_ability_damage_reduction():
	var ability := {
		"type": "damage_reduction",
		"trigger": "combat_start",
		"reduction_amount": 15,
		"duration_turns": 999,
		"message": "Armored!",
	}
	var types := {"Knight": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.damage_bonus = 50
	var engine := _make_engine(900, state, types)
	var enemy := engine.add_enemy("Knight", 500, 0)
	engine.trigger_combat_start_abilities()
	assert_eq(enemy.damage_reduction, 15, "enemy should have 15 DR")

	engine.player_roll()
	var turn := engine.player_attack(0)
	var has_dr_log := false
	for l in turn.logs:
		if "defenses reduce" in l:
			has_dr_log = true
	assert_true(has_dr_log, "should log damage reduction")


# -- spawn_minions (hp_threshold) --

func test_ability_spawn_minions_hp_threshold():
	var ability := {
		"type": "spawn_minions",
		"trigger": "hp_threshold",
		"hp_threshold": 0.5,
		"spawn_type": "Skeleton",
		"spawn_count": 2,
		"spawn_hp_mult": 0.3,
		"spawn_dice": 2,
		"message": "Rise, minions!",
	}
	var types := {"Necro": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.damage_bonus = 60
	var engine := _make_engine(1000, state, types)
	engine.add_enemy("Necro", 100, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_eq(turn.spawned.size(), 2, "should spawn 2 skeletons")
	assert_gte(engine.get_alive_enemies().size(), 2, "necro + skeletons")


# -- spawn_on_death --

func test_ability_spawn_on_death():
	var ability := {
		"type": "spawn_on_death",
		"trigger": "on_death",
		"spawn_type": "Ghost",
		"spawn_count": 3,
		"spawn_hp_mult": 0.2,
		"spawn_dice": 1,
		"message": "From my ashes...",
	}
	var types := {"Wraith": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.damage_bonus = 200
	var engine := _make_engine(1100, state, types)
	engine.add_enemy("Wraith", 10, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_true(turn.target_killed, "wraith should die")
	var ghost_count := 0
	for s in turn.spawned:
		if s == "Ghost":
			ghost_count += 1
	assert_eq(ghost_count, 3, "should spawn 3 ghosts")


# -- transform_on_death --

func test_ability_transform_on_death():
	var ability := {
		"type": "transform_on_death",
		"trigger": "on_death",
		"transform_into": "Dark Form",
		"hp_mult": 1.0,
		"dice_count": 4,
		"message": "I am reborn!",
	}
	var types := {
		"Mage": {"boss_abilities": [ability]},
		"Dark Form": {"boss_abilities": []},
	}
	var state := _make_state()
	state.damage_bonus = 200
	var engine := _make_engine(1200, state, types)
	engine.add_enemy("Mage", 10, 1)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_true(turn.target_killed, "mage should die")
	var alive := engine.get_alive_enemies()
	assert_gt(alive.size(), 0, "Dark Form should exist")
	assert_eq(alive[0].name, "Dark Form")


# -- hp_threshold cooldown (only once) --

func test_ability_hp_threshold_fires_once():
	var ability := {
		"type": "inflict_status",
		"trigger": "hp_threshold",
		"hp_threshold": 0.5,
		"status_name": "Bleed",
		"message": "Bleeding!",
	}
	var types := {"Boss": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.damage_bonus = 60
	var engine := _make_engine(1300, state, types)
	engine.add_enemy("Boss", 100, 0)

	engine.player_roll()
	engine.player_attack(0)
	assert_true(state.flags["statuses"].has("Bleed"), "first trigger inflicts Bleed")

	state.flags["statuses"] = []
	engine.player_roll()
	engine.player_attack(0)
	# cooldown prevents re-triggering via hp_threshold
	# but _handle_inflict_status (enemy_turn path) won't fire for hp_threshold trigger
	assert_false(state.flags["statuses"].has("Bleed"),
		"hp_threshold should not re-trigger")


# -- enemy_turn interval --

func test_ability_enemy_turn_interval():
	var ability := {
		"type": "inflict_status",
		"trigger": "enemy_turn",
		"interval_turns": 2,
		"status_name": "Rot",
		"message": "Rotting!",
	}
	var types := {"Zombie": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.health = 200
	var engine := _make_engine(1400, state, types)
	engine.add_enemy("Zombie", 500, 0)

	engine.player_roll()
	engine.player_attack(0)
	assert_false(state.flags["statuses"].has("Rot"), "turn 1: no Rot (interval=2)")

	state.flags["statuses"] = []
	engine.player_roll()
	engine.player_attack(0)
	assert_true(state.flags["statuses"].has("Rot"), "turn 2: Rot inflicted")


# ==================================================================
# EffectSystem tests
# ==================================================================

# -- Curse tick --

func test_effect_curse_damage_tick():
	var curses := [{
		"type": "curse_damage",
		"turns_left": 3,
		"damage": 8,
		"message": "burning curse",
	}]
	var result := EffectSystem.tick_curses(curses, [], 100)
	assert_eq(result.curse_damage_total, 8)
	assert_eq(curses[0]["turns_left"], 2, "duration decremented")
	assert_true(result.removed_indices.is_empty(), "not yet expired")


func test_effect_curse_expires():
	var curses := [{
		"type": "dice_obscure",
		"turns_left": 1,
		"message": "hidden",
	}]
	var result := EffectSystem.tick_curses(curses, [], 100)
	assert_eq(result.removed_indices.size(), 1)
	assert_eq(result.expired.size(), 1)
	assert_eq(result.expired[0]["type"], "dice_obscure")
	var has_expiry := false
	for l in result.logs:
		if "vision clears" in l:
			has_expiry = true
	assert_true(has_expiry, "expiry message logged")


func test_effect_curse_removed_when_enemy_dies():
	var curses := [{
		"type": "heal_over_time",
		"turns_left": 5,
		"heal_amount": 10,
		"target_enemy_name": "Troll",
		"message": "regen",
	}]
	var result := EffectSystem.tick_curses(curses, [], 100)
	assert_eq(result.removed_indices.size(), 1, "curse removed when target gone")


# -- Status tick --

func test_effect_status_poison_damage():
	var result := EffectSystem.tick_statuses(["Poison"])
	assert_eq(result.damage, 5)
	assert_eq(result.logs.size(), 1)
	assert_true("Poison" in result.logs[0])


func test_effect_status_bleed_damage():
	var result := EffectSystem.tick_statuses(["Bleed"])
	assert_eq(result.damage, 5)
	assert_true("bleed damage" in result.logs[0])


func test_effect_status_burn_damage():
	var result := EffectSystem.tick_statuses(["Burn"])
	assert_eq(result.damage, 5)
	assert_true("fire damage" in result.logs[0])


func test_effect_status_rot_damage():
	var result := EffectSystem.tick_statuses(["Rot"])
	assert_eq(result.damage, 5)


func test_effect_status_choke_no_damage():
	var result := EffectSystem.tick_statuses(["Soot-Choke"])
	assert_eq(result.damage, 0)
	assert_true("weakened" in result.logs[0])


func test_effect_status_hunger_no_damage():
	var result := EffectSystem.tick_statuses(["Hunger"])
	assert_eq(result.damage, 0)
	assert_true("hunger" in result.logs[0])


func test_effect_status_multiple():
	var result := EffectSystem.tick_statuses(["Poison", "Burn", "Bleed"])
	assert_eq(result.damage, 15, "5+5+5")
	assert_eq(result.logs.size(), 3)


# -- Enemy burn tick --

func test_effect_enemy_burn_sequence():
	var enemy := CombatEngine.Enemy.new("Goblin", 100, 2)
	var burn := {0: {"initial_damage": 8, "turns_remaining": 3}}
	var result := EffectSystem.tick_enemy_burns(burn, [enemy])
	assert_eq(result.ticks.size(), 1)
	assert_eq(result.ticks[0]["damage"], 8, "turn 3 → 8 damage")

	var burn2 := {0: {"initial_damage": 8, "turns_remaining": 2}}
	var result2 := EffectSystem.tick_enemy_burns(burn2, [enemy])
	assert_eq(result2.ticks[0]["damage"], 5, "turn 2 → 5 damage")

	var burn3 := {0: {"initial_damage": 8, "turns_remaining": 1}}
	var result3 := EffectSystem.tick_enemy_burns(burn3, [enemy])
	assert_eq(result3.ticks[0]["damage"], 2, "turn 1 → 2 damage")
	assert_eq(result3.expired.size(), 1, "burn expires after turn 1")


func test_effect_enemy_burn_death():
	var enemy := CombatEngine.Enemy.new("Weak", 5, 1)
	var burn := {0: {"initial_damage": 8, "turns_remaining": 3}}
	var result := EffectSystem.tick_enemy_burns(burn, [enemy])
	assert_eq(result.deaths.size(), 1, "enemy should die from burn")
	var has_death := false
	for l in result.logs:
		if "burned to death" in l:
			has_death = true
	assert_true(has_death, "burn death logged")


# ==================================================================
# RewardResolver tests
# ==================================================================

func test_reward_normal_enemy():
	var rng := DeterministicRNG.new(2000)
	var result := RewardResolver.resolve(rng, 3, false, false)
	assert_false(result.is_boss)
	assert_false(result.is_mini_boss)
	assert_gte(result.gold, 10 + 15, "min gold = 10 + floor*5")
	assert_lte(result.gold, 30 + 15, "max gold = 30 + floor*5")
	assert_eq(result.score, 100 + 60, "100 + floor*20")
	assert_eq(result.items.size(), 0)
	assert_false(result.key_fragment)
	assert_eq(result.logs.size(), 1)
	assert_true("+%d gold!" % result.gold in result.logs[0])


func test_reward_mini_boss():
	var rng := DeterministicRNG.new(2100)
	var result := RewardResolver.resolve(rng, 5, false, true, 1)
	assert_true(result.is_mini_boss)
	assert_gte(result.gold, 50 + 100)
	assert_lte(result.gold, 80 + 100)
	assert_eq(result.score, 500 + 250)
	assert_true(result.key_fragment)
	assert_eq(result.key_fragments_total, 2)
	assert_eq(result.items.size(), 1)
	var has_fragment_log := false
	for l in result.logs:
		if "Boss Key Fragment" in l:
			has_fragment_log = true
	assert_true(has_fragment_log)


func test_reward_boss():
	var rng := DeterministicRNG.new(2200)
	var result := RewardResolver.resolve(rng, 2, true, false)
	assert_true(result.is_boss)
	assert_gte(result.gold, 200 + 200)
	assert_lte(result.gold, 350 + 200)
	assert_eq(result.score, 1000 + 400)
	assert_gte(result.items.size(), 3)
	assert_lte(result.items.size(), 5)
	var has_boss_log := false
	for l in result.logs:
		if "FLOOR BOSS DEFEATED" in l:
			has_boss_log = true
	assert_true(has_boss_log)


func test_reward_mini_boss_loot_pool_floor_scaling():
	var rng_low := DeterministicRNG.new(2300)
	var result_low := RewardResolver.resolve(rng_low, 2, false, true)
	assert_true(result_low.items[0] in RewardResolver.MINI_BOSS_LOOT_EARLY,
		"floor 2 uses early loot pool")

	var rng_mid := DeterministicRNG.new(2300)
	var result_mid := RewardResolver.resolve(rng_mid, 6, false, true)
	assert_true(result_mid.items[0] in RewardResolver.MINI_BOSS_LOOT_MID,
		"floor 6 uses mid loot pool")

	var rng_high := DeterministicRNG.new(2300)
	var result_high := RewardResolver.resolve(rng_high, 9, false, true)
	assert_true(result_high.items[0] in RewardResolver.MINI_BOSS_LOOT_HIGH,
		"floor 9 uses high loot pool")


func test_reward_deterministic():
	var r1 := RewardResolver.resolve(DeterministicRNG.new(2400), 3, false, false)
	var r2 := RewardResolver.resolve(DeterministicRNG.new(2400), 3, false, false)
	assert_eq(r1.gold, r2.gold, "same seed → same gold")
	assert_eq(r1.score, r2.score)


# ==================================================================
# EnemySpawnResolver tests
# ==================================================================

func test_spawn_resolver_hp_threshold():
	var config := {
		"can_spawn": true,
		"max_spawns": 2,
		"spawn_trigger": "hp_threshold",
		"spawn_hp_threshold": 0.5,
		"spawn_type": "Skeleton",
		"spawn_count": 2,
		"spawn_hp_mult": 0.3,
		"spawn_dice": 2,
	}
	var enemy := {"name": "Boss", "health": 40, "max_health": 100,
		"config": config, "spawns_used": 0}
	var events := EnemySpawnResolver.check_spawn_conditions([enemy], 1)
	assert_eq(events.size(), 2, "should spawn 2 skeletons")
	assert_eq(events[0].spawn_type, "Skeleton")
	assert_eq(events[0].hp, maxi(10, int(100 * 0.3)))


func test_spawn_resolver_turn_count():
	var config := {
		"can_spawn": true,
		"max_spawns": 4,
		"spawn_trigger": "turn_count",
		"spawn_turn_interval": 3,
		"spawn_type": "Imp",
		"spawn_count": 1,
		"spawn_hp_mult": 0.25,
		"spawn_dice": 1,
	}
	var enemy := {"name": "Demon", "health": 100, "max_health": 100,
		"config": config, "spawns_used": 0, "turn_spawned": 0}

	var e1 := EnemySpawnResolver.check_spawn_conditions([enemy], 1)
	assert_eq(e1.size(), 0, "turn 1: no spawn (interval=3)")

	var e3 := EnemySpawnResolver.check_spawn_conditions([enemy], 3)
	assert_eq(e3.size(), 1, "turn 3: spawn")


func test_spawn_resolver_max_spawns():
	var config := {
		"can_spawn": true,
		"max_spawns": 1,
		"spawn_trigger": "hp_threshold",
		"spawn_hp_threshold": 0.5,
		"spawn_type": "Minion",
		"spawn_count": 1,
		"spawn_hp_mult": 0.3,
		"spawn_dice": 1,
	}
	var enemy := {"name": "Boss", "health": 40, "max_health": 100,
		"config": config, "spawns_used": 1}
	var events := EnemySpawnResolver.check_spawn_conditions([enemy], 1)
	assert_eq(events.size(), 0, "max spawns reached")


func test_split_on_death_resolver():
	var config := {
		"splits_on_death": true,
		"split_into_type": "Blob",
		"split_count": 3,
		"split_hp_percent": 0.4,
		"split_dice": -1,
	}
	var enemy := CombatEngine.Enemy.new("Slime", 0, 3, config)
	var split := EnemySpawnResolver.check_split_on_death(enemy)
	assert_not_null(split)
	assert_eq(split.split_type, "Blob")
	assert_eq(split.count, 3)
	assert_eq(split.dice, 2, "3 + (-1) = 2")


func test_split_on_hp_resolver():
	var config := {
		"splits_on_hp": true,
		"split_hp_threshold": 0.3,
		"split_into_type": "Shard",
		"split_count": 2,
		"split_hp_percent": 0.5,
		"split_dice": 0,
	}
	var enemy := CombatEngine.Enemy.new("Crystal", 25, 2, config)
	enemy.max_health = 100
	var split := EnemySpawnResolver.check_split_on_hp(enemy)
	assert_not_null(split, "25/100 = 0.25 <= 0.3, should split")
	assert_eq(split.split_type, "Shard")

	enemy.health = 50
	var no_split := EnemySpawnResolver.check_split_on_hp(enemy)
	assert_null(no_split, "50/100 = 0.5 > 0.3, should not split")


func test_split_prevents_double_split():
	var config := {
		"splits_on_death": true,
		"split_into_type": "Blob",
		"split_count": 2,
		"split_hp_percent": 0.5,
		"split_dice": 0,
		"_has_split": true,
	}
	var enemy := CombatEngine.Enemy.new("Slime", 0, 2, config)
	var split := EnemySpawnResolver.check_split_on_death(enemy)
	assert_null(split, "should not split again")


# ==================================================================
# CombatLogFormatter tests
# ==================================================================

func test_log_encounter_boss():
	var lines := CombatLogFormatter.encounter_boss("Dragon Lord")
	assert_eq(lines.size(), 4)
	assert_true("FLOOR BOSS" in lines[1])
	assert_true("DRAGON LORD" in lines[2])


func test_log_encounter_mini_boss():
	var lines := CombatLogFormatter.encounter_mini_boss("Shadow Hydra")
	assert_eq(lines.size(), 2)
	assert_true("MINI-BOSS" in lines[0])
	assert_true("SHADOW HYDRA" in lines[0])


func test_log_encounter_normal():
	assert_eq(CombatLogFormatter.encounter_normal("Goblin"),
		"Goblin blocks your path!")


func test_log_player_attack():
	assert_eq(CombatLogFormatter.player_attack(42),
		"⚔️ You attack and deal 42 damage!")


func test_log_fumble():
	assert_eq(CombatLogFormatter.fumble(3),
		"⚠️ You fumble! Lost a 3 from your attack.")


func test_log_damage_reduction():
	assert_eq(CombatLogFormatter.damage_reduction_applied(5, 20, 15),
		"🛡️ Enemy's defenses reduce 5 damage! (20 → 15)")


func test_log_enemy_attack():
	assert_eq(CombatLogFormatter.enemy_attack("Orc", 15),
		"⚔️ Orc attacks for 15 damage!")


func test_log_enemy_just_spawned():
	assert_eq(CombatLogFormatter.enemy_just_spawned("Imp"),
		"Imp is too dazed to attack (just spawned)!")


func test_log_shield_absorb():
	assert_eq(CombatLogFormatter.shield_absorb(10, 5),
		"Your shield absorbs 10 damage! (Shield: 5 remaining)")


func test_log_armor_block():
	assert_eq(CombatLogFormatter.armor_block(8),
		"Your armor blocks 8 damage!")


func test_log_enemy_defeated():
	assert_eq(CombatLogFormatter.enemy_defeated("Goblin"),
		"Goblin has been defeated!")


func test_log_spawned():
	assert_eq(CombatLogFormatter.enemy_spawned("Necro", "Skeleton"),
		"⚠️ Necro summons a Skeleton! ⚠️")
	assert_eq(CombatLogFormatter.spawned_stats("Skeleton", 30, 2),
		"[SPAWNED] Skeleton - HP: 30 | Dice: 2")


func test_log_split():
	assert_eq(CombatLogFormatter.enemy_split("Slime", 3, "Blob"),
		"✸ Slime splits into 3 Blobs! ✸")
	assert_eq(CombatLogFormatter.split_stats("Blob", 10, 2),
		"[SPLIT] Blob - HP: 10 | Dice: 2")


func test_log_transform():
	assert_eq(CombatLogFormatter.transformed_stats("Dark Form", 50, 4),
		"[TRANSFORMED] Dark Form - HP: 50 | Dice: 4")


func test_log_curse_damage():
	assert_eq(CombatLogFormatter.curse_damage(7, "dark curse"),
		"☠ Curse damage! You lose 7 HP. (dark curse)")


func test_log_enemy_regen():
	assert_eq(CombatLogFormatter.enemy_regen("Troll", 10),
		"💚 Troll regenerates 10 HP!")


func test_log_status_poison():
	assert_eq(CombatLogFormatter.status_poison("Poison", 5),
		"☠ [Poison] You take 5 damage!")


func test_log_status_bleed():
	assert_eq(CombatLogFormatter.status_bleed("Bleed", 5),
		"▪ [Bleed] You take 5 bleed damage!")


func test_log_status_burn():
	assert_eq(CombatLogFormatter.status_burn("Burn", 5),
		"✹ [Burn] You take 5 fire damage!")


func test_log_enemy_burn():
	assert_eq(CombatLogFormatter.enemy_burn_tick("Goblin", 8, 3),
		"🔥 Goblin takes 8 burn damage! (3 turns remaining)")


func test_log_enemy_burn_expired():
	assert_eq(CombatLogFormatter.enemy_burn_expired("Goblin"),
		"🔥 Goblin's burn fades away.")


func test_log_enemy_burn_death():
	assert_eq(CombatLogFormatter.enemy_burned_to_death("Goblin"),
		"💀 Goblin burned to death!")


func test_log_gold_reward():
	assert_eq(CombatLogFormatter.gold_reward(50), "+50 gold!")


func test_log_key_fragment():
	assert_eq(CombatLogFormatter.key_fragment(2),
		"Obtained Boss Key Fragment! (2/3)")


func test_log_curse_expiry_messages():
	assert_eq(CombatLogFormatter.curse_expired_dice_obscure(),
		"Your vision clears! Dice values are visible again.")
	assert_eq(CombatLogFormatter.curse_expired_dice_restrict(),
		"The curse fades! Your dice roll normally again.")
	assert_eq(CombatLogFormatter.curse_expired_dice_lock(),
		"The binding breaks! Your dice are unlocked.")
	assert_eq(CombatLogFormatter.curse_expired_reroll(),
		"The curse fades! You can reroll normally again.")
	assert_eq(CombatLogFormatter.curse_expired_regen(),
		"The enemy's regeneration ends.")
	assert_eq(CombatLogFormatter.curse_expired_damage_reduction(),
		"The enemy's defenses fade!")


# ==================================================================
# Integration: full combat with abilities
# ==================================================================

func test_integration_curse_damage_kills_player():
	var ability := {
		"type": "curse_damage",
		"trigger": "combat_start",
		"damage_per_turn": 200,
		"duration_turns": 5,
		"message": "lethal curse",
	}
	var types := {"Lich": {"boss_abilities": [ability]}}
	var state := _make_state()
	state.health = 50
	var engine := _make_engine(3000, state, types)
	engine.add_enemy("Lich", 500, 0)
	engine.trigger_combat_start_abilities()

	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_lte(state.health, 0, "player should die from curse")


func test_integration_split_then_defeat_all():
	var types := {
		"Slime": {
			"splits_on_death": true,
			"split_into_type": "Blob",
			"split_count": 2,
			"split_hp_percent": 0.5,
			"split_dice": -1,
			"boss_abilities": [],
		},
		"Blob": {"boss_abilities": []},
	}
	var state := _make_state()
	state.damage_bonus = 200
	var engine := _make_engine(3100, state, types)
	engine.add_enemy("Slime", 20, 2)
	engine.player_roll()
	var turn1 := engine.player_attack(0)
	assert_true(turn1.target_killed, "slime dies")
	assert_eq(turn1.split_into.size(), 2)

	var alive := engine.get_alive_enemies()
	assert_eq(alive.size(), 2, "2 blobs")
	assert_eq(alive[0].name, "Blob")


func test_integration_periodic_spawn_respects_max():
	var types := {
		"Summoner": {
			"boss_abilities": [{
				"type": "spawn_minions_periodic",
				"trigger": "enemy_turn",
				"interval_turns": 1,
				"max_spawns": 2,
				"spawn_type": "Imp",
				"spawn_count": 1,
				"spawn_hp_mult": 0.2,
				"spawn_dice": 1,
			}]
		}
	}
	var state := _make_state()
	state.health = 500
	var engine := _make_engine(3200, state, types)
	engine.add_enemy("Summoner", 1000, 0)

	var total_spawned := 0
	for _i in 5:
		engine.player_roll()
		var turn := engine.player_attack(0)
		total_spawned += turn.spawned.size()

	assert_lte(total_spawned, 2, "should not exceed max_spawns=2")


func test_integration_real_enemy_types():
	var etd := EnemyTypesData.new()
	etd.load()
	var state := _make_state()
	state.damage_bonus = 200
	var engine := CombatEngine.new(DeterministicRNG.new(4000), state, 3, etd.enemies)
	engine.add_enemy("Gelatinous Slime", 20, 2)
	engine.player_roll()
	var turn := engine.player_attack(0)
	assert_true(turn.target_killed)
	assert_eq(turn.split_into.size(), 3, "Gelatinous Slime splits into 3 Slime Blobs")
	var blobs := engine.get_alive_enemies()
	assert_eq(blobs[0].name, "Slime Blob")
