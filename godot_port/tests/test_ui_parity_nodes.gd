extends "res://addons/gut/test.gd"
## UI parity tests: verify each panel instantiates in headless mode,
## key controls exist with stable node paths, and critical gating
## states render correctly.

var _combat_scene := preload("res://ui/scenes/CombatPanel.tscn")
var _saveload_scene := preload("res://ui/scenes/SaveLoadPanel.tscn")
var _status_scene := preload("res://ui/scenes/CharacterStatusPanel.tscn")
var _inventory_scene := preload("res://ui/scenes/InventoryPanel.tscn")


func before_each() -> void:
	GameSession._load_data()


# ------------------------------------------------------------------
# Combat Panel
# ------------------------------------------------------------------

func test_combat_panel_instantiates() -> void:
	var panel := _combat_scene.instantiate()
	assert_not_null(panel, "CombatPanel instantiated")
	assert_true(panel is PanelContainer, "CombatPanel is PanelContainer")
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel.find_child("DiceContainer", true, false),
		"DiceContainer exists")
	assert_not_null(panel.find_child("DamagePreviewLabel", true, false),
		"DamagePreviewLabel exists")
	assert_not_null(panel.find_child("RollsLabel", true, false),
		"RollsLabel exists")
	assert_not_null(panel.find_child("PlayerHPBar", true, false),
		"PlayerHPBar exists")
	assert_not_null(panel.find_child("EnemyHPBar", true, false),
		"EnemyHPBar exists")
	assert_not_null(panel.find_child("CombatLog", true, false),
		"CombatLog exists")
	assert_not_null(panel.find_child("EnemyList", true, false),
		"EnemyList exists")

	panel.queue_free()
	await get_tree().process_frame


func test_combat_panel_dice_count() -> void:
	var panel := _combat_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_eq(panel._dice_labels.size(), 5, "5 dice labels")
	assert_eq(panel._dice_panels.size(), 5, "5 dice panels")
	assert_eq(panel._lock_buttons.size(), 5, "5 lock buttons")

	panel.queue_free()
	await get_tree().process_frame


func test_combat_panel_buttons_exist() -> void:
	var panel := _combat_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel._btn_roll, "Roll button exists")
	assert_not_null(panel._btn_attack, "Attack button exists")
	assert_not_null(panel._btn_flee, "Flee button exists")
	assert_not_null(panel._btn_close, "Close button exists")

	assert_eq(panel._btn_attack.text, "ATTACK!", "Attack button text matches Python")
	assert_eq(panel._btn_roll.text, "Roll Dice", "Roll button text matches")

	panel.queue_free()
	await get_tree().process_frame


func test_combat_panel_hp_bars_are_progress_bars() -> void:
	var panel := _combat_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_true(panel._player_hp_bar is ProgressBar, "Player HP bar is ProgressBar")
	assert_true(panel._enemy_hp_bar is ProgressBar, "Enemy HP bar is ProgressBar")

	panel.queue_free()
	await get_tree().process_frame


func test_combat_panel_rolls_label_format() -> void:
	var panel := _combat_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_true(panel._rolls_label.text.begins_with("Rolls Remaining:"),
		"Rolls label matches Python format 'Rolls Remaining: X/Y'")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Save/Load Panel
# ------------------------------------------------------------------

func test_saveload_panel_instantiates() -> void:
	var panel := _saveload_scene.instantiate()
	assert_not_null(panel, "SaveLoadPanel instantiated")
	assert_true(panel is PanelContainer, "SaveLoadPanel is PanelContainer")
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel.find_child("SlotList", true, false),
		"SlotList exists")
	assert_not_null(panel.find_child("DetailPanel", true, false),
		"DetailPanel exists")
	assert_not_null(panel.find_child("DetailTitle", true, false),
		"DetailTitle exists")
	assert_not_null(panel.find_child("DetailInfo", true, false),
		"DetailInfo exists")
	assert_not_null(panel.find_child("RenameEdit", true, false),
		"RenameEdit exists")
	assert_not_null(panel.find_child("BtnSave", true, false),
		"BtnSave exists")
	assert_not_null(panel.find_child("BtnLoad", true, false),
		"BtnLoad exists")
	assert_not_null(panel.find_child("BtnDelete", true, false),
		"BtnDelete exists")
	assert_not_null(panel.find_child("BtnRename", true, false),
		"BtnRename exists")

	panel.queue_free()
	await get_tree().process_frame


func test_saveload_two_panel_layout() -> void:
	var panel := _saveload_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel._slot_list, "Slot list exists (left panel)")
	assert_not_null(panel._detail_panel, "Detail panel exists (right panel)")
	assert_not_null(panel._detail_title, "Detail title exists")
	assert_not_null(panel._detail_info, "Detail info exists")

	panel.queue_free()
	await get_tree().process_frame


func test_saveload_combat_gating() -> void:
	GameSession.start_new_game()
	var panel := _saveload_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	panel.refresh()
	assert_false(panel._btn_save.disabled,
		"Save enabled when not in combat")

	# Simulate combat state
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()

	panel.refresh()
	assert_true(panel._btn_save.disabled,
		"Save disabled during combat")

	GameSession.end_combat(true)
	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Character Status Panel
# ------------------------------------------------------------------

func test_character_status_instantiates() -> void:
	var panel := _status_scene.instantiate()
	assert_not_null(panel, "CharacterStatusPanel instantiated")
	assert_true(panel is PanelContainer, "CharacterStatusPanel is PanelContainer")
	add_child(panel)
	await get_tree().process_frame

	var tabs := panel.find_child("StatusTabs", true, false)
	assert_not_null(tabs, "StatusTabs exists")
	assert_true(tabs is TabContainer, "StatusTabs is TabContainer")
	assert_eq(tabs.get_tab_count(), 3, "Three tabs present")

	panel.queue_free()
	await get_tree().process_frame


func test_character_status_tab_names() -> void:
	var panel := _status_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var tabs: TabContainer = panel._tab_container
	assert_eq(tabs.get_tab_title(0), "Character", "First tab is 'Character'")
	assert_eq(tabs.get_tab_title(1), "Game Stats", "Second tab is 'Game Stats'")
	assert_eq(tabs.get_tab_title(2), "Lore Codex", "Third tab is 'Lore Codex'")

	panel.queue_free()
	await get_tree().process_frame


func test_character_status_info_nodes() -> void:
	var panel := _status_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel.find_child("CharacterInfo", true, false),
		"CharacterInfo RichTextLabel exists")
	assert_not_null(panel.find_child("StatsInfo", true, false),
		"StatsInfo RichTextLabel exists")

	panel.queue_free()
	await get_tree().process_frame


func test_character_status_sections_present() -> void:
	GameSession.start_new_game()
	var panel := _status_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	var char_text: String = panel._char_info.text
	assert_true(char_text.find("EQUIPPED GEAR") >= 0,
		"Equipped Gear section header present")
	assert_true(char_text.find("CHARACTER STATS") >= 0,
		"Character Stats section header present")
	assert_true(char_text.find("ACTIVE EFFECTS") >= 0,
		"Active Effects section header present")
	assert_true(char_text.find("RESOURCES") >= 0,
		"Resources section header present")

	panel.queue_free()
	await get_tree().process_frame


func test_character_stats_categories() -> void:
	GameSession.start_new_game()
	var panel := _status_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	var stats_text: String = panel._stats_info.text
	assert_true(stats_text.find("Combat") >= 0, "Combat category present")
	assert_true(stats_text.find("Economy") >= 0, "Economy category present")
	assert_true(stats_text.find("Items") >= 0, "Items category present")
	assert_true(stats_text.find("Exploration") >= 0, "Exploration category present")
	assert_true(stats_text.find("Lore") >= 0, "Lore category present")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Inventory Panel
# ------------------------------------------------------------------

func test_inventory_panel_instantiates() -> void:
	var panel := _inventory_scene.instantiate()
	assert_not_null(panel, "InventoryPanel instantiated")
	assert_true(panel is PanelContainer, "InventoryPanel is PanelContainer")
	add_child(panel)
	await get_tree().process_frame

	assert_not_null(panel.find_child("SlotsLabel", true, false),
		"SlotsLabel exists")
	assert_not_null(panel.find_child("EquipmentSummary", true, false),
		"EquipmentSummary exists")
	assert_not_null(panel.find_child("ItemList", true, false),
		"ItemList exists")
	assert_not_null(panel.find_child("HintLabel", true, false),
		"HintLabel exists")
	assert_not_null(panel.find_child("BtnUse", true, false),
		"BtnUse exists")
	assert_not_null(panel.find_child("BtnRead", true, false),
		"BtnRead exists")
	assert_not_null(panel.find_child("BtnEquip", true, false),
		"BtnEquip exists")
	assert_not_null(panel.find_child("BtnUnequip", true, false),
		"BtnUnequip exists")
	assert_not_null(panel.find_child("BtnDrop", true, false),
		"BtnDrop exists")

	panel.queue_free()
	await get_tree().process_frame


func test_inventory_slots_label() -> void:
	GameSession.start_new_game()
	var panel := _inventory_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	assert_true(panel._slots_label.text.begins_with("Slots:"),
		"Slots label shows 'Slots: X/Y' format")

	panel.queue_free()
	await get_tree().process_frame


func test_inventory_button_gating_no_selection() -> void:
	GameSession.start_new_game()
	var panel := _inventory_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	assert_false(panel._btn_use.visible,
		"Use button hidden when no item selected")
	assert_false(panel._btn_read.visible,
		"Read button hidden when no item selected")
	assert_false(panel._btn_equip.visible,
		"Equip button hidden when no item selected")
	assert_false(panel._btn_unequip.visible,
		"Unequip button hidden when no item selected")
	assert_true(panel._btn_drop.disabled,
		"Drop button disabled when no item selected")

	panel.queue_free()
	await get_tree().process_frame


func test_inventory_drop_disabled_for_equipped() -> void:
	GameSession.start_new_game()
	var gs := GameSession.game_state
	gs.inventory.append("Iron Sword")
	gs.equipped_items["weapon"] = "Iron Sword"

	var panel := _inventory_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	panel._item_list.select(0)
	panel._on_item_selected(0)
	await get_tree().process_frame

	assert_true(panel._btn_drop.disabled,
		"Drop button disabled for equipped item")
	assert_true(panel._btn_unequip.visible,
		"Unequip button visible for equipped item")

	panel.queue_free()
	await get_tree().process_frame
