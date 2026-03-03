extends GutTest
## Tests for SessionService — headless, no scene tree needed.


func test_end_run_emits_signal():
	var gs_node := Node.new()
	gs_node.set_script(null)
	gs_node.set_meta("combat", null)
	gs_node.set_meta("combat_pending", false)

	var mock_gs := _MockGameSession.new()
	var svc := SessionService.new(mock_gs)
	watch_signals(svc)
	svc.end_run()
	assert_signal_emitted(svc, "run_ended")


func test_end_run_clears_combat():
	var mock_gs := _MockGameSession.new()
	mock_gs.combat = RefCounted.new()
	mock_gs.combat_pending = true
	var svc := SessionService.new(mock_gs)
	svc.end_run()
	assert_null(mock_gs.combat, "combat should be null after end_run")
	assert_false(mock_gs.combat_pending, "combat_pending should be false after end_run")


func test_quit_emits_quit_requested():
	var mock_gs := _MockGameSession.new()
	var svc := SessionService.new(mock_gs)
	watch_signals(svc)
	svc.quit_to_main_menu()
	assert_signal_emitted(svc, "quit_requested")
	assert_signal_emitted(svc, "run_ended")


# Minimal stand-in for GameSession so tests run headlessly without autoloads.
class _MockGameSession:
	extends RefCounted
	var combat = null
	var combat_pending: bool = false
	var _started: bool = false
	func start_new_game() -> void:
		_started = true
