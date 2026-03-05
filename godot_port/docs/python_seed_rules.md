# Python Seed Rules

Extracted from: `rng.py`, `dice_dungeon_explorer.py`, `dice_dungeon_launcher.py`

## Seed Parsing

- Python uses `DeterministicRNG(seed: int = 42)` which wraps `random.Random(seed)`.
- Python's `random.Random` accepts any hashable value; `int` seeds have no range restriction (Python int is arbitrary precision).
- No explicit negative-seed handling; Python `random.Random` accepts negative ints.
- The launcher (`dice_dungeon_launcher.py`) does NOT pass a seed; always uses `DefaultRNG()`.
- Seeded mode is only used in tests via `DeterministicRNG(seed)`.

## Storage

- `DeterministicRNG` stores `self._rng = random.Random(seed)` internally.
- No `initial_seed` property exposed on `DefaultRNG`.
- The game does NOT display seed in the UI (no HUD seed label in Python).

## Godot Parity

- Godot uses `RandomNumberGenerator.seed` which is `int` (64-bit signed).
- Large Python ints will be truncated to 64-bit range.
- Negative seeds: Godot `RandomNumberGenerator` accepts negative ints.
- The entered seed must equal `run_seed` stored, which must equal HUD display and trace seed.
- No conversion or abs() should be applied to the seed value.

## Trace Fields

- `run_started` milestone includes `"seed": run_seed`.
- `SessionTrace.reset(seed, rng_type, rng_mode)` stores seed.
