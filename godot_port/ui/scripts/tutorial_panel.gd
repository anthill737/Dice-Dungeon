extends PanelContainer
## Tutorial / How to Play panel — tabbed interface with game instructions.
## Ported from Python explorer/tutorial.py.
## Hosted inside PopupFrame via MenuOverlayManager.

signal close_requested()

var _tab_container: HBoxContainer
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _current_topic: String = "basics"
var _tab_buttons: Dictionary = {}

const TOPICS: Array[Array] = [
	["basics", "Basics"],
	["movement", "Movement"],
	["combat", "Combat"],
	["inventory", "Inventory"],
	["equipment", "Equipment"],
	["resources", "Resources"],
	["keys", "Keys & Bosses"],
	["stores", "Stores"],
	["menus", "Menus"],
	["controls", "Controls"],
]


func _ready() -> void:
	_build_ui()
	switch_tab("basics")


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(0, 40)
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(tab_scroll)

	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(_tab_container)

	for topic_arr in TOPICS:
		var tid: String = topic_arr[0]
		var label: String = topic_arr[1]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(80, 30)
		btn.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
		btn.pressed.connect(switch_tab.bind(tid))
		_tab_container.add_child(btn)
		_tab_buttons[tid] = btn

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_content_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 4)
	_content_scroll.add_child(_content_vbox)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(footer)

	var btn_close := DungeonTheme.make_styled_btn("Got It!", DungeonTheme.BTN_PRIMARY, 160)
	btn_close.custom_minimum_size.y = 36
	btn_close.pressed.connect(func(): close_requested.emit())
	footer.add_child(btn_close)


func switch_tab(topic_id: String) -> void:
	_current_topic = topic_id
	_update_tab_styles()
	_show_content(topic_id)


func _update_tab_styles() -> void:
	for tid in _tab_buttons:
		var btn: Button = _tab_buttons[tid]
		if tid == _current_topic:
			var active := StyleBoxFlat.new()
			active.bg_color = DungeonTheme.TEXT_GOLD
			active.set_corner_radius_all(4)
			active.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", active)
			btn.add_theme_color_override("font_color", Color.BLACK)
		else:
			var normal := StyleBoxFlat.new()
			normal.bg_color = DungeonTheme.BG_PANEL
			normal.set_corner_radius_all(4)
			normal.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)


func _show_content(topic_id: String) -> void:
	for child in _content_vbox.get_children():
		child.queue_free()

	var content := _get_content(topic_id)
	for section in content:
		var stype: String = section.get("type", "text")
		var stext: String = section.get("text", "")
		match stype:
			"title":
				var lbl := Label.new()
				lbl.text = stext
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
				lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
				_content_vbox.add_child(lbl)
			"subtitle":
				var lbl := Label.new()
				lbl.text = stext
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
				lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_CYAN)
				_content_vbox.add_child(lbl)
			"text":
				var lbl := Label.new()
				lbl.text = stext
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
				lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
				_content_vbox.add_child(lbl)
			"box", "list":
				var box := PanelContainer.new()
				var style := StyleBoxFlat.new()
				style.bg_color = DungeonTheme.BG_PANEL
				style.set_corner_radius_all(4)
				style.set_content_margin_all(12)
				style.border_color = DungeonTheme.BORDER
				style.set_border_width_all(1)
				box.add_theme_stylebox_override("panel", style)
				var lbl := Label.new()
				lbl.text = stext
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
				lbl.add_theme_color_override("font_color", DungeonTheme.TEXT_BONE)
				box.add_child(lbl)
				_content_vbox.add_child(box)

	_content_scroll.scroll_vertical = 0


static func _get_content(topic_id: String) -> Array:
	match topic_id:
		"basics":
			return [
				{"type": "title", "text": "GAME OBJECTIVE"},
				{"type": "text", "text": "Explore the dungeon, defeat enemies, collect loot, and survive as long as possible. Descend through increasingly difficult floors and see how far you can go!"},
				{"type": "subtitle", "text": "How to Win"},
				{"type": "list", "text": "• Survive and explore as many rooms as possible\n• Defeat enemies to earn gold and experience\n• Find stairs to descend to deeper floors\n• Collect powerful equipment and items\n• Build your score by exploring and defeating enemies"},
			]
		"movement":
			return [
				{"type": "title", "text": "EXPLORATION & MOVEMENT"},
				{"type": "subtitle", "text": "How to Move Between Rooms"},
				{"type": "box", "text": "Click the N, S, E, W buttons at the bottom of the screen\nOR use the WASD keyboard keys:\nW = North, A = West, S = South, D = East"},
				{"type": "list", "text": "• Each room may contain enemies, loot, chests, or special events\n• Some paths may be blocked - you'll see a message if you try to enter\n• Your current position is shown on the minimap as a gold dot"},
				{"type": "subtitle", "text": "Finding and Collecting Loot"},
				{"type": "box", "text": "When you enter a room with loot, buttons appear in the ACTION PANEL:\n• \"Open Chest\" - Click to open treasure chests\n• \"Search\" - Click when containers appear on the ground\n• \"Pick Up\" - Click to collect specific items"},
				{"type": "subtitle", "text": "Descending to Deeper Floors"},
				{"type": "list", "text": "• Stairs appear randomly in rooms after you've explored a few areas\n• Click the \"Descend\" button when stairs appear\n• Deeper floors have tougher enemies but better rewards\n• Each floor resets the room layout"},
			]
		"combat":
			return [
				{"type": "title", "text": "COMBAT SYSTEM"},
				{"type": "subtitle", "text": "Rolling Dice"},
				{"type": "box", "text": "Click the \"ROLL\" button to roll all unlocked dice.\nYou get 3 rolls per turn - use them wisely!"},
				{"type": "subtitle", "text": "Locking Dice"},
				{"type": "box", "text": "Click on any die to lock or unlock it.\nLocked dice keep their value when you roll again.\nLocked dice show a colored border."},
				{"type": "list", "text": "• Lock high values you want to keep (6s, 5s, or 4s)\n• Unlock and reroll low values to improve your total\n• Plan your locks carefully - you only get 3 rolls per turn!"},
				{"type": "subtitle", "text": "Attacking"},
				{"type": "box", "text": "After rolling, click the \"ATTACK\" button.\nYour dice total determines how much damage you deal.\nHigher total = more damage to the enemy."},
				{"type": "list", "text": "• Critical hits (10% base chance) deal bonus damage\n• Your weapon adds bonus damage to each attack\n• Watch the enemy's dice roll - they attack the same way!"},
				{"type": "subtitle", "text": "Combat Options"},
				{"type": "box", "text": "Use Item: Access potions and combat consumables.\nFlee: Escape from combat (costs HP)."},
			]
		"inventory":
			return [
				{"type": "title", "text": "INVENTORY MANAGEMENT"},
				{"type": "subtitle", "text": "Opening Your Inventory"},
				{"type": "box", "text": "Click the \"INVENTORY\" button below the action panel\nOR press the Tab key on your keyboard."},
				{"type": "subtitle", "text": "Using Consumable Items"},
				{"type": "box", "text": "1. Open your inventory\n2. Click on an item to select it\n3. Click the \"USE\" button to consume potions or scrolls"},
				{"type": "subtitle", "text": "Equipping Items"},
				{"type": "box", "text": "1. Open your inventory\n2. Click on a weapon, armor, or accessory\n3. Click the \"EQUIP\" button to wear or wield it"},
				{"type": "subtitle", "text": "Inventory Capacity"},
				{"type": "list", "text": "• Default capacity: 10 items\n• Increase capacity with backpacks from merchants\n• Equipped items don't count toward the limit\n• Manage your space carefully!"},
			]
		"equipment":
			return [
				{"type": "title", "text": "EQUIPMENT & DURABILITY"},
				{"type": "subtitle", "text": "Equipment Slots"},
				{"type": "list", "text": "• Weapon: Increases attack damage\n• Armor: Reduces damage taken and may increase max HP\n• Accessory: Provides special bonuses\n• Backpack: Increases inventory capacity"},
				{"type": "subtitle", "text": "Understanding Durability"},
				{"type": "box", "text": "Equipment wears down with use.\nWhen durability reaches 0, the item breaks and loses ALL bonuses!"},
				{"type": "subtitle", "text": "Repairing Equipment"},
				{"type": "box", "text": "1. Visit a merchant store\n2. Purchase repair kits\n3. Use repair kits from inventory to restore durability"},
				{"type": "list", "text": "• Weapon Repair Kit: Restores 40% weapon durability\n• Armor Repair Kit: Restores 40% armor durability\n• Master Repair Kit: Restores 60% of any equipment (Floor 5+)"},
			]
		"resources":
			return [
				{"type": "title", "text": "RESOURCES & UPGRADES"},
				{"type": "subtitle", "text": "Gold"},
				{"type": "list", "text": "• Earned by defeating enemies\n• Found in chests and containers\n• Spent at merchants for items, upgrades, and repairs"},
				{"type": "subtitle", "text": "Health Points (HP)"},
				{"type": "box", "text": "Keep your HP above 0 or it's GAME OVER!\nHeal using potions or by resting between rooms."},
				{"type": "subtitle", "text": "Resting to Recover"},
				{"type": "box", "text": "Click the \"REST\" button between rooms to recover HP.\nCooldown: You must explore 3 rooms before resting again."},
				{"type": "subtitle", "text": "Adventure Log"},
				{"type": "box", "text": "The Adventure Log at the bottom records all your actions,\ncombat results, and events."},
			]
		"keys":
			return [
				{"type": "title", "text": "KEYS & SPECIAL ROOMS"},
				{"type": "subtitle", "text": "Old Keys (Mini-Boss Rooms)"},
				{"type": "list", "text": "• Find Old Keys in chests and containers\n• Old Keys unlock elite difficulty mini-boss rooms\n• Mini-bosses are significantly tougher than normal enemies\n• Defeating mini-bosses rewards you with key fragments"},
				{"type": "subtitle", "text": "Key Fragments (Boss Rooms)"},
				{"type": "box", "text": "Collect 3 Key Fragments to unlock a Boss Room.\nFragments automatically combine when you have all 3."},
				{"type": "subtitle", "text": "Using Keys"},
				{"type": "box", "text": "1. Move toward a locked room\n2. A dialog appears asking if you want to use your key\n3. Click \"Unlock & Enter\" or \"Turn Back\""},
				{"type": "list", "text": "• Keys are consumed when used\n• Prepare well before entering - Full HP, Good Equipment, Potions\n• Mini-bosses and bosses don't respawn after defeat"},
			]
		"stores":
			return [
				{"type": "title", "text": "MERCHANTS & STORES"},
				{"type": "subtitle", "text": "Finding Merchants"},
				{"type": "list", "text": "• Stores appear randomly as you explore\n• When you enter a room with a merchant, a \"STORE\" button appears\n• Each floor typically has at least one store\n• Once discovered, you can fast travel to the store"},
				{"type": "subtitle", "text": "Shopping for Items"},
				{"type": "box", "text": "1. Click the \"STORE\" button when available\n2. Browse the BUY tab for items and upgrades\n3. Click on an item to select it\n4. Click \"BUY\" to purchase"},
				{"type": "subtitle", "text": "Selling Items"},
				{"type": "box", "text": "1. Open the store\n2. Click the \"SELL\" tab\n3. Select an item from your inventory\n4. Click \"SELL\" to receive gold"},
			]
		"menus":
			return [
				{"type": "title", "text": "MENUS & INFORMATION"},
				{"type": "subtitle", "text": "Opening the Menu"},
				{"type": "box", "text": "Click the ☰ button in the top-right corner\nOR press the M key"},
				{"type": "subtitle", "text": "Character Info"},
				{"type": "box", "text": "View your current stats, equipped items,\nactive effects, and character progression."},
				{"type": "subtitle", "text": "Lore Codex"},
				{"type": "box", "text": "Access all lore items you've discovered.\nFind lore items throughout the dungeon."},
				{"type": "subtitle", "text": "Save/Load Game"},
				{"type": "list", "text": "• Save Game: Store progress in 3 save slots\n• Load Game: Resume from a previous save\n• Save frequently to avoid losing progress!"},
			]
		"controls":
			return [
				{"type": "title", "text": "CONTROLS & SHORTCUTS"},
				{"type": "subtitle", "text": "Movement Controls"},
				{"type": "box", "text": "WASD Keys or N/S/E/W Buttons:\nW = North, A = West, S = South, D = East"},
				{"type": "subtitle", "text": "Action Shortcuts"},
				{"type": "list", "text": "• Tab: Open/close Inventory\n• R: Rest (when available)\n• M: Open the pause Menu\n• Escape: Close dialogs and menus"},
				{"type": "subtitle", "text": "Quick Reference"},
				{"type": "list", "text": "• Move: WASD keys or directional buttons\n• Combat: Roll dice → Lock good values → Roll again → Attack\n• Loot: Click Search, Pick Up, or Open Chest buttons\n• Heal: Rest button (3-room cooldown) or health potions\n• Inventory: Tab key or Inventory button\n• Save: ☰ menu → Save Game → Choose slot"},
			]
	return [{"type": "title", "text": "Topic Not Found"}, {"type": "text", "text": "This section is currently unavailable."}]
