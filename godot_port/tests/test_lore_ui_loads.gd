extends "res://addons/gut/test.gd"
## Smoke test: LoreCodexPanel and CharacterStatusPanel instantiate
## and contain expected nodes.

var _codex_scene := preload("res://ui/scenes/LoreCodexPanel.tscn")
var _status_scene := preload("res://ui/scenes/CharacterStatusPanel.tscn")


func before_each() -> void:
	GameSession._load_data()


func test_codex_panel_instantiates() -> void:
	var panel := _codex_scene.instantiate()
	assert_not_null(panel, "LoreCodexPanel scene instantiated")
	assert_true(panel is PanelContainer, "LoreCodexPanel is PanelContainer")

	add_child(panel)
	await get_tree().process_frame

	var entry_list := panel.find_child("CodexEntryList", true, false)
	assert_not_null(entry_list, "CodexEntryList child exists")

	var detail_pane := panel.find_child("CodexDetailPane", true, false)
	assert_not_null(detail_pane, "CodexDetailPane child exists")

	var detail_title := panel.find_child("DetailTitle", true, false)
	assert_not_null(detail_title, "DetailTitle child exists")

	var detail_text := panel.find_child("DetailText", true, false)
	assert_not_null(detail_text, "DetailText child exists")

	panel.queue_free()
	await get_tree().process_frame


func test_character_status_panel_instantiates() -> void:
	var panel := _status_scene.instantiate()
	assert_not_null(panel, "CharacterStatusPanel scene instantiated")
	assert_true(panel is PanelContainer, "CharacterStatusPanel is PanelContainer")

	add_child(panel)
	await get_tree().process_frame

	var tabs := panel.find_child("StatusTabs", true, false)
	assert_not_null(tabs, "StatusTabs child exists")
	assert_true(tabs is TabContainer, "StatusTabs is TabContainer")

	assert_eq(tabs.get_tab_count(), 3, "Three tabs present (Character, Stats, Lore)")

	panel.queue_free()
	await get_tree().process_frame


func test_codex_panel_refresh_empty() -> void:
	GameSession.start_new_game()
	var panel := _codex_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	panel.refresh()
	await get_tree().process_frame

	assert_eq(panel._filtered_entries.size(), 0, "No entries in empty codex")

	panel.queue_free()
	await get_tree().process_frame
