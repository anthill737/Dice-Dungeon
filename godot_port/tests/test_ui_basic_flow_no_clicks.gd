extends "res://addons/gut/test.gd"
## Smoke test: exercise core game flow via code — no GUI clicks required.
## Instantiates the Explorer scene, injects engines via GameSession,
## simulates a new run, a few moves, and checks that UI state updates.


func before_each() -> void:
	GameSession._load_data()


func test_new_game_initialises_state() -> void:
	GameSession.start_new_game()

	assert_not_null(GameSession.game_state, "GameState created")
	assert_not_null(GameSession.exploration, "ExplorationEngine created")
	assert_not_null(GameSession.inventory_engine, "InventoryEngine created")
	assert_not_null(GameSession.store_engine, "StoreEngine created")
	assert_null(GameSession.combat, "No combat at start")

	assert_eq(GameSession.game_state.health, 50, "Starting HP is 50")
	assert_eq(GameSession.game_state.gold, 0, "Starting gold is 0")
	assert_eq(GameSession.game_state.floor, 1, "Starting floor is 1")

	var room := GameSession.get_current_room()
	assert_not_null(room, "Current room exists after start_floor")
	assert_true(room.visited, "Entrance room is visited")


func test_movement_updates_position() -> void:
	GameSession.start_new_game()
	var start_pos := GameSession.get_floor_state().current_pos

	var moved := false
	for dir in ["N", "S", "E", "W"]:
		var result := GameSession.move_direction(dir)
		if result != null:
			moved = true
			break

	if moved:
		var new_pos := GameSession.get_floor_state().current_pos
		assert_ne(new_pos, start_pos, "Position changed after move")

		var new_room := GameSession.get_current_room()
		assert_not_null(new_room, "New room exists")
		assert_true(new_room.visited, "New room marked visited")
	else:
		pending("All directions blocked from entrance — rare but possible")


func test_multiple_moves_no_crash() -> void:
	GameSession.start_new_game()

	var directions := ["N", "E", "S", "W", "N", "N", "E", "E", "S", "W"]
	for dir in directions:
		GameSession.move_direction(dir)

	assert_not_null(GameSession.get_current_room(), "Room exists after 10 move attempts")
	assert_gt(GameSession.game_state.floor, 0, "Floor is positive")


func test_combat_flow_no_crash() -> void:
	GameSession.start_new_game()

	var gs := GameSession.game_state
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.data["threats"] = ["Goblin"]

	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}

	GameSession.start_combat_for_room(room)
	assert_not_null(GameSession.combat, "Combat engine created")
	assert_true(gs.in_combat, "Player in combat")

	var ce := GameSession.combat
	ce.player_roll()
	var alive := ce.get_alive_enemies()
	assert_gt(alive.size(), 0, "At least one enemy alive")

	var result := ce.player_attack(0)
	assert_not_null(result, "Attack returns TurnResult")

	GameSession.end_combat(true)
	assert_null(GameSession.combat, "Combat cleared after end")
	assert_false(gs.in_combat, "Player no longer in combat")


func test_inventory_operations() -> void:
	GameSession.start_new_game()

	var inv := GameSession.inventory_engine
	var gs := GameSession.game_state
	assert_eq(gs.inventory.size(), 0, "Inventory starts empty")

	inv.add_item_to_inventory("Health Potion", "found")
	assert_eq(gs.inventory.size(), 1, "Item added")
	assert_eq(gs.inventory[0], "Health Potion", "Correct item")

	gs.health = 30
	var result := inv.use_item(0)
	assert_true(result.get("ok", false), "Item used successfully")
	assert_gt(gs.health, 30, "Health increased after potion")


func test_store_generates_inventory() -> void:
	GameSession.start_new_game()
	var items := GameSession.store_engine.generate_store_inventory()
	assert_gt(items.size(), 0, "Store has items")
	for entry in items:
		assert_eq(entry.size(), 2, "Each entry is [name, price]")


func test_save_load_round_trip() -> void:
	GameSession.start_new_game()
	var gs := GameSession.game_state
	gs.gold = 42
	gs.health = 35

	var fs := GameSession.get_floor_state()
	var json_str := SaveEngine.save_to_string(gs, fs, 1, "test_save")
	assert_gt(json_str.length(), 0, "Serialised to JSON")

	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	var ok := SaveEngine.load_from_string(json_str, gs2, fs2)
	assert_true(ok, "Deserialised successfully")
	assert_eq(gs2.gold, 42, "Gold preserved")
	assert_eq(gs2.health, 35, "Health preserved")


func test_explorer_scene_wiring() -> void:
	GameSession.start_new_game()

	var explorer := preload("res://ui/scenes/Explorer.tscn").instantiate()
	add_child(explorer)
	await get_tree().process_frame

	assert_not_null(explorer._floor_label, "Floor label exists")
	assert_not_null(explorer._hp_label, "HP label exists")
	assert_not_null(explorer._gold_label, "Gold label exists")
	assert_not_null(explorer._log_text, "Log text exists")

	assert_true(explorer._floor_label.text.contains("Floor"), "Floor label shows floor")
	assert_true(explorer._hp_label.text.contains("50"), "HP label shows health")

	explorer.queue_free()
	await get_tree().process_frame
