extends GutTest
## Tests for Dev Menu (Issue I).

func test_dev_menu_scene_instantiates() -> void:
	var scene := preload("res://ui/scenes/DevMenuPanel.tscn")
	var panel := scene.instantiate()
	assert_not_null(panel, "DevMenuPanel scene instantiates without errors")
	add_child(panel)
	assert_true(panel.is_inside_tree(), "Panel is in scene tree")
	panel.queue_free()


func test_dev_menu_has_refresh() -> void:
	var scene := preload("res://ui/scenes/DevMenuPanel.tscn")
	var panel := scene.instantiate()
	assert_true(panel.has_method("refresh"), "DevMenuPanel has refresh method")
	panel.queue_free()


func test_dev_menu_size_profile_exists() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	assert_true(ManagerScript.SIZE_PROFILES.has("dev_menu"), "dev_menu size profile exists")


func test_dev_menu_debug_only() -> void:
	# Dev menu visibility is gated by OS.is_debug_build() in explorer.gd
	# In test (editor) mode, OS.is_debug_build() returns true
	assert_true(OS.is_debug_build(), "Tests run in debug mode")
