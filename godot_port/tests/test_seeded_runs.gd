extends GutTest
## Tests for seeded run support:
##  - SessionService.start_new_run with default and deterministic modes
##  - Seed validation
##  - StartAdventurePanel instantiation
##  - Explorer HUD seed label


# ----------------------------------------------------------------
# SessionService.start_new_run — default mode
# ----------------------------------------------------------------

func test_start_new_run_default_creates_default_rng():
	var mock := _MockGS.new()
	var svc := SessionService.new(mock)
	watch_signals(svc)

	svc.start_new_run({"rng_mode": "default"})
	assert_signal_emitted(svc, "run_started")
	assert_eq(mock.run_rng_mode, "default")
	assert_eq(mock.run_seed, -1)
	assert_true(mock.rng is DefaultRNG, "should be DefaultRNG")


func test_start_new_run_empty_options_uses_default():
	var mock := _MockGS.new()
	var svc := SessionService.new(mock)

	svc.start_new_run({})
	assert_eq(mock.run_rng_mode, "default")
	assert_true(mock.rng is DefaultRNG)


# ----------------------------------------------------------------
# SessionService.start_new_run — deterministic mode
# ----------------------------------------------------------------

func test_start_new_run_deterministic_creates_deterministic_rng():
	var mock := _MockGS.new()
	var svc := SessionService.new(mock)
	watch_signals(svc)

	svc.start_new_run({"rng_mode": "deterministic", "seed": 42})
	assert_signal_emitted(svc, "run_started")
	assert_eq(mock.run_rng_mode, "deterministic")
	assert_eq(mock.run_seed, 42)
	assert_true(mock.rng is DeterministicRNG, "should be DeterministicRNG")


func test_deterministic_run_is_reproducible():
	var mock1 := _MockGS.new()
	SessionService.new(mock1).start_new_run({"rng_mode": "deterministic", "seed": 999})
	var val1 := mock1.rng.rand_int(1, 100)

	var mock2 := _MockGS.new()
	SessionService.new(mock2).start_new_run({"rng_mode": "deterministic", "seed": 999})
	var val2 := mock2.rng.rand_int(1, 100)

	assert_eq(val1, val2, "same seed should produce identical first roll")


func test_deterministic_different_seed_differs():
	var mock1 := _MockGS.new()
	SessionService.new(mock1).start_new_run({"rng_mode": "deterministic", "seed": 1})

	var mock2 := _MockGS.new()
	SessionService.new(mock2).start_new_run({"rng_mode": "deterministic", "seed": 2})

	var vals1: Array = []
	var vals2: Array = []
	for _i in range(20):
		vals1.append(mock1.rng.rand_int(1, 1000))
		vals2.append(mock2.rng.rand_int(1, 1000))

	assert_ne(vals1, vals2, "different seeds should produce different sequences")


# ----------------------------------------------------------------
# Trace integration
# ----------------------------------------------------------------

func test_trace_records_deterministic_mode():
	var mock := _MockGS.new()
	SessionService.new(mock).start_new_run({"rng_mode": "deterministic", "seed": 12345})
	assert_eq(mock.trace.seed_value, 12345)
	assert_eq(mock.trace.rng_type, "DeterministicRNG")


func test_trace_records_default_mode():
	var mock := _MockGS.new()
	SessionService.new(mock).start_new_run({"rng_mode": "default"})
	assert_eq(mock.trace.seed_value, -1)
	assert_eq(mock.trace.rng_type, "DefaultRNG")


func test_trace_run_started_event_contains_rng_mode():
	var mock := _MockGS.new()
	SessionService.new(mock).start_new_run({"rng_mode": "deterministic", "seed": 42})
	var found := false
	for ev in mock.trace.events:
		if ev.get("type") == "run_started":
			assert_eq(ev["payload"].get("rng_mode"), "deterministic")
			assert_eq(ev["payload"].get("seed"), 42)
			found = true
			break
	assert_true(found, "run_started event should exist")


# ----------------------------------------------------------------
# Seed validation
# ----------------------------------------------------------------

func test_seed_input_rejects_empty():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)

	panel._seed_input.text = ""
	watch_signals(panel)
	panel._on_start_seeded()
	assert_signal_not_emitted(panel, "start_run_requested")
	assert_true(panel._error_label.text.length() > 0, "should show error")


func test_seed_input_rejects_non_integer():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)

	panel._seed_input.text = "abc"
	watch_signals(panel)
	panel._on_start_seeded()
	assert_signal_not_emitted(panel, "start_run_requested")
	assert_true(panel._error_label.text.length() > 0, "should show error")


func test_seed_input_accepts_valid_integer():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)

	panel._seed_input.text = "42"
	watch_signals(panel)
	panel._on_start_seeded()
	assert_signal_emitted(panel, "start_run_requested")


# ----------------------------------------------------------------
# StartAdventurePanel popup
# ----------------------------------------------------------------

func test_start_adventure_panel_instantiates():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)
	assert_not_null(panel, "panel should instantiate")
	assert_not_null(panel._btn_start, "start button exists")
	assert_not_null(panel._btn_seeded_toggle, "seeded toggle exists")
	assert_not_null(panel._seed_input, "seed input exists")


func test_start_adventure_panel_seed_row_hidden_by_default():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)
	assert_false(panel._seed_row.visible, "seed row should start hidden")
	assert_false(panel._btn_start_seeded.visible, "seeded button hidden")


func test_start_adventure_panel_toggle_reveals_seed():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)
	panel._on_seeded_toggle()
	assert_true(panel._seed_row.visible, "seed row visible after toggle")
	assert_true(panel._btn_start_seeded.visible, "seeded button visible")
	panel._on_seeded_toggle()
	assert_false(panel._seed_row.visible, "seed row hidden after second toggle")


func test_start_run_button_emits_default():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)
	watch_signals(panel)
	panel._on_start_run()
	assert_signal_emitted(panel, "start_run_requested")


func test_refresh_resets_ui():
	var panel := preload("res://ui/scenes/StartAdventurePanel.tscn").instantiate()
	add_child_autofree(panel)
	panel._on_seeded_toggle()
	panel._error_label.text = "Some error"
	panel._seed_input.text = "99999"
	panel.refresh()
	assert_false(panel._seed_row.visible, "reset hides seed row")
	assert_eq(panel._error_label.text, "", "reset clears error")
	assert_eq(panel._seed_input.text, "12345", "reset restores default seed")


# ----------------------------------------------------------------
# start_run() backward compat
# ----------------------------------------------------------------

func test_start_run_still_works():
	var mock := _MockGS.new()
	var svc := SessionService.new(mock)
	watch_signals(svc)
	svc.start_run()
	assert_signal_emitted(svc, "run_started")
	assert_eq(mock.run_rng_mode, "default")


# ----------------------------------------------------------------
# Mock GameSession
# ----------------------------------------------------------------

class _MockGS:
	extends RefCounted

	var combat = null
	var combat_pending: bool = false
	var game_state: GameState
	var rng: RNG
	var exploration: ExplorationEngine
	var inventory_engine: InventoryEngine
	var store_engine: StoreEngine
	var lore_engine: LoreEngine
	var rooms_db: Array = []
	var items_db: Dictionary = {}
	var lore_db: Dictionary = {}
	var trace: SessionTrace = SessionTrace.new()
	var pending_run_state: Dictionary = {}
	var run_rng_mode: String = "default"
	var run_seed: int = -1
	var _started: bool = false

	func get_saves_dir() -> String:
		return "user://test_saves"

	func start_new_game() -> void:
		start_new_run({})

	func start_new_run(options: Dictionary = {}) -> void:
		_started = true
		var rng_mode: String = options.get("rng_mode", "default")
		var seed_val: int = int(options.get("seed", -1))

		if rng_mode == "deterministic" and seed_val >= 0:
			rng = DeterministicRNG.new(seed_val)
			run_rng_mode = "deterministic"
			run_seed = seed_val
		else:
			rng = DefaultRNG.new()
			run_rng_mode = "default"
			run_seed = -1

		var trace_rng_type := "DeterministicRNG" if run_rng_mode == "deterministic" else "DefaultRNG"

		game_state = GameState.new()
		game_state.reset()
		exploration = ExplorationEngine.new(rng, game_state, rooms_db)
		inventory_engine = InventoryEngine.new(rng, game_state, items_db)
		store_engine = StoreEngine.new(game_state, items_db)
		lore_engine = LoreEngine.new(rng, game_state, lore_db)
		combat = null
		combat_pending = false

		trace.reset(run_seed, trace_rng_type)
		trace.difficulty = game_state.difficulty
		trace.record("run_started", {
			"difficulty": game_state.difficulty,
			"rng_mode": run_rng_mode,
			"seed": run_seed,
		})

	func has_pending_run_state() -> bool:
		return not pending_run_state.is_empty()

	func consume_pending_run_state() -> Dictionary:
		var state := pending_run_state
		pending_run_state = {}
		return state
