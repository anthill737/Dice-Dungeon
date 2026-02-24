#!/usr/bin/env python3
"""
Determinism verification for the Dice Dungeon RNG system.

Run: python -m tests.test_rng_determinism   (from repo root)
  or python tests/test_rng_determinism.py

Tests:
  1. Two DeterministicRNG instances with the same seed produce identical
     sequences for randint, choice, random, shuffle, and sample.
  2. A different seed produces different sequences.
  3. DefaultRNG works without crashing (smoke test).
  4. A small slice of gameplay logic (loot roll, combat roll) produces
     identical results when driven by the same seed.
"""

import sys
import os

# Ensure repo root is on the path so imports work
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rng import DefaultRNG, DeterministicRNG

PASS = 0
FAIL = 0


def check(label, condition):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [PASS] {label}")
    else:
        FAIL += 1
        print(f"  [FAIL] {label}")


def test_same_seed_produces_identical_sequences():
    """Two DeterministicRNG with same seed must be identical."""
    print("\n=== Test 1: Same seed → identical sequences ===")
    seed = 12345
    a = DeterministicRNG(seed)
    b = DeterministicRNG(seed)

    ints_a = [a.randint(1, 100) for _ in range(50)]
    ints_b = [b.randint(1, 100) for _ in range(50)]
    check("randint sequences match", ints_a == ints_b)

    a = DeterministicRNG(seed)
    b = DeterministicRNG(seed)
    pool = list(range(20))
    choices_a = [a.choice(pool) for _ in range(30)]
    choices_b = [b.choice(pool) for _ in range(30)]
    check("choice sequences match", choices_a == choices_b)

    a = DeterministicRNG(seed)
    b = DeterministicRNG(seed)
    floats_a = [a.random() for _ in range(30)]
    floats_b = [b.random() for _ in range(30)]
    check("random() sequences match", floats_a == floats_b)

    a = DeterministicRNG(seed)
    b = DeterministicRNG(seed)
    list_a = list(range(10))
    list_b = list(range(10))
    a.shuffle(list_a)
    b.shuffle(list_b)
    check("shuffle produces same order", list_a == list_b)

    a = DeterministicRNG(seed)
    b = DeterministicRNG(seed)
    pop = list(range(20))
    sample_a = a.sample(pop, 5)
    sample_b = b.sample(pop, 5)
    check("sample produces same elements", sample_a == sample_b)


def test_different_seed_produces_different_sequences():
    """Different seeds must produce different sequences."""
    print("\n=== Test 2: Different seed → different sequences ===")
    a = DeterministicRNG(111)
    b = DeterministicRNG(222)
    ints_a = [a.randint(1, 1000) for _ in range(20)]
    ints_b = [b.randint(1, 1000) for _ in range(20)]
    check("randint sequences differ", ints_a != ints_b)

    a = DeterministicRNG(111)
    b = DeterministicRNG(222)
    floats_a = [a.random() for _ in range(20)]
    floats_b = [b.random() for _ in range(20)]
    check("random() sequences differ", floats_a != floats_b)


def test_default_rng_works():
    """DefaultRNG should function identically to stdlib random."""
    print("\n=== Test 3: DefaultRNG smoke test ===")
    rng = DefaultRNG()
    val = rng.randint(1, 6)
    check("randint returns int in range", isinstance(val, int) and 1 <= val <= 6)

    pool = ["a", "b", "c"]
    c = rng.choice(pool)
    check("choice returns element from pool", c in pool)

    f = rng.random()
    check("random() returns float in [0,1)", isinstance(f, float) and 0.0 <= f < 1.0)

    lst = [1, 2, 3, 4, 5]
    rng.shuffle(lst)
    check("shuffle keeps same elements", sorted(lst) == [1, 2, 3, 4, 5])

    s = rng.sample(range(100), 5)
    check("sample returns k unique elements", len(s) == 5 and len(set(s)) == 5)


def test_gameplay_determinism():
    """
    Simulate a small slice of gameplay logic twice with the same seed
    and verify outcomes are identical.
    """
    print("\n=== Test 4: Gameplay logic determinism ===")

    def simulate_combat_round(rng):
        """Simulate one combat round: dice rolls, crit check, gold reward."""
        dice = [rng.randint(1, 6) for _ in range(5)]
        crit = rng.random() < 0.15
        damage = sum(dice) * (2 if crit else 1)
        gold = rng.randint(10, 30) + 5
        return dice, crit, damage, gold

    def simulate_loot_roll(rng):
        """Simulate container loot generation."""
        loot_roll = rng.random()
        if loot_roll < 0.15:
            return "nothing", 0, None
        elif loot_roll < 0.50:
            gold = rng.randint(5, 15)
            return "gold", gold, None
        elif loot_roll < 0.80:
            items = ["Health Potion", "Weighted Die", "Lucky Chip", "Honey Jar"]
            item = rng.choice(items)
            return "item", 0, item
        else:
            gold = rng.randint(5, 15)
            items = ["Health Potion", "Weighted Die", "Lucky Chip", "Honey Jar"]
            item = rng.choice(items)
            return "both", gold, item

    def simulate_navigation(rng):
        """Simulate room exploration decisions."""
        has_combat = rng.random() < 0.4
        has_stairs = rng.random() < 0.1
        enemies = ["Goblin", "Skeleton", "Rat", "Spider", "Bat"]
        enemy = rng.choice(enemies) if has_combat else None
        return has_combat, has_stairs, enemy

    seed = 98765

    # Run 1
    rng1 = DeterministicRNG(seed)
    combat1 = [simulate_combat_round(rng1) for _ in range(10)]
    loot1 = [simulate_loot_roll(rng1) for _ in range(10)]
    nav1 = [simulate_navigation(rng1) for _ in range(10)]

    # Run 2
    rng2 = DeterministicRNG(seed)
    combat2 = [simulate_combat_round(rng2) for _ in range(10)]
    loot2 = [simulate_loot_roll(rng2) for _ in range(10)]
    nav2 = [simulate_navigation(rng2) for _ in range(10)]

    check("combat rounds identical across runs", combat1 == combat2)
    check("loot rolls identical across runs", loot1 == loot2)
    check("navigation decisions identical across runs", nav1 == nav2)

    # Verify different seed gives different results
    rng3 = DeterministicRNG(seed + 1)
    combat3 = [simulate_combat_round(rng3) for _ in range(10)]
    check("different seed → different combat outcomes", combat1 != combat3)


def test_pick_room_determinism():
    """Verify pick_room_for_floor produces identical results with same seed."""
    print("\n=== Test 5: pick_room_for_floor determinism ===")
    try:
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                        'dice_dungeon_content', 'engine'))
        from rooms_loader import pick_room_for_floor

        fake_rooms = [
            {"id": i, "name": f"Room {i}", "difficulty": d,
             "threats": [], "history": "", "flavor": "", "discoverables": [], "tags": []}
            for i, d in enumerate(["Easy"] * 5 + ["Medium"] * 5 + ["Hard"] * 3)
        ]

        seed = 77777
        rng_a = DeterministicRNG(seed)
        rng_b = DeterministicRNG(seed)

        picks_a = [pick_room_for_floor(fake_rooms, floor=2, rng=rng_a)["id"] for _ in range(20)]
        picks_b = [pick_room_for_floor(fake_rooms, floor=2, rng=rng_b)["id"] for _ in range(20)]
        check("pick_room_for_floor same seed → same rooms", picks_a == picks_b)

        rng_c = DeterministicRNG(seed + 1)
        picks_c = [pick_room_for_floor(fake_rooms, floor=2, rng=rng_c)["id"] for _ in range(20)]
        check("pick_room_for_floor different seed → different rooms", picks_a != picks_c)
    except ImportError as e:
        print(f"  [SKIP] Could not import rooms_loader: {e}")


if __name__ == "__main__":
    print("=" * 60)
    print("Dice Dungeon RNG Determinism Verification")
    print("=" * 60)

    test_same_seed_produces_identical_sequences()
    test_different_seed_produces_different_sequences()
    test_default_rng_works()
    test_gameplay_determinism()
    test_pick_room_determinism()

    print(f"\n{'=' * 60}")
    print(f"Results: {PASS} passed, {FAIL} failed")
    print("=" * 60)
    sys.exit(1 if FAIL > 0 else 0)
