"""
Deterministic RNG verification tests.

Run with:
    python -m pytest tests/test_rng_determinism.py -v
    # or simply:
    python tests/test_rng_determinism.py
"""

import sys
import os

# Ensure project root is on the path so ``rng`` can be imported.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rng import DefaultRNG, DeterministicRNG


# ---------------------------------------------------------------------------
# 1) Same seed → identical sequences
# ---------------------------------------------------------------------------

def test_same_seed_produces_identical_randint():
    a = DeterministicRNG(seed=42)
    b = DeterministicRNG(seed=42)
    results_a = [a.randint(1, 100) for _ in range(50)]
    results_b = [b.randint(1, 100) for _ in range(50)]
    assert results_a == results_b, "randint sequences should match for same seed"


def test_same_seed_produces_identical_choice():
    items = ["sword", "shield", "potion", "scroll", "key"]
    a = DeterministicRNG(seed=99)
    b = DeterministicRNG(seed=99)
    results_a = [a.choice(items) for _ in range(30)]
    results_b = [b.choice(items) for _ in range(30)]
    assert results_a == results_b, "choice sequences should match for same seed"


def test_same_seed_produces_identical_random():
    a = DeterministicRNG(seed=7)
    b = DeterministicRNG(seed=7)
    results_a = [a.random() for _ in range(30)]
    results_b = [b.random() for _ in range(30)]
    assert results_a == results_b, "random() sequences should match for same seed"


def test_same_seed_produces_identical_shuffle():
    a = DeterministicRNG(seed=123)
    b = DeterministicRNG(seed=123)
    list_a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    list_b = list(list_a)
    a.shuffle(list_a)
    b.shuffle(list_b)
    assert list_a == list_b, "shuffle results should match for same seed"


def test_same_seed_produces_identical_sample():
    population = list(range(20))
    a = DeterministicRNG(seed=55)
    b = DeterministicRNG(seed=55)
    results_a = a.sample(population, 5)
    results_b = b.sample(population, 5)
    assert results_a == results_b, "sample results should match for same seed"


# ---------------------------------------------------------------------------
# 2) Different seeds → different sequences
# ---------------------------------------------------------------------------

def test_different_seeds_differ():
    a = DeterministicRNG(seed=1)
    b = DeterministicRNG(seed=2)
    results_a = [a.randint(1, 1000) for _ in range(20)]
    results_b = [b.randint(1, 1000) for _ in range(20)]
    assert results_a != results_b, "different seeds should (almost certainly) produce different sequences"


# ---------------------------------------------------------------------------
# 3) DefaultRNG produces valid outputs (smoke test)
# ---------------------------------------------------------------------------

def test_default_rng_basic():
    rng = DefaultRNG()
    val = rng.randint(1, 6)
    assert 1 <= val <= 6

    chosen = rng.choice(["a", "b", "c"])
    assert chosen in ("a", "b", "c")

    f = rng.random()
    assert 0.0 <= f < 1.0

    lst = [1, 2, 3, 4, 5]
    rng.shuffle(lst)
    assert sorted(lst) == [1, 2, 3, 4, 5]

    sampled = rng.sample(range(20), 3)
    assert len(sampled) == 3
    assert len(set(sampled)) == 3


# ---------------------------------------------------------------------------
# 4) Simulated game-logic slice: dice roll + loot roll
# ---------------------------------------------------------------------------

def test_deterministic_game_slice():
    """Simulate a small game-logic sequence twice with the same seed."""

    def run_game_slice(rng):
        results = {}

        # Dice rolling (3 dice)
        dice = [rng.randint(1, 6) for _ in range(3)]
        results["dice"] = dice

        # Crit check
        results["is_crit"] = rng.random() < 0.1

        # Enemy HP variance
        base_hp = 50
        results["enemy_hp"] = base_hp + rng.randint(-5, 10)

        # Loot roll
        if rng.random() < 0.6:
            loot_type = rng.choice(["gold", "gold", "item", "health"])
        else:
            loot_type = "gold"
        results["loot_type"] = loot_type

        if loot_type == "gold":
            results["gold"] = rng.randint(20, 50)
        elif loot_type == "health":
            results["heal"] = rng.randint(15, 30)
        else:
            items = ["Weighted Die", "Hourglass Shard", "Lucky Chip", "Lockpick Kit"]
            results["item"] = rng.choice(items)

        # Combat flavor text
        taunts = ["Ha!", "You'll pay!", "Is that all?", "Fool!", "Try harder!"]
        results["taunt"] = rng.choice(taunts)

        return results

    r1 = run_game_slice(DeterministicRNG(seed=2025))
    r2 = run_game_slice(DeterministicRNG(seed=2025))
    assert r1 == r2, f"Same seed should produce identical game slice.\n  Run 1: {r1}\n  Run 2: {r2}"


# ---------------------------------------------------------------------------
# 5) Rooms loader determinism
# ---------------------------------------------------------------------------

def test_rooms_loader_determinism():
    """pick_room_for_floor returns the same room given the same seed."""
    sys.path.insert(0, os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "dice_dungeon_content", "engine"
    ))
    from rooms_loader import pick_room_for_floor

    fake_rooms = [
        {"id": i, "name": f"Room{i}", "difficulty": "Easy",
         "threats": [], "history": "", "flavor": "", "discoverables": [],
         "tags": []}
        for i in range(20)
    ]

    rng_a = DeterministicRNG(seed=77)
    rng_b = DeterministicRNG(seed=77)

    picks_a = [pick_room_for_floor(fake_rooms, floor=1, rng=rng_a)["id"] for _ in range(10)]
    picks_b = [pick_room_for_floor(fake_rooms, floor=1, rng=rng_b)["id"] for _ in range(10)]
    assert picks_a == picks_b, "Room picks should be deterministic with same seed"


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    passed = 0
    failed = 0
    for t in tests:
        try:
            t()
            print(f"  PASS  {t.__name__}")
            passed += 1
        except Exception as e:
            print(f"  FAIL  {t.__name__}: {e}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
