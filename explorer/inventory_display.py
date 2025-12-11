"""
Inventory Display Manager - Part 1 of Inventory System

Handles all inventory UI display functionality:
- Show/close inventory dialog
- Item tooltips and hover effects
- Ground items display
- Container searching UI
- Equipment comparison stats
- Mousewheel scrolling setup
"""

import tkinter as tk
from collections import Counter


class InventoryDisplayManager:
    """Manages inventory display and UI interactions"""
    
    def __init__(self, game):
        """Initialize with reference to main game instance"""
        self.game = game
    
    def show_inventory(self):
        """Show inventory dialog"""
        if self.game.dialog_frame:
            self.game.dialog_frame.destroy()
        
        # Responsive sizing
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(450, 500, 0.45, 0.75)
        
        self.game.dialog_frame = tk.Frame(self.game.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Inventory slots counter (top left corner)
        slots_frame = tk.Frame(self.game.dialog_frame, bg='#1a0f08')
        slots_frame.place(relx=0.05, rely=0.02, anchor='nw')
        tk.Label(slots_frame, text=f"Slots: {len(self.game.inventory)}/{self.game.max_inventory}",
                font=('Arial', 10, 'bold'), bg='#1a0f08', fg='#ffffff').pack()
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.game.dialog_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg='#1a0f08', fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        close_btn.bind('<Button-1>', lambda e: self.game.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Title centered
        tk.Label(self.game.dialog_frame, text="INVENTORY", font=('Arial', 18, 'bold'),
                bg='#1a0f08', fg='#ffd700', pady=10).pack()
        
        # Boss Key Fragment counter (below title, centered)
        if hasattr(self.game, 'key_fragments_collected'):
            # Color the text based on completion
            fragment_color = '#ffd700' if self.game.key_fragments_collected >= 3 else '#ffffff'
            tk.Label(self.game.dialog_frame, text=f"Boss Key Fragments: ⬟ {self.game.key_fragments_collected}/3",
                    font=('Arial', 10, 'bold'), bg='#1a0f08', fg=fragment_color).pack()
        
        tk.Label(self.game.dialog_frame, text="(Hover over items for details)",
                font=('Arial', 8, 'italic'), bg='#1a0f08', fg='#888888').pack(pady=(5, 0))
        
        # Inventory list with scrollbar
        list_container = tk.Frame(self.game.dialog_frame, bg='#2c1810')
        list_container.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        canvas = tk.Canvas(list_container, bg='#2c1810', highlightthickness=0)
        scrollbar = tk.Scrollbar(list_container, orient="vertical", command=canvas.yview, width=10,
                                bg='#2c1810', troughcolor='#1a0f08')
        inv_frame = tk.Frame(canvas, bg='#2c1810')
        
        # Create window first
        def update_width(event=None):
            canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
        
        canvas_window = canvas.create_window((0, 0), window=inv_frame, anchor="nw")
        canvas.bind("<Configure>", update_width)
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Pack canvas and scrollbar
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        if not self.game.inventory:
            tk.Label(inv_frame, text="Empty", font=('Arial', 12),
                    bg='#2c1810', fg='#666666').pack(pady=20)
        else:
            # Count duplicate items
            item_counts = Counter(self.game.inventory)
            
            # Track which items we've already processed
            processed_items = set()
            
            for i, item in enumerate(self.game.inventory):
                # Skip if we've already displayed this item
                if item in processed_items:
                    continue
                processed_items.add(item)
                
                item_frame = tk.Frame(inv_frame, bg='#3d2415', relief=tk.RAISED, borderwidth=1)
                item_frame.pack(fill=tk.BOTH, expand=True, pady=2, padx=5)
                
                # Check if item is equipped
                is_equipped = item in self.game.equipped_items.values()
                equipped_text = " [EQUIPPED]" if is_equipped else ""
                
                # Check for durability (equipment only)
                durability_text = ""
                item_def = self.game.item_definitions.get(item, {})
                if item_def.get('type') == 'equipment' and item_def.get('max_durability'):
                    # Show durability for all equipment, even if not yet tracked
                    if item in self.game.equipment_durability:
                        current_dur = self.game.equipment_durability[item]
                        max_dur = item_def['max_durability']
                        durability_percent = int((current_dur / max_dur) * 100)
                    else:
                        # New equipment starts at 100%
                        durability_percent = 100
                    
                    durability_text = f" [{durability_percent}%]"
                
                # Add count if more than one
                count_text = f" x{item_counts[item]}" if item_counts[item] > 1 else ""
                
                item_label = tk.Label(item_frame, text=f"• {item}{count_text}{equipped_text}{durability_text}", font=('Arial', 10),
                        bg='#3d2415', fg='#ffffff', anchor='w', wraplength=280, justify='left')
                item_label.pack(side=tk.LEFT, padx=10, pady=5, fill=tk.BOTH, expand=True)
                
                # Add hover tooltip
                self.create_item_tooltip(item_label, item)
                
                # Get item type to determine if usable/equippable
                item_def = self.game.item_definitions.get(item, {})
                item_type = item_def.get('type', 'unknown')
                item_slot = item_def.get('slot', None)
                
                # Find the actual index of this item in the inventory
                item_idx = self.game.inventory.index(item)
                
                # Buttons container frame on the right side
                button_container = tk.Frame(item_frame, bg='#3d2415')
                button_container.pack(side=tk.RIGHT, padx=2)
                
                # Drop button (rightmost - always present)
                drop_btn = tk.Button(button_container, text="Drop", command=lambda idx=item_idx: self.game.drop_item(idx),
                         font=('Arial', 8), bg='#ff6b6b', fg='#ffffff',
                         width=6)
                drop_btn.pack(side=tk.RIGHT, padx=2)
                
                if is_equipped:
                    drop_btn.config(state=tk.DISABLED, bg='#666666')
                
                # Add Use button for usable items (middle-right)
                usable_types = ['heal', 'buff', 'shield', 'cleanse', 'token', 'tool', 'repair', 'consumable', 'consumable_blessing', 'throwable', 'combat_consumable']
                if item_type in usable_types:
                    tk.Button(button_container, text="Use", command=lambda idx=item_idx: self.game.use_item(idx),
                             font=('Arial', 8), bg='#9b59b6', fg='#ffffff',
                             width=6).pack(side=tk.RIGHT, padx=2)
                
                # Add Read button for readable lore items (middle-right)
                if item_type == 'readable_lore':
                    tk.Button(button_container, text="Read", command=lambda idx=item_idx: self.game.use_item(idx),
                             font=('Arial', 8), bg='#e67e22', fg='#ffffff',
                             width=6).pack(side=tk.RIGHT, padx=2)
                
                # Add Equip/Unequip button for equipment (leftmost of button group)
                if item_type == 'equipment' and item_slot:
                    if is_equipped:
                        tk.Button(button_container, text="Unequip", command=lambda slot=item_slot: self.game.unequip_item(slot),
                                 font=('Arial', 8), bg='#f39c12', fg='#000000',
                                 width=8).pack(side=tk.RIGHT, padx=2)
                    else:
                        tk.Button(button_container, text="Equip", command=lambda itm=item, slot=item_slot: self.game.equip_item(itm, slot),
                                 font=('Arial', 8), bg='#4ecdc4', fg='#000000',
                                 width=8).pack(side=tk.RIGHT, padx=2)
        
        # Update scroll region after all items are added
        inv_frame.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        
        # Add mouse wheel scrolling for inventory
        self.game.setup_mousewheel_scrolling(canvas)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(inv_frame)
        
        # ESC to close
        self.game.dialog_frame.bind('<Escape>', lambda e: self.game.close_dialog() or "break")
        self.game.dialog_frame.focus_set()
    
    def create_item_tooltip(self, widget, item_name):
        """Create hover tooltip for inventory item"""
        tooltip = None
        
        def show_tooltip(event):
            nonlocal tooltip
            # Get item description from definitions
            item_def = self.game.item_definitions.get(item_name, {})
            desc = item_def.get('desc', 'No description available.')
            item_type = item_def.get('type', 'unknown')
            
            # Build tooltip text
            tooltip_text = f"{item_name}\n"
            tooltip_text += f"Type: {item_type.replace('_', ' ').title()}\n"
            tooltip_text += f"\n{desc}"
            
            # Add mechanical info (only if not already in description)
            if 'heal' in item_def:
                tooltip_text += f"\n\nRestores {item_def['heal']} health"
            if 'crit_bonus' in item_def:
                tooltip_text += f"\n\n+{int(item_def['crit_bonus']*100)}% crit chance"
            if 'damage_bonus' in item_def:
                tooltip_text += f"\n\n+{item_def['damage_bonus']} damage"
            if 'extra_rolls' in item_def:
                tooltip_text += f"\n\n+{item_def['extra_rolls']} reroll"
            if 'shield' in item_def:
                tooltip_text += f"\n\n+{item_def['shield']} shield"
            
            # Add usage hint only for items that actually have use functionality
            if item_type in ['heal', 'cleanse', 'buff', 'shield']:
                tooltip_text += "\n\n[Click Use to activate]"
            elif item_type == 'readable_lore':
                tooltip_text += "\n\n[Click Read to view]"
            
            # Create tooltip window
            tooltip = tk.Toplevel(widget)
            tooltip.wm_overrideredirect(True)
            tooltip.wm_geometry(f"+{event.x_root + 15}+{event.y_root + 10}")
            
            tooltip_frame = tk.Frame(tooltip, bg='#1a0f08', relief=tk.SOLID, borderwidth=2)
            tooltip_frame.pack()
            
            label = tk.Label(tooltip_frame, text=tooltip_text,
                           font=('Arial', 9), bg='#1a0f08', fg='#ffd700',
                           justify=tk.LEFT, padx=10, pady=8, wraplength=300)
            label.pack()
        
        def hide_tooltip(event):
            nonlocal tooltip
            if tooltip:
                tooltip.destroy()
                tooltip = None
        
        widget.bind('<Enter>', show_tooltip)
        widget.bind('<Leave>', hide_tooltip)
    
    def show_ground_items(self):
        """Show dialog with all items on the ground in current room"""
        # Check if there's actually anything to show
        has_container = self.game.current_room.ground_container and not self.game.current_room.container_searched
        has_gold = self.game.current_room.ground_gold > 0
        has_items = len(self.game.current_room.ground_items) > 0
        has_uncollected = hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items
        has_dropped = hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items
        
        if not (has_container or has_gold or has_items or has_uncollected or has_dropped):
            # Nothing on ground, don't open empty dialog
            self.game.log("There's nothing on the ground here.", 'system')
            return
        
        if self.game.dialog_frame:
            self.game.dialog_frame.destroy()
        
        # Responsive sizing
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(450, 400)
        
        self.game.dialog_frame = tk.Frame(self.game.root, bg=self.game.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Bind Escape key to close dialog
        self.game.dialog_frame.bind('<Escape>', lambda e: self.game.close_dialog() or "break")
        
        # Title
        title_label = tk.Label(self.game.dialog_frame, text="▢ ITEMS ON GROUND ▢", 
                              font=('Arial', 14, 'bold'),
                              bg=self.game.current_colors["bg_primary"], 
                              fg=self.game.current_colors["text_gold"])
        title_label.pack(pady=10)
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.game.dialog_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.game.current_colors["bg_primary"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        close_btn.bind('<Button-1>', lambda e: self.game.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Scrollable frame for items
        list_container = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_secondary"])
        list_container.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        canvas = tk.Canvas(list_container, bg=self.game.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(list_container, orient="vertical", command=canvas.yview, width=10,
                                bg=self.game.current_colors["bg_secondary"], troughcolor=self.game.current_colors["bg_dark"])
        scrollable_frame = tk.Frame(canvas, bg=self.game.current_colors["bg_secondary"])
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Container section (if exists and not searched)
        if self.game.current_room.ground_container and not self.game.current_room.container_searched:
            tk.Label(scrollable_frame, text="Container:", 
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_secondary"], 
                    fg=self.game.current_colors["text_cyan"]).pack(anchor='w', padx=10, pady=(10, 5))
            
            container = self.game.current_room.ground_container
            item_frame = tk.Frame(scrollable_frame, bg=self.game.current_colors["bg_dark"])
            item_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=2)
            
            # Container name and description
            container_def = self.game.container_definitions.get(container, {})
            description = container_def.get('description', 'A mysterious container')
            
            # Create vertical layout for name and description
            text_frame = tk.Frame(item_frame, bg=self.game.current_colors["bg_dark"])
            text_frame.pack(side=tk.LEFT, padx=10, pady=5, fill=tk.X, expand=True)
            
            tk.Label(text_frame, text=container, font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_dark"], 
                    fg=self.game.current_colors["text_light"],
                    anchor='w').pack(anchor='w')
            
            tk.Label(text_frame, text=description, font=('Arial', 8),
                    bg=self.game.current_colors["bg_dark"], 
                    fg=self.game.current_colors["text_secondary"],
                    anchor='w').pack(anchor='w')
            
            # Check if container is locked
            if self.game.current_room.container_locked:
                # Show lock indicator and lockpick button
                tk.Label(text_frame, text="🔒 LOCKED", font=('Arial', 8, 'bold'),
                        bg=self.game.current_colors["bg_dark"], 
                        fg=self.game.current_colors["text_gold"],
                        anchor='w').pack(anchor='w')
                
                # Check if player has lockpick kit
                has_lockpick = "Lockpick Kit" in self.game.inventory
                if has_lockpick:
                    tk.Button(item_frame, text="Use Lockpick", 
                             command=lambda c=container: self.game.use_lockpick_on_container(c),
                             font=('Arial', 9), bg=self.game.current_colors["button_success"], fg='#000000',
                             width=12).pack(side=tk.RIGHT, padx=5, pady=2)
                else:
                    tk.Label(item_frame, text="Need Lockpick Kit", font=('Arial', 8, 'italic'),
                            bg=self.game.current_colors["bg_dark"], 
                            fg=self.game.current_colors["text_secondary"],
                            anchor='w').pack(side=tk.RIGHT, padx=5)
            else:
                # Normal unlocked container
                tk.Button(item_frame, text="Search", 
                         command=lambda c=container: self.game.search_container(c),
                         font=('Arial', 9), bg=self.game.current_colors["text_cyan"], fg='#000000',
                         width=10).pack(side=tk.RIGHT, padx=5, pady=2)
        
        # Loose gold section
        if self.game.current_room.ground_gold > 0:
            tk.Label(scrollable_frame, text="Gold Coins:", 
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_secondary"], 
                    fg=self.game.current_colors["text_gold"]).pack(anchor='w', padx=10, pady=(10, 5))
            
            gold_frame = tk.Frame(scrollable_frame, bg=self.game.current_colors["bg_dark"])
            gold_frame.pack(fill=tk.X, padx=10, pady=2)
            
            tk.Label(gold_frame, text=f"◉ {self.game.current_room.ground_gold} Gold",
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_dark"], 
                    fg=self.game.current_colors["text_gold"],
                    anchor='w').pack(side=tk.LEFT, padx=10, pady=5, fill=tk.X, expand=True)
            
            tk.Button(gold_frame, text="Pick Up", 
                     command=self.game.pickup_ground_gold,
                     font=('Arial', 9), bg=self.game.current_colors["text_gold"], fg='#000000',
                     width=10).pack(side=tk.RIGHT, padx=5, pady=2)
        
        # Loose items section
        if self.game.current_room.ground_items:
            tk.Label(scrollable_frame, text="Items:", 
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_secondary"], 
                    fg='#90EE90').pack(anchor='w', padx=10, pady=(10, 5))
            
            for item in self.game.current_room.ground_items:
                item_frame = tk.Frame(scrollable_frame, bg=self.game.current_colors["bg_dark"])
                item_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=2)
                
                item_label = tk.Label(item_frame, text=item, font=('Arial', 10),
                        bg=self.game.current_colors["bg_dark"], 
                        fg=self.game.current_colors["text_light"],
                        anchor='w')
                item_label.pack(side=tk.LEFT, padx=10, pady=5, fill=tk.X, expand=True)
                
                if item in self.game.item_definitions:
                    self.create_item_tooltip(item_label, item)
                
                tk.Button(item_frame, text="Pick Up", 
                         command=lambda i=item: self.game.pickup_ground_item(i),
                         font=('Arial', 9), bg='#90EE90', fg='#000000',
                         width=10).pack(side=tk.RIGHT, padx=5, pady=2)
        
        # Containers section - OLD SYSTEM COMPATIBILITY
        discoverables = self.game.current_room.data.get('discoverables', [])
        unsearched_containers = [d for d in discoverables if d not in self.game.current_room.collected_discoverables]
        
        if unsearched_containers and not hasattr(self.game.current_room, 'ground_container'):
            # Old save files compatibility
            tk.Label(scrollable_frame, text="Containers (Legacy):", 
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_secondary"], 
                    fg=self.game.current_colors["text_cyan"]).pack(anchor='w', padx=10, pady=(10, 5))
            
            for container in unsearched_containers:
                item_frame = tk.Frame(scrollable_frame, bg=self.game.current_colors["bg_dark"])
                item_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=2)
                
                # Container name and description
                container_def = self.game.container_definitions.get(container, {})
                description = container_def.get('description', 'A mysterious container')
                
                # Create vertical layout for name and description
                text_frame = tk.Frame(item_frame, bg=self.game.current_colors["bg_dark"])
                text_frame.pack(side=tk.LEFT, padx=10, pady=5, fill=tk.X, expand=True)
                
                tk.Label(text_frame, text=container, font=('Arial', 10, 'bold'),
                        bg=self.game.current_colors["bg_dark"], 
                        fg=self.game.current_colors["text_light"],
                        anchor='w').pack(anchor='w')
                
                tk.Label(text_frame, text=description, font=('Arial', 8),
                        bg=self.game.current_colors["bg_dark"], 
                        fg=self.game.current_colors["text_secondary"],
                        anchor='w').pack(anchor='w')
                
                tk.Button(item_frame, text="Search", 
                         command=lambda c=container: self.game.pickup_from_ground(c, 'container'),
                         font=('Arial', 9), bg=self.game.current_colors["text_cyan"], fg='#000000',
                         width=10).pack(side=tk.RIGHT, padx=5, pady=2)
        
        # Uncollected items section
        if hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items:
            tk.Label(scrollable_frame, text="Left Behind (Inventory Full):", 
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_secondary"], 
                    fg='#ff8c00').pack(anchor='w', padx=10, pady=(10, 5))
            
            for item in self.game.current_room.uncollected_items:
                item_frame = tk.Frame(scrollable_frame, bg=self.game.current_colors["bg_dark"])
                item_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=2)
                
                # Get item description for tooltip
                item_info = self.game.item_definitions.get(item, {})
                item_desc = item_info.get('desc', 'No description available')
                
                item_label = tk.Label(item_frame, text=item, font=('Arial', 10),
                        bg=self.game.current_colors["bg_dark"], 
                        fg=self.game.current_colors["text_light"],
                        anchor='w')
                item_label.pack(side=tk.LEFT, padx=10, pady=5, fill=tk.X, expand=True)
                self.create_item_tooltip(item_label, item)
                
                tk.Button(item_frame, text="Pick Up", 
                         command=lambda i=item: self.game.pickup_from_ground(i, 'uncollected'),
                         font=('Arial', 9), bg='#ff8c00', fg='#ffffff',
                         width=10).pack(side=tk.RIGHT, padx=5, pady=2)
        
        # Dropped items section
        if hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items:
            tk.Label(scrollable_frame, text="Dropped Items:", 
                    font=('Arial', 10, 'bold'),
                    bg=self.game.current_colors["bg_secondary"], 
                    fg='#4CAF50').pack(anchor='w', padx=10, pady=(15, 5))
            
            for item in self.game.current_room.dropped_items:
                item_frame = tk.Frame(scrollable_frame, bg=self.game.current_colors["bg_dark"])
                item_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=2)
                
                # Get item description for tooltip
                item_info = self.game.item_definitions.get(item, {})
                item_desc = item_info.get('desc', 'No description available')
                
                item_label = tk.Label(item_frame, text=item, font=('Arial', 10),
                        bg=self.game.current_colors["bg_dark"], 
                        fg=self.game.current_colors["text_light"],
                        anchor='w')
                item_label.pack(side=tk.LEFT, padx=10, pady=5, fill=tk.X, expand=True)
                self.create_item_tooltip(item_label, item)
                
                tk.Button(item_frame, text="Pick Up", 
                         command=lambda i=item: self.game.pickup_from_ground(i, 'dropped'),
                         font=('Arial', 9), bg='#4CAF50', fg='#ffffff',
                         width=10).pack(side=tk.RIGHT, padx=5, pady=2)
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Button container
        button_frame = tk.Frame(self.game.dialog_frame, bg=self.game.current_colors["bg_primary"])
        button_frame.pack(pady=10)
        
        # Take All button (only if there are 2+ items, excluding unopened containers)
        total_items = 0
        # Don't count unopened containers - they need to be searched manually
        if self.game.current_room.ground_gold > 0:
            total_items += 1
        total_items += len(self.game.current_room.ground_items)
        if hasattr(self.game.current_room, 'uncollected_items'):
            total_items += len(self.game.current_room.uncollected_items)
        if hasattr(self.game.current_room, 'dropped_items'):
            total_items += len(self.game.current_room.dropped_items)
        
        # Only show "Take All" if there are 2+ pickupable items
        if total_items >= 2:
            tk.Button(button_frame, text="Take All", command=self.game.pickup_all_ground_items,
                     font=('Arial', 10, 'bold'), bg='#4CAF50', 
                     fg='#ffffff', width=15, pady=5).pack(side=tk.LEFT, padx=5)
        
        # Close button
        tk.Button(button_frame, text="Close", command=self.game.close_dialog,
                 font=('Arial', 10), bg=self.game.current_colors["button_secondary"], 
                 fg='#ffffff', width=15, pady=5).pack(side=tk.LEFT, padx=5)
    
    def pickup_from_ground(self, item_name, source_type):
        """Pick up item from ground dialog or search container"""
        if source_type == 'uncollected':
            self.game.pickup_uncollected_item(item_name)
        elif source_type == 'dropped':
            self.game.pickup_dropped_item(item_name)
        elif source_type == 'container':
            self.game.search_container(item_name)
        
        # Refresh dialog to update item list
        discoverables = self.game.current_room.data.get('discoverables', [])
        unsearched_containers = [d for d in discoverables if d not in self.game.current_room.collected_discoverables]
        
        if ((hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items) or
            (hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items) or
            unsearched_containers):
            self.show_ground_items()
        else:
            # No more items, close dialog and refresh exploration view
            self.game.close_dialog()
            self.game.show_exploration_options()
