# Dice Dungeon Content Pack — Reference Guide

This folder defines all discoverable content, items, mechanics, effects, and statuses
used by the Dice Dungeon RPG. Copilot and human developers can use it to understand
how rooms, items, and effects interrelate.

---

## Folder structure
dice_dungeon_content/
├─ data/
│ ├─ rooms_v2.json ← all 100 rooms with tags + mechanics
│ ├─ items_definitions.json ← every collectible item and its effect
│ ├─ mechanics_definitions.json ← reusable mechanic templates
│ ├─ effects_catalog.json ← what each mechanic key means
│ └─ statuses_catalog.json ← all status names and suggested effects
├─ schemas/
│ ├─ rooms_v2.schema.json ← json-schema for validation
│ └─ room_mechanics.schema.json ← schema for mechanics blocks
└─ engine/
├─ rooms_loader.py ← loads & picks rooms by floor
├─ mechanics_engine.py ← applies mechanics/effects to the player
└─ integration_hooks.py ← bridges the game class to this content


---

## Core concepts

### 1. **Rooms**
Each entry in `rooms_v2.json` defines:
- `tags`: room type (combat, trap, puzzle, etc.)
- `mechanics`: effect bundles with optional triggers:
  - `on_enter`, `on_clear`, `on_fail`
  - Each bundle can contain any fields from `effects_catalog.json`.

### 2. **Items**
Every item name appearing in rooms is declared in `items_definitions.json`.
Each has:
- `type`: buff, token, tool, sellable, lore, etc.
- Optional direct effect keys (`heal`, `crit_bonus`, etc.)
- `desc`: human-readable description.

### 3. **Mechanics templates**
`mechanics_definitions.json` lists reusable bundles like `heal_small`, `damage_large`, etc.
These are shorthand patterns for content generation or AI-assisted room creation.

### 4. **Effect keys**
`effects_catalog.json` explains what every effect field does.
Used by the engine and as self-documentation for Copilot.

### 5. **Statuses**
`statuses_catalog.json` defines all named conditions—both debuffs and buffs—with
their suggested numeric impact (`tick_damage`, `crit_bonus`, etc.).

---

## Engine integration summary
The Python engine in `engine/` is data-driven:
- `rooms_loader.py` picks a room for each floor.
- `mechanics_engine.py` interprets all keys from the JSONs.
- `integration_hooks.py` connects these systems to your `DiceDungeonRPG` class.

All effect logic is generic—no hard-coding of specific items or rooms—so adding new
items or statuses requires **only editing the JSON files**.

---

## Extending content

1. **Add a new item** → append to `items_definitions.json`.
2. **Add a new status** → append to `statuses_catalog.json`.
3. **Add a new room** → append to `rooms_v2.json` with desired mechanics.
4. **Test** → run the game; the engine automatically recognizes new entries.

---

This README acts as Copilot’s and developers’ map for the content system.
