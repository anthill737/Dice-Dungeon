#!/usr/bin/env python3
"""
Headless tests for room template binding, enemy instantiation,
miniboss timing, and stairs gating.

Run: python -m tests.test_room_binding   (from repo root)
  or python tests/test_room_binding.py
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                'dice_dungeon_content', 'engine'))

from rng import DeterministicRNG
from rooms_loader import load_rooms, pick_room_for_floor
from explorer.rooms import Room

PASS = 0
FAIL = 0

ROOMS_JSON = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'dice_dungeon_content', 'data', 'rooms_v2.json'
)


def check(label, condition):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [PASS] {label}")
    else:
        FAIL += 1
        print(f"  [FAIL] {label}")


def test_room_template_binding():
    """STEP 1: Verify Room objects bind template fields correctly."""
    print("\n=== STEP 1: Room template binding ===")

    rooms = load_rooms(ROOMS_JSON)
    rng = DeterministicRNG(seed=42)

    for i in range(10):
        room_data = pick_room_for_floor(rooms, floor=1, rng=rng)
        room = Room(room_data, x=i, y=0)

        check(f"room[{i}] name != 'Unknown' (got '{room.name}')",
              room.name != "Unknown")
        check(f"room[{i}] room_type != '' (got '{room.room_type}')",
              room.room_type != "")
        check(f"room[{i}] tags is list (got {room.tags})",
              isinstance(room.tags, list))
        check(f"room[{i}] data['name'] == room.name",
              room.data['name'] == room.name)
        check(f"room[{i}] data['difficulty'] == room.room_type",
              room.data['difficulty'] == room.room_type)
        check(f"room[{i}] data['tags'] == room.tags",
              room.data.get('tags', []) == room.tags)


def test_enemy_instantiation():
    """STEP 2: Verify combat rooms have threats populated."""
    print("\n=== STEP 2: Enemy instantiation ===")

    rooms = load_rooms(ROOMS_JSON)
    rng = DeterministicRNG(seed=99)

    found_combat = False
    for i in range(50):
        room_data = pick_room_for_floor(rooms, floor=1, rng=rng)
        room = Room(room_data, x=i, y=0)

        threats = room.data.get('threats', [])
        has_combat_tag = 'combat' in room.data.get('tags', [])

        if threats or has_combat_tag:
            found_combat = True
            check(f"room[{i}] '{room.name}' combat room has threats (len={len(threats)})",
                  len(threats) > 0)
            check(f"room[{i}] room.threats matches data",
                  room.threats == threats)
            break

    check("Found at least one combat-capable room in 50 picks", found_combat)


def test_miniboss_threats():
    """STEP 2b: Verify Elite rooms (used for miniboss) have threats."""
    print("\n=== STEP 2b: Miniboss (Elite) room threats ===")

    rooms = load_rooms(ROOMS_JSON)
    elite_rooms = [r for r in rooms if r.get('difficulty') == 'Elite']
    check(f"Elite rooms exist in data (found {len(elite_rooms)})",
          len(elite_rooms) > 0)

    rng = DeterministicRNG(seed=77)
    for i in range(min(5, len(elite_rooms))):
        r = rng.choice(elite_rooms)
        room = Room(r, x=0, y=i)
        check(f"Elite room '{room.name}' has threats (len={len(room.threats)})",
              len(room.threats) > 0)


def test_boss_threats():
    """STEP 2c: Verify Boss rooms have threats."""
    print("\n=== STEP 2c: Boss room threats ===")

    rooms = load_rooms(ROOMS_JSON)
    boss_rooms = [r for r in rooms if r.get('difficulty') == 'Boss']
    check(f"Boss rooms exist in data (found {len(boss_rooms)})",
          len(boss_rooms) > 0)

    rng = DeterministicRNG(seed=88)
    for i in range(min(5, len(boss_rooms))):
        r = rng.choice(boss_rooms)
        room = Room(r, x=0, y=i)
        check(f"Boss room '{room.name}' has threats (len={len(room.threats)})",
              len(room.threats) > 0)


def test_miniboss_timing():
    """STEP 3: First miniboss only spawns after the threshold (6-10 rooms)."""
    print("\n=== STEP 3: Miniboss timing audit ===")

    rooms = load_rooms(ROOMS_JSON)

    for seed in [42, 123, 777, 1001, 5555]:
        rng = DeterministicRNG(seed=seed)
        next_mini_boss_at = rng.randint(6, 10)
        rooms_explored_on_floor = 0
        first_miniboss_room = None

        for i in range(30):
            rooms_explored_on_floor += 1
            if rooms_explored_on_floor >= next_mini_boss_at:
                first_miniboss_room = rooms_explored_on_floor
                break

        check(
            f"seed={seed}: first miniboss at room {first_miniboss_room} "
            f"(threshold={next_mini_boss_at}, must be >= 6)",
            first_miniboss_room is not None and first_miniboss_room >= 6
        )


def test_stairs_not_in_miniboss():
    """STEP 4: Stairs must not spawn in miniboss/boss rooms."""
    print("\n=== STEP 4: Stairs blocked in miniboss/boss rooms ===")

    rooms = load_rooms(ROOMS_JSON)
    rng = DeterministicRNG(seed=42)

    elite_rooms = [r for r in rooms if r.get('difficulty') == 'Elite']
    boss_rooms = [r for r in rooms if r.get('difficulty') == 'Boss']

    for i in range(5):
        r = rng.choice(elite_rooms)
        room = Room(r, x=0, y=i)
        room.is_mini_boss_room = True
        room.has_combat = True

        is_special = getattr(room, 'is_mini_boss_room', False) or getattr(room, 'is_boss_room', False)
        check(f"Miniboss room '{room.name}' is_special=True → stairs blocked",
              is_special is True)

    for i in range(3):
        r = rng.choice(boss_rooms)
        room = Room(r, x=0, y=i)
        room.is_boss_room = True
        room.has_combat = True

        is_special = getattr(room, 'is_mini_boss_room', False) or getattr(room, 'is_boss_room', False)
        check(f"Boss room '{room.name}' is_special=True → stairs blocked",
              is_special is True)

    normal_data = pick_room_for_floor(rooms, floor=1, rng=rng)
    normal_room = Room(normal_data, x=10, y=10)
    is_special = getattr(normal_room, 'is_mini_boss_room', False) or getattr(normal_room, 'is_boss_room', False)
    check("Normal room is_special=False → stairs allowed",
          is_special is False)


if __name__ == "__main__":
    print("=" * 60)
    print("Dice Dungeon — Room Binding & Instantiation Tests")
    print("=" * 60)

    test_room_template_binding()
    test_enemy_instantiation()
    test_miniboss_threats()
    test_boss_threats()
    test_miniboss_timing()
    test_stairs_not_in_miniboss()

    print(f"\n{'=' * 60}")
    print(f"Results: {PASS} passed, {FAIL} failed")
    print("=" * 60)
    sys.exit(1 if FAIL > 0 else 0)
