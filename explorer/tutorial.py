"""
Tutorial Manager for Dice Dungeon
Handles the tutorial/how-to-play interface with tabbed navigation
"""

import tkinter as tk


class TutorialManager:
    """Manages the in-game tutorial interface"""
    
    def __init__(self, game):
        """
        Initialize the TutorialManager.
        
        Args:
            game: Reference to the main DiceDungeonExplorer instance
        """
        self.game = game
    
    def show_tutorial(self, active_topic='basics'):
        """Display the tutorial dialog with game instructions"""
        # Close existing dialog if any
        if hasattr(self.game, 'dialog_frame') and self.game.dialog_frame and self.game.dialog_frame.winfo_exists():
            self.game.dialog_frame.destroy()
            self.game.dialog_frame = None
        
        # Create dialog
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(800, 700, 0.8, 0.9)
        
        # Determine parent: use game_frame if in-game, otherwise use root
        parent = self.game.root
        if hasattr(self.game, 'game_frame') and self.game.game_frame is not None and self.game.game_frame.winfo_exists():
            parent = self.game.game_frame
        
        self.game.dialog_frame = tk.Frame(parent, bg=self.game.current_colors["bg_panel"], 
                                          relief=tk.RIDGE, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor='center', 
                                      width=dialog_width, height=dialog_height)
        
        # Grab focus and bind ESC to close
        self.game.dialog_frame.focus_set()
        self.game.dialog_frame.bind('<Escape>', lambda e: self.game.close_dialog() or "break")
        
        # Header frame for title and close button
        header_frame = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_panel"])
        header_frame.pack(fill=tk.X, pady=(5, 0))
        
        # Title
        tk.Label(header_frame, text="📜 HOW TO PLAY",
                font=('Arial', self.game.scale_font(20), 'bold'),
                bg=self.game.current_colors["bg_panel"],
                fg=self.game.current_colors["text_gold"],
                pady=5).pack(side=tk.LEFT, padx=10)
        
        # Red X close button
        close_btn = tk.Label(header_frame, text="✕", font=('Arial', self.game.scale_font(16), 'bold'),
                            bg=self.game.current_colors["bg_panel"], fg='#ff4444', cursor="hand2", padx=10)
        close_btn.pack(side=tk.RIGHT, padx=10)
        close_btn.bind('<Button-1>', lambda e: self.game.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Create notebook for topic tabs
        notebook = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_panel"])
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Tab buttons frame with scrolling if needed
        tab_outer = tk.Frame(notebook, bg=self.game.current_colors["bg_panel"])
        tab_outer.pack(fill=tk.X, pady=5)
        
        # Create scrollable tab frame for many tabs
        tab_canvas = tk.Canvas(tab_outer, bg=self.game.current_colors["bg_panel"], height=50, highlightthickness=0)
        tab_frame = tk.Frame(tab_canvas, bg=self.game.current_colors["bg_panel"])
        
        tab_canvas.create_window((0, 0), window=tab_frame, anchor="nw")
        tab_frame.bind("<Configure>", lambda e: tab_canvas.configure(scrollregion=tab_canvas.bbox("all")))
        tab_canvas.pack(fill=tk.X)
        
        # Container for tab content
        content_container = tk.Frame(notebook, bg=self.game.current_colors["bg_panel"])
        content_container.pack(fill=tk.BOTH, expand=True)
        
        # Footer frame for the close button (pack BEFORE showing content so it stays at bottom)
        footer_frame = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_panel"])
        footer_frame.pack(side=tk.BOTTOM, fill=tk.X, pady=10)
        
        # Close button in footer
        tk.Button(footer_frame, text="Got It!", command=self.game.close_dialog,
                 font=('Arial', self.game.scale_font(12), 'bold'), bg=self.game.current_colors["button_primary"], 
                 fg='#000000', width=15, pady=8).pack()
        
        # State to track current tab
        current_tab = {'value': active_topic}
        tab_buttons = {}
        
        # Define topic tabs
        topics = [
            ('basics', 'Basics'),
            ('movement', 'Movement'),
            ('combat', 'Combat'),
            ('inventory', 'Inventory'),
            ('equipment', 'Equipment'),
            ('resources', 'Resources'),
            ('keys', 'Keys & Bosses'),
            ('stores', 'Stores'),
            ('menus', 'Menus'),
            ('controls', 'Controls')
        ]
        
        def switch_tab(topic_id):
            current_tab['value'] = topic_id
            # Update button colors
            for tid, btn in tab_buttons.items():
                if tid == topic_id:
                    btn.config(bg=self.game.current_colors["text_gold"], fg='#000000')
                else:
                    btn.config(bg=self.game.current_colors["bg_dark"], fg='#ffffff')
            # Show content
            self._show_tutorial_content(content_container, topic_id, dialog_width)
        
        # Create tab buttons
        for topic_id, topic_label in topics:
            btn = tk.Button(tab_frame, text=topic_label, command=lambda tid=topic_id: switch_tab(tid),
                           font=('Arial', self.game.scale_font(9), 'bold'), 
                           bg=self.game.current_colors["text_gold"] if topic_id == active_topic else self.game.current_colors["bg_dark"],
                           fg='#000000' if topic_id == active_topic else '#ffffff',
                           padx=5, pady=4)
            btn.pack(side=tk.LEFT, padx=1)
            tab_buttons[topic_id] = btn
        
        # Show initial tab
        switch_tab(active_topic)
        
        # Mark tutorial as seen
        self.game.tutorial_seen = True
    
    def _show_tutorial_content(self, parent, topic_id, dialog_width):
        """Show tutorial content for a specific topic"""
        # Clear parent
        for widget in parent.winfo_children():
            widget.destroy()
        
        # Create scrollable area
        canvas = tk.Canvas(parent, bg=self.game.current_colors["bg_primary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(parent, orient="vertical", command=canvas.yview, width=10,
                                bg=self.game.current_colors["bg_primary"], troughcolor=self.game.current_colors["bg_dark"])
        scroll_frame = tk.Frame(canvas, bg=self.game.current_colors["bg_primary"])
        
        scroll_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        
        def update_width(event=None):
            canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
        
        canvas_window = canvas.create_window((0, 0), window=scroll_frame, anchor="nw")
        canvas.bind("<Configure>", update_width)
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Setup mousewheel scrolling
        self.game.setup_mousewheel_scrolling(canvas)
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Get content for this topic
        content = self._get_tutorial_topic_content(topic_id)
        
        # Display content with styling
        for section in content:
            if section['type'] == 'title':
                tk.Label(scroll_frame, text=section['text'], 
                        font=('Arial', self.game.scale_font(16), 'bold'),
                        bg=self.game.current_colors["bg_primary"], 
                        fg=self.game.current_colors["text_gold"],
                        pady=15, wraplength=dialog_width-80, justify=tk.CENTER).pack(fill=tk.X, padx=20)
            elif section['type'] == 'subtitle':
                tk.Label(scroll_frame, text=section['text'], 
                        font=('Arial', self.game.scale_font(13), 'bold'),
                        bg=self.game.current_colors["bg_primary"], 
                        fg=self.game.current_colors["text_cyan"],
                        pady=8, wraplength=dialog_width-80, justify=tk.CENTER).pack(fill=tk.X, padx=25)
            elif section['type'] == 'text':
                tk.Label(scroll_frame, text=section['text'], 
                        font=('Arial', self.game.scale_font(11)),
                        bg=self.game.current_colors["bg_primary"], 
                        fg=self.game.current_colors["text_primary"],
                        pady=4, wraplength=dialog_width-80, justify=tk.LEFT, anchor='w').pack(fill=tk.X, padx=30)
            elif section['type'] == 'box':
                box_frame = tk.Frame(scroll_frame, bg=self.game.current_colors["bg_panel"], 
                                   relief=tk.RAISED, borderwidth=2)
                box_frame.pack(fill=tk.X, padx=25, pady=8)
                tk.Label(box_frame, text=section['text'], 
                        font=('Arial', self.game.scale_font(11)),
                        bg=self.game.current_colors["bg_panel"], 
                        fg=self.game.current_colors["text_primary"],
                        pady=10, padx=15, wraplength=dialog_width-120, justify=tk.LEFT, anchor='w').pack(fill=tk.X)
            elif section['type'] == 'list':
                list_frame = tk.Frame(scroll_frame, bg=self.game.current_colors["bg_panel"], 
                                     relief=tk.RAISED, borderwidth=2)
                list_frame.pack(fill=tk.X, padx=25, pady=8)
                tk.Label(list_frame, text=section['text'], 
                        font=('Arial', self.game.scale_font(11)),
                        bg=self.game.current_colors["bg_panel"], 
                        fg=self.game.current_colors["text_primary"],
                        pady=10, padx=15, wraplength=dialog_width-120, justify=tk.LEFT, anchor='w').pack(fill=tk.X)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(scroll_frame)
    
    def _get_tutorial_topic_content(self, topic_id):
        """Get tutorial content for a specific topic"""
        content_map = {
            'basics': [
                {'type': 'title', 'text': 'GAME OBJECTIVE'},
                {'type': 'text', 'text': 'Explore the dungeon, defeat enemies, collect loot, and survive as long as possible. Descend through increasingly difficult floors and see how far you can go!'},
                {'type': 'subtitle', 'text': 'How to Win'},
                {'type': 'list', 'text': '• Survive and explore as many rooms as possible\n• Defeat enemies to earn gold and experience\n• Find stairs to descend to deeper floors\n• Collect powerful equipment and items\n• Build your score by exploring and defeating enemies'},
            ],
            'movement': [
                {'type': 'title', 'text': 'EXPLORATION & MOVEMENT'},
                {'type': 'subtitle', 'text': 'How to Move Between Rooms'},
                {'type': 'box', 'text': 'Click the N, S, E, W buttons at the bottom of the screen\nOR use the WASD keyboard keys:\nW = North, A = West, S = South, D = East'},
                {'type': 'list', 'text': '• Each room may contain enemies, loot, chests, or special events\n• Some paths may be blocked - you\'ll see a message if you try to enter\n• Your current position is shown on the minimap as a gold dot'},
                {'type': 'subtitle', 'text': 'Finding and Collecting Loot'},
                {'type': 'box', 'text': 'When you enter a room with loot, buttons appear in the ACTION PANEL:\n• "Open Chest" - Click to open treasure chests\n• "Search" - Click when containers appear on the ground\n• "Pick Up [Item]" - Click to collect specific items'},
                {'type': 'list', 'text': '• Watch your inventory space - you can only carry 10 items by default\n• Some containers may be locked and require a lockpick to open\n• Items left on the ground remain in that room'},
                {'type': 'subtitle', 'text': 'Descending to Deeper Floors'},
                {'type': 'list', 'text': '• Stairs appear randomly in rooms after you\'ve explored a few areas\n• Click the "Descend" button when stairs appear\n• Deeper floors have tougher enemies but better rewards\n• Each floor resets the room layout'},
            ],
            'combat': [
                {'type': 'title', 'text': 'COMBAT SYSTEM'},
                {'type': 'subtitle', 'text': 'Rolling Dice'},
                {'type': 'box', 'text': 'Click the "ROLL" button to roll all unlocked dice.\nYou get 3 rolls per turn - use them wisely!'},
                {'type': 'subtitle', 'text': 'Locking Dice'},
                {'type': 'box', 'text': 'Click on any die to lock or unlock it.\nLocked dice keep their value when you roll again.\nLocked dice show a colored border.'},
                {'type': 'list', 'text': '• Lock high values you want to keep (6s, 5s, or 4s)\n• Unlock and reroll low values to improve your total\n• Plan your locks carefully - you only get 3 rolls per turn!'},
                {'type': 'subtitle', 'text': 'Attacking'},
                {'type': 'box', 'text': 'After rolling, click the "ATTACK" button.\nYour dice total determines how much damage you deal.\nHigher total = more damage to the enemy.'},
                {'type': 'list', 'text': '• Critical hits (10% base chance) deal bonus damage\n• Your weapon adds bonus damage to each attack\n• Watch the enemy\'s dice roll - they attack the same way!'},
                {'type': 'subtitle', 'text': 'Combat Options'},
                {'type': 'box', 'text': 'Use Item: Access potions and combat consumables from your inventory.\nFlee: Escape from combat (costs some gold and ends your turn).'},
                {'type': 'list', 'text': '• Different enemies have different HP, damage, and abilities\n• Some enemies may have special attack patterns\n• Fleeing is strategic - don\'t be afraid to retreat when outmatched'},
            ],
            'inventory': [
                {'type': 'title', 'text': 'INVENTORY MANAGEMENT'},
                {'type': 'subtitle', 'text': 'Opening Your Inventory'},
                {'type': 'box', 'text': 'Click the "INVENTORY" button below the action panel\nOR press the Tab key on your keyboard.'},
                {'type': 'subtitle', 'text': 'Using Consumable Items'},
                {'type': 'box', 'text': '1. Open your inventory\n2. Click on an item to select it (it will highlight)\n3. Click the "USE" button to consume potions or scrolls'},
                {'type': 'list', 'text': '• Some items only work in combat (like attack boosters)\n• Others only work outside of combat (like repair kits)\n• Consumable items disappear after use'},
                {'type': 'subtitle', 'text': 'Equipping Items'},
                {'type': 'box', 'text': '1. Open your inventory\n2. Click on a weapon, armor, or accessory\n3. Click the "EQUIP" button to wear or wield it'},
                {'type': 'list', 'text': '• You can only equip one weapon, one armor piece, and one accessory at a time\n• Equipped items appear in your character stats\n• Equipped items don\'t count toward your inventory limit'},
                {'type': 'subtitle', 'text': 'Dropping Items'},
                {'type': 'box', 'text': 'Select an item → Click the "DROP" button.\nDropped items are left behind in the current room.'},
                {'type': 'subtitle', 'text': 'Inventory Capacity'},
                {'type': 'list', 'text': '• Default capacity: 10 items\n• Increase capacity with backpacks from merchants\n• Equipped items don\'t count toward the limit\n• Manage your space carefully - you can\'t pick up items if full!'},
            ],
            'equipment': [
                {'type': 'title', 'text': 'EQUIPMENT & DURABILITY'},
                {'type': 'subtitle', 'text': 'Equipment Slots'},
                {'type': 'list', 'text': '• Weapon: Increases your attack damage each turn\n• Armor: Reduces damage you take and may increase max HP\n• Accessory: Provides special bonuses (crit chance, rerolls, inventory space)\n• Backpack: Increases your inventory capacity (doesn\'t count as accessory)'},
                {'type': 'subtitle', 'text': 'Understanding Durability'},
                {'type': 'box', 'text': 'Equipment wears down with use.\nWhen durability reaches 0, the item breaks and loses ALL bonuses!'},
                {'type': 'list', 'text': '• Check durability: Click the ☰ menu → Character Info\n• Weapons lose durability when you attack\n• Armor loses durability when you take damage\n• Repair equipment BEFORE it breaks to keep your bonuses active'},
                {'type': 'subtitle', 'text': 'Repairing Equipment'},
                {'type': 'box', 'text': '1. Visit a merchant store (appears randomly in dungeon rooms)\n2. Purchase repair kits from the store\n3. Use repair kits from your inventory to restore durability'},
                {'type': 'list', 'text': '• Weapon Repair Kit: Restores 40% weapon durability\n• Armor Repair Kit: Restores 40% armor durability\n• Master Repair Kit: Restores 60% of any equipment (available on Floor 5+)'},
            ],
            'resources': [
                {'type': 'title', 'text': 'RESOURCES & UPGRADES'},
                {'type': 'subtitle', 'text': 'Gold'},
                {'type': 'list', 'text': '• Earned by defeating enemies in combat\n• Found in chests and containers throughout the dungeon\n• Spent at merchants for items, upgrades, and repairs\n• Lost when fleeing from combat'},
                {'type': 'subtitle', 'text': 'Health Points (HP)'},
                {'type': 'box', 'text': 'Keep your HP above 0 or it\'s GAME OVER!\nHeal using potions or by resting between rooms.'},
                {'type': 'list', 'text': '• Current HP is shown in the top-left corner\n• Heal with health potions from your inventory\n• Rest between rooms to recover HP (see below)\n• Increase max HP with armor or stat upgrades from merchants'},
                {'type': 'subtitle', 'text': 'Resting to Recover'},
                {'type': 'box', 'text': 'Click the "REST" button between rooms to recover HP.\nHealing amount is based on your maximum HP.\nCooldown: You must explore 3 rooms before resting again.'},
                {'type': 'list', 'text': '• Resting is free but has a cooldown\n• Cannot rest during combat\n• Use it strategically before challenging fights\n• The Rest button shows when it\'s available'},
                {'type': 'subtitle', 'text': 'Purchasing Stat Upgrades'},
                {'type': 'box', 'text': '1. Visit a merchant store\n2. Look for upgrade items (Max HP Upgrade, Damage Upgrade, etc.)\n3. Purchase upgrades to increase your stats for THIS RUN ONLY'},
                {'type': 'list', 'text': '• Upgrades only last for the current game session\n• Upgrades reset when you die or start a new game\n• Can purchase multiple upgrades per floor\n• Common upgrades: Max HP, Damage Bonus, Critical Chance, Rerolls'},
                {'type': 'subtitle', 'text': 'Adventure Log'},
                {'type': 'box', 'text': 'The Adventure Log is located at the bottom of the screen.\nIt records all your actions, combat results, and events.'},
                {'type': 'list', 'text': '• Scroll through the log to review past events\n• Different colors indicate different types of messages\n• Combat details, loot found, and damage taken are all recorded\n• Use it to track what happened in previous rooms'},
            ],
            'keys': [
                {'type': 'title', 'text': 'KEYS & SPECIAL ROOMS'},
                {'type': 'subtitle', 'text': 'Old Keys (Mini-Boss Rooms)'},
                {'type': 'list', 'text': '• Find Old Keys in chests and containers\n• Old Keys unlock elite difficulty mini-boss rooms\n• Mini-bosses are significantly tougher than normal enemies\n• Defeating mini-bosses rewards you with key fragments'},
                {'type': 'subtitle', 'text': 'Key Fragments (Boss Rooms)'},
                {'type': 'box', 'text': 'Collect 3 Key Fragments to unlock a Boss Room.\nFragments automatically combine when you have all 3.'},
                {'type': 'list', 'text': '• Boss rooms contain the floor\'s toughest enemy\n• Bosses have much higher HP and damage\n• Defeating bosses grants the best loot and rewards\n• Only one boss room appears per floor'},
                {'type': 'subtitle', 'text': 'Using Keys'},
                {'type': 'box', 'text': '1. Move toward a locked room (shown with a door icon on the map)\n2. A dialog appears asking if you want to use your key\n3. Click "Yes" to unlock and enter, or "No" to save the key for later'},
                {'type': 'box', 'text': '⚠️ PREPARE WELL BEFORE ENTERING!\nMake sure you have: Full HP, Good Equipment, Healing Potions'},
                {'type': 'list', 'text': '• Keys are consumed when used\n• You cannot leave once combat starts\n• Mini-bosses and bosses don\'t respawn after defeat\n• Plan your approach carefully'},
            ],
            'stores': [
                {'type': 'title', 'text': 'MERCHANTS & STORES'},
                {'type': 'subtitle', 'text': 'Finding Merchants'},
                {'type': 'list', 'text': '• Stores appear randomly as you explore the dungeon\n• When you enter a room with a merchant, a "STORE" button appears in the ACTION PANEL\n• Each floor typically has at least one store\n• Store inventory is consistent throughout the entire floor'},
                {'type': 'subtitle', 'text': 'Shopping for Items'},
                {'type': 'box', 'text': '1. Click the "STORE" button when available\n2. Browse the BUY tab for items, upgrades, and repair kits\n3. Click on an item to select it\n4. Click the "BUY" button to purchase (if you have enough gold)'},
                {'type': 'subtitle', 'text': 'Store Tabs'},
                {'type': 'list', 'text': '• BUY Tab: Purchase items, weapons, armor, potions, and upgrades\n• SELL Tab: Sell unwanted items from your inventory for gold'},
                {'type': 'subtitle', 'text': 'What You Can Buy'},
                {'type': 'list', 'text': '• Weapons & Armor: Better equipment for improved combat performance\n• Potions & Consumables: Healing items and combat boosters\n• Repair Kits: Restore equipment durability\n• Stat Upgrades: Temporary boosts for current run\n• Accessories: Special items with unique bonuses (inventory space, crit chance, etc.)'},
                {'type': 'subtitle', 'text': 'Selling Items'},
                {'type': 'box', 'text': '1. Open the store\n2. Click the "SELL" tab\n3. Select an item from your inventory\n4. Click the "SELL" button to receive gold'},
                {'type': 'list', 'text': '• Sell price is typically 60% of the purchase price\n• Selling is useful for clearing inventory space\n• Sell duplicate or outdated equipment'},
            ],
            'menus': [
                {'type': 'title', 'text': 'MENUS & INFORMATION'},
                {'type': 'subtitle', 'text': 'Opening the Menu'},
                {'type': 'box', 'text': 'Click the ☰ button in the top-right corner\nOR press the M key on your keyboard'},
                {'type': 'subtitle', 'text': 'Character Info'},
                {'type': 'box', 'text': 'In the menu, click "Character Info" to view:\n• All your current stats and bonuses\n• Equipped items and their durability\n• Active status effects\n• Overall character progression'},
                {'type': 'list', 'text': '• Check equipment durability regularly\n• See all stat bonuses from items and upgrades\n• Monitor active buffs and debuffs\n• Track your current build'},
                {'type': 'subtitle', 'text': 'Lore Codex'},
                {'type': 'box', 'text': 'In the menu, click "Lore Codex" to access:\n• All lore items you\'ve discovered\n• Story fragments and world building\n• Character backgrounds and histories\n• Item descriptions and flavor text'},
                {'type': 'list', 'text': '• Find lore items scattered throughout the dungeon\n• Read them to learn about the game world\n• Collect all entries for the complete story\n• Lore is organized by category'},
                {'type': 'subtitle', 'text': 'Settings'},
                {'type': 'box', 'text': 'In the menu, click "Settings" to adjust:\n• Difficulty level\n• Color scheme\n• Text speed\n• Keyboard controls'},
                {'type': 'subtitle', 'text': 'Save/Load Game'},
                {'type': 'list', 'text': '• Save Game: Store your progress in one of 3 save slots\n• Load Game: Resume from a previously saved game\n• Each save slot is independent\n• Save frequently to avoid losing progress!'},
            ],
            'controls': [
                {'type': 'title', 'text': 'CONTROLS & SHORTCUTS'},
                {'type': 'subtitle', 'text': 'Menu Buttons'},
                {'type': 'list', 'text': '• ☰ Button (top-right): Opens pause menu with Save, Load, Settings, and Quit options\n• ? Button (top-right): Shows keybindings reference\n• ✕ Button: Closes dialogs and menus'},
                {'type': 'subtitle', 'text': 'Movement Controls'},
                {'type': 'box', 'text': 'WASD Keys or N/S/E/W Buttons:\nW or N = Move North\nA or W = Move West\nS or S = Move South\nD or E = Move East'},
                {'type': 'subtitle', 'text': 'Action Shortcuts (Default Keybindings)'},
                {'type': 'list', 'text': '• Tab: Open or close Inventory\n• R: Rest (when available and off cooldown)\n• M: Open the pause Menu\n• L: Toggle Adventure Log (expand/collapse the bottom log panel)\n• Escape: Close dialogs and menus'},
                {'type': 'subtitle', 'text': 'Saving Your Game'},
                {'type': 'box', 'text': '1. Click the ☰ menu button (top-right)\n2. Select "Save Game" from the menu\n3. Choose a save slot (1, 2, or 3)\n4. Your progress is automatically saved!'},
                {'type': 'list', 'text': '• Save frequently to avoid losing progress\n• You can maintain up to 3 separate save files\n• Each save slot is independent'},
                {'type': 'subtitle', 'text': 'Customizing Keybindings'},
                {'type': 'box', 'text': '1. Click ☰ menu → Settings\n2. Navigate to the Keybindings tab\n3. Click on any control to reassign its key'},
                {'type': 'subtitle', 'text': 'Quick Reference Guide'},
                {'type': 'list', 'text': '• Move: WASD keys or N/S/E/W buttons\n• Combat: Roll dice → Lock good values → Roll again → Attack\n• Loot: Click Search, Pick Up, or Open Chest buttons\n• Heal: Click Rest button (3-room cooldown) or use health potions\n• Inventory: Press Tab key or click Inventory button\n• Save: ☰ menu → Save Game → Choose slot'},
            ],
        }
        
        return content_map.get(topic_id, [
            {'type': 'title', 'text': 'Topic Not Found'},
            {'type': 'text', 'text': 'This tutorial section is currently unavailable.'}
        ])
