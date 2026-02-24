"""
Injectable RNG system for Dice Dungeon.

Provides a unified interface for all randomness so that gameplay can be made
deterministic (same seed → same results) without changing any probabilities.

Usage:
    from rng import DefaultRNG, DeterministicRNG

    # Normal gameplay (indistinguishable from bare `random` module):
    rng = DefaultRNG()

    # Repeatable test run:
    rng = DeterministicRNG(seed=42)

    rng.randint(1, 6)
    rng.choice(["a", "b", "c"])
    rng.random()
    rng.shuffle(some_list)
    rng.sample(population, k)
"""

from abc import ABC, abstractmethod
import random as _random
from typing import Any, List, MutableSequence, Sequence, TypeVar

T = TypeVar("T")


class RNG(ABC):
    """Abstract interface that every RNG implementation must satisfy."""

    @abstractmethod
    def randint(self, a: int, b: int) -> int:
        """Return random int N such that a <= N <= b (inclusive)."""

    @abstractmethod
    def choice(self, seq: Sequence[T]) -> T:
        """Return a random element from non-empty *seq*."""

    @abstractmethod
    def shuffle(self, seq: MutableSequence) -> None:
        """Shuffle *seq* in-place."""

    @abstractmethod
    def random(self) -> float:
        """Return a float in [0.0, 1.0)."""

    @abstractmethod
    def sample(self, population: Sequence[T], k: int) -> List[T]:
        """Return *k* unique elements chosen from *population*."""


class DefaultRNG(RNG):
    """Wraps Python's module-level ``random`` functions.

    Produces the same statistical behaviour the game shipped with.
    """

    def randint(self, a: int, b: int) -> int:
        return _random.randint(a, b)

    def choice(self, seq: Sequence[T]) -> T:
        return _random.choice(seq)

    def shuffle(self, seq: MutableSequence) -> None:
        _random.shuffle(seq)

    def random(self) -> float:
        return _random.random()

    def sample(self, population: Sequence[T], k: int) -> List[T]:
        return _random.sample(population, k)


class DeterministicRNG(RNG):
    """Seeded RNG that produces repeatable sequences.

    Backed by its own ``random.Random`` instance so it never interferes
    with the global random state.
    """

    def __init__(self, seed: int = 0):
        self._rng = _random.Random(seed)

    def randint(self, a: int, b: int) -> int:
        return self._rng.randint(a, b)

    def choice(self, seq: Sequence[T]) -> T:
        return self._rng.choice(seq)

    def shuffle(self, seq: MutableSequence) -> None:
        self._rng.shuffle(seq)

    def random(self) -> float:
        return self._rng.random()

    def sample(self, population: Sequence[T], k: int) -> List[T]:
        return self._rng.sample(population, k)
