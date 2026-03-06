from typing import Any, Dict
from rooms_loader import load_rooms, pick_room_for_floor
from mechanics_engine import (
    apply_on_enter, apply_on_clear, apply_on_fail,
    settle_temp_effects, get_effective_stats
)

def attach_content(game_obj: Any, base_dir: str):
    import os
    data_path = os.path.join(base_dir, "dice_dungeon_content", "data", "rooms_v2.json")
    game_obj._rooms = load_rooms(data_path)
    game_obj._current_room = None

def start_room_for_floor(game_obj: Any, floor: int, log_fn):
    from .rooms_loader import pick_room_for_floor
    rng = getattr(game_obj, 'rng', None)
    room = pick_room_for_floor(game_obj._rooms, floor, rng=rng)
    game_obj._current_room = room
    log_fn(f"=== ROOM: {room['name']} ({room['difficulty']}) ===")
    log_fn(room["flavor"])
    apply_on_enter(game_obj, room, log_fn)
    eff = get_effective_stats(game_obj)
    if hasattr(game_obj, "reroll_bonus"):
        game_obj.rolls_left = 3 + game_obj.reroll_bonus + eff["extra_rolls"]

def complete_room_success(game_obj: Any, log_fn):
    room = getattr(game_obj, "_current_room", None)
    if room:
        apply_on_clear(game_obj, room, log_fn)
    settle_temp_effects(game_obj, phase="after_combat")

def complete_room_fail(game_obj: Any, log_fn):
    room = getattr(game_obj, "_current_room", None)
    if room:
        apply_on_fail(game_obj, room, log_fn)
    settle_temp_effects(game_obj, phase="after_combat")

def on_floor_transition(game_obj: Any):
    settle_temp_effects(game_obj, phase="floor_transition")

def apply_effective_modifiers(game_obj: Any):
    eff = get_effective_stats(game_obj)
    game_obj._effective_crit = float(getattr(game_obj, "crit_chance", 0.1)) + eff["crit_bonus"]
    game_obj._effective_dmg_bonus = int(getattr(game_obj, "damage_bonus", 0)) + eff["damage_bonus"]
    game_obj._effective_gold_mult = float(getattr(game_obj, "multiplier", 1.0)) * (1.0 + eff["gold_mult"])
    game_obj._temp_shield = eff["temp_shield"]
    game_obj._shop_discount = eff["shop_discount"]
    game_obj._has_disarm = eff["has_disarm"]
    game_obj._has_escape = eff["has_escape"]
    game_obj._statuses = eff["statuses"]
