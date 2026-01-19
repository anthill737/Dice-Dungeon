# Debug Logging System - Quick Reference

## Overview
A comprehensive debug logging system that **automatically activates** when running from VS Code.

## How It Works

### Automatic Activation
The debug logger automatically enables when:
- Running from VS Code (detects `TERM_PROGRAM=vscode` or `VSCODE_PID`)
- Environment variable `DEBUG=1` is set
- Command line flag `--debug` is used

### Log File Location
```
Dice Dungeon/logs/debug_YYYYMMDD_HHMMSS.log
```

Each run creates a new timestamped log file.

## Viewing Logs

### Method 1: View Latest Log (Recommended)
```bash
python view_logs.py
```
Shows the last 100 lines of the latest log file.

### Method 2: Direct File Access
Navigate to `logs/` folder and open the latest `debug_*.log` file.

### Method 3: Real-time Monitoring (PowerShell)
```powershell
Get-Content logs\debug_20251129_232906.log -Wait -Tail 50
```

## Log Categories

The system logs different types of events with clear categories:

| Category | Description | Example |
|----------|-------------|---------|
| `INIT` | Game initialization | `DiceDungeonExplorer starting` |
| `COMBAT` | Combat flow events | `trigger_combat CALLED` |
| `BUTTON` | Button creation/clicks | `Attack button created` |
| `UI` | UI state changes | `action_panel shown` |
| `STATE` | Game state transitions | `Combat turn starting` |
| `DICE` | Dice rolling events | `Rolled: [3, 5, 2, 1, 6]` |
| `NAVIGATION` | Room/floor navigation | `Moved to new room` |

## Testing the Attack Button Issue

### Steps to Debug:

1. **Run the game** (should already be running)
2. **Start a new game** or load existing save
3. **Move to a room with an enemy** 
4. **Click the Attack button**
5. **Check the logs**:
   ```powershell
   python view_logs.py
   ```

### What to Look For in Logs:

When you click Attack, you should see:
```
[BUTTON] Attack button created | command=start_combat_turn
[COMBAT] start_combat_turn CALLED | in_combat=True | has_enemy=True
[STATE] Combat turn starting | combat_state=player_rolled
[UI] action_panel shown
[COMBAT] attack_enemy CALLED | has_dice=True | ...
```

### If Attack Does Nothing:

Look for these patterns in the logs:

**Pattern 1: Button Never Created**
```
# Missing: [BUTTON] Attack button created
```
→ Problem: Button creation code not executing

**Pattern 2: Button Created But Not Clicked**
```
[BUTTON] Attack button created
# Missing: [COMBAT] start_combat_turn CALLED
```
→ Problem: Button click not triggering callback

**Pattern 3: Callback Runs But Exits Early**
```
[COMBAT] start_combat_turn CALLED | in_combat=False
[COMBAT WARNING] Not in combat, calling trigger_combat()
```
→ Problem: Combat state not properly initialized

**Pattern 4: Dice Not Available**
```
[COMBAT] attack_enemy CALLED | has_dice=False
[COMBAT WARNING] No dice rolled yet
```
→ Problem: Dice system not initialized

## Current Instrumentation

### Files with Debug Logging:

1. **dice_dungeon_explorer.py**
   - Logger initialized in `__init__`
   - `trigger_combat()`: Logs entry with enemy details
   - `start_combat_turn()`: Logs combat state and UI visibility
   - Attack button creation: Logs button creation in `trigger_combat()`

2. **explorer/combat.py**
   - Logger initialized in `CombatManager.__init__`
   - `attack_enemy()`: Logs dice state and combat state

## Expanding Debug Coverage

To add logging to other areas:

```python
# At top of file
from debug_logger import get_logger

# In class __init__
self.debug_logger = get_logger()

# In methods
self.debug_logger.combat("Description", key=value, ...)
self.debug_logger.button("Button action", state="enabled", ...)
self.debug_logger.ui("UI change", visible=True, ...)
self.debug_logger.state("State transition", old="idle", new="combat")
```

## Log Levels

- **DEBUG**: Detailed diagnostic info (UI updates, minor state changes)
- **INFO**: General informational messages (shown in console + file)
- **WARNING**: Unexpected but handled situations
- **ERROR**: Actual errors that need attention

## Performance

- **Minimal overhead** when debug is disabled (just a boolean check)
- **No performance impact** on production/non-VS Code runs
- **Efficient logging** with buffered file I/O
- **Separate console output** for important messages only

## Next Steps for Debugging Attack Issue

1. **Reproduce the issue** while running from VS Code
2. **Run `python view_logs.py`** immediately after clicking Attack
3. **Share the relevant log section** showing what happens (or doesn't happen)
4. **Identify the break point** where the flow stops

The logs will tell us exactly where the attack flow is breaking down!
