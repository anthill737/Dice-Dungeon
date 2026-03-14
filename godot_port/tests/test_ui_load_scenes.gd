extends "res://addons/gut/test.gd"
## Smoke test: verify all UI scenes load without runtime errors and
## contain expected nodes.

var _main_menu_scene := preload("res://ui/scenes/MainMenu.tscn")
var _explorer_scene := preload("res://ui/scenes/Explorer.tscn")
var _combat_scene := preload("res://ui/scenes/CombatPanel.tscn")
var _inventory_scene := preload("res://ui/scenes/InventoryPanel.tscn")
var _store_scene := preload("res://ui/scenes/StorePanel.tscn")
var _save_load_scene := preload("res://ui/scenes/SaveLoadPanel.tscn")


func test_main_menu_loads() -> void:
	var scene := _main_menu_scene.instantiate()
	assert_not_null(scene, "MainMenu scene instantiated")

	add_child(scene)
	await get_tree().process_frame

	assert_not_null(scene.find_child("BtnStart", true, false), "BtnStart exists")
	assert_not_null(scene.find_child("BtnLoad", true, false), "BtnLoad exists")
	assert_not_null(scene.find_child("BtnSettings", true, false), "BtnSettings exists")
	assert_not_null(scene.find_child("BtnQuit", true, false), "BtnQuit exists")
	assert_not_null(scene.find_child("Title", true, false), "Title label exists")
	assert_eq(MusicService.get_active_context(), "main_menu", "main menu activates menu music")
	assert_eq(MusicService.get_active_cue(), "music_main_menu", "main menu cue stays active")
	assert_true(MusicService.is_playing(), "main menu music is playing")
	assert_eq(MusicService.get_active_track_path(), "res://assets/audio/music/Dice Dungeon.wav", "main menu theme uses Dice Dungeon.wav")

	scene.queue_free()
	await get_tree().process_frame


func test_explorer_scene_loads() -> void:
	var scene := _explorer_scene.instantiate()
	assert_not_null(scene, "Explorer scene instantiated")
	assert_true(scene is Control, "Explorer is a Control")
	scene.queue_free()


func test_combat_panel_loads() -> void:
	var scene := _combat_scene.instantiate()
	assert_not_null(scene, "CombatPanel scene instantiated")
	assert_true(scene is PanelContainer, "CombatPanel is PanelContainer")
	scene.queue_free()


func test_inventory_panel_loads() -> void:
	var scene := _inventory_scene.instantiate()
	assert_not_null(scene, "InventoryPanel scene instantiated")
	assert_true(scene is PanelContainer, "InventoryPanel is PanelContainer")
	scene.queue_free()


func test_store_panel_loads() -> void:
	var scene := _store_scene.instantiate()
	assert_not_null(scene, "StorePanel scene instantiated")
	assert_true(scene is PanelContainer, "StorePanel is PanelContainer")
	scene.queue_free()


func test_save_load_panel_loads() -> void:
	var scene := _save_load_scene.instantiate()
	assert_not_null(scene, "SaveLoadPanel scene instantiated")
	assert_true(scene is PanelContainer, "SaveLoadPanel is PanelContainer")
	scene.queue_free()
