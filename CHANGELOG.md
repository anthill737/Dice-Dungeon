# Dice Dungeon Explorer - Changelog

## [Unreleased] - 2025-11-29

### Architecture - Manager Migration System
- **CRITICAL RULE**: All code changes MUST be made to the appropriate manager files in `explorer/` directory
  - **Active Managers** (as of 2025-11-29):
    - `explorer/combat.py` - CombatManager (349 lines) - All combat logic, enemy turns, damage calculation
    - `explorer/dice.py` - DiceManager (327 lines) - Dice rolling, locking, display, animation, combo calculation
    - `explorer/inventory_core.py` - InventoryManager (438 lines) - Inventory display, item management
    - `explorer/inventory_items.py` - ItemsManager (511 lines) - Item usage, equipment, consumables
    - `explorer/inventory_ground.py` - GroundItemsManager (367 lines) - Ground item interactions, pickup/drop
    - `explorer/inventory_equipment.py` - EquipmentManager (476 lines) - Equipment stats, weapon/armor management
    - `explorer/navigation.py` - NavigationManager (662 lines) - Room movement, floor transitions, locked rooms
    - `explorer/store.py` - StoreManager - Shop system, buying/selling
    - `explorer/lore.py` - LoreManager - Lore codex, reading system
    - `explorer/save.py` - SaveManager - Save/load game state
    - `explorer/quest.py` - QuestManager - Quest tracking, completion
  - **Main file** (`dice_dungeon_explorer.py`, ~10,061 lines) contains only:
    - UI setup and initialization
    - Manager delegation wrapper methods (1-2 lines each)
    - Core game loop and display update methods
  - **DO NOT** add new methods or logic to main file - create/update managers instead
  - **DO NOT** modify main file unless changing UI layout, initialization, or display updates
  - When user requests feature changes, identify which manager owns that system and update it there
  - Progress: 22.7% reduction from original 13,636 lines (3,095 lines migrated to managers)

### Changed
- **Dice System Migration**: Moved all dice mechanics to DiceManager
  - Technical: Created `explorer/dice.py` with DiceManager class (327 lines)
  - **11 methods migrated** with delegation wrappers in main file:
    - `toggle_dice(idx)` - Toggle lock state for a specific die
    - `roll_dice()` - Roll all unlocked dice with 20-frame animation (500ms total)
    - `_animate_dice_roll()` - Recursive animation showing random values, then final values
    - `reset_turn()` - Unlock all dice, restore rolls (3 + reroll_bonus), reset has_rolled flag
    - `update_dice_display()` - Update all dice canvases with current values and lock overlays
    - `get_current_dice_style()` - Get dice appearance (colors, pips vs numbers) from CombatManager
    - `_get_die_face_text()` - Convert die value to pip symbols (⚀⚁⚂⚃⚄⚅) or numbers
    - `render_die_on_canvas()` - Draw single die on canvas with pips or number
    - `_draw_dice_pips()` - Draw traditional 1-6 pip patterns on canvas
    - `_preview_damage()` - Calculate and display potential damage without logging combos
    - `calculate_damage()` - Calculate final damage with combo detection and logging
  - **Key Features Preserved**:
    - Dice locking system with visual overlays (gray stipple + "LOCKED" text)
    - Roll animation at 25ms per frame (smooth 40fps)
    - Combo detection: Pairs (+value×2), 3-of-a-kind (+value×5), 4-of-a-kind (+value×10), 5-of-a-kind (+value×20)
    - Special combos: Full House (+50), Flush (all same, +value×15), Small Straight (+25), Full Straight (+40)
    - Damage preview shows total without announcing combos
    - Damage calculation logs all combos with color tags ('crit' for big combos, 'player' for medium)
    - Difficulty multipliers applied to final damage
  - **Critical Technical Details**:
    - Manager initialized in main `__init__`: `self.dice_manager = DiceManager(self)`
    - Animation uses `self.game.root.after(25, lambda: ...)` for 25ms frame delay
    - Locked dice rendered with double stipple overlay: gray75 + gray50 for 80% opacity effect
    - Die values stored in `self.game.dice_values` (list of 0-6)
    - Lock states in `self.game.dice_locked` (list of booleans)
    - Dice canvases in `self.game.dice_canvases` (list of tk.Canvas widgets)
    - Preview uses same combo logic but without logging to avoid spoilers
    - Attack button enabled only after `has_rolled == True`
    - Rolls remaining updated after animation completes
    - Style fetched from CombatManager to support enemy-specific dice appearance
- **Navigation System Migration**: Moved all room movement and exploration logic to NavigationManager
  - Technical: Created `explorer/navigation.py` with NavigationManager class (662 lines)
  - **10 methods migrated** with delegation wrappers in main file:
    - `start_new_floor()` - Floor initialization, entrance room creation, boss system setup
    - `get_adjacent_pos(direction)` - Calculate position in N/S/E/W direction
    - `generate_ground_loot(room)` - Spawn containers, gold, and items on ground (60% container, 40% loose items)
    - `describe_ground_items(room)` - Log what player notices on ground
    - `descend_floor()` - Advance to next floor, increment floor counter, call start_new_floor()
    - `explore_direction(direction)` - Move to adjacent room, create new room if needed
    - `show_exploration_options()` - Display action buttons (chest, rest, inventory, stairs, store)
    - `enter_room(room, is_first, skip_effects, new_pos)` - Main room entry with key checks
    - `_complete_room_entry()` - Complete entry after key decisions, update position/UI
    - `_continue_room_entry()` - Apply room effects, trigger combat or show exploration
  - **Key Features Preserved**:
    - Boss key system: 3 mini-boss fragments unlock boss room
    - Old Key system: Unlocks mini-boss rooms
    - Locked room mechanics with dialog prompts
    - Starter area tracking (first 3 rooms on floor 1 = no combat)
    - Random room blocking (30% per direction) with 2 exit minimum
    - Combat pre-rolling (40% chance determined at room creation)
    - Special room spawning (stairs 10%, store 15%, chest 20%)
    - Ground loot generation on first visit
    - Boss spawn timing: mini-bosses at rooms 6-10, main boss at 20-30
  - **Critical Technical Details**:
    - Position updated in `_complete_room_entry()` before combat via `self.game.current_pos = new_pos`
    - Minimap updated BEFORE combat check to show movement immediately
    - Combat triggered via early return to prevent exploration options showing
    - `self.game.starter_rooms` is a set, must be converted to/from list for JSON save
    - Room exit blocking uses `room.exits` dict with False values and `room.blocked_exits` list
    - Manager initialized in main `__init__`: `self.navigation_manager = NavigationManager(self)`
    - All wrapper methods: `def method_name(self, *args, **kwargs): return self.navigation_manager.method_name(*args, **kwargs)`
- **Combat UI Changes**: Removed emoji decorations from combat buttons for Python 3.7.4 compatibility
  - Technical: Windows Tkinter with Tcl 8.6 cannot display Unicode above U+FFFF (emojis in U+1F000-U+1FFFF range)
  - Attack button: Changed from "⚔️ Attack" to "Attack"
  - Flee button: Changed from "🏃 Flee" to "Flee"
  - Damage messages: Changed from "💥 You deal X damage!" to "[HIT] You deal X damage!"
  - Damage preview: Changed from "💥 Potential damage: X" to "[DMG] Potential damage: X"
  - Error: `_tkinter.TclError: character U+1f3c3 is above the range (U+0000-U+FFFF) allowed by Tcl`
  - Emojis work in buttons but NOT in Text widgets (log messages)
  - Python 3.7.4 limitation - newer versions may support higher Unicode
- **VS Label Display**: VS label now hidden during exploration, shown only during combat
  - Technical: Modified 3 locations across managers:
    - Main file `__init__`: VS label created but not packed initially (line 1768)
    - NavigationManager `show_exploration_options()`: VS label hidden via `pack_forget()`
    - CombatManager `enemy_defeated()`: VS label hidden when combat ends
  - VS label shown only in `trigger_combat()` via `self.vs_label.pack(expand=True)`
  - Cleaner UI during peaceful exploration
  - Combat-specific UI element appears only when relevant
- **Rest Status Display**: Removed brackets from "Rest Ready!" status message
  - Changed from " | [Rest Ready!]" to " | Rest Ready!" in progress label
  - Appears in top-right corner when rest cooldown reaches 0
  - More polished, less cluttered UI appearance
- **Minimap Update Timing**: Minimap now updates immediately when entering combat rooms
  - Technical: Moved `self.game.update_display()` and `self.game.draw_minimap()` to occur BEFORE combat check
  - Changed in `explorer/navigation.py` in `_continue_room_entry()` method
  - Update sequence: Ground loot → Display update → Minimap draw → Combat check
  - Previously: Combat triggered → early return → minimap never updated until after combat
  - Now: Position and minimap update immediately → then combat triggers if needed
  - Player sees their position change on minimap even when combat starts instantly

### Fixed
- **Save File Compatibility**: Fixed crashes when loading old save files
  - Added initialization of missing attributes in `load_from_slot()`:
    - `in_starter_area` defaults to False if missing
    - `starter_chests_opened` defaults to empty list
    - `signs_read` defaults to empty list  
    - `starter_rooms` converted from list to set with backward compatibility
  - Added these attributes to `save_to_slot()` for future saves
  - Old saves from before Navigation migration now load without errors
- **Dropped Items Messaging**: Consolidated dropped items notification
  - Technical: Replaced loop that logged individual `self.log(item)` for each dropped item with single count-based message
  - Checks `if len(self.current_room.dropped_items) > 0` then logs count instead of iterating items
  - Changed from individual messages per item to single count-based message
  - Now shows: "There are X items on the ground you dropped here"
  - Reduces message spam when re-entering rooms with multiple dropped items
  - More concise and cleaner adventure log output
- **Message Prefix Cleanup**: Removed redundant category prefixes from log messages
  - Technical: Used find/replace to remove hardcoded prefix strings from all `self.log()` calls
  - Removed `[LOOT]` prefix from loot discovery messages (chest finds, item pickups)
  - Removed `[STORE]` prefix from all shop-related messages (12 instances)
  - Removed `[GOLD]` prefix from gold reward messages (boss/mini-boss/enemy defeats)
  - Log function already adds category tags to file output automatically via timestamp file logging
  - Messages now cleaner: "Found 13 gold..." instead of "[LOOT] Found 13 gold..."
  - Affects all loot, shop, and gold-related notifications
- **Combat Animation Timing**: Removed pause between damage and death animations
  - Technical: Removed `self.root.after(200, ...)` delay calls between damage application and death animations
  - Eliminated 200ms delay in multi-enemy death animation system (`_handle_multi_enemy_deaths`)
  - Eliminated 100ms delay in legacy single-enemy death animation system (`enemy_defeated`)
  - Death animations now trigger immediately in same call stack as damage application
  - Death animations now play immediately after final hit
  - Smoother, more responsive combat flow
- **Acid Slime Sprite**: Updated acid slime enemy sprite using PixelLab AI generation
  - Technical: Generated via `mcp_pixellab_create_character()` with description: "acid slime blob with bubbling toxic surface"
  - Used 4-directional generation (south, west, east, north) at 128×128px resolution
  - Replaced existing sprite files in `assets/sprites/enemies/acid_slime/` directory
  - New 128×128px sprite with green glowing blob appearance
  - Bubbling acidic surface with toxic dripping ooze effect
  - Gelatinous body with caustic bubbles
  - All four directional views replaced (south, west, east, north)
- **Enemy Dice Display Position**: Enemy dice now positioned correctly to left of sprite
  - Technical: Changed Tkinter pack geometry in `__init__` - sprite packs to RIGHT first, then dice frame packs to RIGHT
  - In `_show_and_animate_enemy_dice()`, changed `self.enemy_dice_frame.pack(side=tk.LEFT)` to `pack(side=tk.RIGHT)`
  - Tkinter RIGHT packing places later widgets to the left of earlier widgets when parent uses horizontal layout
  - Fixed pack order: sprite packs first to RIGHT, then dice frame packs to RIGHT (appearing left of sprite)
  - Previously dice appeared on right side due to LEFT packing order
  - Visual layout now matches intended design with dice beside sprite

### Fixed
- **Rest Button State**: Rest button now properly grays out when on cooldown
  - Button visual state (color/text) already changed but remained clickable
  - Added `rest_state = tk.DISABLED` when `rest_cooldown > 0`
  - Button now properly disabled and grayed out immediately after use
  - Prevents accidental clicks during cooldown period
- **Combat Button Flashing**: Fixed buttons flickering during enemy turn log messages
  - Root cause: `_process_typewriter_queue()` was toggling `combat_buttons_enabled` flag on every log message
  - Each log message disabled buttons during text animation, then re-enabled them after
  - Solution: Removed button state toggling from typewriter queue processing
  - Buttons now maintain consistent state throughout combat without visual flashing
  - Previously: With each enemy attack log, Roll/Attack buttons would flash grey → enabled → grey
  - Now: Buttons stay in proper state determined by combat flow, not text animation
- **Dice Roll Counter Not Resetting Between Combats**: Fixed rolls carrying over from previous combat
  - Root cause: `rolls_label` created once in `__init__` but never updated when starting new combat
  - `trigger_combat()` set `rolls_left = 3 + reroll_bonus` but label still displayed old value
  - When dice section became visible in new combat, showed stale roll count from last combat
  - Solution: Added `rolls_label.config()` in `start_combat_turn()` to refresh display
  - Now properly shows "Rolls Remaining: 3/3" (or 3/4 with bonuses) at start of each combat
  - Previously: Ending combat with 1/3 rolls → new combat showed 1/3 until first roll
  - Applies to both `trigger_combat()` (new enemy) and `start_combat_turn()` (new turn within combat)
- **Sneak Attack System Removed**: Cleaned up all sneak attack code and references
  - Deleted `attempt_sneak()` function completely
  - Removed sneak button from combat UI (was alongside Attack/Flee buttons)
  - Removed sneak attack help text from tutorial ("Try sneak attacks for instant damage (40% success)")
  - Simplified combat to focus on core mechanics: Roll Dice → Attack → Flee
  - Reduces UI clutter and streamlines combat decision-making
- **Dice Locking Broken**: Fixed inability to lock/unlock dice during combat
  - Root cause: `_disable_combat_controls()` was unbinding click events from dice canvases
  - Called during `attack_enemy()` to prevent input during attack sequence
  - But unbind was never reversed, leaving dice unclickable for rest of combat
  - Solution: Removed dice unbinding from `_disable_combat_controls()`
  - Also removed unused `_enable_combat_controls()` function (never called anywhere)
  - Dice click bindings now persist throughout combat, created once in `start_combat_turn()`
  - Previously: After first attack, clicking dice did nothing - no lock/unlock
  - Now: Dice clickable at all times during player's turn
- **Roll Dice Button Greyed Out**: Fixed roll button appearing disabled but still functional
  - Root cause: `_disable_combat_controls()` was changing roll button colors to grey (#666666)
  - Button created with turquoise (#4ecdc4) but toggled to grey during attack sequences
  - Never restored to original color due to `_enable_combat_controls()` not being called
  - Solution: Removed roll button from `_disable_combat_controls()` entirely
  - Roll button now maintains consistent turquoise appearance throughout combat
  - Only Attack and Flee buttons are disabled during attack sequences (as intended)
  - Previously: Roll button looked disabled (grey) but was still clickable and functional
  - Now: Visual appearance matches actual functionality - always appears enabled and turquoise

## [Unreleased] - 2025-11-26

### Added
- **Redesigned Lore Codex System**: Complete overhaul with category-based organization
  - Technical implementation: Created nested dictionary structure `lore_codex` organized by 10 type categories
  - Each entry stores: `{"type": str, "title": str, "subtitle": str, "content": str, "floor_found": int}`
  - UI built with collapsible frames using `_toggle_lore_category()` method with lambda default parameters to fix closure bug
  - Category headers are clickable labels that expand/collapse child frames via `pack()`/`pack_forget()`
  - Progress tracking calculates len(lore_codex) and displays with color coding: <30=red, <60=yellow, >=60=green
  - Reading interface uses `show_lore_submenu()` which destroys action_buttons_strip widgets and shows lore content + Back button
  - Migration in `load_game()` infers type from item names if "type" field missing, removes duplicates via dict keying
  - Unique entry tracking via composite key: `f"{item_name}_{inventory_index}"` prevents duplicate codex entries
  - **10 Lore Categories** with dropdown/accordion UI (Hades/Hollow Knight style):
    - 📜 Guard Journals (12 total) - Diary entries from corrupted guards
    - 📋 Quest Notices (8 total) - Bounties and missions posted throughout dungeon
    - ✍️ Scrawled Notes (10 total) - Hasty messages from desperate adventurers
    - 📖 Training Manuals (15 total) - Combat techniques and skill guides
    - 🌿 Pressed Pages (7 total) - Botanical notes from the Thorn Archive
    - ⚕️ Surgeon's Notes (6 total) - Medical observations of dungeon afflictions
    - 🧩 Puzzle Notes (10 total) - Hints and solutions to dungeon mysteries
    - ⭐ Star Charts (4 total) - Celestial navigation maps
    - 🗺️ Map Scraps (6 total) - Fragments of dungeon layouts
    - 🙏 Prayer Strips (10 total) - Religious devotions and blessings
  - **Compact Dropdown Interface**: Categories expand/collapse independently with arrow indicators
  - **Progress Tracking**: Shows "x/88" total lore discovered with color-coded category counts
  - **In-Game Submenu Reading**: Lore content displays in game frame (not popup windows)
  - **Unified Reading Experience**: All lore items (inventory and codex) use same submenu display
  - **"Back" Navigation**: Reading from codex shows "Back" button to return to category list
  - **Full Persistence**: Codex entries saved to JSON with type, title, subtitle, content, floor_found
  - **Migration System**: Old saves automatically upgraded with type inference and duplicate removal
  - **No Duplicate Entries**: Each lore item tracked by unique key (item_name_inventoryIndex)
  - Accessible from pause menu via Character Status → Lore Codex
  - Inventory lore reading now redirects to same submenu system (encourages codex usage)
- **Enemy Dice Display**: Visible enemy dice during combat
  - Technical: Created `enemy_dice_frame` in `__init__` packed to `enemy_sprite_dice_container`
  - `_show_and_animate_enemy_dice()` creates small Canvas widgets (28×28px) in 2×2 grid layout
  - Uses `_render_enemy_die()` method with dark red color scheme (#4a0000 bg, #8b0000 border, white pips)
  - Animation via `_animate_enemy_dice_roll()` with 8 frames at 25ms intervals (200ms total)
  - Dice values stored in `self.enemy_dice_values` list, canvases in `self.enemy_dice_canvases` list
  - Frame shown via `enemy_dice_frame.pack(side=tk.RIGHT)` and hidden via `pack_forget()` when combat ends
  - Enemy dice appear below enemy sprite during their turn
  - Animated dice roll (8 frames, ~200ms) showing random values before locking
  - Small red-tinted dice (28×28px) with white pips
  - Shows first enemy's dice in multi-enemy encounters
  - Dice hidden when combat ends
  - Visual feedback for enemy attack power before damage announcement
  - Matches player dice animation style for consistency

### Added
- **Complete Combat Sequence Refactoring**: Overhauled combat flow with message-first approach
  - Technical: Implemented state machine with `self.combat_state` tracking: "idle", "player_rolled", "resolving_player_attack", "resolving_enemy_attack"
  - Split `attack_enemy()` into phases: `attack_enemy()` → `_calculate_and_announce_player_damage()` → `_execute_player_attack()` → `_check_enemy_status_after_damage()`
  - Added `_disable_combat_controls()` to prevent button clicks during animations (sets button state=tk.DISABLED)
  - Timing controlled via `self.root.after(delay_ms, callback)` pattern for staged execution
  - Damage messages logged first, then `after(700, apply_damage)` creates pause before HP bars update
  - Enemy turn split into: `_start_enemy_turn_sequence()` → `_show_and_animate_enemy_dice()` → `_announce_enemy_damage()` → damage application
  - All animation callbacks check `if hasattr(self, 'widget') and widget.winfo_exists()` to prevent TclError on destroyed widgets
  - Combat now follows: attack declaration → damage message → damage application → animations → enemy turn
  - All controls disabled during combat sequences to prevent input during resolution
  - Animations (shake/flash effects) now trigger AFTER damage messages display
  - Staged combat phases with proper timing delays for better readability
  - Player attack: calculate → message (700ms) → apply/animate (1800ms) → check enemy status (300ms)
  - Enemy attack: roll → announce rolls (700ms) → announce damage (700ms) → armor reduction (700ms) → apply/animate (1800ms)
  - Combat state machine: idle → resolving_player_attack → resolving_enemy_attack → idle
  - Doubled timing delays for better pacing (600-1800ms between phases)
  - Attack messages combined into single line: "⚔️ You attack and deal X damage!"
  - Enemy turn delay reduced to 300ms for smoother flow after player damage

### Added
- **Instant Text for Explored Rooms**: Text animation only plays for newly discovered rooms
  - Technical: Added `instant_text_mode` flag set when room in `self.visited` set before calling `log()`
  - `_typewriter_effect()` checks `instant_mode` parameter and if True, prints entire message immediately instead of character-by-character
  - Typewriter queue items upgraded from tuple `(message, tag)` to `(message, tag, instant_mode)` with backward compatibility
  - Room visited status checked via `if self.current_pos in self.visited` before triggering exploration text
  - Returning to previously explored rooms shows text instantly
  - New rooms require waiting for text to finish before moving
  - Improves navigation speed through familiar areas
  - Maintains narrative pacing for first-time room discoveries
- **Lore Item Selection**: Multiple copies of the same lore item can now be individually read
  - Dropdown menu appears when reading stacked lore items
  - Shows "Copy 1 (#3 in inventory)" format for clarity
  - Each copy has unique content based on position in inventory
  - Works with Quest Notices, Guard Journals, and all readable lore
- **Repair Kit Selection Menu**: Interactive selection dialog for using repair kits
  - Shows all repairable equipment when using Weapon/Armor/Master Repair Kits
  - Displays three categories:
    - Broken items: "Broken Iron Sword → Restore to Iron Sword (50 durability)"
    - Unequipped items: "Steel Armor - 30/100 → 70/100 (+40)"
    - Equipped items: "Iron Sword (equipped) - 60/100 → 100/100 (+40)"
  - Scrollable list with individual Repair button for each item
  - Repair kits respect slot types (weapon kits only repair weapons, etc.)
  - Broken item definitions recreated on load if missing (fixes save/load issue)
- **Shop Item Stacking**: Shop selling interface now stacks items like inventory
  - Duplicate items shown as "Item Name x3" instead of separate rows
  - Consistent with inventory display for better UX
  - Selling one item from stack updates count dynamically
  - Cleaner, more organized sell interface
- **Developer Mode**: Hidden developer tools for testing and debugging
  - Technical: Secret code check in pause menu - string comparison with "1337" sets `self.dev_mode = True`
  - Creates Toplevel window with ttk.Notebook containing 5 tabs, each a tk.Frame
  - Dev multipliers stored in `self.dev_config` dict with keys like "enemy_hp_mult", "player_damage_mult"
  - God mode implemented via check in damage functions: `if self.dev_config.get("god_mode", False): return`
  - Spawn functions directly call `trigger_combat()` with enemy name from dropdown selection
  - Floor jump modifies `self.floor` directly then calls `generate_new_floor()` to rebuild dungeon
  - Export log button writes `self.adventure_log` list to file with timestamp via `open(filename, 'w', encoding='utf-8')`
  - Sliders use ttk.Scale with `command=lambda v: self.dev_config.update({key: float(v)})`
  - Activated by entering secret code "1337" in pause menu
  - Comprehensive dev tools window with 5 tabs:
    - **Spawning Tab**: Spawn any enemy (normal/mini-boss/boss), spawn items
    - **Player Tab**: Add gold, damage/heal player, toggle god mode, adjust stats with sliders
    - **Parameters Tab**: 9 runtime multiplier sliders (enemy HP/damage, player damage, gold drops, item spawn rates, shop prices, durability loss, enemy dice)
    - **World Tab**: Jump to any floor, advance to next floor
    - **Info Tab**: Debug information display with refresh button
  - God mode prevents all damage (status effects, hazards, enemy attacks)
  - Dev multipliers apply to all combat calculations in real-time
  - Export Debug Log button exports full adventure log to text file
  - Window styled to match game's dark fantasy theme (dark brown bg, gold accents)
  - All dev settings persist during session but don't affect save files
- **Complete Enemy Sprite System**: All 251 enemies now have custom pixel art sprites
  - 128×128px sprites generated via PixelLab API
  - Displayed during combat encounters next to enemy stats
  - Dark fantasy aesthetic matching game theme
  - Sprites loaded from `assets/sprites/enemies/` directory

### Changed
- **Text Animation Speed**: Improved text speed settings for better pacing
  - Slow: Reduced from 20ms to 15ms per character (25% faster, more readable)
  - Medium: 13ms per character (unchanged)
  - Fast: 7ms per character (unchanged)
  - Instant: All text appears immediately (unchanged)
  - Speed descriptions updated to reflect new timings
- **Adventure Log UI**: Improved layout and readability
  - Removed outer padding for maximum text width
  - Removed bullet icon (◈) from header
  - Header left-aligned with cleaner appearance
  - Text now spans full width of window
  - Font size increased to 11pt for better readability
  - Smoother scrolling with `update_idletasks()` after line breaks
- **Movement Buttons**: Reduced size to prevent window cutoff
  - Width reduced from 3 to 2 characters
  - Font size reduced from 10pt to 9pt
  - Border width reduced from 2px to 1px
  - More compact layout fits better in various window sizes
- **Combat UI Improvements**: Enhanced combat flow and clarity
  - Flee button icon changed to 🏃‍♂️ (running man) for larger, clearer visual
  - Combat buttons standardized to match exploration button sizing
  - Attack and Flee buttons use consistent font (11pt) and padding (8px)
- **Settings UI Improvements**: Better visual feedback for selected options
  - Text speed buttons now properly update selection highlighting when clicked
  - Dice face mode buttons (Numbers/Pips) now properly update selection highlighting
  - Selected options highlighted with gold background (#ffd700)
  - Unselected options use dark background with light text
  - Hover descriptions update correctly based on current selection
- **Dice Lock Visual Redesign**: Locked dice now use overlay system instead of color change
  - Semi-transparent dark overlay (stippled pattern) on locked dice
  - Gold "LOCKED" text at bottom of each locked die
  - Maintains die readability while clearly showing locked state
  - More professional appearance similar to modern game UI
  - No longer uses yellow background approach
- **Minimap Blocked Path Indicators**: Improved visualization of blocked exits
  - Changed from X marks to red bars at room edges
  - Bars positioned at exact edge corresponding to blocked direction
  - More intuitive and cleaner visual representation
  - Current room's blocked exits show immediately on minimap

### Fixed
- **Lore Reading Bugs**: Fixed multiple issues with lore item reading and codex population
  - **"Surgeon Note" Mapping**: Added handling for both "Surgeon Note" and "Surgeon's Note" item names
  - **Title Standardization**: All lore items now use consistent titles in codex regardless of inventory name
  - **Content Retrieval**: Fixed popup showing wrong content by using `lore_item_assignments` directly
  - **Codex Empty Bug**: Added "type" field to all 10 lore types' `lore_codex.append()` calls
  - **Codex Persistence**: Added `lore_codex` to save/load operations so entries persist across sessions
  - **Dropdown Closure Bug**: Fixed all dropdowns opening same category by using default parameters in toggle function
  - **Training Manual Duplicates**: Fixed duplicate codex entries by checking `is_new` before `_get_lore_entry_index()`
  - **AttributeError Fix**: Added `getattr(self, 'combat_accuracy_penalty', 0)` for old saves without attribute
  - **Migration Support**: Type inference and duplicate removal for old saves without type field
- **Critical Reroll Bug**: Fixed game-breaking bug where player would lose all rerolls after 3 combat turns
  - Technical: The game was missing a method to reset dice between combat rounds
  - After player attack → enemy turn → round end, no function was restoring `rolls_left` to initial value
  - Created new `reset_turn()` method that: sets `rolls_left = 3 + self.reroll_bonus`, resets `dice_locked = [False] * num_dice`, clears `dice_values = [0] * num_dice`
  - Added call to `reset_turn()` in `_check_combat_end()` which runs after each enemy turn completes
  - Also calls `update_dice_display()` to refresh UI with new turn state
  - Previous flow: attack → enemy turn → _check_combat_end() → (nothing) → player stuck with 0 rolls
  - New flow: attack → enemy turn → _check_combat_end() → reset_turn() → player has 3 rolls for new turn
  - Missing `reset_turn()` method was causing `rolls_left` to never reset between turns
  - Added `reset_turn()` method to properly restore rolls to `3 + reroll_bonus` after each enemy turn
  - Method also unlocks all dice, rolls new dice, and updates display for new turn
  - Fixes issue where player would get "No rolls left! You must ATTACK now!" and be unable to continue combat
  - `_check_combat_end()` now correctly calls `reset_turn()` to prepare for next combat round
- **Player Sprite Shake Animation**: Fixed non-working player damage shake effect
  - Added try/except in `_shake_widget()` to check if widget is packed before shaking
  - Uses `pack_info()` to verify widget geometry before attempting animation
  - Prevents errors when trying to shake widgets that aren't visible/packed
  - Player sprite box now properly shakes when taking damage
- **Duplicate Legacy Code**: Removed first duplicate `_execute_player_attack()` method
  - Legacy method at line ~4713 was not called by any code
  - Kept second instance and other legacy methods marked but not removed for safety
  - Cleaner codebase without affecting functionality
- **Repair Kit Broken Items**: Broken weapons and armor now properly appear in repair menu
  - Broken item definitions recreated if missing after save/load
  - Items starting with "Broken " are detected and handled correctly
  - Original item slot determined from item definitions
  - Fixes issue where loaded saves couldn't repair broken equipment
- **Dev Tools Functionality**: Fixed non-working dev mode features
  - Add Gold button now correctly calls `update_display()` instead of non-existent `update_gold_display()`
  - Damage Player button now correctly calls `update_display()` instead of non-existent `update_health_display()`
  - Gold additions and player damage now properly update UI
- **Pause Menu Button Visibility**: "Return to Main Menu" button now always visible
  - Previously hidden behind dev mode check
  - Button moved outside conditional block for consistent access
- **Dev Tools Window Styling**: Professional appearance matching game aesthetic
  - Removed white borders from ttk.Notebook tabs
  - Applied dark brown background (#2c1810) to match game
  - Tab styling with gold text (#f39c12) and dark backgrounds (#3c2820)
  - Selected tabs highlighted with brighter gold (#ffd700)
  - Removed padding/margins for seamless integration

## [Unreleased] - 2025-11-24

### Added
- **Dice Customization System**: Complete visual customization for combat dice
  - Technical: Dice styles stored in `DICE_STYLES` dict with keys: bg_color, border_color, pip_color, face_mode, locked_bg, locked_pip
  - Current style stored in `self.settings["dice_style"]` (string key like "Classic White")
  - Settings saved to `dice_dungeon_settings.json` via `json.dump(self.settings, f)`
  - Dice rendering via `_render_die()` method using Canvas primitives: `create_rectangle()` for die face, `create_oval()` for pips, `create_text()` for numbers
  - Pip positions calculated with dict lookup: `{1: [(center,center)], 2: [(margin,margin), (size-margin, size-margin)], ...}`
  - Preview dice created as 64×64px Canvas widgets in settings menu, combat dice as 72×72px
  - Style change triggers `update_dice_display()` which redraws all existing dice canvases with new colors
  - Locked state overlays created via `create_rectangle()` with stipple="gray50" for semi-transparent effect
  - **8 Visual Presets with Rich, High-Contrast Colors**:
    - **Classic White**: Ivory die with dark pips (traditional dice aesthetic)
    - **Obsidian Gold**: Nearly black background with bright gold numbers
    - **Bloodstone Red**: Deep blood red with bone-colored pips
    - **Arcane Blue**: Dark navy with cyan numbers (magical theme)
    - **Bone & Ink**: Off-white background with dark ink pips
    - **Emerald Forest**: Deep forest green with light green numbers
    - **Royal Purple**: Dark royal purple with pale gold numbers
    - **Rose Quartz**: Soft pink with dark magenta pips (NEW!)
  - **Canvas-Based Rendering**: Both preview AND combat dice use proper canvas rendering
    - 72×72px combat dice with full visual customization
    - Proper pip patterns for "Pips" mode (traditional 1-6 dot layouts)
    - Large, bold numbers for "Numbers" mode (fills die face)
    - Real dice appearance with visible borders and high-contrast colors
    - Clickable canvases respond to mouse clicks for locking dice
  - **Preview System**: Live preview using 64×64px canvas dice
    - Preview shows values 1, 3, 6 to demonstrate each style
  - **Style-Specific Preset Buttons**: Each button styled to match its dice theme
    - Background and foreground colors reflect the dice style
    - Gold highlighting for currently selected preset
    - Visual distinction makes choosing styles intuitive
  - **Mix-and-Match Overrides**: Apply individual elements from different styles
    - Face Mode toggle: Numbers (1-6) or Pips (⚀⚁⚂⚃⚄⚅)
    - Future support for custom colors (bg, pip color, border)
  - **Full Persistence**: Settings saved to JSON and loaded on startup
  - **Real-Time Updates**: Preview and in-game dice update instantly when changing styles
  - **Settings Integration**: New "Dice Appearance" section in Settings menu
  - **Reset Function**: One-click reset to default Classic White style
  - Each preset defines: background color, border color, pip/number color, face mode, locked state variants, and button styling
- **Boss-Blocked Stairs**: Stairs cannot be used until floor boss is defeated
  - Technical: New `boss_alive` flag tracked in `room_state` dictionary for boss rooms
  - Set to True when boss spawned in `add_boss_enemy()` method via `room_state.setdefault("boss_alive", True)`
  - Changed to False in `_check_combat_end()` when boss enemy dies: `room_state["boss_alive"] = False`
  - `use_stairs()` method checks flag before allowing descent: `if room_state.get("boss_alive", False):`
  - Block message: "You must defeat the floor boss first!" appears as popup and in adventure log
  - Boss death triggers barrier removal message and enables stairs immediately
  - Stairs button disabled via `stairs_button.config(state="disabled", bg="#7f7f7f")` while boss alive
  - Button re-enabled on boss death: `stairs_button.config(state="normal", bg=original_color)`
  - Before: Player could use stairs anytime during boss combat, trivializing boss encounters
  - After: Stairs locked until `boss_alive = False`, forcing engagement with floor boss
  - Stairs button is grayed out and disabled until boss defeated
  - Clicking stairs shows popup warning: "You must defeat the floor boss first!"
  - Message also appears in adventure log
  - Prevents accidental floor skipping and ensures boss encounters
- **Inventory Stacking**: Duplicate items now stack with quantity counter
  - Technical: Items have `stackable` property (bool) in item definition dicts, defaults to False
  - Stackable items: healing potions, keys, arrows, consumables defined in `CONSUMABLE_ITEM_POOL` with `"stackable": True`
  - Equipment (swords, armor, shields, helmets) explicitly set `"stackable": False`
  - `try_add_to_inventory()` logic:
    1. Check if item has `"stackable": True`
    2. Search inventory list for existing item with same `item_type` (string comparison)
    3. If found, increment `stack_count` property: `existing_item["stack_count"] += 1`
    4. If not found or not stackable, append as new inventory entry
  - Stack count displayed in inventory via `f"{item.get('stack_count', 1)}x {item_name}"`
  - Using stacked item decrements count: `stack_count -= 1`, removes from inventory if `stack_count <= 0`
  - Save system stores stack_count in JSON: `{"item_type": "healing_potion", "stack_count": 5, ...}`
  - Load system restores stacks by reading stack_count property from save data
  - Before: 10 healing potions = 10 inventory slots
  - After: 10 healing potions = 1 inventory slot with display "10x Healing Potion"
  - Items show "x2", "x3", etc. for multiple copies
  - Single inventory row per unique item type
  - Buttons (Use/Drop/Equip) operate on first instance of that item
  - Cleaner, more compact inventory display
  - Gold value removed from inventory display (was cluttering UI)

### Fixed
- **Red Flash on Damage**: Room canvas flashes red when player takes damage
  - Technical: Uses `canvas.create_rectangle()` overlay with red fill color and alpha transparency
  - Triggered in `_apply_combat_damage()` after reducing player health
  - Flash animation: `create_rectangle(0, 0, canvas_width, canvas_height, fill="#ff0000", stipple="gray75")`
  - Stipple pattern creates semi-transparent effect (75% transparency)
  - Flash duration controlled by `after(150, lambda: canvas.delete(flash_rect))` - 150ms flash
  - Rectangle tagged with unique ID for deletion after animation
  - Overlays entire map_canvas to create full-screen damage feedback
  - Before: No visual feedback when taking damage (only health bar change)
  - After: Instant red flash provides clear damage feedback synchronized with health reduction
  - Red overlay appears for 150ms then automatically removes itself
  - Visual feedback synchronized with health reduction and combat log message

- **Enemy Death Animation**: Enemies shake and flash when killed
  - Technical: Two-part animation sequence managed by chained `after()` callbacks
  - Shake effect: alternates sprite position by ±5 pixels in both x and y directions
  - Implementation: `canvas.move(sprite_id, dx, dy)` called 6 times (3 shake cycles) at 50ms intervals
  - Flash effect: `itemconfig(sprite_id, state="hidden")` and `state="normal"` alternating at 80ms intervals
  - Animation sequence: shake (50ms) → shake (50ms) → shake (50ms) → flash (80ms) → flash (80ms) → flash (80ms) → delete sprite
  - Total animation time: ~450ms before sprite removal
  - Coordinates stored before shake: `original_coords = canvas.coords(sprite_id)` for return positioning
  - After final flash, sprite deleted: `canvas.delete(sprite_id)` and removed from `self.enemy_sprites` list
  - Before: Enemy sprites vanished instantly on death (jarring transition)
  - After: Smooth death animation with shake + flash provides satisfying combat feedback
  - Shakes back and forth (±5 pixels, 3 times) then flashes 3 times before disappearing
  - Total animation: ~450ms from death to sprite removal

- **Mousewheel Scrolling**: Complete overhaul of scroll system for all menus
  - Technical: Replaced individual widget `bind("<MouseWheel>")` with `root.bind_all("<MouseWheel>", callback)`
  - Callback checks mouse position via `root.winfo_pointerx/y()` and widget bounds via `widget.winfo_rootx/y() + winfo_width/height()`
  - Only scrolls if mouse is within widget bounding box: `x_min <= pointer_x <= x_max and y_min <= pointer_y <= y_max`
  - Multiple scrollable areas (store, inventory, stats) each have their own bind_all callback with position detection
  - Scroll amount calculated as `int(-1 * (event.delta / 120))` for Windows mousewheel delta values
  - Canvas scrolled via `canvas.yview_scroll(amount, "units")` method
  - Now uses `bind_all` to capture mousewheel from any widget
  - Works when hovering over buttons, labels, items, stats, save files
  - No longer limited to scrollbar or empty canvas areas
  - Position-based detection prevents conflicts between multiple scrollable areas
  - Applies to: Store (buy/sell), Inventory, Character Stats, Save File List, Settings

### Changed
- **Combat Log Cleanup**: Removed verbose dice roll messages
  - No longer logs "[ROLL 1/3] Rolled 3 dice: [4, 5, 5]"
  - No longer logs "Lock dice you want to keep..." instructions
  - No longer logs "Locked die #1 showing 6" / "Unlocked die #2" messages
  - Cleaner, less cluttered adventure log during combat
  - Dice state is visible on-screen, doesn't need constant logging
- **Inventory Display**: Removed gold value from all inventory items
  - Item rows now show: "• Item Name x2 [EQUIPPED] [80%]"
  - No more "(50g)" suffixes cluttering the display
  - Sell value still visible in store's sell tab when needed

## [Unreleased] - 2025-11-20

### Added
- **Lockpick Kit Functionality**: Lockpick Kit now automatically disarms the first trap you encounter
  - Using Lockpick Kit adds a disarm token to player flags
  - When entering a room with hazard trap, token is consumed and trap bypassed
  - Displays "[DISARMED]" message instead of taking trap damage
  - Token only works on combat hazard traps (not combat itself)
- **Minimap Boss Indicators**: Minimap now shows boss room completion status
  - 🔒 (red) for locked boss/mini-boss rooms not yet unlocked
  - ✓ (green) for defeated bosses
  - ⚡ (purple) for undefeated mini-bosses
  - 💀 (red) for undefeated main bosses
  - Icons update dynamically as you defeat bosses
- **Comprehensive Stats Tracking**: Added 40+ detailed statistics tracked throughout gameplay
  - Combat stats: enemies encountered/defeated, damage dealt/taken, critical hits, boss/mini-boss defeats
  - Economy stats: gold found/spent, items purchased/sold
  - Item stats: items found/used, potions consumed
  - Equipment stats: items equipped, equipment broken/repaired
  - Exploration stats: containers searched, lore items discovered
  - Enemy-specific kill counters for all enemy types
  - All stats persist in saves and high scores
- **Stats UI**: Complete statistics screen accessible from inventory
  - Organized into Combat, Economy, Items, Equipment, Lore, and Enemy sections
  - Shows lifetime achievements and playstyle insights
  - Integrated with save/load system
- **Backpack Equipment Slot**: New dedicated slot for inventory expansion items
  - Separates utility items from combat accessories
  - Traveler's Pack and Merchant's Satchel moved to backpack slot
  - Combat accessories (Mystic Ring, Lucky Coin, etc.) remain in accessory slot
  - Displays in Character Status UI alongside weapon, armor, and accessory
  - Full backward compatibility with old saves
- **Mystic Ring Combat Ability**: Converted from passive to active ability
  - Appears as purple "💍 Mystic Ring" button during combat
  - Click to gain +1 reroll (usable once per combat)
  - Button grays out after use, resets for next combat
  - Ring stays equipped permanently (999 durability)
  - More strategic gameplay - choose when to use the extra reroll
  - Character Status shows "COMBAT: +1 REROLL (Once)" instead of passive bonus
- **Mysterious Key**: Placeholder item for future content
  - Defined as "escape_token" in item definitions
  - Potential uses being considered:
    - Secret escape route from dungeon
    - Unlock special treasure room
    - Skip a floor mechanic
    - Access hidden boss area
  - Not currently implemented in game mechanics

### Changed
- **Minimap Visual Improvements**: Enhanced minimap clarity and icon visibility
  - Visited room color changed from dark cyan (#4ecdc4) to medium gray (#4a4a4a)
  - Room squares sized at 45% of cell size to prevent overlapping
  - Connection lines made subtle: dark gray (#1a1a1a), dotted style
  - All icons increased to 14pt font size for better visibility
  - Stairs icon changed to ∩ (arch symbol) in green
  - Store icon changed to $ (dollar sign) in green
  - Lock icons changed to bright red (#ff3333) for visibility
- **Item System Overhaul**: All 135 discoverable items now have complete descriptions
  - Added 87 missing items with full descriptions and mechanics
  - Added compatibility aliases for encoding issues (Tuner Hammer, Underking Crest, etc.)
  - All items now display tooltips in inventory, ground items, containers, and shop
- **Container System Redesign**: Implemented two-stage randomization for better loot balance
  - Stage 1: 60% chance container spawns, 40% chance loose loot immediately
  - Stage 2 (when searching container): 15% empty, 35% gold only, 30% item only, 20% both
  - Applied to 122 rooms across all floors with 20 different container types
  - More varied and unpredictable looting experience
- **Accessory Durability**: Traveler's Pack and Merchant's Satchel durability increased to 999
  - Prevents accessories from breaking during normal gameplay
  - Makes utility items effectively permanent
- **Permanent Upgrade Pricing Rebalanced**: More strategic choices with better value
  - Extra Die: Increased from 150+floor×30 to 800+floor×200 (5.3× more expensive)
  - Critical Upgrade: Reduced from 550+floor×130 to 200+floor×50 (63% cheaper)
  - Critical Upgrade bonus increased from 2% to 5% crit chance (2.5× more powerful)
  - Makes Extra Die appropriately expensive for powerful permanent benefit
  - Makes Critical Upgrade affordable with meaningful 5% impact
- **Once-Per-Floor Upgrade Limit**: Permanent upgrades can only be purchased once per floor
  - Prevents buying multiple Extra Dice or upgrades from same store
  - Encourages exploring multiple floors for full character progression
  - Tracking persists through saves
- **Philosopher's Stone Fragment Value**: Increased sell value from 25g to 50g (2× increase)
  - Better reflects rarity and usefulness as sellable lore item
- **High Scores Column Alignment**: Fixed stats display for cleaner presentation
  - All numeric columns properly aligned
  - Improved readability of leaderboard
- **Early Floor Difficulty**: Increased enemy damage by 15% on floors 1-3
  - Makes early combat more challenging and engaging
  - Better prepares players for later floors
  - Applied after difficulty multipliers and global reduction

### Fixed
- **Room Reward Distribution**: Fixed on_clear mechanics for 65 rooms
  - Items from room completion now drop to ground instead of auto-inventory
  - Prevents inventory overflow and gives player choice
  - Consistent with container/loot system behavior
- **Environmental Hazard Keywords**: Fixed false positive triggers
  - Shadow Imp no longer triggers trap warning due to "shadow" keyword
  - Hazard detection now more precise and reliable
- **Equipment Bonus Doubling Bug**: Equipment bonuses no longer applied multiple times
  - Fixed bug where equipping/unequipping could stack bonuses
  - Bonuses now properly removed before applying new equipment
  - Affects damage, crit, rerolls, HP, armor, and inventory slots
- **Durability System Bugs**: Multiple fixes for equipment durability
  - Weapons no longer lose durability when selling items
  - Fixed incorrect durability loss triggers in various game actions
  - Equipment breaking now properly tracked in stats
- **Mini-Boss Spawn Cap**: Fixed spawn limit from 2 to 3 mini-bosses per floor
  - Ensures players can always collect all 3 key fragments needed for boss
  - Matches intended game design
- **Armor Healing Exploit**: Removed unintended healing on armor re-equip
  - Players can no longer heal by repeatedly equipping/unequipping armor
  - Armor bonus only applies to max HP, not current HP
- **Enemy Damage Bug**: Removed unconditional 50% damage boost to enemies
  - Enemy damage now properly calculated without hidden multiplier
  - Combat balance restored to intended difficulty
- **Stats Tracking Not Working**: Fixed all stat increment locations
  - Added tracking throughout combat system (encounters, damage, defeats)
  - Added tracking in economy (gold found/spent, purchases, sales)
  - Added tracking for items (found, used, potions consumed)
  - Added tracking for equipment (equipped, broken, repaired)
  - Added tracking for exploration (containers searched)
  - All 40+ stats now properly increment during gameplay
- **Items Found Counter**: Fixed tracking to include all item sources
  - Now counts items from containers, enemy loot, room rewards, and chests
  - Previously only counted container items
  - Does not count purchased items (tracked separately) or picked-up dropped items

## [Unreleased] - 2025-11-19

### Fixed
- **Discoverable Items Processing**: Fixed major bug where room discoverables were appearing in ground items dialog and could be picked up multiple times
  - Technical: Discoverables were being added to room's `ground_items` list but not removed after collection
  - Changed to process discoverables immediately in `collect_discoverable()` - gold added to `self.gold`, healing applied to `self.health`, items added to inventory
  - Only items that don't fit in inventory get added to room's `uncollected_items` list (not discoverable list)
  - Removed discoverable handling from ground items dialog - it now only shows `uncollected_items` and `dropped_items`
  - Pick Up All iterates only over uncollected/dropped items, calls `try_add_to_inventory()` for each
  - Ground dialog categories changed from 3 to 2: "Left Behind (Inventory Full)" and "Dropped Items" (removed "Items Noticed")
  - Previous bug: discoverables stayed in room list → appeared in ground dialog → could be collected infinite times
  - New behavior: discoverables processed once → immediately applied → never appear in ground items again
  - Discoverables (gold, healing herbs, etc.) are now processed IMMEDIATELY when searching/exploring
  - Only actual items that couldn't fit in inventory appear in ground items dialog
  - Removed "Items Noticed" section from ground dialog (those rewards are instant)
  - Fixed healing items healing you then still being pickupable from ground
  - Fixed gold pouches giving gold then appearing as pickupable items
  - Pick Up All button now only picks up uncollected/dropped items, not discoverables
- **Random Discovery System**: Items found in rooms are now completely randomized
  - 30% chance: Find nothing (search yields no results)
  - 40% chance: Find 3-20 random gold instead of listed item
  - 30% chance: Get the actual discoverable item (or replacement if undefined)
  - Makes exploration more unpredictable and exciting
  - Undefined flavor items automatically replaced with useful items (Health Potion, Weighted Die, Lucky Chip, etc.)

### Added
- **Ground Items System**: New centralized ground items dialog for better item management
  - Single button shows total count: "X items on ground"
  - Opens dialog showing all ground items organized by category
  - Categories: "Items Noticed", "Left Behind (Inventory Full)", "Dropped Items"
  - Each item shows name and "Pick Up" button
  - "Pick Up All" button to collect multiple items at once
  - Escape key closes dialog (consistent with inventory/gear menus)
  - Tooltips show item descriptions when hovering over item names
- **Item Tooltips**: All ground items now show descriptions on hover
  - Discoverable items show clean names (e.g., "Lucky Chip" instead of "Lucky Chip (+1% crit)")
  - Uses same tooltip system as inventory items
- **Inventory Display Improvements**:
  - Changed inventory count display from "(X/Y slots)" to "(X/Y)"
  - Moved slot counter to top-left of inventory dialog
  - Added "Boss Key Fragments" label below title
  - Repositioned elements to prevent text overlap
- **Responsive UI Layout**: Game UI now properly scales to different window sizes
  - Stats, room info, and action buttons have fixed heights
  - Adventure log dynamically expands/contracts with window size
  - No scrolling needed - all important elements always visible
  - Minimap stays fixed on right side
- **Starter Room Protection**: First 3 rooms on Floor 1 are now permanent safe zones
  - Combat never triggers in these rooms, even on revisit
  - Tracked via `starter_rooms` set for persistent safe zones
  - Starting room (0,0) automatically marked as safe

### Fixed
- **Equipment Bonus Re-application**: Equipment bonuses now properly re-applied on game load
  - Fixed bug where armor wasn't reducing damage after loading a save
  - Added `skip_hp=True` parameter to prevent HP bonus from being applied twice
  - Max HP bonus only applied when equipping, not when loading
- **Lucky Chip Crit Bonus**: Increased from 1% to 5% (was incorrectly set in items_definitions.json)
- **HP Doubling on Load**: Fixed bug where HP bonus was applied both on equip AND on load
  - Equipment bonuses now skipped for max_hp_bonus when loading saves
- **Guard's Journal Page Read Button**: Fixed item definition lookup failure
  - Renamed from "Guard's Journal Page" to "Guard Journal" to avoid apostrophe issues
  - Updated items_definitions.json, rooms_v2.json, and all references
  - Read button now appears correctly for lore items
- **Combat Button Sizing**: Standardized combat and exploration button sizes
  - Combat buttons now use same font (11pt) and padding (8px) as exploration buttons
  - Prevents window from resizing when combat starts
- **Unlocked Rooms Persistence**: Boss and mini-boss rooms stay unlocked after defeat
  - Rooms added to `unlocked_rooms` set when boss defeated
  - Fixed re-locking issue when revisiting defeated boss rooms
- **Slippery Floor Fumble Bug**: Fixed bug where fumble removed 0 instead of lowest die
  - Now properly filters non-zero dice before selecting minimum
  - Prevents duplicate zeros in dice array
- **Rest Button Visibility**: Rest button now shows grey (#666666) when on cooldown
  - Previously showed black which was hard to distinguish from available state
- **Discoverable Items**: Moved from inline buttons to ground items container
  - Previously showed as separate "Items Noticed" buttons
  - Now integrated into ground items dialog under "Items Noticed" section
- **Ground Items Dialog Tooltips**: Fixed tooltip method calls
  - Changed from non-existent `create_tooltip()` to `create_item_tooltip()`
  - All ground items now properly display tooltips
- **Item Name Formatting**: Removed type descriptors from item names in ground dialog
  - "Scrawled Note (lore)" now displays as "Scrawled Note"
  - "Lucky Chip (+1% crit next combat)" now displays as "Lucky Chip"
  - Strip parenthetical descriptions using `item.split(' (')[0]`
- **Pick Up All Functionality**: Fixed multiple bugs with batch item pickup
  - Now properly stops when inventory is full
  - Shows "INVENTORY FULL! X item(s) left on ground" message when items remain
  - Shows "✓ Picked up X item(s)" message when all items collected
  - Added `skip_refresh` parameter to `collect_discoverable()` method
  - Prevents UI refresh after each individual pickup during batch operation
  - Tracks inventory changes to count only successfully picked up items
  - No longer deletes items when inventory fills up

### Changed
- **UI Proportions**: Made controls smaller and adventure log bigger for better readability
  - Header buttons: 10pt font, smaller padding
  - Stats section: More compact (11pt HP, 10pt gold, 9pt progress)
  - Room display: Reduced font sizes and padding
  - Action buttons: Reduced padding
  - Adventure log: Font increased to 11pt, dynamically fills available space
- **Starter Gear**: Updated initial chest contents for better new player experience
  - Chest 1: Healing Poultice + Lucky Chip + 15 gold
  - Chest 2: Healing Poultice + Hourglass Shard + 15 gold
  - Removed Lockpick Kit (no traps to disarm in current version)
  - Total: 2 healing potions, 1 lucky chip, 1 hourglass shard, 30 gold
- **Inventory Button Layout**: Standardized inventory item button positions
  - "Equip", "Use", and "Read" buttons on left side
  - "Drop" button on right side
  - Consistent across all inventory items
- **Item Descriptions**: Cleaned up all room item tooltips
  - Removed redundant information (type descriptors, mechanics already in name)
  - More concise and atmospheric descriptions
  - Health potions show heal amount in tooltip
- **Lore Items**: Updated room references to match renamed items
  - "Scrawled Note (lore)" → "Scrawled Note" in rooms_v2.json
  - "Ledger Entry" renamed to "Scrawled Note" everywhere

### Removed
- **Sneak Attack Button**: Removed from combat UI
  - Combat simplified to just Attack and Flee options
  - Reduces clutter and streamlines combat flow
- Scrollable canvas from main game area (no longer needed with responsive layout)
- Debug print statements for item type checking in inventory and combat
- Lockpick Kit from starter chests (unused item)
- Inline ground item buttons from exploration view
- Type descriptors from ground item names in dialog

## [Previous] - 2025-11-17

### Added
- **Victory Screen**: Proper endgame celebration when defeating the final boss
  - Victory bonus: +5000 points
  - Complete stats summary (floor, rooms, enemies, gold, chests)
  - Options to view high scores or return to main menu
- **Broken Equipment System**: Equipment now breaks into "Broken [Item]" instead of disappearing
  - Broken items remain in inventory and can be repaired
  - Broken items have reduced sell value (50% of original)
  - Repair kits can restore broken items to 50% durability
- **Boss Spawning Requirements**: Boss can only spawn after defeating all 3 mini-bosses on floor
  - Mini-boss count increased from 2 to 3 per floor
  - Boss won't appear until you've collected all 3 key fragments
  - Ensures players always have enough fragments for boss rooms
- **Comprehensive Lore System**: Fully implemented readable lore items with rich narrative content
  - Guard's Journal Pages: 8 atmospheric entries about the siege and dungeon horrors
  - Quest Notices: 6 unsettling bounties and contracts
  - Training Manual Pages: 5 combat training excerpts with dark undertones
  - Scrawled Notes: 5 warnings from previous explorers
  - Pressed Pages: 3 botanical treatises from the Thorn Archive
  - Surgeon's Notes: 3 medical horror entries from the Alabaster Ward
  - Puzzle Notes: 2 notes about the Riddle Mill's secrets
  - Star Charts: 2 impossible astronomical observations
  - Cracked Map Scraps: Notes about impossible dungeon geography
  - Prayer Strips: Cult devotional texts
- Lore items now properly defined in `items_definitions.json` as type "readable_lore"
- Complete lore content database in `lore_items.json` with horror-themed narrative
- Display functions for all lore item types with unique UI styling
- Helper function `_get_lore_entry_index()` to manage lore entry assignments
- Boss Key Fragment counter in inventory UI (🔑 x/3) - turns gold when complete

### Fixed
- **Equipment Durability Persistence**: Equipment durability now saves and loads properly
  - Fixed data loss bug where durability reset to full on reload
  - Broken equipment state now persists across save/load
- **Debug Logging Removed**: Removed debug spam from production code
  - Clean log output when using items
  - Debug logging only active when dev_mode is enabled
- **Room Entry System**: Boss and mini-boss rooms now properly block entry when keys are declined
  - Room state changes (current_room, visited, rooms_explored) now occur AFTER key validation
  - Prevents players from entering locked rooms without using keys
  - Added `_complete_room_entry()` function to handle post-validation room entry
- **Equipment & Durability**:
  - Chain Vest stats upgraded to +20 max HP, +2 armor (from +10 HP, +1 armor)
  - Added max_durability values to all equipment items in items_definitions.json
  - Added armor_bonus property to all armor pieces (Leather Armor was missing it)
  - Increased Plate Armor to +3 armor and Dragon Scale to +4 armor
  - Repair kits now available from floor 1 (previously floor 2+)
  - Added repair kits to 4 discoverable rooms: Bellfounder's Forge, Crucible Steps, Tinkerer's Yard, Wagon Bone Yard
- **Combat & Pacing**:
  - First 3 rooms now skip combat encounters (grace period for new players)
  - Mini-boss rooms properly check for Old Key before allowing entry
  - Boss rooms properly check for 3 Key Fragments before allowing entry
- **Item System**:
  - Fixed character encoding issue with apostrophes (curly ' vs straight ') in item names
  - Added apostrophe normalization when collecting and using items
  - Dropped items now appear immediately in exploration options (no need to leave/re-enter room)
  - Stay in inventory screen after dropping an item (don't exit to exploration)
- **Save Compatibility**:
  - Added backward compatibility for `key_fragments_collected` attribute in old saves
  - Added initialization checks in mini-boss defeat, boss room entry, and inventory display
  - Fixed KeyError crashes for lore system when loading old saves
  - All lore display functions now initialize missing lore_key entries
  - Equipment durability dict properly restored from saves
- **Room Exploration**: Room exploration counter now only increases on first visit (not revisits)
- **Room Healing**: Room entry healing effects now only apply on first visit (prevents exploit)
- **Lore Persistence**: Lore item assignments now properly saved and restored across sessions
- **Key Fragment Counter**: Now properly saved and loaded, only changes when defeating mini-bosses
- **Debug Improvements**:
  - Added debug logging for item name normalization when using journal pages
  - Improved error handling for missing attributes in older save files

### Changed
- Dropped items now stay in inventory view instead of switching to exploration options
- Lore entry tracking system now properly initializes all lore categories
- Room flag restoration moved earlier in room entry flow for better boss/mini-boss detection

### Technical
- Refactored lore display functions to use shared helper instead of duplicated logic
- Improved room state management to prevent premature room entry
- Enhanced save/load compatibility with attribute existence checks
- Normalized item name handling to support both character encodings

---

## PixelLab MCP Server Usage Guide

### Overview
PixelLab is an AI-powered pixel art generation service accessed through MCP (Model Context Protocol). It can generate:
- **Characters** with 4 or 8 directional views (top-down perspective)
- **Character Animations** based on template actions
- **Isometric Tiles** for 3D-style games
- **Top-Down Tilesets** for 2D game maps (Wang/corner-based autotiling)
- **Sidescroller Tilesets** for 2D platformer games
- **Map Objects** with transparent backgrounds for placement on game maps

All operations are **asynchronous** - they return job IDs immediately and you must poll for completion.

---

### Character Creation Workflow

#### Step 1: Create Character
```python
# Use mcp_pixellab_create_character tool
mcp_pixellab_create_character(
    description="acid hydra with three serpent heads, dripping green poison",
    n_directions=8,  # 4 or 8 directions
    size=48,  # Canvas size in pixels (16-128)
    view="low top-down",  # Options: "low top-down", "high top-down", "side"
    name="Acid Hydra v2",  # Optional reference name
    ai_freedom=750,  # Creative freedom (100=strict, 999=creative)
    
    # Style parameters (optional, defaults shown):
    detail="medium detail",  # "low detail", "medium detail", "high detail"
    shading="basic shading",  # "flat", "basic", "medium", "detailed"
    outline="single color black outline",  # "single color black outline", "single color outline", "selective outline", "lineless"
    
    # Body proportions (optional):
    proportions='{"type": "preset", "name": "default"}'  # or "chibi", "cartoon", "stylized", "realistic_male", etc.
    # OR custom: '{"type": "custom", "head_size": 1.5, "arms_length": 0.8, "legs_length": 0.9, "shoulder_width": 0.7, "hip_width": 0.8}'
)
```

**Returns:**
```json
{
  "character_id": "7372d7e7-4f49-4ff0-8779-f0ce9085e312",
  "job_ids": ["job-abc123", "job-def456", ...],
  "status": "processing",
  "estimated_time": "3-5 minutes for 8 directions"
}
```

#### Step 2: Check Character Status
```python
# Wait 3-5 minutes, then check status
mcp_pixellab_get_character(
    character_id="7372d7e7-4f49-4ff0-8779-f0ce9085e312",
    include_preview=True  # Optional preview image of all directions
)
```

**Returns when complete:**
```json
{
  "character_id": "7372d7e7-4f49-4ff0-8779-f0ce9085e312",
  "name": "Acid Hydra v2",
  "status": "completed",
  "rotations": {
    "south": "https://pixellab.ai/download/...",
    "south_west": "https://pixellab.ai/download/...",
    "west": "https://pixellab.ai/download/...",
    // ... all 8 directions
  },
  "animations": [],  // Empty until you create animations
  "download_url": "https://pixellab.ai/download/character-zip-...",
  "preview_image": "data:image/png;base64,..."  // If include_preview=True
}
```

#### Step 3: Download Character Sprites
The `download_url` provides a ZIP file with all directional sprites. Use curl or wget:

```bash
# The tool returns a curl command you can run
curl -o acid_hydra_v2.zip "https://pixellab.ai/download/character-zip-..."
```

Then extract and organize:
```
assets/sprites/enemies/acid_hydra/
├── south.png
├── south_west.png
├── west.png
├── north_west.png
├── north.png
├── north_east.png
├── east.png
└── south_east.png
```

---

### Character Animation Workflow

#### Step 1: Queue Animation Jobs
After character is created, you can animate it:

```python
mcp_pixellab_animate_character(
    character_id="7372d7e7-4f49-4ff0-8779-f0ce9085e312",
    template_animation_id="falling-back-death",  # See list below
    action_description="dissolving into an acid puddle"  # Custom description (optional)
    animation_name="Death Dissolve"  # Optional custom name
)
```

**Available Animation Templates:**
- **Combat**: `fight-stance-idle-8-frames`, `lead-jab`, `cross-punch`, `high-kick`, `roundhouse-kick`, `leg-sweep`, `surprise-uppercut`, `hurricane-kick`, `flying-kick`, `fireball`
- **Movement**: `walking`, `walk-1`, `walk-2`, `walking-2` through `walking-10`, `walking-4-frames`, `walking-6-frames`, `walking-8-frames`, `running-4-frames`, `running-6-frames`, `running-8-frames`, `crouched-walking`, `sad-walk`, `scary-walk`
- **Actions**: `jumping-1`, `jumping-2`, `running-jump`, `two-footed-jump`, `running-slide`, `picking-up`, `drinking`, `throw-object`, `pushing`, `pull-heavy-object`
- **Special**: `breathing-idle`, `crouching`, `backflip`, `front-flip`, `getting-up`, `taking-punch`, `falling-back-death`

**Returns:**
```json
{
  "character_id": "7372d7e7-4f49-4ff0-8779-f0ce9085e312",
  "animation_jobs": ["job-xyz789", "job-uvw101", ...],
  "status": "processing",
  "estimated_time": "2-4 minutes depending on directions"
}
```

#### Step 2: Check Animation Status
Use the same `mcp_pixellab_get_character` tool - it includes animation status:

```python
mcp_pixellab_get_character(character_id="7372d7e7-4f49-4ff0-8779-f0ce9085e312")
```

**Returns when animations complete:**
```json
{
  "character_id": "...",
  "animations": [
    {
      "animation_id": "anim-123",
      "name": "Death Dissolve",
      "template": "falling-back-death",
      "status": "completed",
      "frames": {
        "south": ["frame1.png", "frame2.png", ...],
        "west": ["frame1.png", "frame2.png", ...],
        // ... all directions
      },
      "download_url": "https://pixellab.ai/download/animation-zip-..."
    }
  ]
}
```

---

### Character Management

#### List All Characters
```python
mcp_pixellab_list_characters(
    limit=10,  # Max results (1-50)
    offset=0,  # Skip first N characters
    tags="wizard,fire"  # Optional filter by tags (comma-separated, returns ANY match)
)
```

#### Delete Character
```python
mcp_pixellab_delete_character(character_id="7372d7e7-4f49-4ff0-8779-f0ce9085e312")
```

---

### Important Notes

1. **Timing**: Character creation takes 2-5 minutes, animations take 2-4 minutes. Use `Start-Sleep -Seconds 300` to wait.

2. **Asynchronous Pattern**:
   ```python
   # Create character
   result = mcp_pixellab_create_character(...)
   character_id = result["character_id"]
   
   # Wait 3-5 minutes
   # Then check status
   status = mcp_pixellab_get_character(character_id=character_id)
   
   # If status["status"] == "completed":
   #   Download using status["download_url"]
   ```

3. **Download Method**: The MCP returns URLs, use curl/wget in PowerShell:
   ```powershell
   curl.exe -o output.zip "https://pixellab.ai/download/..."
   ```

4. **File Organization**: Extract sprites and organize by enemy type:
   ```
   assets/sprites/enemies/
   ├── acid_hydra/
   │   ├── south.png
   │   ├── west.png
   │   └── ...
   ├── skeleton_warrior/
   │   ├── south.png
   │   └── ...
   ```

5. **Animation vs Static**: Most enemies use static sprites (single direction). Animations are for special death effects, boss intros, etc.

6. **Cost**: PixelLab requires a subscription. Operations consume credits - check your plan limits.

---

### Example: Complete Workflow for Acid Hydra Death Animation

```python
# 1. Create character (if not already created)
char_result = mcp_pixellab_create_character(
    description="acid hydra with three serpent heads dripping green poison",
    n_directions=8,
    size=48,
    name="Acid Hydra v2"
)

# 2. Wait 3-5 minutes
# Use: Start-Sleep -Seconds 300

# 3. Check if complete
status = mcp_pixellab_get_character(character_id=char_result["character_id"])
# If status["status"] != "completed", wait longer

# 4. Queue animation
anim_result = mcp_pixellab_animate_character(
    character_id=char_result["character_id"],
    template_animation_id="falling-back-death",
    action_description="dissolving into an acid puddle with green smoke rising",
    animation_name="Acid Death"
)

# 5. Wait 2-4 minutes
# Use: Start-Sleep -Seconds 240

# 6. Check animation status
final_status = mcp_pixellab_get_character(character_id=char_result["character_id"])
# Look for final_status["animations"][0]["status"] == "completed"

# 7. Download
# Use curl command from final_status["animations"][0]["download_url"]
```

---

### Tileset & Map Object Tools

PixelLab also supports:
- `mcp_pixellab_create_isometric_tile` - 3D-style tiles
- `mcp_pixellab_create_topdown_tileset` - Wang tilesets for seamless terrain
- `mcp_pixellab_create_sidescroller_tileset` - Platform game tilesets
- `mcp_pixellab_create_map_object` - Objects with transparent backgrounds

Refer to tool documentation for these advanced features.
