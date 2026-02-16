"""
item_icons.py – Helper for loading item icons in the game UI.

Provides a safe icon-lookup that always returns a valid path,
falling back to unknown.png if the specific icon is missing.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from functools import lru_cache


def _icons_dir() -> Path:
    """Return the absolute path to assets/icons/items/."""
    if getattr(sys, "frozen", False):
        base = Path(sys._MEIPASS)
    else:
        base = Path(__file__).resolve().parent.parent
    return base / "assets" / "icons" / "items"


def slugify(name: str) -> str:
    """Convert an item name to a filesystem-safe slug.

    >>> slugify("Greater Health Potion")
    'greater_health_potion'
    """
    s = name.lower().strip()
    s = re.sub(r"[''']", "", s)
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")


@lru_cache(maxsize=512)
def get_item_icon_path(item_name: str) -> Path:
    """Return the path to the 48×48 icon for *item_name*.

    Falls back to ``unknown.png`` if the specific icon does not exist.
    Never raises — always returns a valid Path (even if the fallback
    itself is missing, returns the expected fallback path so callers
    can handle gracefully).
    """
    icons = _icons_dir()
    slug = slugify(item_name)
    specific = icons / f"{slug}.png"
    if specific.exists():
        return specific
    fallback = icons / "unknown.png"
    return fallback


def icon_exists(item_name: str) -> bool:
    """Return True only if the *specific* icon file exists (not fallback)."""
    icons = _icons_dir()
    slug = slugify(item_name)
    return (icons / f"{slug}.png").exists()
