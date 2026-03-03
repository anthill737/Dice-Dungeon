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


func end_run() -> void:
	if _game_session.combat != null:
		_game_session.combat = null
	_game_session.combat_pending = false
	run_ended.emit()


func quit_to_main_menu() -> void:
	end_run()
	quit_requested.emit()
