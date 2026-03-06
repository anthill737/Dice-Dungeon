# Godot vs Python — Intentional Gameplay Differences

This document lists intentional behavioral differences between the Godot port
and the Python reference implementation. These are deliberate UX improvements
or architectural choices, not bugs.

## 1. Intro Splash / Loading Screen

**Python**: Shows a `SplashScreen` Toplevel with animated progress dots during
content loading, then transitions to the main menu.

**Godot**: Content loading is near-instant (no I/O bottleneck), so no animated
splash screen is shown. The intro cinematic serves as the equivalent narrative
transition before the threshold area.

## 2. Threshold Tutorial Auto-Open

**Python**: If `tutorial_seen` is False, the tutorial dialog is automatically
shown 200ms after entering the threshold area.

**Godot**: Tutorial must be opened manually via the "Show Tutorial" button in
the threshold area or the "?" button during gameplay. This avoids disrupting
the player's first impression of the threshold content.
