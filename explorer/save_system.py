"""
Save System for Dice Dungeon Explorer
Handles save/load game logic and save slot UI
"""

from typing import TYPE_CHECKING

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
