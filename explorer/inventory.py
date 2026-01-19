"""
Inventory Manager for Dice Dungeon
Handles player inventory, ground items, using/dropping items
"""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from dice_dungeon_explorer import DiceDungeonExplorer


class InventoryManager:
    """
    Handles player inventory, using items, dropping items,
    and showing the inventory UI.
    
    Methods that will be moved here:
    - try_add_to_inventory
    - _add_item_to_inventory
    - get_unequipped_inventory_count
    - show_inventory
    - use_item
    - drop_item
    - equip_item
    - show_ground_items
    - pickup_ground_item
    - pickup_all_ground_items
    - describe_ground_items
    - close_dialog_and_refresh_inventory
    """
    
    def __init__(self, game: "DiceDungeonExplorer"):
        self.game = game
