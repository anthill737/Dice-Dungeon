extends "res://addons/gut/test.gd"
## Minimap tests — validates data/state mapping (not pixels).
## Covers: instantiation, model accuracy, visibility, special markers,
## blocked edges, follow behavior, and save/load rebuild.

var _minimap_scene := preload("res://ui/scenes/MinimapPanel.tscn")
var _explorer_scene := preload("res://ui/scenes/Explorer.tscn")


func before_each() -> void:
	GameSession._load_data()


# ------------------------------------------------------------------
# 1) Explorer scene contains MinimapPanel
# ------------------------------------------------------------------

func test_explorer_has_minimap_panel() -> void:
	GameSession.start_new_game()
	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	assert_not_null(explorer._minimap_panel, "MinimapPanel exists on Explorer")
	assert_true(explorer._minimap_panel is PanelContainer, "MinimapPanel is a PanelContainer")

	explorer.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 2) Standalone instantiation
# ------------------------------------------------------------------

func test_minimap_instantiates() -> void:
	var panel := _minimap_scene.instantiate()
	assert_not_null(panel, "MinimapPanel scene instantiated")
	assert_true(panel is PanelContainer, "MinimapPanel is PanelContainer")

	add_child(panel)
	await get_tree().process_frame

	var canvas := panel.find_child("MinimapCanvas", true, false)
	assert_not_null(canvas, "MinimapCanvas child exists")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 3) Explored room count increments on movement
# ------------------------------------------------------------------

func test_explored_rooms_increment() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var initial_count: int = panel.get_explored_room_count()
	assert_gt(initial_count, 0, "Entrance room counted as explored")

	var moved := false
	for dir in ["N", "E", "S", "W"]:
		var result := GameSession.move_direction(dir)
		if result != null:
			if GameSession.combat_pending:
				var r := GameSession.get_current_room()
				if r != null:
					r.combat_escaped = true
				GameSession.combat_pending = false
				GameSession.state_changed.emit()
			moved = true
			break

	if moved:
		await get_tree().process_frame
		var new_count: int = panel.get_explored_room_count()
		assert_gt(new_count, initial_count, "Room count increased after move")
	else:
		pending("All directions blocked — rare but possible")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 4) Current room indicator updates on movement
# ------------------------------------------------------------------

func test_current_room_updates() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var start_pos: Vector2i = panel.get_current_room_pos()

	var moved := false
	for dir in ["N", "E", "S", "W"]:
		var result := GameSession.move_direction(dir)
		if result != null:
			if GameSession.combat_pending:
				var r := GameSession.get_current_room()
				if r != null:
					r.combat_escaped = true
				GameSession.combat_pending = false
				GameSession.state_changed.emit()
			moved = true
			break

	if moved:
		await get_tree().process_frame
		var new_pos: Vector2i = panel.get_current_room_pos()
		assert_ne(new_pos, start_pos, "Current room position changed after move")
	else:
		pending("All directions blocked — rare but possible")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 5) Save/Load — minimap rebuilds from restored FloorState
# ------------------------------------------------------------------

func test_save_load_rebuild() -> void:
	GameSession.start_new_game()

	for dir in ["N", "E", "S", "W", "N", "E"]:
		GameSession.move_direction(dir)
		if GameSession.combat_pending:
			var r := GameSession.get_current_room()
			if r != null:
				r.combat_escaped = true
			GameSession.combat_pending = false

	var gs := GameSession.game_state
	var fs := GameSession.get_floor_state()
	var json_str := SaveEngine.save_to_string(gs, fs)

	var pre_rooms := fs.rooms.size()
	var pre_pos := fs.current_pos

	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	var ok := SaveEngine.load_from_string(json_str, gs2, fs2)
	assert_true(ok, "Load succeeded")

	GameSession.game_state = gs2
	GameSession.rng = DefaultRNG.new()
	GameSession.exploration = ExplorationEngine.new(GameSession.rng, gs2, GameSession.rooms_db)
	GameSession.exploration.floor = fs2
	GameSession.state_changed.emit()

	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_eq(panel.get_explored_room_count(), pre_rooms,
		"Minimap room count matches saved state after load")
	assert_eq(panel.get_current_room_pos(), pre_pos,
		"Minimap current pos matches saved state after load")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 6) On new run start: player marker at starting room
# ------------------------------------------------------------------

func test_player_marker_at_start() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel.model_player_room,
		"model_player_room is set at start")
	assert_eq(panel.model_player_room, Vector2i.ZERO,
		"Player marker is at origin (starting room)")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 7) Starting room visible immediately
# ------------------------------------------------------------------

func test_starting_room_visible() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_true(panel.model_visible_rooms.has(Vector2i.ZERO),
		"Starting room (0,0) is in visible rooms list")
	assert_eq(panel.model_visible_rooms.size(), 1,
		"Only the starting room is visible at start")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 8) Special room markers — stairs
# ------------------------------------------------------------------

func test_special_marker_stairs() -> void:
	GameSession.start_new_game()
	var fs := GameSession.get_floor_state()
	var room := fs.get_current_room()
	room.has_stairs = true

	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	# Force model update after mutating room
	GameSession.state_changed.emit()
	await get_tree().process_frame

	assert_true(panel.model_special_markers.has(Vector2i.ZERO),
		"Starting room has a special marker")
	assert_eq(panel.model_special_markers[Vector2i.ZERO], "stairs",
		"Marker type is 'stairs'")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 9) Special room markers — store
# ------------------------------------------------------------------

func test_special_marker_store() -> void:
	GameSession.start_new_game()
	var fs := GameSession.get_floor_state()
	var room := fs.get_current_room()
	room.has_store = true
	fs.store_found = true
	fs.store_pos = Vector2i.ZERO

	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	GameSession.state_changed.emit()
	await get_tree().process_frame

	assert_true(panel.model_special_markers.has(Vector2i.ZERO),
		"Starting room has a special marker")
	assert_eq(panel.model_special_markers[Vector2i.ZERO], "store",
		"Marker type is 'store'")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 10) Special room markers — boss locked
# ------------------------------------------------------------------

func test_special_marker_boss_locked() -> void:
	GameSession.start_new_game()
	var fs := GameSession.get_floor_state()
	var room := fs.get_current_room()
	room.is_boss_room = true
	room.has_combat = true
	fs.special_rooms[Vector2i.ZERO] = "boss"
	# Not in unlocked_rooms → should be "locked"

	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	GameSession.state_changed.emit()
	await get_tree().process_frame

	assert_true(panel.model_special_markers.has(Vector2i.ZERO),
		"Boss room has a special marker")
	assert_eq(panel.model_special_markers[Vector2i.ZERO], "locked",
		"Marker type is 'locked' for undefeated boss in special_rooms")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 11) Special room markers — boss defeated
# ------------------------------------------------------------------

func test_special_marker_boss_defeated() -> void:
	GameSession.start_new_game()
	var fs := GameSession.get_floor_state()
	var room := fs.get_current_room()
	room.is_boss_room = true
	room.enemies_defeated = true
	fs.special_rooms[Vector2i.ZERO] = "boss"
	fs.unlocked_rooms[Vector2i.ZERO] = true

	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	GameSession.state_changed.emit()
	await get_tree().process_frame

	assert_eq(panel.model_special_markers[Vector2i.ZERO], "defeated",
		"Marker type is 'defeated' for beaten boss")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 12) Blocked edges appear in model
# ------------------------------------------------------------------

func test_blocked_edges_in_model() -> void:
	GameSession.start_new_game()
	var fs := GameSession.get_floor_state()
	var room := fs.get_current_room()
	# Force a blocked exit
	if "N" not in room.blocked_exits:
		room.blocked_exits.append("N")
		room.exits["N"] = false

	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	GameSession.state_changed.emit()
	await get_tree().process_frame

	var found_blocked := false
	for edge in panel.model_blocked_edges:
		if edge["pos"] == Vector2i.ZERO and edge["dir"] == "N":
			found_blocked = true
			break
	assert_true(found_blocked,
		"Blocked edge (0,0 N) is present in model_blocked_edges")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 13) Follow behavior: center target updates on move
# ------------------------------------------------------------------

func test_follow_center_target_updates() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_eq(panel.model_center_target, Vector2i.ZERO,
		"Center target starts at origin")

	var moved := false
	for dir in ["N", "E", "S", "W"]:
		var result := GameSession.move_direction(dir)
		if result != null:
			if GameSession.combat_pending:
				var r := GameSession.get_current_room()
				if r != null:
					r.combat_escaped = true
				GameSession.combat_pending = false
				GameSession.state_changed.emit()
			moved = true
			break

	if moved:
		await get_tree().process_frame
		assert_eq(panel.model_center_target, panel.model_player_room,
			"Center target matches player room after move")
		assert_ne(panel.model_center_target, Vector2i.ZERO,
			"Center target is no longer at origin after move")
	else:
		pending("All directions blocked — rare but possible")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 14) Tooltip child exists
# ------------------------------------------------------------------

func test_tooltip_node_exists() -> void:
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var tooltip := panel.find_child("MinimapTooltip", true, false)
	assert_not_null(tooltip, "MinimapTooltip label exists")
	assert_false(tooltip.visible, "Tooltip starts hidden")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# 15) Multiple rooms visible after movement
# ------------------------------------------------------------------

func test_visible_rooms_grow_after_moves() -> void:
	GameSession.start_new_game()
	var panel := _minimap_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var initial_visible: int = panel.model_visible_rooms.size()

	var moves_made := 0
	for dir in ["N", "E", "S", "W"]:
		var result := GameSession.move_direction(dir)
		if result != null:
			if GameSession.combat_pending:
				var r := GameSession.get_current_room()
				if r != null:
					r.combat_escaped = true
				GameSession.combat_pending = false
				GameSession.state_changed.emit()
			moves_made += 1
			if moves_made >= 2:
				break

	if moves_made > 0:
		await get_tree().process_frame
		assert_gt(panel.model_visible_rooms.size(), initial_visible,
			"More rooms visible after movement")
	else:
		pending("Could not move in any direction")

	panel.queue_free()
	await get_tree().process_frame
