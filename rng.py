"""
RNG (Random Number Generator) abstraction layer for Dice Dungeon.

Provides an injectable RNG interface so that game logic can be run
deterministically (same seed → same outcome) for testing and replay,
while defaulting to standard Python randomness in normal play.
"""

import random as _random
from abc import ABC, abstractmethod


class RNG(ABC):
    """Abstract RNG interface used by all game subsystems."""

    @abstractmethod
    def randint(self, a: int, b: int) -> int:
        """Return random int N such that a <= N <= b (inclusive)."""

    @abstractmethod
    def choice(self, seq):
        """Return a random element from non-empty sequence *seq*."""

    @abstractmethod
    def random(self) -> float:
        """Return a random float in [0.0, 1.0)."""

    @abstractmethod
    def shuffle(self, seq) -> None:
        """Shuffle sequence *seq* in place."""

    @abstractmethod
    def sample(self, population, k: int) -> list:
        """Return *k* unique elements chosen from *population*."""


class DefaultRNG(RNG):
    """Wraps Python's module-level ``random`` functions (non-deterministic)."""

    def randint(self, a: int, b: int) -> int:
        return _random.randint(a, b)

    def choice(self, seq):
        return _random.choice(seq)

    def random(self) -> float:
        return _random.random()

    def shuffle(self, seq) -> None:
        _random.shuffle(seq)

    def sample(self, population, k: int) -> list:
        return _random.sample(population, k)


class DeterministicRNG(RNG):
    """Seeded RNG that produces repeatable sequences.

    Uses an independent ``random.Random`` instance so it never
    interferes with the module-level PRNG.
    """

    def __init__(self, seed: int = 42):
        self._rng = _random.Random(seed)

    def randint(self, a: int, b: int) -> int:
        return self._rng.randint(a, b)

    def choice(self, seq):
        return self._rng.choice(seq)

    def random(self) -> float:
        return self._rng.random()

    def shuffle(self, seq) -> None:
        self._rng.shuffle(seq)

    def sample(self, population, k: int) -> list:
        return self._rng.sample(population, k)
