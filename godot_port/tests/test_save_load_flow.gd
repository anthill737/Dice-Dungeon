extends GutTest
## Tests for save/load flow improvements:
##  - SessionService.start_run_from_save (load from Main Menu)
##  - Overwrite-save confirmation dialog
##  - SaveLoadService.slot_has_save
##  - SaveLoadPanel context-aware behavior


var _tmp_dir: String


func before_each():
	_tmp_dir = "user://test_slflow_%d" % randi()
	if not DirAccess.dir_exists_absolute(_tmp_dir):
		DirAccess.make_dir_recursive_absolute(_tmp_dir)


func after_each():
	for i in range(1, SaveEngine.MAX_SLOTS + 1):
		SaveEngine.delete_slot(_tmp_dir, i)
	if DirAccess.dir_exists_absolute(_tmp_dir):
		DirAccess.remove_absolute(_tmp_dir)


func _make_state(gold: int = 42, hp: int = 30, floor_num: int = 2) -> Array:
	var gs := GameState.new()
	gs.reset()
	gs.gold = gold
	gs.health = hp
	gs.floor = floor_num
	var fs := FloorState.new()
	fs.floor_index = floor_num
	fs.current_pos = Vector2i(1, 1)
	return [gs, fs]


func _save_to_slot(slot: int, gold: int = 42, hp: int = 30, floor_num: int = 2) -> void:
	var pair := _make_state(gold, hp, floor_num)
	SaveEngine.save_to_slot(pair[0], pair[1], _tmp_dir, slot, "Test Slot %d" % slot)


# ----------------------------------------------------------------
# SessionService.start_run_from_save
# ----------------------------------------------------------------

func test_start_run_from_save_loads_state():
	_save_to_slot(3, 99, 45, 5)
	var mock := _MockGameSessionFull.new(_tmp_dir)
	var svc := SessionService.new(mock)
	watch_signals(svc)

	var ok := svc.start_run_from_save(3)
	assert_true(ok, "start_run_from_save should succeed for filled slot")
	assert_signal_emitted(svc, "run_started")
	assert_eq(mock.game_state.gold, 99, "gold should be 99")
	assert_eq(mock.game_state.health, 45, "health should be 45")
	assert_eq(mock.game_state.floor, 5, "floor should be 5")
	assert_not_null(mock.exploration, "exploration engine should be created")
	assert_not_null(mock.inventory_engine, "inventory engine should be created")
	assert_not_null(mock.store_engine, "store engine should be created")
	assert_not_null(mock.lore_engine, "lore engine should be created")
	assert_null(mock.combat, "combat should be null after load")
	assert_false(mock.combat_pending, "combat_pending should be false after load")


func test_start_run_from_save_sets_pending_run_state():
	_save_to_slot(2)
	var mock := _MockGameSessionFull.new(_tmp_dir)
	var svc := SessionService.new(mock)

	svc.start_run_from_save(2)
	assert_false(mock.pending_run_state.is_empty(), "pending_run_state should be set")
	assert_eq(mock.pending_run_state.get("source"), "save")
	assert_eq(mock.pending_run_state.get("slot_id"), 2)


func test_start_run_from_save_fails_on_empty_slot():
	var mock := _MockGameSessionFull.new(_tmp_dir)
	var svc := SessionService.new(mock)
	watch_signals(svc)

	var ok := svc.start_run_from_save(7)
	assert_false(ok, "start_run_from_save should fail for empty slot")
	assert_signal_not_emitted(svc, "run_started")
	assert_true(mock.pending_run_state.is_empty(), "pending_run_state should stay empty on failure")


func test_start_run_from_save_does_not_call_start_new_game():
	_save_to_slot(1)
	var mock := _MockGameSessionFull.new(_tmp_dir)
	var svc := SessionService.new(mock)

	svc.start_run_from_save(1)
	assert_false(mock._started, "start_new_game should NOT be called during load")


# ----------------------------------------------------------------
# GameSession handoff helpers
# ----------------------------------------------------------------

func test_game_session_has_pending_run_state():
	var mock := _MockGameSessionFull.new(_tmp_dir)
	assert_false(mock.has_pending_run_state(), "should be false initially")
	mock.pending_run_state = {"source": "save", "slot_id": 1}
	assert_true(mock.has_pending_run_state(), "should be true after set")


func test_game_session_consume_clears_state():
	var mock := _MockGameSessionFull.new(_tmp_dir)
	mock.pending_run_state = {"source": "save", "slot_id": 1}
	var consumed := mock.consume_pending_run_state()
	assert_eq(consumed.get("slot_id"), 1)
	assert_false(mock.has_pending_run_state(), "should be cleared after consume")


# ----------------------------------------------------------------
# SaveLoadService.slot_has_save
# ----------------------------------------------------------------

func test_slot_has_save_returns_false_for_empty():
	var svc := SaveLoadService.new(_tmp_dir)
	assert_false(svc.slot_has_save(1), "empty slot should return false")


func test_slot_has_save_returns_true_for_filled():
	_save_to_slot(1)
	var svc := SaveLoadService.new(_tmp_dir)
	assert_true(svc.slot_has_save(1), "filled slot should return true")


func test_slot_has_save_returns_false_after_delete():
	_save_to_slot(1)
	var svc := SaveLoadService.new(_tmp_dir)
	svc.delete_slot(1)
	assert_false(svc.slot_has_save(1), "deleted slot should return false")


func test_slot_has_save_invalid_slot():
	var svc := SaveLoadService.new(_tmp_dir)
	assert_false(svc.slot_has_save(0), "invalid slot 0")
	assert_false(svc.slot_has_save(11), "invalid slot 11")
	assert_false(svc.slot_has_save(-1), "invalid slot -1")


# ----------------------------------------------------------------
# SaveLoadPanel overwrite confirmation
# ----------------------------------------------------------------

func test_panel_occupied_slot_check():
	_save_to_slot(3)
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	add_child_autofree(panel)

	panel._slots_data = SaveEngine.list_slots(_tmp_dir)
	assert_true(panel._is_slot_occupied(3), "slot 3 should be occupied")
	assert_false(panel._is_slot_occupied(1), "slot 1 should be empty")


func test_panel_confirm_overlay_starts_hidden():
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	add_child_autofree(panel)
	assert_false(panel._confirm_overlay.visible, "confirm overlay should start hidden")


func test_panel_show_confirm_overlay():
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	add_child_autofree(panel)
	panel._show_confirm_overlay(5)
	assert_true(panel._confirm_overlay.visible, "confirm overlay should be visible")
	assert_true(panel._confirm_label.text.find("Slot 5") >= 0, "should mention slot number")


func test_panel_cancel_hides_overlay():
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	add_child_autofree(panel)
	panel._pending_save_slot = 5
	panel._confirm_overlay.visible = true
	panel._on_overwrite_cancelled()
	assert_false(panel._confirm_overlay.visible, "overlay should be hidden after cancel")
	assert_eq(panel._pending_save_slot, -1, "pending slot should be cleared")


func test_panel_context_main_menu_disables_save():
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	panel.panel_context = panel.PanelContext.MAIN_MENU
	add_child_autofree(panel)
	panel._slots_data = SaveEngine.list_slots(_tmp_dir)
	panel.refresh()
	assert_true(panel._btn_save.disabled, "save should be disabled in MAIN_MENU context")


func test_panel_main_menu_load_emits_signal_for_filled_slot():
	_save_to_slot(2)
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	panel.panel_context = panel.PanelContext.MAIN_MENU
	add_child_autofree(panel)

	panel._slots_data = SaveEngine.list_slots(_tmp_dir)
	panel._slot_list.clear()
	for slot_info in panel._slots_data:
		if slot_info.get("empty", false):
			panel._slot_list.add_item("Slot %d: [empty]" % slot_info["slot"])
		else:
			panel._slot_list.add_item("Slot %d: %s" % [slot_info["slot"], slot_info.get("save_name", "")])
	panel._slot_list.select(1)

	watch_signals(panel)
	panel._on_load()
	assert_signal_emitted(panel, "load_into_game_requested")


func test_panel_main_menu_load_noop_for_empty_slot():
	var panel := preload("res://ui/scenes/SaveLoadPanel.tscn").instantiate()
	panel.panel_context = panel.PanelContext.MAIN_MENU
	add_child_autofree(panel)

	panel._slots_data = SaveEngine.list_slots(_tmp_dir)
	panel._slot_list.clear()
	for slot_info in panel._slots_data:
		panel._slot_list.add_item("Slot %d: [empty]" % slot_info["slot"])
	panel._slot_list.select(0)

	watch_signals(panel)
	panel._on_load()
	assert_signal_not_emitted(panel, "load_into_game_requested")


# ----------------------------------------------------------------
# Mock: full GameSession stand-in for start_run_from_save tests
# ----------------------------------------------------------------

class _MockGameSessionFull:
	extends RefCounted
	var combat = null
	var combat_pending: bool = false
	var _started: bool = false
	var game_state: GameState
	var rng: RNG
	var exploration: ExplorationEngine
	var inventory_engine: InventoryEngine
	var store_engine: StoreEngine
	var lore_engine: LoreEngine
	var rooms_db: Array = []
	var items_db: Dictionary = {}
	var lore_db: Dictionary = {}
	var container_db: Dictionary = {}
	var trace: SessionTrace = SessionTrace.new()
	var pending_run_state: Dictionary = {}
	var _saves_dir: String

	func _init(saves_dir: String = "user://test_saves") -> void:
		_saves_dir = saves_dir

	func get_saves_dir() -> String:
		return _saves_dir

	func start_new_game() -> void:
		_started = true

	func has_pending_run_state() -> bool:
		return not pending_run_state.is_empty()

	func consume_pending_run_state() -> Dictionary:
		var state := pending_run_state
		pending_run_state = {}
		return state
