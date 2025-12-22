"""
Inventory Pickup Manager - Part 3 of Inventory System

Handles all item pickup and container interactions:
- Search containers and show loot
- Pick up ground gold
- Pick up ground items
- Pick up uncollected items (left behind)
- Pick up dropped items
- Container contents dialogs and "Take All"
"""

import tkinter as tk
import random


class InventoryPickupManager:
    """Manages item pickup and container searching"""
    
    def __init__(self, game):
        """Initialize with reference to main game instance"""
        self.game = game
    
    def use_lockpick_on_container(self, container_name):
        """Use Lockpick Kit to unlock a locked container"""
        # Check if player has lockpick kit
        if "Lockpick Kit" not in self.game.inventory:
            self.game.log("You don't have a Lockpick Kit!", 'system')
            return
        
        # Remove lockpick kit from inventory
        self.game.inventory.remove("Lockpick Kit")
        
        # Unlock the container
        self.game.current_room.container_locked = False
        
        # Track stats
        self.game.stats["items_used"] += 1
        
        self.game.log(f"🔓 Used Lockpick Kit! The {container_name} is now unlocked.", 'success')
        
        # Refresh the ground items display to show unlocked container
        self.game.close_dialog()
        self.game.show_ground_items()
    
    def search_container(self, container_name):
        """Open container and show submenu with its contents"""
        # Get container definition
        if container_name not in self.game.container_definitions:
            self.game.log(f"[SEARCH] You can't figure out how to open the {container_name}.", 'system')
            return
        
        # Check if container is locked
        if self.game.current_room.container_locked:
            self.game.log(f"The {container_name} is locked! You need a Lockpick Kit to open it.", 'system')
            return
        
        # Check if this is first time opening container
        first_time_opening = not self.game.current_room.container_searched
        
        # Mark container as searched
        self.game.current_room.container_searched = True
        
        # Track stats only on first opening
        if first_time_opening:
            self.game.stats["containers_searched"] += 1
            self.game.chests_opened += 1
        
        container = self.game.container_definitions[container_name]
        loot_table = container["loot_table"]
        weights = container["weights"]
        loot_pools = container["loot_pools"]
        
        # Check if container already has rolled contents (player re-opened it)
        if self.game.current_room.container_gold > 0 or self.game.current_room.container_item is not None:
            # Use existing contents
            found_gold = self.game.current_room.container_gold
            found_item = self.game.current_room.container_item
        else:
            # Roll for loot - can get gold, item, both, or nothing
            # Adjusted weights: 15% nothing, 35% gold only, 30% item only, 20% both
            loot_roll = random.random()
            
            found_gold = 0
            found_item = None
            
            if loot_roll < 0.15:
                # Nothing
                pass
            elif loot_roll < 0.50:
                # Gold only
                gold_data = loot_pools.get("gold", {"min": 5, "max": 15})
                found_gold = random.randint(gold_data["min"], gold_data["max"])
                self.game.stats["gold_found"] += found_gold
            elif loot_roll < 0.80:
                # Item only
                # Pick a random loot category (excluding "gold" and "nothing")
                item_categories = [cat for cat in loot_table if cat not in ["gold", "nothing"]]
                if item_categories:
                    category = random.choice(item_categories)
                    item_pool = loot_pools.get(category, [])
                    if item_pool:
                        found_item = random.choice(item_pool)
                        self.game.stats["items_found"] += 1
            else:
                # Both gold and item
                gold_data = loot_pools.get("gold", {"min": 5, "max": 15})
                found_gold = random.randint(gold_data["min"], gold_data["max"])
                self.game.stats["gold_found"] += found_gold
                
                item_categories = [cat for cat in loot_table if cat not in ["gold", "nothing"]]
                if item_categories:
                    category = random.choice(item_categories)
                    item_pool = loot_pools.get(category, [])
                    if item_pool:
                        found_item = random.choice(item_pool)
                        self.game.stats["items_found"] += 1
            
            # Store contents on room so they persist if not taken
            self.game.current_room.container_gold = found_gold
            self.game.current_room.container_item = found_item
        
        # Show container contents submenu
        self.show_container_contents(container_name, found_gold, found_item)
    
    def show_container_contents(self, container_name, gold_amount, item_found):
        """Show submenu displaying what's inside the opened container"""
        if self.game.dialog_frame:
            self.game.dialog_frame.destroy()
        
        # Store current container state
        self.game.current_container_gold = gold_amount
        self.game.current_container_item = item_found
        self.game.current_container_name = container_name
        
        # Responsive sizing
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(400, 350)
        
        self.game.dialog_frame = tk.Frame(self.game.root, bg=self.game.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Bind Escape key to close dialog
        self.game.dialog_frame.bind('<Escape>', lambda e: self.close_container_and_refresh() or "break")
        
        # Title
        title_label = tk.Label(self.game.dialog_frame, text=f"▢ {container_name.upper()} ▢", 
                              font=('Arial', 14, 'bold'),
                              bg=self.game.current_colors["bg_primary"], 
                              fg=self.game.current_colors["text_gold"])
        title_label.pack(pady=15)
        
        # Container description
        container_def = self.game.container_definitions.get(container_name, {})
        description = container_def.get('description', 'You open the container...')
        tk.Label(self.game.dialog_frame, text=description,
                font=('Arial', 10),
                bg=self.game.current_colors["bg_primary"],
                fg=self.game.current_colors["text_secondary"],
                wraplength=350).pack(pady=10)
        
        # Contents frame
        contents_frame = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_secondary"], relief=tk.SUNKEN, borderwidth=2)
        contents_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        # Check if empty
        if gold_amount == 0 and item_found is None:
            tk.Label(contents_frame, text="The container is empty.",
                    font=('Arial', 12, 'italic'),
                    bg=self.game.current_colors["bg_secondary"],
                    fg=self.game.current_colors["text_secondary"]).pack(expand=True)
        else:
            tk.Label(contents_frame, text="You found:",
                    font=('Arial', 11, 'bold'),
                    bg=self.game.current_colors["bg_secondary"],
                    fg=self.game.current_colors["text_cyan"]).pack(pady=10)
            
            # Show gold
            if gold_amount > 0:
                gold_frame = tk.Frame(contents_frame, bg=self.game.current_colors["bg_dark"])
                gold_frame.pack(fill=tk.X, padx=15, pady=5)
                
                tk.Label(gold_frame, text=f"◉ {gold_amount} Gold",
                        font=('Arial', 11, 'bold'),
                        bg=self.game.current_colors["bg_dark"],
                        fg=self.game.current_colors["text_gold"]).pack(side=tk.LEFT, padx=10, pady=8)
                
                tk.Button(gold_frame, text="Take",
                         command=self.take_container_gold,
                         font=('Arial', 9), bg=self.game.current_colors["text_gold"],
                         fg='#000000', width=8).pack(side=tk.RIGHT, padx=10, pady=5)
            
            # Show item
            if item_found:
                item_frame = tk.Frame(contents_frame, bg=self.game.current_colors["bg_dark"])
                item_frame.pack(fill=tk.BOTH, expand=True, padx=15, pady=5)
                
                item_label = tk.Label(item_frame, text=f"⚡ {item_found}",
                        font=('Arial', 11),
                        bg=self.game.current_colors["bg_dark"],
                        fg=self.game.current_colors["text_light"])
                item_label.pack(side=tk.LEFT, padx=10, pady=8)
                
                # Tooltip for item
                if item_found in self.game.item_definitions:
                    self.game.create_item_tooltip(item_label, item_found)
                
                tk.Button(item_frame, text="Take",
                         command=self.take_container_item,
                         font=('Arial', 9), bg=self.game.current_colors["text_cyan"],
                         fg='#000000', width=8).pack(side=tk.RIGHT, padx=10, pady=5)
        
        # Buttons
        button_frame = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_primary"])
        button_frame.pack(pady=15)
        
        # Show "Take All" only if there are 2+ items (gold + item)
        total_container_items = 0
        if gold_amount > 0:
            total_container_items += 1
        if item_found:
            total_container_items += 1
        
        if total_container_items >= 2:
            tk.Button(button_frame, text="Take All",
                     command=lambda: self.take_all_from_container(gold_amount, item_found),
                     font=('Arial', 10, 'bold'), bg='#4CAF50',
                     fg='#ffffff', width=12, pady=5).pack(side=tk.LEFT, padx=5)
        
        tk.Button(button_frame, text="Close",
                 command=self.close_container_and_refresh,
                 font=('Arial', 10), bg=self.game.current_colors["button_secondary"],
                 fg='#ffffff', width=12, pady=5).pack(side=tk.LEFT, padx=5)
    
    def take_container_gold(self):
        """Take gold from container"""
        amount = self.game.current_container_gold
        self.game.gold += amount
        self.game.total_gold_earned += amount
        # Don't increment stats["gold_found"] - already counted in search_container
        self.game.log(f"Collected {amount} gold!", 'loot')
        self.game.current_container_gold = 0
        self.game.current_room.container_gold = 0  # Remove from room storage
        # Refresh the container display with updated contents
        self.show_container_contents(self.game.current_container_name, self.game.current_container_gold, self.game.current_container_item)
    
    def take_container_item(self):
        """Take item from container"""
        item_name = self.game.current_container_item
        self.game.try_add_to_inventory(item_name, "container")
        self.game.current_container_item = None
        self.game.current_room.container_item = None  # Remove from room storage
        # Refresh the container display with updated contents
        self.show_container_contents(self.game.current_container_name, self.game.current_container_gold, self.game.current_container_item)
    
    def take_all_from_container(self, gold_amount, item_name):
        """Take all items from container"""
        if gold_amount > 0:
            self.game.gold += gold_amount
            self.game.total_gold_earned += gold_amount
            # Don't increment stats["gold_found"] - already counted in search_container
            self.game.log(f"Collected {gold_amount} gold!", 'loot')
            self.game.current_room.container_gold = 0  # Remove from room storage
        
        if item_name:
            self.game.try_add_to_inventory(item_name, "container")
            self.game.current_room.container_item = None  # Remove from room storage
        
        self.close_container_and_refresh()
    
    def close_container_and_refresh(self):
        """Close container dialog and return to ground items view"""
        self.game.close_dialog()
        # Check if there are still items on ground (including container items)
        container_has_items = (self.game.current_room.container_gold > 0 or 
                              self.game.current_room.container_item is not None)
        if self.game.current_room.ground_gold > 0 or self.game.current_room.ground_items or \
           (hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items) or \
           (hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items) or \
           container_has_items:
            self.game.show_ground_items()
            self.game.show_exploration_options()  # Update button count
        else:
            self.game.update_display()
            self.game.show_exploration_options()
    
    def pickup_ground_gold(self):
        """Pick up loose gold from ground"""
        if self.game.current_room.ground_gold > 0:
            amount = self.game.current_room.ground_gold
            self.game.gold += amount
            self.game.total_gold_earned += amount
            self.game.stats["gold_found"] += amount
            self.game.log(f"Picked up {amount} gold!", 'loot')
            self.game.current_room.ground_gold = 0
            
            # Refresh or close dialog
            if self.game.current_room.ground_container and not self.game.current_room.container_searched:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif self.game.current_room.ground_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            else:
                self.game.close_dialog()
                self.game.update_display()
                self.game.show_exploration_options()
                self.game.show_exploration_options()
    
    def pickup_ground_item(self, item_name):
        """Pick up a loose item from ground"""
        if item_name in self.game.current_room.ground_items:
            self.game.current_room.ground_items.remove(item_name)
            self.game.try_add_to_inventory(item_name, "ground")
            
            # Refresh or close dialog
            if self.game.current_room.ground_container and not self.game.current_room.container_searched:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif self.game.current_room.ground_gold > 0:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif self.game.current_room.ground_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            else:
                self.game.close_dialog()
                self.game.update_display()
                self.game.show_exploration_options()
    
    def pickup_uncollected_item(self, item_name, skip_refresh=False):
        """Try to pick up an item that was previously left behind due to full inventory"""
        if not hasattr(self.game.current_room, 'uncollected_items'):
            return
        
        if item_name not in self.game.current_room.uncollected_items:
            return  # Item no longer here
        
        # Try to add to inventory
        if len(self.game.inventory) < self.game.max_inventory:
            self.game.inventory.append(item_name)
            self.game.current_room.uncollected_items.remove(item_name)
            self.game.stats["items_found"] += 1
            self.game.log(f"▢ Picked up {item_name}! ({len(self.game.inventory)}/{self.game.max_inventory} slots)", 'loot')
            
            # Refresh or close dialog
            if self.game.current_room.ground_container and not self.game.current_room.container_searched:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif self.game.current_room.ground_gold > 0:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif self.game.current_room.ground_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            elif hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items:
                self.game.show_ground_items()
                self.game.show_exploration_options()  # Update button count
            else:
                self.game.close_dialog()
                self.game.update_display()
                self.game.show_exploration_options()
        else:
            self.game.log(f"❌ INVENTORY STILL FULL! Can't pick up {item_name}. ({len(self.game.inventory)}/{self.game.max_inventory})", 'system')
        
        if not skip_refresh:
            self.game.update_display()
            # Don't call show_exploration_options here - let caller handle refresh
    
    def pickup_dropped_item(self, item_name, skip_refresh=False):
        """Pick up an item that was previously dropped by the player"""
        if not hasattr(self.game.current_room, 'dropped_items'):
            return
        
        if item_name not in self.game.current_room.dropped_items:
            return  # Item no longer here
        
        # Try to add to inventory
        if len(self.game.inventory) < self.game.max_inventory:
            self.game.inventory.append(item_name)
            # Track item collection (even for picked up dropped items)
            if "items_collected" not in self.game.stats:
                self.game.stats["items_collected"] = {}
            self.game.stats["items_collected"][item_name] = self.game.stats["items_collected"].get(item_name, 0) + 1
            self.game.current_room.dropped_items.remove(item_name)
            # Don't count dropped items as found (player already had them)
            self.game.log(f"▢ Picked up {item_name}! ({len(self.game.inventory)}/{self.game.max_inventory})", 'loot')
        else:
            self.game.log(f"❌ INVENTORY FULL! Can't pick up {item_name}. ({len(self.game.inventory)}/{self.game.max_inventory})", 'system')
        
        if not skip_refresh:
            self.game.update_display()
            # Don't call show_exploration_options here - let caller handle refresh
