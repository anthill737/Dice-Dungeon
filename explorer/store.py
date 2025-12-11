"""
Store Management Module

This module handles all store/shop functionality for the Dice Dungeon game,
including buying/selling items, generating store inventory, and price calculations.
"""

import tkinter as tk
import random
from collections import Counter


class StoreManager:
    """Manages the in-game store interface and transactions"""
    
    def __init__(self, game):
        """
        Initialize the StoreManager.
        
        Args:
            game: Reference to the main DiceDungeonExplorer instance
        """
        self.game = game
    
    def show_store(self, active_tab='buy'):
        """Display the store interface"""
        # Close existing dialog if any
        if self.game.dialog_frame and self.game.dialog_frame.winfo_exists():
            self.game.dialog_frame.destroy()
        
        # Generate store inventory once per floor (not per visit or tab switch)
        # This ensures consistent store offerings throughout the entire floor
        if not hasattr(self.game, 'floor_store_inventory') or self.game.floor_store_inventory is None:
            self.game.floor_store_inventory = self._generate_store_inventory()
        
        # Create dialog
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(700, 600, 0.7, 0.8)
        
        self.game.dialog_frame = tk.Frame(self.game.game_frame, bg=self.game.current_colors["bg_panel"], 
                                      relief=tk.RIDGE, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor='center', 
                                width=dialog_width, height=dialog_height)
        
        # Grab focus and bind ESC to close
        self.game.dialog_frame.focus_set()
        self.game.dialog_frame.bind('<Escape>', lambda e: self.game.close_dialog() or "break")
        
        # Title
        tk.Label(self.game.dialog_frame, text="◘ MERCHANT'S SHOP", 
                font=('Arial', 20, 'bold'), bg=self.game.current_colors["bg_panel"], 
                fg=self.game.current_colors["text_gold"], pady=10).pack()
        
        tk.Label(self.game.dialog_frame, text=f"Your Gold: {self.game.gold}", 
                font=('Arial', 12, 'bold'), bg=self.game.current_colors["bg_panel"], 
                fg=self.game.current_colors["text_gold"], pady=5).pack()
        
        # Create notebook for tabs
        notebook = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_panel"])
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Tab buttons
        tab_frame = tk.Frame(notebook, bg=self.game.current_colors["bg_panel"])
        tab_frame.pack(fill=tk.X, pady=5)
        
        # Container for tab content
        content_frame = tk.Frame(notebook, bg=self.game.current_colors["bg_panel"])
        content_frame.pack(fill=tk.BOTH, expand=True)
        
        # State to track current tab
        current_tab = {'value': active_tab}
        
        def show_buy_tab():
            current_tab['value'] = 'buy'
            buy_btn.config(bg=self.game.current_colors["text_gold"], fg='#000000')
            sell_btn.config(bg=self.game.current_colors["bg_dark"], fg='#ffffff')
            self._show_store_buy_content(content_frame)
        
        def show_sell_tab():
            current_tab['value'] = 'sell'
            buy_btn.config(bg=self.game.current_colors["bg_dark"], fg='#ffffff')
            sell_btn.config(bg=self.game.current_colors["text_gold"], fg='#000000')
            self._show_store_sell_content(content_frame)
        
        buy_btn = tk.Button(tab_frame, text="BUY", command=show_buy_tab,
                           font=('Arial', 12, 'bold'), bg=self.game.current_colors["text_gold"], 
                           fg='#000000', width=15, pady=5)
        buy_btn.pack(side=tk.LEFT, padx=5)
        
        sell_btn = tk.Button(tab_frame, text="SELL", command=show_sell_tab,
                            font=('Arial', 12, 'bold'), bg=self.game.current_colors["bg_dark"], 
                            fg='#ffffff', width=15, pady=5)
        sell_btn.pack(side=tk.LEFT, padx=5)
        
        # Close button
        tk.Button(self.game.dialog_frame, text="Leave Store", command=self.game.close_dialog,
                 font=('Arial', 11, 'bold'), bg=self.game.current_colors["button_secondary"], 
                 fg='#000000', width=15, pady=8).pack(pady=10)
        
        # Show the requested tab
        if active_tab == 'sell':
            show_sell_tab()
        else:
            show_buy_tab()
    
    def _show_store_buy_content(self, parent):
        """Show the buy tab content"""
        # Clear parent
        for widget in parent.winfo_children():
            widget.destroy()
        
        # Create scrollable area
        canvas = tk.Canvas(parent, bg=self.game.current_colors["bg_primary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(parent, orient="vertical", command=canvas.yview, width=10)
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
        
        # Use the floor's store inventory (generated once per floor)
        store_items = self.game.floor_store_inventory
        
        tk.Label(scroll_frame, text="Available Items:", font=('Arial', 12, 'bold'),
                bg=self.game.current_colors["bg_primary"], fg=self.game.current_colors["text_cyan"],
                pady=10).pack()
        
        # Display items
        for item_name, price in store_items:
            self._create_store_item_row(scroll_frame, item_name, price, is_buying=True)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(scroll_frame)
    
    def _show_store_sell_content(self, parent):
        """Show the sell tab content"""
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
        
        tk.Label(scroll_frame, text="Your Inventory:", font=('Arial', 12, 'bold'),
                bg=self.game.current_colors["bg_primary"], fg=self.game.current_colors["text_cyan"],
                pady=10).pack()
        
        if not self.game.inventory:
            tk.Label(scroll_frame, text="(Empty)", font=('Arial', 11),
                    bg=self.game.current_colors["bg_primary"], fg=self.game.current_colors["text_secondary"],
                    pady=20).pack()
        else:
            # Count duplicate items
            item_counts = Counter(self.game.inventory)
            
            # Track which items we've already processed
            processed_items = set()
            
            # Display inventory items with sell price (stacked)
            for idx, item_name in enumerate(self.game.inventory):
                # Skip if we've already displayed this item
                if item_name in processed_items:
                    continue
                processed_items.add(item_name)
                
                sell_price = self._calculate_sell_price(item_name)
                count = item_counts[item_name]
                
                # Create stacked item display with count
                self._create_store_item_row(scroll_frame, item_name, sell_price, is_buying=False, item_idx=idx, item_count=count)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(scroll_frame)
    
    def _generate_store_inventory(self):
        """Generate store inventory based on floor level - all items shown (no randomization)"""
        store_items = []
        
        # ESSENTIALS - Always available
        store_items.append(("Health Potion", 30 + (self.game.floor * 5)))
        
        # REPAIR KITS - Always available from floor 1+ (CRITICAL for equipment durability)
        store_items.append(("Weapon Repair Kit", 60 + (self.game.floor * 15)))  # Restore 40% weapon durability
        store_items.append(("Armor Repair Kit", 60 + (self.game.floor * 15)))   # Restore 40% armor durability
        
        if self.game.floor >= 5:
            store_items.append(("Master Repair Kit", 120 + (self.game.floor * 30)))  # Restore 60% any equipment
        
        # PERMANENT UPGRADES - Always shown but expensive (unless already purchased this floor)
        upgrades = [
            ("Max HP Upgrade", 400 + (self.game.floor * 100)),  # +10 max HP - very expensive
            ("Damage Upgrade", 500 + (self.game.floor * 120)),  # +1 permanent damage - most expensive
            ("Fortune Upgrade", 450 + (self.game.floor * 110)), # +1 permanent reroll
        ]
        if self.game.floor >= 2:
            upgrades.append(("Critical Upgrade", 200 + (self.game.floor * 50)))  # +2% permanent crit
        
        # Filter out upgrades already purchased on this floor and add all available
        available_upgrades = [(name, price) for name, price in upgrades if name not in self.game.purchased_upgrades_this_floor]
        store_items.extend(available_upgrades)
        
        # CONSUMABLES - Show ALL consumables for current floor tier
        if self.game.floor >= 1:
            store_items.extend([
                ("Lucky Chip", 70 + (self.game.floor * 15)),
                ("Honey Jar", 20 + (self.game.floor * 4)),
                ("Healing Poultice", 50 + (self.game.floor * 10)),
            ])
        
        if self.game.floor >= 2:
            store_items.extend([
                ("Weighted Die", 60 + (self.game.floor * 15)),
                ("Lockpick Kit", 50 + (self.game.floor * 10)),
                ("Conductor Rod", 70 + (self.game.floor * 15)),
            ])
        
        if self.game.floor >= 3:
            store_items.extend([
                ("Hourglass Shard", 80 + (self.game.floor * 20)),
                ("Tuner's Hammer", 85 + (self.game.floor * 22)),
                ("Antivenom Leaf", 40 + (self.game.floor * 10)),
            ])
        
        if self.game.floor >= 4:
            store_items.extend([
                ("Cooled Ember", 90 + (self.game.floor * 23)),
                ("Smoke Pot", 55 + (self.game.floor * 12)),
                ("Black Candle", 65 + (self.game.floor * 15)),
            ])
        
        # EQUIPMENT - Weapons, Armor, Accessories (ALL items shown for floor)
        # Weapons (damage bonuses)
        if self.game.floor >= 1:
            store_items.extend([
                ("Iron Sword", 120 + (self.game.floor * 30)),      # +4 damage
                ("Steel Dagger", 100 + (self.game.floor * 25)),    # +2 damage
            ])
        
        if self.game.floor >= 2:
            store_items.extend([
                ("War Axe", 220 + (self.game.floor * 50)),         # +5 damage
                ("Rapier", 160 + (self.game.floor * 35)),          # +3 damage, +6% crit
            ])
        
        if self.game.floor >= 4:
            store_items.extend([
                ("Greatsword", 280 + (self.game.floor * 60)),      # +6 damage
                ("Assassin's Blade", 260 + (self.game.floor * 55)), # +3 damage, +8% crit
            ])
        
        # Armor (HP and defense)
        if self.game.floor >= 1:
            store_items.extend([
                ("Leather Armor", 110 + (self.game.floor * 28)),   # +15 max HP
                ("Chain Vest", 130 + (self.game.floor * 32)),      # +10 max HP, +1 armor
            ])
        
        if self.game.floor >= 3:
            store_items.extend([
                ("Plate Armor", 220 + (self.game.floor * 50)),     # +25 max HP, +2 armor
                ("Dragon Scale", 300 + (self.game.floor * 65)),    # +30 max HP, +3 armor
            ])
        
        # Accessories (special bonuses)
        if self.game.floor >= 1:
            store_items.append(("Traveler's Pack", 100 + (self.game.floor * 25))) # +5 inventory
        
        if self.game.floor >= 2:
            store_items.extend([
                ("Lucky Coin", 140 + (self.game.floor * 35)),      # +5% crit
                ("Mystic Ring", 150 + (self.game.floor * 38)),     # +1 reroll per combat
                ("Merchant's Satchel", 180 + (self.game.floor * 40)), # +10 inventory
                ("Extra Die", 500 + (self.game.floor * 50))        # Add extra die to rolls
            ])
        
        if self.game.floor >= 4:
            store_items.extend([
                ("Crown of Fortune", 250 + (self.game.floor * 55)), # +10% crit
                ("Timekeeper's Watch", 270 + (self.game.floor * 58)), # +2 rerolls per combat
            ])
        
        # VALUABLES/UTILITY
        if self.game.floor >= 3:
            store_items.extend([
                ("Blue Quartz", 90 + (self.game.floor * 20)),
                ("Silk Bundle", 120 + (self.game.floor * 30))
            ])
        
        return store_items
    
    def _calculate_sell_price(self, item_name):
        """Calculate sell price for an item (50% of buy price from store)"""
        # Calculate what the buy price would be in the store
        buy_price = 0
        
        # Match the store pricing logic for consumables
        if item_name == "Health Potion":
            buy_price = 30 + (self.game.floor * 5)
        elif item_name == "Extra Die":
            buy_price = 100 + (self.game.floor * 20)
        elif item_name == "Lucky Chip":
            buy_price = 70 + (self.game.floor * 15)
        elif item_name == "Honey Jar":
            buy_price = 20 + (self.game.floor * 4)
        elif item_name == "Healing Poultice":
            buy_price = 50 + (self.game.floor * 10)
        elif item_name == "Weighted Die":
            buy_price = 60 + (self.game.floor * 15)
        elif item_name == "Lockpick Kit":
            buy_price = 50 + (self.game.floor * 10)
        elif item_name == "Conductor Rod":
            buy_price = 70 + (self.game.floor * 15)
        elif item_name == "Hourglass Shard":
            buy_price = 80 + (self.game.floor * 20)
        elif item_name == "Tuner's Hammer":
            buy_price = 85 + (self.game.floor * 22)
        elif item_name == "Cooled Ember":
            buy_price = 90 + (self.game.floor * 23)
        elif item_name == "Blue Quartz":
            buy_price = 90 + (self.game.floor * 20)
        elif item_name == "Silk Bundle":
            buy_price = 120 + (self.game.floor * 30)
        elif item_name == "Disarm Token":
            buy_price = 150
        elif item_name == "Antivenom Leaf":
            buy_price = 40 + (self.game.floor * 10)
        elif item_name == "Smoke Pot":
            buy_price = 55 + (self.game.floor * 12)
        elif item_name == "Black Candle":
            buy_price = 65 + (self.game.floor * 15)
        
        # Equipment prices
        elif item_name == "Iron Sword":
            buy_price = 120 + (self.game.floor * 30)
        elif item_name == "Steel Dagger":
            buy_price = 100 + (self.game.floor * 25)
        elif item_name == "War Axe":
            buy_price = 180 + (self.game.floor * 40)
        elif item_name == "Rapier":
            buy_price = 160 + (self.game.floor * 35)
        elif item_name == "Greatsword":
            buy_price = 280 + (self.game.floor * 60)
        elif item_name == "Assassin's Blade":
            buy_price = 260 + (self.game.floor * 55)
        elif item_name == "Leather Armor":
            buy_price = 110 + (self.game.floor * 28)
        elif item_name == "Chain Vest":
            buy_price = 130 + (self.game.floor * 32)
        elif item_name == "Plate Armor":
            buy_price = 220 + (self.game.floor * 50)
        elif item_name == "Dragon Scale":
            buy_price = 300 + (self.game.floor * 65)
        elif item_name == "Traveler's Pack":
            buy_price = 100 + (self.game.floor * 25)
        elif item_name == "Merchant's Satchel":
            buy_price = 180 + (self.game.floor * 40)
        elif item_name == "Lucky Coin":
            buy_price = 140 + (self.game.floor * 35)
        elif item_name == "Mystic Ring":
            buy_price = 150 + (self.game.floor * 38)
        elif item_name == "Crown of Fortune":
            buy_price = 250 + (self.game.floor * 55)
        elif item_name == "Timekeeper's Watch":
            buy_price = 270 + (self.game.floor * 58)
        
        else:
            # For items not explicitly listed, check if they have a direct sell_value
            if item_name in self.game.item_definitions:
                item_data = self.game.item_definitions[item_name]
                
                # Prioritize explicit sell_value from item definition
                if 'sell_value' in item_data:
                    return item_data['sell_value']
                
                # Otherwise check rarity
                rarity = item_data.get('rarity', 'common').lower()
                
                # Base prices by rarity
                base_prices = {
                    'common': 30,
                    'uncommon': 60,
                    'rare': 120,
                    'epic': 250,
                    'legendary': 500
                }
                buy_price = base_prices.get(rarity, 30)
            else:
                buy_price = 20
        
        # Sell for 50% of buy price
        return max(5, buy_price // 2)
    
    def _create_store_item_row(self, parent, item_name, price, is_buying=True, item_idx=None, item_count=1):
        """Create a row for a store item"""
        item_frame = tk.Frame(parent, bg=self.game.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=1)
        item_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Container to prevent overflow
        container = tk.Frame(item_frame, bg=self.game.current_colors["bg_panel"])
        container.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Left side - Item info (with weight to take up more space)
        info_frame = tk.Frame(container, bg=self.game.current_colors["bg_panel"])
        info_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
        
        # Item name with count if selling multiple
        count_text = f" x{item_count}" if item_count > 1 and not is_buying else ""
        name_label = tk.Label(info_frame, text=f"{item_name}{count_text}", font=('Arial', 11, 'bold'),
                             bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_primary"],
                             anchor='w')
        name_label.pack(anchor='w', fill=tk.X)
        
        # Item description if available - always show for store items
        desc = ""
        if item_name in self.game.item_definitions:
            desc = self.game.item_definitions[item_name].get('desc', '')
        
        # Add default descriptions for store-specific items not in definitions
        if not desc:
            if item_name == "Extra Die":
                desc = "Permanently adds one more die to your dice pool"
        
        if desc:
            desc_label = tk.Label(info_frame, text=desc, 
                    font=('Arial', 9), bg=self.game.current_colors["bg_panel"], 
                    fg=self.game.current_colors["text_secondary"], anchor='w',
                    wraplength=350, justify=tk.LEFT)
            desc_label.pack(anchor='w', fill=tk.X, pady=(2, 0))
        
        # Right side - Price and button
        action_frame = tk.Frame(container, bg=self.game.current_colors["bg_panel"])
        action_frame.pack(side=tk.RIGHT, padx=5)
        
        tk.Label(action_frame, text=f"{price}g", font=('Arial', 11, 'bold'),
                bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_gold"]).pack()
        
        if is_buying:
            # Buy button
            can_afford = self.game.gold >= price
            
            # Check item type to determine if inventory space is needed
            item_def = self.game.item_definitions.get(item_name, {})
            item_type = item_def.get('type', '')
            
            # Upgrades don't need inventory space
            needs_inventory = item_type not in ['upgrade']
            can_carry = self.game.get_unequipped_inventory_count() < self.game.max_inventory if needs_inventory else True
            
            # For Extra Die, check if already at max
            if item_name == "Extra Die" and self.game.num_dice >= self.game.max_dice:
                btn_state = tk.DISABLED
                btn_text = "Max Dice"
            elif not can_afford:
                btn_state = tk.DISABLED
                btn_text = "Can't Afford"
            elif needs_inventory and not can_carry:
                btn_state = tk.DISABLED
                btn_text = "Inv. Full"
            else:
                btn_state = tk.NORMAL
                btn_text = "Buy"
            
            tk.Button(action_frame, text=btn_text, 
                     command=lambda: self._buy_item(item_name, price),
                     font=('Arial', 9, 'bold'), bg=self.game.current_colors["button_primary"], 
                     fg='#000000', width=10, pady=5, state=btn_state).pack(pady=3)
        else:
            # Sell button
            tk.Button(action_frame, text="Sell", 
                     command=lambda: self._sell_item(item_idx, price),
                     font=('Arial', 9, 'bold'), bg=self.game.current_colors["text_purple"], 
                     fg='#ffffff', width=10, pady=5).pack(pady=3)
    
    def _buy_item(self, item_name, price):
        """Purchase an item from the store"""
        if self.game.gold < price:
            self.game.log("Not enough gold!", 'system')
            return
        
        # Check if this is an upgrade or equipment (doesn't go to inventory)
        item_def = self.game.item_definitions.get(item_name, {})
        item_type = item_def.get('type', '')
        
        # Handle PERMANENT UPGRADES
        if item_type == "upgrade":
            # Apply permanent stat increases
            if 'max_hp_bonus' in item_def:
                bonus = item_def['max_hp_bonus']
                self.game.max_health += bonus
                self.game.health += bonus  # Also restore that much HP
                self.game.log(f"[UPGRADE] Maximum HP increased by {bonus}! (Now {self.game.max_health})", 'success')
            
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.game.damage_bonus += bonus
                self.game.log(f"[UPGRADE] Permanent damage increased by {bonus}! (Now +{self.game.damage_bonus})", 'success')
            
            if 'reroll_bonus' in item_def:
                bonus = item_def['reroll_bonus']
                self.game.reroll_bonus += bonus
                self.game.log(f"[UPGRADE] Permanent rerolls increased by {bonus}! (Now +{self.game.reroll_bonus})", 'success')
            
            if 'crit_bonus' in item_def:
                bonus = item_def['crit_bonus']
                self.game.crit_chance += bonus
                self.game.log(f"[UPGRADE] Crit chance increased by {int(bonus*100)}%! (Now {int(self.game.crit_chance*100)}%)", 'success')
            
            # Track that this upgrade was purchased on this floor
            self.game.purchased_upgrades_this_floor.add(item_name)
            
            self.game.gold -= price
            
            # Track stats
            self.game.stats["gold_spent"] += price
            self.game.stats["items_purchased"] += 1
            
            self.game.update_display()
            self.show_store()
            return
        
        # Handle EQUIPMENT (goes to inventory, can be equipped)
        if item_type == "equipment":
            if self.game.get_unequipped_inventory_count() >= self.game.max_inventory:
                self.game.log("Inventory is full! (Equipped items don't count)", 'system')
                return
            
            self.game.inventory.append(item_name)
            
            # Initialize durability for newly purchased equipment
            max_dur = item_def.get('max_durability', 100)
            self.game.equipment_durability[item_name] = max_dur
            
            # Track floor level for scaling bonuses
            self.game.equipment_floor_level[item_name] = self.game.floor
            
            slot = item_def.get('slot', 'unknown')
            self.game.log(f"Purchased {item_name}! (Equip it from inventory for {slot} slot)", 'loot')
            
            self.game.gold -= price
            
            # Track stats
            self.game.stats["gold_spent"] += price
            self.game.stats["items_purchased"] += 1
            
            self.game.update_display()
            self.show_store()
            return
        
        # Handle Extra Die
        if item_name == "Extra Die":
            if self.game.num_dice >= self.game.max_dice:
                self.game.log(f"You already have the maximum {self.game.max_dice} dice!", 'system')
                return
            self.game.num_dice += 1
            self.game.dice_values = [0] * self.game.num_dice
            self.game.dice_locked = [False] * self.game.num_dice
            self.game.log(f"Purchased {item_name}! Now have {self.game.num_dice} dice.", 'loot')
            
            # Track that this upgrade was purchased on this floor
            self.game.purchased_upgrades_this_floor.add(item_name)
            
            self.game.gold -= price
            
            # Track stats
            self.game.stats["gold_spent"] += price
            self.game.stats["items_purchased"] += 1
            
            self.game.update_display()
            self.show_store()
            return
        
        # All other items (consumables) go to inventory
        if self.game.get_unequipped_inventory_count() >= self.game.max_inventory:
            self.game.log("Inventory is full! (Equipped items don't count)", 'system')
            return
        
        self.game.inventory.append(item_name)
        self.game.log(f"Purchased {item_name}!", 'loot')
        
        self.game.gold -= price
        
        # Track stats
        self.game.stats["gold_spent"] += price
        self.game.stats["items_purchased"] += 1
        
        self.game.update_display()
        
        # Refresh store display
        self.show_store()
    
    def _sell_item(self, item_idx, price):
        """Sell an item from inventory"""
        if item_idx >= len(self.game.inventory):
            return
        
        item_name = self.game.inventory[item_idx]
        item_def = self.game.item_definitions.get(item_name, {})
        item_type = item_def.get('type', '')
        
        # Check if item is equipped AND it's the only copy
        # If you have multiple copies, you can sell the unequipped ones
        item_count = self.game.inventory.count(item_name)
        is_equipped = item_name in self.game.equipped_items.values()
        
        if is_equipped and item_count == 1:
            self.game.log(f"Cannot sell equipped item! Unequip {item_name} first.", 'system')
            return
        
        # Handle quest items (bounty posters) with special rewards
        if item_type == 'quest_item':
            quest_reward = item_def.get('gold_reward', price)
            self.game.inventory.pop(item_idx)
            self.game.gold += quest_reward
            self.game.total_gold_earned += quest_reward
            self.game.log(f"Turned in {item_name}! Claimed {quest_reward} gold reward!", 'success')
        else:
            # Normal item sale
            self.game.inventory.pop(item_idx)
            self.game.gold += price
            self.game.total_gold_earned += price
            
            # Track stats
            self.game.stats["items_sold"] += 1
            
            self.game.log(f"Sold {item_name} for {price} gold!", 'loot')
        
        self.game.update_display()
        
        # Refresh store display - stay on sell tab
        self.show_store(active_tab='sell')
