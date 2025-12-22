"""
Save System for Dice Dungeon Explorer
Handles save/load game logic and save slot UI
"""

from typing import TYPE_CHECKING
import tkinter as tk

if TYPE_CHECKING:
    from dice_dungeon_explorer import DiceDungeonExplorer


class SaveSystem:
    """
    Handles save/load game logic and save slot UI.
    
    Methods that will be moved here:
    - show_unified_save_load_menu
    - show_save_slots
    - show_load_slots
    - _create_save_slot_button
    - _save_to_empty_slot
    - save_to_slot
    - load_from_slot
    - save_game
    - load_game
    - delete_save_slot
    - save_high_score
    - show_unsaved_changes_dialog
    - Any small helper methods only for saving/loading
    """
    
    def __init__(self, game: "DiceDungeonExplorer"):
        self.game = game
    
    def show_name_save_dialog(self, slot_num):
        """Show dialog to name a save before saving to empty slot"""
        # Create name dialog overlay
        name_overlay = tk.Frame(self.game.dialog_frame, bg='#1a0f0a', relief=tk.RIDGE, borderwidth=3)
        name_overlay.place(relx=0.5, rely=0.5, anchor='center', width=550, height=280)
        name_overlay.lift()
        
        # Title
        tk.Label(name_overlay, text=f"💾 Save to Slot {slot_num} 💾",
                font=('Arial', 18, 'bold'), bg='#1a0f0a', fg='#ffd700',
                pady=15).pack()
        
        tk.Label(name_overlay, 
                text="Give your adventure a name:",
                font=('Arial', 12), bg='#1a0f0a', fg='#d4a574',
                pady=5).pack()
        
        # Name entry frame
        entry_frame = tk.Frame(name_overlay, bg='#1a0f0a')
        entry_frame.pack(pady=15)
        
        tk.Label(entry_frame, text="Save Name:", font=('Arial', 11, 'bold'),
                bg='#1a0f0a', fg='#ffd700').pack(anchor='w', padx=20)
        
        name_entry = tk.Entry(entry_frame, font=('Arial', 12), width=35, bg='#2c1810', fg='#ffffff',
                             insertbackground='#ffffff', relief=tk.SUNKEN, borderwidth=2)
        name_entry.pack(padx=20, pady=5)
        name_entry.focus_set()
        
        # Suggestion text
        tk.Label(name_overlay, 
                text="(Leave blank for default name)",
                font=('Arial', 9, 'italic'), bg='#1a0f0a', fg='#888888',
                pady=5).pack()
        
        # Button frame
        btn_frame = tk.Frame(name_overlay, bg='#1a0f0a')
        btn_frame.pack(pady=15)
        
        def do_save():
            custom_name = name_entry.get().strip()
            name_overlay.destroy()
            self.game.save_to_slot(slot_num, custom_name)
            # Note: save_to_slot already calls close_dialog()
        
        def cancel_save():
            name_overlay.destroy()
        
        tk.Button(btn_frame, text="Save", 
                 command=do_save,
                 font=('Arial', 12, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=12, pady=8).pack(side=tk.LEFT, padx=5)
        
        tk.Button(btn_frame, text="Cancel", 
                 command=cancel_save,
                 font=('Arial', 12), bg='#ff6b6b', fg='#000000',
                 width=12, pady=8).pack(side=tk.LEFT, padx=5)
        
        # Bind Enter key to save
        name_entry.bind('<Return>', lambda e: do_save())
        name_entry.bind('<Escape>', lambda e: cancel_save())
