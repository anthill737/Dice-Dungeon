# Dice Dungeon — Gameplay Testing Reference

This document describes how to play and test every feature of Dice Dungeon. The game is built with Python/Tkinter.

---

## How to Play Well (Strategy Guide)

### Dice Strategy
- **Always lock high dice** (5s and 6s) before rerolling. The goal is to maximize your total.
- **Chase combos**: If you roll two 6s, lock them both and try for a triple (6+6+6 = 18 base + 30 combo = 48 damage). A triple is worth far more than scattered high numbers.
- **Straights are powerful**: If you see 1-2-3-4 after your first roll, lock them and try to complete the straight for +40 bonus.
- **Full House (+50) is the best non-flush combo.** If you have a pair and a triple, that's huge — don't reroll.
- **Don't waste rolls**: If your dice are already good (all 4+), just attack. Rerolling risks losing what you have.

### Health Management
- **Heal when below 50% HP.** Don't wait until you're nearly dead — one bad enemy roll can kill you.
- **Use Health Potions from inventory** (Tab → click Use on Health Potion). Each heals a fixed amount.
- **Rest between fights** (R key or Rest button) to recover some HP. It has a cooldown, so rest whenever it's available.
- **Buy Health Potions at the store** whenever you visit — they're cheap and save your life.
- In Classic Mode, always pick "Rest" at the floor complete menu if you're below 70% HP.

### Item Priority
- **Pick up everything.** Check every room for ground items (click the "X items" button). Search every container.
- **Equip weapons first** — damage bonus applies to every attack, compounding over the whole run.
- **Equip armor second** — HP and armor bonuses keep you alive longer.
- **Use buffs only in combat** — buff items (damage boost, crit boost) only work during a fight, so save them for tough enemies and bosses.
- **Keep lockpick kits** — locked containers (floor 2+) often have the best loot.
- **Sell junk at the store** — lore items, quest items (Bounty Posters), and excess consumables can be sold for gold.
- **Repair equipment before it breaks** — broken equipment gives zero bonuses. Use repair kits proactively when durability drops below 30%.

### Exploration Strategy
- **Explore every room** before using stairs. More rooms = more loot, more gold, more XP.
- **Find and kill all 3 mini-bosses** on each floor — they drop Boss Key Fragments needed to fight the floor boss, plus guaranteed loot.
- **Save Old Keys for mini-boss rooms.** Don't waste them.
- **Visit the store** on every floor — buy permanent upgrades (Max HP, Damage, Fortune, Critical) whenever you can afford them. These compound across the entire run.
- **Use the minimap** to see which directions you haven't explored yet.

### Combat Priority
- **Kill dangerous enemies first** in multi-enemy fights. Target enemies that spawn allies (Necromancer, Shadow Hydra) before they overwhelm you.
- **Flee from fights you can't win** (50% chance) — it's better to flee and heal than die. You cannot flee from bosses.
- **Use Fire Potions on groups** — the throwable hits a selected target for burn damage.
- **Cleanse status effects quickly** — Poison/Burn/Bleed stack damage each turn and will kill you if ignored.

### Boss Fights
- **Prepare before boss rooms**: Full HP, best equipment, buffs ready in inventory.
- **You need 3 Boss Key Fragments** (from mini-bosses) to enter a boss room.
- **You cannot flee bosses** — commit only when ready.
- **Boss rewards are huge**: 200–350+ gold and 3–5 rare equipment drops.

### Store Spending Priority
1. Health Potions (always stock up)
2. Permanent upgrades (Max HP → Damage → Fortune → Critical)
3. Repair kits (if equipment is damaged)
4. Lockpick kits (for locked containers)
5. Better equipment (when you can afford it)

---

## Launch

- Run `dice_dungeon_launcher.py` → opens launcher with two mode cards
- **Classic Mode** → runs `dice_dungeon_rpg.py` (simple dice combat)
- **Explorer Mode** → runs `dice_dungeon_explorer.py` (full dungeon crawl)

---

## Classic Mode

Mouse-only. Floor-by-floor dice combat, no exploration.

### Starting a Game
1. Click "START NEW RUN" on the main menu
2. Player starts with: 3 dice, 3 rolls/turn, 100 HP, 0 gold, Floor 1

### Combat Loop
1. Click "ROLL DICE" → dice animate and show values (1–6)
2. Click any die to **lock** it (preserves its value on reroll)
3. Reroll unlocked dice (up to 3 total rolls per turn)
4. Click "ATTACK!" → damage = sum of dice + combo bonuses
5. Enemy rolls its own dice and attacks back
6. Repeat until someone reaches 0 HP

### Dice Combos (both modes)
- **Pair**: +value×2
- **Triple**: +value×5
- **Four of a kind**: +value×10
- **Five of a kind**: +value×20
- **Full House**: +50
- **Flush** (all same value): +value×15
- **Straight** (1–6): +40
- **4+ Straight**: +25

### Floor Complete Menu
After killing the enemy, choose:
- **Shop** — buy upgrades (Max HP, Damage, Rerolls, Heal)
- **Rest** — heal 20% HP
- **Next Floor** — advance (enemies scale up each floor)

### Classic UI Buttons
- `?` → help/combo rules dialog
- `☰` → pause menu (High Scores / Return to Menu / Resume)

---

## Explorer Mode

Full dungeon crawl with keyboard + mouse support.

### Keybindings (customizable in Settings)
- **W / ↑** — Move North
- **S / ↓** — Move South
- **A / ←** — Move West
- **D / →** — Move East
- **Tab / I** — Open Inventory
- **M** — Open Menu
- **R** — Rest
- **G** — Character Status
- **ESC** — Close current dialog, or open menu

### Starting a Game
1. Click "START ADVENTURE" on the main menu
2. Starter area (Floor 0): 3 tutorial rooms with readable signs and a starter chest
3. Walk through the starter rooms, then enter the dungeon (Floor 1 begins)

### Exploration
- Each room has directional exits (N/S/E/W). Some exits are blocked randomly.
- Moving in a direction opens a new procedurally generated room.
- The minimap on the right sidebar updates as you explore.

### Room Types and Spawn Rates
- **Combat rooms**: ~40% of rooms have enemies
- **Chest rooms**: 20% chance in unvisited rooms
- **Store rooms**: 15% chance after 2+ rooms explored (once per floor)
- **Stairs rooms**: 10% chance after 3+ rooms explored (once per floor, boss must be dead)
- **Mini-boss rooms**: Spawn every 8–12 rooms, max 3 per floor (require Old Key to enter)
- **Boss rooms**: Spawn 4–6 rooms after 3rd mini-boss defeated (require 3 Boss Key Fragments to enter)

### Exploration UI Buttons
- **N / S / E / W** — direction buttons to move
- **Chest** — appears if room has a chest
- **X items** — shows ground item count, click to interact
- **Rest** — heal (has cooldown timer)
- **Inv** — open inventory
- **Store** or **→Store** — access shop
- **Stairs** — descend to next floor (disabled until boss is defeated)

### Combat (Explorer Mode)
1. Enter a combat room → "Attack" and "Flee" buttons appear
2. Click "Attack" → dice UI appears
3. Roll dice → lock dice you want to keep → reroll → click "ATTACK!"
4. Damage applied to targeted enemy → enemy turn → enemy rolls and attacks you
5. On victory: earn gold + possible loot drops
6. **Flee**: 50% success chance. Cannot flee boss fights.

### Multi-Enemy Combat
- Some rooms have multiple enemies
- Target selection buttons appear — click to choose which enemy to attack
- Special enemies spawn allies mid-fight:
  - **Splitting**: Gelatinous Slime, Crystal Golem split into smaller copies on death
  - **Spawning**: Necromancer, Shadow Hydra, Demon Lord summon minions at HP thresholds or on turn intervals

### Status Effects
Poison, Burn, Bleed, Choke, Hunger — deal damage over time each turn during combat.

### Boss Rewards
- **Mini-boss**: 50–80 + floor×20 gold, Boss Key Fragment, guaranteed loot
- **Boss**: 200–350 + floor×100 gold, 3–5 rare equipment drops

---

## Inventory

Open with **Tab** or **I**.

### Item Actions
Each item shows contextual buttons:
- **Use** — consumables, buffs, shields
- **Read** — lore items
- **Equip / Unequip** — equipment
- **Drop** — unequipped items only

### Item Categories
| Type | What It Does |
|------|--------------|
| heal | Restores HP (Health Potion, Healing Poultice) |
| buff | Temporary combat bonus (damage, crit, rerolls) |
| shield | Temporary shield HP, combat only |
| cleanse | Removes negative status effects |
| token | Single-use escape or disarm |
| tool | Lockpick Kit, trap disarmer |
| repair | Weapon/Armor/Master Repair Kit — restores equipment durability |
| lore | Simple description text |
| readable_lore | Full lore entry added to codex (Guard Journal, Quest Notice, etc.) |
| consumable_blessing | Prayer Candle — random buff |
| combat_consumable | Fire Potion — throwable, select target |
| equipment | Equip to a slot for stat bonuses |
| quest_item | Bounty Posters — sell at store for gold reward |

### Equipment System
Three slots:
- **Weapon** — damage bonus
- **Armor** — HP + armor bonus
- **Accessory** — crit chance, extra rerolls, inventory space, etc.

Equipment has **durability** (percentage). Loses durability when used in combat. At 0% it breaks and becomes "Broken [Item]". Use repair kits to restore 40–60% durability.

Floor scaling: equipment bonuses increase +1 damage/floor and +3 HP/floor after floor 1.

---

## Ground Items

Rooms can have items on the ground. Click the "X items" button to interact.

### Ground Item Types
- **Containers** (60% normal rooms, 100% mini-boss rooms)
  - Must search manually — loot roll: 15% nothing, 35% gold only, 30% item only, 20% both
  - 30% chance locked (floor 2+) — use Lockpick Kit to open
- **Loose gold** — 40% chance, 5–20 gold
- **Loose items** — 40% chance, 1–2 random items
- **Uncollected items** — items left behind when inventory was full
- **Dropped items** — items you previously dropped

---

## Store

Accessible via store rooms or the →Store button.

### Buy Tab
- **Essentials**: Health Potion, Weapon/Armor Repair Kits, Master Repair Kit (floor 5+)
- **Permanent Upgrades** (once per floor):
  - Max HP Upgrade (+10 HP)
  - Damage Upgrade (+1 damage)
  - Fortune Upgrade (+1 reroll)
  - Critical Upgrade (+2% crit, floor 2+)
- **Consumables** (unlock at higher floors): Lucky Chip, Honey Jar, Weighted Die, Lockpick Kit, Smoke Pot, etc.
- **Equipment** (unlock at higher floors): Iron Sword → Greatsword, Leather Armor → Dragon Scale, Traveler's Pack → Crown of Fortune

### Sell Tab
- Sell items at 50% of buy price
- Quantity slider for stackable items
- Bounty Posters give special gold reward when sold

---

## Lore System

- Find readable items throughout the dungeon (Guard Journal, Quest Notice, Training Manual Page, Old Letter, Star Chart, etc.)
- Read from inventory → full lore entry popup appears → entry added to Lore Codex
- Multiple copies of the same item type give **different** lore entries
- View all discovered lore: press **G** → Lore tab

---

## Save/Load System

- 10 save slots available
- Access from main menu ("Save/Load") or pause menu
- **Keyboard shortcuts in save/load menu**: Up/Down to navigate, Enter to select, Delete to remove, F2 to rename

---

## Character Status (G key)

Three tabs:
- **Character** — equipped items, HP, current stats
- **Stats** — total kills, rooms explored, gold earned, etc.
- **Lore** — all discovered lore codex entries

---

## Settings

Access from main menu or pause menu:
- **Difficulty**: Easy / Normal / Hard / Nightmare
- **Color Scheme**: Visual theme selection
- **Text Speed**: Adventure log typewriter speed
- **Keybindings**: Rebind all controls

---

## Minimap

- Right sidebar shows all explored rooms as a grid
- Current room highlighted
- Zoom in/out and pan controls available

---

## Code Architecture

Entry points:
- `dice_dungeon_launcher.py` — launcher
- `dice_dungeon_rpg.py` — Classic Mode (self-contained)
- `dice_dungeon_explorer.py` — Explorer Mode (delegates to managers)

Manager files in `explorer/`:
- `combat.py` — CombatManager
- `dice.py` — DiceManager
- `inventory_display.py` — InventoryDisplayManager
- `inventory_pickup.py` — InventoryPickupManager
- `inventory_equipment.py` — InventoryEquipmentManager
- `inventory_usage.py` — InventoryUsageManager
- `navigation.py` — NavigationManager
- `store.py` — StoreManager
- `lore.py` — LoreManager
- `quests.py` — QuestManager
- `ui_dialogs.py` — UIDialogsManager

Game data in `dice_dungeon_content/data/`:
- `enemy_types.json` — special enemy behaviors (splitting, spawning)
- `items_definitions.json` — all item definitions and stats
- `rooms_v2.json` — room templates with threats, mechanics, tags
- `container_definitions.json` — container loot tables with weighted probabilities
- `lore_items.json` — all lore text entries by category
- `world_lore.json` — world mythology, starter area, flavor text
