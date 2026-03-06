# Godot vs Python — Intentional Gameplay Differences

This document lists intentional behavioral differences between the Godot port
and the Python reference implementation. These are deliberate UX improvements
or architectural choices, not bugs.

## 1. Locked Container Flow — Direct "Use Lockpick"

**Python**: In the ground items dialog, locked containers show "Use Lockpick"
which calls `use_lockpick_on_container()` to directly consume a Lockpick Kit
and unlock the container. Separately, from the inventory screen, using a
Lockpick Kit as an item grants a `disarm_token` flag for traps.

**Godot**: Same behavior. The "Use Lockpick" button in the ground items panel
calls `InventoryEngine.use_lockpick_on_container()` which directly unlocks the
container and consumes the kit. The inventory "Use" path for lockpick-type
items still grants `disarm_token` for traps.

**Status**: This is Python parity, not a difference. Both systems use the same
dual-path approach (direct unlock for containers, token for traps).

## 2. Intro Splash / Loading Screen

**Python**: Shows a `SplashScreen` Toplevel with animated progress dots during
content loading, then transitions to the main menu.

**Godot**: Content loading is near-instant (no I/O bottleneck), so no splash
screen is shown. The intro cinematic serves as the equivalent narrative
transition.

## 3. Threshold Tutorial Auto-Open

**Python**: If `tutorial_seen` is False, the tutorial is automatically shown
200ms after entering the threshold area.

**Godot**: Tutorial must be opened manually via the "Show Tutorial" button in
the threshold area. This avoids disrupting the player's first impression of
the threshold content.

## 4. Container Loot Pools

**Python**: Uses `container_definitions.json` loot pools with a two-step
category selection (`rng.choice(categories)` then `rng.choice(pool)`).

**Godot**: Uses the same JSON-driven loot pools via `ContainerResolver`.
Per-container gold ranges and item pools match Python. However, the RNG call
count differs (2 calls for item vs 1 in old code), so seeded container search
results may differ from traces captured before this refactor.

## 5. Ground Items Panel

**Python**: Ground items are shown in a dialog with sections for containers,
gold, items, uncollected, and dropped items. Searched containers with
remaining loot are re-shown with "Open" button.

**Godot**: Same behavior via the `GroundItemsPanel` overlay. All state
mutation goes through `ExplorationEngine` methods, then UI re-renders from
authoritative room state.
