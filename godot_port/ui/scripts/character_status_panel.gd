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
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.09, 0.11, 0.97)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "=== CHARACTER STATUS ==="
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_btn_close = Button.new()
	_btn_close.text = "Close"
	_btn_close.pressed.connect(func(): close_requested.emit(); visible = false)
	header.add_child(_btn_close)

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
	_character_tab.add_child(_char_info)

	# Stats tab
	_stats_tab = VBoxContainer.new()
	_stats_tab.name = "Stats"
	_tab_container.add_child(_stats_tab)

	_stats_info = RichTextLabel.new()
	_stats_info.bbcode_enabled = true
	_stats_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_tab.add_child(_stats_info)

	# Lore tab — embedded codex panel
	_lore_tab = VBoxContainer.new()
	_lore_tab.name = "Lore"
	_tab_container.add_child(_lore_tab)

	_lore_codex_panel = _codex_scene.instantiate()
	_lore_codex_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_codex_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lore_codex_panel.has_signal("close_requested"):
		_lore_codex_panel.close_requested.connect(func(): close_requested.emit(); visible = false)
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

	var lines: PackedStringArray = []
	lines.append("[b]Health:[/b] %d / %d" % [gs.health, gs.max_health])
	lines.append("[b]Gold:[/b] %d" % gs.gold)
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
			lines.append("  %s: (empty)" % slot)
		else:
			var dur := GameSession.inventory_engine.get_durability_percent(item) if GameSession.inventory_engine != null else 100
			lines.append("  %s: %s [%d%%]" % [slot, item, dur])

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
