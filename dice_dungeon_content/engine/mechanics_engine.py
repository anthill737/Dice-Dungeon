from typing import Any, Dict, Callable

LogFn = Callable[[str], None]

class PlayerAdapter:
    """
    Attributes used on the game object:
      gold, total_gold_earned, health, max_health, multiplier, damage_bonus, crit_chance,
      reroll_bonus, temp_shield, shop_discount,
      inventory (list), flags (dict), temp_effects (dict)
    """
    def __init__(self, game_obj: Any):
        self.g = game_obj
        if not hasattr(self.g, "inventory"): self.g.inventory = []
        if not hasattr(self.g, "flags"):
            self.g.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
        if not hasattr(self.g, "temp_effects"): self.g.temp_effects = {}
        if not hasattr(self.g, "temp_shield"): self.g.temp_shield = 0
        if not hasattr(self.g, "shop_discount"): self.g.shop_discount = 0.0
        if not hasattr(self.g, "total_gold_earned"): self.g.total_gold_earned = 0

def _add_temp(p: PlayerAdapter, key: str, delta, duration: str):
    if not delta: return
    eff = p.g.temp_effects.get(key, {"delta": 0, "duration": duration})
    eff["delta"] += delta
    eff["duration"] = duration
    p.g.temp_effects[key] = eff

def _apply_bundle(p: PlayerAdapter, eff: Dict[str, Any], log: LogFn):
    if not eff: return
    dur = eff.get("duration", "combat")

    # REMOVED: Random heal on room entry
    # heal = int(eff.get("heal", 0))
    # if heal:
    #     p.g.health = min(p.g.max_health, p.g.health + heal)
    #     log(f"+{heal} HP")

    # REMOVED: Random gold on room entry
    # gold_flat = int(eff.get("gold_flat", 0))
    # if gold_flat:
    #     p.g.gold += gold_flat
    #     p.g.total_gold_earned += gold_flat
    #     log(f"+{gold_flat} Gold")

    if eff.get("cleanse"):
        p.g.flags["statuses"].clear()
        log("Cleansed all negative statuses")

    if eff.get("disarm_token"):
        p.g.flags["disarm_token"] += 1
        log("Gained a disarm token")

    if eff.get("escape_token"):
        p.g.flags["escape_token"] += 1
        log("Gained an escape token")

    item = eff.get("item")
    if item:
        # Add to ground items instead of directly to inventory
        if hasattr(p.g, 'current_room') and p.g.current_room:
            if not hasattr(p.g.current_room, 'ground_items'):
                p.g.current_room.ground_items = []
            p.g.current_room.ground_items.append(item)
            log(f"Found item: {item} (on ground)")
        else:
            # Fallback for old save files or edge cases
            p.g.inventory.append(item)
            log(f"Found item: {item}")

    status = eff.get("status")
    if status:
        # Prevent duplicate statuses
        if status not in p.g.flags["statuses"]:
            p.g.flags["statuses"].append(status)
            log(f"Status applied: {status}")
        # If already present, don't log or add again

    shield = int(eff.get("shield", 0))
    if shield:
        p.g.temp_shield += shield
        log(f"+{shield} Shield")

    _add_temp(p, "extra_rolls", int(eff.get("extra_rolls", 0)), dur)
    _add_temp(p, "crit_bonus", float(eff.get("crit_bonus", 0.0)), dur)
    _add_temp(p, "damage_bonus", int(eff.get("damage_bonus", 0)), dur)
    _add_temp(p, "gold_mult", float(eff.get("gold_mult", 0.0)), dur)
    _add_temp(p, "shop_discount", float(eff.get("shop_discount", 0.0)), dur)

def apply_on_enter(game_obj: Any, room: Dict[str, Any], log: LogFn):
    p = PlayerAdapter(game_obj)
    eff = (room.get("mechanics") or {}).get("on_enter")
    _apply_bundle(p, eff, log)

def apply_on_clear(game_obj: Any, room: Dict[str, Any], log: LogFn):
    p = PlayerAdapter(game_obj)
    eff = (room.get("mechanics") or {}).get("on_clear")
    _apply_bundle(p, eff, log)

def apply_on_fail(game_obj: Any, room: Dict[str, Any], log: LogFn):
    p = PlayerAdapter(game_obj)
    eff = (room.get("mechanics") or {}).get("on_fail")
    _apply_bundle(p, eff, log)

def settle_temp_effects(game_obj: Any, phase: str):
    g = PlayerAdapter(game_obj).g
    to_delete = []
    for key, data in list(g.temp_effects.items()):
        dur = data.get("duration", "combat")
        expire = (phase == "after_combat" and dur == "combat") or \
                 (phase == "floor_transition" and dur in ("combat","floor"))
        if expire:
            to_delete.append(key)
    for k in to_delete:
        del g.temp_effects[k]
    if phase == "floor_transition":
        g.temp_shield = 0
        g.shop_discount = 0.0

def get_effective_stats(game_obj: Any) -> Dict[str, Any]:
    g = PlayerAdapter(game_obj).g
    te = getattr(g, "temp_effects", {})
    return {
        "crit_bonus": float(te.get("crit_bonus", {}).get("delta", 0.0)),
        "damage_bonus": int(te.get("damage_bonus", {}).get("delta", 0)),
        "gold_mult": float(te.get("gold_mult", {}).get("delta", 0.0)),
        "extra_rolls": int(te.get("extra_rolls", {}).get("delta", 0)),
        "shop_discount": float(te.get("shop_discount", {}).get("delta", 0.0)),
        "temp_shield": int(getattr(g, "temp_shield", 0)),
        "statuses": list(getattr(g, "flags", {}).get("statuses", [])),
        "has_disarm": int(getattr(g, "flags", {}).get("disarm_token", 0)) > 0,
        "has_escape": int(getattr(g, "flags", {}).get("escape_token", 0)) > 0,
    }
