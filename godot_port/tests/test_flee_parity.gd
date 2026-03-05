extends GutTest
## Deterministic flee tests covering all permutations:
## 1. Normal enemy, flee success → takes damage
## 2. Normal enemy, flee failure → no damage, still in combat
## 3. Boss enemy → flee blocked entirely
## 4. Mini-boss enemy → flee blocked entirely
##
## Python parity: explorer/combat.py attempt_flee() lines 285-324
## - Boss/mini-boss: cannot flee
## - Normal: rng.random() < 0.5, damage rng.randint(5,15) on success


func _make_combat_room() -> void:
	GameSession._load_data()
	GameSession.start_new_game()
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}


# ------------------------------------------------------------------
# Test 1: Normal enemy, flee success → takes rng.randint(5,15) damage
# ------------------------------------------------------------------

func test_flee_normal_success_deals_damage() -> void:
	_make_combat_room()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	var hp_before := GameSession.game_state.health
	var succeeded := false
	var damage_taken := 0

	for _i in 40:
		var result := GameSession.attempt_flee_pending()
		if result.get("success", false):
			succeeded = true
			damage_taken = int(result.get("damage", 0))
			break
		GameSession.combat_pending = true

	assert_true(succeeded, "Fled from normal enemy within 40 attempts")
	assert_gt(damage_taken, 0, "Flee success deals damage (Python parity)")
	assert_gte(damage_taken, 5, "Damage >= 5 (Python: randint(5,15))")
	assert_lte(damage_taken, 15, "Damage <= 15 (Python: randint(5,15))")
	assert_eq(GameSession.game_state.health, hp_before - damage_taken,
		"HP reduced by flee damage")


# ------------------------------------------------------------------
# Test 2: Normal enemy, flee failure → no damage, still pending
# ------------------------------------------------------------------

func test_flee_normal_failure_no_damage() -> void:
	_make_combat_room()
	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	var hp_before := GameSession.game_state.health
	var got_failure := false

	for _i in 40:
		var result := GameSession.attempt_flee_pending()
		if not result.get("success", false):
			got_failure = true
			assert_eq(GameSession.game_state.health, hp_before,
				"No HP lost on flee failure")
			assert_true(GameSession.combat_pending,
				"Still pending after flee failure")
			break
		# Succeeded, undo and retry
		room.combat_escaped = false
		GameSession.combat_pending = true
		GameSession.game_state.health = GameSession.game_state.max_health

	assert_true(got_failure, "Got at least one flee failure within 40 attempts")


# ------------------------------------------------------------------
# Test 3: Boss enemy → flee blocked entirely
# ------------------------------------------------------------------

func test_flee_boss_blocked() -> void:
	_make_combat_room()
	var room := GameSession.get_current_room()
	room.is_boss_room = true
	GameSession._check_combat_pending(room)

	var hp_before := GameSession.game_state.health
	var result := GameSession.attempt_flee_pending()

	assert_false(result.get("success", false), "Cannot flee from boss")
	assert_eq(result.get("reason", ""), "boss_fight", "Blocked reason is boss_fight")
	assert_eq(GameSession.game_state.health, hp_before, "No HP lost")
	assert_true(GameSession.combat_pending, "Still pending — not escaped")


# ------------------------------------------------------------------
# Test 4: Mini-boss enemy → flee blocked entirely
# ------------------------------------------------------------------

func test_flee_miniboss_blocked() -> void:
	_make_combat_room()
	var room := GameSession.get_current_room()
	room.is_mini_boss_room = true
	GameSession._check_combat_pending(room)

	var hp_before := GameSession.game_state.health
	var result := GameSession.attempt_flee_pending()

	assert_false(result.get("success", false), "Cannot flee from mini-boss")
	assert_eq(result.get("reason", ""), "boss_fight", "Blocked reason is boss_fight")
	assert_eq(GameSession.game_state.health, hp_before, "No HP lost")
	assert_true(GameSession.combat_pending, "Still pending — not escaped")
