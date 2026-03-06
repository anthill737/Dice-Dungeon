extends GutTest
## Tests for gameplay correctness and UI polish batch:
## - Score calculation
## - Game over state
## - Store comparison logic
## - Codex display readiness
## - Locked room edge cases (newly generated rooms)

var _rooms_db: Array = []


func before_all() -> void:
	var rd := RoomsData.new()
	assert_true(rd.load(), "rooms DB must load")
	_rooms_db = rd.rooms


# ==================================================================
# SCORING
# ==================================================================

func test_score_normal_kill() -> void:
	assert_eq(ScoreResolver.score_normal_kill(1), 120)
	assert_eq(ScoreResolver.score_normal_kill(5), 200)


func test_score_miniboss_kill() -> void:
	assert_eq(ScoreResolver.score_miniboss_kill(1), 550)
	assert_eq(ScoreResolver.score_miniboss_kill(3), 650)


func test_score_boss_kill() -> void:
	assert_eq(ScoreResolver.score_boss_kill(1), 1200)
	assert_eq(ScoreResolver.score_boss_kill(5), 2000)


func test_score_floor_descent() -> void:
	assert_eq(ScoreResolver.score_floor_descent(2), 200)
	assert_eq(ScoreResolver.score_floor_descent(5), 500)


func test_score_victory_bonus() -> void:
	assert_eq(ScoreResolver.score_victory(), 5000)


func test_score_deterministic() -> void:
	var a1 := ScoreResolver.score_boss_kill(3)
	var a2 := ScoreResolver.score_boss_kill(3)
	assert_eq(a1, a2, "Score must be deterministic")


func test_run_score_accumulates() -> void:
	var state := GameState.new()
	state.run_score = 0
	state.run_score += ScoreResolver.score_normal_kill(1)
	state.run_score += ScoreResolver.score_floor_descent(2)
	assert_eq(state.run_score, 320, "120 + 200 = 320")


# ==================================================================
# GAME OVER
# ==================================================================

func test_is_player_dead() -> void:
	var state := GameState.new()
	state.health = 10
	assert_false(GameOverResolver.is_player_dead(state))
	state.health = 0
	assert_true(GameOverResolver.is_player_dead(state))


func test_build_death_summary() -> void:
	var state := GameState.new()
	state.floor = 3
	state.total_gold_earned = 150
	state.run_score = 500
	state.stats["enemies_defeated"] = 5
	state.stats["bosses_defeated"] = 1
	state.stats["items_found"] = 3

	var fs := FloorState.new()
	fs.rooms_explored = 12
	fs.mini_bosses_defeated = 2

	var summary := GameOverResolver.build_summary(state, fs, GameOverResolver.EndReason.DEATH)
	assert_eq(summary.floor_reached, 3)
	assert_eq(summary.rooms_explored, 12)
	assert_eq(summary.enemies_defeated, 5)
	assert_eq(summary.gold_earned, 150)
	assert_eq(summary.victory_bonus, 0)
	assert_eq(summary.final_score, 500)


func test_build_victory_summary() -> void:
	var state := GameState.new()
	state.run_score = 1000

	var fs := FloorState.new()
	var summary := GameOverResolver.build_summary(state, fs, GameOverResolver.EndReason.VICTORY)
	assert_eq(summary.victory_bonus, 5000)
	assert_eq(summary.final_score, 6000)


# ==================================================================
# SAVE/LOAD RUN SCORE
# ==================================================================

func test_save_load_preserves_run_score() -> void:
	var state := GameState.new()
	state.run_score = 1234

	var fs := FloorState.new()
	var save_data := SaveEngine.serialize(state, fs)
	assert_eq(save_data["run_score"], 1234)

	var new_state := GameState.new()
	var new_fs := FloorState.new()
	SaveEngine.deserialize(save_data, new_state, new_fs)
	assert_eq(new_state.run_score, 1234)


# ==================================================================
# COMBAT ABILITY PARITY
# ==================================================================

func test_ability_system_all_types_handled() -> void:
	var types := [
		"dice_obscure", "dice_restrict", "dice_lock_random",
		"curse_reroll", "curse_damage", "inflict_status",
		"heal_over_time", "damage_reduction",
		"spawn_minions", "spawn_minions_periodic",
		"spawn_on_death", "transform_on_death",
	]
	var r := DeterministicRNG.new(1234)
	var cs := {
		"combat_turn_count": 5,
		"boss_ability_cooldowns": {},
		"enemy_hp_fraction": 0.4,
		"enemy_max_health": 100,
		"enemy_health_mult": 1.0,
		"floor": 1,
		"num_dice": 3,
		"dice_locked": [false, false, false],
		"statuses": [],
	}

	for atype in types:
		var ability := {"type": atype, "trigger": "combat_start"}
		if atype == "inflict_status":
			ability["status_name"] = "Poison"
		if atype == "transform_on_death":
			ability["transform_into"] = "Demon Prince"
		if atype == "spawn_minions" or atype == "spawn_on_death":
			ability["spawn_type"] = "Skeleton"
		if atype == "spawn_minions_periodic":
			ability["spawn_type"] = "Imp"
			ability["interval_turns"] = 1
		if atype == "dice_restrict":
			ability["restricted_values"] = [1, 2, 3]
		if atype == "dice_lock_random":
			ability["lock_count"] = 1

		var events := AbilitySystem.evaluate_abilities(
			"TestBoss", {"boss_abilities": [ability]}, "combat_start", cs.duplicate(true), r)
		assert_gte(events.size(), 0, "ability type '%s' should not crash" % atype)


func test_effect_system_tick_statuses() -> void:
	var statuses: Array = ["Poison", "Bleed", "Burn"]
	var result := EffectSystem.tick_statuses(statuses)
	assert_eq(result.damage, 15, "5 damage per DoT status × 3")


func test_boss_special_attacks_from_json() -> void:
	var etd := EnemyTypesData.new()
	assert_true(etd.load(), "enemy_types must load")
	var db := etd.enemies

	var demon := db.get("Demon Lord", {})
	assert_true(demon.has("boss_abilities"), "Demon Lord should have abilities")
	var ability_types: Array = []
	for ab in demon.get("boss_abilities", []):
		ability_types.append(ab.get("type", ""))
	assert_true("curse_damage" in ability_types, "Demon Lord should have curse_damage")
	assert_true("spawn_minions_periodic" in ability_types, "Demon Lord should have periodic spawns")
	assert_true("transform_on_death" in ability_types, "Demon Lord should transform on death")


# ==================================================================
# STORE COMPARISON
# ==================================================================

func test_tooltip_formatter_output() -> void:
	var item_def := {
		"desc": "A sharp blade",
		"damage_bonus": 5,
		"crit_bonus": 0.1,
	}
	var result := TooltipFormatter.format("Iron Sword", item_def)
	assert_true(result.contains("Iron Sword"))
	assert_true(result.contains("A sharp blade"))
	assert_true(result.contains("+5 Damage"))
	assert_true(result.contains("+10% Crit"))


# ==================================================================
# NEWLY GENERATED LOCKED BOSS ROOM
# ==================================================================

func test_newly_generated_boss_blocks_entry() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(90000)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(5)

	engine.floor.boss_spawned = false
	engine.floor.next_boss_at = 1

	var pos_before := engine.floor.current_pos
	var room := engine.move("E")
	assert_null(room, "boss room should block entry")
	assert_eq(engine.floor.current_pos, pos_before)

	var boss_pos := pos_before + Vector2i(1, 0)
	assert_true(engine.floor.rooms.has(boss_pos))
	var boss_room: RoomState = engine.floor.rooms[boss_pos]
	assert_true(boss_room.is_boss_room)
	assert_false(boss_room.visited)


func test_game_state_has_run_score() -> void:
	var state := GameState.new()
	assert_eq(state.run_score, 0, "run_score should default to 0")
	state.reset()
	assert_eq(state.run_score, 0, "run_score should reset to 0")


func test_game_state_stats_has_enemies_defeated() -> void:
	var state := GameState.new()
	assert_eq(int(state.stats.get("enemies_defeated", 0)), 0)
	assert_eq(int(state.stats.get("bosses_defeated", 0)), 0)
	assert_eq(int(state.stats.get("chests_opened", 0)), 0)
