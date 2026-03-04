extends Control
## Explorer Scene — core gameplay screen (polished UI).
## Layout: TopBar | Center (room+combat) | Right Sidebar (minimap+actions) | Bottom (log).
## Hosts embedded overlay panels via MenuOverlayManager for Combat, Inventory,
## Store, SaveLoad, CharacterStatus, LoreCodex, Settings, Pause.

# --- Info widgets ---
var _floor_label: Label
var _room_pos_label: Label
var _seed_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _gold_label: Label
var _rooms_explored_label: Label
var _room_name_label: Label
var _room_desc_label: RichTextLabel
var _room_flags_label: Label

# --- Adventure log ---
var _log_text: RichTextLabel
var _typewriter_queue: Array = []
var _typewriter_active: bool = false
var _log_scroll_sticky: bool = true
var _log_unread_count: int = 0
var _log_new_msg_btn: Button

# --- Movement buttons ---
var _btn_north: Button
var _btn_south: Button
var _btn_east: Button
var _btn_west: Button

# --- Action buttons ---
var _btn_attack: Button
var _btn_flee: Button
var _btn_chest: Button
var _btn_ground: Button
var _btn_inventory: Button
var _btn_store: Button
var _btn_rest: Button
var _btn_descend: Button
var _btn_settings: Button
var _btn_character: Button
var _btn_pause: Button

# --- Overlay panels (kept as refs for refresh/gating) ---
var _combat_panel: Control
var _inventory_panel: Control
var _store_panel: Control
var _save_load_panel: Control
var _character_status_panel: Control
var _settings_panel: Control
var _lore_codex_panel: Control
var _pause_menu: Control

# --- Overlay manager ---
var _overlay_manager  # MenuOverlayManager

# --- Debug overlay ---
var _debug_panel: PanelContainer
var _debug_label: RichTextLabel
var _debug_visible: bool = false

var _minimap_panel: PanelContainer
var _context: GameContext

var _combat_scene := preload("res://ui/scenes/CombatPanel.tscn")
var _inventory_scene := preload("res://ui/scenes/InventoryPanel.tscn")
var _store_scene := preload("res://ui/scenes/StorePanel.tscn")
var _save_load_scene := preload("res://ui/scenes/SaveLoadPanel.tscn")
var _minimap_scene := preload("res://ui/scenes/MinimapPanel.tscn")
var _character_status_scene := preload("res://ui/scenes/CharacterStatusPanel.tscn")
var _settings_scene := preload("res://ui/scenes/SettingsPanel.tscn")
var _lore_codex_scene := preload("res://ui/scenes/LoreCodexPanel.tscn")
var _pause_menu_scene := preload("res://ui/scenes/PauseMenu.tscn")


func _ready() -> void:
	_context = GameContext.new()
	_build_ui()
	_build_debug_overlay()
	_setup_overlay_manager()
	_context.set_menus(_overlay_manager)
	if _context.session:
		_context.session.quit_requested.connect(_on_quit_requested)
	_connect_signals()
	_connect_log_bridge()
	_consume_pending_run_state()
	_refresh_ui()


func _process(_delta: float) -> void:
	_check_log_scroll()


func _consume_pending_run_state() -> void:
	if GameSession.has_pending_run_state():
		var run_state := GameSession.consume_pending_run_state()
		if run_state.get("source") == "save":
			_append_log("Loaded save from slot %d." % int(run_state.get("slot_id", 0)))


# ==================================================================
# UI CONSTRUCTION
# ==================================================================

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = DungeonTheme.BG_PRIMARY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	_build_top_bar(root_vbox)

	var middle_hbox := HBoxContainer.new()
	middle_hbox.name = "MiddleHBox"
	middle_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_hbox.size_flags_stretch_ratio = 1.0
	middle_hbox.add_theme_constant_override("separation", 0)
	root_vbox.add_child(middle_hbox)

	_build_center_panel(middle_hbox)
	_build_right_sidebar(middle_hbox)

	_build_adventure_log(root_vbox)


func _build_top_bar(parent: Node) -> void:
	var outer := VBoxContainer.new()
	outer.name = "TopBarOuter"
	outer.add_theme_constant_override("separation", 0)
	parent.add_child(outer)

	# --- Row 1: Title + icon buttons ---
	var row1 := PanelContainer.new()
	row1.name = "TopBar"
	var r1_style := StyleBoxFlat.new()
	r1_style.bg_color = DungeonTheme.BG_HEADER
	r1_style.border_color = DungeonTheme.BORDER_GOLD
	r1_style.set_border_width_all(0)
	r1_style.border_width_bottom = 1
	r1_style.set_content_margin_all(6)
	r1_style.content_margin_left = 10
	r1_style.content_margin_right = 10
	row1.add_theme_stylebox_override("panel", r1_style)
	outer.add_child(row1)

	var hbox1 := HBoxContainer.new()
	hbox1.add_theme_constant_override("separation", 12)
	row1.add_child(hbox1)

	var title := Label.new()
	title.text = "⚔ DICE DUNGEON ⚔"
	title.add_theme_font_size_override("font_size", DungeonTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	hbox1.add_child(title)

	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox1.add_child(spacer1)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	hbox1.add_child(btn_box)

	_btn_pause = _make_icon_btn("☰", "Menu")
	_btn_pause.pressed.connect(_on_pause)
	btn_box.add_child(_btn_pause)

	_btn_settings = _make_icon_btn("⚙", "Settings")
	_btn_settings.pressed.connect(_on_settings)
	btn_box.add_child(_btn_settings)

	_btn_character = _make_icon_btn("?", "Character")
	_btn_character.pressed.connect(_on_character_status)
	btn_box.add_child(_btn_character)

	# --- Row 2: Stats bar (HP/Gold left, floor info right) ---
	var row2 := PanelContainer.new()
	row2.name = "StatsBar"
	var r2_style := StyleBoxFlat.new()
	r2_style.bg_color = DungeonTheme.BG_PANEL
	r2_style.border_color = DungeonTheme.BORDER
	r2_style.set_border_width_all(0)
	r2_style.border_width_bottom = 1
	r2_style.border_width_top = 1
	r2_style.set_content_margin_all(5)
	r2_style.content_margin_left = 10
	r2_style.content_margin_right = 10
	row2.add_theme_stylebox_override("panel", r2_style)
	outer.add_child(row2)

	var hbox2 := HBoxContainer.new()
	hbox2.add_theme_constant_override("separation", 16)
	row2.add_child(hbox2)

	# Left side: HP + Gold
	var hp_box := HBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 6)
	hbox2.add_child(hp_box)

	var hp_icon := Label.new()
	hp_icon.text = "♥ HEALTH"
	hp_icon.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	hp_icon.add_theme_color_override("font_color", DungeonTheme.TEXT_RED)
	hp_box.add_child(hp_icon)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(120, 16)
	_hp_bar.max_value = 50
	_hp_bar.value = 50
	_hp_bar.show_percentage = false
	DungeonTheme.style_hp_bar(_hp_bar, 1.0)
	hp_box.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.text = "50/50"
	_hp_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_hp_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	hp_box.add_child(_hp_label)

	var gold_box := HBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 4)
	hbox2.add_child(gold_box)

	var gold_icon := Label.new()
	gold_icon.text = "◆ Gold:"
	gold_icon.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	gold_icon.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	gold_box.add_child(gold_icon)

	_gold_label = Label.new()
	_gold_label.text = "0"
	_gold_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_gold_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	gold_box.add_child(_gold_label)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox2.add_child(spacer2)

	# Right side: Floor info + rooms explored
	_floor_label = Label.new()
	_floor_label.text = "▼ THE THRESHOLD"
	_floor_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_floor_label.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
	hbox2.add_child(_floor_label)

	_rooms_explored_label = Label.new()
	_rooms_explored_label.text = "Rooms Explored: 0 | Rest Ready!"
	_rooms_explored_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_rooms_explored_label.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	hbox2.add_child(_rooms_explored_label)

	# Hidden labels kept for compatibility
	_room_pos_label = Label.new()
	_room_pos_label.visible = false
	hbox2.add_child(_room_pos_label)

	_seed_label = Label.new()
	_seed_label.name = "SeedLabel"
	_seed_label.visible = false
	hbox2.add_child(_seed_label)


func _build_center_panel(parent: Node) -> void:
	var center := VBoxContainer.new()
	center.name = "CenterPanel"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 3.0
	center.add_theme_constant_override("separation", 0)
	parent.add_child(center)

	var room_panel := PanelContainer.new()
	room_panel.name = "RoomPanel"
	var room_style := StyleBoxFlat.new()
	room_style.bg_color = Color(0.16, 0.09, 0.06)
	room_style.border_color = DungeonTheme.BORDER_GOLD
	room_style.set_border_width_all(2)
	room_style.set_content_margin_all(6)
	room_style.content_margin_left = 16
	room_style.content_margin_right = 16
	room_panel.add_theme_stylebox_override("panel", room_style)
	center.add_child(room_panel)

	var room_vbox := VBoxContainer.new()
	room_vbox.add_theme_constant_override("separation", 4)
	room_panel.add_child(room_vbox)

	_room_name_label = Label.new()
	_room_name_label.name = "RoomNameLabel"
	_room_name_label.text = "---"
	_room_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_name_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	_room_name_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	room_vbox.add_child(_room_name_label)

	var room_sep := DungeonTheme.make_separator(DungeonTheme.BORDER_GOLD)
	room_vbox.add_child(room_sep)

	_room_desc_label = RichTextLabel.new()
	_room_desc_label.name = "RoomDescLabel"
	_room_desc_label.text = ""
	_room_desc_label.bbcode_enabled = true
	_room_desc_label.fit_content = true
	_room_desc_label.scroll_active = false
	_room_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_desc_label.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_room_desc_label.add_theme_font_size_override("italics_font_size", DungeonTheme.FONT_BODY)
	_room_desc_label.add_theme_color_override("default_color", Color(0.96, 0.90, 0.83))
	room_vbox.add_child(_room_desc_label)

	_room_flags_label = Label.new()
	_room_flags_label.name = "RoomFlagsLabel"
	_room_flags_label.text = ""
	_room_flags_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_room_flags_label.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	room_vbox.add_child(_room_flags_label)

	var action_spacer := Control.new()
	action_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(action_spacer)


func _build_right_sidebar(parent: Node) -> void:
	var sidebar := PanelContainer.new()
	sidebar.name = "RightSidebar"
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = DungeonTheme.BG_PANEL
	sb_style.border_color = DungeonTheme.BORDER
	sb_style.border_width_left = 2
	sb_style.set_content_margin_all(8)
	sidebar.add_theme_stylebox_override("panel", sb_style)
	sidebar.custom_minimum_size = Vector2(220, 0)
	parent.add_child(sidebar)

	var sidebar_vbox := VBoxContainer.new()
	sidebar_vbox.add_theme_constant_override("separation", 8)
	sidebar.add_child(sidebar_vbox)

	_minimap_panel = _minimap_scene.instantiate()
	_minimap_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_vbox.add_child(_minimap_panel)

	var move_header := Label.new()
	move_header.text = "MOVE"
	move_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_header.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	move_header.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	sidebar_vbox.add_child(move_header)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sidebar_vbox.add_child(grid)

	grid.add_child(_spacer())
	_btn_north = _make_move_btn("↑")
	grid.add_child(_btn_north)
	grid.add_child(_spacer())

	_btn_west = _make_move_btn("←")
	grid.add_child(_btn_west)
	grid.add_child(_spacer())
	_btn_east = _make_move_btn("→")
	grid.add_child(_btn_east)

	grid.add_child(_spacer())
	_btn_south = _make_move_btn("↓")
	grid.add_child(_btn_south)
	grid.add_child(_spacer())

	var wasd_hint := Label.new()
	wasd_hint.text = "(or WASD/Arrows)"
	wasd_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wasd_hint.add_theme_font_size_override("font_size", 10)
	wasd_hint.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	sidebar_vbox.add_child(wasd_hint)

	var action_sep := DungeonTheme.make_separator(DungeonTheme.BORDER)
	sidebar_vbox.add_child(action_sep)

	var action_header := Label.new()
	action_header.text = "ACTIONS"
	action_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_header.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	action_header.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	sidebar_vbox.add_child(action_header)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 3)
	sidebar_vbox.add_child(actions)

	_btn_attack = _make_action_btn("⚔ Attack", DungeonTheme.BTN_PRIMARY)
	actions.add_child(_btn_attack)
	_btn_flee = _make_action_btn("🏃 Flee", DungeonTheme.TEXT_RED)
	actions.add_child(_btn_flee)
	_btn_chest = _make_action_btn("📦 Open Chest", DungeonTheme.TEXT_GOLD)
	actions.add_child(_btn_chest)
	_btn_ground = _make_action_btn("🔍 Ground Items", DungeonTheme.TEXT_SECONDARY)
	actions.add_child(_btn_ground)
	_btn_inventory = _make_action_btn("🎒 Inventory", DungeonTheme.BTN_SECONDARY)
	actions.add_child(_btn_inventory)
	_btn_store = _make_action_btn("🏪 Store", DungeonTheme.BTN_SECONDARY)
	actions.add_child(_btn_store)
	_btn_rest = _make_action_btn("💤 Rest", DungeonTheme.TEXT_GREEN)
	actions.add_child(_btn_rest)
	_btn_descend = _make_action_btn("⬇ Descend", DungeonTheme.TEXT_CYAN)
	actions.add_child(_btn_descend)


func _build_adventure_log(parent: Node) -> void:
	var log_panel := PanelContainer.new()
	log_panel.name = "LogPanel"
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_stretch_ratio = 0.85
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.10, 0.07, 0.05)
	log_style.border_color = DungeonTheme.BORDER_GOLD
	log_style.border_width_top = 2
	log_style.set_content_margin_all(10)
	log_style.content_margin_left = 12
	log_style.content_margin_right = 12
	log_style.content_margin_bottom = 8
	log_panel.add_theme_stylebox_override("panel", log_style)
	log_panel.custom_minimum_size = Vector2(0, 140)
	parent.add_child(log_panel)

	var log_vbox := VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 4)
	log_panel.add_child(log_vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	log_vbox.add_child(header_hbox)

	var log_header := Label.new()
	log_header.text = "ADVENTURE LOG"
	log_header.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	log_header.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	header_hbox.add_child(log_header)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)

	var copy_btn := Button.new()
	copy_btn.text = "Copy Log"
	copy_btn.custom_minimum_size = Vector2(70, 20)
	copy_btn.add_theme_font_size_override("font_size", 10)
	var copy_style := StyleBoxFlat.new()
	copy_style.bg_color = DungeonTheme.BG_PANEL
	copy_style.set_corner_radius_all(3)
	copy_style.set_content_margin_all(2)
	copy_btn.add_theme_stylebox_override("normal", copy_style)
	copy_btn.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	var copy_hover := StyleBoxFlat.new()
	copy_hover.bg_color = DungeonTheme.BG_PANEL.lightened(0.15)
	copy_hover.set_corner_radius_all(3)
	copy_hover.set_content_margin_all(2)
	copy_btn.add_theme_stylebox_override("hover", copy_hover)
	copy_btn.pressed.connect(_on_copy_log)
	header_hbox.add_child(copy_btn)

	_log_text = RichTextLabel.new()
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.scroll_active = true
	_log_text.selection_enabled = true
	_log_text.fit_content = false
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.add_theme_font_size_override("normal_font_size", 14)
	_log_text.add_theme_color_override("default_color", Color(0.93, 0.89, 0.80))
	_log_text.add_theme_constant_override("line_separation", 3)
	log_vbox.add_child(_log_text)

	_log_new_msg_btn = Button.new()
	_log_new_msg_btn.text = "New messages"
	_log_new_msg_btn.visible = false
	_log_new_msg_btn.custom_minimum_size = Vector2(120, 22)
	_log_new_msg_btn.add_theme_font_size_override("font_size", 10)
	var nmb_style := StyleBoxFlat.new()
	nmb_style.bg_color = DungeonTheme.TEXT_GOLD.darkened(0.5)
	nmb_style.set_corner_radius_all(3)
	nmb_style.set_content_margin_all(2)
	_log_new_msg_btn.add_theme_stylebox_override("normal", nmb_style)
	_log_new_msg_btn.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	_log_new_msg_btn.pressed.connect(_on_new_messages_clicked)
	log_vbox.add_child(_log_new_msg_btn)


# ==================================================================
# DEBUG OVERLAY
# ==================================================================

func _build_debug_overlay() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugOverlay"
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	_debug_panel.add_theme_stylebox_override("panel", style)
	_debug_panel.anchor_left = 0.0
	_debug_panel.anchor_top = 0.5
	_debug_panel.anchor_right = 0.5
	_debug_panel.anchor_bottom = 1.0
	_debug_panel.visible = false
	add_child(_debug_panel)

	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = true
	_debug_label.scroll_active = true
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.add_child(_debug_label)


# ==================================================================
# OVERLAY MANAGER SETUP
# ==================================================================

func _setup_overlay_manager() -> void:
	var ManagerScript := preload("res://ui/scripts/menu_overlay_manager.gd")
	_overlay_manager = ManagerScript.new()
	_overlay_manager.name = "MenuOverlayManager"
	add_child(_overlay_manager)

	# Instantiate content panels
	_combat_panel = _combat_scene.instantiate()
	_inventory_panel = _inventory_scene.instantiate()
	_store_panel = _store_scene.instantiate()
	_save_load_panel = _save_load_scene.instantiate()
	_character_status_panel = _character_status_scene.instantiate()
	_settings_panel = _settings_scene.instantiate()
	_lore_codex_panel = _lore_codex_scene.instantiate()
	_pause_menu = _pause_menu_scene.instantiate()

	# Register menus — size profiles defined in MenuOverlayManager.SIZE_PROFILES
	_overlay_manager.register_menu("combat", "⚔ COMBAT ⚔", _combat_panel,
		"combat", func() -> bool: return not _is_combat_locking())
	_overlay_manager.register_menu("inventory", "🎒 INVENTORY", _inventory_panel, "inventory")
	_overlay_manager.register_menu("store", "🏪 STORE", _store_panel, "store")
	_overlay_manager.register_menu("save_load", "💾 SAVE / LOAD", _save_load_panel, "save_load")
	_overlay_manager.register_menu("character_status", "⚙ CHARACTER STATUS", _character_status_panel, "status")
	_overlay_manager.register_menu("settings", "⚙ SETTINGS", _settings_panel, "settings")
	_overlay_manager.register_menu("lore_codex", "📜 LORE CODEX", _lore_codex_panel, "lore")
	_overlay_manager.register_menu("pause", "☰ PAUSED", _pause_menu, "pause")

	# Wire pause menu signals
	_pause_menu.close_requested.connect(func(): _overlay_manager.close_menu("pause"))
	_pause_menu.open_settings_requested.connect(func():
		_overlay_manager.close_menu("pause")
		_overlay_manager.open_menu("settings")
	)
	_pause_menu.open_save_load_requested.connect(func():
		_overlay_manager.close_menu("pause")
		_overlay_manager.open_menu("save_load")
	)
	_pause_menu.quit_to_menu_requested.connect(_quit_to_main_menu)


# ==================================================================
# SIGNAL WIRING
# ==================================================================

func _connect_signals() -> void:
	_btn_north.pressed.connect(_move.bind("N"))
	_btn_south.pressed.connect(_move.bind("S"))
	_btn_east.pressed.connect(_move.bind("E"))
	_btn_west.pressed.connect(_move.bind("W"))

	_btn_attack.pressed.connect(_on_attack)
	_btn_flee.pressed.connect(_on_flee)
	_btn_chest.pressed.connect(_on_chest)
	_btn_ground.pressed.connect(_on_ground_items)
	_btn_inventory.pressed.connect(_on_inventory)
	_btn_store.pressed.connect(_on_store)
	_btn_rest.pressed.connect(_on_rest)
	_btn_descend.pressed.connect(_on_descend)

	GameSession.state_changed.connect(_refresh_ui)
	GameSession.log_message.connect(_append_log)
	GameSession.combat_started.connect(_on_combat_started)
	GameSession.combat_ended.connect(_on_combat_ended)
	GameSession.combat_pending_changed.connect(_refresh_ui)

	# Panel close_requested signals → close via overlay manager
	if _combat_panel.has_signal("close_requested"):
		_combat_panel.close_requested.connect(_on_combat_close_requested)
	if _inventory_panel.has_signal("close_requested"):
		_inventory_panel.close_requested.connect(func(): _overlay_manager.close_menu("inventory"))
	if _store_panel.has_signal("close_requested"):
		_store_panel.close_requested.connect(func(): _overlay_manager.close_menu("store"))
	if _save_load_panel.has_signal("close_requested"):
		_save_load_panel.close_requested.connect(func(): _overlay_manager.close_menu("save_load"))
	if _character_status_panel.has_signal("close_requested"):
		_character_status_panel.close_requested.connect(func(): _overlay_manager.close_menu("character_status"))
	if _settings_panel.has_signal("close_requested"):
		_settings_panel.close_requested.connect(func(): _overlay_manager.close_menu("settings"))
	if _lore_codex_panel.has_signal("close_requested"):
		_lore_codex_panel.close_requested.connect(func(): _overlay_manager.close_menu("lore_codex"))


# ==================================================================
# COMBAT LIFECYCLE
# ==================================================================

func _on_combat_close_requested() -> void:
	if _is_combat_locking():
		return
	_overlay_manager.close_menu("combat")


func _on_combat_started() -> void:
	_overlay_manager.open_menu("combat")


func _on_combat_ended() -> void:
	_overlay_manager.close_menu("combat")
	_refresh_ui()


func _is_combat_locking() -> bool:
	return GameSession.is_pending_choice() or GameSession.is_combat_active()


# ==================================================================
# INPUT
# ==================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# ESC / ui_cancel: close topmost popup, or toggle pause menu
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu"):
		if _overlay_manager.is_any_open():
			_overlay_manager.close_top_menu()
		else:
			_on_pause()
		get_viewport().set_input_as_handled()
		return

	# Block game inputs when any popup is open
	if _any_panel_open():
		return

	if event.is_action_pressed("move_north"):
		_move("N")
	elif event.is_action_pressed("move_south"):
		_move("S")
	elif event.is_action_pressed("move_west"):
		_move("W")
	elif event.is_action_pressed("move_east"):
		_move("E")
	elif event.is_action_pressed("character_status"):
		_on_character_status()
	elif event.is_action_pressed("open_inventory"):
		_on_inventory()
	elif event.is_action_pressed("rest"):
		_on_rest()
	elif event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		_debug_panel.visible = _debug_visible
		if _debug_visible:
			_refresh_debug()
	elif event.keycode == KEY_F4:
		_export_session_trace()


# -------------------------------------------------------------------
# Menu open actions
# -------------------------------------------------------------------

func _on_settings() -> void:
	_overlay_manager.open_menu("settings")

func _on_pause() -> void:
	_overlay_manager.open_menu("pause")

func _on_inventory() -> void:
	_overlay_manager.open_menu("inventory")

func _on_store() -> void:
	var room := GameSession.get_current_room()
	if room == null or not room.has_store:
		_append_log("No store here.")
		return
	_overlay_manager.open_menu("store")

func _on_character_status() -> void:
	_overlay_manager.open_menu("character_status")

func _on_save_load() -> void:
	_overlay_manager.open_menu("save_load")


# -------------------------------------------------------------------
# Panel query helpers
# -------------------------------------------------------------------

func _any_panel_open() -> bool:
	return _overlay_manager.is_any_open()


func _close_topmost_panel() -> bool:
	return _overlay_manager.close_top_menu()


func _close_all_panels() -> void:
	_overlay_manager.close_all_menus()
	# Re-show combat if it was locking
	if _is_combat_locking() and _combat_panel != null:
		_overlay_manager.open_menu("combat")


func _show_panel(panel: Control) -> void:
	# Legacy helper for tests that call _show_panel/_hide_panel directly
	if panel == _combat_panel:
		_overlay_manager.open_menu("combat")
	elif panel == _inventory_panel:
		_overlay_manager.open_menu("inventory")
	elif panel == _store_panel:
		_overlay_manager.open_menu("store")
	elif panel == _save_load_panel:
		_overlay_manager.open_menu("save_load")
	elif panel == _character_status_panel:
		_overlay_manager.open_menu("character_status")
	elif panel == _settings_panel:
		_overlay_manager.open_menu("settings")
	elif panel == _lore_codex_panel:
		_overlay_manager.open_menu("lore_codex")
	elif panel == _pause_menu:
		_overlay_manager.open_menu("pause")


func _hide_panel(panel: Control) -> void:
	if panel == _combat_panel:
		_overlay_manager.close_menu("combat")
	elif panel == _inventory_panel:
		_overlay_manager.close_menu("inventory")
	elif panel == _store_panel:
		_overlay_manager.close_menu("store")
	elif panel == _save_load_panel:
		_overlay_manager.close_menu("save_load")
	elif panel == _character_status_panel:
		_overlay_manager.close_menu("character_status")
	elif panel == _settings_panel:
		_overlay_manager.close_menu("settings")
	elif panel == _lore_codex_panel:
		_overlay_manager.close_menu("lore_codex")
	elif panel == _pause_menu:
		_overlay_manager.close_menu("pause")


# -------------------------------------------------------------------
# Quit to Main Menu
# -------------------------------------------------------------------

func _quit_to_main_menu() -> void:
	_overlay_manager.close_all_menus()
	if _context and _context.session:
		_context.session.quit_to_main_menu()
	else:
		GameSession.combat = null
		GameSession.combat_pending = false
	get_tree().change_scene_to_file("res://ui/scenes/MainMenu.tscn")


func _on_quit_requested() -> void:
	_overlay_manager.close_all_menus()
	get_tree().change_scene_to_file("res://ui/scenes/MainMenu.tscn")


func _connect_log_bridge() -> void:
	if _context and _context.log:
		GameSession.log_message.connect(func(msg: String):
			var meta := _classify_message(msg)
			_context.log.append(msg, meta[0], meta[1], meta[2])
		)
		GameSession.trace.set_adventure_log(_context.log)


static func _classify_message(msg: String) -> Array:
	# Returns [tag, category, source]
	if msg.begins_with("===") or msg.begins_with("=="):
		return ["system", "ROOM", "exploration"]
	if msg.begins_with("Entered:") or msg.begins_with("Returned to:"):
		return ["system", "ROOM", "exploration"]
	if msg.begins_with("Enemy:") or msg.begins_with("Enemy lurks"):
		return ["enemy", "COMBAT", "exploration"]
	if msg.begins_with("Combat begins"):
		return ["enemy", "COMBAT", "combat"]
	if msg.begins_with("Enemies ahead") or msg.begins_with("Something lurks"):
		return ["enemy", "COMBAT", "exploration"]
	if msg.begins_with("Fled"):
		return ["system", "COMBAT", "combat"]
	if msg.begins_with("Found stairs"):
		return ["success", "DISCOVERY", "exploration"]
	if msg.begins_with("Discovered"):
		return ["success", "DISCOVERY", "exploration"]
	if msg.begins_with("Browsing store"):
		return ["system", "STORE", "store"]
	if msg.begins_with("Rested") or msg.begins_with("Already at full"):
		return ["success", "INTERACTION", "system"]
	if msg.contains("gold") and (msg.begins_with("Picked up") or msg.begins_with("+") or msg.begins_with("Collected")):
		return ["loot", "LOOT", "exploration"]
	if msg.begins_with("Picked up") or msg.begins_with("Searched"):
		return ["loot", "LOOT", "exploration"]
	if msg.begins_with("[CHEST]") or msg.begins_with("Opened chest"):
		return ["loot", "LOOT", "exploration"]
	if msg.begins_with("Mini-boss defeated") or msg.begins_with("Boss defeated"):
		return ["success", "COMBAT", "combat"]
	if msg.begins_with("Container is locked"):
		return ["system", "INTERACTION", "exploration"]
	if msg.begins_with("Inventory full"):
		return ["system", "SYSTEM", "system"]
	if msg.begins_with("[Session Trace]"):
		return ["system", "SYSTEM", "system"]
	if msg.begins_with("Cannot") or msg.begins_with("No ") or msg.begins_with("Failed"):
		return ["system", "SYSTEM", "system"]
	if msg.begins_with("Loaded save"):
		return ["system", "SYSTEM", "system"]
	# Flavor text and peaceful messages
	for peaceful in ExplorationEngine.PEACEFUL_MESSAGES:
		if msg == peaceful:
			return ["system", "ROOM", "exploration"]
	return ["system", "SYSTEM", "system"]


# -------------------------------------------------------------------
# Game actions
# -------------------------------------------------------------------

func _move(direction: String) -> void:
	if _any_panel_open():
		return
	if GameSession.is_combat_blocking():
		_append_log("Enemies block your path! Fight or flee first.")
		return
	var room := GameSession.move_direction(direction)
	if room == null:
		_append_log("Cannot move %s." % direction)
	_refresh_ui()


func _on_attack() -> void:
	if GameSession.is_pending_choice():
		GameSession.accept_combat()
		return

	var room := GameSession.get_current_room()
	if room == null:
		return
	if room.has_combat and not room.enemies_defeated:
		if GameSession.combat == null:
			GameSession.start_combat_for_room(room)
		_overlay_manager.open_menu("combat")


func _on_flee() -> void:
	if GameSession.is_pending_choice():
		GameSession.attempt_flee_pending()
		return


func _on_chest() -> void:
	var result := GameSession.open_chest()
	if result.is_empty():
		_append_log("No chest to open.")


func _on_ground_items() -> void:
	var room := GameSession.get_current_room()
	if room == null:
		return
	var items := GameSession.exploration.inspect_ground_items(room)
	if items.is_empty():
		_append_log("Nothing on the ground.")
		return
	for item in items:
		if item.get("type") == "gold":
			GameSession.pickup_ground_gold()
		elif item.get("type") == "item":
			GameSession.pickup_ground_item(0)
		elif item.get("type") == "container":
			var result := GameSession.exploration.search_container(room)
			GameSession._emit_logs(GameSession.exploration.logs)
			if result.get("locked", false):
				_append_log("Container is locked!")
			elif not result.is_empty():
				var g: int = int(result.get("gold", 0))
				if g > 0:
					GameSession.game_state.gold += g
				var it: String = str(result.get("item", ""))
				if not it.is_empty():
					GameSession.inventory_engine.add_item_to_inventory(it, "ground")
	GameSession.state_changed.emit()


func _on_rest() -> void:
	GameSession.attempt_rest()


func _on_descend() -> void:
	var result := GameSession.descend_stairs()
	if result == null:
		_append_log("Cannot descend. Defeat the boss first or find stairs.")


# -------------------------------------------------------------------
# UI refresh
# -------------------------------------------------------------------

func _refresh_ui() -> void:
	var gs := GameSession.game_state
	var room := GameSession.get_current_room()
	var fs := GameSession.get_floor_state()

	if gs == null:
		return

	var pos := fs.current_pos if fs != null else Vector2i.ZERO
	_floor_label.text = "▼ Floor %d" % gs.floor
	_room_pos_label.text = "(%d, %d)" % [pos.x, pos.y]
	_hp_label.text = "%d/%d" % [gs.health, gs.max_health]
	_gold_label.text = "%d" % gs.gold

	var rooms_explored: int = fs.rooms_explored if fs != null else 0
	_rooms_explored_label.text = "Rooms Explored: %d | Seed: %d" % [rooms_explored, GameSession.run_seed]

	if GameSession.run_rng_mode == "deterministic":
		_seed_label.text = "Seed: %d (Deterministic)" % GameSession.run_seed
	else:
		_seed_label.text = "Seed: %d" % GameSession.run_seed

	_hp_bar.max_value = gs.max_health
	_hp_bar.value = gs.health
	var hp_ratio: float = float(gs.health) / float(gs.max_health) if gs.max_health > 0 else 0.0
	DungeonTheme.style_hp_bar(_hp_bar, hp_ratio)

	if room != null:
		_room_name_label.text = room.data.get("name", "Unknown Room")
		var desc: String = room.data.get("flavor", "")
		if desc.is_empty():
			desc = room.data.get("description", "")
		_room_desc_label.clear()
		_room_desc_label.append_text("[i]%s[/i]" % desc if not desc.is_empty() else "")
		var flags: PackedStringArray = []
		if room.has_combat and not room.enemies_defeated and not room.combat_escaped:
			flags.append("⚔ COMBAT")
		if room.has_chest and not room.chest_looted:
			flags.append("📦 CHEST")
		if room.ground_items.size() > 0 or room.ground_gold > 0:
			flags.append("🔍 GROUND ITEMS")
		if room.has_store:
			flags.append("🏪 STORE")
		if room.has_stairs:
			flags.append("⬇ STAIRS")
		if room.is_mini_boss_room:
			flags.append("⚠ MINI-BOSS")
		if room.is_boss_room:
			flags.append("☠ BOSS")
		_room_flags_label.text = "  ".join(flags) if not flags.is_empty() else ""
	else:
		_room_name_label.text = "---"
		_room_desc_label.clear()
		_room_flags_label.text = ""

	_update_button_visibility(room)

	# Update combat popup closable state dynamically
	var combat_frame = _overlay_manager.get_frame("combat")
	if combat_frame != null:
		combat_frame.closable = not _is_combat_locking()

	if _debug_visible:
		_refresh_debug()


func _update_button_visibility(room: RoomState) -> void:
	var blocking := GameSession.is_combat_blocking()
	var pending := GameSession.is_pending_choice()
	var active := GameSession.is_combat_active()
	var show_combat_buttons := pending or (room != null and room.has_combat and not room.enemies_defeated and not room.combat_escaped and active)

	_btn_north.disabled = blocking
	_btn_south.disabled = blocking
	_btn_east.disabled = blocking
	_btn_west.disabled = blocking
	_update_move_btn_style(_btn_north)
	_update_move_btn_style(_btn_south)
	_update_move_btn_style(_btn_east)
	_update_move_btn_style(_btn_west)

	_btn_attack.visible = show_combat_buttons
	_btn_flee.visible = pending and not active
	_btn_chest.visible = room != null and room.has_chest and not room.chest_looted and not blocking
	_btn_ground.visible = room != null and (room.ground_items.size() > 0 or room.ground_gold > 0 or (not room.ground_container.is_empty() and not room.container_searched)) and not blocking
	_btn_store.visible = room != null and room.has_store and not blocking
	_btn_descend.visible = room != null and room.has_stairs and not blocking


# -------------------------------------------------------------------
# Debug overlay (F3 toggle)
# -------------------------------------------------------------------

func _refresh_debug() -> void:
	var room := GameSession.get_current_room()
	var fs := GameSession.get_floor_state()
	var gs := GameSession.game_state
	if room == null or fs == null or gs == null:
		_debug_label.text = "[DEBUG] No room data"
		return

	var pos := fs.current_pos
	var threats: Array = room.data.get("threats", [])
	var tags: Array = room.data.get("tags", [])
	var is_starter := fs.starter_rooms.has(pos)
	var combat_suppressed := is_starter and not threats.is_empty()
	var enemy_count := 0
	var enemy_names: PackedStringArray = []
	if GameSession.combat != null:
		var alive := GameSession.combat.get_alive_enemies()
		enemy_count = alive.size()
		for e in alive:
			enemy_names.append("%s (%dHP)" % [e.name, e.health])

	var lines: PackedStringArray = [
		"[b]--- DEBUG (F3) ---[/b]",
		"floor: %d" % gs.floor,
		"coord: (%d, %d)" % [pos.x, pos.y],
		"room_type: %s" % room.data.get("difficulty", "?"),
		"tags: %s" % str(tags),
		"has_combat: %s" % str(room.has_combat),
		"enemies_defeated: %s" % str(room.enemies_defeated),
		"combat_escaped: %s" % str(room.combat_escaped),
		"combat_pending: %s" % str(GameSession.combat_pending),
		"combat_active: %s" % str(GameSession.is_combat_active()),
		"enemy_count: %d" % enemy_count,
		"enemy_names: %s" % (", ".join(enemy_names) if not enemy_names.is_empty() else "none"),
		"threats_pool: %s" % str(threats),
		"chest: %s" % str(room.has_chest and not room.chest_looted),
		"ground_items: %d" % (room.ground_items.size() + (1 if room.ground_gold > 0 else 0)),
		"store: %s" % str(room.has_store),
		"stairs: %s" % str(room.has_stairs),
		"starter_room: %s" % str(is_starter),
		"combat_suppressed: %s" % str(combat_suppressed),
		"rooms_explored: %d" % fs.rooms_explored,
	]
	_debug_label.text = "\n".join(lines)


# -------------------------------------------------------------------
# Log (with optional typewriter effect)
# -------------------------------------------------------------------

func _append_log(msg: String) -> void:
	if _log_text == null:
		return

	if not _log_scroll_sticky:
		_log_unread_count += 1
		if _log_new_msg_btn != null:
			_log_new_msg_btn.text = "New messages (%d)" % _log_unread_count
			_log_new_msg_btn.visible = true

	var style := _get_line_style(msg)
	var sm = get_node_or_null("/root/SettingsManager")
	var delay_ms: int = 0
	if sm != null and sm.has_method("get_text_speed_delay"):
		delay_ms = sm.get_text_speed_delay()

	if delay_ms <= 0:
		_render_styled_line(msg, style)
		return

	_typewriter_queue.append({"text": msg, "style": style})
	if not _typewriter_active:
		_process_typewriter()


static func _get_line_style(msg: String) -> Dictionary:
	if msg.begins_with("===") or msg.begins_with("=="):
		return {"color": DungeonTheme.TEXT_GOLD, "bold": false}
	if msg.begins_with("Entered:") or msg.begins_with("Returned to:"):
		return {"color": DungeonTheme.TEXT_GOLD, "bold": true}
	if msg.begins_with("Enemy:") or msg.begins_with("Enemy lurks") or msg.contains("blocks your path"):
		return {"color": DungeonTheme.TEXT_RED, "bold": false}
	if msg.begins_with("Combat begins"):
		return {"color": DungeonTheme.TEXT_RED, "bold": false}
	if msg.begins_with("Found stairs") or msg.begins_with("Rested") or msg.begins_with("Fled successfully"):
		return {"color": DungeonTheme.TEXT_GREEN, "bold": false}
	if msg.begins_with("Discovered"):
		return {"color": DungeonTheme.TEXT_CYAN, "bold": false}
	if msg.begins_with("Picked up") or msg.begins_with("Opened chest") or msg.begins_with("Searched"):
		return {"color": DungeonTheme.TEXT_GOLD, "bold": false}
	if msg.begins_with("[CHEST]"):
		return {"color": DungeonTheme.TEXT_GOLD, "bold": false}
	if msg.begins_with("Mini-boss defeated") or msg.begins_with("Boss defeated"):
		return {"color": DungeonTheme.TEXT_GREEN, "bold": false}
	if msg.begins_with("[Session Trace]"):
		return {"color": DungeonTheme.TEXT_SECONDARY, "bold": false}
	if msg.begins_with("Browsing store"):
		return {"color": DungeonTheme.TEXT_CYAN, "bold": false}
	if msg.begins_with("Cannot") or msg.begins_with("No ") or msg.begins_with("Already") or msg.begins_with("Failed"):
		return {"color": DungeonTheme.TEXT_SECONDARY, "bold": false}
	if msg.begins_with("Enemies ahead") or msg.begins_with("Something lurks"):
		return {"color": DungeonTheme.TEXT_RED, "bold": false}
	return {}


func _render_styled_line(msg: String, style: Dictionary) -> void:
	var has_color: bool = style.has("color")
	var is_bold: bool = style.get("bold", false)
	if has_color:
		_log_text.push_color(style["color"])
	if is_bold:
		_log_text.push_bold()
	_log_text.append_text(msg)
	if is_bold:
		_log_text.pop()
	if has_color:
		_log_text.pop()
	_log_text.append_text("\n")


func _on_copy_log() -> void:
	if _context == null or _context.log == null:
		return
	var entries := _context.log.get_text_entries()
	if entries.is_empty():
		return
	var header := _build_copy_header()
	var text := header + "\n".join(entries)
	DisplayServer.clipboard_set(text)
	_append_log("[Session Trace] Log copied to clipboard.")


func _build_copy_header() -> String:
	var lines: PackedStringArray = []
	lines.append("=== Dice Dungeon — Adventure Log ===")
	lines.append("Seed: %d" % GameSession.run_seed)
	lines.append("RNG Mode: %s" % GameSession.run_rng_mode)
	var gs := GameSession.game_state
	if gs != null:
		lines.append("Floor: %d" % gs.floor)
	var room := GameSession.get_current_room()
	if room != null:
		lines.append("Room: %s" % room.data.get("name", "?"))
	var aid: int = 0
	if _context != null and _context.log != null:
		aid = _context.log.size()
	lines.append("Action ID: %d" % aid)
	lines.append("Build: %s" % GameSession.trace.build_version)
	lines.append("Content Version: %s" % GameSession.trace.content_version)
	lines.append("Settings Fingerprint: %s" % GameSession.trace.settings_fingerprint)
	lines.append("====================================")
	lines.append("")
	return "\n".join(lines)


func _on_new_messages_clicked() -> void:
	_log_scroll_sticky = true
	_log_unread_count = 0
	if _log_new_msg_btn != null:
		_log_new_msg_btn.visible = false
	if _log_text != null:
		_log_text.scroll_following = true


func _check_log_scroll() -> void:
	if _log_text == null:
		return
	var vscroll := _log_text.get_v_scroll_bar()
	if vscroll == null:
		return
	var at_bottom := vscroll.value >= vscroll.max_value - vscroll.page - 2.0
	if at_bottom:
		if not _log_scroll_sticky:
			_log_scroll_sticky = true
			_log_unread_count = 0
			if _log_new_msg_btn != null:
				_log_new_msg_btn.visible = false
			_log_text.scroll_following = true
	else:
		if _log_scroll_sticky:
			_log_scroll_sticky = false
			_log_text.scroll_following = false


func _process_typewriter() -> void:
	if _typewriter_queue.is_empty():
		_typewriter_active = false
		return
	_typewriter_active = true
	var entry = _typewriter_queue.pop_front()
	var msg: String = entry["text"] if entry is Dictionary else str(entry)
	var style: Dictionary = entry.get("style", {}) if entry is Dictionary else {}

	var has_color: bool = style.has("color")
	var is_bold: bool = style.get("bold", false)
	if has_color:
		_log_text.push_color(style["color"])
	if is_bold:
		_log_text.push_bold()

	_typewrite_chars(msg, 0, has_color, is_bold)


func _typewrite_chars(msg: String, idx: int, has_color: bool, is_bold: bool) -> void:
	if _log_text == null:
		_typewriter_active = false
		return
	if idx >= msg.length():
		if is_bold:
			_log_text.pop()
		if has_color:
			_log_text.pop()
		_log_text.append_text("\n")
		_process_typewriter()
		return

	_log_text.append_text(msg[idx])

	var sm = get_node_or_null("/root/SettingsManager")
	var delay_ms: int = 13
	if sm != null and sm.has_method("get_text_speed_delay"):
		delay_ms = sm.get_text_speed_delay()
	if delay_ms <= 0:
		_log_text.append_text(msg.substr(idx + 1))
		if is_bold:
			_log_text.pop()
		if has_color:
			_log_text.pop()
		_log_text.append_text("\n")
		_process_typewriter()
		return

	get_tree().create_timer(float(delay_ms) / 1000.0).timeout.connect(
		_typewrite_chars.bind(msg, idx + 1, has_color, is_bold))


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

func _make_icon_btn(icon_text: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = icon_text
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(32, 28)
	btn.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)

	var normal := StyleBoxFlat.new()
	normal.bg_color = DungeonTheme.BG_PANEL
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = DungeonTheme.BG_PANEL.lightened(0.15)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = DungeonTheme.BG_PANEL.darkened(0.1)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


func _make_move_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(40, 32)
	btn.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)

	var normal := StyleBoxFlat.new()
	normal.bg_color = DungeonTheme.BTN_PRIMARY
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Color.BLACK)

	var hover := StyleBoxFlat.new()
	hover.bg_color = DungeonTheme.BTN_HOVER
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(2)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = DungeonTheme.BTN_PRESSED
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(2)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = DungeonTheme.BTN_DISABLED_BG
	disabled.set_corner_radius_all(4)
	disabled.set_content_margin_all(2)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", DungeonTheme.BTN_DISABLED_TEXT)

	return btn


func _make_action_btn(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", DungeonTheme.FONT_BUTTON)

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.6)
	normal.set_corner_radius_all(3)
	normal.border_color = accent.darkened(0.2)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", accent.lightened(0.3))

	var hover := StyleBoxFlat.new()
	hover.bg_color = accent.darkened(0.4)
	hover.set_corner_radius_all(3)
	hover.border_color = accent
	hover.set_border_width_all(1)
	hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent.darkened(0.5)
	pressed.set_corner_radius_all(3)
	pressed.set_content_margin_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = DungeonTheme.BTN_DISABLED_BG
	disabled.set_corner_radius_all(3)
	disabled.set_content_margin_all(4)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", DungeonTheme.BTN_DISABLED_TEXT)

	return btn


func _update_move_btn_style(btn: Button) -> void:
	if btn.disabled:
		btn.add_theme_color_override("font_color", DungeonTheme.BTN_DISABLED_TEXT)
	else:
		btn.add_theme_color_override("font_color", Color.BLACK)


func _export_session_trace() -> void:
	var paths := GameSession.export_session_trace()
	var json_path: String = str(paths.get("json", ""))
	var txt_path: String = str(paths.get("txt", ""))
	if json_path.is_empty():
		_append_log("[Session Trace] Export failed — could not write files.")
		return
	_append_log("[Session Trace] Exported to %s" % json_path)
	_append_log("[Session Trace] Text summary: %s" % txt_path)
	GameSession.log_message.emit("[Session Trace] Export complete.")


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(40, 32)
	return c
