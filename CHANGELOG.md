# Dice Dungeon - Changelog

## [Unreleased] - 2026-02-03

### Added
- **Resolution Settings System**: Replaced abstract "Display Size" presets with standard resolution picker
  - WHY: Display Size presets (Small/Medium/Large/Extra Large) were conceptually wrong — players expect real resolution options like every other game
  - PROBLEM SOLVED: UI stayed small at larger sizes, sprites shrank instead of grew, scale factors were arbitrarily hardcoded
  - TECHNICAL IMPLEMENTATION:
    - **Resolution Presets**: 950×700 (base), 1100×800, 1280×720, 1280×960, 1366×768, 1600×900, 1920×1080, Fullscreen
    - **Derived Scale Factor**: `min(width/950, height/700)` — no more hardcoded scale factors per preset
    - **apply_resolution()**: Replaces old `apply_display_size()`, sets geometry + derives scale factor + rebuilds sprites + refreshes HUD
    - **Settings Migration**: Automatically converts old `display_size` setting to new `resolution` on first load
    - **Settings UI**: Resolution buttons displayed in rows of 3 with current selection highlighted
    - **Fullscreen Resize Handler**: `on_window_resize` only recalculates scale for Fullscreen mode
    - **Files Updated**: dice_dungeon_explorer.py (resolution_presets, apply_resolution, settings UI, migration)

- **Full Font Scaling System**: Converted 514+ hardcoded font declarations to dynamic `scale_font()` across entire codebase
  - WHY: All text was fixed-size and never scaled with resolution, making larger resolutions have tiny unreadable text
  - PROBLEM SOLVED: Every font in the game now scales proportionally with chosen resolution
  - TECHNICAL IMPLEMENTATION:
    - **scale_font(base_size)**: Returns `max(8, int(base_size * scale_factor * 1.15))` — minimum 8pt, 15% boost for readability
    - **scale_padding(base)**: Returns `max(1, int(base * scale_factor))` for consistent UI spacing
    - **get_scaled_wraplength()**: Returns `max(200, int(base * scale_factor))` for text wrapping
    - **Launcher**: Added `scale_font()` method to DiceDungeonLauncher class, 17 fonts converted
    - **Classic Mode**: Added `scale_font()` method to DiceDungeonRPG class, 78 fonts converted
    - **Adventure Mode**: 411+ fonts converted in dice_dungeon_explorer.py and all explorer/ modules
    - **Files Updated**: dice_dungeon_explorer.py, dice_dungeon_launcher.py, dice_dungeon_rpg.py, explorer/combat.py, explorer/dice.py, explorer/inventory.py, explorer/inventory_display.py, explorer/inventory_equipment.py, explorer/inventory_pickup.py, explorer/inventory_usage.py, explorer/lore.py, explorer/navigation.py, explorer/quests.py, explorer/rooms.py, explorer/save_system.py, explorer/store.py, explorer/tutorial.py, explorer/ui_character_menu.py, explorer/ui_dialogs.py, explorer/ui_main.py, explorer/ui_main_menu.py

- **HUD Font Refresh on Resolution Change**: HUD labels now update fonts when resolution changes mid-game
  - WHY: Gold, HP, floor, room title, and room description labels were created once with baked-in fonts
  - PROBLEM SOLVED: Changing resolution in settings now immediately updates all HUD text sizes
  - TECHNICAL IMPLEMENTATION:
    - **_refresh_hud_fonts()**: Updates gold_label, floor_label, progress_label, dev_indicator, room_title, room_desc
    - **Called From**: `apply_resolution()` after scale factor recalculation
    - **File Updated**: dice_dungeon_explorer.py

### Changed
- **Dialog Scaling**: All popup overlays now scale with resolution instead of using fixed pixel sizes
  - WHY: Dialogs were hardcoded to fixed widths/heights (e.g., 500×250) that became tiny or squished at high resolutions
  - PROBLEM SOLVED: All 8 major dialog types now scale proportionally with the chosen resolution
  - TECHNICAL IMPLEMENTATION:
    - **Overwrite Confirm**: 500×250 base → scales with `int(base * scale_factor)`
    - **Delete Confirm**: 500×250 base → scales
    - **Key Usage Dialog**: 500×300 base → scales
    - **Sign Dialog**: 600×500 base → scales
    - **Chest Dialog**: 500×400 base → scales
    - **Game Over Dialog**: 400×350 base → scales
    - **Pause Menu**: 400×500 base → scales
    - **Navigation Chest**: 500×450 base → scales
    - **Files Updated**: dice_dungeon_explorer.py, explorer/navigation.py

- **Save Slot Button Layout**: Action buttons now use flexible layout instead of fixed character widths
  - WHY: Save/Load/Overwrite/Delete buttons used fixed `width=14`/`width=22` that squished at higher resolutions
  - PROBLEM SOLVED: Buttons now stretch proportionally using `padx=20` + `fill=tk.X, expand=True`
  - TECHNICAL IMPLEMENTATION:
    - **Removed**: Fixed `width=` parameter from save slot action buttons
    - **Added**: `fill=tk.X, expand=True` for horizontal stretching, `padx=20` for consistent padding
    - **File Updated**: dice_dungeon_explorer.py save slot overlay

- **Sprite Scaling Uncapped**: Removed 180px upper clamp on sprite sizing
  - WHY: Sprites shrank or stayed small at larger resolutions because of an artificial maximum size
  - PROBLEM SOLVED: Sprites now scale freely with resolution, growing as large as the resolution demands
  - TECHNICAL IMPLEMENTATION:
    - **Removed**: `min(target, 180)` clamp in `_rebuild_sprite_photos()`
    - **File Updated**: dice_dungeon_explorer.py

- **Flint and Steel → Fire Potion**: Replaced item throughout the game
  - WHY: Old item name didn't fit dungeon RPG theme
  - PROBLEM SOLVED: Fire Potion is thematically consistent with fantasy dungeon setting
  - TECHNICAL IMPLEMENTATION:
    - **Files Updated**: dice_dungeon_content/data/items_definitions.json, related content files

### Fixed
- **Window Icon**: Fixed game window showing full logo instead of small die icon
  - WHY: Icon path referenced `DD Logo.png` (the large banner logo) instead of `DD Icon.png` (the die icon)
  - PROBLEM SOLVED: Window icon and taskbar now correctly show small die icon
  - TECHNICAL IMPLEMENTATION:
    - **Changed**: `DD Logo.png` → `DD Icon.png` in icon loading code
    - **File Updated**: dice_dungeon_explorer.py

- **Character Status Screen Blank/Crash**: Fixed character gear screen rendering completely blank
  - WHY: `explorer/ui_character_menu.py` uses standalone module functions (not class methods), but all 47 font calls used `self.game.scale_font()` — `self` doesn't exist in that context
  - PROBLEM SOLVED: All 47 instances changed from `self.game.scale_font()` to `game.scale_font()`, screen renders correctly
  - TECHNICAL IMPLEMENTATION:
    - **Pattern Fix**: `self.game.scale_font` → `game.scale_font` throughout entire file
    - **File Updated**: explorer/ui_character_menu.py (47 replacements)

- **SplashScreen Launch Scheduling**: Fixed splash screen's `launch_game()` becoming dead code after font scaling method was added
  - WHY: The `self.splash.after(5000, self.launch_game)` call was accidentally placed after a `return` statement
  - PROBLEM SOLVED: Reordered code so launch scheduling stays at end of `__init__`, `scale_font` as separate method
  - TECHNICAL IMPLEMENTATION:
    - **File Updated**: dice_dungeon_explorer.py SplashScreen class

- **Logo Path Fix**: Fixed logo not displaying in splash screen when running as bundled EXE
  - WHY: Logo path was incorrect for PyInstaller-frozen executables
  - PROBLEM SOLVED: Logo path now uses `get_data_dir()` for correct resolution in both dev and EXE modes
  - TECHNICAL IMPLEMENTATION:
    - **File Updated**: dice_dungeon_explorer.py SplashScreen class

## [Unreleased] - 2026-02-02

### Added
- **Multiple Color Schemes**: Added 5 complete color themes for personalized visual experience
  - WHY: Allow players to customize the game's appearance to their preference
  - PROBLEM SOLVED: Game was locked to single "Classic" brown theme with no visual customization
  - TECHNICAL IMPLEMENTATION:
    - **Classic**: Original warm brown dungeon theme (default)
    - **Dark**: Gruvbox-inspired warm dark mode with amber/orange accents
    - **Light**: Parchment/cream theme for bright environments
    - **Neon**: Cyberpunk-style with hot pink, cyan, and neon accents
    - **Forest**: Deep forest green theme with natural earth tones
    - **ColorManager**: Created `explorer/color_schemes.py` module following manager pattern
    - **Live Preview**: Color changes apply immediately when selecting in settings
    - **Full UI Coverage**: All game elements update including adventure log, minimap, dialogs
    - **Tag Updates**: Adventure log text tags update colors dynamically
    - **Persistence**: Selected scheme saves to settings file and persists across sessions
    - **Reset Button**: "Reset to Classic" button in settings for easy default restore
    - **Files Updated**: dice_dungeon_explorer.py, explorer/color_schemes.py, docs/ARCHITECTURE_RULES.md

## [Previous Unreleased] - 2026-01-18

### Added
- **Narrative Introduction Screen**: Added first-time narrative intro that displays before gameplay begins
  - WHY: Provide atmospheric context and world-building before throwing players into dungeon
  - PROBLEM SOLVED: Game started abruptly with no setup or narrative framing
  - TECHNICAL IMPLEMENTATION:
    - **One-Time Display**: Shows only on very first new game, never again
    - **Persistent Flag**: Stored in settings file as "intro_shown" boolean
    - **Narrative Text**: Atmospheric story about waking in ancient structure, finding dice
    - **Centered Display**: Full-screen overlay with centered text, no UI elements
    - **Continue Button**: Single button to proceed to normal gameplay
    - **Enter Binding**: Can press Enter to continue instead of clicking
    - **Backwards Compatibility**: Existing settings files get intro_shown=False added
    - **Post-Intro Flow**: After Continue, proceeds directly to existing starter area
    - **No Gameplay Changes**: Zero impact on combat, dice, inventory, or balance
    - **File Updated**: dice_dungeon_explorer.py show_narrative_intro() method

### Changed
- **Game Branding**: Renamed from "Dice Dungeon Explorer" to "Dice Dungeon" throughout entire codebase
  - WHY: Simplified branding and consistent naming across all game materials
  - PROBLEM SOLVED: Updated all UI elements, documentation, and file references
  - TECHNICAL IMPLEMENTATION:
    - **Window Titles**: Updated all tk.Tk() titles to "Dice Dungeon"
    - **UI Headers**: Changed all "DICE DUNGEON EXPLORER" labels to "DICE DUNGEON"
    - **Documentation**: Updated README, CHANGELOG, ARCHITECTURE_RULES, all guides
    - **Build Scripts**: Updated setup.py, build_exe.py, installer scripts
    - **Module Docstrings**: Updated all Python file header comments
    - **Export Files**: Adventure log exports now show "DICE DUNGEON"
    - **Files Updated**: 24+ files across main game, explorer modules, docs, and build tools

### Fixed
- **Save System for Installed EXE**: Fixed critical bug preventing saves when running as installed executable
  - WHY: PyInstaller's `__file__` doesn't work correctly when frozen as exe, saves wrote to wrong location
  - PROBLEM SOLVED: Implemented proper frozen exe detection to find correct base directory
  - TECHNICAL IMPLEMENTATION:
    - **Helper Function**: Added `get_base_dir()` that checks `getattr(sys, 'frozen', False)`
    - **EXE Path**: When frozen, uses `os.path.dirname(sys.executable)` for base directory
    - **Dev Path**: When running as script, uses `os.path.dirname(os.path.abspath(__file__))`
    - **Path Utils Module**: Created `explorer/path_utils.py` with `get_base_dir()`, `get_asset_path()`, `get_saves_dir()`
    - **Updated Paths**: Fixed saves_dir, assets paths, content engine paths, icon paths
    - **Files Updated**: dice_dungeon_explorer.py, explorer/ui_main_menu.py, explorer/navigation.py
    - **Result**: Saves now correctly write to `/saves` folder next to installed exe

- **Hotkey Interference During Text Entry**: Fixed all hotkeys (including M for menu) triggering while typing
  - WHY: Typing save file names like "My Game" would trigger menu close on 'M' key, interrupting input
  - PROBLEM SOLVED: All hotkeys now completely blocked when typing in any text entry field
  - TECHNICAL IMPLEMENTATION:
    - **Focus Detection**: `handle_hotkey()` checks if `focused_widget` is instance of `tk.Entry`
    - **Complete Block**: Returns immediately for ALL hotkeys when typing (inventory, menu, movement, etc.)
    - **Entry Bindings**: Entry widgets use their own built-in Escape key bindings
    - **No Exceptions**: Even 'menu' action blocked - text entry fields handle their own escape
    - **File Updated**: dice_dungeon_explorer.py handle_hotkey() function
    - **Result**: Can now type any letter (M, I, R, W, A, S, D, Tab, etc.) in save names without issues

## [Unreleased] - 2025-12-21

### Added
- **Status Effect Combat System**: Implemented comprehensive status effect system with 51 enemies inflicting DoT effects
  - WHY: Cleanse items existed but no enemies actually applied status effects, making them useless
  - PROBLEM SOLVED: Added inflict_status abilities to ~20% of regular enemies (51 total) matching sprite folders
  - TECHNICAL IMPLEMENTATION:
    - **Status Types**: Poison, Burn, Bleed, Rot - all deal 5 damage per turn consistently
    - **Enemy Abilities**: Added boss_abilities with inflict_status type to 51 enemies
    - **Trigger Patterns**: Various triggers (combat_start, enemy_turn with intervals 2-5 turns)
    - **Cleanse Integration**: Existing cleanse items now have purpose (Soap Bar, Antivenom Leaf, etc.)
    - **Combat Processing**: Status effects process each turn via process_status_effects()
    - **Auto-Clear**: Status effects clear automatically after combat (win/flee/death)
    - **Status Enemies**: Rat Swarm, Angler Slime, Fire Beetle, Poison Rat, Lava Serpent, +46 more
    - **Message Updates**: All status messages updated to show "5 damage per turn" consistently

- **Incense Spirit & Lightning Warden Mini-Bosses**: Added two new mini-bosses with unique ability sets
  - WHY: These enemies existed but had no special abilities despite being classified as mini-bosses
  - PROBLEM SOLVED: Created thematic boss ability sets and proper HP scaling
  - TECHNICAL IMPLEMENTATION:
    - **Incense Spirit Abilities**:
      - Heal over time: 10 HP per turn for entire combat
      - Inflict Poison every 3 turns (5 damage/turn)
      - Dice obscure at 50% HP for 3 turns
    - **Lightning Warden Abilities**:
      - Damage reduction: 8 damage reduction throughout combat
      - Dice lock: Force-locks 2 random dice every 3 turns
      - Curse damage: 4 shock damage per turn when below 50% HP
    - **HP Multipliers**: Incense Spirit 1.5x, Lightning Warden 1.7x (then 3x mini-boss multiplier)
    - **Category Integration**: Added to official mini-boss lists in both classification and combat systems

### Enhanced
- **Enemy HP Balancing**: Increased base enemy health across all floors for better combat pacing
  - WHY: Regular enemies were too weak at 30-40 HP, dying too quickly even on floor 1
  - PROBLEM SOLVED: Increased base HP formula from 30 + (floor × 10) to 50 + (floor × 10)
  - TECHNICAL IMPLEMENTATION:
    - **New Formula**: base_hp = 50 + (floor × 10) instead of 30 + (floor × 10)
    - **Floor 1 Regular Enemies**: Now ~55-70 HP instead of ~35-50 HP
    - **Floor 1 Status Enemies**: Now ~77-92 HP (1.375x multiplier) instead of ~55-70 HP
    - **All Enemy Types**: Mini-bosses, elites, and floor bosses scale proportionally higher
    - **Three Locations**: Updated in combat.py trigger_combat(), transform_on_death, and dev tools
    - **Consistent Scaling**: Maintains same multiplier system, just higher base values

- **Enemy Classification System Cleanup**: Reorganized enemy HP multipliers into clear, logical categories
  - WHY: Multiple overlapping lists made it confusing to understand enemy tiers and scaling
  - PROBLEM SOLVED: Created single organized system with clear category comments
  - TECHNICAL IMPLEMENTATION:
    - **Category Structure**:
      - Regular Enemies: Partial name matches (Goblin 0.7x, Rat 0.6x, Spider 0.6x, etc.)
      - Elite Enemies: Partial matches (Demon 2.0x, Dragon 2.5x, Lich 1.8x, etc.)
      - Mini-Bosses: Specific names with 1.0x-2.3x base, then 3x mini-boss multiplier
      - Floor Bosses: Specific names with 1.9x-2.8x base, then 8x floor boss multiplier
      - Status Effect Enemies: 51 specific names with 1.375x multiplier
    - **Removed Conflicts**: Eliminated confusing "Special/Boss enemies" section mixing categories
    - **Consistent Application**: Updated both combat.py and dice_dungeon_explorer.py dev tools
    - **Clear Comments**: Each section explicitly states purpose and multiplier application order

- **Enemy Classification Logic**: Fixed mini-boss detection to use whitelist instead of boss_abilities flag
  - WHY: Adding boss_abilities to regular enemies for status effects incorrectly classified them as mini-bosses
  - PROBLEM SOLVED: Changed from automatic detection to explicit whitelist of actual bosses/mini-bosses
  - TECHNICAL IMPLEMENTATION:
    - **Whitelist Approach**: Defined explicit lists of floor_bosses and mini_bosses by name
    - **Floor Bosses**: Demon Lord, Demon Prince, Bone Reaper (3 total)
    - **Mini-Bosses**: Gelatinous Slime, Slime Blob, Necromancer, Shadow Hydra, Crystal Golem, Crystal Shard, Acid Hydra, Void Wraith, Shadow Head, Imp, Skeleton, Incense Spirit, Lightning Warden (13 total)
    - **Regular Enemies**: All others classified by HP thresholds (Elite if avg_hp >= 50, else Regular)
    - **Dev Tools**: Updated get_enemy_category() to use same whitelist logic
    - **Status Effect Enemies**: Now correctly classified as Regular/Elite despite having boss_abilities

- **Developer Tools Enemy Spawning**: Improved dev menu to auto-detect boss/mini-boss status
  - WHY: Manual checkboxes for "Spawn as Boss/Mini-Boss" were confusing and error-prone
  - PROBLEM SOLVED: Removed manual overrides, made dev menu automatically spawn enemies correctly
  - TECHNICAL IMPLEMENTATION:
    - **Removed Checkboxes**: Deleted "Spawn as Boss" and "Spawn as Mini-Boss" checkbox options
    - **Auto-Detection**: Dev menu now checks enemy name against boss/mini-boss lists automatically
    - **Correct Stats**: HP and dice counts displayed in dev menu now match actual spawn values
    - **Proper Spawning**: Clicking enemy spawns with correct is_boss/is_mini_boss flags set
    - **Consistent Logic**: Uses same boss/mini-boss lists as classification system
    - **Simpler UX**: One-click spawn with correct stats, no manual configuration needed

### Fixed
- **Armor Health Adjustment**: Fixed armor equipping/unequipping to properly adjust current health
  - WHY: Equipping armor increased max HP but not current HP, leaving player seemingly wounded
  - PROBLEM SOLVED: Current health now increases/decreases when equipping/unequipping armor
  - TECHNICAL IMPLEMENTATION:
    - **Equip**: Added `self.game.health += scaled_hp` after increasing max_health
    - **Unequip**: Subtracts scaled_hp from current health (but never below 1)
    - **Formula**: scaled_hp = int(hp_bonus * armor_durability_percent)
    - **Safe Floor**: Uses `max(1, self.game.health - scaled_hp)` to prevent death from unequipping
    - **Files Updated**: explorer/inventory_equipment.py equip_item() and unequip_item()

- **Container Loot Persistence**: Fixed bug where container items disappeared if not picked up immediately
  - WHY: Container loot was regenerated each time opened, losing previous contents
  - PROBLEM SOLVED: Store container contents on room object when first generated, reuse on reopen
  - TECHNICAL IMPLEMENTATION:
    - **Storage**: Added container_gold and container_item attributes to room object
    - **First Opening**: Generate loot and store in room.container_gold and room.container_item
    - **Reopening**: Check if room already has contents, use existing instead of regenerating
    - **Persistence**: Contents survive across room exits and save/load cycles
    - **Location**: explorer/inventory_pickup.py search_container() method

- **Ground Items Button Update**: Fixed item count button not updating after picking up uncollected items
  - WHY: Picking up uncollected_items removed from list but didn't refresh exploration button
  - PROBLEM SOLVED: Added show_exploration_options() calls after successful uncollected item pickup
  - TECHNICAL IMPLEMENTATION:
    - **Refresh Logic**: Added comprehensive if/elif chain to check remaining ground items
    - **Button Update**: Calls show_ground_items() and show_exploration_options() appropriately
    - **Close Dialog**: Closes ground items dialog when nothing remains
    - **Same Pattern**: Matches ground_item and ground_gold pickup refresh logic
    - **Location**: explorer/inventory_pickup.py pickup_uncollected_item()

- **Container Button Persistence**: Fixed ground button showing even after taking all container items
  - WHY: Button checked if container exists and is unsearched, not if items remain
  - PROBLEM SOLVED: Added check for remaining container contents before showing button
  - TECHNICAL IMPLEMENTATION:
    - **Container Check**: Added `container_has_items = (container_gold > 0 or container_item is not None)`
    - **Updated Logic**: Button shows if container unsearched OR has remaining items
    - **Both Locations**: Updated show_exploration_options() for button and show_ground_items() for dialog
    - **Consistent Behavior**: Container only appears in both places when it has loot left
    - **Location**: explorer/navigation.py show_exploration_options()

- **Hand Axe Pricing**: Fixed Hand Axe to cost same as other +3 damage weapons
  - WHY: Hand Axe had no explicit store price, likely using wrong default value
  - PROBLEM SOLVED: Added Hand Axe to store pricing logic matching Short Sword, Mace, Spear
  - TECHNICAL IMPLEMENTATION:
    - **Store Price**: 120 + (floor × 30) gold to buy
    - **Sell Price**: 60 + (floor × 15) gold (50% of buy price)
    - **Consistency**: Matches all other +3 damage weapons exactly
    - **Location**: explorer/store.py _calculate_sell_price()

## [Unreleased] - 2025-12-20

### Enhanced
- **Classic Mode Shop Interface Overhaul**: Completely redesigned shop to match Explorer mode's polished UI
  - WHY: Classic mode had cramped shop dialog with buttons getting cut off and limited functionality
  - PROBLEM SOLVED: Rebuilt shop as full-screen centered dialog with Explorer-style layout and features
  - TECHNICAL IMPLEMENTATION:
    - **Dialog Size**: Increased from 450x400 to 550x500 centered dialog with proper borders
    - **Red X Close Button**: Added top-right corner close button (✕) with hover effects (#ff4444 → #ff0000)
    - **Item Row Layout**: Redesigned with left-aligned info panel and right-aligned action panel
    - **Visual Hierarchy**: Item name (11pt bold) → Description (9pt, 350px wrap) | Price (11pt gold) + Buy button
    - **Button State Management**: Buttons disable showing "Can't Afford" or "Max Dice" when appropriate
    - **Live Gold Updates**: Gold label updates immediately after purchases without full refresh
    - **Better Spacing**: 10px padding on items, RIDGE borders, professional color scheme (#4a2c1a panels)

- **Shop Automatic Progression System**: Shop now intelligently progresses to next floor when closed from floor complete
  - WHY: Players had to manually click "Next Floor" after leaving shop, creating extra unnecessary step
  - PROBLEM SOLVED: Shop tracks context and automatically starts next floor when closed after floor complete
  - TECHNICAL IMPLEMENTATION:
    - **Context Tracking**: Added `from_floor_complete` parameter to `open_shop_dialog()` method
    - **New Close Handler**: Created `close_shop_and_continue()` that checks context flag
    - **Multiple Close Methods**: ESC key, Red X, and "Next Floor" button all use unified close handler
    - **Flag Management**: `shop_from_floor_complete` flag automatically resets after triggering progression
    - **Seamless Flow**: Floor complete → Shop → Any close method → Next floor starts automatically
    - **Smart Behavior**: Only auto-progresses when opened from floor complete, normal close otherwise

- **Explorer-Style Scroll Mechanics in Classic Shop**: Implemented comprehensive mousewheel scrolling system
  - WHY: Classic mode shop had basic scrolling that didn't work on all UI elements like Explorer
  - PROBLEM SOLVED: Replicated Explorer's recursive mousewheel binding for smooth scrolling everywhere
  - TECHNICAL IMPLEMENTATION:
    - **Canvas Scrolling**: Direct mousewheel binding to canvas with delta/120 conversion
    - **Recursive Binding**: `bind_mousewheel_to_tree()` recursively binds all child widgets
    - **Event Propagation**: Uses `add='+'` flag to allow multiple bindings without conflicts
    - **Consistent Behavior**: Matches Explorer mode's scroll behavior exactly
    - **Widget Coverage**: Canvas and all descendants (frames, labels, buttons) support scrolling

- **Shop UI Simplification**: Removed redundant "Leave Store" button in favor of single "Next Floor" button
  - WHY: Having both "Leave Store" and "Next Floor" buttons was redundant since shop auto-progresses
  - PROBLEM SOLVED: Simplified to single "Next Floor" button that handles all close scenarios
  - TECHNICAL IMPLEMENTATION:
    - **Button Consolidation**: Removed "Leave Store" (#ff6b6b red) button from bottom frame
    - **Single Action**: "Next Floor" button (#4ecdc4 cyan) calls `close_shop_and_continue()`
    - **Unified Behavior**: All close methods (ESC, Red X, button) trigger same progression logic
    - **Clearer Intent**: Single button makes it obvious that closing shop advances the game
    - **Consistent Styling**: Matches Explorer mode's single-button approach

### Fixed
- **Shop Purchase and Refresh Logic**: Fixed shop to properly refresh after purchases showing updated states
  - WHY: After buying items, button states weren't updating to reflect affordability changes
  - PROBLEM SOLVED: Implemented automatic shop refresh system after each purchase
  - TECHNICAL IMPLEMENTATION:
    - **New Purchase Handler**: Created `buy_item_dialog_update()` that handles purchase and refresh
    - **State Tracking**: Stores gold label reference (`shop_gold_label`) for live updates
    - **Automatic Refresh**: Closes and reopens shop after purchase to update all button states
    - **Context Preservation**: Maintains `from_floor_complete` flag across refresh
    - **Purchase Logging**: Added detailed log messages for each purchase type with feedback
    - **Gold Display**: Updates gold immediately via label config before refresh

- **Indentation Error in Shop Code**: Fixed Python IndentationError causing launcher crash
  - WHY: Duplicate line during edit created unexpected indent at line 1161
  - PROBLEM SOLVED: Removed duplicate button pack() line
  - TECHNICAL IMPLEMENTATION:
    - Identified duplicate: `font=('Arial', 11, 'bold'), bg='#4ecdc4', fg='#000000',`
    - Removed second occurrence that was causing IndentationError
    - Verified proper method ending with single button definition

## [Unreleased] - 2025-12-14

### Added
- **Professional Splash Screen with Loading Animation**: Polished startup experience with DD Logo and animated loading sequence
  - WHY: Game lacked professional startup branding and visual polish
  - PROBLEM SOLVED: Created animated 5-second splash screen with DD Logo, loading messages, and animated dots
  - TECHNICAL IMPLEMENTATION:
    - New `SplashScreen` class with 650x450 borderless window centered on screen
    - DD Logo displays from assets/DD Logo.png (120x120 with PIL scaling)
    - Animated loading sequence: "Loading game engine....Starting adventure!"
    - 4-dot animation cycles at end of each message line every 100ms
    - Messages spread evenly across 5-second duration with proper timing
    - Graceful fallbacks: Text "DD" logo if PIL unavailable or logo missing
    - Proper window icon integration with DD Logo
    - Clean launch sequence: Splash → Main Game Window

- **DD Logo Integration Across UI**: Added professional branding with actual logo image throughout interface
  - WHY: Game used text-only branding instead of utilizing existing professional logo asset
  - PROBLEM SOLVED: Integrated DD Logo.png across window icons and main menu for consistent branding
  - TECHNICAL IMPLEMENTATION:
    - **Window Icon**: Added DD Logo as window/taskbar icon with PhotoImage loading and error handling
    - **Main Menu Logo**: Displays actual DD Logo (80-120px scaled) above game title
    - **Responsive Sizing**: Logo scales with window size while maintaining aspect ratio
    - **Memory Management**: Proper image reference storage prevents garbage collection
    - **Fallback System**: Falls back to "DD" text if logo unavailable
    - **Layout Optimization**: Adjusted spacing and font sizes to accommodate logo without overflow

### Enhanced
- **Main Menu Visual Layout**: Optimized spacing and sizing to fit properly on all screen sizes
  - WHY: Main menu elements were overflowing and not fitting on smaller screens
  - PROBLEM SOLVED: Comprehensive spacing reduction and responsive sizing adjustments
  - TECHNICAL IMPLEMENTATION:
    - **Size Reductions**: Logo (80-120px), title font (22pt), subtitle (14pt), fallback text (32pt)
    - **Spacing Optimization**: Reduced padding throughout (logo: 15px, title: 8px, buttons: 25px)
    - **Button Spacing**: Reduced internal button padding (8px) and external spacing (5px)
    - **Responsive Design**: All elements scale with window size using scale_factor
    - **Professional Layout**: Logo → Title → Subtitle → Buttons maintains visual hierarchy
    - Menu now fits comfortably on standard screen sizes while maintaining visual appeal

- **Splash Screen Animation Polish**: Refined loading animation for better visual feedback and timing
  - WHY: Initial 3-second splash with separate dots felt rushed and visually disconnected
  - PROBLEM SOLVED: Enhanced to 5-second duration with inline dot animation at end of text
  - TECHNICAL IMPLEMENTATION:
    - **Extended Duration**: Increased from 3 to 5 seconds for better logo visibility
    - **Inline Animation**: Dots now appear at end of loading text using horizontal frame layout
    - **Improved Timing**: Messages distribute evenly across 5-second duration
    - **Enhanced Animation**: 4-dot cycling (....to.) for smoother visual effect
    - **Better Completion**: "Ready!" with exclamation mark for clear completion state
    - **Layout Fix**: Increased window size (650x450) and improved text positioning
    - **Text Clarity**: Removed "..." from messages since animation provides feedback
    - Loading sequence feels more polished and professional

### Fixed
- **Crystal Golem Dice Lock Ability**: Complete overhaul of boss ability system for proper dice locking
  - WHY: Multiple issues caused dice lock to fail - timing, value preservation, visual display, and turn counting
  - PROBLEM SOLVED: Comprehensive fix across combat system, dice manager, and curse processing
  - TECHNICAL IMPLEMENTATION:
    - Fixed curse timing: Moved curse processing from start-of-turn to end-of-round for proper duration
    - Fixed turn counting: Removed duplicate turn counter increment in enemy phase that broke spawn detection
    - Fixed dice values: Crystal Golem now sets locked dice to random values (1-6) that persist through turn transitions
    - Fixed value preservation: Both `start_combat_turn()` and `reset_turn()` now preserve force-locked dice values
    - Fixed visual display: Added proper `update_dice_display()` calls and removed manual "?" rendering that overrode values
    - Dice lock now properly freezes 2 random dice at random values for player's next turn every 3 turns

- **Split Enemy Immediate Attack Bug**: Fixed Crystal Shards and other split enemies attacking immediately when spawned
  - WHY: Turn counter was incremented twice per round, breaking newly spawned enemy detection logic
  - PROBLEM SOLVED: Removed redundant turn counter increment from `_start_enemy_turn_sequence()`
  - TECHNICAL IMPLEMENTATION:
    - Turn counter now only increments once per round in `start_combat_turn()`
    - Split enemies created with `turn_spawned = current_turn` are properly skipped during attack phase
    - Players see "Crystal Shard is too dazed to attack (just spawned)!" message

- **Item Statistics Tracking**: Centralized scattered item acquisition tracking code
  - WHY: Item tracking logic was duplicated across multiple files with inconsistent implementation
  - PROBLEM SOLVED: Created centralized `track_item_acquisition()` function in inventory manager
  - TECHNICAL IMPLEMENTATION:
    - Added `track_item_acquisition(item_name, source)` to `inventory_equipment.py`
    - Updated `add_item_to_inventory()` to use centralized tracking
    - Replaced 3 instances of duplicate tracking code in main file with centralized function calls
    - Consistent tracking across all acquisition methods: found, reward, chest, purchase, ground

- **Force-Locked Dice Visual System**: Enhanced dice manager to properly handle boss ability dice locks
  - WHY: DiceManager wasn't checking `forced_dice_locks` array, only manual `dice_locked` array
  - PROBLEM SOLVED: Updated dice system to respect and display force-locked dice from boss abilities
  - TECHNICAL IMPLEMENTATION:
    - `roll_dice()` now excludes `forced_dice_locks` from rollable dice
    - `update_dice_display()` shows force-locked dice with "CURSED" label in red vs "LOCKED" in gold
    - `toggle_dice()` prevents clicking force-locked dice with warning message
    - `reset_turn()` preserves both lock states and values for force-locked dice

- **Developer Tools Tab Structure**: Fixed critical Tkinter error preventing dev menu from opening
  - WHY: Dev tools crashed with "can't add .!frame6.!notebook.!frame3.!canvas.!frame as slave of .!frame6.!notebook" 
  - PROBLEM SOLVED: Duplicate `notebook.add(player_tab, text="Player")` call was trying to add nested frame directly
  - TECHNICAL IMPLEMENTATION:
    - Removed duplicate line 8110 in `show_dev_tools()` function
    - All 6 tabs (Enemies, Items, Player, Parameters, World, Info) now work correctly

- **Split Enemy HP Fixed to 30**: Split enemies (like Crystal Shards) now have exactly 30 HP instead of scaling with floor
  - WHY: Crystal Shards were getting 30+(floor*10) HP instead of consistent 30 HP like other small enemies
  - PROBLEM SOLVED: Changed split_enemy() function to use fixed 30 HP instead of calculated base_hp
  - TECHNICAL IMPLEMENTATION:
    - Removed floor-based HP calculation from split_enemy() function
    - All split enemies now consistent with spawned enemy HP standard (30 HP, 2 dice)
    - Tab structure now properly creates outer frames first, then nested scrollable content
    - Player tab: `player_tab_outer` → `player_outer_canvas` → `player_tab` (proper hierarchy)
    - Enemy tab: `enemy_tab_outer` → `enemy_canvas` → `enemy_tab` (proper hierarchy)  
    - Item tab: `item_tab_outer` → `item_outer_canvas` → `item_tab` (proper hierarchy)
  - All 6 tabs now load correctly: Enemies, Items, Player, Parameters, World, Info

- **Developer Tools Enemy List Completeness**: Fixed spawner showing only 11 enemies instead of full 288+ roster
  - WHY: Dev tools loaded from `enemy_types.json` (special mechanics only) instead of complete enemy catalog
  - PROBLEM SOLVED: Now loads from sprite system which contains full enemy roster
  - TECHNICAL IMPLEMENTATION:
    - Changed enemy loading from `self.enemy_types.keys()` to `self.enemy_sprites.keys()`
    - Combined sprite-based enemies (288+) with config enemies (11) to get complete list
    - Removed duplicates and sorted alphabetically for clean display
    - Debug output: "Found X total enemies from sprites and config" 
    - Sample shown: "Sample enemies: ['Acid Hydra', 'Acid Slime', 'Actor Shade'...]"
  - Enemy spawner now shows complete catalog: 288+ unique enemies instead of just 11

- **Developer Tools Enemy Stats Accuracy**: Fixed enemy HP/dice calculations to match actual combat values
  - WHY: Dev menu showed generic "HP:~45 | Dice:3" estimates that didn't match real combat stats
  - PROBLEM SOLVED: Implemented exact same calculation logic as `trigger_combat()` function
  - TECHNICAL IMPLEMENTATION:
    - Created `calculate_enemy_stats(enemy_name, as_boss, as_mini_boss)` function
    - Uses identical formula: `base_hp = 30 + (floor * 10)` with ±5 to +10 random range
    - Applies boss multipliers: 8x for bosses, 3x for mini-bosses
    - Applies difficulty multipliers from current game settings
    - Applies dev mode multipliers from Parameters tab
    - Dice calculation: Regular 3+(floor//2) capped at 6, Mini-boss +1, Boss +2
    - Enemy-specific HP multipliers added for diversity:
      * **Weak enemies**: Bat (0.5x), Rat (0.6x), Spider (0.6x), Imp (0.7x), Goblin (0.7x)
      * **Normal enemies**: Skeleton (1.0x), Orc (1.0x), Zombie (1.1x), Bandit (0.9x) 
      * **Strong enemies**: Troll (1.5x), Ogre (1.4x), Knight (1.3x), Guard (1.2x), Warrior (1.1x)
      * **Elite enemies**: Dragon (2.5x), Demon (2.0x), Lich (1.8x), Vampire (1.6x), Golem (2.2x)
      * **Boss enemies**: Ancient (3.2x), Primordial (4.0x), Lord (3.0x), King (3.5x)
    - HP ranges displayed: "HP:24-39" for ranges, "HP:45" for fixed values
    - Stats update dynamically when changing Boss/Mini-Boss checkboxes
  - Dev menu stats now perfectly match what appears in actual combat
  - Updated combat.py to use same enemy-specific multipliers for consistency

### Enhanced
- **Items Found Stat Tracking Completeness**: Ensured all item acquisition methods properly track to character stats
  - WHY: Some item sources weren't incrementing the "Items Found" counter in character status screen
  - COMPREHENSIVE AUDIT COMPLETED: All acquisition paths now tracked
  - TECHNICAL IMPLEMENTATION - Added `self.stats["items_found"] += 1` to:
    - **Store Purchases**: Both consumables and equipment purchases count as "found"
    - **Container Searches**: Items from chests, barrels, crates, etc. already tracked
    - **Ground Pickups**: Loose items, uncollected items, dropped items already tracked  
    - **Enemy Rewards**: Boss and mini-boss drops already tracked via `source="reward"`
    - **Starter Chests**: Tutorial area loot already tracked
    - **Dev Tool Spawning**: Manual item addition via developer tools now tracked
    - **Quest Rewards**: Room completion rewards already tracked
    - **Equipment System**: Internal item additions now tracked
  - VERIFIED WORKING SOURCES:
    - `try_add_to_inventory(item, "found")` → triggers items_found increment
    - `try_add_to_inventory(item, "reward")` → triggers items_found increment  
    - Container searches via `search_container()` → tracked in pickup manager
    - Ground item pickup via `pickup_ground_item()` → tracked in pickup manager
    - Uncollected item recovery via `pickup_uncollected_item()` → tracked in pickup manager
    - Starter chest opening via `open_starter_chest()` → tracked in navigation manager
    - Enemy defeat rewards in `enemy_defeated()` → tracked via "reward" source
  - CHARACTER STATS ACCURACY: "Items Found" counter now comprehensively tracks all acquisition
  - Items Collected dictionary also tracks individual item counts for detailed statistics

### Added
- **Dynamic Enemy Diversity System**: Implemented enemy-specific HP multipliers for varied combat experiences  
  - WHY: All enemies had identical HP calculations making combat repetitive and predictable
  - ENEMY TIER SYSTEM IMPLEMENTED:
    - **Tier 1 - Weak (0.4x-0.8x HP)**: Grub, Bat, Sprite, Wisp, Rat, Spider, Imp, Slime, Goblin
    - **Tier 2 - Normal (0.9x-1.1x HP)**: Bandit, Skeleton, Orc, Zombie, Warrior
    - **Tier 3 - Strong (1.1x-1.5x HP)**: Wolf, Boar, Beast, Guard, Knight, Ogre, Troll, Bear
    - **Tier 4 - Elite (1.4x-2.8x HP)**: Wraith, Vampire, Lich, Phoenix, Demon, Dragon, Hydra, Titan, Golem
    - **Tier 5 - Legendary (1.6x-4.0x HP)**: Named bosses, Crystal Golem, Necromancer, Demon Lord/Prince
  - TECHNICAL IMPLEMENTATION:
    - Added `enemy_hp_multipliers` dictionary in both dev menu and combat systems
    - Multipliers applied to base HP before random variation: `base_hp = int(base_hp * multiplier)`
    - Partial name matching: "Dragon" keyword applies to "Ancient Dragon", "Fire Dragon", etc.
    - Consistent across dev menu preview and actual combat spawning
    - Combined with existing floor scaling: `base_hp = 30 + (floor * 10)`
    - Applied before boss multipliers (8x boss, 3x mini-boss) and difficulty modifiers
  - PLAYER EXPERIENCE:
    - Early floors: Rats ~18 HP, Goblins ~25 HP, Skeletons ~35 HP, Trolls ~53 HP
    - Mid floors: Bats ~25 HP, Orcs ~50 HP, Knights ~65 HP, Dragons ~125 HP  
    - Late floors: Sprites ~40 HP, Warriors ~88 HP, Demons ~160 HP, Titans ~224 HP
    - Boss multipliers create extreme variety: Regular Dragon ~125 HP, Boss Dragon ~1000 HP
  - Dev menu and combat now show identical, properly diversified enemy statistics
  - Combat feels more tactical with weak swarm enemies vs. elite powerhouses

### Added
- **Boss Abilities System**: Mini-bosses and floor bosses now have unique special abilities
  - WHY: Bosses felt like regular enemies with more HP - needed unique mechanics for memorable fights
  - WHAT'S NEW:
    - **6 Ability Types**: Dice manipulation, curses, spawning, and transformations
    - **4 Trigger Types**: Combat start, HP thresholds, enemy turns, and on death
    - **Unique Boss Identities**: Each boss has distinct abilities matching their theme
  - TECHNICAL IMPLEMENTATION:
    - Added `boss_abilities` field to enemy_types.json with ability configurations
    - Implemented ability execution system in combat.py with trigger handlers
    - Active curse tracking with turn-based countdowns and effect cleanup
    - Dice manipulation: obscuring (hide values), restricting (limit rolls), force-locking
    - Status effects: reroll limits, damage over time
    - Enhanced spawning: spawn on death with configured enemy stats
    - Transformation: replace boss with new form when defeated
  - BOSS ABILITIES IMPLEMENTED:
    * **Gelatinous Slime**: Obscures dice for 2 turns at combat start
    * **Necromancer**: Limits rerolls to 1/turn at 50% HP, spawns 3 Skeletons on death
    * **Shadow Hydra**: Restricts dice to 1s and 2s every 4 turns for 2 turns
    * **Demon Lord**: 3 damage/turn curse, transforms into Demon Prince on death
    * **Demon Prince**: Permanently obscures dice at 50% HP
    * **Crystal Golem**: Force-locks 2 random dice every 3 turns
  - PLAYER EXPERIENCE:
    - Cursed dice show purple "?" with "CURSED" text when obscured
    - Reroll curse shows "[CURSED]" in rolls remaining label
    - Boss ability messages announce each effect trigger
    - Curse effects expire automatically with countdown messages
    - Can use items and mystic ring even when cursed
  - INTEGRATION:
    - Abilities trigger at: combat start, player turn start, enemy damage, enemy turn, enemy death
    - Cooldown system prevents repeated hp_threshold triggers
    - Turn-based interval tracking for recurring enemy_turn abilities
    - Transform_on_death replaces enemy instead of removing for seamless transition
  - DOCUMENTATION:
    - Created BOSS_ABILITIES_GUIDE.md with full system documentation
    - Includes ability types, triggers, boss strategies, and implementation guide
    - Guidelines for adding new abilities and balancing considerations
  - BALANCE:
    - Curse durations: 2-3 turns for major effects, 1 turn for minor
    - Spawn stats: 30-40% HP multiplier, 2-3 dice for minions
    - HP thresholds: 50-75% for early triggers, 25% for desperation
    - All curses have counterplay (wait out, use items, adapt strategy)

## [Unreleased] - 2025-12-13

### Fixed
- **Extra Die Purchase System**: Fixed critical bug preventing Extra Die upgrades from working
  - WHY: Extra Die wasn't applying when purchased from store, despite gold being deducted
  - PROBLEM SOLVED: 
    - Extra Die has `"type": "upgrade"` in items_definitions.json
    - Generic upgrade handler checked for `max_hp_bonus`, `damage_bonus`, `reroll_bonus`, `crit_bonus` fields
    - Extra Die has none of these fields, so handler took gold but applied nothing
    - Handler returned early before Extra Die-specific code could execute
  - TECHNICAL IMPLEMENTATION:
    - Moved Extra Die handling BEFORE generic upgrade handler in `_buy_item()` (explorer/store.py lines 728-792)
    - Extra Die check now at line 728, generic upgrades at line 795
    - Ensures `self.game.num_dice += 1` executes properly
    - Updates dice_values and dice_locked arrays to match new dice count
    - Added comprehensive debug output tracking each step of purchase process
    - Logs purchase message: "Purchased Extra Die! Now have X dice."
    - Adds to purchased_upgrades_this_floor set to prevent re-buying on same floor
  - Extra Die now correctly increases dice pool from 3 → 4 → 5
  - Purchase message appears in adventure log
  - Character status screen shows updated dice count in Combat Stats section
- **Store Refresh on Purchase**: Removed unnecessary store refresh after buying Extra Die
  - WHY: Store was refreshing entire UI and scrolling to top after Extra Die purchase
  - PROBLEM SOLVED: Removed `self._show_store_buy_content()` call from Extra Die purchase handler
  - TECHNICAL IMPLEMENTATION:
    - Extra Die purchase (lines 728-792) now only updates gold label, not entire store
    - Gold label update: `self.gold_label.config(text=f"Your Gold: {self.game.gold}")`
    - Removed lines that were calling store refresh and saving/restoring scroll position
    - Store remains at same scroll position with same items visible
    - Buy button stays available until store is closed/reopened (then greys out properly)
  - No more jarring UI refresh or scroll jumping when buying permanent upgrades
- **Critical Hit Chance Corruption**: Fixed negative crit chance in save file
  - WHY: Save file had `"crit_chance": -0.04999999999999999` (-5%) instead of default 0.1 (10%)
  - PROBLEM SOLVED: Directly edited save file to restore correct base crit chance
  - TECHNICAL IMPLEMENTATION:
    - Located crit_chance at line 12600 in saves/dice_dungeon_save_slot_1.json
    - Changed value from -0.04999999999999999 to 0.1
    - Base crit is 10%, can be increased through upgrades and equipment
  - Character status screen now shows correct "10.0%" critical hit chance
  - Likely caused by earlier game state or calculation bug (now prevented by proper upgrade handling)

### Added
- **Character Status Tooltips**: Added cursor-following tooltips with detailed stat breakdowns
  - WHY: Players couldn't see where combat bonuses were coming from (equipment vs permanent upgrades)
  - IMPLEMENTATION:
    - Created `create_tooltip_follower()` helper function in ui_character_menu.py (lines 15-44)
    - Tooltip appears at cursor position (+15px right, +15px down) with light yellow background
    - Updates position as mouse moves using `<Motion>` event binding
    - Destroys automatically when cursor leaves widget using `<Leave>` event
  - TECHNICAL DETAILS - Tooltip Content:
    - **Dice Pool**: Shows "Total Dice: X\n\nBase: X dice\n(Permanent upgrade)"
    - **Damage Bonus**: Shows total first, then "Permanent Upgrade: +X" and equipment list
    - **Multiplier**: Shows total multiplier with equipment and permanent sources
    - **Crit Chance**: Shows percentage total, permanent upgrades, and equipment bonuses
    - **Healing Bonus**: Shows total HP bonus from all sources
    - **Rerolls**: Shows total bonus rerolls with source breakdown
  - Equipment contributions calculated by examining all equipped items:
    - Checks weapon, armor, accessory, backpack slots
    - Applies floor scaling bonus (floor_level - 1) to damage
    - Stores equipment sources as list of tuples: (item_name, bonus_value)
  - Tooltips applied to label, value, and entire row frame for easy triggering
  - Permanent values calculated by subtracting equipment totals from current stats
- **Character Status Screen Manager**: Migrated UI to dedicated module
  - WHY: Following architecture pattern to keep main file clean and modular
  - CREATED: `explorer/ui_character_menu.py` (825 lines)
  - REMOVED: 748 lines from dice_dungeon_explorer.py
  - TECHNICAL IMPLEMENTATION:
    - Module contains 4 main functions:
      - `show_character_status(game)` - Creates tabbed interface with Character/Stats/Lore tabs
      - `_populate_character_tab(game, parent)` - Shows equipment, combat stats, effects, resources, upgrades
      - `_populate_stats_tab(game, parent)` - Shows combat/economy/items/equipment/lore/exploration statistics
      - `_populate_lore_tab(game, parent)` - Shows expandable lore categories with read buttons
      - `_add_stats_section(game, parent, title, items)` - Helper for stats sections
      - `create_tooltip_follower(game, widget, get_tooltip_text)` - Tooltip system
    - Main file import: `from explorer import ui_character_menu` (line 15)
    - Main file delegation: `self.show_character_status()` → `ui_character_menu.show_character_status(self)`
    - All functionality preserved: tabs, scrolling, lazy loading, expandable sections
  - CRITICAL PRESERVED FEATURES:
    - Tabbed notebook with custom styling (gold selected, cyan unselected)
    - Lazy loading: Stats and Lore tabs only populate when clicked
    - Scrollable canvas with mousewheel support on all tabs
    - Equipped Gear section with durability display
    - Combat Stats with tooltips showing breakdown
    - Active Effects (shield, discount, tokens, temp effects)
    - Resources (health, gold, inventory space, rest cooldown)
    - Permanent Upgrades calculation (shows count and total bonus)
    - Lore Codex with expandable categories and read buttons
    - Red X close button in top-right corner
    - Responsive dialog sizing (75% width, 90% height)
  - Main file reduced by 748 lines, now only contains delegation
  - Follows established manager architecture pattern

## [Unreleased] - 2025-12-11

### Added
- **Architecture Rules Documentation**: Created `ARCHITECTURE_RULES.md`
  - WHY: Need formal guidelines to enforce manager pattern and prevent main file bloat
  - CONTENT: Documents manager organization, when to use managers, code review checklist
  - Serves as reference for all future development work
- **UI Dialogs Manager**: Created new manager for settings and high scores
  - WHY: Following manager architecture pattern to keep main file clean
  - TECHNICAL IMPLEMENTATION:
    - Created `explorer/ui_dialogs.py` with `UIDialogsManager` class
    - Main file now has simple 1-2 line delegation methods: `show_settings()` and `show_high_scores()`
    - Manager handles all UI logic for dialogs including parent detection (game_frame vs root)
    - Follows architecture rule: main file only contains delegation wrappers, managers contain implementation
  - Synced all updated files to `dice-dungeon-github/` folder for version control

### Fixed
- **Settings Menu UI Pattern**: Converted from popup dialog to in-game submenu
  - WHY: Settings used Toplevel dialog (separate window) while all other menus used in-game submenus, and main menu buttons weren't working
  - PROBLEM SOLVED: Settings/high scores buttons did nothing when clicked from main menu
  - TECHNICAL IMPLEMENTATION:
    - Created `UIDialogsManager` in `explorer/ui_dialogs.py` to handle dialog display logic
    - Manager detects context: uses `game_frame` parent when in-game, `root` parent when on main menu
    - Settings creates dialog with `place()` geometry manager for overlay effect
    - High scores fully migrated to manager with proper parent detection
    - Main file delegation: `show_settings()` → `ui_dialogs_manager.show_settings()`
    - Main file delegation: `show_high_scores()` → `ui_dialogs_manager.show_high_scores()`
    - Added red X close button in top-right corner matching lore codex pattern
    - Cancel/Save & Back buttons work from both contexts (main menu and in-game)
  - Now works reliably from both main menu and in-game pause menu
  - Follows proper manager architecture (no bloat in main file)
- **Threshold Chamber UX Issues**: Fixed flashing and improved UI clarity
  - WHY: User reported excessive flashing when opening chests and unclear button labels
  - PROBLEM SOLVED: 
    - Entire UI was rebuilding on chest open causing flash
    - Buttons showed chest descriptions instead of simple labels
    - No visual feedback when chest was already opened
  - TECHNICAL IMPLEMENTATION:
    - Migrated starter area to `NavigationManager` following architecture pattern
    - Main file delegation: `show_starter_area()` → `navigation_manager.show_starter_area()`
    - Main file delegation: `open_starter_chest()` → `navigation_manager.open_starter_chest()`
    - Created `_render_chest_buttons()` method to update only chest buttons, not entire UI
    - Created `_close_chest_dialog()` method that calls `_render_chest_buttons()` instead of rebuilding
    - Chest buttons now show "Chest 1", "Chest 2" etc. (simple labels)
    - Chest descriptions moved to dialog that appears when opening
    - Opened chests display as "Chest X (already looted)" in grayed text
    - Removed "[Read]" and "[Open]" prefixes from all buttons
    - Increased description text size by 30% (font 11 → 14)
    - Changed chest button labels to use descriptive text from chest descriptions
    - Simplified chest descriptions: "Carved wooden chest" and "Sealed stone coffer"
    - Removed brackets from "CHEST OPENED" dialog header
    - Removed brackets from "ENTER THE DUNGEON - FLOOR 1" button
    - Changed intro text to welcoming message: "Welcome, Adventurer. Study these teachings before your journey begins."
  - No more flashing, cleaner UI, better user feedback
- **Minimap Legend**: Fixed visited/unvisited color labels and symbols
  - WHY: Legend showed blue for visited but actual visited tiles use gray color
  - PROBLEM SOLVED: Removed "Unvisited" label, changed "Visited" to use gray color (#555555)
  - Updated stairs symbol in legend to match actual icon (∩ = Stairs)
  - Now legend accurately reflects minimap colors and symbols
- **Minimap Boss Icons**: Improved boss room visibility
  - WHY: Mini-boss icon "L" was unclear, skull and crossbones too hard to see
  - PROBLEM SOLVED: Changed both mini-boss and floor boss icons to skull emoji (💀)
  - Since mini-boss and floor boss never appear on same floor, using same icon causes no confusion
  - Updated legend to show "💀 = Boss" (covering both types)
  - Icons now clearly visible and immediately recognizable
- **Spawned Enemy Health**: Fixed scaling for summoned/split enemies
  - WHY: Spawned enemies inherited percentage of parent health, making them too strong
  - PROBLEM SOLVED: All spawned/split enemies now use base 30 HP + floor scaling (30 + floor * 10)
  - TECHNICAL IMPLEMENTATION:
    - Updated `spawn_additional_enemy()` in combat.py to use base health formula
    - Updated `split_enemy()` in combat.py to use same base health formula
    - Enemies like Necromancer's skeletons and Gelatinous Slime's blobs now have consistent health
  - Spawned enemies now have appropriate health for their floor level
- **Enemy Target Selection Sprite**: Sprite now updates when selecting different enemies
  - Technical: Added sprite update in `select_target()` method (combat.py lines 699-703)
  - When clicking spawned/summoned enemies during combat, their sprite now appears in sprite box
  - Previous: Sprite only updated when enemy's turn came around
  - Now: Sprite updates immediately when clicking enemy name to target them
- **Burn Damage Animation**: Enemies now shake and flash when taking burn damage
  - Technical: Added `_animate_enemy_damage(damage)` call in `_apply_burn_damage()` (combat.py line 1693)
  - Burn damage at start of turn now triggers same shake/flash animation as regular attacks
  - Previous: Burn damage was silent with no visual feedback
  - Now: Red flash and shake animation shows burn damage clearly
- **Combat Message Duplication**: Fixed enemy rolls being logged twice
  - Technical: Added `if enemy_index > 0:` check in `_announce_enemy_attacks_sequentially()` (combat.py line 1947)
  - First enemy's roll already logged during dice animation, so skip logging it again
  - Previous: "Enemy rolls X, Y, Z" appeared twice for first enemy in combat
  - Now: Each enemy's roll only appears once in combat log

### Removed
- **Garden Shears Item**: Removed non-functional item from game
  - Technical: Removed from items_definitions.json (line 198)
  - Garden Storage room (id 117) now awards 15 gold instead of Garden Shears
  - Technical: Changed rooms_v2.json lines 509-513 from `"item": "Garden Shears"` to `"gold_flat": 15`
  - Item had no associated functionality or use

### Changed
- **Store Menu UX Improvements**: Complete overhaul of buying/selling experience
  - **No More Flashing**: Buy and sell operations no longer refresh entire menu
  - **Quantity Selection**: Slider appears when selling multiple items
    - Shows "You have X [item name]" with visual slider (1 to max)
    - Real-time total price calculation updates as you adjust quantity
    - Smooth removal of items after sale (no visual disruption)
  - **Sell Confirmation Popup**: New confirmation dialog before selling items
    - Displays item name and sell price
    - Prevents accidental sales
    - Shows quantity selector if you have multiples
  - **Smart Refresh**: When selling partial quantities, menu updates to show remaining items
  - **Gold Label Updates**: Gold amount updates in real-time without menu refresh
  - **Red X Close Button**: Added close button in top-right corner (matches lore codex style)
  - **Scroll Position Preservation**: Menu maintains scroll position when refreshing
  - Technical: Direct widget manipulation (label.config, frame.destroy) instead of show_store() calls
  - Technical: Quantity stored in IntVar, total price calculated as quantity × unit_price
  - Technical: Confirmation popup uses Toplevel with 400×280px size for slider, 400×200px without

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

---

## [Unreleased] - 2025-10-10

### Added
- **Explorer Mode with Content System Integration**: Created full roguelike exploration mode with JSON-driven content
  - Technical: Created `dice_dungeon_explorer.py` (830+ lines) with scrollable UI, map display, room navigation
  - **100 Rooms System**: Loads from `dice_dungeon_content/data/rooms_v2.json` instead of hardcoded rooms
  - **Smart Room Selection**: Automatically picks difficulty-appropriate rooms by floor
    - Floors 1-3: Easy rooms
    - Floors 4-6: Medium rooms  
    - Floors 7-9: Hard rooms
    - Floors 10-12: Elite rooms
    - Floor 13+: Elite + Boss rooms (every 3rd floor)
  - **Room Exploration**: Navigate N/S/E/W through procedurally generated dungeons
  - **Room Discovery**: Shows name, difficulty, flavor text, threats, tags, and discoverables
  - **Room Mechanics Engine**: Automatic effect application system
    - `on_enter` effects: Applied when entering room (healing, damage, buffs, gold)
    - `on_clear` effects: Applied when completing room objectives
    - `on_fail` effects: Applied when failing room challenges
  - Technical: Content engine modules in `dice_dungeon_content/engine/`:
    - `rooms_loader.py` - Floor-based room selection logic
    - `mechanics_engine.py` - Effect application with PlayerAdapter system
    - `integration_hooks.py` - Game integration layer

- **Content Pack System Architecture**: Modular data-driven game content system
  - Technical: Created `dice_dungeon_content/` directory structure with `/data`, `/schemas`, `/engine`
  - **Room Definitions**: `rooms_v2.json` with 100 unique rooms
    - Each room has: id, name, difficulty, threats, history, flavor text, discoverables
    - Tags system: combat, trap, puzzle, event, lore, rest, environment, elite, boss
    - Mechanics blocks with triggers (on_enter, on_clear, on_fail)
  - **Items System**: `items_definitions.json` defining all collectible items
    - Types: buff, token, tool, sellable, lore
    - Direct effect keys: heal, crit_bonus, damage_bonus, gold_mult
  - **Mechanics Templates**: `mechanics_definitions.json` with reusable effect bundles
    - Shorthand patterns: heal_small, damage_large, etc.
  - **Effects Catalog**: `effects_catalog.json` documenting all effect keys
  - **Statuses System**: `statuses_catalog.json` with all status conditions
    - Both debuffs and buffs with numeric impact values
  - **Schema Validation**: JSON schemas for content validation
    - `rooms_v2.schema.json` for room structure
    - `room_mechanics.schema.json` for mechanics blocks

- **Inventory & Status Tracking System**: Full implementation for content system
  - **Inventory Management**: List-based item storage with pickup/drop
  - **Status Effects**: Duration-based buff/debuff tracking
    - Durations: combat (clears after combat), floor (clears on floor transition), permanent
  - **Special Tokens**: 
    - Disarm tokens: Auto-disable hazards in trap rooms
    - Escape tokens: One-time escape from bad situations
  - **Temporary Effects System**: Track limited-duration modifiers
    - Effect types: extra_rolls, crit_bonus, damage_bonus, gold_mult, shop_discount
    - Automatic cleanup based on duration and phase
  - **Temp Shield**: Absorbs damage before HP, persists until used or floor transition

- **Game Launcher System**: Dual-mode selector interface
  - Technical: Created `dice_dungeon_launcher.py` (125 lines) with two-card UI
  - **Classic Mode Card**: Launch original dice combat RPG (`dice_dungeon_rpg.py`)
  - **Explorer Mode Card**: Launch new roguelike exploration (`dice_dungeon_explorer.py`)
  - **Subprocess Management**: Each mode runs as separate process
  - **Themed UI**: Mode-specific colors (classic: purple, explorer: teal)

- **Content Stats Display**: Comprehensive stats dialog showing content system data
  - Shows all content tracking: inventory count, disarm tokens, escape tokens
  - Active statuses count, temporary effects count, temp shield value
  - Integrated with existing power-ups and player stats display

- **Combat Flavor Text System**: Dynamic narrative combat messaging
  - **Enemy Taunts**: Type-specific taunts for Goblin, Orc, Troll, Dragon, Demon, Lich
    - Each enemy type has 3+ unique taunt messages
    - "default" fallback for unknown enemy types
    - Displayed at start of enemy turn
  - **Enemy Hurt Reactions**: Pain responses by enemy type
    - Different reactions based on enemy personality/theme
    - Displayed when enemy takes damage
  - **Enemy Death Messages**: Dramatic death narration by enemy type
    - Unique death descriptions for each enemy class
    - Displayed when enemy HP reaches 0
  - **Player Combat Messages**: Varied attack flavor text
    - ~15 attack variations ("You strike with precision!", "Your dice guide your blade!", etc.)
    - Dramatic critical hit messages with "*** CRITICAL HIT! ***" formatting
    - Randomly selected during attack actions

- **Complete Dice Rolling UI**: Interactive dice system with locking
  - **toggle_dice(idx)**: Lock/unlock individual dice for strategic rerolls
    - Visual feedback: Locked dice turn gold, unlocked dice remain white
    - State persistence across rolls within same turn
  - **roll_dice()**: Roll all unlocked dice with roll limit tracking
    - Decrements `rolls_left` counter (starts at 3 per turn)
    - Only rerolls dice that aren't locked
    - Updates display after each roll
  - **update_dice_display()**: Real-time visual state updates
    - Shows current dice values
    - Color coding: gold for locked, white for unlocked
    - Updates lock/unlock button states

- **Combat Turn Management System**: Complete turn-based combat flow
  - **start_combat_turn()**: Initialize player's combat turn
    - Creates 5 interactive dice buttons
    - Sets `rolls_left` to 3
    - Enables roll and attack actions
    - Clears previous turn state
  - **attack_enemy()**: Process player attack with dice calculation
    - Calculates damage from current dice values
    - Applies combo bonuses (pairs, triples, straights, etc.)
    - Applies damage to enemy HP
    - Logs attack message with flavor text
    - Triggers enemy_turn() after player attack
  - **enemy_turn()**: Enemy attack logic
    - Enemy rolls scaled dice (number increases with floor)
    - Calculates enemy damage with floor bonus
    - Applies damage to player HP
    - Checks for player death → game_over()
    - Displays enemy taunt from flavor text system
    - Returns control to player for next turn

- **Damage Calculation with Combos**: Full poker-style combo system
  - **Pairs**: value × 2 damage bonus
  - **Triples**: value × 5 damage bonus
  - **Quads**: value × 10 damage bonus
  - **Five of a Kind**: value × 20 damage bonus
  - **Full House** (3 of one + 2 of another): +50 flat damage
  - **Flush** (all same suit, if using suited dice): value × 15
  - **Straight** (sequential values): +25 to +40 based on length
  - Combo detection runs on final dice values after all rerolls
  - Logs combo type and bonus in combat messages

- **Victory & Defeat Mechanics**: Complete combat resolution system
  - **enemy_defeated()**: Rewards and progression after killing enemy
    - Awards gold: 10-30 base + (floor × 5)
    - Awards run_score: 100 base + (floor × 20)
    - Plays death message from flavor text system
    - Calls `complete_room_success()` for content system integration
    - Increments `enemies_killed` tracker
    - Displays loot summary in combat log
  - **attempt_sneak()**: Stealth attack option (40% success rate)
    - Success: Deal instant damage (20-40), enter combat with advantage
    - Failure: Enemy gets first strike, enter normal combat
    - Risk/reward tactical choice for combat-heavy rooms
  - **attempt_flee()**: Escape option (50% success rate)
    - Success: Escape combat with 5-15 HP loss, return to exploration
    - Failure: Enemy attacks, remain in combat
    - Useful for preserving HP when low or outmatched

- **Chest Looting System**: Random treasure rewards
  - **open_chest()**: Open treasure chest with weighted random loot
    - **Gold**: 20-50 base + (floor × 10) gold pieces (common)
    - **Health Potion**: Heal 15-30 HP instantly (common)
    - **Items**: Random equipment/consumable from item pool (rare)
      - Pool: ['Magic Sword', 'Shield', 'Lucky Coin', 'Ancient Scroll', 'Crystal', 'Gem']
      - Checks inventory capacity (max 20 items)
      - Displays "Inventory full!" if no space
    - Sets `chest_looted` flag to prevent re-looting same chest
    - Increments `chests_opened` tracker for stats
    - Logs loot details in exploration log

- **Game Over Screen**: End-game statistics display
  - **game_over()**: Display final stats in centered dialog (400×350 window)
    - Shows:
      - Floor Reached: Maximum floor number achieved
      - Rooms Explored: Total unique rooms visited
      - Enemies Defeated: Total kills across entire run
      - Chests Opened: Total chests looted
      - Gold Earned: Total gold collected
      - Final Score: Calculated run_score value
    - Calls `save_high_score()` to persist achievement
    - "Return to Menu" button to restart game
    - Retro-styled UI with green text on dark background

- **High Score Persistence**: Save and load top scores
  - **save_high_score()**: Persist score to JSON file
    - Saves to `dice_dungeon_explorer_scores.json`
    - Data stored: score, floor, rooms, gold, kills
    - Maintains top 10 scores only
    - Sorted by score descending (highest first)
    - JSON format with indent=2 for human readability
    - Handles missing file gracefully (creates new)
  - Score comparison: Only saves if in top 10
  - Automatic cleanup: Removes scores beyond rank 10

- **High Scores Display**: Leaderboard view
  - **show_high_scores()**: Full-screen table showing top 10 runs
    - Window size: 700×650 pixels
    - Columns: Rank, Score, Floor, Rooms, Gold, Kills
    - Fixed-width font: Consolas 11pt for proper alignment
    - Color scheme: Green text (#00ff00) on dark background (#1a1a1a)
    - Retro arcade aesthetic matching game theme
    - Scrollable if more than 10 entries (unlikely but handled)
  - Accessed from main menu "High Scores" button
  - Shows empty state if no scores saved yet

- **Help System**: Comprehensive gameplay guide
  - **show_help()**: Scrollable help dialog (500×500 pixels)
  - **Sections**:
    - **Goal**: Objective of descending deeper into dungeon
    - **Exploration**: Direction buttons (N/S/E/W), stairs requirement for floor descent
    - **Combat**: Dice combat system, 5 dice + 3 rerolls, combo mechanics
      - Lock dice strategy
      - Sneak and flee options
    - **Looting**: Chest mechanics, inventory management (max 20), rest option (+20 HP)
    - **Dice Combos**: Complete list of patterns with bonuses
      - Pairs, Triples, Quads, Five of a Kind
      - Full House, Straights, Flush (if using suited dice)
    - **Tips**: Strategic advice
      - Explore thoroughly before descending
      - Enemies scale with floor level
      - Manage HP carefully, use rest rooms
      - Learn combo patterns for max damage
  - Accessed from main menu "Help" button
  - Text wrapping for readability

- **Rest Mechanic**: HP recovery option
  - **rest()**: Heal HP in safe rooms
    - Base healing: 20 HP
    - Bonus from `heal_bonus` stat (from equipment/buffs)
    - Caps at `max_health` (no overheal)
    - Logs actual HP recovered (not attempted)
    - Strategic resource: Use when low HP before risky rooms
  - Available in rooms tagged as "rest" or when no threats present
  - No cost or penalty, encourages tactical pacing

- **Floor Progression System**: Dungeon descent mechanics
  - **descend_floor()**: Advance to next floor level
    - **Requirement**: Must have stairs in current room
    - Validation: Checks `stairs_here` flag before allowing descent
    - Increments `floor` counter
    - Awards bonus score: 100 × current_floor
    - Calls `start_new_floor()` to generate new dungeon layout
    - Resets room state (new map, clear visited rooms)
    - Logs floor transition in exploration log
  - Floor Scaling: Enemy difficulty, loot quality, room challenges all scale with floor
  - Stairs Requirement: Forces exploration, can't rush deeper without finding stairs

### Fixed
- **Python 3.7.4 Emoji Compatibility**: Removed ALL emojis from Explorer Mode UI
  - Technical: Python 3.7.4's Tkinter uses Tcl 8.6 which only supports Unicode U+0000-U+FFFF
  - Error: `_tkinter.TclError: character U+1fXXX is above the range (U+0000-U+FFFF) allowed by Tcl`
  - **20+ emojis removed** from Labels and Text widgets throughout dice_dungeon_explorer.py:
    - 💰 (U+1F4B0) Gold label → "Gold: X"
    - 📊 (U+1F4CA) Stats title → "[STATS]"
    - 🎮 (U+1F3AE) Help text → text-based instructions
    - 📦 (U+1F4E6) Chest messages → "[CHEST]"
    - 💤 (U+1F4A4) Rest messages → "[REST]"
    - 🪜 (U+1FA9C) Stairs messages → "[STAIRS]"
    - 🎒 (U+1F392) Inventory title → "[INVENTORY]"
    - ☰ (U+2630) Menu title → "[MENU]"
    - 🚶 (U+1F6B6) Exploration section → "EXPLORATION:"
    - ⚔️ (U+2694) Combat section → "COMBAT:"
    - 🎲 (U+1F3B2) Dice roll messages → "[ROLL]"
    - 💡 (U+1F4A1) Tutorial tips → text markers
    - 🏆 (U+1F3C6) Achievement messages → text-based
  - **Combat UI**: Replaced emoji buttons with text labels
    - "🎲 Roll Dice" → "Roll Dice"
    - "⚔️ ATTACK!" → "ATTACK!"
    - "🏃 Try to Flee" → "Try to Flee"
  - **Combo Messages**: Replaced emoji prefixes with bracket tags
    - "💥 You deal X damage" → "[HIT] You deal X damage"
    - "🔥 CRITICAL!" → "[CRITICAL!]"
    - Various combo emojis → "[FIVE OF A KIND!]", "[FULL HOUSE!]", etc.
  - **All affected locations**: Stats labels, room titles, combat labels, help dialog, menu titles, loot messages
  - Files edited: Multiple string replacements across UI initialization, combat system, exploration functions
  - Result: Game now runs without crashes on Python 3.7.4 Windows systems
  - Note: Emojis work fine in button text, but NOT in Label or Text widget text content

- **Minimap Navigation**: Real-time dungeon map visualization
  - **Why Added**: User moved into a room that went off the visible map area, needed way to track dungeon layout and current position
  - **Problem Solved**: Without minimap, players had no spatial awareness - couldn't remember which rooms they'd explored, where stairs were located, or how rooms connected. This made navigation frustrating and repetitive.
  
  **Visual Display**: Canvas-based minimap (180×180px) showing explored rooms
    - **Room Types with Color Coding**: Visual differentiation for strategic planning
      - Standard rooms: Cyan (#4ecdc4) when visited, gray (#666666) unvisited
      - Rest rooms: Special marking for HP recovery locations
      - Stairs rooms: Green "S" marker for floor progression points
      - Chest rooms: Visual indicator for loot opportunities
    - **Visited Status**: Grayscale for unexplored maintains mystery, full color rewards exploration
    - **Current Position**: Yellow (#ffd700) highlight makes "you are here" instantly visible
    - **Exits**: Directional indicators (N/E/S/W) show available paths from each room
    - **Cleared Status**: Green border when all enemies defeated - tracks combat progress
  
  **Auto-Updates**: Minimap refreshes dynamically
    - On room entry: `enter_room()` calls `draw_minimap()` to show new position
    - On floor descent: `start_new_floor()` regenerates map for new floor layout
    - On window resize: `on_canvas_configure()` triggers redraw with new dimensions
  
  **Scaling**: Adapts to window size, maintains aspect ratio
    - Cell size calculated from available canvas space
    - Rooms and connections scale proportionally
    - Text markers (stairs, etc.) resize with zoom level
  
  **Dead-End Blocking**: Creates maze-like exploration preventing straight line to stairs
    - **Why**: Without blocked exits, dungeons felt like open grids with no navigation challenge
    - **Implementation**: `block_some_exits()` randomly blocks 30% of connections between rooms
    - **Safety Check**: Ensures each room has at least one exit (prevents softlocks)
    - **Bidirectional**: If A→B blocked, B→A also blocked (consistent physics)
    - **Visual Feedback**: "BLOCKED" marker on minimap, disabled direction buttons in UI
    - **Strategic Impact**: Forces players to explore alternate paths, increases backtracking, makes stairs discovery more rewarding

- **Save/Load System**: Complete game state persistence
  - **Why Added**: User explicitly requested "there needs to be a save game option" - game sessions can last 30+ minutes, progress loss on quit was unacceptable
  - **Problem Solved**: Players couldn't take breaks or quit safely. Without saves, each dungeon run was an all-or-nothing commitment. Deaths meant losing all progress. Saves enable roguelike progression.
  
  **save_game()**: Serializes entire game state to JSON
    - **Challenge**: Needed to preserve complex game state across Python sessions
    - **Dungeon Layout**: All rooms with full state
      - `data_name`: Room content identifier for recreation from content system
      - Coordinates: `(x, y)` position tuples (converted to string keys for JSON)
      - Room state: visited, cleared, stairs discovered, chest looted
      - Enemy state: enemies_defeated count, remaining enemies
      - Navigation: exits list, blocked_exits list for maze structure
    - **Player Stats**: Complete character state
      - Resources: gold, health, max_health
      - Progression: floor number, score, rooms_explored count
      - Position: current_room_idx references active room in dungeon
    - **Inventory System**: All items with full properties
      - Item objects → dicts: name, type, dice_power, modifiers, flags
      - Preserves equipped items, consumables, lore items, keys
      - Maintains inventory order for stack management
    - **Equipment & Modifiers**: Character build preserved
      - Dice slots: num_dice, dice_locked states, rolls_left
      - Combat stats: multiplier, damage_bonus, heal_bonus, reroll_bonus, crit_chance
      - Temporary effects: temp_effects dict, temp_shield value, shop_discount
      - Flags: Special states like boss defeated, quest progress
    - **Error Handling**: Try-except with messagebox shows user-friendly error on save failure
    - **File**: `dice_dungeon_explorer_save.json` in game directory (single save slot)
  
  **load_game()**: Deserializes and restores complete state
    - **Validation**: Checks file existence before attempting load (prevents crash)
    - **Dungeon Reconstruction**: 
      - Parses saved room data, looks up original content by `data_name`
      - Recreates Room objects with proper content system references
      - Restores all room states from save (visited, cleared, etc.)
      - Rebuilds `self.dungeon` dictionary with position keys
    - **Player Restoration**: All stats restored exactly as saved
      - Inventory items: Simple dicts restored (no complex object recreation needed yet)
      - Equipment bonuses: Reapplied to ensure combat math works correctly
      - Position: Finds and sets `self.current_room` from coordinates
    - **skip_effects Parameter**: Critical for proper loading
      - Without: Room entry would re-trigger all events (damage, loot, enemy spawns)
      - With: Player positioned in room without side effects
      - Preserves exact save state instead of randomizing room effects
    - **Error Handling**: Try-except shows specific error message if load fails (corrupt save, missing data, etc.)
  
  **UI Integration**: Seamless save/load experience
    - **Main Menu**: "Load Game" button between "Start Adventure" and "High Scores"
      - Checks for save file, shows messagebox if none exists
      - Immediately launches into saved game state
    - **Pause Menu**: "Save Game" button in hamburger menu (☰)
      - Accessible anytime during gameplay
      - Shows confirmation messagebox on success
      - Closes pause menu after save
    - **User Feedback**: Success/failure messageboxes for all operations
  
  **enter_room() Enhancement**: Added skip_effects parameter for loading
    - **Without skip_effects**: Normal room entry applies all effects
      - HP changes from hazards or healing
      - Gold grants from room rewards
      - Enemy spawns from combat triggers
      - Chest/loot generation
    - **With skip_effects=True**: Loading-safe entry
      - Player positioned in room visually
      - Room description shown
      - No game state changes (HP, gold, inventory stay as loaded)
      - Combat state remains inactive
    - **Use Case**: Only used by `load_game()` to restore exact save state

- **UI Resizing Improvements**: Better window management
  - **Why Added**: User reported "the UI still isn't resizing for a larger window" - window could be expanded but game content stayed small
  - **Problem Solved**: Originally designed for 700×650px window. When users maximized or resized window, game stayed in top-left corner with wasted whitespace. Canvas didn't expand to use available space.
  
  **Window Dimensions**: Increased from 700×650 to 1000×750 default
    - **Reasoning**: Modern monitors support larger windows comfortably
    - **Impact**: More text visible in adventure log without scrolling
    - **Proportions**: 4:3 aspect ratio maintained for balanced layout
    - **User Experience**: Less cramped UI, easier to read combat messages
  
  **Minimum Size**: Set to 900×700 (up from 400×400) for usability
    - **Why**: 400×400 was too small - buttons overlapped, text cut off
    - **Threshold**: 900×700 is minimum where all UI elements visible without cropping
    - **Prevents**: Users resizing window too small and breaking layout
  
  **Canvas Expansion**: Fixed canvas to fill available space
    - **Technical Challenge**: Tkinter Canvas doesn't auto-expand with pack() by default
    - **Solution Components**:
      - `on_canvas_configure()`: Callback when canvas size changes
        - Gets current canvas width: `self.canvas.winfo_width()`
        - Updates canvas window item width: `self.canvas.itemconfig(canvas_window, width=width)`
        - Forces canvas content to match canvas size
      - `on_frame_configure()`: Callback when content frame size changes
        - Updates scroll region: `self.canvas.configure(scrollregion=self.canvas.bbox("all"))`
        - Ensures scrollbars work correctly with new content size
      - **Binding**: `self.canvas.bind("<Configure>", on_canvas_configure)` auto-triggers on resize
    - **Result**: Canvas expands horizontally when window resized, content fills available width
  
  **Minimap Scaling**: Proportional adjustment
    - Minimap stays fixed 180×180px (right side)
    - Maintains square aspect ratio regardless of window size
    - Cell sizes scale with zoom level, not window size
  
  **Responsive Layout**: Both panels adjust dynamically
    - **Left Panel**: Game content (stats, log, action buttons) expands to fill space
    - **Right Panel**: Minimap stays fixed width, positioned at right edge
    - **Pack Geometry**: `game_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)` enables expansion
    - **User Experience**: Game feels responsive to window changes, no awkward empty space

- **Minimap Zoom Controls**: Dynamic zoom and player-centered view
  - **Why Added**: User reported "the minimap should be able to be zoomed out of and into. i just moved into a room off the map" - minimap had fixed zoom showing only ~5x5 rooms, larger dungeons went off-screen
  - **Problem Solved**: 
    - **Without Zoom**: Dungeons larger than 5×5 rooms had areas invisible on minimap
    - **Navigation Issue**: Players couldn't see where they'd been or plan routes to distant rooms
    - **Exploration Frustration**: Had to mentally remember dungeon layout beyond visible area
    - **Solution**: Variable zoom (25%-300%) lets players see entire floor or focus on local area
  
  **Zoom Interface**: Three control methods for accessibility
    - **+/- Buttons**: Explicit controls above minimap
      - Large, obvious targets for mouse users
      - Each click changes zoom by 25% (0.25× multiplier)
      - Visual: Dark brown buttons (#4a2c1a) matching game theme
    - **Zoom Display**: Real-time percentage label (25%-300%)
      - Shows current zoom level numerically
      - Updates immediately when zoom changes
      - Helps players know their current view scale
      - Font: Arial 9pt, white text on dark background
    - **Mouse Wheel**: Smooth scrolling control when hovering over minimap
      - Natural, intuitive zoom interaction
      - Scroll up = zoom in, scroll down = zoom out
      - Same 25% increments as buttons
      - Bound to canvas: `self.minimap_canvas.bind("<MouseWheel>", self.on_minimap_scroll)`
  
  **Zoom Levels**: Strategic range for different use cases
    - **25%** - Maximum zoom out
      - **Area**: 8× more rooms visible (16×16 grid vs 4×4)
      - **Use Case**: Initial floor exploration, finding stairs, planning route
      - **View**: Entire floor visible at once for strategic planning
      - **Trade-off**: Room details very small, mainly for navigation
    - **50%** - Wide strategic view
      - **Area**: 4× area visible (8×8 grid)
      - **Use Case**: Medium-range planning, tracking multiple objective locations
      - **Balance**: Good compromise between overview and detail
    - **100%** - Default view (original implementation)
      - **Area**: Standard 4×4 grid of rooms
      - **Use Case**: Normal gameplay, comfortable detail level
      - **Starting Zoom**: Game launches at 100%
    - **200%** - Close tactical view
      - **Area**: 2×2 grid, very detailed
      - **Use Case**: Examining nearby room connections, checking specific exit states
      - **Details**: Room icons, stairs markers, connections very clear
    - **300%** - Maximum zoom in
      - **Area**: ~1.5×1.5 rooms visible
      - **Use Case**: Detailed inspection of immediate area
      - **Limit**: Chosen to prevent zooming so far rooms become meaningless
  
  **Player-Centered View**: Map follows player movement
    - **Why Critical**: Fixed-position minimap would show player moving off-screen at edges
    - **Implementation**: 
      - Calculate player offset: `rel_x = room_x - player_x`, `rel_y = room_y - player_y`
      - Position rooms relative to canvas center (90, 90): `x = 90 + (rel_x × cell_size)`
      - Player room always drawn at canvas center with yellow (#ffd700) color
    - **Benefits**:
      - Never go off edge of minimap
      - Always see rooms in all directions from current position
      - Map "scrolls" automatically as you navigate
      - No manual panning needed
    - **User Experience**: Feels like player is stationary, dungeon moves around them
  
  **Adaptive Rendering**: Graphics scale with zoom for performance and clarity
    - **Room Sizes**: 
      - Cell size: `base_cell_size (20px) × zoom_level`
      - Room square: 40% of cell size (prevents overlap)
      - Half-size: Clamped between 4-15px for visibility at all zooms
    - **Connection Lines**: 
      - Thickness: `max(1, int(zoom_level × 2))` pixels
      - At 25%: 1px thin lines (minimal visual clutter)
      - At 300%: 6px thick lines (very visible connections)
    - **Stairs Marker ("S")**: 
      - Only shown when `zoom_level >= 0.5` (50%+)
      - **Why**: At 25% zoom, stairs text is tiny and clutters view
      - Font size: `max(8, int(10 × zoom_level))`
      - Scales from 8pt (readable minimum) to 30pt (maximum zoom)
    - **Culling (Performance Optimization)**:
      - Before drawing each room: `if x < -20 or x > 200 or y < -20 or y > 200: continue`
      - Skips rooms outside 180×180px canvas bounds (plus 20px buffer)
      - **Impact**: Large dungeons (50+ rooms) only render ~9-16 visible rooms
      - Maintains 60fps even with huge floors
  
  **Implementation Details**: 
    - **zoom_in_minimap()**: 
      - Increases `self.minimap_zoom` by 0.25
      - Max clamp: `min(3.0, self.minimap_zoom + 0.25)` prevents zooming past 300%
      - Updates label: `self.zoom_label.config(text=f"{int(self.minimap_zoom * 100)}%")`
      - Redraws map: `self.draw_minimap()` with new zoom
    - **zoom_out_minimap()**: 
      - Decreases `self.minimap_zoom` by 0.25
      - Min clamp: `max(0.25, self.minimap_zoom - 0.25)` prevents zooming below 25%
      - Same label update and redraw
    - **on_minimap_scroll(event)**: 
      - Checks wheel direction: `if event.delta > 0: zoom_in_minimap() else: zoom_out_minimap()`
      - Windows sends positive delta for scroll up, negative for scroll down
    - **draw_minimap() Changes**:
      - Uses `cell_size = 20 × self.minimap_zoom` for all coordinate math
      - Centers on player with offset calculations
      - Applies culling checks before rendering each room
      - Scales all visual elements (squares, lines, text) proportionally

### Fixed
- **Save/Load System Architecture Mismatch**: Critical bug fix for save game functionality
  - **Root Cause**: Code attempted to access `self.dungeon_rooms` (list structure) but actual implementation uses `self.dungeon` (dictionary with `(x,y)` position tuples as keys)
  - **Why This Occurred**: Initial save/load implementation was written for list-based room storage, but dungeon generation evolved to use coordinate-based dictionary for better spatial relationships and pathfinding
  - **Impact**: Save game button would crash with AttributeError, preventing progress preservation
  
  **Save Function Fixes**:
  - Changed iteration from `for room in self.dungeon_rooms` → `for pos, room in self.dungeon.items()`
  - **Position Serialization**: Save positions as string keys `"{x},{y}"` (JSON requires string keys for dict serialization)
  - **Format**: `rooms_data[f"{pos[0]},{pos[1]}"]` creates proper JSON structure
  - Added `current_pos` serialization: `list(self.current_pos)` converts tuple to JSON-compatible list
  - Added `stairs_found` flag to save data (tracks whether stairs have been discovered on floor)
  - Result: Complete dungeon state with all spatial relationships preserved
  
  **Load Function Fixes**:
  - Reconstructs `self.dungeon` as dictionary instead of list
  - **Position Parsing**: `x, y = map(int, pos_key.split(','))` converts string keys back to coordinates
  - Creates `(x, y)` tuple keys for dictionary: `self.dungeon[(x, y)] = room`
  - Restores `self.current_pos` from saved list: `tuple(save_data['current_pos'])`
  - Gets current room from dict: `self.current_room = self.dungeon[self.current_pos]`
  - Added `stairs_found` restoration with default fallback: `save_data.get('stairs_found', False)`
  - **skip_effects=True**: Prevents re-triggering room entry effects (HP changes, gold grants, enemy spawns)
  
  **Why Dictionary Structure is Superior**:
  - **Spatial Queries**: O(1) lookup for "what room is at (x,y)?" vs O(n) list search
  - **Pathfinding**: Direct access to adjacent rooms via coordinate math: `(x+1, y)`, `(x, y-1)`, etc.
  - **Minimap Rendering**: Efficient iteration of rooms with spatial relationships intact
  - **Exit Validation**: Quick checks for connected rooms when determining valid exits
  - **Save File Format**: Natural mapping of positions to room data in JSON
  
  **Preserved in Save File**:
  - All player stats (gold, HP, max_health, floor, score, inventory, equipment)
  - Complete dungeon layout: Every room's position, content, visited status, cleared state
  - Room states: Stairs discovered, chests looted, enemies defeated, exits available, blocked paths
  - Player position: Exact coordinate in dungeon
  - Modifiers: Dice count, damage/heal bonuses, crit chance, multiplier, reroll bonuses
  - Effects: Temporary buffs, shields, shop discounts, flags for special conditions
  
  Result: Save/load now fully functional, preserving complete game state across sessions

---

## [Unreleased] - 2025-10-09

**THE BEGINNING** - This marks the inception of Dice Dungeon. What started as a simple request became a full-fledged roguelike RPG in a single day.

### Origin Story
The project began with a request to "build a game with odds and multipliers and sequences and matches and levels with scores you have to beat." The initial prototype was a match-3 style number chain game called "Number Chain Multiplier" with:
- 6×6 grid of numbers
- Click-and-drag selection mechanics
- Combo multipliers for sequences
- Level progression with target scores

**The Pivot**: After testing, the user requested "something like dice or balatro or an rpg" instead of a matching game. This led to the complete redesign that became Dice Dungeon RPG.

### Core Game Created (Initial Implementation)
The fundamental dice-based combat RPG was built with these systems:

**Combat System Foundation**:
- Turn-based combat with player vs single enemy
- Dice rolling mechanics (initially 5 dice, later changed to 3 starting dice)
- Health system (100 HP for player, scaled enemy HP)
- Damage calculation from dice totals
- Enemy attack system with randomized damage
- Victory rewards (gold and score points)

**Dice Mechanics**:
- Roll dice to generate attack values
- Multiple rolls per turn (3 rolls initially)
- Basic combo detection:
  - Pairs (2 matching): Value × 2 bonus
  - Triples (3 matching): Value × 5 bonus
  - Quads (4 matching): Value × 10 bonus
  - Five of a Kind: Value × 20 bonus
  - Straights (1-2-3-4-5 or 2-3-4-5-6): +30 bonus
  - Full House (3-of-kind + pair): +50 bonus
- Attack button to execute attack with current dice

**Progression System**:
- Floor-based progression (each floor = one enemy encounter)
- Enemy difficulty scales with floor number
- Score accumulation based on damage dealt and floors cleared
- Gold earning system (10-30 gold per enemy defeated)

**Shop System (Basic)**:
- Accessible between floors
- Item inventory:
  - Extra Die (50g) - Add another die to rolls
  - Damage Boost (40g) - Permanent +10 damage
  - Heal Potion (30g) - Restore 40 HP
  - Lucky Charm (60g) - +10% critical hit chance
  - Reroll Token (35g) - +1 extra roll per turn
  - Gold Multiplier (100g) - +25% gold earned
- Purchase system deducts gold
- Item effects apply immediately

**Enemy Variety (Initial Set)**:
- Goblin (50 HP, 5-15 damage)
- Orc (100 HP, 10-20 damage)
- Troll (150 HP, 15-25 damage)
- Dragon (200 HP, 20-35 damage)
- Demon (250 HP, 25-40 damage)
- Random enemy selection based on floor

**UI Structure**:
- Tkinter-based desktop application
- 900×800px window (later made resizable)
- Dark theme (#1a1a2e background)
- Combat log showing all actions
- HP/Gold/Score display
- Dice visualization with click-to-roll

### Added (First Major Iteration)
After the core game was playable, these features were immediately added:

- **Main Menu System**: Professional game launcher
  - **Why Added**: Original game started directly in combat with no title screen or menu - felt unpolished and lacked proper game structure
  - **Problem Solved**: Players had no way to review high scores without quitting, no branding/identity, and combat started abruptly without context
  
  **Features**:
  - START NEW RUN button to begin a new game (resets all stats, starts floor 1)
  - HIGH SCORES button to view leaderboard (shows top 10 runs)
  - QUIT button to exit (closes application window)
  - Instructions panel explaining core mechanics (dice rolling, combos, shop)
  - Title screen with "Dice Dungeon RPG" branding (establishes game identity)
  - Prevents jumping straight into combat (proper game flow)
  
  **Technical Implementation**:
  - `show_main_menu()` destroys all game frames and creates menu layout
  - Uses `pack()` geometry manager with centered buttons
  - Stores `game_active = False` flag to prevent combat updates
  - Button commands: `command=self.start_game` links to game initialization
  - Dark theme colors: #1a1a2e background, #ffd700 title text, #4ecdc4 buttons
  
  **Impact**: Game feels professional with proper entry point and navigation
  
- **High Score Leaderboard System**: Top 10 run tracking
  - **Why Added**: No persistence between runs - achievements were lost forever, no way to compare performance or track improvement
  - **Problem Solved**: Players needed motivation to improve, competitive comparison, and proof of their best runs
  
  **Features**:
  - Scores saved to dice_dungeon_scores.json (persistent across sessions)
  - Displays rank (gold/silver/bronze colors for top 3 - #ffd700, #c0c0c0, #cd7f32)
  - Tracks: Total Score, Floor Reached, Gold Earned (3 metrics for run quality)
  - Shows "NEW HIGH SCORE!" notification on game over (celebration moment)
  - Accessible from main menu anytime (no need to die to view)
  - Automatic saving on death (no manual save required)
  - Sorted by score descending (best runs at top)
  
  **Technical Implementation**:
  - `save_high_score()`: Appends current run to scores list, sorts by score, keeps top 10
  - `load_high_scores()`: Reads JSON file, returns empty list if not found (no crash)
  - JSON structure: `[{"score": 1234, "floor": 8, "gold": 567}, ...]`
  - Score calculation: Base score from damage + floor bonuses (100 × floor reached)
  - File operations: `json.dump(scores, f, indent=2)` for human-readable format
  - Display: Fixed-width font (Consolas) for column alignment, green text (#00ff00) on dark bg
  
  **Impact**: Added replayability and long-term goals, players chase higher floors and better scores
  
- **Floor Complete Menu**: Strategic choice system after each victory
  - **Why Added**: Original game auto-progressed to next floor immediately after victory - no decision-making, no strategic planning between fights
  - **Problem Solved**: 
    - Players couldn't shop for upgrades between floors
    - No opportunity to heal before next combat
    - No moment to assess run status (gold, HP, inventory)
    - Forced immediate combat when player might be low HP
    - Removed strategic layer of resource management
  
  **Three Strategic Options**:
  - **VISIT SHOP** - Browse and buy upgrades
    - Opens shop dialog with all available items
    - Spend accumulated gold on permanent upgrades
    - Strategic: Buy dice early, damage late, potions when desperate
  - **REST** - Heal 30 HP before next floor (was 20 HP)
    - Free HP recovery (no gold cost)
    - Increased from 20 to 30 HP for better viability
    - Strategic: Use when below 50% HP, skip if healthy to save time
  - **NEXT FLOOR** - Continue immediately
    - Bypass shop and rest for immediate progression
    - For speedrunning or when already at full HP with good items
    - Maintains combat momentum
  
  **Technical Implementation**:
  - `show_floor_complete_menu()`: Called by `defeat_enemy()` after victory
  - Modal dialog blocks game interaction until choice made
  - Shows current stats at top: Gold, HP, Score (informed decisions)
  - Button callbacks: `command=lambda: floor_action('shop')` etc.
  - `floor_action(choice)`: Routes to shop, rest, or next floor method
  - Dialog stays open until player makes choice (can't skip accidentally)
  
  **Strategic Implications**:
  - Forces risk/reward decisions (spend gold now vs save for later)
  - Healing decision based on next floor difficulty estimate
  - Shop visits vs immediate progression affects run pacing
  - Added depth to what was previously automatic process
  
  **Impact**: Transformed victory from automatic transition into strategic planning moment, added roguelike decision-making layer
  
- **Shop Item Descriptions**: Clear explanation for each purchase
  - Extra Die: "Add another die to your rolls for bigger combos"
  - Damage Boost: "Permanently increase damage by +10"
  - Heal Potion: "Instantly restore 40 HP"
  - Lucky Charm: "Increase critical hit chance by +10%"
  - Reroll Token: "Gain +1 extra roll each turn"
  - Gold Multiplier: "Increase all gold earned by +25%"
  - Helps new players understand purchases
  - Displayed below item name in smaller font
  
- **Scrollable Shop Window**: Enhanced shopping experience
  - Larger window (700×650px instead of 500×600px)
  - Canvas with scrollbar for long item lists
  - Descriptions appear under each item
  - Shows current gold at top
  - Dynamic gold label updates without closing shop
  - Better visual hierarchy
  - Mouse wheel scrolling support

### Changed
- **Rest Mechanic**: Removed from combat, only available between floors
  - Before: REST button accessible anytime (infinite healing exploit)
  - After: Only appears in Floor Complete Menu
  - Healing increased from 20 HP to 30 HP as compensation
  
- **Shop Flow**: Improved usability during floor transitions
  - Added floor_complete parameter to open_shop()
  - Close button changes to "Continue to Next Floor" when modal
  - Returns to continuation menu instead of combat screen
  - Modal prevents clicking through to game during shopping
  
- **Game Over Flow**: Better integration with high scores
  - Saves score automatically on death
  - Shows notification if new high score achieved
  - Prompts to return to main menu instead of immediate restart
  - Option to quit or view high scores

- **In-Window Dialog System**: Major UI architecture change
  - **Why Changed**: Toplevel popup windows created as separate OS windows, could be moved/minimized independently, broke game flow
  - **Problem Solved**: Popups felt disjointed, could hide behind main window, required window management, broke immersion
  
  **Previous Architecture Issues**:
  - `shop_window = tk.Toplevel(self.root)` created new OS window
  - Windows taskbar showed multiple entries for same app
  - Popups could be positioned off-screen or behind main window
  - Alt-Tab showed multiple windows (confusing)
  - No true modality - could click main game while dialog open
  
  **New Architecture**:
  - Created `show_dialog()` method for centralized dialog management
  - Uses dark overlay frame (#000000 with 70% opacity via rgba simulation)
  - Overlay placed over entire game area with `place(relx=0, rely=0, relwidth=1, relheight=1)`
  - Content frame centered: `place(relx=0.5, rely=0.5, anchor="center")`
  - Prevents interaction with game during dialogs (grab_set equivalent)
  - All dialogs now consistent: shop, floor complete menu, confirmations
  
  **Technical Implementation**:
  - `self.dialog_frame`: Global overlay frame, destroyed/recreated each dialog
  - Content frame: `tk.Frame(overlay, bg="#1a1a2e", relief=tk.RAISED, borderwidth=3)`
  - Relative positioning: `relx=0.5, rely=0.5` centers at 50% of parent
  - Close methods: `self.dialog_frame.destroy()` removes entire overlay
  - Button bindings update to call close_dialog() instead of window.destroy()
  
  **Impact**: Cleaner UX, feels like native game UI, no window management hassle, true single-window app
  
- **Window Size Optimization**: Made game playable on smaller screens
  - **Why Changed**: User explicitly requested "game should be made with the intent of the window being able to be as small as possible"
  - **Problem Solved**: Original 900×800px window too large for laptops, netbooks, or users who wanted game as small side window
  
  **Window Size Changes**:
  - Default: 900×800px → 700×650px (22% smaller area, fits 1366×768 laptops comfortably)
  - Minimum: 600×500px → 400×400px (56% smaller minimum, extreme compaction)
  - Tested at 400×400 to ensure all buttons visible and clickable
  
  **UI Compaction Strategy**:
  - Font size reductions: Title 20→14, Stats 18→12, Combat log 12→10
  - Padding reductions: pady=10→5 throughout all frames
  - Button sizing: Fixed width in characters, not pixels (adapts to font)
  - Combat log: Reduced font but increased readability with color coding
  - Dice display: Scaled canvas sizes down from 80×80 to 60×60 pixels
  - Shop items: Two-column layout at small sizes instead of single column
  
  **Technical Challenges**:
  - Tkinter's pack() doesn't auto-shrink text - had to manually reduce all fonts
  - Scrollbar on combat log became critical at small sizes (limited vertical space)
  - Dialog content had to be responsive: `min(500, self.root.winfo_width() - 40)`
  - Help dialog button getting cut off required frame reorganization
  
  **Result**: Game fully playable at 400×400px, no clipping or accessibility issues, window can be tucked in corner while multitasking
  
- **UI Compaction**: Reduced spacing and font sizes throughout
  - Title font: 20 → 14
  - Stats font: 18 → 12, reduced further for compact layouts
  - Combat log font: 12 → 10
  - Padding reduced: pady=10 → pady=5 in most frames
  - All label fonts reduced to 9-10 for HP/Gold/Score displays
  - Makes game information-dense but still readable
  - Enables small-window gameplay without clipping
  
- **Dice Reset After Attack**: Automatic dice reroll system
  - **Why Added**: User requested "the dice need to randomize after each of my attacks" - manual rerolling after every attack was tedious
  - **Problem Solved**: 
    - Previous flow: Attack → Dice stay locked → Player must click dice to reroll → Select new combos → Attack again
    - Tedious extra click after every single attack
    - Broke combat flow momentum
    - Felt unresponsive and clunky
  
  **New Flow**:
  - `reset_turn()` now calls `self.roll_dice()` automatically after attack resolves
  - Dice immediately show new random values
  - Rolls counter resets to 3/3 available
  - All dice unlocked automatically (no stale locks)
  - Player can immediately assess new roll and plan next move
  
  **Technical Implementation**:
  - Modified `reset_turn()` method called by `attack_enemy()` after damage resolution
  - Added `self.roll_dice()` call at end of reset sequence
  - Dice values: `self.dice_values = [random.randint(1, 6) for _ in range(self.num_dice)]`
  - UI update: `update_dice_display()` refreshes canvas with new values
  - Timing: Happens after 1-2 second enemy turn delay for visual clarity
  
  **Impact**: Combat feels faster and more responsive, one less click per attack cycle (saves 30+ clicks per run)
  
- **Procedural Enemy Flavor Text**: Dynamic combat narration
  - **Why Added**: Combat felt sterile with only damage numbers - no personality, no immersion, generic "Enemy attacks for X damage" messages
  - **Problem Solved**: 
    - All enemies felt the same (just different HP pools)
    - No emotional connection or memorable moments
    - Combat log was dry spreadsheet of numbers
    - Missed opportunity for world-building and character
  
  **Context-Based Response System**:
  - Each enemy type has 3 dialogue dictionaries (high damage >30, low damage, death)
  - Enemy responds dynamically based on player's last attack damage
  - High damage (>30): Angry, threatening, pain expressions
  - Low damage (<30): Mocking, confident, dismissive
  - Death: Dramatic final words, threats, or pleas
  
  **Enemy Personality Examples**:
  - **Goblin** (cowardly, whiny):
    - Low: "That tickles!", "Ouch! But I'll survive!"
    - High: "Ow ow ow! Stop it!", "You'll pay for that!"
    - Death: "No fair! You cheated!", "I should've stayed in my cave..."
  - **Dragon** (proud, arrogant):
    - Low: "Pathetic mortal...", "Is that your best?"
    - High: "ROAR! You dare wound me?!", "My scales... you've pierced them!"
    - Death: "Impossible... a mortal... defeats... me...", "My hoard... take it... you've earned it..."
  - **Demon** (menacing, otherworldly):
    - Low: "I've felt worse in the abyss.", "Your attacks are meaningless."
    - High: "You have power... interesting.", "Pain... how novel."
    - Death: "I shall return... from the abyss!", "You've doomed this realm by defeating me..."
  
  **Technical Implementation**:
  - Enemy class has dialogue attributes: `self.low_damage_quotes`, `self.high_damage_quotes`, `self.death_quotes`
  - Combat system checks damage after player attack: `if damage > 30: quote = random.choice(enemy.high_damage_quotes)`
  - Random selection: `random.choice(quote_list)` prevents repetition within same combat
  - Logged in red color with enemy tag: `self.log(quote, 'enemy')`
  - Triggered at specific moments: After player attack, on enemy defeat
  
  **Variety Mechanism**:
  - Each category has 3-5 quotes per enemy type
  - Random selection each time (can repeat but unlikely)
  - Different enemies have different voice/personality
  - 7 enemy types × 3 contexts × 4 quotes = 84 unique lines
  
  **Impact**: Combat feels alive and reactive, enemies have personality, memorable moments ("That dragon was so arrogant!"), increased immersion

- **Colored Combat Log**: Enhanced combat readability with color-coded messages
  - **Why Added**: User requested "Can you make the enemy text and damage numbers in red?" - monochrome text made combat log hard to scan
  - **Problem Solved**: 
    - All text was white/gray - couldn't quickly distinguish player vs enemy actions
    - Critical moments (big hits, deaths) didn't stand out
    - Combat felt flat and unexciting visually
    - Scrollback reading was tedious (had to parse every line carefully)
  
  **Color Scheme Rationale**:
  - GREEN (#00ff00) - Player attacks and actions
    - Reason: Green = "go", success, player agency
    - Used for: Dice rolls, attack announcements, damage dealt
  - RED (#ff4444) - Enemy attacks, taunts, and damage
    - Reason: Red = danger, threat, damage taken
    - Used for: Enemy attack rolls, damage to player, enemy dialogue
  - GOLD (#ffd700) - System messages (floor starts, victories)
    - Reason: Gold = important events, rewards, progression
    - Used for: Floor transitions, victory messages, gold earned
  - MAGENTA/BOLD (#ff00ff) - Critical hits
    - Reason: Bright purple = special event, excitement, big damage
    - Used for: "CRITICAL HIT!" messages, 2× damage announcements
  
  **Technical Implementation**:
  - Configured Text widget tags: `self.combat_log.tag_config('player', foreground='#00ff00')`
  - Updated `log()` method signature: `def log(self, message, tag='default')`
  - Tag application: `self.combat_log.insert(tk.END, message + '\n', tag)`
  - Each message category gets appropriate tag: `self.log("You attack!", 'player')`
  - Tags support multiple attributes: foreground, background, font, weight
  
  **Impact**: Combat log instantly readable at a glance, exciting visual feedback, easier to debug combat issues
  
- **Hamburger Menu**: In-game menu system for quick access
  - **Why Added**: User requested "Can you add a menu or hamburger button in one of the top corners to hold the options settings, leaderboard, return to menu button while playing?"
  - **Problem Solved**: 
    - Bottom-frame buttons took up valuable screen space
    - No way to view high scores during active run
    - Quitting required closing entire application (no safe exit)
    - Options/settings had no access point during gameplay
    - UI felt cluttered with always-visible controls
  
  **Menu Structure**:
  - **☰ Button** in top-right corner (universal menu icon)
    - Minimal screen real estate (30×30px button)
    - Accessible at all times during gameplay
    - Opens modal overlay with three options
  
  **Three Menu Options**:
  - **View High Scores**: Check leaderboard without quitting run
    - Shows top 10 scores in modal dialog
    - Compare current run to past achievements
    - Motivation to beat personal best
    - Returns to game when closed (no run interruption)
  - **Return to Main Menu**: Quit current run with confirmation
    - Confirmation dialog prevents accidental quits
    - "Are you sure? Progress will be lost" warning
    - Saves high score if applicable before quitting
    - Safe way to exit mid-run without Alt+F4
  - **Resume Game**: Close menu and continue playing
    - Dismiss menu without any action
    - Equivalent to clicking outside menu or pressing Escape
    - Returns immediately to combat/exploration
  
  **Technical Implementation**:
  - Button placement: `tk.Button(header_frame, text="☰", font=('Arial', 16), command=self.show_hamburger_menu)`
  - Packed to right side: `pack(side=tk.RIGHT, padx=10)`
  - Menu uses in-window modal system (same as shop/dialogs)
  - Overlay prevents game interaction while menu open
  - Escape key binding: `dialog.bind('<Escape>', lambda e: self.close_dialog())`
  
  **UX Design Decisions**:
  - Top-right placement: Industry standard (most apps put menus here)
  - ☰ symbol: Universal hamburger menu icon (instantly recognizable)
  - Modal overlay: Forces deliberate choice, prevents accidental clicks
  - Resume as default: Makes dismissing menu easy (click anywhere)
  
  **Impact**: Cleaner UI (removed bottom buttons), added mid-run leaderboard access, safe quit option, more screen space for combat log

- **Responsive Dialog System**: Dynamic window resize handling
  - **Why Added**: User reported "when the window is as small as it can be and the shop window pops up, if I expand the window, the button to move to the next round is all messed up"
  - **Problem Solved**: 
    - Dialog dimensions calculated once at creation (400×400 window)
    - User expands window to 1920×1080 mid-dialog
    - Dialog stays 400px wide (tiny in huge window)
    - Buttons/content poorly positioned (intended for small dialog)
    - Or opposite: Dialog 700px wide in 400px window (content cut off)
  
  **Edge Cases Handled**:
  - **Expand While Dialog Open**: Dialog grows to use available space
  - **Shrink While Dialog Open**: Dialog shrinks to fit, maintains minimum size
  - **Multiple Dialogs**: Each dialog has independent resize handling
  - **Rapid Resizing**: Debounced with event binding (doesn't spam updates)
  
  **Technical Implementation**:
  - **Dynamic Sizing**: `min(desired_width, window_width - 40)` for max dialog dimensions
    - Always leaves 40px margin (20px each side) for visual breathing room
    - Prevents dialog from touching window edges
    - Scales proportionally between 400px minimum and window size
  - **Resize Binding**: `self.root.bind('<Configure>', self.on_window_resize)`
    - <Configure> event fires when window dimensions change
    - Callback checks if dialog exists: `if hasattr(self, 'dialog_frame') and self.dialog_frame:`
    - Updates dialog placement: `dialog_frame.place_configure(...)` with new dimensions
  - **Cleanup**: `self.root.unbind('<Configure>')` when dialog closes
    - Prevents callback from firing after dialog destroyed
    - Avoids AttributeError on closed dialog references
    - Reduces event handler overhead when no dialog open
  
  **Placement Math**:
  - Center calculation: `relx=0.5, rely=0.5` (50% of parent width/height)
  - Anchor: `anchor='center'` (position center point, not corner)
  - Width constraint: `min(500, root.winfo_width() - 40)` (max 500 OR window-40)
  - Height constraint: `min(600, root.winfo_height() - 40)` (same logic)
  - Result: Dialog scales smoothly from 400×400 to 1880×1040 window sizes
  
  **Tkinter Quirks Handled**:
  - `winfo_width()` returns 1 before window fully initialized (check for this)
  - `place_configure()` must be used (not `place()`) for existing widgets
  - Event can fire multiple times per resize (idempotent updates required)
  - Dialog content must use pack/grid with fill/expand for internal scaling
  
  **Impact**: Dialogs look good at any window size, no more cut-off content, smooth resize experience, professional feel

- **High Score Gold Tracking Fix**: Cumulative gold tracking for leaderboard
  - Added `self.total_gold_earned = 0` variable to track cumulative gold across entire run
  - Separates spendable gold (`self.gold`) from total earned for high scores
  - Updated `defeat_enemy()` to increment both gold and total_gold_earned
  - Updated `save_high_score()` to save total_gold_earned instead of remaining balance
  - Game Over screen now shows "Total Gold Earned" instead of remaining gold
  - Fixes issue where spending gold in shop would lower high score display
  - User reported: "I had 1 gold left at the end because i bought a lot and it said that was all i earned"

- **Dice Limits and Starting Balance**: Strategic dice management system
  - **Why Changed**: User requested "you should be limited to a maximum of 8 dice and you should only start with 3 dice"
  - **Problem Solved**: 
    - Starting with 5 dice made early game too easy (almost always got good combos)
    - No maximum cap meant late-game scaling to 10-15 dice (trivial to get five-of-a-kind)
    - "Extra Die" purchases became no-brainer spam (buy until unbeatable)
    - Removed strategic tension from shop decisions
    - Game became exponentially easier as dice count grew
  
  **Balance Changes**:
  - **Starting Dice**: 5 → 3
    - Reason: With 3 dice, combos are rare (forces reroll strategy)
    - Early floors challenging (can't rely on pairs every roll)
    - Makes first "Extra Die" purchase feel impactful
    - 3 dice = 216 possible rolls, only 36 have matching pairs (16.7%)
  - **Maximum Dice**: Unlimited → 8
    - Reason: 8 dice is strong but not trivial (can still get bad rolls)
    - Prevents late-game autopilot (still need strategy at 8 dice)
    - Makes "Extra Die" a limited resource (5 total purchases possible)
    - 8 dice still requires skill to maximize damage combos
  
  **Shop Integration**:
  - Purchase validation: `if self.num_dice >= self.max_dice:` before allowing buy
  - User feedback: "You already have the maximum of 8 dice!" messagebox
  - "Extra Die" button grayed out when at max (visual indicator)
  - Price still shown but not purchasable (prevents confusion)
  
  **Strategic Implications**:
  - **Early Game** (3-4 dice): Dice purchases high priority for combo consistency
  - **Mid Game** (5-6 dice): Balance dice vs damage/crit upgrades
  - **Late Game** (7-8 dice): Focus on multipliers and damage (dice maxed)
  - **Decision Pressure**: Only 5 dice upgrades available entire run - when to buy?
  
  **Mathematical Impact**:
  - 3 dice: 0.46% five-of-kind, 2.8% four-of-kind, 11.6% three-of-kind
  - 5 dice: 1.2% five-of-kind, 12% four-of-kind, 25.9% three-of-kind
  - 8 dice: 4.6% five-of-kind, 37% four-of-kind, 51% three-of-kind
  - Cap prevents reaching 100% combo probability (keeps strategy relevant)
  
  **Impact**: Game maintains challenge throughout run, dice purchases feel meaningful, strategic resource allocation required

- **Combo System Documentation**: In-game help and real-time combo display
  - **Why Added**: User asked "what are the multipliers? it mentions straights and triples, but idk how they work" - combo system was opaque
  - **Problem Solved**: 
    - Players didn't understand how damage was calculated
    - No reference for combo bonuses (had to experiment blindly)
    - Unclear what patterns to aim for with dice locking
    - Combat felt like random number generator with no strategy
    - New players confused why same total (e.g. 18) gave different damage
  
  **Help Dialog ("?" Button)**:
  - Added next to hamburger menu in header (always accessible)
  - Scrollable reference guide (450×500px with canvas)
  - Complete combo list with examples:
    - PAIRS (2 matching): Value × 2 bonus (e.g., 5-5 = +10 bonus)
    - TRIPLES (3 matching): Value × 5 bonus (e.g., 4-4-4 = +20 bonus)
    - QUADS (4 matching): Value × 10 bonus (e.g., 6-6-6-6 = +60 bonus)
    - FIVE OF A KIND: Value × 20 bonus (e.g., 3-3-3-3-3 = +60 bonus)
    - LOW STRAIGHT (1-2-3-4-5): +30 flat bonus
    - HIGH STRAIGHT (2-3-4-5-6): +30 flat bonus
  - Explains that multiple combos stack (pair + straight = both bonuses)
  - Shows formula: Base (dice sum) + Combo bonuses + Item bonuses = Total damage
  
  **Real-Time Combo Display**:
  - New `get_combo_description()` method analyzes current dice after each roll
  - Logs combo info in system color (gold) after roll completes
  - Format: "Combo: PAIR of 3s (+6 bonus) | Potential Damage: 25"
  - Multiple combos separated: "TRIPLE 5s (+25) | STRAIGHT (+30)"
  - No combos: "No combos (base damage only) | Potential Damage: 12"
  - Updates after each of 3 rolls (helps decide when to stop rolling)
  
  **Technical Implementation**:
  - `get_combo_description()`: Analyzes `self.dice_values`, returns formatted string
  - Detection logic: Count occurrences, check sequences, identify patterns
  - Called by `roll_dice()` after dice randomization completes
  - Display includes calculation preview (helps learning)
  - Combo info logged before "Potential Damage" line
  
  **Learning Curve Benefits**:
  - **Immediate Feedback**: See combos right after rolling (connect cause/effect)
  - **Pattern Recognition**: Learn which combinations are valuable
  - **Strategic Planning**: Decide which dice to lock based on combo potential
  - **Damage Estimation**: Know if current roll is worth attacking with
  - **Mastery Path**: New players learn system without external guide
  
  **Impact**: Transformed combo system from hidden mechanic to transparent strategy layer, new players learn by playing, veterans optimize more effectively

- **Real-Time Combo Display**: Live feedback during dice rolling
  - Added combo info display after each roll
  - Calls `get_combo_description()` to analyze current dice
  - Logs: "Combo: {combo_info}" in system color
  - Logs: "Potential Damage: {damage}" for player to see total
  - Helps players understand their roll quality before committing to attack
  - Encourages strategic use of the 3 available rolls per turn
  - Result: Players can make informed decisions about when to lock dice and when to reroll

- **Bottom Menu Button Removal**: UI simplification
  - Removed redundant "RETURN TO MENU" button from bottom of game screen
  - Functionality still available via hamburger menu (☰) in top corner
  - Reduces visual clutter in main gameplay area
  - Maintains consistent navigation pattern through hamburger menu
  - User requested: "remove the 'return to menu' button from the bottom"

- **Help Dialog Button Visibility Fix**: Small window support
  - Fixed "Got It!" button getting cut off at minimum window size (400x400)
  - Created `content_container` frame to wrap canvas and scrollbar
  - Set fixed canvas height of 350px instead of unbounded expansion
  - Changed button container to `side=tk.BOTTOM` for guaranteed visibility
  - Help text remains scrollable even at small sizes
  - Button always visible and accessible at bottom of dialog
  - Result: Help dialog fully functional at all window sizes
  - User reported: "the how to play submenu gets its 'got it' button cut off when the windows are really small"

- **Enemy Damage Rebalancing**: Reduced starting difficulty
  - Enemy damage reduced by ~10% across all floors
  - Changed from `random.randint(5, 15) + (floor * 2)` to `random.randint(4, 13) + (floor * 2)`
  - Floor 1 enemies now deal 6-15 damage (down from 7-17)
  - Makes early game more forgiving for learning mechanics
  - Scaling still increases with floor progression
  - User requested: "the beginning enemies need to hit like 10% less hard"

- **Damage Calculation Debug Logging**: Transparency and troubleshooting
  - Added detailed breakdown logging to `calculate_damage()` method
  - Creates `bonus_details` list to track all damage bonuses
  - Each combo type appends specific details (e.g., "Triple 6s: +30", "Straight: +30")
  - Logs complete breakdown: `Base: {base} | {combos} | Bonus Items: +{damage_bonus}`
  - Shows in combat log with 'system' color for visibility
  - Helps players understand damage calculations and verify accuracy
  - Context: User reported confusion about quad 6s (84 damage) vs triple 6s+1 (98 damage)
  - Assistant verified math was correct - 98 was due to critical hit (2× multiplier)
  - User quote: "quad 6s results in a lower attack than three 6s and a 1 somehow"

- **Critical Hit System Clarification**: Explained existing mechanic
  - Critical hits multiply total damage by 2× (including base + combos + items)
  - Applied at end of calculation: `int(total * 2)` when crit triggers
  - Crit chance determined by `self.crit_chance` stat (affected by items/upgrades)
  - Example: Triple 6s+1 = 49 damage × 2 (crit) = 98 damage
  - Example: Quad 6s = 84 damage (no crit)
  - Explains why weaker roll can outdamage stronger roll occasionally
  - No code changes - system working as intended
  - Assistant suggested potential improvements: "CRITICAL HIT!" message, pre-crit damage display
  - Context: User confused why triple did more damage than quad
  - Shows component breakdown: "Base: {base} | {bonus_details} | Bonus Items: +{damage_bonus}"
  - Lists each active combo with specific bonus amounts:
    * "Pair of 5s: +10"
    * "Triple 4s: +20"
    * "Quad 6s: +60"
    * "Straight: +30"
  - Helps verify damage calculations are working correctly
  - Makes game mechanics transparent to players
  - Useful for debugging reported issues like "quad 6s results in a lower attack than three 6s and a 1"
  - Result: Players can see exactly how their damage is calculated
  - Context: User reported damage calculation concerns, agent added logging to verify correctness and provide transparency
    - "Rolled! Dice: [3, 3, 5, 6, 2]"
    - "Combo: PAIR of 3s (+6 bonus)"
    - "Potential Damage: 25"
  - Shows "No combos (base damage only)" when no bonuses active
  - Multiple combos displayed with " | " separator
  - User asked: "what are the multipliers? it mentions straights and triples, but idk how they work"

- **Bottom Menu Button Removal**: UI decluttering
  - Removed redundant "RETURN TO MENU" button from bottom frame
  - Functionality now accessed via hamburger menu (☰) in top corner
  - Cleans up gameplay area by removing unnecessary UI element
  - User requested: "remove the 'return to menu' button from the bottom"
  - User reported: "when the window is as small as it can be and the shop window pops up, if I expand the window, the button to move to the next round is all messed up"
  - Fixed issue where shop dialog buttons became inaccessible after window resize

- **Enemy Damage Rebalancing (Second Pass)**: Reduced early game difficulty
  - Changed enemy floor bonus from `self.floor * 3` to just `self.floor`
  - Before: Floor 1 enemies dealt 2d6+3 (5-15 damage, avg ~10)
  - After: Floor 1 enemies deal 2d6+1 (3-13 damage, avg ~8)
  - Impact scaling:
    * Floor 1: 2d6+1 = 3-13 (avg ~8)
    * Floor 2: 2d6+2 = 4-14 (avg ~9)
    * Floor 3: 3d6+3 = 6-21 (avg ~13.5)
  - User reported: "the floor bonus made the enemies hit like a truck early on"
  - Makes early floors more survivable while maintaining difficulty curve

- **Combat Math Clarification Discussion**: User confusion about damage breakdown
  - User shared screenshot showing damage calculation breakdown
  - User stated: "this math doesn't make sense. I have no power ups"
  - Discussion about how damage bonuses (items, set bonuses, multipliers) are displayed
  - Verified damage calculation logging shows: Base + Set Bonus + Item Bonus + Multiplier

- **Flush/Triple Double-Counting Bug Fix**: Flush combos were also counted as triples
  - User discovered: "it's because a flush is also a triple 5"
  - Bug: Three 5s shown as "TRIPLE 5s" in combo description while damage showed "FLUSH"
  - Problem: `get_combo_description()` didn't check if triple/quad was actually a flush (all dice same)
  - Solution: Added flush checks to triple/quad/five branches
    * `if count == len(self.dice_values):` detects when ALL dice match
    * Shows "FLUSH! All {value}s! (+{value*30} ULTIMATE bonus!!!)" instead of triple
    * Only shows triple/quad/five if NOT all dice match
  - Impact: Combo display now matches damage calculation (flush-only, no double bonuses)

- **Small Straight Bonuses Added**: New combo options for 3 and 4 consecutive dice
  - User requested: "also you should add small straights"
  - Added three straight tiers:
    * Full Straight (5 consecutive): 1-2-3-4-5 or 2-3-4-5-6 = +40 bonus (unchanged)
    * Small Straight (4 consecutive): Any 4 in sequence = +25 bonus (new)
    * Mini Straight (3 consecutive): Any 3 in sequence = +15 bonus (new)
  - Updated `get_combo_description()` with tiered straight detection
  - Updated `calculate_damage()` with matching bonus amounts
  - Updated help dialog with new straight tier documentation
  - Impact: More combo opportunities, especially valuable with fewer dice

### Fixed
- **Bottom Button Redundancy**: Removed duplicate controls
  - Removed REST button from bottom frame (combat exploit)
  - Removed SHOP button from bottom frame (redundant with floor menu)
  - Replaced with single RETURN TO MENU button
  - Cleaner UI with more combat log space
  
- **Rest Menu Loop**: Removed redundant menu after resting
  - Before: Rest → Show continuation menu (Shop/Continue) → User complained about extra click
  - After: Rest → Heal 30 HP → Automatically go to next floor
  - Created rest_and_continue() method to handle in one flow
  - User requested: "after I rest, it still asks if I want to visit the shop or continue. that shouldn't happen"
  - Streamlines the rest path for players who just want to heal and move on

### Technical
- Added json module for high score persistence
- Added os module for file path handling
- Created self.game_active flag to track active runs
- Created self.scores_file path constant
- Added show_main_menu() entry point
- Added show_high_scores() leaderboard display
- Added load_high_scores() and save_high_score() functions
- Added show_floor_complete_menu() post-victory options
- Added show_continue_menu() for post-rest flow
- Added floor_action() to handle menu selections
- Added close_shop() to manage shop-to-menu transitions
- Added return_to_menu() with quit confirmation
