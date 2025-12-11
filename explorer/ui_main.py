"""
Main UI setup for Dice Dungeon Explorer
Handles building the main game UI frames and panels
"""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from dice_dungeon_explorer import DiceDungeonExplorer


# UI setup methods will be moved here:
# - setup_game_ui
# - _build_main_frames (if it exists)
# - _build_adventure_log (if it exists)
# - _build_player_panel (if it exists)
# - _build_enemy_panel (if it exists)
# - _build_minimap
# - draw_minimap
# - pan_minimap_north/south/east/west
# - center_minimap
# - zoom_in_minimap
# - zoom_out_minimap
# - on_minimap_scroll

# For now, these remain in the main class as they're tightly
# coupled with initialization. They can be refactored later
# into helper functions or a UIBuilder class.
