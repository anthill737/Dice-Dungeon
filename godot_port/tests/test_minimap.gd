extends "res://addons/gut/test.gd"
## Smoke tests for the MinimapPanel added in Step 10.
## Validates: instantiation, explored-room tracking, current-room indicator,
## and save/load rebuild.

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
