extends GutTest
## Tests for:
## - Enemy HP varies per type/floor (not all 20)
## - Room entry log appears exactly once, no flavor duplication


func _make_session(seed_val: int = 42) -> void:
	GameSession._load_data()
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": seed_val})


# ── Enemy HP: varies across enemy types ──

func test_enemy_hp_varies_across_types() -> void:
	_make_session()
	var hp_values: Array[int] = []
	var names := ["Goblin", "Skeleton", "Ogre", "Dragon", "Bat"]
	for enemy_name in names:
		var hp := GameSession._calc_enemy_hp(enemy_name, 1, false, false)
		hp_values.append(hp)
		assert_gt(hp, 0, "%s should have positive HP" % enemy_name)

	var unique_count := 0
	for i in hp_values.size():
		var is_unique := true
		for j in i:
			if hp_values[j] == hp_values[i]:
				is_unique = false
				break
		if is_unique:
			unique_count += 1
	assert_gt(unique_count, 1, "HP should vary — not all enemies identical")


func test_goblin_hp_floor1_normal() -> void:
	_make_session()
	var hp := GameSession._calc_enemy_hp("Goblin", 1, false, false)
	# Python: base=60, mult=0.7 → 42, +rng(-5..10) → 37..52 (Normal diff)
	assert_gte(hp, 25, "Goblin floor 1 HP >= 25")
	assert_lte(hp, 100, "Goblin floor 1 HP <= 100")


func test_skeleton_hp_floor1_normal() -> void:
	_make_session()
	var hp := GameSession._calc_enemy_hp("Skeleton", 1, false, false)
	# Python: base=60, mult=1.0 → 60, +rng(-5..10) → 55..70 (Normal diff)
	assert_gte(hp, 35, "Skeleton floor 1 HP >= 35")
	assert_lte(hp, 150, "Skeleton floor 1 HP <= 150")


func test_enemy_hp_scales_with_floor() -> void:
	_make_session(100)
	var hp_f1 := GameSession._calc_enemy_hp("Skeleton", 1, false, false)
	_make_session(100)
	var hp_f5 := GameSession._calc_enemy_hp("Skeleton", 5, false, false)
	assert_gt(hp_f5, hp_f1, "Higher floor = more HP")


func test_boss_multiplier_applied() -> void:
	_make_session()
	var hp_normal := GameSession._calc_enemy_hp("Crystal Golem", 1, false, false)
	_make_session()
	var hp_boss := GameSession._calc_enemy_hp("Crystal Golem", 1, false, true)
	assert_gt(hp_boss, hp_normal * 5, "Boss HP significantly higher than normal")


func test_miniboss_multiplier_applied() -> void:
	_make_session()
	var hp_normal := GameSession._calc_enemy_hp("Goblin", 1, false, false)
	_make_session()
	var hp_mini := GameSession._calc_enemy_hp("Goblin", 1, true, false)
	assert_gt(hp_mini, hp_normal * 2, "Miniboss HP significantly higher")


func test_combat_enemy_not_all_20hp() -> void:
	_make_session()
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Skeleton"]
	GameSession.enemy_types_db["Skeleton"] = {}
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()
	var ce := GameSession.combat
	assert_not_null(ce, "Combat created")
	var enemies := ce.get_alive_enemies()
	assert_gt(enemies.size(), 0, "Has enemies")
	assert_ne(enemies[0].health, 20, "Enemy HP should not be default 20")
	assert_gt(enemies[0].health, 30, "Enemy HP should be substantial")
	GameSession.end_combat(true)


func test_enemy_hp_multiplier_lookup_matches_python() -> void:
	# Python table (explorer/combat.py lines 360-396): partial name match, first wins.
	# Verify the ENEMY_HP_MULTIPLIERS dict contains the correct keys and values
	# matching the Python table, and that _calc_enemy_hp produces correctly
	# scaled relative differences between enemy types.
	var table: Dictionary = GameSession.ENEMY_HP_MULTIPLIERS

	# Verify specific Python table entries exist with correct values
	assert_eq(table.get("Goblin"), 0.7, "Goblin mult matches Python")
	assert_eq(table.get("Dragon"), 2.5, "Dragon mult matches Python")
	assert_eq(table.get("Troll"), 1.5, "Troll mult matches Python")
	assert_eq(table.get("Skeleton"), 1.0, "Skeleton mult matches Python")
	assert_eq(table.get("Bat"), 0.5, "Bat mult matches Python")

	# Verify relative HP ordering: Dragon > Troll > Skeleton > Goblin > Bat
	_make_session(8888)
	var hp_dragon := GameSession._calc_enemy_hp("Dragon", 3, false, false)
	var hp_troll := GameSession._calc_enemy_hp("Troll", 3, false, false)
	var hp_skel := GameSession._calc_enemy_hp("Skeleton", 3, false, false)
	var hp_goblin := GameSession._calc_enemy_hp("Goblin", 3, false, false)
	var hp_bat := GameSession._calc_enemy_hp("Bat", 3, false, false)

	assert_gt(hp_dragon, hp_troll, "Dragon HP > Troll HP")
	assert_gt(hp_troll, hp_skel, "Troll HP > Skeleton HP")
	assert_gt(hp_skel, hp_goblin, "Skeleton HP > Goblin HP")
	assert_gt(hp_goblin, hp_bat, "Goblin HP > Bat HP")


func test_health_sanity_no_uniform_fallback() -> void:
	_make_session(77)
	var hp_set: Dictionary = {}
	var names := ["Goblin", "Skeleton", "Ogre", "Dragon", "Bat", "Spider",
		"Troll", "Knight", "Orc", "Zombie"]
	for n in names:
		var hp := GameSession._calc_enemy_hp(n, 3, false, false)
		hp_set[hp] = hp_set.get(hp, 0) + 1
	var max_same := 0
	for v in hp_set.values():
		if int(v) > max_same:
			max_same = int(v)
	var pct: float = float(max_same) / float(names.size())
	assert_lt(pct, 0.8, "Less than 80%% of enemies should share the same HP")


# ── Room entry log: exactly once with flavor ──

func test_room_entry_log_exactly_once() -> void:
	_make_session(200)
	var room := GameSession.get_current_room()
	assert_not_null(room, "Starting room exists")

	var log_entries: Array[String] = []
	var _capture := func(msg: String):
		log_entries.append(msg)
	GameSession.log_message.connect(_capture)

	GameSession.move_direction("E")

	var entered_count := 0
	for entry in log_entries:
		if entry.begins_with("Entered:"):
			entered_count += 1
	assert_eq(entered_count, 1, "Exactly one 'Entered:' log per move")

	GameSession.log_message.disconnect(_capture)


func test_room_entry_log_includes_flavor() -> void:
	_make_session(200)

	var log_entries: Array[String] = []
	var _capture := func(msg: String):
		log_entries.append(msg)
	GameSession.log_message.connect(_capture)

	var moved_room: RoomState = null
	for dir in ["E", "N", "S", "W"]:
		moved_room = GameSession.move_direction(dir)
		if moved_room != null:
			break
	GameSession.log_message.disconnect(_capture)

	if moved_room == null:
		pending("Could not move in any direction")
		return

	var flavor: String = moved_room.data.get("flavor", "")
	if flavor.is_empty():
		pending("Room has no flavor text")
		return

	var flavor_found := false
	for entry in log_entries:
		if entry == flavor:
			flavor_found = true
			break
	assert_true(flavor_found, "Log should include room flavor text (Python parity)")


func test_revisit_uses_entered_not_returned() -> void:
	_make_session(300)

	var moved_out := false
	var out_dir := ""
	var back_dir := ""
	var dir_pairs := [["E", "W"], ["N", "S"], ["W", "E"], ["S", "N"]]
	for pair in dir_pairs:
		var room := GameSession.move_direction(pair[0])
		if room != null:
			moved_out = true
			out_dir = pair[0]
			back_dir = pair[1]
			break
	if not moved_out:
		pending("Could not move in any direction from start room")
		return

	var room_back := GameSession.move_direction(back_dir)
	if room_back == null:
		pending("Could not return to start room")
		return

	var log_entries: Array[String] = []
	var _capture := func(msg: String):
		log_entries.append(msg)
	GameSession.log_message.connect(_capture)

	GameSession.move_direction(out_dir)

	var entered_count := 0
	for entry in log_entries:
		if entry.begins_with("Entered:"):
			entered_count += 1
	assert_eq(entered_count, 1, "Revisit uses 'Entered:' (Python parity, not 'Returned to:')")

	GameSession.log_message.disconnect(_capture)
