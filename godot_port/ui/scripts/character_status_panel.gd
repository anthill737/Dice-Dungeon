extends PanelContainer
## Character Status Panel — tabs for Character, Game Stats, and Lore Codex.
## Mirrors Python explorer/ui_character_menu.py show_character_status.
## Character tab has section headers: Equipped Gear, Character Stats,
## Active Effects, Resources.

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

	# Tabs — names matching Python: Character, Game Stats, Lore Codex
	_tab_container = TabContainer.new()
	_tab_container.name = "StatusTabs"
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tab_container)

	# Character tab
	_character_tab = VBoxContainer.new()
	_character_tab.name = "Character"
	_tab_container.add_child(_character_tab)

	_char_info = RichTextLabel.new()
	_char_info.name = "CharacterInfo"
	_char_info.bbcode_enabled = true
	_char_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_char_info.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_char_info.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	_character_tab.add_child(_char_info)

	# Game Stats tab (renamed from "Stats")
	_stats_tab = VBoxContainer.new()
	_stats_tab.name = "Game Stats"
	_tab_container.add_child(_stats_tab)

	_stats_info = RichTextLabel.new()
	_stats_info.name = "StatsInfo"
	_stats_info.bbcode_enabled = true
	_stats_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_info.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_stats_info.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
	_stats_tab.add_child(_stats_info)

	# Lore Codex tab (renamed from "Lore")
	_lore_tab = VBoxContainer.new()
	_lore_tab.name = "Lore Codex"
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
	var red_hex := DungeonTheme.TEXT_RED.to_html(false)
	var purple_hex := DungeonTheme.TEXT_PURPLE.to_html(false)
	var green_hex := DungeonTheme.TEXT_GREEN.to_html(false)

	var lines: PackedStringArray = []

	# --- Section: Equipped Gear (cyan header, matching Python) ---
	lines.append("[color=#%s][b]◊ EQUIPPED GEAR[/b][/color]" % cyan_hex)
	lines.append("")
	for slot in gs.equipped_items:
		var item_name: String = gs.equipped_items[slot]
		if item_name.is_empty():
			lines.append("  %s: [color=#%s](empty)[/color]" % [slot.capitalize(), dim_hex])
		else:
			var dur := 100
			var effects := ""
			if GameSession.inventory_engine != null:
				dur = GameSession.inventory_engine.get_durability_percent(item_name)
				var item_def := GameSession.inventory_engine.get_item_def(item_name)
				var desc: String = item_def.get("desc", "")
				if not desc.is_empty():
					effects = " — %s" % desc
			lines.append("  %s: [color=#%s]%s[/color] [%d%%]%s" % [
				slot.capitalize(), cyan_hex, item_name, dur, effects])
	lines.append("")

	# --- Section: Character Stats (red header, matching Python) ---
	lines.append("[color=#%s][b]⚔ CHARACTER STATS[/b][/color]" % red_hex)
	lines.append("")
	lines.append("  [b]Health:[/b] [color=#%s]%d / %d[/color]" % [cyan_hex, gs.health, gs.max_health])
	lines.append("  [b]Dice Pool:[/b] [color=#%s]%d[/color]" % [cyan_hex, gs.num_dice])
	lines.append("  [b]Base Damage Bonus:[/b] [color=#%s]%d[/color]" % [cyan_hex, gs.damage_bonus])
	lines.append("  [b]Damage Multiplier:[/b] [color=#%s]%.1f×[/color]" % [cyan_hex, gs.multiplier])
	lines.append("  [b]Crit Chance:[/b] [color=#%s]%.0f%%[/color]" % [cyan_hex, gs.crit_chance * 100])
	lines.append("  [b]Healing Bonus:[/b] [color=#%s]%d[/color]" % [cyan_hex, 0])
	lines.append("  [b]Bonus Rerolls:[/b] [color=#%s]%d[/color]" % [cyan_hex, gs.reroll_bonus])
	lines.append("  [b]Armor:[/b] [color=#%s]%d[/color]" % [cyan_hex, gs.armor])
	lines.append("  [b]Floor:[/b] [color=#%s]%d[/color]" % [cyan_hex, gs.floor])
	lines.append("")

	# --- Section: Active Effects (purple header, matching Python) ---
	lines.append("[color=#%s][b]✨ ACTIVE EFFECTS[/b][/color]" % purple_hex)
	lines.append("")

	var has_effects := false

	if gs.temp_shield > 0:
		lines.append("  Shield: [color=#%s]%d[/color]" % [cyan_hex, gs.temp_shield])
		has_effects = true

	if gs.shop_discount > 0.0:
		lines.append("  Shop Discount: [color=#%s]%.0f%%[/color]" % [green_hex, gs.shop_discount * 100])
		has_effects = true

	var statuses: Array = gs.flags.get("statuses", [])
	if not statuses.is_empty():
		lines.append("  Statuses: [color=#%s]%s[/color]" % [red_hex, ", ".join(statuses)])
		has_effects = true

	var disarm: int = int(gs.flags.get("disarm_token", 0))
	if disarm > 0:
		lines.append("  Disarm Tokens: [color=#%s]%d[/color]" % [cyan_hex, disarm])
		has_effects = true

	var escape: int = int(gs.flags.get("escape_token", 0))
	if escape > 0:
		lines.append("  Escape Tokens: [color=#%s]%d[/color]" % [cyan_hex, escape])
		has_effects = true

	if gs.temp_combat_damage > 0:
		lines.append("  Temp Damage Bonus: [color=#%s]+%d[/color] (combat)" % [cyan_hex, gs.temp_combat_damage])
		has_effects = true

	if gs.temp_combat_crit > 0.0:
		lines.append("  Temp Crit Bonus: [color=#%s]+%.0f%%[/color] (combat)" % [cyan_hex, gs.temp_combat_crit * 100])
		has_effects = true

	if gs.temp_combat_rerolls > 0:
		lines.append("  Temp Extra Rerolls: [color=#%s]+%d[/color] (combat)" % [cyan_hex, gs.temp_combat_rerolls])
		has_effects = true

	if not has_effects:
		lines.append("  [color=#%s](none)[/color]" % dim_hex)

	lines.append("")

	# --- Section: Resources (gold header, matching Python) ---
	lines.append("[color=#%s][b]◇ RESOURCES[/b][/color]" % gold_hex)
	lines.append("")
	lines.append("  [b]Gold:[/b] [color=#%s]%d[/color]" % [gold_hex, gs.gold])
	lines.append("  [b]Inventory:[/b] %d / %d" % [gs.inventory.size(), gs.max_inventory])

	_char_info.text = "\n".join(lines)


func _refresh_stats() -> void:
	var gs := GameSession.game_state
	if gs == null:
		_stats_info.text = "No active game."
		return

	var s := gs.stats
	var cyan_hex := DungeonTheme.TEXT_CYAN.to_html(false)
	var gold_hex := DungeonTheme.TEXT_GOLD.to_html(false)
	var red_hex := DungeonTheme.TEXT_RED.to_html(false)

	var lines: PackedStringArray = []

	# Combat section
	lines.append("[color=#%s][b]⚔ Combat[/b][/color]" % red_hex)
	lines.append("  Enemies Defeated: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("enemies_defeated", 0))])
	lines.append("")

	# Economy section
	lines.append("[color=#%s][b]◇ Economy[/b][/color]" % gold_hex)
	lines.append("  Gold Found: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("gold_found", 0))])
	lines.append("  Gold Spent: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("gold_spent", 0))])
	lines.append("")

	# Items section
	lines.append("[color=#%s][b]🎒 Items[/b][/color]" % DungeonTheme.TEXT_CYAN.to_html(false))
	lines.append("  Items Found: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("items_found", 0))])
	lines.append("  Items Used: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("items_used", 0))])
	lines.append("  Potions Used: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("potions_used", 0))])
	lines.append("  Items Sold: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("items_sold", 0))])
	lines.append("  Items Purchased: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("items_purchased", 0))])
	lines.append("")

	# Exploration section
	lines.append("[color=#%s][b]🗺 Exploration[/b][/color]" % DungeonTheme.TEXT_GREEN.to_html(false))
	lines.append("  Containers Searched: [color=#%s]%s[/color]" % [cyan_hex, str(s.get("containers_searched", 0))])
	lines.append("")

	# Lore section
	lines.append("[color=#%s][b]📜 Lore[/b][/color]" % DungeonTheme.TEXT_PURPLE.to_html(false))
	lines.append("  Lore Entries Discovered: [color=#%s]%d[/color]" % [cyan_hex, gs.lore_codex.size()])

	_stats_info.text = "\n".join(lines)
