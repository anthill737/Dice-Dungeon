# Architecture Rules for Dice Dungeon Explorer

## Manager Pattern - CRITICAL RULES

### 1. ALWAYS Use Managers for Game Logic
- **DO NOT** add new game logic to `dice_dungeon_explorer.py` (main file)
- Main file should ONLY contain:
  - UI setup and initialization
  - Manager delegation wrapper methods (1-2 lines each)
  - Core game loop and display update methods
  
### 2. Manager Organization
- **CombatManager** (`explorer/combat.py`) - All combat logic, enemy turns, damage calculation
- **DiceManager** (`explorer/dice.py`) - Dice rolling, locking, display, animation, combo calculation
- **InventoryManager** (`explorer/inventory.py`) - Inventory display, item management
- **InventoryDisplayManager** (`explorer/inventory_display.py`) - Inventory UI rendering
- **InventoryEquipmentManager** (`explorer/inventory_equipment.py`) - Equipment stats, weapon/armor management
- **InventoryPickupManager** (`explorer/inventory_pickup.py`) - Ground item interactions, pickup/drop
- **InventoryUsageManager** (`explorer/inventory_usage.py`) - Item usage, consumables
- **NavigationManager** (`explorer/navigation.py`) - Room movement, floor transitions, locked rooms, starter area
- **StoreManager** (`explorer/store.py`) - Shop system, buying/selling
- **LoreManager** (`explorer/lore.py`) - Lore codex, reading system
- **SaveSystem** (`explorer/save_system.py`) - Save/load game state
- **QuestManager** (`explorer/quests.py`) - Quest tracking, completion
- **UIDialogsManager** (`explorer/ui_dialogs.py`) - Settings menu, high scores, other UI dialogs

### 3. When Making Changes
1. **FIRST**: Identify which manager owns the system you're modifying
2. **THEN**: Make changes to that manager file
3. **FINALLY**: Update main file delegation method if needed (should be 1-2 lines)

### 4. When Creating New Features
1. **FIRST**: Determine which manager should own it
2. **IF** no appropriate manager exists, create a new one in `explorer/`
3. **THEN**: Implement in the manager
4. **FINALLY**: Add delegation method to main file

### 5. Code Reviews - Check These
- ❌ Did you add 50+ lines of logic to main file? → Move to manager
- ❌ Did you add a new game system to main file? → Create/use manager
- ❌ Does your main file method do more than call a manager? → Refactor
- ✅ Is your change in the appropriate manager? → Good!
- ✅ Is the main file method just 1-2 lines of delegation? → Perfect!

## Current Migration Progress
- **22.7%** reduction from original 13,636 lines
- **3,095 lines** migrated to managers
- Target: < 6,000 lines in main file
