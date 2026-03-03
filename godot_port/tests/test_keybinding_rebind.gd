extends GutTest
## Test that keybinding changes are applied to the InputMap immediately.

const CFG_PATH := "user://settings.cfg"


func before_each() -> void:
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func after_all() -> void:
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func test_rebind_updates_input_map() -> void:
	var sm := _make_manager()

	sm.set_keybinding("move_north", KEY_UP)
	assert_true(InputMap.has_action("move_north"), "action exists")

	var events := InputMap.action_get_events("move_north")
	assert_eq(events.size(), 1, "exactly one event")
	var ev: InputEventKey = events[0] as InputEventKey
	assert_not_null(ev, "event is InputEventKey")
	assert_eq(int(ev.keycode), KEY_UP, "keycode updated to Up arrow")
	sm.queue_free()


func test_rebind_replaces_previous_event() -> void:
	var sm := _make_manager()

	sm.set_keybinding("move_south", KEY_DOWN)
	sm.set_keybinding("move_south", KEY_KP_2)

	var events := InputMap.action_get_events("move_south")
	assert_eq(events.size(), 1, "only one event after double rebind")
	var ev: InputEventKey = events[0] as InputEventKey
	assert_eq(int(ev.keycode), KEY_KP_2, "latest binding wins")
	sm.queue_free()


func test_reset_defaults_restores_wasd() -> void:
	var sm := _make_manager()

	sm.set_keybinding("move_north", KEY_UP)
	sm.set_keybinding("move_south", KEY_DOWN)
	sm.reset_keybindings_to_defaults()

	var events_n := InputMap.action_get_events("move_north")
	var ev_n: InputEventKey = events_n[0] as InputEventKey
	assert_eq(int(ev_n.keycode), KEY_W, "north reset to W")

	var events_s := InputMap.action_get_events("move_south")
	var ev_s: InputEventKey = events_s[0] as InputEventKey
	assert_eq(int(ev_s.keycode), KEY_S, "south reset to S")
	sm.queue_free()


func test_all_default_actions_registered() -> void:
	var sm := _make_manager()

	for action in sm.BINDABLE_ACTIONS:
		assert_true(InputMap.has_action(action), "action '%s' registered" % action)

	sm.queue_free()


func _make_manager() -> Node:
	var script := load("res://game/core/settings/settings_manager.gd")
	var sm := Node.new()
	sm.set_script(script)
	add_child(sm)
	return sm
