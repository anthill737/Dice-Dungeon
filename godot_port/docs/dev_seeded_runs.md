# Seeded Runs — Developer Guide

## Overview

Players can start either a normal (random) run or a deterministic seeded
run from the Main Menu.  Seeded runs use `DeterministicRNG` to guarantee
identical sequences given the same seed, enabling run reproduction and
debugging.

## How to Start a Seeded Run

1. Click **Start Adventure** on the Main Menu.
2. A popup appears with two options:
   - **Start Run** — begins a normal run with `DefaultRNG`.
   - **Start Seeded Run** — reveals a seed input field.
3. Enter an integer seed (default: `12345`) and click **Start Seeded Run**.
4. The game transitions to Explorer Mode using `DeterministicRNG(seed)`.

## RNG Modes

| Mode            | RNG Class          | Seed         | Reproducible |
|-----------------|--------------------|-------------|-------------|
| `"default"`     | `DefaultRNG`       | -1 (random) | No          |
| `"deterministic"` | `DeterministicRNG` | user-chosen | Yes         |

## API

### GameSession.start_new_run(options)

```gdscript
GameSession.start_new_run({"rng_mode": "deterministic", "seed": 42})
```

Parameters in `options`:
- `rng_mode` — `"default"` or `"deterministic"` (default: `"default"`)
- `seed` — integer seed (only used when `rng_mode == "deterministic"`)

### SessionService.start_new_run(options)

Delegates to `GameSession.start_new_run(options)` and emits `run_started`.
This is the canonical entry point used by the Main Menu UI.

### Run State Fields

`GameSession` stores the active run configuration:
- `run_rng_mode: String` — `"default"` or `"deterministic"`
- `run_seed: int` — `-1` for random, or the chosen seed

## HUD Seed Display

During gameplay, the Explorer top bar shows the current seed:

- Normal run: `Seed: Random`
- Seeded run: `Seed: 183746 (Deterministic)`

The label uses a small font with slight transparency to remain unobtrusive.

## Session Trace

The session trace records `rng_mode` and `seed` in two places:

### Run Metadata

```json
{
  "seed": 42,
  "rng_type": "DeterministicRNG"
}
```

### `run_started` Event Payload

```json
{
  "type": "run_started",
  "payload": {
    "difficulty": "Normal",
    "rng_mode": "deterministic",
    "seed": 42,
    "max_health": 50,
    "num_dice": 3
  }
}
```

The seed shown in the HUD matches what the trace logs.

## Test Coverage

Tests are in `tests/test_seeded_runs.gd`:

- Default run creates `DefaultRNG` with seed -1
- Deterministic run creates `DeterministicRNG` with correct seed
- Same seed produces identical first roll (reproducibility)
- Different seeds produce different sequences
- Trace metadata records correct `rng_type` and `seed_value`
- `run_started` event payload includes `rng_mode` and `seed`
- Invalid seed input (empty, non-integer) is rejected
- Valid integer seed is accepted
- `StartAdventurePanel` instantiates correctly, seed row hidden by default
- Toggle reveals/hides seed input
- `refresh()` resets panel to defaults
- `start_run()` backward compatibility preserved
