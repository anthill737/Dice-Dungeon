extends "res://addons/gut/test.gd"
## Tests that CombatPanel cannot be closed during pending/active combat,
## that Flee is only available during pending, and that victory properly
## clears combat and allows the panel to close.

var _explorer_scene := preload("res://ui/scenes/Explorer.tscn")


func _setup_combat_room() -> void:
	GameSession._load_data()
	GameSession.start_new_game()
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}


# ------------------------------------------------------------------
# A) Pending state: panel not closable, flee available, movement blocked
# ------------------------------------------------------------------

func test_A_pending_panel_not_closable_flee_visible() -> void:
	_setup_combat_room()

	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	assert_true(GameSession.is_pending_choice(), "combat_pending is true")
	assert_true(GameSession.is_combat_blocking(), "movement blocked")

	explorer._show_panel(explorer._combat_panel)
	explorer._combat_panel.refresh()
	await get_tree().process_frame

	# Close button must be hidden
	assert_false(explorer._combat_panel._btn_close.visible,
		"Close button hidden during pending")

	# Flee button must be visible and enabled
	assert_true(explorer._combat_panel._btn_flee.visible,
		"Flee button visible during pending")
	assert_false(explorer._combat_panel._btn_flee.disabled,
		"Flee button enabled during pending")

	# Attempt to close via handler => panel stays visible
	explorer._on_combat_close_requested()
	await get_tree().process_frame
	assert_true(explorer._combat_panel.visible,
		"CombatPanel still visible after close attempt during pending")
	assert_true(GameSession.is_pending_choice(),
		"combat_pending still true after close attempt")

	# ESC (_close_topmost_panel) must not close combat panel
	explorer._close_topmost_panel()
	await get_tree().process_frame
	assert_true(explorer._combat_panel.visible,
		"CombatPanel still visible after ESC during pending")

	# _close_all_panels must not close combat panel
	explorer._close_all_panels()
	await get_tree().process_frame
	assert_true(explorer._combat_panel.visible,
		"CombatPanel still visible after _close_all_panels during pending")

	# Movement still blocked
	assert_true(GameSession.is_combat_blocking(),
		"Movement still blocked throughout pending")

	explorer.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# B) Active combat: flee hidden, panel not closable
# ------------------------------------------------------------------

func test_B_active_combat_flee_hidden_panel_locked() -> void:
	_setup_combat_room()

	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()

	assert_true(GameSession.is_combat_active(), "combat_active is true")
	assert_false(GameSession.is_pending_choice(), "combat_pending cleared")
	assert_true(GameSession.is_combat_blocking(), "movement blocked")

	explorer._show_panel(explorer._combat_panel)
	explorer._combat_panel.refresh()
	await get_tree().process_frame

	# Flee button must be hidden
	assert_false(explorer._combat_panel._btn_flee.visible,
		"Flee button hidden during active combat")

	# Close button must be hidden
	assert_false(explorer._combat_panel._btn_close.visible,
		"Close button hidden during active combat")

	# Attempt to close via handler => panel stays
	explorer._on_combat_close_requested()
	await get_tree().process_frame
	assert_true(explorer._combat_panel.visible,
		"CombatPanel still visible after close attempt during active")

	# ESC => panel stays
	explorer._close_topmost_panel()
	await get_tree().process_frame
	assert_true(explorer._combat_panel.visible,
		"CombatPanel still visible after ESC during active")

	# _close_all_panels => panel stays
	explorer._close_all_panels()
	await get_tree().process_frame
	assert_true(explorer._combat_panel.visible,
		"CombatPanel still visible after _close_all_panels during active")

	# Movement still blocked
	assert_true(GameSession.is_combat_blocking(),
		"Movement still blocked during active combat")

	explorer.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# C) Victory: combat clears, panel hides, movement unblocks
# ------------------------------------------------------------------

func test_C_victory_clears_combat_panel_hides() -> void:
	_setup_combat_room()

	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()

	assert_not_null(GameSession.combat, "CombatEngine created")

	# Kill enemy => victory
	var alive := GameSession.combat.get_alive_enemies()
	assert_gt(alive.size(), 0, "Enemies present")
	alive[0].health = 0
	GameSession.end_combat(true)

	await get_tree().process_frame

	assert_null(GameSession.combat, "CombatEngine cleared")
	assert_false(GameSession.is_combat_blocking(), "Movement unblocked")
	assert_true(room.enemies_defeated, "Room enemies defeated")

	# Panel should be hidden (combat_ended triggers _on_combat_ended)
	# Give fade tween time to complete
	await get_tree().create_timer(0.3).timeout
	assert_false(explorer._combat_panel.visible,
		"CombatPanel hidden after victory")

	explorer.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# D) Sidebar flee button hidden during active combat
# ------------------------------------------------------------------

func test_D_sidebar_flee_hidden_during_active() -> void:
	_setup_combat_room()

	var explorer := _explorer_scene.instantiate()
	add_child(explorer)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	# During pending, sidebar flee should be visible
	explorer._refresh_ui()
	await get_tree().process_frame
	assert_true(explorer._btn_flee.visible,
		"Sidebar flee visible during pending")

	GameSession.accept_combat()
	explorer._refresh_ui()
	await get_tree().process_frame

	# During active combat, sidebar flee should be hidden
	assert_false(explorer._btn_flee.visible,
		"Sidebar flee hidden during active combat")

	explorer.queue_free()
	await get_tree().process_frame
