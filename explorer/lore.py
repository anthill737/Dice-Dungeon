import tkinter as tk
import random


class LoreManager:
    """Handles all lore/notes/journal UI display and management"""
    
    def __init__(self, game):
        self.game = game
        self.lore_overlay_frame = None  # For popup overlays
    
    def _get_lore_entry_index(self, lore_key, item_key, reread_msg="You've read all these. This one seems familiar..."):
        """Helper to get or assign a lore entry index for a specific item instance"""
        # Check if this item already has an assigned entry
        if item_key in self.game.lore_item_assignments:
            return self.game.lore_item_assignments[item_key]
        
        # First time reading this item - assign a new entry
        total_entries = len(self.game.lore_items[lore_key])
        
        # Initialize key if it doesn't exist (for old saves)
        if lore_key not in self.game.used_lore_entries:
            self.game.used_lore_entries[lore_key] = []
        
        used_indices = self.game.used_lore_entries[lore_key]
        
        # Find an unused entry
        available_indices = [i for i in range(total_entries) if i not in used_indices]
        
        if not available_indices:
            # All entries have been used - start reusing from beginning
            entry_index = random.randint(0, total_entries - 1)
            self.game.log(reread_msg, 'system')
        else:
            # Pick a random unused entry
            entry_index = random.choice(available_indices)
            # Mark this entry as used
            self.game.used_lore_entries[lore_key].append(entry_index)
        
        # Assign this entry to this item permanently
        self.game.lore_item_assignments[item_key] = entry_index
        return entry_index
    
    def read_lore_item(self, item_name, idx):
        """Main entry point: Read a lore item - opens unified lore display"""
        # Close current dialog
        if self.game.dialog_frame:
            self.game.dialog_frame.destroy()
        
        # Ensure lore entry exists in codex by reading it once (will be added if new)
        item_key = f"{item_name}_{idx}"
        
        # Determine lore type and ensure it's in the codex
        lore_type_map = {
            "Guard Journal": ("guards_journal", "guards_journal_pages"),
            "Quest Notice": ("quest_notice", "quest_notices"),
            "Scrawled Note": ("scrawled_note", "scrawled_notes"),
            "Ledger Entry": ("scrawled_note", "scrawled_notes"),
            "Training Manual Page": ("training_manual", "training_manual_pages"),
            "Training Manual Scrap": ("training_manual", "training_manual_pages"),
            "Pressed Page": ("pressed_page", "pressed_pages"),
            "Surgeon Note": ("surgeons_note", "surgeons_notes"),
            "Surgeon's Note": ("surgeons_note", "surgeons_notes"),
            "Puzzle Note": ("puzzle_note", "puzzle_notes"),
            "Star Chart Scrap": ("star_chart", "star_charts"),
            "Star Chart": ("star_chart", "star_charts"),
            "Cracked Map Scrap": ("map_scrap", "cracked_map_scraps"),
            "Prayer Strip": ("prayer_strip", "prayer_strips"),
            "Old Letter": ("old_letter", "old_letters")
        }
        
        lore_info = lore_type_map.get(item_name)
        if not lore_info:
            self.game.log(f"Cannot read {item_name}.", 'system')
            return
        
        lore_type, lore_key = lore_info
        
        # Determine the standardized title for codex storage
        title_map = {
            "guards_journal": "Guard Journal",
            "quest_notice": "Quest Notice",
            "scrawled_note": "Scrawled Note",
            "training_manual": "Training Manual Page",
            "pressed_page": "Pressed Page",
            "surgeons_note": "Surgeon's Note",
            "puzzle_note": "Puzzle Note",
            "star_chart": "Star Chart",
            "map_scrap": "Cracked Map Scrap",
            "prayer_strip": "Prayer Strip",
            "old_letter": "Old Letter"
        }
        standard_title = title_map.get(lore_type, item_name)
        
        # Check if this specific item instance is already assigned
        is_new = item_key not in self.game.lore_item_assignments
        
        if is_new:
            # Read it once to add to codex
            entry_index = self._get_lore_entry_index(lore_key, item_key)
            entry = self.game.lore_items[lore_key][entry_index]
            
            # Determine subtitle based on type
            subtitle = ""
            if lore_type == "guards_journal":
                subtitle = entry.get("date", "")
            elif lore_type == "quest_notice":
                subtitle = f"Reward: {entry.get('reward', 'Unknown')}"
            elif lore_type == "training_manual":
                subtitle = entry.get("title", "")
            
            # Generate unique ID for this lore instance
            unique_id = len([e for e in self.game.lore_codex if e.get('type') == lore_type]) + 1
            
            # Add to codex with unique ID
            self.game.lore_codex.append({
                "type": lore_type,
                "title": standard_title,
                "subtitle": subtitle,
                "content": entry.get("text", entry.get("content", "")),
                "floor_found": self.game.floor,
                "unique_id": unique_id,
                "item_key": item_key  # Store for reference
            })
            
            # Update stat
            stat_name = standard_title
            self.game.stats["lore_found"][stat_name] = self.game.stats["lore_found"].get(stat_name, 0) + 1
            
            self.game.log(f"New lore discovered: {standard_title} #{unique_id}!", 'lore')
        
        # Get the actual content for this specific item instance
        entry_index = self.game.lore_item_assignments.get(item_key, 0)
        entry = self.game.lore_items[lore_key][entry_index]
        
        # Create a display entry for the popup
        subtitle = ""
        if lore_type == "guards_journal":
            subtitle = entry.get("date", "")
        elif lore_type == "quest_notice":
            subtitle = f"Reward: {entry.get('reward', 'Unknown')}"
        elif lore_type == "training_manual":
            subtitle = entry.get("title", "")
        
        display_entry = {
            "type": lore_type,
            "title": standard_title,
            "subtitle": subtitle,
            "content": entry.get("text", entry.get("content", "")),
            "floor_found": getattr(self.game, 'floor', 1)
        }
        
        # Show the lore entry popup directly
        self.show_lore_entry_popup(display_entry)
    
    def read_lore_item_with_return(self, item_name, idx, return_callback):
        """Read a lore item with a return callback (for selection dialogs)"""
        item_key = f"{item_name}_{idx}"
        
        # Determine lore type
        lore_type_map = {
            "Guard Journal": ("guards_journal", "guards_journal_pages"),
            "Quest Notice": ("quest_notice", "quest_notices"),
            "Scrawled Note": ("scrawled_note", "scrawled_notes"),
            "Ledger Entry": ("scrawled_note", "scrawled_notes"),
            "Training Manual Page": ("training_manual", "training_manual_pages"),
            "Training Manual Scrap": ("training_manual", "training_manual_pages"),
            "Pressed Page": ("pressed_page", "pressed_pages"),
            "Surgeon Note": ("surgeons_note", "surgeons_notes"),
            "Surgeon's Note": ("surgeons_note", "surgeons_notes"),
            "Puzzle Note": ("puzzle_note", "puzzle_notes"),
            "Star Chart Scrap": ("star_chart", "star_charts"),
            "Star Chart": ("star_chart", "star_charts"),
            "Cracked Map Scrap": ("map_scrap", "cracked_map_scraps"),
            "Prayer Strip": ("prayer_strip", "prayer_strips"),
            "Old Letter": ("old_letter", "old_letters")
        }
        
        lore_info = lore_type_map.get(item_name)
        if not lore_info:
            self.game.log(f"Cannot read {item_name}.", 'system')
            return
        
        lore_type, lore_key = lore_info
        
        # Determine the standardized title
        title_map = {
            "guards_journal": "Guard Journal",
            "quest_notice": "Quest Notice",
            "scrawled_note": "Scrawled Note",
            "training_manual": "Training Manual Page",
            "pressed_page": "Pressed Page",
            "surgeons_note": "Surgeon's Note",
            "puzzle_note": "Puzzle Note",
            "star_chart": "Star Chart",
            "map_scrap": "Cracked Map Scrap",
            "prayer_strip": "Prayer Strip",
            "old_letter": "Old Letter"
        }
        standard_title = title_map.get(lore_type, item_name)
        
        # Check if new
        is_new = item_key not in self.game.lore_item_assignments
        
        if is_new:
            entry_index = self._get_lore_entry_index(lore_key, item_key)
            entry = self.game.lore_items[lore_key][entry_index]
            
            subtitle = ""
            if lore_type == "guards_journal":
                subtitle = entry.get("date", "")
            elif lore_type == "quest_notice":
                subtitle = f"Reward: {entry.get('reward', 'Unknown')}"
            elif lore_type == "training_manual":
                subtitle = entry.get("title", "")
            
            unique_id = len([e for e in self.game.lore_codex if e.get('type') == lore_type]) + 1
            
            self.game.lore_codex.append({
                "type": lore_type,
                "title": standard_title,
                "subtitle": subtitle,
                "content": entry.get("text", entry.get("content", "")),
                "floor_found": self.game.floor,
                "unique_id": unique_id,
                "item_key": item_key
            })
            
            stat_name = standard_title
            self.game.stats["lore_found"][stat_name] = self.game.stats["lore_found"].get(stat_name, 0) + 1
            
            self.game.log(f"New lore discovered: {standard_title} #{unique_id}!", 'lore')
        
        # Get content
        entry_index = self.game.lore_item_assignments.get(item_key, 0)
        entry = self.game.lore_items[lore_key][entry_index]
        
        subtitle = ""
        if lore_type == "guards_journal":
            subtitle = entry.get("date", "")
        elif lore_type == "quest_notice":
            subtitle = f"Reward: {entry.get('reward', 'Unknown')}"
        elif lore_type == "training_manual":
            subtitle = entry.get("title", "")
        
        display_entry = {
            "type": lore_type,
            "title": standard_title,
            "subtitle": subtitle,
            "content": entry.get("text", entry.get("content", "")),
            "floor_found": getattr(self.game, 'floor', 1)
        }
        
        # Show with return callback
        self.show_lore_entry_popup(display_entry, return_callback)
    
    def read_and_close(self, item_name, idx):
        """Helper to read lore item and keep the selection menu open"""
        copies_indices = [i for i, inv_item in enumerate(self.game.inventory) if inv_item == item_name]
        self.read_lore_item_with_return(item_name, idx, lambda: self.game.show_lore_selection_dialog(item_name, copies_indices))
    
    def show_lore_entry_popup(self, lore_entry, return_callback=None):
        """Display a lore entry in a popup overlay"""
        # Create overlay frame
        if self.lore_overlay_frame:
            self.lore_overlay_frame.destroy()
        
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(550, 500, 0.6, 0.75)
        
        self.lore_overlay_frame = tk.Frame(self.game.game_frame, bg=self.game.current_colors["bg_primary"],
                                     relief=tk.RIDGE, borderwidth=3)
        self.lore_overlay_frame.place(relx=0.5, rely=0.5, anchor='center',
                               width=dialog_width, height=dialog_height)
        
        # Header
        header_frame = tk.Frame(self.lore_overlay_frame, bg=self.game.current_colors["bg_primary"])
        header_frame.pack(fill=tk.X, pady=(10, 0))
        
        tk.Label(header_frame, text=lore_entry["title"],
                font=('Arial', self.game.scale_font(16), 'bold'),
                bg=self.game.current_colors["bg_primary"],
                fg=self.game.current_colors["text_gold"]).pack()
        
        def close_overlay():
            if self.lore_overlay_frame:
                self.lore_overlay_frame.destroy()
                self.lore_overlay_frame = None
            # Return focus to root window so keybindings work
            self.game.root.focus_force()
            if return_callback:
                return_callback()
        
        # Close button
        close_btn = tk.Label(header_frame, text="✕", font=('Arial', self.game.scale_font(16), 'bold'),
                            bg=self.game.current_colors["bg_primary"], fg='#ff4444',
                            cursor="hand2", padx=5)
        close_btn.place(relx=1.0, rely=0.0, anchor='ne', x=-10, y=0)
        close_btn.bind('<Button-1>', lambda e: close_overlay())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Subtitle and floor
        if lore_entry.get("subtitle"):
            tk.Label(self.lore_overlay_frame, text=lore_entry["subtitle"],
                    font=('Arial', self.game.scale_font(11), 'italic'),
                    bg=self.game.current_colors["bg_primary"],
                    fg=self.game.current_colors["text_secondary"]).pack()
        
        tk.Label(self.lore_overlay_frame, text=f"Discovered on Floor {lore_entry['floor_found']}",
                font=('Arial', self.game.scale_font(10), 'italic'),
                bg=self.game.current_colors["bg_primary"],
                fg=self.game.current_colors["text_secondary"]).pack(pady=5)
        
        # Content
        text_frame = tk.Frame(self.lore_overlay_frame, bg=self.game.current_colors["bg_dark"], 
                             relief=tk.SUNKEN, borderwidth=2)
        text_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        text_widget = tk.Text(text_frame,
                             wrap=tk.WORD,
                             font=('Arial', self.game.scale_font(11)),
                             bg=self.game.current_colors["bg_dark"],
                             fg=self.game.current_colors["text_primary"],
                             relief=tk.FLAT,
                             padx=15,
                             pady=15)
        text_scrollbar = tk.Scrollbar(text_frame, command=text_widget.yview)
        text_widget.configure(yscrollcommand=text_scrollbar.set)
        
        text_widget.insert('1.0', lore_entry["content"])
        text_widget.configure(state=tk.DISABLED)
        
        text_widget.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        text_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.game.setup_mousewheel_scrolling(text_widget)
        
        # ESC to close
        self.lore_overlay_frame.bind('<Escape>', lambda e: close_overlay() or "break")
        text_widget.bind('<Escape>', lambda e: close_overlay() or "break")
        header_frame.bind('<Escape>', lambda e: close_overlay() or "break")
        
        self.lore_overlay_frame.lift()
        self.lore_overlay_frame.focus_set()
        text_widget.focus_set()
