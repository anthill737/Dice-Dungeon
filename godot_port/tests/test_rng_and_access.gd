extends GutTest
## Protective tests for RNG safety, room-access resolution,
## unlocked-room persistence, and game-over correctness.

const _ScoreResolver := preload("res://game/core/combat/score_resolver.gd")
const _GameOverResolver := preload("res://game/services/game_over_resolver.gd")
const _RoomAccessResolver := preload("res://game/core/exploration/room_access_resolver.gd")

var _rooms_db: Array = []


func before_all() -> void:
	var rd := RoomsData.new()
	assert_true(rd.load(), "rooms DB must load")
	_rooms_db = rd.rooms


func _make(seed_val: int) -> ExplorationEngine:
	var state := GameState.new()
	return ExplorationEngine.new(DeterministicRNG.new(seed_val), state, _rooms_db)


# ==================================================================
# PART 1 — RNG safety for existing locked rooms
# ==================================================================

func test_locked_existing_room_does_not_consume_rng() -> void:
	var state := GameState.new()
	var r := PortableLCG.new(50000)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	mb_room.visited = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	var rng_before := r._state
	var pos_before := engine.floor.current_pos

	var result := engine.move("E")

	assert_null(result, "move into locked room should return null")
	assert_eq(r._state, rng_before, "RNG state must not change for existing locked room")
	assert_eq(engine.floor.current_pos, pos_before, "player must not move")


func test_locked_boss_existing_room_does_not_consume_rng() -> void:
	var state := GameState.new()
	var r := PortableLCG.new(50001)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	var boss_pos := Vector2i(1, 0)
	var boss_room := RoomState.new({"name": "Boss Lair", "difficulty": "Boss"}, 1, 0)
	boss_room.is_boss_room = true
	boss_room.has_combat = true
	boss_room.visited = true
	engine.floor.rooms[boss_pos] = boss_room
	engine.floor.special_rooms[boss_pos] = "boss"

	var rng_before := r._state
	var result := engine.move("E")
	assert_null(result, "move into locked boss room should return null")
	assert_eq(r._state, rng_before, "RNG must not change for existing locked boss room")


func test_newly_generated_locked_room_consumes_generation_rng_only() -> void:
	var state := GameState.new()
	var r := PortableLCG.new(50010)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)
	engine.floor.next_mini_boss_at = 1

	var rng_after_floor_start := r._state
	var room := engine.move("E")
	var rng_after_blocked_move := r._state

	assert_null(room, "newly generated locked room should block entry")
	assert_ne(rng_after_blocked_move, rng_after_floor_start,
		"room generation RNG IS consumed (matching Python)")

	var mb_pos := engine.floor.current_pos + Vector2i(1, 0)
	assert_true(engine.floor.rooms.has(mb_pos), "room should exist")
	assert_false(engine.floor.rooms[mb_pos].visited, "room must not be visited")


# ==================================================================
# PART 2 — Unlocked-room state persistence
# ==================================================================

func test_unlock_consumes_exactly_one_old_key() -> void:
	var state := GameState.new()
	state.inventory.append("Old Key")
	state.inventory.append("Old Key")
	var r := DeterministicRNG.new(51000)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	var pos := Vector2i(2, 2)
	engine.floor.special_rooms[pos] = "mini_boss"

	assert_true(engine.use_old_key(pos), "unlock should succeed")
	assert_eq(state.inventory.count("Old Key"), 1,
		"exactly one Old Key consumed")
	assert_true(engine.floor.unlocked_rooms.has(pos),
		"room must be marked unlocked")


func test_unlocked_room_accessible_from_any_direction() -> void:
	var state := GameState.new()
	state.inventory.append("Old Key")
	var r := DeterministicRNG.new(51001)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	mb_room.visited = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	engine.use_old_key(mb_pos)

	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "", "unlocked room should have no gate")

	var south_pos := Vector2i(1, -1)
	var south_room := RoomState.new({"name": "Room South"}, 1, -1)
	south_room.visited = true
	engine.floor.rooms[south_pos] = south_room

	engine.floor.current_pos = south_pos
	var gate_from_south := engine.check_room_gating(mb_pos)
	assert_eq(gate_from_south, "",
		"room stays unlocked from different directions")


func test_unlocked_room_persists_save_load() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(51002)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	var pos := Vector2i(3, 4)
	engine.floor.special_rooms[pos] = "mini_boss"
	engine.floor.unlocked_rooms[pos] = true

	var save_data := SaveEngine.serialize(state, engine.floor)

	var loaded_state := GameState.new()
	var loaded_floor := FloorState.new()
	SaveEngine.deserialize(save_data, loaded_state, loaded_floor)

	assert_true(loaded_floor.unlocked_rooms.has(pos),
		"unlocked room must persist through save/load")
	assert_true(loaded_floor.special_rooms.has(pos),
		"special rooms must persist through save/load")
	assert_eq(loaded_floor.special_rooms[pos], "mini_boss")


# ==================================================================
# PART 4 — RoomAccessResolver
# ==================================================================

func test_resolver_allows_normal_room() -> void:
	var fs := FloorState.new()
	var state := GameState.new()
	var ac = _RoomAccessResolver.check_access(Vector2i(1, 1), fs, state)
	assert_eq(ac.result, _RoomAccessResolver.AccessResult.ALLOWED)
	assert_eq(ac.gate_type, "")


func test_resolver_detects_locked_mini_boss_no_key() -> void:
	var fs := FloorState.new()
	fs.special_rooms[Vector2i(1, 0)] = "mini_boss"
	var state := GameState.new()
	var ac = _RoomAccessResolver.check_access(Vector2i(1, 0), fs, state)
	assert_eq(ac.result, _RoomAccessResolver.AccessResult.LOCKED_NO_KEY)
	assert_eq(ac.gate_type, "locked_mini_boss")


func test_resolver_detects_locked_mini_boss_with_key() -> void:
	var fs := FloorState.new()
	fs.special_rooms[Vector2i(1, 0)] = "mini_boss"
	var state := GameState.new()
	state.inventory.append("Old Key")
	var ac = _RoomAccessResolver.check_access(Vector2i(1, 0), fs, state)
	assert_eq(ac.result, _RoomAccessResolver.AccessResult.LOCKED_HAS_KEY)
	assert_eq(ac.gate_type, "has_key_mini_boss")


func test_resolver_detects_locked_boss_no_fragments() -> void:
	var fs := FloorState.new()
	fs.special_rooms[Vector2i(2, 0)] = "boss"
	fs.key_fragments = 2
	var state := GameState.new()
	var ac = _RoomAccessResolver.check_access(Vector2i(2, 0), fs, state)
	assert_eq(ac.result, _RoomAccessResolver.AccessResult.LOCKED_NO_KEY)
	assert_eq(ac.gate_type, "locked_boss")


func test_resolver_detects_boss_with_fragments() -> void:
	var fs := FloorState.new()
	fs.special_rooms[Vector2i(2, 0)] = "boss"
	fs.key_fragments = 3
	var state := GameState.new()
	var ac = _RoomAccessResolver.check_access(Vector2i(2, 0), fs, state)
	assert_eq(ac.result, _RoomAccessResolver.AccessResult.LOCKED_HAS_KEY)
	assert_eq(ac.gate_type, "has_key_boss")


func test_resolver_unlocked_room_allowed() -> void:
	var fs := FloorState.new()
	fs.special_rooms[Vector2i(1, 0)] = "mini_boss"
	fs.unlocked_rooms[Vector2i(1, 0)] = true
	var state := GameState.new()
	var ac = _RoomAccessResolver.check_access(Vector2i(1, 0), fs, state)
	assert_eq(ac.result, _RoomAccessResolver.AccessResult.ALLOWED)


func test_resolver_unlock_mini_boss() -> void:
	var fs := FloorState.new()
	var state := GameState.new()
	state.inventory.append("Old Key")
	var pos := Vector2i(1, 0)
	assert_true(_RoomAccessResolver.unlock_mini_boss(pos, fs, state))
	assert_false(state.inventory.has("Old Key"))
	assert_true(fs.unlocked_rooms.has(pos))


func test_resolver_unlock_boss() -> void:
	var fs := FloorState.new()
	fs.key_fragments = 3
	var pos := Vector2i(2, 0)
	assert_true(_RoomAccessResolver.unlock_boss(pos, fs))
	assert_eq(fs.key_fragments, 0)
	assert_true(fs.unlocked_rooms.has(pos))


func test_resolver_is_accessible() -> void:
	var fs := FloorState.new()
	assert_true(_RoomAccessResolver.is_accessible(Vector2i(0, 0), fs))
	fs.special_rooms[Vector2i(1, 0)] = "mini_boss"
	assert_false(_RoomAccessResolver.is_accessible(Vector2i(1, 0), fs))
	fs.unlocked_rooms[Vector2i(1, 0)] = true
	assert_true(_RoomAccessResolver.is_accessible(Vector2i(1, 0), fs))


# ==================================================================
# PART 5 — Game-over summary correctness
# ==================================================================

func test_game_over_death_summary() -> void:
	var state := GameState.new()
	state.floor = 4
	state.total_gold_earned = 200
	state.run_score = 1500
	state.stats["enemies_defeated"] = 8
	state.stats["bosses_defeated"] = 1
	state.stats["items_found"] = 5
	state.stats["chests_opened"] = 3
	state.lore_codex = [{"title": "a"}, {"title": "b"}]

	var fs := FloorState.new()
	fs.rooms_explored = 15
	fs.mini_bosses_defeated = 2

	var s := _GameOverResolver.build_summary(state, fs, _GameOverResolver.EndReason.DEATH)
	assert_eq(s.floor_reached, 4)
	assert_eq(s.rooms_explored, 15)
	assert_eq(s.enemies_defeated, 8)
	assert_eq(s.bosses_defeated, 1)
	assert_eq(s.gold_earned, 200)
	assert_eq(s.items_found, 5)
	assert_eq(s.chests_opened, 3)
	assert_eq(s.lore_found, 2)
	assert_eq(s.run_score, 1500)
	assert_eq(s.victory_bonus, 0)
	assert_eq(s.final_score, 1500)


func test_game_over_victory_summary() -> void:
	var state := GameState.new()
	state.run_score = 3000
	var fs := FloorState.new()
	var s := _GameOverResolver.build_summary(state, fs, _GameOverResolver.EndReason.VICTORY)
	assert_eq(s.victory_bonus, 5000)
	assert_eq(s.final_score, 8000)


func test_game_over_reads_run_score_not_stats() -> void:
	var state := GameState.new()
	state.run_score = 999
	state.stats["run_score"] = 0
	var fs := FloorState.new()
	var s := _GameOverResolver.build_summary(state, fs, _GameOverResolver.EndReason.DEATH)
	assert_eq(s.run_score, 999,
		"summary must read state.run_score, not state.stats['run_score']")
	assert_eq(s.final_score, 999)


# ==================================================================
# PART 7 — Score breakdown values match ScoreResolver
# ==================================================================

func test_score_breakdown_constants() -> void:
	assert_eq(_ScoreResolver.score_normal_kill(1), 120)
	assert_eq(_ScoreResolver.score_miniboss_kill(1), 550)
	assert_eq(_ScoreResolver.score_boss_kill(1), 1200)
	assert_eq(_ScoreResolver.score_floor_descent(2), 200)
	assert_eq(_ScoreResolver.score_victory(), 5000)


func test_score_deterministic_across_calls() -> void:
	var a := _ScoreResolver.score_boss_kill(5)
	var b := _ScoreResolver.score_boss_kill(5)
	assert_eq(a, b, "scoring must be deterministic")
	assert_eq(a, 2000, "1000 + 5*200 = 2000")


# ==================================================================
# last_move_gate is signaling-only
# ==================================================================

func test_last_move_gate_only_signaling() -> void:
	var engine := _make(52000)
	engine.start_floor(1)

	assert_eq(engine.last_move_gate, "",
		"last_move_gate starts empty")

	engine.move("E")
	assert_eq(engine.last_move_gate, "",
		"normal move clears last_move_gate")

	engine.floor.special_rooms[Vector2i(0, 1)] = "mini_boss"
	var mb_room := RoomState.new({"name": "MB"}, 0, 1)
	mb_room.is_mini_boss_room = true
	mb_room.visited = true
	engine.floor.rooms[Vector2i(0, 1)] = mb_room

	engine.floor.current_pos = Vector2i(0, 0)
	engine.move("N")
	assert_eq(engine.last_move_gate, "",
		"blocked-without-key does not set last_move_gate")

	engine.state.inventory.append("Old Key")
	engine.move("N")
	assert_eq(engine.last_move_gate, "has_key_mini_boss",
		"has-key sets last_move_gate for UI dialog")
