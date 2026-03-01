#!/usr/bin/env python3
"""
Parity reference runner (Python side).

Runs small deterministic scenarios and outputs JSON to stdout.
The Godot side runs the same scenarios and the parity test diffs the results.

Usage:
    python tools/parity/python_runner.py <scenario_id> <seed>

Since Python and Godot use different PRNG algorithms, scenarios use
pre-scripted dice values so both sides compute on identical inputs.
The seed is used only for RNG-dependent sub-decisions (crit checks, etc.)
where we compare logic paths rather than exact random values.
"""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from collections import Counter


# ---------- Combo scoring (matches Python dice.py / Godot dice_roller.gd) ----------

def calc_combo_bonus(values: list[int]) -> int:
    if not any(values):
        return 0

    counts = Counter(values)
    bonus = 0

    for value, count in counts.items():
        if count >= 5:
            bonus += value * 20
        elif count == 4:
            bonus += value * 10
        elif count == 3:
            bonus += value * 5
        elif count == 2:
            bonus += value * 2

    sorted_counts = sorted(counts.values(), reverse=True)
    if len(sorted_counts) >= 2 and sorted_counts[0] == 3 and sorted_counts[1] == 2:
        bonus += 50

    if len(counts) == 1 and len(values) >= 5:
        value = list(counts.keys())[0]
        bonus += value * 15

    sorted_unique = sorted(set(values))
    if sorted_unique == [1, 2, 3, 4, 5, 6]:
        bonus += 40
    elif len(sorted_unique) >= 4:
        for i in range(len(sorted_unique) - 3):
            run = sorted_unique[i:i+4]
            if run == list(range(run[0], run[0] + 4)):
                bonus += 25
                break

    return bonus


def calc_total_damage(values: list[int], multiplier: float = 1.0, damage_bonus: int = 0) -> int:
    base = sum(values)
    combo = calc_combo_bonus(values)
    return int(base * multiplier) + combo + damage_bonus


# ---------- Mechanics engine (matches Python mechanics_engine.py) ----------

def apply_effect_bundle(state: dict, eff: dict) -> list[str]:
    logs = []
    if not eff:
        return logs
    dur = eff.get("duration", "combat")

    if eff.get("cleanse"):
        state["statuses"] = []
        logs.append("Cleansed all negative statuses")

    if eff.get("disarm_token"):
        state["disarm_token"] = state.get("disarm_token", 0) + 1
        logs.append("Gained a disarm token")

    if eff.get("escape_token"):
        state["escape_token"] = state.get("escape_token", 0) + 1
        logs.append("Gained an escape token")

    item = eff.get("item")
    if item:
        state.setdefault("ground_items", []).append(item)
        logs.append(f"Found item: {item} (on ground)")

    status = eff.get("status")
    if status and status not in state.get("statuses", []):
        state.setdefault("statuses", []).append(status)
        logs.append(f"Status applied: {status}")

    shield = int(eff.get("shield", 0))
    if shield:
        state["temp_shield"] = state.get("temp_shield", 0) + shield
        logs.append(f"+{shield} Shield")

    for key in ("extra_rolls", "crit_bonus", "damage_bonus", "gold_mult", "shop_discount"):
        delta = eff.get(key, 0)
        if isinstance(delta, float) and delta == 0.0:
            continue
        if isinstance(delta, int) and delta == 0:
            continue
        te = state.setdefault("temp_effects", {})
        existing = te.get(key, {"delta": 0, "duration": dur})
        if isinstance(delta, float) or isinstance(existing["delta"], float):
            existing["delta"] = float(existing["delta"]) + float(delta)
        else:
            existing["delta"] = int(existing["delta"]) + int(delta)
        existing["duration"] = dur
        te[key] = existing

    return logs


# ---------- Scenarios ----------

def scenario_s1(seed: int) -> dict:
    """Dice roll/lock/reroll and compute attack damage."""
    dice_values_roll1 = [2, 6, 5]
    locked = [False, True, True]  # lock the 6 and 5
    dice_values_roll2 = [4, 6, 5]  # reroll first die: 2 -> 4 (scripted)

    combo_r1 = calc_combo_bonus(dice_values_roll1)
    damage_r1 = calc_total_damage(dice_values_roll1, multiplier=1.0, damage_bonus=0)

    combo_r2 = calc_combo_bonus(dice_values_roll2)
    damage_r2 = calc_total_damage(dice_values_roll2, multiplier=1.0, damage_bonus=0)

    # With multiplier and bonus
    damage_r2_boosted = calc_total_damage(dice_values_roll2, multiplier=1.5, damage_bonus=3)

    return {
        "scenario_id": "S1",
        "seed": seed,
        "initial_state": {"dice": [0, 0, 0]},
        "actions": [
            {"action": "roll", "result": dice_values_roll1},
            {"action": "lock", "indices": [1, 2]},
            {"action": "roll", "result": dice_values_roll2},
        ],
        "final_state": {
            "dice_after_roll1": dice_values_roll1,
            "combo_roll1": combo_r1,
            "damage_roll1": damage_r1,
            "dice_after_roll2": dice_values_roll2,
            "combo_roll2": combo_r2,
            "damage_roll2": damage_r2,
            "damage_roll2_boosted": damage_r2_boosted,
        },
        "log": [
            f"Roll 1: {dice_values_roll1}, combo={combo_r1}, damage={damage_r1}",
            f"Locked indices [1, 2]",
            f"Roll 2: {dice_values_roll2}, combo={combo_r2}, damage={damage_r2}",
            f"Boosted (mult=1.5, bonus=3): {damage_r2_boosted}",
        ],
    }


def scenario_s2(seed: int) -> dict:
    """Apply mechanics effects on room enter/clear."""
    state = {
        "health": 50,
        "max_health": 50,
        "crit_chance": 0.1,
        "damage_bonus": 0,
        "temp_shield": 0,
        "temp_effects": {},
        "statuses": [],
        "ground_items": [],
        "disarm_token": 0,
        "escape_token": 0,
    }
    initial_state = dict(state)
    initial_state["temp_effects"] = dict(state["temp_effects"])

    room = {
        "name": "Test Chamber",
        "mechanics": {
            "on_enter": {"crit_bonus": 0.05, "shield": 8, "extra_rolls": 1},
            "on_clear": {"item": "Old Key", "escape_token": True},
            "on_fail": {"status": "poison"},
        },
    }

    logs = []

    # on_enter
    on_enter = room["mechanics"]["on_enter"]
    logs.extend(apply_effect_bundle(state, on_enter))

    state_after_enter = {
        "temp_effects": dict(state.get("temp_effects", {})),
        "temp_shield": state["temp_shield"],
        "ground_items": list(state.get("ground_items", [])),
    }

    # on_clear
    on_clear = room["mechanics"]["on_clear"]
    logs.extend(apply_effect_bundle(state, on_clear))

    return {
        "scenario_id": "S2",
        "seed": seed,
        "initial_state": initial_state,
        "actions": [
            {"action": "apply_on_enter", "effects": on_enter},
            {"action": "apply_on_clear", "effects": on_clear},
        ],
        "final_state": {
            "temp_effects": state.get("temp_effects", {}),
            "temp_shield": state["temp_shield"],
            "ground_items": state.get("ground_items", []),
            "escape_token": state.get("escape_token", 0),
            "statuses": state.get("statuses", []),
            "state_after_enter": state_after_enter,
        },
        "log": logs,
    }


def scenario_s3(seed: int) -> dict:
    """Simple 1-enemy combat for 2 turns with scripted dice."""
    enemy_hp = 40
    enemy_dice_count = 2
    player_hp = 50
    damage_bonus = 0
    multiplier = 1.0
    crit_chance = 0.0  # no crits for deterministic comparison

    # Scripted dice: player and enemy
    turns = [
        {"player_dice": [5, 6, 4], "enemy_dice": [3, 2]},
        {"player_dice": [6, 6, 3], "enemy_dice": [5, 1]},
    ]

    logs = []
    current_enemy_hp = enemy_hp
    current_player_hp = player_hp
    turn_results = []

    for i, turn in enumerate(turns):
        pd = turn["player_dice"]
        ed = turn["enemy_dice"]

        p_combo = calc_combo_bonus(pd)
        p_damage = calc_total_damage(pd, multiplier, damage_bonus)
        current_enemy_hp -= p_damage
        enemy_killed = current_enemy_hp <= 0

        e_damage = sum(ed)
        if not enemy_killed:
            current_player_hp -= e_damage
        else:
            e_damage = 0

        turn_result = {
            "turn": i + 1,
            "player_dice": pd,
            "player_combo": p_combo,
            "player_damage": p_damage,
            "enemy_dice": ed,
            "enemy_damage": e_damage,
            "enemy_hp_after": max(0, current_enemy_hp),
            "player_hp_after": current_player_hp,
            "enemy_killed": enemy_killed,
        }
        turn_results.append(turn_result)
        logs.append(f"Turn {i+1}: player {pd}={p_damage}dmg, enemy {ed}={e_damage}dmg")

        if enemy_killed:
            logs.append(f"Enemy defeated on turn {i+1}")
            break

    return {
        "scenario_id": "S3",
        "seed": seed,
        "initial_state": {
            "player_hp": player_hp,
            "enemy_hp": enemy_hp,
            "enemy_dice": enemy_dice_count,
        },
        "actions": [{"turn": t["turn"], "player_dice": t["player_dice"],
                     "enemy_dice": t["enemy_dice"]} for t in turn_results],
        "final_state": {
            "player_hp": current_player_hp,
            "enemy_hp": max(0, current_enemy_hp),
            "enemy_killed": current_enemy_hp <= 0,
            "turns_played": len(turn_results),
            "turn_results": turn_results,
        },
        "log": logs,
    }


SCENARIOS = {
    "S1": scenario_s1,
    "S2": scenario_s2,
    "S3": scenario_s3,
}


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <scenario_id> <seed>", file=sys.stderr)
        sys.exit(1)

    scenario_id = sys.argv[1]
    seed = int(sys.argv[2])

    if scenario_id not in SCENARIOS:
        print(f"Unknown scenario: {scenario_id}. Available: {list(SCENARIOS.keys())}", file=sys.stderr)
        sys.exit(1)

    result = SCENARIOS[scenario_id](seed)
    print(json.dumps(result, indent=2, default=str))


if __name__ == "__main__":
    main()
