extends PanelContainer
## Character Status Panel — tabs for Character, Stats, and Lore Codex.
## Mirrors Python explorer/ui_character_menu.py show_character_status.

signal close_requested()

var _tab_container: TabContainer
var _character_tab: VBoxContainer
var _stats_tab: VBoxContainer
var _lore_tab: Control

var _char_info: RichTextLabel
var _stats_info: RichTextLabel
var _lore_codex_panel: Control

var _btn_close: Button

var _codex_scene := preload("res://ui/scenes/LoreCodexPanel.tscn")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(func(): if visible: refresh())


func _build_ui() -> void:
	var bg := DungeonTheme.make_panel_bg(
		Color(0.06, 0.07, 0.10, 0.97), DungeonTheme.TEXT_PURPLE)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := DungeonTheme.make_header(
		"⚙ CHARACTER STATUS", DungeonTheme.TEXT_PURPLE, DungeonTheme.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_btn_close = DungeonTheme.make_styled_btn("✕ Close", DungeonTheme.TEXT_SECONDARY, 80)
	_btn_close.pressed.connect(func(): close_requested.emit())
	header.add_child(_btn_close)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.TEXT_PURPLE))

	# Tabs
	_tab_container = TabContainer.new()
	_tab_container.name = "StatusTabs"
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tab_container)

	# Character tab
	_character_tab = VBoxContainer.new()
	_character_tab.name = "Character"
	_tab_container.add_child(_character_tab)

	_char_info = RichTextLabel.new()
	_char_info.bbcode_enabled = true
	_char_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_char_info.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_char_info.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	_character_tab.add_child(_char_info)

	# Stats tab
	_stats_tab = VBoxContainer.new()
	_stats_tab.name = "Stats"
	_tab_container.add_child(_stats_tab)

	_stats_info = RichTextLabel.new()
	_stats_info.bbcode_enabled = true
	_stats_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_info.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_stats_info.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	_stats_tab.add_child(_stats_info)

	# Lore tab
	_lore_tab = VBoxContainer.new()
	_lore_tab.name = "Lore"
	_tab_container.add_child(_lore_tab)

	_lore_codex_panel = _codex_scene.instantiate()
	_lore_codex_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_codex_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lore_codex_panel.has_signal("close_requested"):
		_lore_codex_panel.close_requested.connect(func(): close_requested.emit())
	_lore_tab.add_child(_lore_codex_panel)


func refresh() -> void:
	_refresh_character()
	_refresh_stats()
	if _lore_codex_panel.has_method("refresh"):
		_lore_codex_panel.refresh()


func _refresh_character() -> void:
	var gs := GameSession.game_state
	if gs == null:
		_char_info.text = "No active game."
		return

	var gold_hex := DungeonTheme.TEXT_GOLD.to_html(false)
	var cyan_hex := DungeonTheme.TEXT_CYAN.to_html(false)
	var dim_hex := DungeonTheme.TEXT_DIM.to_html(false)

	var lines: PackedStringArray = []
	lines.append("[b]Health:[/b] %d / %d" % [gs.health, gs.max_health])
	lines.append("[b]Gold:[/b] [color=#%s]%d[/color]" % [gold_hex, gs.gold])
	lines.append("[b]Floor:[/b] %d" % gs.floor)
	lines.append("[b]Dice:[/b] %d" % gs.num_dice)
	lines.append("[b]Damage Bonus:[/b] %d" % gs.damage_bonus)
	lines.append("[b]Crit Chance:[/b] %.0f%%" % (gs.crit_chance * 100))
	lines.append("[b]Reroll Bonus:[/b] %d" % gs.reroll_bonus)
	lines.append("[b]Armor:[/b] %d" % gs.armor)
	lines.append("")

	lines.append("[b]Equipment:[/b]")
	for slot in gs.equipped_items:
		var item: String = gs.equipped_items[slot]
		if item.is_empty():
			lines.append("  %s: [color=#%s](empty)[/color]" % [slot, dim_hex])
		else:
			var dur := GameSession.inventory_engine.get_durability_percent(item) if GameSession.inventory_engine != null else 100
			lines.append("  %s: [color=#%s]%s[/color] [%d%%]" % [slot, cyan_hex, item, dur])

	lines.append("")
	lines.append("[b]Inventory:[/b] %d / %d" % [gs.inventory.size(), gs.max_inventory])

	_char_info.text = "\n".join(lines)


func _refresh_stats() -> void:
	var gs := GameSession.game_state
	if gs == null:
		_stats_info.text = "No active game."
		return

	var s := gs.stats
	var lines: PackedStringArray = []
	lines.append("[b]Game Statistics[/b]")
	lines.append("")
	lines.append("[b]Items Found:[/b] %s" % str(s.get("items_found", 0)))
	lines.append("[b]Items Used:[/b] %s" % str(s.get("items_used", 0)))
	lines.append("[b]Potions Used:[/b] %s" % str(s.get("potions_used", 0)))
	lines.append("[b]Items Sold:[/b] %s" % str(s.get("items_sold", 0)))
	lines.append("[b]Items Purchased:[/b] %s" % str(s.get("items_purchased", 0)))
	lines.append("[b]Gold Found:[/b] %s" % str(s.get("gold_found", 0)))
	lines.append("[b]Gold Spent:[/b] %s" % str(s.get("gold_spent", 0)))
	lines.append("[b]Containers Searched:[/b] %s" % str(s.get("containers_searched", 0)))
	lines.append("")
	lines.append("[b]Lore Entries Discovered:[/b] %d" % gs.lore_codex.size())

	_stats_info.text = "\n".join(lines)
