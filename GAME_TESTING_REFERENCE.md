# Dice Dungeon — Gameplay Testing Reference (Enhanced for Cursor Agents)

This document describes how to play and test every feature of Dice Dungeon. The game is built with Python/Tkinter.

This version includes strict behavioral rules for automated Cursor Cloud Agent testing.

---

# How to Play Well (Strategy Guide)

## Dice Strategy (MANDATORY FOR TESTING)

- **Always lock high dice (5s and 6s) before rerolling.**
- **Always evaluate combos on every roll.**
- Never skip locking — every combat must involve active locking decisions.
- If dice show 5 or 6, lock them immediately unless chasing a straight.
- If two 6s appear, lock both and chase a triple.
- If three of a kind appears, stop rerolling unless chasing Full House.
- If 1-2-3-4 appears, lock and chase straight.
- If dice are already strong (all 4+), do NOT reroll.
- Do not attack without attempting to optimize locks.

### Combos
- Pair: +value×2
- Triple: +value×5
- Four of a kind: +value×10
- Five of a kind: +value×20
- Full House: +50
- Flush: +value×15
- Straight (1–6): +40
- 4+ Straight: +25

---

## Health Management (STRICT AGENT RULES)

- **If HP < 50% → Heal immediately.**
- Heal until HP ≥ 80% when possible.
- Healing is allowed during combat.
- If HP ≤ 30% during combat → heal before attacking.
- Rest whenever cooldown allows.
- Buy Health Potions at every store.
- In Classic Mode, always choose Rest if HP < 70%.

Agent must never:
- Ignore healing when below 50%
- Continue fighting at low HP when healing is available

---

## Item Priority

- Always pick up everything.
- Always click the "X items" button in every room.
- Always search containers.
- Always open chests.
- Equip better weapons immediately.
- Equip armor second.
- Use buffs only in combat.
- Keep lockpick kits.
- Sell junk at store.
- Repair equipment when durability < 30%.

---

## Exploration Strategy

- Explore every room before stairs.
- Kill all 3 mini-bosses.
- Save Old Keys for mini-boss rooms.
- Visit store every floor.
- Use minimap to find unexplored paths.

---

## Combat Priority

- Always lock dice intelligently every combat.
- Kill dangerous enemies first.
- Flee unwinnable fights (not bosses).
- Use Fire Potions on groups.
- Cleanse status effects quickly.

---

## Boss Fights

- Enter with full HP.
- Must have 3 Boss Key Fragments.
- Cannot flee.
- Expect large gold + rare loot rewards.

---

## Store Spending Priority

1. Health Potions
2. Permanent upgrades (Max HP → Damage → Fortune → Critical)
3. Repair kits
4. Lockpick kits
5. Equipment upgrades

---

# Launch

- Run `dice_dungeon_launcher.py`
- Classic Mode → `dice_dungeon_rpg.py`
- Explorer Mode → `dice_dungeon_explorer.py`

---

# Classic Mode

Mouse-only. No exploration.

## Starting a Game

- START NEW RUN
- 3 dice
- 3 rolls
- 100 HP
- Floor 1

## Combat Loop

1. Roll Dice
2. Lock highest dice
3. Reroll intelligently
4. ATTACK
5. Enemy attacks
6. Repeat

### Floor Complete Menu

- Shop
- Rest (mandatory if HP < 70%)
- Next Floor

---

# Explorer Mode

Full dungeon crawl.

## Keybindings

- W / ↑ — North
- S / ↓ — South
- A / ← — West
- D / → — East
- Tab / I — Inventory
- M — Menu
- R — Rest
- G — Character Status
- ESC — Close dialog

---

## Starting a Game

- START ADVENTURE
- Floor 0 tutorial
- Enter Floor 1 dungeon

---

## Exploration

- Move N/S/E/W
- Rooms generate procedurally
- Minimap updates

---

## Room Types and Spawn Rates

- Combat: ~40%
- Chest: 20%
- Store: 15% (once per floor)
- Stairs: 10% (boss must be dead)
- Mini-boss: every 8–12 rooms (max 3)
- Boss: after 3 mini-bosses

---

## Exploration UI Buttons

- Direction buttons
- Chest button
- "X items" button (always click)
- Rest button
- Inv
- Store
- Stairs

---

## Combat (Explorer Mode)

1. Attack → dice UI
2. Lock intelligently
3. Reroll intelligently
4. Attack
5. Enemy turn
6. Loot after victory

Flee = 50% chance (not bosses)

---

## Multi-Enemy Combat

Target weakest or spawning enemy first.

Splitting enemies:
- Gelatinous Slime
- Crystal Golem

Spawning enemies:
- Necromancer
- Shadow Hydra
- Demon Lord

---

## Status Effects

- Poison
- Burn
- Bleed
- Choke
- Hunger

Cleanse quickly.

---

# Inventory

Open with Tab / I.

## Actions

- Use
- Read
- Equip / Unequip
- Drop

---

## Equipment

Slots:
- Weapon
- Armor
- Accessory

Durability decreases in combat.
Repair when <30%.

---

# Ground Items (CRITICAL TEST STEP)

In every room:

1. Click "X items"
2. Search containers
3. Open locked containers (if lockpick)
4. Pick up loose gold
5. Pick up loose items
6. Retrieve dropped items

Agent must never leave a room without checking ground items.

---

# Store

Buy:
- Health Potions
- Permanent upgrades
- Repair kits
- Lockpicks
- Equipment upgrades

Sell:
- Junk
- Lore
- Quest items
- Excess consumables

---

# Lore System

- Read lore from inventory
- Adds to codex
- View via G key

---

# Save/Load

- 10 save slots
- Keyboard shortcuts supported

---

# Character Status (G)

Tabs:
- Character
- Stats
- Lore

---

# Settings

- Difficulty
- Color Scheme
- Text Speed
- Keybindings

---

# Minimap

- Shows explored rooms
- Zoom + pan

---

# Code Architecture

Entry points:
- `dice_dungeon_launcher.py`
- `dice_dungeon_rpg.py`
- `dice_dungeon_explorer.py`

Managers:
- combat.py
- dice.py
- inventory_display.py
- inventory_pickup.py
- inventory_equipment.py
- inventory_usage.py
- navigation.py
- store.py
- lore.py
- quests.py
- ui_dialogs.py

Data:
- enemy_types.json
- items_definitions.json
- rooms_v2.json
- container_definitions.json
- lore_items.json
- world_lore.json

---

# Cursor Agent Enforcement Summary

For automated playtesting, agent must:

- Lock dice every combat
- Heal below 50%
- Heal during combat if needed
- Heal to 80–100% if possible
- Always open chests
- Always click "X items"
- Always search containers
- Always pick up loot
- Visit store every floor
- Repair equipment under 30%
- Kill all mini-bosses
- Never enter boss without preparation
