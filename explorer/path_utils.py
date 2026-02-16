"""
Path utilities for Dice Dungeon
Provides helper functions to get correct paths when running as exe or script
"""

import sys
import os
import shutil


def get_base_dir():
    """
    Get the base directory for user data (saves, settings) - persists across runs.
    
    When frozen (EXE), uses %APPDATA%/DiceDungeon so saves persist regardless
    of where the EXE is placed. Also migrates saves from old EXE-adjacent locations.
    When running as script, uses the project root directory.
    """
    if getattr(sys, 'frozen', False):
        # Running as compiled exe — use APPDATA for persistent user data
        appdata = os.environ.get('APPDATA', os.path.expanduser('~'))
        base = os.path.join(appdata, 'DiceDungeon')
        os.makedirs(base, exist_ok=True)
        
        # Migrate saves from old EXE-adjacent location if they exist
        _migrate_old_saves(base)
        
        return base
    else:
        # Running as script - use parent directory of explorer module
        return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _migrate_old_saves(appdata_base):
    """One-time migration of saves from old EXE-adjacent location to APPDATA"""
    appdata_saves = os.path.join(appdata_base, 'saves')
    migration_marker = os.path.join(appdata_base, '.saves_migrated')
    
    # Skip if already migrated
    if os.path.exists(migration_marker):
        return
    
    # Check for saves next to the EXE
    exe_dir = os.path.dirname(sys.executable)
    old_saves = os.path.join(exe_dir, 'saves')
    
    if os.path.isdir(old_saves):
        os.makedirs(appdata_saves, exist_ok=True)
        for filename in os.listdir(old_saves):
            src = os.path.join(old_saves, filename)
            dst = os.path.join(appdata_saves, filename)
            if os.path.isfile(src) and not os.path.exists(dst):
                try:
                    shutil.copy2(src, dst)
                except Exception:
                    pass
    
    # Mark migration as done
    try:
        with open(migration_marker, 'w') as f:
            f.write('migrated')
    except Exception:
        pass


def get_data_dir():
    """
    Get directory for bundled data files (assets, content, engine).
    When frozen as exe, PyInstaller extracts bundled data to sys._MEIPASS.
    In dev mode, data lives alongside the script.
    """
    if getattr(sys, 'frozen', False):
        return sys._MEIPASS
    else:
        return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def get_asset_path(*path_parts):
    """
    Get path to an asset file (sprites, logos, etc).
    Uses get_data_dir() so assets are found inside PyInstaller bundles.
    
    Args:
        *path_parts: Parts of the path relative to data directory
        
    Returns:
        Absolute path to the asset
    """
    return os.path.join(get_data_dir(), *path_parts)


def get_saves_dir():
    """
    Get the saves directory path.
    
    Returns:
        Absolute path to saves directory
    """
    return os.path.join(get_base_dir(), 'saves')
