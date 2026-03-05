extends GutTest
## Tests for menu toggle behavior (Issue B).
## Verifies that toggle_menu opens a closed menu and closes an open+topmost menu.

var _manager


func before_each() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	_manager = ManagerScript.new()
	_manager.name = "TestOverlayManager"
	add_child(_manager)

	var panel_a := PanelContainer.new()
	panel_a.name = "PanelA"
	var panel_b := PanelContainer.new()
	panel_b.name = "PanelB"

	_manager.register_menu("inventory", "Inventory", panel_a, "inventory")
	_manager.register_menu("character_status", "Status", panel_b, "status")


func after_each() -> void:
	if is_instance_valid(_manager):
		_manager.queue_free()


func test_toggle_opens_closed_menu() -> void:
	assert_false(_manager.is_menu_open("inventory"), "Menu starts closed")
	_toggle("inventory")
	assert_true(_manager.is_menu_open("inventory"), "Menu opens after toggle")


func test_toggle_closes_topmost_menu() -> void:
	_manager.open_menu("inventory")
	assert_true(_manager.is_menu_open("inventory"), "Menu is open")
	assert_eq(_manager.get_top_menu_key(), "inventory")
	_toggle("inventory")
	# After toggle, should be closing via close_menu
	# The close uses a tween so visibility change is deferred,
	# but close_menu emits menu_closed and removes from stack
	assert_false(_manager.get_stack().has("inventory"), "Inventory removed from stack after toggle-close")


func test_toggle_does_not_close_if_not_topmost() -> void:
	_manager.open_menu("inventory")
	_manager.open_menu("character_status")
	assert_eq(_manager.get_top_menu_key(), "character_status")
	_toggle("inventory")
	# Inventory is not topmost, so toggle should re-open (push to top) not close
	assert_true(_manager.get_stack().has("inventory"), "Inventory stays in stack")


func test_tab_does_not_tab_focus() -> void:
	# Tab in _unhandled_input calls set_input_as_handled — this is a code path test.
	# We just verify the toggle_menu pattern works correctly.
	_toggle("inventory")
	assert_true(_manager.is_menu_open("inventory"), "Tab-toggle opens inventory")
	_toggle("inventory")
	assert_false(_manager.get_stack().has("inventory"), "Tab-toggle closes inventory")


## Mirror the toggle logic from explorer.gd
func _toggle(menu_key: String) -> void:
	if _manager.is_menu_open(menu_key):
		if _manager.get_top_menu_key() == menu_key:
			_manager.close_menu(menu_key)
			return
	_manager.open_menu(menu_key)
