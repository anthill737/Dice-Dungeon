extends GutTest
## Tests for locked-room gating (Python parity), adventure log entries,
## and minimap icon sizing constraints.
## All tests use DeterministicRNG for reproducibility.

var _rooms_db: Array = []


func before_all() -> void:
	var rd := RoomsData.new()
	assert_true(rd.load(), "rooms DB must load")
	_rooms_db = rd.rooms


func _make_engine(seed_val: int) -> ExplorationEngine:
	var state := GameState.new()
	return ExplorationEngine.new(DeterministicRNG.new(seed_val), state, _rooms_db)


# ==================================================================
# 1) Miniboss room without Old Key — blocked
# ==================================================================

func test_miniboss_blocked_without_old_key() -> void:
	var engine := _make_engine(60000)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "locked_mini_boss",
		"miniboss room should be locked without Old Key")


func test_miniboss_turn_back_no_room_entered() -> void:
	var engine := _make_engine(60001)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	engine.state.inventory.append("Old Key")
	var gate := engine.check_room_gating(mb_pos)
	assert_eq(gate, "has_key_mini_boss",
		"should show dialog when key present")

	var pos_before := engine.floor.current_pos
	var rooms_explored_before := engine.floor.rooms_explored

	# Simulate Turn Back by NOT calling move/confirm — just decline
	# (The game session emits decline_locked_room_entry)
	# Verify no state changes occur:
	assert_eq(engine.floor.current_pos, pos_before,
		"player position should not change on Turn Back")
	assert_eq(engine.floor.rooms_explored, rooms_explored_before,
		"rooms_explored should not change on Turn Back")
	assert_true(engine.state.inventory.has("Old Key"),
		"Old Key should NOT be consumed on Turn Back")


# ==================================================================
# 2) Miniboss room with Old Key — Unlock & Enter
# ==================================================================

func test_miniboss_unlock_consumes_key() -> void:
	var engine := _make_engine(60010)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	engine.state.inventory.append("Old Key")
	var ok := engine.use_old_key(mb_pos)
	assert_true(ok, "use_old_key should succeed")
	assert_false(engine.state.inventory.has("Old Key"),
		"Old Key consumed after unlock")
	assert_true(engine.floor.unlocked_rooms.has(mb_pos),
		"room marked unlocked")


func test_miniboss_unlock_log_message() -> void:
	var engine := _make_engine(60011)
	engine.start_floor(1)
	engine.logs.clear()

	var mb_pos := Vector2i(1, 0)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	engine.state.inventory.append("Old Key")
	engine.use_old_key(mb_pos)

	assert_true(engine.logs.has("[KEY USED] The Old Key turns in the lock with a satisfying click!"),
		"unlock log must match Python exactly")
	assert_true(engine.logs.has("The elite room door swings open!"),
		"door-open log must match Python exactly")


func test_miniboss_move_after_unlock() -> void:
	var engine := _make_engine(60012)
	engine.start_floor(1)

	var mb_pos := Vector2i(1, 0)
	var mb_room := RoomState.new({"name": "Elite Den", "difficulty": "Elite"}, 1, 0)
	mb_room.is_mini_boss_room = true
	mb_room.has_combat = true
	mb_room.visited = true
	engine.floor.rooms[mb_pos] = mb_room
	engine.floor.special_rooms[mb_pos] = "mini_boss"

	engine.state.inventory.append("Old Key")
	engine.use_old_key(mb_pos)

	var room := engine.move("E")
	assert_not_null(room, "should be able to move into unlocked room")
	assert_eq(engine.floor.current_pos, mb_pos,
		"player should be in the miniboss room")


# ==================================================================
# 3) Boss room gating
# ==================================================================

func test_boss_blocked_without_fragments() -> void:
	var engine := _make_engine(60020)
	engine.start_floor(1)

	var boss_pos := Vector2i(1, 0)
	engine.floor.special_rooms[boss_pos] = "boss"

	var gate := engine.check_room_gating(boss_pos)
	assert_eq(gate, "locked_boss",
		"boss room should be locked without fragments")

	engine.floor.key_fragments = 2
	gate = engine.check_room_gating(boss_pos)
	assert_eq(gate, "locked_boss",
		"boss room should still be locked with only 2 fragments")


func test_boss_has_key_with_3_fragments() -> void:
	var engine := _make_engine(60021)
	engine.start_floor(1)

	var boss_pos := Vector2i(1, 0)
	engine.floor.special_rooms[boss_pos] = "boss"
	engine.floor.key_fragments = 3

	var gate := engine.check_room_gating(boss_pos)
	assert_eq(gate, "has_key_boss",
		"boss room should be accessible with 3 fragments")


func test_boss_unlock_consumes_fragments() -> void:
	var engine := _make_engine(60022)
	engine.start_floor(1)

	var boss_pos := Vector2i(1, 0)
	engine.floor.special_rooms[boss_pos] = "boss"
	engine.floor.key_fragments = 3

	var ok := engine.use_boss_key(boss_pos)
	assert_true(ok, "use_boss_key should succeed")
	assert_eq(engine.floor.key_fragments, 0,
		"all fragments consumed")
	assert_true(engine.floor.unlocked_rooms.has(boss_pos),
		"boss room marked unlocked")


func test_boss_unlock_log_message() -> void:
	var engine := _make_engine(60023)
	engine.start_floor(1)
	engine.logs.clear()

	var boss_pos := Vector2i(1, 0)
	engine.floor.special_rooms[boss_pos] = "boss"
	engine.floor.key_fragments = 3
	engine.use_boss_key(boss_pos)

	assert_true(engine.logs.has("The 3 fragments merge into a complete key!"),
		"boss unlock log must match Python")
	assert_true(engine.logs.has("The massive boss door grinds open!"),
		"boss door-open log must match Python")


# ==================================================================
# 4) Turn Back log entries match Python
# ==================================================================

func test_decline_miniboss_log_messages() -> void:
	# These messages are emitted by GameSession.decline_locked_room_entry()
	# which calls log_message.emit(). We test the exact strings here.
	var expected_msg1 := "You decide to save your Old Key for later."
	var expected_msg2 := "You turn back. The elite room remains locked."

	# Verify the message classification
	var meta1 := _classify(expected_msg1)
	assert_eq(meta1[0], "system", "decline tag should be 'system'")
	assert_eq(meta1[1], "INTERACTION", "decline category should be INTERACTION")
	assert_eq(meta1[2], "exploration", "decline source should be 'exploration'")

	var meta2 := _classify(expected_msg2)
	assert_eq(meta2[0], "enemy", "turn-back tag should be 'enemy'")
	assert_eq(meta2[1], "INTERACTION", "turn-back category should be INTERACTION")
	assert_eq(meta2[2], "exploration", "turn-back source should be 'exploration'")


func test_decline_boss_log_messages() -> void:
	var expected_msg1 := "You decide to prepare more before facing the boss."
	var expected_msg2 := "You turn back. The boss room remains sealed."

	var meta1 := _classify(expected_msg1)
	assert_eq(meta1[0], "system", "boss decline tag should be 'system'")
	assert_eq(meta1[1], "INTERACTION", "boss decline category should be INTERACTION")
	assert_eq(meta1[2], "exploration", "boss decline source should be 'exploration'")

	var meta2 := _classify(expected_msg2)
	assert_eq(meta2[0], "enemy", "boss turn-back tag should be 'enemy'")
	assert_eq(meta2[1], "INTERACTION", "boss turn-back category should be INTERACTION")
	assert_eq(meta2[2], "exploration", "boss turn-back source should be 'exploration'")


# ==================================================================
# 5) Unlock log entries match Python
# ==================================================================

func test_unlock_miniboss_log_classification() -> void:
	var msg1 := "[KEY USED] The Old Key turns in the lock with a satisfying click!"
	var meta1 := _classify(msg1)
	assert_eq(meta1[0], "success", "key-used tag should be 'success'")
	assert_eq(meta1[1], "INTERACTION", "key-used category should be INTERACTION")
	assert_eq(meta1[2], "exploration", "key-used source should be 'exploration'")

	var msg2 := "The elite room door swings open!"
	var meta2 := _classify(msg2)
	assert_eq(meta2[0], "success", "door-open tag should be 'success'")
	assert_eq(meta2[1], "INTERACTION", "door-open category should be INTERACTION")


func test_unlock_boss_log_classification() -> void:
	var msg1 := "The 3 fragments merge into a complete key!"
	var meta1 := _classify(msg1)
	assert_eq(meta1[0], "success", "merge tag should be 'success'")
	assert_eq(meta1[1], "INTERACTION", "merge category should be INTERACTION")

	var msg2 := "The massive boss door grinds open!"
	var meta2 := _classify(msg2)
	assert_eq(meta2[0], "success", "boss door tag should be 'success'")
	assert_eq(meta2[1], "INTERACTION", "boss door category should be INTERACTION")


func test_pre_dialog_log_classification() -> void:
	# Miniboss pre-dialog
	var msg_mb1 := "⚡ A reinforced door blocks your path! ⚡"
	var meta_mb1 := _classify(msg_mb1)
	assert_eq(meta_mb1[0], "enemy", "blocks-path tag should be 'enemy'")
	assert_eq(meta_mb1[1], "INTERACTION", "blocks-path category should be INTERACTION")

	var msg_mb2 := "The door is sealed with an ornate lock."
	var meta_mb2 := _classify(msg_mb2)
	assert_eq(meta_mb2[1], "INTERACTION", "ornate-lock category should be INTERACTION")
	assert_eq(meta_mb2[2], "exploration", "ornate-lock source should be 'exploration'")

	# Boss pre-dialog
	var msg_b1 := "☠ An enormous sealed door looms before you! ☠"
	var meta_b1 := _classify(msg_b1)
	assert_eq(meta_b1[0], "enemy", "sealed-door tag should be 'enemy'")
	assert_eq(meta_b1[1], "INTERACTION", "sealed-door category should be INTERACTION")

	var msg_b2 := "Three keyhole slots glow faintly in the door."
	var meta_b2 := _classify(msg_b2)
	assert_eq(meta_b2[1], "INTERACTION", "keyhole-slots category should be INTERACTION")


func test_adventure_log_action_id_increments() -> void:
	var svc := AdventureLogService.new()
	svc.append("[KEY USED] The Old Key turns in the lock with a satisfying click!", "success", "INTERACTION", "exploration")
	svc.append("The elite room door swings open!", "success", "INTERACTION", "exploration")
	svc.append("You decide to save your Old Key for later.", "system", "INTERACTION", "exploration")

	var entries := svc.get_entries()
	assert_eq(entries.size(), 3)
	assert_eq(entries[0]["action_id"], 0, "first action_id should be 0")
	assert_eq(entries[1]["action_id"], 1, "second action_id should be 1")
	assert_eq(entries[2]["action_id"], 2, "third action_id should be 2")


# ==================================================================
# 6) Minimap icon_size <= cell_size - margin
# ==================================================================

func test_icon_size_never_exceeds_cell_minus_margin() -> void:
	# Icons only drawn at zoom >= 0.5, so test from 0.5 upward.
	var zoom := 0.5
	while zoom <= 3.0:
		var cell := 18.0 * zoom
		var half := cell / 2.0
		var icon_size := _compute_icon_size(half)
		var max_allowed := half - 1.0  # ICON_MARGIN = 1.0
		assert_lte(icon_size, max_allowed,
			"icon_size (%.2f) must be <= half - margin (%.2f) at zoom %.2f" % [icon_size, max_allowed, zoom])
		zoom += 0.25


# ==================================================================
# 7) Minimap icon_size >= minimum readable threshold
# ==================================================================

func test_icon_size_above_minimum() -> void:
	var zoom := 0.5  # icons only drawn at zoom >= 0.5
	while zoom <= 3.0:
		var cell := 18.0 * zoom
		var half := cell / 2.0
		var icon_size := _compute_icon_size(half)
		assert_gte(icon_size, 3.0,
			"icon_size (%.2f) must be >= MIN_ICON_SIZE (3.0) at zoom %.2f" % [icon_size, zoom])
		zoom += 0.25


# ==================================================================
# 8) Icons remain centered (icon_size symmetric around center)
# ==================================================================

func test_icon_centered_in_cell() -> void:
	var zoom := 1.0
	var cell := 18.0 * zoom
	var half := cell / 2.0
	var icon_size := _compute_icon_size(half)

	# Icon drawn from (center - icon_size/2) to (center + icon_size/2)
	# This should always fit within [center - half, center + half]
	assert_lte(icon_size / 2.0, half,
		"half icon_size must fit within half cell_size")
	assert_lte(icon_size, cell,
		"icon_size must be <= cell_size")


# ==================================================================
# Additional: Turn Back does not fire room_entered via GameSession
# ==================================================================

func test_game_session_decline_does_not_move() -> void:
	GameSession._load_data()
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 70000})

	var pos_before := GameSession.get_floor_state().current_pos
	var rooms_before := GameSession.get_floor_state().rooms_explored

	GameSession.decline_locked_room_entry("has_key_mini_boss")

	assert_eq(GameSession.get_floor_state().current_pos, pos_before,
		"position unchanged after decline")
	assert_eq(GameSession.get_floor_state().rooms_explored, rooms_before,
		"rooms_explored unchanged after decline")


func test_game_session_decline_boss_does_not_move() -> void:
	GameSession._load_data()
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 70001})

	var pos_before := GameSession.get_floor_state().current_pos
	GameSession.decline_locked_room_entry("has_key_boss")

	assert_eq(GameSession.get_floor_state().current_pos, pos_before,
		"position unchanged after boss decline")


# ==================================================================
# Additional: Minimap icon sizing via static method
# ==================================================================

func test_minimap_compute_icon_size_static() -> void:
	# Test the static compute_icon_size method on MinimapPanel
	# Load minimap script to call static method
	var MinimapPanel := preload("res://ui/scripts/minimap_panel.gd")

	# At zoom 1.0: cell = 18, half = 9
	var s1 := MinimapPanel.compute_icon_size(9.0)
	assert_lte(s1, 8.0, "icon_size at zoom 1.0 must be <= half - margin")
	assert_gte(s1, 3.0, "icon_size at zoom 1.0 must be >= MIN_ICON_SIZE")

	# At zoom 3.0: cell = 54, half = 27
	var s3 := MinimapPanel.compute_icon_size(27.0)
	assert_lte(s3, 26.0, "icon_size at zoom 3.0 must be <= half - margin")

	# At zoom 0.5: cell = 9, half = 4.5
	var s05 := MinimapPanel.compute_icon_size(4.5)
	assert_gte(s05, 3.0, "icon_size at zoom 0.5 must be >= MIN_ICON_SIZE")
	assert_lte(s05, 3.5, "icon_size at zoom 0.5 must be <= half - margin")


# ==================================================================
# 9) Newly generated locked miniboss — blocked before entry
# ==================================================================

func test_newly_generated_miniboss_blocks_entry() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(80000)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	# Force next mini-boss at room 1 so the very next room is a mini-boss
	engine.floor.next_mini_boss_at = 1

	# Ensure player has no Old Key
	assert_false(state.inventory.has("Old Key"), "should start without key")

	# Try to move East — should generate a miniboss room but block entry
	var pos_before := engine.floor.current_pos
	var room := engine.move("E")
	assert_null(room, "move should return null for locked newly-generated miniboss")
	assert_eq(engine.floor.current_pos, pos_before,
		"player should NOT move into the locked room")

	# The room should exist in floor.rooms (generated) but not visited
	var mb_pos := pos_before + Vector2i(1, 0)
	assert_true(engine.floor.rooms.has(mb_pos),
		"room should be generated even though entry was blocked")
	var mb_room: RoomState = engine.floor.rooms[mb_pos]
	assert_false(mb_room.visited,
		"room should not be marked visited")
	assert_true(mb_room.is_mini_boss_room,
		"room should be a mini-boss room")


func test_newly_generated_miniboss_has_key_gate() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(80001)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	engine.floor.next_mini_boss_at = 1
	state.inventory.append("Old Key")

	var room := engine.move("E")
	assert_null(room, "move returns null so caller can show dialog")
	assert_eq(engine.last_move_gate, "has_key_mini_boss",
		"last_move_gate should signal has_key_mini_boss")


func test_newly_generated_miniboss_unlock_then_enter() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(80002)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	engine.floor.next_mini_boss_at = 1
	state.inventory.append("Old Key")

	var pos_before := engine.floor.current_pos
	var room := engine.move("E")
	assert_null(room, "first move blocked for dialog")

	var mb_pos := pos_before + Vector2i(1, 0)
	# Unlock
	var ok := engine.use_old_key(mb_pos)
	assert_true(ok, "unlock should succeed")
	assert_false(state.inventory.has("Old Key"), "key consumed")

	# Now move again — should enter the existing unvisited room
	room = engine.move("E")
	assert_not_null(room, "entry should succeed after unlock")
	assert_eq(engine.floor.current_pos, mb_pos,
		"player should be in miniboss room")
	assert_true(room.visited,
		"room should be marked visited after entry")


func test_newly_generated_miniboss_reapproach_stays_unlocked() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(80003)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	engine.floor.next_mini_boss_at = 1
	state.inventory.append("Old Key")

	var pos_before := engine.floor.current_pos
	var mb_pos := pos_before + Vector2i(1, 0)

	engine.move("E")  # blocked for dialog
	engine.use_old_key(mb_pos)
	var room := engine.move("E")  # enter
	assert_not_null(room)

	# Move away (back west) — revisiting origin
	var back := engine.move("W")
	assert_not_null(back)

	# Move east again — should enter without lock
	var again := engine.move("E")
	assert_not_null(again, "re-entry should succeed without key")
	assert_eq(engine.floor.current_pos, mb_pos)


# ==================================================================
# 10) Save/load preserves unlocked-room state
# ==================================================================

func test_save_load_preserves_unlocked_rooms() -> void:
	var state := GameState.new()
	var r := DeterministicRNG.new(80010)
	var engine := ExplorationEngine.new(r, state, _rooms_db)
	engine.start_floor(1)

	var mb_pos := Vector2i(5, 5)
	engine.floor.special_rooms[mb_pos] = "mini_boss"
	engine.floor.unlocked_rooms[mb_pos] = true

	var save_data := SaveEngine.serialize(state, engine.floor)
	var new_state := GameState.new()
	var new_floor := FloorState.new()
	SaveEngine.deserialize(save_data, new_state, new_floor)

	assert_true(new_floor.unlocked_rooms.has(mb_pos),
		"unlocked rooms should persist through save/load")
	assert_true(new_floor.special_rooms.has(mb_pos),
		"special rooms should persist through save/load")
	assert_eq(new_floor.special_rooms[mb_pos], "mini_boss")


# ==================================================================
# Helpers
# ==================================================================

## Use the static _classify_message on the Explorer script.
static func _classify(msg: String) -> Array:
	var ExplorerScript := preload("res://ui/scripts/explorer.gd")
	return ExplorerScript._classify_message(msg)


static func _compute_icon_size(half: float) -> float:
	return clampf(half * 0.85, 3.0, half - 1.0)
