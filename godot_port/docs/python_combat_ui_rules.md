# Python Combat UI Rules (Authoritative Reference)

Extracted from `explorer/combat.py`, `explorer/dice.py`, `dice_dungeon_explorer.py`.

## Log Message Categories

Python uses tag-based styling in the combat/adventure log.

| Tag | Foreground | Bold | Usage |
|-----|-----------|------|-------|
| `player` | Cyan (#5fa5a5) | Yes | Player attacks, rolls |
| `enemy` | Red (#c85450) | Yes | Enemy actions, encounters, curses, spawns |
| `system` | Gold (#d4af37) | No | System messages, target lock, daze |
| `crit` | Magenta (#b565b5) | Yes | Critical hit messages |
| `loot` | Purple (#8b6f9b) | No | Gold drops, key fragments |
| `success` | Green (#7fae7f) | Yes | Victory, defeat messages, curse expiry, shield |
| `fire` | OrangeRed (#ff4500) | Yes | Fire/burn effects |
| `combat` | (default) | No | Burn death |
| `damage_dealt` | Orange (#d4823b) | Yes | (unused in combat.py directly) |
| `damage_taken` | Red (#c85450) | No | (unused in combat.py directly) |
| `warning` | Warning color | Yes | (unused in combat.py directly) |

## Event → Log Message Mapping

### Encounter Start
- Boss: `"☠ FLOOR BOSS ☠"` (enemy), `"⚔️ {NAME} ⚔️"` (enemy)
- Mini-boss: `"⚡ {NAME} ⚡ (MINI-BOSS)"` (enemy), `"A powerful guardian blocks your path!"` (enemy)
- Normal: `"{name} blocks your path!"` (enemy)
- All: `"Enemy HP: {hp} | Dice: {dice}"` (enemy)

### Player Roll
- `"⚄ You rolled: [{dice_str}]{restriction_note} - {potential_info}"` (player)

### Player Attack
- Fumble: `"⚠️ You fumble! Lost a {n} from your attack."` (enemy)
- Crit: random from `player_crits` list (crit)
- Attack: `"⚔️ You attack and deal {damage} damage!"` (player)
- Damage reduction: `"🛡️ Enemy's defenses reduce {n} damage! ({orig} → {new})"` (enemy)

### Enemy Attack
- Roll: `"{name} rolls: [{dice_str}]"` (enemy)
- Attack: `"⚔️ {name} attacks for {damage} damage!"` (enemy)
- Dazed: `"{name} is too dazed to attack (just spawned)!"` (system)

### Damage to Player
- Shield: `"Your shield absorbs {n} damage! (Shield: {left} remaining)"` (success)
- Armor: `"Your armor blocks {n} damage!"` (success)
- Damage: `"You take {n} damage!"` (enemy)
- Blocked: `"All damage blocked!"` (success)

### Status Effects
- Poison/Rot: `"☠ [{status}] You take {n} damage!"` (enemy)
- Bleed: `"▪ [{status}] You take {n} bleed damage!"` (enemy)
- Burn/Heat: `"✹ [{status}] You take {n} fire damage!"` (fire)
- Choke/Soot: `"≋ [{status}] Your attacks are weakened!"` (system)
- Hunger: `"◆ [{status}] You feel weakened from hunger..."` (system)

### Curse Effects
- Damage: `"☠ Curse damage! You lose {n} HP. ({message})"` (enemy)
- Regen: `"💚 {name} regenerates {n} HP!"` (enemy)
- Ability: `"⚠️ {message}"` (enemy)

### Spawn / Split / Transform
- Spawn: `"⚠️ {spawner} summons a {type}! ⚠️"` (enemy), `"[SPAWNED] {type} - HP: {hp} | Dice: {dice}"` (enemy)
- Split: `"✸ {name} splits into {n} {type}s! ✸"` (enemy), `"[SPLIT] {name} - HP: {hp} | Dice: {dice}"` (enemy)
- Transform: `"[TRANSFORMED] {name} - HP: {hp} | Dice: {dice}"` (enemy)

### Enemy Burn
- Tick: `"🔥 {name} takes {damage} burn damage! ({turns} turns remaining)"` (fire)
- Expire: `"🔥 {name}'s burn fades away."` (system)
- Death: `"💀 {name} burned to death!"` (combat/fire)

### Defeat / Rewards
- `"{name} has been defeated!"` (success)
- `"+{n} gold!"` (loot)
- Boss: `"☠ FLOOR BOSS DEFEATED! ☠"` (success)
- Mini-boss: `"Mini-boss defeated!"` (success), `"Obtained Boss Key Fragment! ({n}/3)"` (loot)

## Dice Presentation Rules

### Player Dice
- Size: 72 × scale_factor pixels
- Click on die canvas toggles lock (direct toggle, no separate button needed)
- Force-locked dice cannot be unlocked (show "CURSED" in red #ff4444)
- Locked dice show "LOCKED" in gold #ffd700
- Locked dice get a stipple overlay on the canvas
- Obscured dice (curse) show "?" with purple #8b008b border and "CURSED" text

### Dice Styles
Multiple visual themes (classic_white, obsidian_gold, bloodstone_red, etc.) with:
- `bg`, `border`, `pip_color`, `face_mode` (pips or numbers)
- `locked_bg`, `locked_border`, `locked_pip` for locked state

### Roll Animation
- Player: 15 frames, 25ms interval (~375ms total) via dice.py
- Combat path: 8 frames, 25ms interval (~200ms total)
- Each frame shows random values, final frame shows actual values

### Enemy Dice
- Size: 28 × scale_factor pixels (small)
- Layout: 2×2 grid
- Style: dark red #4a0000 bg, medium red #8b0000 border, white pips
- Animation: 8 frames, 25ms interval (~200ms total)
- Read-only (no click interaction)

## Damage Feedback

### Flash Effects
- Enemy hit: red #ff0000 flash on sprite area/label for 700ms
- Player hit: red #ff0000 flash on sprite box/label for 700ms
- Defeat: 3 rapid red flashes (150ms on, 300ms cycle)

### Shake Animation
- Intensity scales with damage:
  - ≤10: 4 frames, ±3px offset
  - ≤20: 6 frames, ±5px offset
  - ≤30: 8 frames, ±7px offset
  - >30: 10 frames, ±9px offset
- Frame interval: 30ms
- Alternating vertical offset via pady

### Floating Damage Numbers
- Python does NOT have floating damage numbers — all numeric feedback is via log

### Fade-Out on Defeat
- 10 frames, 70ms interval (~700ms)
- Background darkens from #1a1410 to black

## Emphasis Patterns
- Ability trigger messages are prefixed with `"⚠️"` and logged as `'enemy'` (red, bold)
- Crit messages use `'crit'` tag (magenta, bold)
- Gold rewards use `'loot'` tag (purple)
- Separators use `"=" * 60` for boss events
- Status effects use emoji prefixes: ☠ (poison), ▪ (bleed), ✹ (burn), ≋ (choke), ◆ (hunger)
- Spawn events use `"⚠️"` prefix
- Boss encounters use `"☠"` and `"⚔️"` emoji framing
