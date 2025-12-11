import json
import os
from typing import Any, Dict, List, Optional

class RoomLoadError(Exception):
    ...

def load_rooms(json_path: str) -> List[Dict[str, Any]]:
    """Load rooms_v2.json; minimal validation."""
    if not os.path.exists(json_path):
        raise RoomLoadError(f"Rooms file not found: {json_path}")
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise RoomLoadError("rooms_v2.json must be a JSON array")
    req = ["id", "name", "difficulty", "threats", "history", "flavor", "discoverables"]
    for r in data:
        for key in req:
            if key not in r:
                raise RoomLoadError(f"Room missing key '{key}': {r}")
    return data

def pick_room_for_floor(rooms: List[Dict[str, Any]], floor: int) -> Dict[str, Any]:
    """
    Map floor → difficulty → random room.
    1–3: Easy, 4–6: Medium, 7–9: Hard, 10–12: Elite, 13+: Elite with Boss chance
    
    Reduces combat encounters by ~20% by preferring non-combat rooms when available.
    """
    import random
    if floor <= 3:
        target = "Easy"
    elif floor <= 6:
        target = "Medium"
    elif floor <= 9:
        target = "Hard"
    elif floor <= 12:
        target = "Elite"
    else:
        target = "Elite"
        if floor % 3 == 0:
            target = "Boss"
    
    # Get all rooms matching difficulty
    pool = [r for r in rooms if r.get("difficulty") == target] or rooms
    
    # Reduce combat by 20% - prefer non-combat rooms 20% of the time
    if random.random() < 0.20:
        # Try to find non-combat rooms (those with "lore", "puzzle", "event", "rest" tags)
        non_combat_tags = {"lore", "puzzle", "event", "rest", "environment"}
        non_combat_pool = [r for r in pool 
                          if any(tag in non_combat_tags for tag in r.get("tags", []))
                          and "combat" not in r.get("tags", [])]
        if non_combat_pool:
            pool = non_combat_pool
    
    return random.choice(pool)

def find_room_by_id(rooms: List[Dict[str, Any]], rid: int) -> Optional[Dict[str, Any]]:
    for r in rooms:
        if r.get("id") == rid:
            return r
    return None
