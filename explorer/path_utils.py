"""
Path utilities for Dice Dungeon
Provides helper functions to get correct paths when running as exe or script
"""

import sys
import os


def get_base_dir():
    """
    Get the base directory - works both in dev and when frozen as exe.
    
    Returns the directory containing the main executable or script.
    """
    if getattr(sys, 'frozen', False):
        # Running as compiled exe - use directory containing the exe
        return os.path.dirname(sys.executable)
    else:
        # Running as script - use parent directory of explorer module
        return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def get_asset_path(*path_parts):
    """
    Get path to an asset file.
    
    Args:
        *path_parts: Parts of the path relative to base directory
        
    Returns:
        Absolute path to the asset
    """
    return os.path.join(get_base_dir(), *path_parts)


def get_saves_dir():
    """
    Get the saves directory path.
    
    Returns:
        Absolute path to saves directory
    """
    return os.path.join(get_base_dir(), 'saves')
