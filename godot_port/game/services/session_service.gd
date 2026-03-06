class_name SessionService
extends RefCounted
## Manages session lifecycle: starting a run, ending a run, quitting to
## the main menu.  Owns cleanup responsibilities (nulling engines, resetting
## combat state) so that orphan nodes are avoided.
##
## No UI code — emits signals that the composition layer (Explorer / MainMenu)
## can subscribe to for scene-switching and overlay teardown.

signal run_started()
signal run_ended()
signal quit_requested()

var _game_session


func _init(game_session) -> void:
	_game_session = game_session


func start_run() -> void:
	_game_session.start_new_game()
	run_started.emit()


## Canonical entry point for starting a new run with options.
## options may contain:
##   rng_mode: "default" | "deterministic"
##   seed:     int (used when rng_mode == "deterministic")
func start_new_run(options: Dictionary = {}) -> void:
	_game_session.start_new_run(options)
	run_started.emit()


## Canonical entry point for loading a saved run from the Main Menu.
## Loads the save data, rebuilds all engines, stores a handoff dict in
## GameSession.pending_run_state so Explorer can consume it, and emits
## run_started.  Returns true on success.
func start_run_from_save(slot_id: int) -> bool:
	var saves_dir: String = _game_session.get_saves_dir()
	var gs := GameState.new()
	var fs := FloorState.new()
	var ok := SaveEngine.load_from_slot(saves_dir, slot_id, gs, fs)
	if not ok:
		return false

	_game_session.game_state = gs
	_game_session.rng = DefaultRNG.new()
	_game_session.exploration = ExplorationEngine.new(
		_game_session.rng, gs, _game_session.rooms_db, _game_session.container_db)
	_game_session.exploration.floor = fs
	_game_session.inventory_engine = InventoryEngine.new(
		_game_session.rng, gs, _game_session.items_db)
	_game_session.store_engine = StoreEngine.new(gs, _game_session.items_db)
	_game_session.lore_engine = LoreEngine.new(
		_game_session.rng, gs, _game_session.lore_db)
	_game_session.combat = null
	_game_session.combat_pending = false

	_game_session.trace.reset(-1, "DefaultRNG", "default")
	_game_session.trace.difficulty = gs.difficulty
	_game_session.trace.record("loaded", {"slot": slot_id, "name": ""})
	_game_session.trace.set_floor(fs.floor_index)
	_game_session.trace.set_coord(fs.current_pos)

	_game_session.pending_run_state = {
		"source": "save",
		"slot_id": slot_id,
	}

	run_started.emit()
	return true


func end_run() -> void:
	if _game_session.combat != null:
		_game_session.combat = null
	_game_session.combat_pending = false
	run_ended.emit()


func quit_to_main_menu() -> void:
	end_run()
	quit_requested.emit()
