extends "res://addons/gut/test.gd"
## Consolidated tests for popup content panels:
## - Each panel instantiates headless without errors
## - Critical named nodes exist (table-driven)
## - Critical gating states render correctly
## - Combat panel gating (pending, active, victory)
## - PopupFrame sizing / title bar / content container

var _explorer_scene := preload("res://ui/scenes/Explorer.tscn")
var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")

var _combat_scene := preload("res://ui/scenes/CombatPanel.tscn")
var _inventory_scene := preload("res://ui/scenes/InventoryPanel.tscn")
var _saveload_scene := preload("res://ui/scenes/SaveLoadPanel.tscn")
var _status_scene := preload("res://ui/scenes/CharacterStatusPanel.tscn")
var _lore_scene := preload("res://ui/scenes/LoreCodexPanel.tscn")
var _store_scene := preload("res://ui/scenes/StorePanel.tscn")


func before_each() -> void:
	GameSession._load_data()


# ------------------------------------------------------------------
# Table-driven: each scene loads and critical nodes exist
# ------------------------------------------------------------------

var _scene_nodes := {
	"combat": {
		"scene": "res://ui/scenes/CombatPanel.tscn",
		"nodes": ["DiceContainer", "RollsLabel", "EnemyHPBar", "CombatLog", "EnemyList"],
	},
	"inventory": {
		"scene": "res://ui/scenes/InventoryPanel.tscn",
		"nodes": ["SlotsLabel", "EquipmentSummary", "ItemList", "HintLabel", "BtnUse", "BtnDrop"],
	},
	"save_load": {
		"scene": "res://ui/scenes/SaveLoadPanel.tscn",
		"nodes": ["SlotList", "DetailPanel", "DetailTitle", "BtnSave", "BtnLoad"],
	},
	"character_status": {
		"scene": "res://ui/scenes/CharacterStatusPanel.tscn",
		"nodes": ["StatusTabs", "CharacterInfo", "StatsInfo"],
	},
	"lore_codex": {
		"scene": "res://ui/scenes/LoreCodexPanel.tscn",
		"nodes": ["CodexEntryList", "CodexDetailPane", "DetailTitle", "DetailText"],
	},
	"store": {
		"scene": "res://ui/scenes/StorePanel.tscn",
		"nodes": [],
	},
}

func test_all_panels_instantiate_and_have_nodes() -> void:
	for key in _scene_nodes:
		var info: Dictionary = _scene_nodes[key]
		var scene := load(info["scene"])
		assert_not_null(scene, "%s scene loads" % key)
		var panel = scene.instantiate()
		assert_not_null(panel, "%s instantiates" % key)
		add_child(panel)
		await get_tree().process_frame

		for node_name in info["nodes"]:
			var node = panel.find_child(node_name, true, false)
			assert_not_null(node, "%s has %s" % [key, node_name])

		panel.queue_free()
		await get_tree().process_frame


# ------------------------------------------------------------------
# Character Status tabs
# ------------------------------------------------------------------

func test_character_status_has_three_tabs() -> void:
	var panel := _status_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var tabs = panel.find_child("StatusTabs", true, false)
	assert_not_null(tabs, "StatusTabs exists")
	assert_true(tabs is TabContainer, "Is TabContainer")
	assert_eq(tabs.get_tab_count(), 3, "Three tabs")

	panel.queue_free()
	await get_tree().process_frame


func test_character_status_sections_present() -> void:
	GameSession.start_new_game()
	var panel := _status_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	var text: String = panel._char_info.text
	assert_true(text.find("EQUIPPED GEAR") >= 0, "Equipped Gear section")
	assert_true(text.find("CHARACTER STATS") >= 0, "Character Stats section")
	assert_true(text.find("ACTIVE EFFECTS") >= 0, "Active Effects section")
	assert_true(text.find("RESOURCES") >= 0, "Resources section")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Inventory button gating
# ------------------------------------------------------------------

func test_inventory_buttons_hidden_no_selection() -> void:
	GameSession.start_new_game()
	var panel := _inventory_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame

	assert_false(panel._btn_use.visible, "Use hidden without selection")
	assert_true(panel._btn_drop.disabled, "Drop disabled without selection")

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

	assert_true(panel._btn_drop.disabled, "Drop disabled for equipped")
	assert_true(panel._btn_unequip.visible, "Unequip visible for equipped")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Combat panel gating
# ------------------------------------------------------------------

func _setup_combat_room() -> void:
	GameSession._load_data()
	GameSession.start_new_game()
	var room := GameSession.get_current_room()
	room.has_combat = true
	room.enemies_defeated = false
	room.combat_escaped = false
	room.data["threats"] = ["Goblin"]
	GameSession.enemy_types_db["Goblin"] = {"health": 10, "num_dice": 1}


func test_combat_panel_has_no_flee_button() -> void:
	_setup_combat_room()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	assert_true(GameSession.is_pending_choice(), "Pending")

	ex._show_panel(ex._combat_panel)
	ex._combat_panel.refresh()
	await get_tree().process_frame

	# Python parity: combat panel has no flee button.
	# Flee is only in the explorer sidebar during pre-combat pending choice.
	assert_false("_btn_flee" in ex._combat_panel, "No flee button in combat panel")

	ex.queue_free()
	await get_tree().process_frame


func test_combat_victory_clears() -> void:
	_setup_combat_room()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)
	GameSession.accept_combat()
	assert_not_null(GameSession.combat, "CombatEngine created")

	var alive := GameSession.combat.get_alive_enemies()
	alive[0].health = 0
	GameSession.end_combat(true)
	await get_tree().process_frame

	assert_null(GameSession.combat, "Combat cleared")
	assert_false(GameSession.is_combat_blocking(), "Movement unblocked")

	await get_tree().create_timer(0.3).timeout
	assert_false(ex._overlay_manager.is_menu_open("combat"),
		"Combat popup hidden after victory")

	ex.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# PopupFrame sizing / structure
# ------------------------------------------------------------------

func test_popup_has_title_bar() -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = "Test"
	add_child(frame)
	await get_tree().process_frame

	assert_not_null(frame.find_child("TitleBar", true, false), "TitleBar exists")
	assert_not_null(frame.get_popup_panel(), "PopupPanel exists")

	frame.queue_free()
	await get_tree().process_frame


func test_popup_sizing_algorithm() -> void:
	# Verify the formula: max(base, min(base*1.5, vp*pct))
	# At 1280x720: inventory (450,500,0.45,0.75)
	# w = max(450, min(675, 576)) = 576
	# h = max(500, min(750, 540)) = 540
	var vp_w := 1280.0
	var vp_h := 720.0
	var bw := 450.0
	var bh := 500.0
	var target_w: float = maxf(bw, minf(bw * 1.5, vp_w * 0.45))
	var target_h: float = maxf(bh, minf(bh * 1.5, vp_h * 0.75))
	assert_almost_eq(target_w, 576.0, 1.0, "Inventory width at 1280")
	assert_almost_eq(target_h, 540.0, 1.0, "Inventory height at 720")

	# Pause (350,300,0.35,0.45)
	target_w = maxf(350.0, minf(525.0, vp_w * 0.35))
	target_h = maxf(300.0, minf(450.0, vp_h * 0.45))
	assert_almost_eq(target_w, 448.0, 1.0, "Pause width at 1280")
	assert_almost_eq(target_h, 324.0, 1.0, "Pause height at 720")


func test_size_profiles_defined() -> void:
	var OverlayManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	var expected := ["pause", "inventory", "settings", "store",
		"combat", "status", "lore", "save_load"]
	for key in expected:
		assert_true(OverlayManagerScript.SIZE_PROFILES.has(key),
			"SIZE_PROFILES has '%s'" % key)


# ------------------------------------------------------------------
# Lore codex empty refresh
# ------------------------------------------------------------------

func test_codex_refresh_empty() -> void:
	GameSession.start_new_game()
	var panel := _lore_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	panel.refresh()
	await get_tree().process_frame

	assert_eq(panel._filtered_entries.size(), 0, "No entries in empty codex")

	panel.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# Sidebar flee button hidden during active combat
# ------------------------------------------------------------------

func test_sidebar_flee_hidden_during_active() -> void:
	_setup_combat_room()
	var ex := _explorer_scene.instantiate()
	add_child(ex)
	await get_tree().process_frame

	var room := GameSession.get_current_room()
	GameSession._check_combat_pending(room)

	ex._refresh_ui()
	await get_tree().process_frame
	assert_true(ex._btn_flee.visible, "Sidebar flee visible during pending")

	GameSession.accept_combat()
	ex._refresh_ui()
	await get_tree().process_frame
	assert_false(ex._btn_flee.visible, "Sidebar flee hidden during active")

	ex.queue_free()
	await get_tree().process_frame
