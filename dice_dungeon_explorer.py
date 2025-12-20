"""
Dice Dungeon Explorer
A roguelike dice game with dungeon exploration, combat, and interactive rooms
"""

import tkinter as tk
from tkinter import messagebox, ttk
from PIL import Image, ImageTk
import random
import json
import os
import sys
import copy
from collections import Counter
from debug_logger import get_logger
from explorer import ui_character_menu

# Add content engine to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dice_dungeon_content', 'engine'))

# Try to import content engine modules (optional)
try:
    from rooms_loader import load_rooms, pick_room_for_floor  # type: ignore
    from mechanics_engine import apply_on_enter, apply_on_clear, apply_on_fail, settle_temp_effects, get_effective_stats  # type: ignore
    from integration_hooks import attach_content, complete_room_success, complete_room_fail, on_floor_transition, apply_effective_modifiers  # type: ignore
    CONTENT_ENGINE_AVAILABLE = True
    print("[CONTENT ENGINE] Successfully imported content engine modules!")
except ImportError as ie:
    print(f"[CONTENT ENGINE] Import failed: {ie}")
    CONTENT_ENGINE_AVAILABLE = False
    CONTENT_ENGINE_AVAILABLE = False
    # Provide dummy functions if content engine is not available
    def load_rooms(): return []
    def pick_room_for_floor(rooms, floor): 
        # Return a basic fallback room if content engine isn't available
        return {
            'name': 'Empty Chamber',
            'description': 'A bare stone chamber.',
            'flavor': 'Dust motes drift through shafts of dim light.',
            'difficulty': 'Easy',
            'threats': [],
            'tags': [],
            'loot_table': 'basic'
        }
    def apply_on_enter(game, room_data, log_func): pass
    def apply_on_clear(game, room_data): pass
    def apply_on_fail(game, room_data): pass
    def settle_temp_effects(game): pass
    def get_effective_stats(game): return {}
    def attach_content(game, base_dir): pass
    def complete_room_success(game, log_func): pass
    def complete_room_fail(game, log_func): pass
    def on_floor_transition(game): pass
    def apply_effective_modifiers(game): pass

# Import game components from the explorer package
from explorer.rooms import Room
from explorer.combat import CombatManager
from explorer.dice import DiceManager
from explorer.inventory import InventoryManager
from explorer.inventory_display import InventoryDisplayManager
from explorer.inventory_equipment import InventoryEquipmentManager
from explorer.inventory_pickup import InventoryPickupManager
from explorer.inventory_usage import InventoryUsageManager
from explorer.navigation import NavigationManager
from explorer.store import StoreManager
from explorer.lore import LoreManager
from explorer.save_system import SaveSystem
from explorer.quests import QuestManager
from explorer.quest_definitions import create_default_quests
from explorer.ui_main_menu import MainMenuManager

class DiceDungeonExplorer:
    def __init__(self, root):
        self.root = root
        self.root.title("Dice Dungeon Explorer")
        
        # Set window and taskbar icon
        try:
            import os
            icon_path = os.path.join(os.path.dirname(__file__), "assets", "DD Logo.png")
            if os.path.exists(icon_path):
                # Create PhotoImage for the icon
                icon = tk.PhotoImage(file=icon_path)
                # Store reference to prevent garbage collection
                self.root.icon_image = icon
                # Set icon for window and taskbar (True makes it default for all windows)
                self.root.iconphoto(True, icon)
        except Exception as e:
            print(f"Could not load window icon: {e}")
            # Fallback to default icon
            try:
                self.root.iconphoto(False, tk.PhotoImage())
            except:
                pass  # If fallback also fails, just continue without icon
        
        self.root.geometry("950x700")  # Smaller default size
        self.root.minsize(900, 650)  # Reduced minimum size
        self.root.configure(bg='#2c1810')
        
        # Initialize debug logger
        self.debug_logger = get_logger()
        self.debug_logger.info("INIT", "DiceDungeonExplorer starting")
        
        # Track window scaling for responsive UI
        self.base_window_width = 1000
        self.base_window_height = 750
        self.scale_factor = 1.0
        
        # Bind window resize event for dynamic scaling
        self.root.bind('<Configure>', self.on_window_resize)
        
        # Ensure saves directory exists
        self.saves_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'saves')
        os.makedirs(self.saves_dir, exist_ok=True)
        
        # High scores file
        self.scores_file = os.path.join(self.saves_dir, 'dice_dungeon_explorer_scores.json')
        
        # Save game file (deprecated - now using slot system)
        self.save_file = os.path.join(self.saves_dir, 'dice_dungeon_explorer_save.json')
        
        # Load content system
        try:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            attach_content(self, base_dir)
            
            # Ensure _rooms was initialized by attach_content
            if not hasattr(self, '_rooms'):
                self._rooms = []
                self._current_room = None
            
            # Debug: Check if rooms loaded
            if hasattr(self, '_rooms') and self._rooms:
                print(f"[CONTENT ENGINE] Loaded {len(self._rooms)} rooms successfully!")
            else:
                print("[CONTENT ENGINE] WARNING: No rooms loaded, using fallback!")
            
            self.content_loaded = True
            
            # Load world lore and starter area
            lore_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'world_lore.json')
            with open(lore_file, 'r', encoding='utf-8') as f:
                self.world_lore = json.load(f)
                
            # Load item definitions for tooltips
            items_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'items_definitions.json')
            with open(items_file, 'r', encoding='utf-8') as f:
                self.item_definitions = json.load(f)
            
            # Load lore items (journal pages, quest notices, scrawled notes)
            lore_items_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'lore_items.json')
            with open(lore_items_file, 'r', encoding='utf-8') as f:
                self.lore_items = json.load(f)
            
            # Load combat flavor text
            combat_flavor_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'combat_flavor.json')
            with open(combat_flavor_file, 'r', encoding='utf-8') as f:
                combat_flavor = json.load(f)
                self.enemy_taunts = combat_flavor['enemy_taunts']
                self.enemy_hurt = combat_flavor['enemy_hurt']
                self.enemy_death = combat_flavor['enemy_death']
                self.player_attacks = combat_flavor['player_attacks']
                self.player_crits = combat_flavor['player_crits']
            
            # Load enemy type definitions (spawning/splitting mechanics)
            enemy_types_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'enemy_types.json')
            with open(enemy_types_file, 'r', encoding='utf-8') as f:
                self.enemy_types = json.load(f)
            
            # Define hardcoded color scheme with enhanced visual hierarchy
            self.color_schemes = {
                "Classic": {
                    # Background hierarchy (darkest to lightest)
                    "bg_primary": "#2c1810",      # Main dark brown background
                    "bg_secondary": "#1a0f08",    # Darker sections
                    "bg_dark": "#0f0805",         # Darkest areas
                    "bg_panel": "#3d2415",        # Raised panels (lighter)
                    "bg_header": "#231408",       # Header bar
                    "bg_room": "#2a1810",         # Room description area
                    "bg_log": "#1a1008",          # Adventure log
                    "bg_minimap": "#1f1408",      # Minimap panel
                    
                    # Border colors
                    "border_gold": "#b8932e",     # Muted gold borders
                    "border_dark": "#0a0604",     # Dark borders
                    "border_accent": "#8b7355",   # Brown accent borders
                    
                    # Text colors (bone/parchment theme)
                    "text_primary": "#e8dcc4",    # Bone white for main text
                    "text_secondary": "#a89884",  # Muted secondary text
                    "text_light": "#f5e6d3",      # Lightest text
                    "text_gold": "#d4af37",       # Muted gold
                    "text_green": "#7fae7f",      # Muted green (healing)
                    "text_red": "#c85450",        # Muted red (damage)
                    "text_cyan": "#5fa5a5",       # Muted cyan (info)
                    "text_purple": "#8b6f9b",     # Muted purple (rare)
                    "text_orange": "#d4823b",     # Muted orange (loot)
                    "text_white": "#ffffff",      # Pure white (accents)
                    "text_magenta": "#b565b5",    # Muted magenta (crit)
                    "text_warning": "#d4a537",    # Warning yellow
                    
                    # Button colors
                    "button_primary": "#d4af37",  # Muted gold (main actions)
                    "button_secondary": "#5fa5a5",# Muted cyan (secondary)
                    "button_success": "#7fae7f",  # Muted green (success)
                    "button_danger": "#c85450",   # Muted red (danger)
                    "button_disabled": "#4a3a2a", # Disabled state
                    "button_hover": "#f0cf5a",    # Lighter gold hover
                    
                    # HP bar colors
                    "hp_full": "#7fae7f",         # Full HP (green)
                    "hp_mid": "#d4a537",          # Mid HP (yellow)
                    "hp_low": "#c85450",          # Low HP (red)
                    "hp_bg": "#1a1008",           # HP bar background
                }
            }
            
            # Unicode icons for UI elements
            self.icons = {
                "hp": "❤",
                "gold": "◆",
                "floor": "▼",
                "damage": "⚔",
                "heal": "✚",
                "crit": "★",
                "item": "◉",
                "chest": "◘",
                "stairs": "▼",
                "store": "◆",
                "warning": "⚠",
                "death": "✖",
                "arrow_up": "▲",
                "arrow_down": "▼",
                "arrow_left": "◄",
                "arrow_right": "►",
            }
            
            # Load difficulty settings
            difficulty_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'difficulty_settings.json')
            with open(difficulty_file, 'r', encoding='utf-8') as f:
                self.difficulty_settings = json.load(f)
            
            # Load container definitions
            container_file = os.path.join(base_dir, 'dice_dungeon_content', 'data', 'container_definitions.json')
            with open(container_file, 'r', encoding='utf-8') as f:
                self.container_definitions = json.load(f)
            
            # Load enemy sprites
            self.enemy_sprites = {}
            self.sprite_images = {}  # Store PhotoImage references to prevent garbage collection
            self.load_enemy_sprites(base_dir)
                
        except Exception as e:
            messagebox.showerror("Content Load Error", f"Failed to load game content:\n{e}")
            self.content_loaded = False
            self.root.quit()
            return
        
        # Player stats (reduced health pool from 100 to 50 for increased difficulty)
        self.gold = 0
        self.health = 50
        self.max_health = 50
        self.floor = 1
        self.run_score = 0
        self.total_gold_earned = 0
        self.rooms_explored = 0
        self.enemies_killed = 0
        self.chests_opened = 0
        self.game_active = False
        self.in_settings = False
        
        # Inventory (reduced from 20 to 10 for increased difficulty)
        self.inventory = []
        self.max_inventory = 10
        
        # Equipment slots - track what's currently equipped
        self.equipped_items = {
            "weapon": None,    # Damage bonuses
            "armor": None,     # Shield/defense
            "accessory": None, # Crit/reroll bonuses
            "backpack": None   # Inventory expansion
        }
        
        # Equipment durability tracking - {item_name: current_durability}
        self.equipment_durability = {}
        
        # Equipment floor level tracking - {item_name: floor_found}
        # Used to scale equipment stats based on which floor it was found/bought on
        self.equipment_floor_level = {}
        
        # Dice state
        self.num_dice = 3
        self.max_dice = 8
        self.dice_values = []
        self.dice_locked = []
        self.rolls_left = 3
        
        # Power-ups
        self.multiplier = 1.0
        self.damage_bonus = 0
        self.heal_bonus = 0
        self.reroll_bonus = 0
        self.crit_chance = 0.1
        self.armor = 0  # Armor rating for damage reduction
        
        # Temporary combat buffs (reset after each combat)
        self.temp_combat_damage = 0
        self.temp_combat_crit = 0
        self.temp_combat_rerolls = 0
        
        # Adventure log for persistence and debugging
        self.adventure_log = []  # List of (message, tag) tuples
        
        # Combat button state tracking
        self.combat_buttons_enabled = True
        self.current_save_slot = None  # Track which save slot is being used
        
        # Developer mode system
        self.dev_mode = False  # Developer mode toggle
        self.dev_key_sequence = []  # Track key sequence for dev mode activation
        self.dev_invincible = False  # God mode flag
        self.dev_config = {  # Runtime adjustable parameters
            "enemy_hp_mult": 1.0,
            "enemy_damage_mult": 1.0,
            "player_damage_mult": 1.0,
            "gold_drop_mult": 1.0,
            "item_spawn_rate_mult": 1.0,
            "shop_buy_price_mult": 1.0,
            "shop_sell_price_mult": 1.0,
            "durability_loss_mult": 1.0,
            "enemy_dice_mult": 1.0
        }
        
        # Content system tracking
        self.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
        self.temp_effects = {}
        self.temp_shield = 0
        self.shop_discount = 0.0
        self.purchased_upgrades_this_floor = set()  # Track permanent upgrades bought on current floor
        
        # Comprehensive stats tracking
        self.stats = {
            # Combat stats
            "enemies_encountered": 0,
            "enemies_fled": 0,
            "enemies_defeated": 0,
            "mini_bosses_defeated": 0,
            "bosses_defeated": 0,
            "total_damage_dealt": 0,
            "total_damage_taken": 0,
            "highest_single_damage": 0,
            "critical_hits": 0,
            
            # Economy stats
            "gold_found": 0,
            "gold_spent": 0,
            "items_purchased": 0,
            "items_sold": 0,
            
            # Items stats
            "items_found": 0,
            "items_used": 0,
            "potions_used": 0,
            "containers_searched": 0,
            
            # Equipment stats
            "weapons_broken": 0,
            "armor_broken": 0,
            "weapons_repaired": 0,
            "armor_repaired": 0,
            
            # Progress stats
            "rooms_explored": 0,
            "times_rested": 0,
            
            # Lore items found (track each type)
            "lore_found": {
                "Guard Journal": 0,
                "Quest Notice": 0,
                "Scrawled Note": 0,
                "Training Manual Page": 0,
                "Pressed Page": 0,
                "Surgeon's Note": 0,
                "Puzzle Note": 0,
                "Cracked Map Scrap": 0,
                "Star Chart": 0,
                "Old Letter": 0,
                "Prayer Strip": 0
            },
            
            # Enemy-specific tracking
            "enemy_kills": {},  # {enemy_name: count}
            "most_damaged_enemy": {"name": "", "damage": 0},
            
            # Item collection tracking (all items ever collected)
            "items_collected": {}  # {item_name: count}
        }
        
        # Lore item persistence - track USED entry indices to avoid duplicates
        self.used_lore_entries = {
            "guards_journal_pages": [],
            "quest_notices": [],
            "scrawled_notes": [],
            "training_manual_pages": [],
            "pressed_pages": [],
            "surgeons_notes": [],
            "puzzle_notes": [],
            "star_charts": [],
            "cracked_map_scraps": [],
            "old_letters": [],
            "prayer_strips": []
        }  # Format: {"guards_journal_pages": [0, 3, 7], ...}
        self.discovered_lore_items = []  # Track which lore items have been found (removed from pool)
        
        # Lore Codex - track all discovered lore pages with their full content
        # Format: [{"title": "Guard Journal", "content": "...", "floor_found": 3}, ...]
        self.lore_codex = []
        
        # Track which lore entry each item shows (by item collection order)
        # Format: {"Guard Journal_0": 3, "Quest Notice_0": 5, "Guard Journal_1": 7}
        self.lore_item_assignments = {}
        self.lore_item_counters = {}  # Counter for each lore item type
        
        # Lore max counts for codex progress tracking (must match category_info json_key values)
        self.lore_max_counts = {
            "guards_journal_pages": 16,
            "quest_notices": 12,
            "training_manual_pages": 10,
            "scrawled_notes": 10,
            "map_scraps": 10,
            "pressed_pages": 6,
            "surgeons_notes": 6,
            "puzzle_notes": 4,
            "star_charts": 4,
            "old_letters": 12,
            "prayer_strips": 10
        }
        
        # Game settings
        self.settings = {"difficulty": "Normal", "color_scheme": "Classic", "audio_volume": 0.5, "text_speed": "Medium"}
        
        # Dice style presets - rich, high-contrast dark fantasy theme
        self.dice_styles = {
            "classic_white": {
                "id": "classic_white",
                "label": "Classic White",
                "bg": "#f5f5dc",  # Ivory/beige
                "border": "#2a2a2a",
                "pip_color": "#1a1a1a",  # Dark pips
                "face_mode": "pips",
                "locked_bg": "#ffd700",
                "locked_border": "#8b6914",
                "locked_pip": "#000000",
                "button_bg": "#d4d4bc",
                "button_fg": "#1a1a1a"
            },
            "obsidian_gold": {
                "id": "obsidian_gold",
                "label": "Obsidian Gold",
                "bg": "#0a0a0a",  # Nearly black
                "border": "#ffd700",  # Gold border
                "pip_color": "#ffd700",  # Bright gold
                "face_mode": "numbers",
                "locked_bg": "#1a1a1a",
                "locked_border": "#ffed4e",
                "locked_pip": "#ffed4e",
                "button_bg": "#1a1a1a",
                "button_fg": "#ffd700"
            },
            "bloodstone_red": {
                "id": "bloodstone_red",
                "label": "Bloodstone Red",
                "bg": "#4a0000",  # Deep blood red
                "border": "#8b0000",
                "pip_color": "#e8dcc4",  # Bone-colored
                "face_mode": "pips",
                "locked_bg": "#6a0000",
                "locked_border": "#ff4444",
                "locked_pip": "#ffffff",
                "button_bg": "#3a0000",
                "button_fg": "#e8dcc4"
            },
            "arcane_blue": {
                "id": "arcane_blue",
                "label": "Arcane Blue",
                "bg": "#001a33",  # Dark navy
                "border": "#00ffff",  # Cyan border
                "pip_color": "#00ffff",  # Cyan pips
                "face_mode": "numbers",
                "locked_bg": "#002a44",
                "locked_border": "#7fffd4",
                "locked_pip": "#7fffd4",
                "button_bg": "#002a44",
                "button_fg": "#00ffff"
            },
            "bone_ink": {
                "id": "bone_ink",
                "label": "Bone & Ink",
                "bg": "#f5f5dc",  # Off-white/bone
                "border": "#1a1a1a",
                "pip_color": "#000000",  # Dark ink
                "face_mode": "pips",
                "locked_bg": "#ffd700",
                "locked_border": "#8b6914",
                "locked_pip": "#000000",
                "button_bg": "#e8dcc4",
                "button_fg": "#000000"
            },
            "emerald_forest": {
                "id": "emerald_forest",
                "label": "Emerald Forest",
                "bg": "#0d3d0d",  # Deep forest green
                "border": "#1a5a1a",
                "pip_color": "#90ee90",  # Light green
                "face_mode": "numbers",
                "locked_bg": "#1a5a1a",
                "locked_border": "#7cfc00",
                "locked_pip": "#adff2f",
                "button_bg": "#1a4a1a",
                "button_fg": "#90ee90"
            },
            "royal_purple": {
                "id": "royal_purple",
                "label": "Royal Purple",
                "bg": "#1a0033",  # Dark royal purple
                "border": "#6a4a8a",
                "pip_color": "#daa520",  # Pale gold
                "face_mode": "numbers",
                "locked_bg": "#2a0044",
                "locked_border": "#da70d6",
                "locked_pip": "#ffd700",
                "button_bg": "#2a1a3a",
                "button_fg": "#daa520"
            },
            "rose_quartz": {
                "id": "rose_quartz",
                "label": "Rose Quartz",
                "bg": "#ffb3d9",  # Soft pink
                "border": "#c71585",  # Deep pink border
                "pip_color": "#8b0045",  # Dark magenta pips
                "face_mode": "pips",
                "locked_bg": "#ff69b4",  # Hot pink when locked
                "locked_border": "#ff1493",
                "locked_pip": "#ffffff",
                "button_bg": "#ffb3d9",
                "button_fg": "#8b0045"
            }
        }
        
        # Current dice style configuration
        self.current_dice_style = "classic_white"
        self.dice_style_overrides = {
            "bg": None,
            "pip_color": None,
            "face_mode": None
        }
        
        # Define difficulty multipliers
        self.difficulty_multipliers = {
            "Easy": {
                "player_damage_mult": 1.5,
                "player_damage_taken_mult": 0.7,
                "enemy_health_mult": 0.7,
                "enemy_damage_mult": 1.0,
                "loot_chance_mult": 1.3,
                "heal_mult": 1.2
            },
            "Normal": {
                "player_damage_mult": 1.0,
                "player_damage_taken_mult": 1.0,
                "enemy_health_mult": 1.0,
                "enemy_damage_mult": 1.0,
                "loot_chance_mult": 1.0,
                "heal_mult": 1.0
            },
            "Hard": {
                "player_damage_mult": 0.8,
                "player_damage_taken_mult": 1.3,
                "enemy_health_mult": 1.3,
                "enemy_damage_mult": 1.3,
                "loot_chance_mult": 0.8,
                "heal_mult": 0.8
            },
            "Brutal": {
                "player_damage_mult": 0.6,
                "player_damage_taken_mult": 1.6,
                "enemy_health_mult": 1.8,
                "enemy_damage_mult": 1.6,
                "loot_chance_mult": 0.6,
                "heal_mult": 0.6
            }
        }
        
        # Enemy type definitions will be loaded from JSON file
        # (Loaded in content system initialization above)
        
        # Define color schemes
        # Note: This is a duplicate definition that should be removed
        # The actual color schemes are defined later in the constructor
        
        self.load_settings()
        # Force Classic color scheme only
        self.settings["color_scheme"] = "Classic"
        self.current_colors = self.color_schemes["Classic"]
        
        # Settings tracking
        self.settings_return_to = None  # Track where to return after settings
        self.original_settings = None  # Track original settings for change detection
        self.settings_modified = False  # Track if settings were changed
        
        # Exploration state
        self.dungeon = {}
        self.current_pos = (0, 0)
        self.current_room = None
        self.stairs_found = False
        self.in_combat = False
        self.in_interaction = False
        
        # Boss spawn tracking
        self.next_mini_boss_at = random.randint(6, 10)
        self.next_boss_at = None
        
        # Store tracking
        self.store_found = False
        self.store_position = None
        self.store_room = None
        self.floor_store_inventory = None  # Generated once per floor, consistent across all store visits
        
        # Enemy state - support for multiple enemies
        self.enemies = []  # List of enemy dictionaries
        self.current_enemy_index = 0  # Which enemy is currently being targeted
        self.mystic_ring_used = False  # Track if Mystic Ring used this combat
        # Legacy single-enemy properties (for compatibility)
        self.enemy_health = 0
        self.enemy_max_health = 0
        self.enemy_name = ""
        self.enemy_num_dice = 2
        self.last_damage_was_crit = False
        # Combat turn tracking for spawning enemies
        self.combat_turn_count = 0
        # Burn damage tracking (initial_damage, turns_remaining)
        self.enemy_burn_status = {}  # Dict mapping enemy index to burn info
        
        # UI elements
        self.main_frame = None
        self.game_frame = None
        self.dialog_frame = None
        self.dice_buttons = []
        self.minimap_canvas = None
        self.minimap_zoom = 1.0  # Zoom level for minimap (0.5 = zoomed out, 2.0 = zoomed in)
        self.zoom_label = None
        self.minimap_pan_x = 0  # Pan offset X (in room coordinates)
        self.minimap_pan_y = 0  # Pan offset Y (in room coordinates)
        
        # Keybindings
        self.setup_keybindings()
        
        # Initialize manager instances
        # These managers handle specific subsystems and keep the main class cleaner
        self.combat_manager = CombatManager(self)
        self.dice_manager = DiceManager(self)
        self.inventory_manager = InventoryManager(self)
        self.inventory_display_manager = InventoryDisplayManager(self)
        self.inventory_equipment_manager = InventoryEquipmentManager(self)
        self.inventory_pickup_manager = InventoryPickupManager(self)
        self.inventory_usage_manager = InventoryUsageManager(self)
        self.navigation_manager = NavigationManager(self)
        self.store_manager = StoreManager(self)
        self.lore_manager = LoreManager(self)
        self.save_system = SaveSystem(self)
        self.quest_manager = QuestManager(self)
        self.main_menu_manager = MainMenuManager(self)
        
        # Import and initialize UI dialogs manager
        from explorer.ui_dialogs import UIDialogsManager
        self.ui_dialogs_manager = UIDialogsManager(self)
        
        # Register default quests
        self.quest_manager.register_default_quests(create_default_quests())
        
        # Show main menu
        self.main_menu_manager.show_main_menu()
    
    def load_settings(self):
        """Load or initialize game settings"""
        self.settings_file = os.path.join(self.saves_dir, 'dice_dungeon_settings.json')
        
        # Default settings
        default_settings = {
            "difficulty": "Normal",  # Easy, Normal, Hard, Brutal
            "color_scheme": "Classic",  # Classic, Dark, Light, Neon, Forest
            "audio_enabled": False,  # Coming soon
            "keybindings": {
                "inventory": "Tab",
                "menu": "m",
                "rest": "r",
                "move_north": "w",
                "move_south": "s",
                "move_east": "d",
                "move_west": "a"
            }
        }
        
        try:
            with open(self.settings_file, 'r') as f:
                self.settings = json.load(f)
                
                # Ensure keybindings exist (for backwards compatibility)
                if "keybindings" not in self.settings:
                    self.settings["keybindings"] = default_settings["keybindings"]
                
                # Ensure text_speed exists (for backwards compatibility)
                if "text_speed" not in self.settings:
                    self.settings["text_speed"] = "Medium"
        except:
            self.settings = default_settings
            self.save_settings()
        
        # Force Classic color scheme only
        self.settings["color_scheme"] = "Classic"
        self.current_colors = self.color_schemes["Classic"]
    
    def save_settings(self):
        """Save settings to file"""
        try:
            with open(self.settings_file, 'w') as f:
                json.dump(self.settings, f, indent=2)
        except Exception as e:
            print(f"Error saving settings: {e}")
    
    def setup_mousewheel_scrolling(self, widget):
        """Universal mouse wheel scrolling setup for any scrollable widget"""
        def _on_mousewheel(event):
            try:
                # Scroll the widget
                if isinstance(widget, tk.Text):
                    widget.yview_scroll(int(-1*(event.delta/120)), "units")
                elif isinstance(widget, tk.Canvas):
                    widget.yview_scroll(int(-1*(event.delta/120)), "units")
                elif hasattr(widget, 'yview_scroll'):
                    widget.yview_scroll(int(-1*(event.delta/120)), "units")
            except Exception as e:
                pass  # Silently ignore scroll errors
        
        def _on_key_scroll(event):
            """Handle keyboard scrolling"""
            try:
                if event.keysym == "Up":
                    widget.yview_scroll(-3, "units")
                elif event.keysym == "Down":
                    widget.yview_scroll(3, "units")
                elif event.keysym == "Prior":  # Page Up
                    widget.yview_scroll(-10, "units")
                elif event.keysym == "Next":   # Page Down  
                    widget.yview_scroll(10, "units")
            except:
                pass
            return "break"
        
        # Bind mousewheel directly to the widget and all its children
        # This way scrolling works anywhere in the dialog
        def bind_tree(widget_to_bind):
            widget_to_bind.bind("<MouseWheel>", _on_mousewheel, add='+')
            for child in widget_to_bind.winfo_children():
                bind_tree(child)
        
        # Bind to the widget's parent dialog frame if it exists
        parent = widget
        while parent:
            if isinstance(parent, tk.Frame) and parent.winfo_class() == 'Frame':
                # Found a frame, bind to it and all children
                bind_tree(parent)
                break
            try:
                parent = parent.master
            except:
                break
        
        # Also bind directly to the scrollable widget
        widget.bind("<MouseWheel>", _on_mousewheel, add='+')
        
        # Configure widget for keyboard scrolling
        if hasattr(widget, 'configure'):
            try:
                widget.configure(highlightthickness=0)
            except:
                pass
        widget.bind("<Button-1>", lambda e: widget.focus_set())
        widget.bind("<Up>", _on_key_scroll)
        widget.bind("<Down>", _on_key_scroll)
        widget.bind("<Prior>", _on_key_scroll)
        widget.bind("<Next>", _on_key_scroll)
    
    def get_difficulty_modifier(self, modifier_type):
        """Get difficulty modifier value"""
        difficulty = self.settings.get("difficulty", "Normal")
        return self.difficulty_settings[difficulty].get(modifier_type, 1.0)
    
    def update_scroll_region(self):
        """Update scroll region for main game canvas"""
        if hasattr(self, 'main_canvas') and hasattr(self, 'scroll_frame'):
            self.main_canvas.update_idletasks()
            self.main_canvas.configure(scrollregion=self.main_canvas.bbox("all"))
    
    def setup_keybindings(self):
        """Setup global keybindings for the game"""
        # Unbind all previous bindings to avoid duplicates
        self.root.unbind_all('<Tab>')
        self.root.unbind_all('<Escape>')
        self.root.unbind_all('<r>')
        self.root.unbind_all('<i>')
        self.root.unbind_all('<m>')
        self.root.unbind_all('<h>')
        self.root.unbind_all('<w>')
        self.root.unbind_all('<a>')
        self.root.unbind_all('<s>')
        self.root.unbind_all('<d>')
        self.root.unbind_all('<g>')
        
        # Apply keybindings from settings
        self.apply_keybindings()
    
    def apply_keybindings(self):
        """Apply keybindings from settings"""
        keybindings = self.settings.get("keybindings", {
            "inventory": "Tab",
            "menu": "m",
            "rest": "r",
            "move_north": "w",
            "move_south": "s",
            "move_east": "d",
            "move_west": "a"
        })
        
        # Unbind all previous custom bindings
        for key in ['Tab', 'Escape', 'r', 'R', 'i', 'I', 'm', 'M', 'h', 'H', 
                    'w', 'W', 's', 'S', 'a', 'A', 'd', 'D', 'g', 'G']:
            try:
                self.root.unbind(f'<{key}>')
            except:
                pass
        
        # ESC is always bound to menu
        self.root.bind('<Escape>', lambda e: self.handle_hotkey('menu'))
        
        # Special keys that don't have uppercase variants
        special_keys = ['Tab', 'Escape', 'Return', 'BackSpace', 'Delete', 'Insert', 
                       'Home', 'End', 'Prior', 'Next', 'Up', 'Down', 'Left', 'Right',
                       'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12']
        
        # Helper function to bind keys safely
        def bind_key_safely(key, action):
            """Bind a key, handling special keys that don't have uppercase variants"""
            self.root.bind(f'<{key}>', lambda e: self.handle_hotkey(action))
            # Only bind uppercase if it's not a special key
            if key not in special_keys:
                self.root.bind(f'<{key.upper()}>', lambda e: self.handle_hotkey(action))
        
        # Bind configured keys
        if "inventory" in keybindings:
            key = keybindings["inventory"]
            bind_key_safely(key, 'inventory')
        
        if "menu" in keybindings:
            key = keybindings["menu"]
            bind_key_safely(key, 'menu')
        
        if "rest" in keybindings:
            key = keybindings["rest"]
            bind_key_safely(key, 'rest')
        
        # Movement keys
        if "move_north" in keybindings:
            key = keybindings["move_north"]
            bind_key_safely(key, 'north')
        
        if "move_south" in keybindings:
            key = keybindings["move_south"]
            bind_key_safely(key, 'south')
        
        if "move_west" in keybindings:
            key = keybindings["move_west"]
            bind_key_safely(key, 'west')
        
        if "move_east" in keybindings:
            key = keybindings["move_east"]
            bind_key_safely(key, 'east')
        
        # Character status key (always 'g')
        bind_key_safely('g', 'character_status')
        
        # Inventory shortcut key (always 'i')
        bind_key_safely('i', 'inventory')
        
        # Arrow keys always work for movement
        self.root.bind('<Up>', lambda e: self.handle_hotkey('north'))
        self.root.bind('<Down>', lambda e: self.handle_hotkey('south'))
        self.root.bind('<Left>', lambda e: self.handle_hotkey('west'))
        self.root.bind('<Right>', lambda e: self.handle_hotkey('east'))
    
    def handle_hotkey(self, action):
        """Handle hotkey presses during gameplay"""
        # Special handling for menu key (ESC or custom) - toggle pause menu
        if action == 'menu':
            # If a dialog is open (including pause menu), close it
            if self.dialog_frame and self.dialog_frame.winfo_exists():
                self.close_dialog()
                return
            # Check if we're in settings mode (highest priority)
            if hasattr(self, 'in_settings') and self.in_settings:
                self.exit_settings()
                return
            # Check if we're in keybindings editor
            if hasattr(self, 'in_keybind_editor') and self.in_keybind_editor:
                self.show_settings()
                return
            # Otherwise open pause menu if in active gameplay
            if self.game_active:
                self.show_pause_menu()
            return
        
        # Special handling for inventory - always available during gameplay
        if action == 'inventory':
            if self.game_active:
                self.show_inventory()
            return
        
        # Special handling for character status - always available during gameplay
        if action == 'character_status':
            if self.game_active:
                self.show_character_status()
            return
        
        # Don't process other hotkeys if we're not in active gameplay or if dialog is open
        if not self.game_active or self.dialog_frame:
            return
        
        # Don't process movement hotkeys if in combat or interaction
        if action in ['north', 'south', 'east', 'west'] and (self.in_combat or self.in_interaction):
            return
        
        # Don't process rest hotkey during combat
        if action == 'rest' and self.in_combat:
            return
        
        # Process actions
        if action == 'rest':
            self.rest()
        elif action == 'north':
            self.explore_direction('N')
        elif action == 'south':
            self.explore_direction('S')
        elif action == 'west':
            self.explore_direction('W')
        elif action == 'east':
            self.explore_direction('E')
    
    def log(self, message, tag='system'):
        """Add message to the log and persist it"""
        # Store in adventure log for save persistence
        self.adventure_log.append((message, tag))
        
        # Also write to debug log file in real-time (slot-specific)
        try:
            slot_suffix = f"_slot_{self.current_save_slot}" if self.current_save_slot else "_new_game"
            debug_log_file = os.path.join(self.saves_dir, 
                                         f'adventure_log{slot_suffix}.txt')
            with open(debug_log_file, 'a', encoding='utf-8') as f:
                import datetime
                timestamp = datetime.datetime.now().strftime("%H:%M:%S")
                f.write(f"[{timestamp}] [{tag.upper()}] {message}\n")
        except:
            pass  # Silently fail if debug logging doesn't work
        
        # Display in UI with typewriter effect
        if not hasattr(self, 'log_text'):
            return
        
        # Add to typewriter queue
        if not hasattr(self, 'typewriter_queue'):
            self.typewriter_queue = []
            self.typewriter_active = False
        
        # Check if we're in instant mode for revisited rooms
        instant_mode = getattr(self, 'instant_text_mode', False)
        self.typewriter_queue.append((message, tag, instant_mode))
        
        # Start typewriter if not already active
        if not self.typewriter_active:
            self._process_typewriter_queue()
    
    def _process_typewriter_queue(self):
        """Process the typewriter queue with animated text"""
        if not self.typewriter_queue:
            self.typewriter_active = False
            return
        
        self.typewriter_active = True
        
        # Support both old format (message, tag) and new format (message, tag, instant_mode)
        queue_item = self.typewriter_queue.pop(0)
        if len(queue_item) == 3:
            message, tag, instant_mode = queue_item
        else:
            message, tag = queue_item
            instant_mode = False
        
        # Type out the message character by character
        self._typewriter_effect(message, tag, 0, instant_mode)
    
    def _typewriter_effect(self, message, tag, index, instant_mode=False):
        """Animate typing effect for a single message"""
        if index < len(message):
            self.log_text.config(state=tk.NORMAL)
            self.log_text.insert(tk.END, message[index], tag)
            self.log_text.see(tk.END)
            self.log_text.config(state=tk.DISABLED)
            
            # Force immediate update and smooth scrolling
            self.log_text.update()
            self.log_text.see(tk.END)
            self.root.update_idletasks()
            
            # Get text speed delay from settings
            text_speed = self.settings.get('text_speed', 'Medium')
            speed_delays = {'Slow': 15, 'Medium': 13, 'Fast': 7, 'Instant': 0}
            delay = speed_delays.get(text_speed, 13)
            
            # Force instant mode for revisited rooms or if setting is Instant
            if instant_mode or delay == 0:
                # Instant mode - print all remaining text at once
                self.log_text.config(state=tk.NORMAL)
                self.log_text.insert(tk.END, message[index+1:], tag)
                self.log_text.see(tk.END)
                self.log_text.config(state=tk.DISABLED)
                # Jump to end of message
                self._typewriter_effect(message, tag, len(message), instant_mode)
            else:
                # Schedule next character
                self.root.after(delay, lambda: self._typewriter_effect(message, tag, index + 1, instant_mode))
        else:
            # Add newline with animated smooth scrolling
            self.log_text.config(state=tk.NORMAL)
            self.log_text.insert(tk.END, '\n')
            self.log_text.config(state=tk.DISABLED)
            
            # Skip animation for instant mode (revisited rooms)
            if instant_mode:
                self.log_text.see(tk.END)
                # Process next message immediately with no delay
                self._process_typewriter_queue()
            else:
                # Animate smooth scroll to bottom over multiple frames
                self._smooth_scroll_to_end(0, 5)
    
    def _smooth_scroll_to_end(self, frame, max_frames):
        """Animate smooth scrolling to the end of the log"""
        if frame < max_frames:
            self.log_text.see(tk.END)
            self.log_text.update()
            # Schedule next frame (10ms for smooth animation)
            self.root.after(10, lambda: self._smooth_scroll_to_end(frame + 1, max_frames))
        else:
            # Animation complete, process next in queue
            self.root.after(50, self._process_typewriter_queue)
    
    def export_adventure_log(self):
        """Export the full adventure log to a text file for debugging"""
        try:
            import datetime
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            slot_suffix = f"_slot_{self.current_save_slot}" if self.current_save_slot else "_new_game"
            export_file = os.path.join(self.saves_dir, 
                                      f'adventure_log_export{slot_suffix}_{timestamp}.txt')
            
            with open(export_file, 'w', encoding='utf-8') as f:
                f.write(f"DICE DUNGEON EXPLORER - Adventure Log Export\n")
                f.write(f"Save Slot: {self.current_save_slot if self.current_save_slot else 'New Game (Not Saved)'}\n")
                f.write(f"Exported: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"{'='*70}\n\n")
                f.write(f"Player Stats:\n")
                f.write(f"  Floor: {self.floor}\n")
                f.write(f"  Health: {self.health}/{self.max_health}\n")
                f.write(f"  Gold: {self.gold}\n")
                f.write(f"  Rooms Explored: {self.rooms_explored}\n")
                f.write(f"  Enemies Killed: {self.enemies_killed}\n")
                f.write(f"  Inventory: {len(self.inventory)}/{self.max_inventory}\n")
                f.write(f"\n{'='*70}\n\n")
                f.write(f"Adventure Log ({len(self.adventure_log)} entries):\n\n")
                
                for i, (message, tag) in enumerate(self.adventure_log, 1):
                    f.write(f"{i}. [{tag.upper()}] {message}\n")
            
            messagebox.showinfo("Log Exported", f"Adventure log exported to:\n{os.path.basename(export_file)}\n\nSave Slot: {self.current_save_slot if self.current_save_slot else 'New Game'}")
            return export_file
        except Exception as e:
            messagebox.showerror("Export Failed", f"Failed to export adventure log:\n{e}")
            return None
    
    def _update_combat_button_states(self):
        """Update combat button states based on combat_buttons_enabled flag"""
        if not self.in_combat:
            return
        
        # Disable/enable roll dice button
        if hasattr(self, 'dice_frame'):
            for widget in self.combat_buttons_frame.winfo_children():
                for button in widget.winfo_children():
                    if isinstance(button, tk.Button):
                        if self.combat_buttons_enabled:
                            # Re-enable with original state logic
                            if 'Roll' in button.cget('text'):
                                button.config(state=tk.NORMAL)
                            elif 'ATTACK' in button.cget('text'):
                                # Attack button state depends on has_rolled
                                if hasattr(self, 'has_rolled') and self.has_rolled:
                                    button.config(state=tk.NORMAL, bg='#ff6b6b', fg='#ffffff')
                                else:
                                    button.config(state=tk.DISABLED, bg='#666666', fg='#333333')
                            elif 'Mystic Ring' in button.cget('text'):
                                if not self.mystic_ring_used:
                                    button.config(state=tk.NORMAL)
                        else:
                            # Disable all combat buttons during text animation
                            button.config(state=tk.DISABLED)
    
    def try_add_to_inventory(self, item_name, source="found"):
        """
        Try to add an item to inventory. If inventory is full, add to room's uncollected items.
        Returns True if added, False if inventory was full.
        """
        if len(self.inventory) < self.max_inventory:
            self.inventory.append(item_name)
            # Track acquisition using centralized function
            self.inventory_equipment_manager.track_item_acquisition(item_name, source)
            
            if source == "found":
                self.log(f"Found {item_name}!", 'loot')
            elif source == "reward":
                self.log(f"Received {item_name}!", 'loot')
            elif source == "purchase":
                self.log(f"[PURCHASE] Bought {item_name}!", 'loot')
            elif source == "search":
                self.log(f"[SEARCH] Collected {item_name}!", 'loot')
            
            return True
        else:
            # Inventory full - add to room's uncollected items
            if hasattr(self, 'current_room') and self.current_room:
                if item_name not in self.current_room.uncollected_items:
                    self.current_room.uncollected_items.append(item_name)
            
            self.log(f"❌ INVENTORY FULL! {item_name} left behind.", 'system')
            self.log(f"▪ Make space and return to pick it up. ({len(self.inventory)}/{self.max_inventory})", 'system')
            return False
    
    def get_responsive_dialog_size(self, base_width, base_height, width_percent=0.5, height_percent=0.7):
        """Calculate responsive dialog size based on window dimensions"""
        window_width = self.root.winfo_width()
        window_height = self.root.winfo_height()
        
        # Use percentage of window size, but clamp between min (base) and max values
        min_width = base_width
        max_width = int(base_width * 1.5)
        min_height = base_height
        max_height = int(base_height * 1.5)
        
        dialog_width = max(min_width, min(max_width, int(window_width * width_percent)))
        dialog_height = max(min_height, min(max_height, int(window_height * height_percent)))
        
        return dialog_width, dialog_height
    
    def on_window_resize(self, event):
        """Handle window resize events to update scale factor and refresh main menu if visible"""
        # Only update if the event is for the root window
        if event.widget == self.root:
            current_width = self.root.winfo_width()
            current_height = self.root.winfo_height()
            
            # Calculate scale factor based on both dimensions (use the smaller ratio to prevent overflow)
            width_scale = current_width / self.base_window_width
            height_scale = current_height / self.base_window_height
            self.scale_factor = min(width_scale, height_scale)
            
            # Clamp scale factor to reasonable bounds
            self.scale_factor = max(0.8, min(self.scale_factor, 2.5))
            
            # If we're on the main menu (no game_frame exists), refresh it for responsive layout
            if hasattr(self, 'main_frame') and self.main_frame.winfo_exists() and not hasattr(self, 'game_frame'):
                # Delay the refresh slightly to avoid excessive calls during window dragging
                self.root.after(100, self.main_menu_manager._delayed_main_menu_refresh)
    
    def load_enemy_sprites(self, base_dir):
        """Load enemy sprite images from disk - automatically loads all sprites"""
        import re
        sprites_dir = os.path.join(base_dir, 'assets', 'sprites', 'enemies')
        
        if not os.path.exists(sprites_dir):
            print(f"Sprites directory not found: {sprites_dir}")
            return
        
        # Get all enemy folders
        try:
            enemy_folders = [f for f in os.listdir(sprites_dir) 
                           if os.path.isdir(os.path.join(sprites_dir, f))]
        except Exception as e:
            print(f"Error reading sprites directory: {e}")
            return
        
        loaded_count = 0
        failed_count = 0
        
        for folder_name in enemy_folders:
            # Convert folder name back to enemy name with special handling for apostrophes
            # e.g., "charmers_serpent" -> "Charmer's Serpent"
            # e.g., "jury_of_crows" -> "Jury of Crows"
            
            # First try standard conversion
            enemy_name = ' '.join(word.capitalize() for word in folder_name.split('_'))
            
            # Handle special cases
            # "Charmers" -> "Charmer's"
            enemy_name = re.sub(r'\bCharmers\b', "Charmer's", enemy_name)
            # "Jury Of Crows" -> "Jury of Crows" (lowercase "of")
            enemy_name = re.sub(r'\bOf\b', 'of', enemy_name)
            
            sprite_path = os.path.join(sprites_dir, folder_name, 'rotations', 'south.png')
            
            if os.path.exists(sprite_path):
                try:
                    # Load and resize image to 90x90 for display
                    img = Image.open(sprite_path)
                    img = img.resize((90, 90), Image.LANCZOS)
                    photo = ImageTk.PhotoImage(img)
                    
                    # Store both the PhotoImage and original for reference
                    self.enemy_sprites[enemy_name] = photo
                    self.sprite_images[enemy_name] = photo  # Prevent garbage collection
                    loaded_count += 1
                    
                except Exception as e:
                    print(f"Failed to load sprite for {enemy_name}: {e}")
                    failed_count += 1
            else:
                # Try alternate directions if south is missing
                for direction in ['west', 'east', 'north']:
                    alt_path = os.path.join(sprites_dir, folder_name, 'rotations', f'{direction}.png')
                    if os.path.exists(alt_path):
                        try:
                            img = Image.open(alt_path)
                            img = img.resize((90, 90), Image.LANCZOS)
                            photo = ImageTk.PhotoImage(img)
                            self.enemy_sprites[enemy_name] = photo
                            self.sprite_images[enemy_name] = photo
                            loaded_count += 1
                            break
                        except Exception as e:
                            continue
                else:
                    failed_count += 1
        
        print(f"Loaded {loaded_count} enemy sprites ({failed_count} failed)")
    
    def scale_font(self, base_size):
        """Calculate scaled font size based on current window size (15% larger)"""
        scaled_size = int(base_size * self.scale_factor * 1.15)
        # Ensure minimum readability
        return max(8, scaled_size)
    
    def scale_padding(self, base_padding):
        """Calculate scaled padding based on current window size"""
        return int(base_padding * self.scale_factor)
    
    def get_scaled_wraplength(self, base_length=600):
        """Calculate scaled wraplength for text widgets based on window width"""
        # Use 70% of current window width for wrapping, with a minimum
        current_width = self.root.winfo_width()
        if current_width > 1:
            # Use percentage of window width for better responsiveness
            calculated_width = int(current_width * 0.7)
            return max(calculated_width, 500)  # Minimum 500px
        # Fallback to scaled base length
        return int(base_length * self.scale_factor)
    
    def show_main_menu(self):
        """Show the main menu - delegates to MainMenuManager"""
        self.main_menu_manager.show_main_menu()
    
    # ========== UI STYLING HELPER METHODS ==========
    
    def create_styled_panel(self, parent, bg_type="panel", border_width=2, border_color="border_accent"):
        """Create a consistently styled panel frame with borders"""
        bg_color = self.current_colors.get(bg_type, self.current_colors["bg_panel"])
        border = self.current_colors.get(border_color, self.current_colors["border_accent"])
        
        frame = tk.Frame(parent, bg=bg_color, relief=tk.RIDGE, 
                        borderwidth=border_width, highlightbackground=border,
                        highlightthickness=1)
        return frame
    
    def create_styled_button(self, parent, text, command, style="primary", width=12, **kwargs):
        """Create a consistently styled button with hover effects
        
        Args:
            style: 'primary' (gold), 'secondary' (cyan), 'danger' (red), 'disabled' (gray)
        """
        style_map = {
            "primary": {
                "bg": self.current_colors["button_primary"],
                "fg": "#000000",
                "activebackground": self.current_colors["button_hover"],
                "font": ('Arial', 11, 'bold'),
                "relief": tk.RAISED,
                "borderwidth": 2,
                "pady": 10
            },
            "secondary": {
                "bg": self.current_colors["button_secondary"],
                "fg": "#000000",
                "activebackground": "#7fc5c5",
                "font": ('Arial', 11, 'bold'),
                "relief": tk.RAISED,
                "borderwidth": 2,
                "pady": 10
            },
            "danger": {
                "bg": self.current_colors["button_danger"],
                "fg": "#ffffff",
                "activebackground": "#e87470",
                "font": ('Arial', 11, 'bold'),
                "relief": tk.RAISED,
                "borderwidth": 2,
                "pady": 10
            },
            "disabled": {
                "bg": self.current_colors["button_disabled"],
                "fg": "#6a5a4a",
                "activebackground": self.current_colors["button_disabled"],
                "font": ('Arial', 11),
                "relief": tk.SUNKEN,
                "borderwidth": 1,
                "pady": 10,
                "state": tk.DISABLED
            }
        }
        
        config = style_map.get(style, style_map["primary"])
        config.update(kwargs)  # Allow overrides
        config["width"] = width
        
        button = tk.Button(parent, text=text, command=command, **config)
        return button
    
    def create_hp_bar(self, parent, current_hp, max_hp, width=200, height=20):
        """Create a visual HP bar with gradient colors"""
        canvas = tk.Canvas(parent, width=width, height=height, 
                          bg=self.current_colors["hp_bg"],
                          highlightbackground=self.current_colors["border_dark"],
                          highlightthickness=1)
        
        if max_hp > 0:
            hp_percent = current_hp / max_hp
            fill_width = int(width * hp_percent)
            
            # Choose color based on HP percentage
            if hp_percent > 0.6:
                fill_color = self.current_colors["hp_full"]
            elif hp_percent > 0.3:
                fill_color = self.current_colors["hp_mid"]
            else:
                fill_color = self.current_colors["hp_low"]
            
            # Draw HP bar
            if fill_width > 0:
                canvas.create_rectangle(2, 2, fill_width, height-2, 
                                       fill=fill_color, outline="")
            
            # Draw HP text overlay
            # Scale font size based on bar height
            font_size = max(9, min(12, int(height * 0.6)))
            canvas.create_text(width//2, height//2, 
                             text=f"{current_hp}/{max_hp}",
                             font=('Arial', font_size, 'bold'),
                             fill=self.current_colors["text_white"])
        
        return canvas
    
    def create_section_header(self, parent, text, icon="", font_size=12):
        """Create a styled section header with optional icon"""
        header_text = f"{icon} {text}" if icon else text
        label = tk.Label(parent, text=header_text, 
                        font=('Arial', font_size, 'bold'),
                        bg=self.current_colors["bg_header"],
                        fg=self.current_colors["text_gold"],
                        pady=8)
        return label
    
    def start_new_game(self):
        """Initialize a new game"""
        # Reset save slot tracking (will be set when user saves)
        self.current_save_slot = None
        
        # Clear debug log file for new game
        try:
            debug_log_file = os.path.join(self.saves_dir, 'adventure_log_new_game.txt')
            with open(debug_log_file, 'w', encoding='utf-8') as f:
                import datetime
                f.write(f"=== NEW GAME STARTED: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n\n")
        except:
            pass
        
        # Reset all stats (reduced health from 100 to 50)
        self.gold = 0
        self.health = 50
        self.max_health = 50
        self.floor = 0  # Start at 0 for tutorial area
        self.run_score = 0
        self.total_gold_earned = 0
        self.rooms_explored = 0
        self.enemies_killed = 0
        self.chests_opened = 0
        
        # Reset comprehensive stats
        self.stats = {
            "enemies_encountered": 0,
            "enemies_fled": 0,
            "enemies_defeated": 0,
            "mini_bosses_defeated": 0,
            "bosses_defeated": 0,
            "total_damage_dealt": 0,
            "total_damage_taken": 0,
            "highest_single_damage": 0,
            "critical_hits": 0,
            "gold_found": 0,
            "gold_spent": 0,
            "items_purchased": 0,
            "items_sold": 0,
            "items_found": 0,
            "items_used": 0,
            "potions_used": 0,
            "containers_searched": 0,
            "weapons_broken": 0,
            "armor_broken": 0,
            "weapons_repaired": 0,
            "armor_repaired": 0,
            "rooms_explored": 0,
            "times_rested": 0,
            "lore_found": {
                "Guard Journal": 0,
                "Quest Notice": 0,
                "Scrawled Note": 0,
                "Training Manual Page": 0,
                "Pressed Page": 0,
                "Surgeon's Note": 0,
                "Puzzle Note": 0,
                "Cracked Map Scrap": 0,
                "Star Chart": 0,
                "Prayer Strip": 0
            },
            "enemy_kills": {},
            "most_damaged_enemy": {"name": "", "damage": 0}
        }
        
        # Reset purchased upgrades tracker
        self.purchased_upgrades_this_floor = set()
        
        # Boss system tracking
        self.key_fragments_collected = 0
        self.mini_bosses_defeated = 0
        self.boss_defeated = False
        self.mini_bosses_spawned_this_floor = 0  # Track spawns per floor (max 3)
        self.boss_spawned_this_floor = False  # Track if boss has spawned on this floor
        self.special_rooms = {}  # Tracks {(x, y): 'mini_boss' or 'boss'}
        self.locked_rooms = set()  # Set of (x, y) tuples for locked rooms
        self.unlocked_rooms = set()  # Set of (x, y) tuples for rooms where keys were used
        self.is_boss_fight = False  # Flag for current combat
        self.rooms_explored_on_floor = 0  # Track rooms explored to trigger boss spawns
        self.next_mini_boss_at = random.randint(6, 10)  # Random target for first mini-boss
        self.next_boss_at = None  # Will be set on floor 5+
        
        # Reset inventory
        self.inventory = []
        self.max_inventory = 10
        
        # Reset equipment slots
        self.equipped_items = {
            "weapon": None,
            "armor": None,
            "accessory": None,
            "backpack": None
        }
        
        # Reset equipment durability
        self.equipment_durability = {}
        
        # Reset equipment floor levels
        self.equipment_floor_level = {}
        
        # Reset dice
        self.num_dice = 3
        self.dice_values = [0] * self.num_dice
        self.dice_locked = [False] * self.num_dice
        self.rolls_left = 3
        
        # Reset power-ups
        self.multiplier = 1.0
        self.damage_bonus = 0
        self.heal_bonus = 0
        self.reroll_bonus = 0
        self.crit_chance = 0.1
        self.armor = 0
        
        # Reset temporary combat buffs
        self.temp_combat_damage = 0
        self.temp_combat_crit = 0
        self.temp_combat_rerolls = 0
        
        # Reset adventure log
        self.adventure_log = []
        
        # Reset content tracking
        self.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
        self.temp_effects = {}
        self.temp_shield = 0
        self.shop_discount = 0.0
        self.combat_accuracy_penalty = 0.0
        
        # Reset lore item persistence
        self.used_lore_entries = {
            "guards_journal_pages": [],
            "quest_notices": [],
            "scrawled_notes": [],
            "training_manual_pages": [],
            "pressed_pages": [],
            "surgeons_notes": [],
            "puzzle_notes": [],
            "star_charts": [],
            "cracked_map_scraps": [],
            "old_letters": [],
            "prayer_strips": []
        }
        self.discovered_lore_items = []
        self.lore_item_assignments = {}
        
        # Rest cooldown tracking (can rest once per 3 rooms explored)
        self.rest_cooldown = 0
        self.rooms_since_rest = 0
        
        # Starter area tracking
        self.in_starter_area = True
        self.starter_chests_opened = []
        self.signs_read = []
        self.starter_rooms = set()  # Track first 3 room positions - no combat ever
        
        self.game_active = True
        self.show_starter_area()
    
    def start_new_floor(self):
        """Initialize a new floor"""
        return self.navigation_manager.start_new_floor()
    
    def setup_game_ui(self):
        """Setup the main game UI matching classic RPG style"""
        # Force window update to get accurate dimensions
        self.root.update_idletasks()
        
        # Calculate initial scale factor based on current window size
        current_width = self.root.winfo_width()
        current_height = self.root.winfo_height()
        if current_width > 1 and current_height > 1:  # Window has been sized
            width_scale = current_width / self.base_window_width
            height_scale = current_height / self.base_window_height
            self.scale_factor = min(width_scale, height_scale)
            self.scale_factor = max(0.8, min(self.scale_factor, 2.5))
        
        for widget in self.root.winfo_children():
            widget.destroy()
        
        self.game_frame = tk.Frame(self.root, bg=self.current_colors["bg_secondary"])
        self.game_frame.pack(fill=tk.BOTH, expand=True)
        
        # Main container with two columns
        main_container = tk.Frame(self.game_frame, bg=self.current_colors["bg_secondary"])
        main_container.pack(fill=tk.BOTH, expand=True)
        
        # Left side - Game area (no scrolling, fully responsive layout)
        left_frame = tk.Frame(main_container, bg=self.current_colors["bg_secondary"])
        left_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Right side - Minimap (fixed width, always fits in column)
        right_frame = tk.Frame(main_container, bg=self.current_colors["bg_primary"], relief=tk.RIDGE, borderwidth=2)
        right_frame.pack(side=tk.RIGHT, fill=tk.Y, padx=5, pady=5)
        
        # Build game UI - everything visible, no scrolling
        self._build_game_ui(left_frame)
        
        # Build minimap
        self._build_minimap(right_frame)
    
    def _build_game_ui(self, parent_frame):
        """Build the game UI elements - fully responsive layout"""
        # === HEADER with improved styling ===
        header = self.create_styled_panel(parent_frame, bg_type="bg_header", border_width=1, border_color="border_gold")
        header.pack(fill=tk.X, side=tk.TOP, padx=self.scale_padding(3), pady=self.scale_padding(2))
        
        # Header inner frame for padding
        header_inner = tk.Frame(header, bg=self.current_colors["bg_header"])
        header_inner.pack(fill=tk.X, padx=self.scale_padding(6), pady=self.scale_padding(3))
        
        tk.Label(header_inner, text="⚔ DICE DUNGEON EXPLORER ⚔", 
                font=('Georgia', self.scale_font(12), 'bold'),
                bg=self.current_colors["bg_header"], 
                fg=self.current_colors["text_gold"]).pack(side=tk.LEFT, padx=self.scale_padding(8))
        
        # Right side buttons
        btn_frame = tk.Frame(header_inner, bg=self.current_colors["bg_header"])
        btn_frame.pack(side=tk.RIGHT)
        
        # Dev mode toggle button - only show when dev mode is enabled
        self.dev_mode_button = tk.Button(btn_frame, text="⚙", command=self.toggle_dev_mode,
                 font=('Arial', self.scale_font(9)), bg='#333333', fg='#888888',
                 width=2, pady=self.scale_padding(2), relief=tk.FLAT)
        if self.dev_mode:
            self.dev_mode_button.pack(side=tk.LEFT, padx=self.scale_padding(2))
        
        tk.Button(btn_frame, text="☰", command=self.show_pause_menu,
                 font=('Arial', self.scale_font(10), 'bold'), 
                 bg=self.current_colors["button_secondary"], fg='#000000',
                 width=2, pady=self.scale_padding(2), relief=tk.RAISED, borderwidth=2).pack(side=tk.LEFT, padx=self.scale_padding(2))
        
        tk.Button(btn_frame, text="⚙", command=self.show_character_status,
                 font=('Arial', self.scale_font(10), 'bold'), 
                 bg=self.current_colors["text_purple"], fg='#ffffff',
                 width=2, pady=self.scale_padding(2), relief=tk.RAISED, borderwidth=2).pack(side=tk.LEFT, padx=self.scale_padding(2))
        
        tk.Button(btn_frame, text="?", command=self.show_keybindings,
                 font=('Arial', self.scale_font(10), 'bold'), 
                 bg=self.current_colors["button_secondary"], fg='#000000',
                 width=2, pady=self.scale_padding(2), relief=tk.RAISED, borderwidth=2).pack(side=tk.LEFT, padx=self.scale_padding(2))
        
        # === STATS BAR with HP bar and icons ===
        stats_frame = self.create_styled_panel(parent_frame, bg_type="bg_panel", border_width=1, border_color="border_accent")
        stats_frame.pack(fill=tk.X, side=tk.TOP, padx=self.scale_padding(3), pady=self.scale_padding(1))
        
        stats_inner = tk.Frame(stats_frame, bg=self.current_colors["bg_panel"])
        stats_inner.pack(fill=tk.X, padx=self.scale_padding(6), pady=self.scale_padding(4))
        
        # Left side - HP with visual bar
        left_stats = tk.Frame(stats_inner, bg=self.current_colors["bg_panel"])
        left_stats.pack(side=tk.LEFT)
        
        hp_container = tk.Frame(left_stats, bg=self.current_colors["bg_panel"])
        hp_container.pack(anchor='w', pady=2)
        
        tk.Label(hp_container, text=f"{self.icons['hp']} HEALTH",
                font=('Arial', self.scale_font(9), 'bold'), 
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_red"]).pack(side=tk.LEFT, padx=(0, 8))
        
        # HP bar (will be created and stored as attribute)
        self.hp_bar = self.create_hp_bar(hp_container, self.health, self.max_health, 
                                         width=int(180 * self.scale_factor), 
                                         height=int(18 * self.scale_factor))
        self.hp_bar.pack(side=tk.LEFT)
        
        # Gold with icon
        gold_container = tk.Frame(left_stats, bg=self.current_colors["bg_panel"])
        gold_container.pack(anchor='w', pady=2)
        
        tk.Label(gold_container, text=f"{self.icons['gold']}",
                font=('Arial', self.scale_font(12)), 
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_gold"]).pack(side=tk.LEFT)
        
        self.gold_label = tk.Label(gold_container, text=f" Gold: {self.gold}",
                                   font=('Arial', self.scale_font(11), 'bold'), 
                                   bg=self.current_colors["bg_panel"], 
                                   fg=self.current_colors["text_gold"])
        self.gold_label.pack(side=tk.LEFT)
        
        # Right side - Floor & Progress
        right_stats = tk.Frame(stats_inner, bg=self.current_colors["bg_panel"])
        right_stats.pack(side=tk.RIGHT)
        
        floor_container = tk.Frame(right_stats, bg=self.current_colors["bg_panel"])
        floor_container.pack(anchor='e', pady=2)
        
        tk.Label(floor_container, text=f"{self.icons['floor']}",
                font=('Arial', self.scale_font(12)), 
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_cyan"]).pack(side=tk.LEFT)
        
        self.floor_label = tk.Label(floor_container, text=f" FLOOR {self.floor}",
                                    font=('Arial', self.scale_font(12), 'bold'), 
                                    bg=self.current_colors["bg_panel"], 
                                    fg=self.current_colors["text_cyan"])
        self.floor_label.pack(side=tk.LEFT)
        
        # Dev mode indicator
        self.dev_indicator = tk.Label(floor_container, text="",
                                     font=('Arial', self.scale_font(9), 'bold'),
                                     bg=self.current_colors["bg_panel"],
                                     fg='#9b59b6')
        self.dev_indicator.pack(side=tk.LEFT, padx=5)
        if self.dev_mode:
            self.dev_indicator.config(text="[DEV]")
        
        progress_container = tk.Frame(right_stats, bg=self.current_colors["bg_panel"])
        progress_container.pack(anchor='e', pady=2)
        
        self.progress_label = tk.Label(progress_container, text=f"Rooms Explored: {self.rooms_explored}",
                                      font=('Arial', self.scale_font(10)), 
                                      bg=self.current_colors["bg_panel"], 
                                      fg=self.current_colors["text_secondary"])
        self.progress_label.pack()
        
        # === ROOM DESCRIPTION PANEL (compact) ===
        self.room_frame = self.create_styled_panel(parent_frame, bg_type="bg_room", border_width=2, border_color="border_gold")
        self.room_frame.pack(fill=tk.X, side=tk.TOP, padx=self.scale_padding(3), pady=(self.scale_padding(1), self.scale_padding(1)))
        
        room_inner = tk.Frame(self.room_frame, bg=self.current_colors["bg_room"])
        room_inner.pack(fill=tk.X, padx=self.scale_padding(8), pady=self.scale_padding(3))
        
        # Room title
        self.room_title = tk.Label(room_inner, text="", 
                                   font=('Georgia', self.scale_font(12), 'bold'),
                                   bg=self.current_colors["bg_room"], 
                                   fg=self.current_colors["text_gold"], 
                                   pady=self.scale_padding(1))
        self.room_title.pack()
        
        # Decorative separator
        separator = tk.Frame(room_inner, height=1, bg=self.current_colors["border_gold"])
        separator.pack(fill=tk.X, pady=self.scale_padding(1))
        
        # Room description
        self.room_desc = tk.Label(room_inner, text="", 
                                  wraplength=self.get_scaled_wraplength(600),
                                  font=('Georgia', self.scale_font(9), 'italic'), 
                                  bg=self.current_colors["bg_room"], 
                                  fg=self.current_colors["text_light"],
                                  justify=tk.LEFT, 
                                  pady=self.scale_padding(1))
        self.room_desc.pack()
        
        # === ACTION PANEL - Player VS Enemy ===
        self.action_panel = tk.Frame(parent_frame, bg=self.current_colors["bg_panel"])
        self.action_panel.pack(fill=tk.X, side=tk.TOP, padx=self.scale_padding(3), pady=self.scale_padding(2))
        
        action_inner = tk.Frame(self.action_panel, bg=self.current_colors["bg_panel"])
        action_inner.pack(fill=tk.X, padx=self.scale_padding(8), pady=self.scale_padding(6))
        
        # Left: Player sub-frame
        player_frame = tk.Frame(action_inner, bg=self.current_colors["bg_panel"], width=140)
        player_frame.pack(side=tk.LEFT, fill=tk.Y)
        player_frame.pack_propagate(False)
        
        tk.Label(player_frame, text="Player", 
                font=('Arial', self.scale_font(9), 'bold'),
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_cyan"]).pack(anchor='w', pady=(0, 4))
        
        # Player sprite placeholder - larger space for future sprite
        self.player_sprite_box = tk.Frame(player_frame, bg='#1a1410', relief=tk.SUNKEN, borderwidth=1, height=90, width=90)
        self.player_sprite_box.pack(anchor='w', pady=(4, 0))
        self.player_sprite_box.pack_propagate(False)
        self.player_sprite_label = tk.Label(self.player_sprite_box, text="Player\nSprite", font=('Arial', 7), 
                bg='#1a1410', fg='#555555')
        self.player_sprite_label.place(relx=0.5, rely=0.5, anchor='center')
        
        # Center: Dice section container (hidden until combat)
        vs_frame = tk.Frame(action_inner, bg=self.current_colors["bg_panel"])
        vs_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # === DICE AND COMBAT CONTROLS (in center of action panel, hidden when not in combat) ===
        self.dice_section = tk.Frame(vs_frame, bg=self.current_colors["bg_panel"])
        # Don't pack initially - will be shown during combat
        
        # Rolls remaining label
        self.rolls_label = tk.Label(self.dice_section, text=f"Rolls Remaining: {self.rolls_left}/{3 + self.reroll_bonus}",
                                    font=('Arial', self.scale_font(10), 'bold'),
                                    bg=self.current_colors["bg_panel"],
                                    fg=self.current_colors["text_cyan"])
        self.rolls_label.pack(pady=self.scale_padding(2))
        
        # Damage preview label (shows potential damage after rolling)
        self.damage_preview_label = tk.Label(self.dice_section, text="",
                                            font=('Arial', self.scale_font(9)),
                                            bg=self.current_colors["bg_panel"],
                                            fg=self.current_colors["text_gold"])
        self.damage_preview_label.pack(pady=self.scale_padding(1))
        
        # Dice row
        self.dice_frame = tk.Frame(self.dice_section, bg=self.current_colors["bg_panel"])
        self.dice_frame.pack(pady=self.scale_padding(2))
        
        # Combat buttons row
        self.combat_buttons_frame = tk.Frame(self.dice_section, bg=self.current_colors["bg_panel"])
        self.combat_buttons_frame.pack(pady=self.scale_padding(2))
        
        # Right: Enemy sub-frame
        self.enemy_column = tk.Frame(action_inner, bg=self.current_colors["bg_panel"], width=160)
        self.enemy_column.pack(side=tk.RIGHT, fill=tk.Y)
        self.enemy_column.pack_propagate(False)
        
        self.action_panel_enemy_label = tk.Label(self.enemy_column, text="---", 
                font=('Arial', self.scale_font(9), 'bold'),
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_red"])
        self.action_panel_enemy_label.pack(anchor='e')
        
        self.enemy_hp_frame = tk.Frame(self.enemy_column, bg=self.current_colors["bg_panel"])
        self.enemy_hp_frame.pack(anchor='e', pady=(2, 2))
        self.action_panel_enemy_hp = None
        
        # Enemy sprite and dice container - side by side
        self.enemy_sprite_dice_container = tk.Frame(self.enemy_column, bg=self.current_colors["bg_panel"])
        self.enemy_sprite_dice_container.pack(anchor='e', pady=(4, 0))
        
        # Enemy sprite placeholder
        self.enemy_sprite_area = tk.Frame(self.enemy_sprite_dice_container, bg='#1a1410', relief=tk.SUNKEN, borderwidth=1, height=90, width=90)
        self.enemy_sprite_area.pack(side=tk.RIGHT)
        
        # Enemy dice display - to the left of sprite (pack AFTER sprite so it appears to the left)
        self.enemy_dice_frame = tk.Frame(self.enemy_sprite_dice_container, bg=self.current_colors["bg_panel"])
        self.enemy_dice_canvases = []
        self.enemy_dice_values = []
        # Pack to right (after sprite) but don't show initially
        self.enemy_dice_frame.pack(side=tk.RIGHT, padx=(0, 4))
        self.enemy_dice_frame.pack_forget()  # Hidden initially
        self.enemy_sprite_area.pack_propagate(False)
        self.enemy_sprite_label = tk.Label(self.enemy_sprite_area, text="Enemy\nSprite", font=('Arial', 7), 
                                           bg='#1a1410', fg='#555555')
        self.enemy_sprite_label.place(relx=0.5, rely=0.5, anchor='center')
        # Hide enemy area initially
        self.enemy_sprite_area.pack_forget()
        
        # === ACTION BUTTONS BAR (no movement controls) ===
        actions_bar = tk.Frame(parent_frame, bg=self.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=1)
        actions_bar.pack(side=tk.TOP, fill=tk.X, padx=self.scale_padding(3), pady=(0, self.scale_padding(2)))
        
        actions_inner = tk.Frame(actions_bar, bg=self.current_colors["bg_panel"])
        actions_inner.pack(fill=tk.X, padx=self.scale_padding(6), pady=self.scale_padding(3))
        
        # Action buttons (Rest, Inventory, Store) - centered
        self.action_buttons_strip = tk.Frame(actions_inner, bg=self.current_colors["bg_panel"])
        self.action_buttons_strip.pack(expand=True)
        
        # === ADVENTURE LOG (expanded) ===
        log_outer = tk.Frame(parent_frame, bg=self.current_colors["bg_secondary"])
        log_outer.pack(fill=tk.BOTH, expand=True, side=tk.BOTTOM, padx=0, pady=self.scale_padding(2))
        
        # Log header
        log_header = self.create_section_header(log_outer, "ADVENTURE LOG", icon="", font_size=11)
        log_header.config(bg=self.current_colors["bg_secondary"])
        log_header.pack(pady=(4, 2), anchor='w', padx=8)
        
        # Log frame
        log_frame = self.create_styled_panel(log_outer, bg_type="bg_log", border_width=2, border_color="border_dark")
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        # Text widget
        self.log_text = tk.Text(log_frame, 
                               bg=self.current_colors["bg_log"], 
                               fg=self.current_colors["text_primary"],
                               font=('Consolas', self.scale_font(10)), 
                               wrap=tk.WORD, 
                               state=tk.DISABLED,
                               padx=8,
                               pady=8,
                               spacing1=2,
                               spacing2=0,
                               spacing3=4,
                               relief=tk.FLAT,
                               borderwidth=0)
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)
        
        # Typewriter effect variables
        self.typewriter_queue = []
        self.typewriter_active = False
        
        # Configure text tags
        self.log_text.tag_config('player', foreground=self.current_colors["text_cyan"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('enemy', foreground=self.current_colors["text_red"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('system', foreground=self.current_colors["text_gold"])
        self.log_text.tag_config('crit', foreground=self.current_colors["text_magenta"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('loot', foreground=self.current_colors["text_purple"])
        self.log_text.tag_config('success', foreground=self.current_colors["text_green"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('damage_dealt', foreground=self.current_colors["text_orange"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('damage_taken', foreground=self.current_colors["text_red"])
        self.log_text.tag_config('healing', foreground=self.current_colors["text_green"])
        self.log_text.tag_config('gold_gained', foreground=self.current_colors["text_gold"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('warning', foreground=self.current_colors["text_warning"], font=('Consolas', self.scale_font(10), 'bold'))
        self.log_text.tag_config('fire', foreground='#ff4500', font=('Consolas', self.scale_font(10), 'bold'))  # Fiery orange-red
        self.log_text.tag_config('burn', foreground='#ff6347', font=('Consolas', self.scale_font(10), 'bold'))  # Tomato red
    
    def _build_minimap(self, parent):
        """Build the minimap display with enhanced styling"""
        # Minimap header - smaller and inline with zoom
        header_frame = tk.Frame(parent, bg=self.current_colors["bg_minimap"])
        header_frame.pack(pady=self.scale_padding(4), fill=tk.X, padx=4)
        
        tk.Label(header_frame, text="◎ Map", font=('Arial', self.scale_font(9), 'bold'),
                bg=self.current_colors["bg_minimap"],
                fg=self.current_colors["text_gold"]).pack(side=tk.LEFT)
        
        # Zoom controls inline with header - much smaller
        zoom_frame = tk.Frame(header_frame, bg=self.current_colors["bg_minimap"])
        zoom_frame.pack(side=tk.RIGHT)
        
        tk.Button(zoom_frame, text="-", command=self.zoom_out_minimap,
                 font=('Arial', self.scale_font(8), 'bold'), 
                 bg=self.current_colors["bg_panel"], 
                 fg=self.current_colors["text_primary"],
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack(side=tk.LEFT, padx=1)
        
        self.zoom_label = tk.Label(zoom_frame, text="100%", font=('Arial', self.scale_font(7)),
                                   bg=self.current_colors["bg_minimap"], 
                                   fg=self.current_colors["text_gold"], width=4)
        self.zoom_label.pack(side=tk.LEFT, padx=2)
        
        tk.Button(zoom_frame, text="+", command=self.zoom_in_minimap,
                 font=('Arial', self.scale_font(8), 'bold'), 
                 bg=self.current_colors["bg_panel"], 
                 fg=self.current_colors["text_primary"],
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack(side=tk.LEFT, padx=1)
        
        # Pan controls - much more compact
        pan_container = tk.Frame(parent, bg=self.current_colors["bg_minimap"])
        pan_container.pack(pady=self.scale_padding(2))
        
        # Pan controls - Top row (North)
        pan_frame_n = tk.Frame(pan_container, bg=self.current_colors["bg_minimap"])
        pan_frame_n.pack(pady=0)
        
        tk.Button(pan_frame_n, text="↑", command=self.pan_minimap_north,
                 font=('Arial', self.scale_font(8)), 
                 bg=self.current_colors["bg_panel"], 
                 fg=self.current_colors["text_primary"],
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack()
        
        # Pan controls - Middle row (West, Center, East)
        pan_frame_m = tk.Frame(pan_container, bg=self.current_colors["bg_minimap"])
        pan_frame_m.pack(pady=0)
        
        tk.Button(pan_frame_m, text="←", command=self.pan_minimap_west,
                 font=('Arial', self.scale_font(8)), 
                 bg=self.current_colors["bg_panel"], 
                 fg=self.current_colors["text_primary"],
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack(side=tk.LEFT, padx=1)
        
        tk.Button(pan_frame_m, text="⊙", command=self.center_minimap,
                 font=('Arial', self.scale_font(8)), 
                 bg=self.current_colors["button_primary"], 
                 fg='#000000',
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack(side=tk.LEFT, padx=1)
        
        tk.Button(pan_frame_m, text="→", command=self.pan_minimap_east,
                 font=('Arial', self.scale_font(8)), 
                 bg=self.current_colors["bg_panel"], 
                 fg=self.current_colors["text_primary"],
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack(side=tk.LEFT, padx=1)
        
        # Pan controls - Bottom row (South)
        pan_frame_s = tk.Frame(pan_container, bg=self.current_colors["bg_minimap"])
        pan_frame_s.pack(pady=0)
        
        tk.Button(pan_frame_s, text="↓", command=self.pan_minimap_south,
                 font=('Arial', self.scale_font(8)), 
                 bg=self.current_colors["bg_panel"], 
                 fg=self.current_colors["text_primary"],
                 width=2, height=1, relief=tk.RAISED, borderwidth=1).pack()
        
        # Canvas with styled border
        self.minimap_canvas = tk.Canvas(parent, width=180, height=180,
                                        bg='#0a0604',
                                        highlightthickness=2,
                                        highlightbackground=self.current_colors["border_gold"],
                                        relief=tk.SUNKEN)
        self.minimap_canvas.pack(pady=6, padx=8)
        
        # Bind mouse wheel for zoom
        self.minimap_canvas.bind("<MouseWheel>", self.on_minimap_scroll)
        
        # === LEGEND with improved styling ===
        legend_frame = self.create_styled_panel(parent, bg_type="bg_panel", border_width=1, border_color="border_dark")
        legend_frame.pack(pady=3, padx=8, fill=tk.X)
        
        legend_inner = tk.Frame(legend_frame, bg=self.current_colors["bg_panel"])
        legend_inner.pack(padx=6, pady=4)
        
        tk.Label(legend_inner, text="MAP LEGEND", font=('Arial', 9, 'bold'),
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_gold"]).pack(pady=(0, 2))
        
        # Color legend with muted colors
        tk.Label(legend_inner, text="● You", font=('Arial', 8),
                bg=self.current_colors["bg_panel"], 
                fg='#d4af37').pack(anchor='w', pady=0)
        tk.Label(legend_inner, text="● Visited", font=('Arial', 8),
                bg=self.current_colors["bg_panel"], 
                fg='#555555').pack(anchor='w', pady=0)
        
        # Separator
        sep = tk.Frame(legend_inner, height=1, bg=self.current_colors["border_dark"])
        sep.pack(fill=tk.X, pady=2)
        
        # Symbol legend
        tk.Label(legend_inner, text="∩ = Stairs", font=('Arial', 8),
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_secondary"]).pack(anchor='w', pady=0)
        tk.Label(legend_inner, text="$ = Store", font=('Arial', 8),
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_secondary"]).pack(anchor='w', pady=0)
        tk.Label(legend_inner, text="💀 = Boss", font=('Arial', 8),
                bg=self.current_colors["bg_panel"], 
                fg=self.current_colors["text_secondary"]).pack(anchor='w', pady=0)
        
        # === MOVEMENT CONTROLS (at bottom of minimap column) ===
        movement_inner = tk.Frame(parent, bg=self.current_colors["bg_primary"])
        movement_inner.pack(pady=3, padx=8)
        
        tk.Label(movement_inner, text="MOVE", font=('Arial', 9, 'bold'),
                bg=self.current_colors["bg_primary"], 
                fg=self.current_colors["text_gold"]).pack(pady=(0, 2))
        
        # North button
        move_n_frame = tk.Frame(movement_inner, bg=self.current_colors["bg_primary"])
        move_n_frame.pack(pady=1)
        
        # Store movement buttons for later state updates
        self.movement_buttons = {}
        
        self.movement_buttons['N'] = tk.Button(move_n_frame, text="↑",
                       command=lambda: self.explore_direction('N'),
                       font=('Arial', self.scale_font(9), 'bold'), 
                       bg=self.current_colors["button_primary"], 
                       fg='#000000',
                       width=2, height=1,
                       relief=tk.RAISED,
                       borderwidth=1)
        self.movement_buttons['N'].pack()
        
        # West and East row
        move_m_frame = tk.Frame(movement_inner, bg=self.current_colors["bg_primary"])
        move_m_frame.pack(pady=1)
        
        self.movement_buttons['W'] = tk.Button(move_m_frame, text="←",
                       command=lambda: self.explore_direction('W'),
                       font=('Arial', self.scale_font(9), 'bold'), 
                       bg=self.current_colors["button_primary"], 
                       fg='#000000',
                       width=2, height=1,
                       relief=tk.RAISED,
                       borderwidth=1)
        self.movement_buttons['W'].pack(side=tk.LEFT, padx=1)
        
        # Empty space in center - same width as buttons for even spacing
        tk.Label(move_m_frame, text="", width=2,
                bg=self.current_colors["bg_primary"]).pack(side=tk.LEFT, padx=1)
        
        self.movement_buttons['E'] = tk.Button(move_m_frame, text="→",
                       command=lambda: self.explore_direction('E'),
                       font=('Arial', self.scale_font(9), 'bold'), 
                       bg=self.current_colors["button_primary"], 
                       fg='#000000',
                       width=2, height=1,
                       relief=tk.RAISED,
                       borderwidth=1)
        self.movement_buttons['E'].pack(side=tk.LEFT, padx=1)
        
        # South button
        move_s_frame = tk.Frame(movement_inner, bg=self.current_colors["bg_primary"])
        move_s_frame.pack(pady=1)
        
        self.movement_buttons['S'] = tk.Button(move_s_frame, text="↓",
                       command=lambda: self.explore_direction('S'),
                       font=('Arial', self.scale_font(9), 'bold'), 
                       bg=self.current_colors["button_primary"], 
                       fg='#000000',
                       width=2, height=1,
                       relief=tk.RAISED,
                       borderwidth=1)
        self.movement_buttons['S'].pack()
        
        tk.Label(movement_inner, text="(or WASD/Arrows)", 
                font=('Arial', self.scale_font(7), 'italic'),
                bg=self.current_colors["bg_primary"], 
                fg=self.current_colors["text_secondary"]).pack(pady=(2, 0))
        
        self.draw_minimap()
    
    def pan_minimap_north(self):
        """Pan minimap north (up)"""
        self.minimap_pan_y += 2
        self.draw_minimap()
    
    def pan_minimap_south(self):
        """Pan minimap south (down)"""
        self.minimap_pan_y -= 2
        self.draw_minimap()
    
    def pan_minimap_east(self):
        """Pan minimap east (right)"""
        self.minimap_pan_x += 2
        self.draw_minimap()
    
    def pan_minimap_west(self):
        """Pan minimap west (left)"""
        self.minimap_pan_x -= 2
        self.draw_minimap()
    
    def center_minimap(self):
        """Center minimap on player position"""
        self.minimap_pan_x = 0
        self.minimap_pan_y = 0
        self.draw_minimap()
    
    def zoom_in_minimap(self):
        """Zoom in on the minimap"""
        if self.minimap_zoom < 3.0:
            self.minimap_zoom = min(3.0, self.minimap_zoom + 0.25)
            self.zoom_label.config(text=f"{int(self.minimap_zoom * 100)}%")
            self.draw_minimap()
    
    def zoom_out_minimap(self):
        """Zoom out on the minimap"""
        if self.minimap_zoom > 0.25:
            self.minimap_zoom = max(0.25, self.minimap_zoom - 0.25)
            self.zoom_label.config(text=f"{int(self.minimap_zoom * 100)}%")
            self.draw_minimap()
    
    def on_minimap_scroll(self, event):
        """Handle mouse wheel scroll on minimap"""
        if event.delta > 0:
            self.zoom_in_minimap()
        else:
            self.zoom_out_minimap()
    
    def draw_minimap(self):
        """Draw the minimap showing explored rooms"""
        if not self.minimap_canvas:
            return
        
        self.minimap_canvas.delete("all")
        
        if not self.dungeon:
            return
        
        # Calculate bounds
        min_x = min(pos[0] for pos in self.dungeon.keys())
        max_x = max(pos[0] for pos in self.dungeon.keys())
        min_y = min(pos[1] for pos in self.dungeon.keys())
        max_y = max(pos[1] for pos in self.dungeon.keys())
        
        # Base cell size adjusted by zoom
        base_cell_size = 20
        cell_size = base_cell_size * self.minimap_zoom
        
        # Canvas center
        canvas_center_x = 90
        canvas_center_y = 90
        
        # Center point is player position plus pan offset
        center_x = self.current_pos[0] + self.minimap_pan_x
        center_y = self.current_pos[1] + self.minimap_pan_y
        
        # Draw rooms
        for pos, room in self.dungeon.items():
            # Calculate position relative to center point
            rel_x = pos[0] - center_x
            rel_y = pos[1] - center_y
            
            x = canvas_center_x + (rel_x * cell_size)
            y = canvas_center_y - (rel_y * cell_size)
            
            # Skip if outside canvas bounds
            if x < -20 or x > 200 or y < -20 or y > 200:
                continue
            
            # Choose color
            if pos == self.current_pos:
                color = '#ffd700'  # Yellow for current
            elif room.visited:
                color = '#4a4a4a'  # Medium gray for visited (better icon visibility)
            else:
                color = '#666666'  # Gray for unvisited
            
            # Cell half-size - keep at 0.45 to prevent overlapping
            half_size = max(6, min(18, cell_size * 0.45))
            
            # Draw room square
            self.minimap_canvas.create_rectangle(
                x - half_size, y - half_size, x + half_size, y + half_size,
                fill=color, outline='#ffffff', width=1
            )
            
            # Draw connections for open paths
            for direction, connected_pos in [('N', (pos[0], pos[1]+1)),
                                            ('S', (pos[0], pos[1]-1)),
                                            ('E', (pos[0]+1, pos[1])),
                                            ('W', (pos[0]-1, pos[1]))]:
                # Check if this path is blocked
                is_blocked = direction in room.blocked_exits
                
                if connected_pos in self.dungeon and not is_blocked:
                    # Calculate connected room position relative to center point
                    rel_x2 = connected_pos[0] - center_x
                    rel_y2 = connected_pos[1] - center_y
                    
                    x2 = canvas_center_x + (rel_x2 * cell_size)
                    y2 = canvas_center_y - (rel_y2 * cell_size)
                    
                    # Skip if outside canvas bounds
                    if x2 < -20 or x2 > 200 or y2 < -20 or y2 > 200:
                        continue
                    
                    # Draw thin, subtle line for open path
                    self.minimap_canvas.create_line(
                        x, y, x2, y2,
                        fill='#3a3a3a', width=1, dash=(2, 3)
                    )
            
            # Draw red bars at room edges for blocked exits
            for direction in room.blocked_exits:
                bar_length = half_size * 1.5
                bar_width = 3
                
                if direction == 'N':
                    # Bar at top edge
                    self.minimap_canvas.create_line(
                        x - bar_length, y - half_size,
                        x + bar_length, y - half_size,
                        fill='#ff3333', width=bar_width
                    )
                elif direction == 'S':
                    # Bar at bottom edge
                    self.minimap_canvas.create_line(
                        x - bar_length, y + half_size,
                        x + bar_length, y + half_size,
                        fill='#ff3333', width=bar_width
                    )
                elif direction == 'E':
                    # Bar at right edge
                    self.minimap_canvas.create_line(
                        x + half_size, y - bar_length,
                        x + half_size, y + bar_length,
                        fill='#ff3333', width=bar_width
                    )
                elif direction == 'W':
                    # Bar at left edge
                    self.minimap_canvas.create_line(
                        x - half_size, y - bar_length,
                        x - half_size, y + bar_length,
                        fill='#ff3333', width=bar_width
                    )
            
            # Mark stairs
            if room.has_stairs and self.minimap_zoom >= 0.5:
                self.minimap_canvas.create_text(
                    x, y, text="∩", fill='#00ff00',
                    font=('Arial', max(10, int(14 * self.minimap_zoom)), 'bold')
                )
            
            # Mark mini-boss rooms
            if hasattr(room, 'is_mini_boss_room') and room.is_mini_boss_room and self.minimap_zoom >= 0.5:
                # Show lock if not yet unlocked
                if pos in self.special_rooms and pos not in self.unlocked_rooms:
                    self.minimap_canvas.create_text(
                        x, y, text="💀", fill='#ff3333',
                        font=('Arial', max(10, int(16 * self.minimap_zoom)), 'bold')
                    )
                elif room.visited:
                    # Show defeated indicator if boss was defeated
                    if room.enemies_defeated:
                        self.minimap_canvas.create_text(
                            x, y, text="✓", fill='#00ff00',
                            font=('Arial', max(10, int(14 * self.minimap_zoom)), 'bold')
                        )
                    else:
                        self.minimap_canvas.create_text(
                            x, y, text="💀", fill='#ff0000',
                            font=('Arial', max(10, int(16 * self.minimap_zoom)), 'bold')
                        )
            
            # Mark main boss room
            if hasattr(room, 'is_boss_room') and room.is_boss_room and self.minimap_zoom >= 0.5:
                # Show lock if not yet unlocked
                if pos in self.special_rooms and pos not in self.unlocked_rooms:
                    self.minimap_canvas.create_text(
                        x, y, text="💀", fill='#ff3333',
                        font=('Arial', max(10, int(14 * self.minimap_zoom)), 'bold')
                    )
                elif room.visited:
                    # Show defeated indicator if boss was defeated
                    if room.enemies_defeated:
                        self.minimap_canvas.create_text(
                            x, y, text="✓", fill='#00ff00',
                            font=('Arial', max(10, int(14 * self.minimap_zoom)), 'bold')
                        )
                    else:
                        # Use skull for boss room
                        self.minimap_canvas.create_text(
                            x, y, text="💀", fill='#ff0000',
                            font=('Arial', max(10, int(16 * self.minimap_zoom)), 'bold')
                        )
            
            # Mark store
            if self.store_found and pos == self.store_position and self.minimap_zoom >= 0.5:
                self.minimap_canvas.create_text(
                    x, y, text="$", fill='#00ff00',
                    font=('Arial', max(10, int(14 * self.minimap_zoom)), 'bold')
                )
    
    def enter_room(self, room, is_first=False, skip_effects=False, new_pos=None):
        """Enter a room and process events"""
        return self.navigation_manager.enter_room(room, is_first, skip_effects, new_pos)
    
    def _complete_room_entry(self, room, is_first, skip_effects, new_pos=None):
        """Complete the room entry after key checks"""
        return self.navigation_manager._complete_room_entry(room, is_first, skip_effects, new_pos)
    
    def _continue_room_entry(self, room, skip_effects, is_first_visit):
        """Continue room entry after key decisions"""
        return self.navigation_manager._continue_room_entry(room, skip_effects, is_first_visit)
    
    def show_exploration_options(self):
        """Show options for exploring - new layout"""
        return self.navigation_manager.show_exploration_options()
    
    def handle_key_movement(self, direction):
        """Handle keyboard-based movement - only works when not in combat"""
        if not self.in_combat:
            self.explore_direction(direction)
    
    def explore_direction(self, direction):
        """Move in a direction"""
        return self.navigation_manager.explore_direction(direction)
    
    def get_adjacent_pos(self, direction):
        """Get position in direction"""
        return self.navigation_manager.get_adjacent_pos(direction)
    

    def trigger_combat(self, enemy_name, is_mini_boss=False, is_boss=False):
        """Delegate to CombatManager"""
        return self.combat_manager.trigger_combat(enemy_name, is_mini_boss, is_boss)
    
    def spawn_additional_enemy(self, spawner_enemy, spawn_type, hp_mult, dice_count):
        """Delegate to CombatManager"""
        return self.combat_manager.spawn_additional_enemy(spawner_enemy, spawn_type, hp_mult, dice_count)
    
    def split_enemy(self, enemy, split_type, split_count, hp_percent, dice_modifier=0):
        """Delegate to CombatManager"""
        return self.combat_manager.split_enemy(enemy, split_type, split_count, hp_percent, dice_modifier)
    
    def update_enemy_display(self):
        """Delegate to CombatManager"""
        return self.combat_manager.update_enemy_display()
    
    def check_spawn_conditions(self):
        """Delegate to CombatManager"""
        return self.combat_manager.check_spawn_conditions()
    
    def check_split_conditions(self, enemy):
        """Delegate to CombatManager"""
        return self.combat_manager.check_split_conditions(enemy)
    
    def select_target(self, target_index):
        """Delegate to CombatManager"""
        return self.combat_manager.select_target(target_index)
    
    def process_status_effects(self):
        """Delegate to CombatManager"""
        return self.combat_manager.process_status_effects()
    
    def start_combat_turn(self):
        """Delegate to CombatManager"""
        return self.combat_manager.start_combat_turn()
    
    def use_mystic_ring(self):
        """Delegate to CombatManager"""
        return self.combat_manager.use_mystic_ring()
    
    def use_fire_potion(self, target_index=None):
        """Delegate to CombatManager"""
        return self.combat_manager.use_fire_potion(target_index)
    
    def show_fire_potion_target_selection(self, item_idx):
        """Show dialog to select which enemy to target with Fire Potion"""
        if not self.enemies:
            self.log("No enemies to target!", 'system')
            return
        
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        # Responsive sizing
        dialog_width, dialog_height = self.get_responsive_dialog_size(400, 300)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Bind Escape key to close dialog
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        
        # Title
        title_label = tk.Label(self.dialog_frame, text="🔥 SELECT TARGET 🔥", 
                              font=('Arial', 14, 'bold'),
                              bg=self.current_colors["bg_primary"], 
                              fg=self.current_colors["text_gold"])
        title_label.pack(pady=10)
        
        tk.Label(self.dialog_frame, text="Choose which enemy to throw the Fire Potion at:",
                font=('Arial', 10),
                bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_light"]).pack(pady=5)
        
        # Enemy list
        list_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_secondary"])
        list_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        for i, enemy in enumerate(self.enemies):
            enemy_frame = tk.Frame(list_frame, bg=self.current_colors["bg_dark"])
            enemy_frame.pack(fill=tk.X, padx=5, pady=5)
            
            # Enemy info
            info_frame = tk.Frame(enemy_frame, bg=self.current_colors["bg_dark"])
            info_frame.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=10, pady=5)
            
            tk.Label(info_frame, text=enemy['name'], font=('Arial', 11, 'bold'),
                    bg=self.current_colors["bg_dark"], fg=self.current_colors["text_light"]).pack(anchor='w')
            tk.Label(info_frame, text=f"HP: {enemy['health']}/{enemy['max_health']}", font=('Arial', 9),
                    bg=self.current_colors["bg_dark"], fg=self.current_colors["text_secondary"]).pack(anchor='w')
            
            # Target button
            def make_target_func(target_idx, inv_idx):
                def target_enemy():
                    self.close_dialog()
                    # Remove item from inventory
                    if inv_idx < len(self.inventory):
                        self.inventory.pop(inv_idx)
                    # Use fire potion on target
                    self.use_fire_potion(target_idx)
                return target_enemy
            
            tk.Button(enemy_frame, text="Target", command=make_target_func(i, item_idx),
                     bg='#e74c3c', fg='#ffffff', font=('Arial', 10, 'bold'),
                     width=10).pack(side=tk.RIGHT, padx=10)
        
        # Cancel button
        tk.Button(self.dialog_frame, text="Cancel", command=self.close_dialog,
                 bg=self.current_colors["button_secondary"], fg='#ffffff',
                 font=('Arial', 10, 'bold'), width=15).pack(pady=10)
    
    def _disable_combat_controls(self):
        """Delegate to CombatManager"""
        return self.combat_manager._disable_combat_controls()
    
    def _animate_enemy_damage(self, damage):
        """Delegate to CombatManager"""
        return self.combat_manager._animate_enemy_damage(damage)
    
    def _play_enemy_animation(self, enemy_folder, animation_name, direction, num_frames, frame_delay_ms):
        """Delegate to CombatManager"""
        return self.combat_manager._play_enemy_animation(enemy_folder, animation_name, direction, num_frames, frame_delay_ms)
    
    def _play_animation_frames(self, frames, current_frame, delay_ms):
        """Delegate to CombatManager"""
        return self.combat_manager._play_animation_frames(frames, current_frame, delay_ms)
    
    def _animate_player_damage(self, damage):
        """Delegate to CombatManager"""
        return self.combat_manager._animate_player_damage(damage)
    
    def _apply_player_damage(self, damage):
        """Delegate to CombatManager"""
        return self.combat_manager._apply_player_damage(damage)
    
    def _play_enemy_defeat_animation(self, target_index):
        """Delegate to CombatManager"""
        return self.combat_manager._play_enemy_defeat_animation(target_index)
    
    def _play_enemy_defeat_animation_legacy(self):
        """Delegate to CombatManager"""
        return self.combat_manager._play_enemy_defeat_animation_legacy()
    
    def _play_enemy_death_animation(self, enemy_folder, animation_name, direction, num_frames, frame_delay_ms):
        """Delegate to CombatManager"""
        return self.combat_manager._play_enemy_death_animation(enemy_folder, animation_name, direction, num_frames, frame_delay_ms)
    
    def _play_death_animation_frames(self, frames, current_frame, delay_ms):
        """Delegate to CombatManager"""
        return self.combat_manager._play_death_animation_frames(frames, current_frame, delay_ms)
    
    def _shrink_enemy_sprite(self, scale, frames_remaining):
        """Delegate to CombatManager"""
        return self.combat_manager._shrink_enemy_sprite(scale, frames_remaining)
    
    def _flash_enemy_hp_intense(self):
        """Delegate to CombatManager"""
        return self.combat_manager._flash_enemy_hp_intense()
    
    def _multi_flash(self, widget, flash_count, max_flashes):
        """Delegate to CombatManager"""
        return self.combat_manager._multi_flash(widget, flash_count, max_flashes)
    
    def _multi_flash_frame(self, widget, flash_count, max_flashes):
        """Delegate to CombatManager"""
        return self.combat_manager._multi_flash_frame(widget, flash_count, max_flashes)
    
    def _multi_flash_label(self, widget, flash_count, max_flashes):
        """Delegate to CombatManager"""
        return self.combat_manager._multi_flash_label(widget, flash_count, max_flashes)
    
    def _fade_out_enemy(self, target_index, frames_remaining):
        """Delegate to CombatManager"""
        return self.combat_manager._fade_out_enemy(target_index, frames_remaining)
    
    def _flash_enemy_hp(self, damage=0):
        """Delegate to CombatManager"""
        return self.combat_manager._flash_enemy_hp(damage)
    
    def _flash_player_hp(self, damage=0):
        """Delegate to CombatManager"""
        return self.combat_manager._flash_player_hp(damage)
    
    def _shake_widget(self, widget, frame, damage):
        """Delegate to CombatManager"""
        return self.combat_manager._shake_widget(widget, frame, damage)
    
    def _start_enemy_turn_sequence(self):
        """Delegate to CombatManager"""
        return self.combat_manager._start_enemy_turn_sequence()
    
    def _check_poison_death(self):
        """Delegate to CombatManager"""
        return self.combat_manager._check_poison_death()
    
    def _announce_enemy_attack(self):
        """Delegate to CombatManager"""
        return self.combat_manager._announce_enemy_attack()
    
    def _show_and_animate_enemy_dice(self, final_values, num_dice):
        """Delegate to CombatManager"""
        return self.combat_manager._show_and_animate_enemy_dice(final_values, num_dice)
    
    def _animate_enemy_dice_roll(self, final_values, frame, max_frames):
        """Delegate to CombatManager"""
        return self.combat_manager._animate_enemy_dice_roll(final_values, frame, max_frames)
    
    def _render_enemy_die(self, canvas, value):
        """Delegate to CombatManager"""
        return self.combat_manager._render_enemy_die(canvas, value)
    
    def _announce_enemy_damage(self):
        """Delegate to CombatManager"""
        return self.combat_manager._announce_enemy_damage()
    
    def _apply_armor_and_announce_final_damage(self):
        """Delegate to CombatManager"""
        return self.combat_manager._apply_armor_and_announce_final_damage()
    
    def _apply_enemy_damage_and_animate(self):
        """Delegate to CombatManager"""
        return self.combat_manager._apply_enemy_damage_and_animate()
    
    def _check_combat_end(self):
        """Delegate to CombatManager"""
        return self.combat_manager._check_combat_end()
    
    def _execute_enemy_attacks(self):
        """Delegate to CombatManager"""
        return self.combat_manager._execute_enemy_attacks()
    
    def _end_combat_round(self):
        """Delegate to CombatManager"""
        return self.combat_manager._end_combat_round()
    
    def _calculate_and_announce_player_damage(self):
        """Delegate to CombatManager"""
        return self.combat_manager._calculate_and_announce_player_damage()
    
    def _apply_player_damage_and_animate(self):
        """Delegate to CombatManager"""
        return self.combat_manager._apply_player_damage_and_animate()
    
    def _check_enemy_status_after_damage(self, target, damage):
        """Delegate to CombatManager"""
        return self.combat_manager._check_enemy_status_after_damage(target, damage)
    
    def _handle_enemy_defeat(self, target):
        """Delegate to CombatManager"""
        return self.combat_manager._handle_enemy_defeat(target)
    
    def _finalize_enemy_defeat(self, target):
        """Delegate to CombatManager"""
        return self.combat_manager._finalize_enemy_defeat(target)
    
    def _execute_player_attack(self):
        """Delegate to CombatManager"""
        return self.combat_manager._execute_player_attack()

    def enemy_defeated(self):
        """Enemy is defeated"""
        return self.combat_manager.enemy_defeated()
    
    def clear_combat_buffs(self):
        """Remove all temporary combat buffs"""
        # Reset temporary combat bonuses
        if hasattr(self, 'temp_combat_damage'):
            self.damage_bonus -= self.temp_combat_damage
            self.temp_combat_damage = 0
        
        if hasattr(self, 'temp_combat_crit'):
            self.crit_chance -= self.temp_combat_crit
            self.temp_combat_crit = 0
        
        if hasattr(self, 'temp_combat_rerolls'):
            self.reroll_bonus -= self.temp_combat_rerolls
            self.temp_combat_rerolls = 0
        
        # Reset Mystic Ring for next combat
        self.mystic_ring_used = False
        if hasattr(self, 'combat_turn_count'):
            delattr(self, 'combat_turn_count')
        
        # Clear temp shield
        self.temp_shield = 0
        
        # Clear combat hazard effects
        if hasattr(self, 'combat_crit_penalty'):
            self.combat_crit_penalty = 0
        if hasattr(self, 'combat_fumble_chance'):
            self.combat_fumble_chance = 0
        if hasattr(self, 'combat_enemy_damage_boost'):
            self.combat_enemy_damage_boost = 0
        if hasattr(self, 'combat_poison_damage'):
            self.combat_poison_damage = 0
        
        # Clear burn status
        self.enemy_burn_status = {}
        
        # Clear status effects after combat
        if self.flags.get('statuses'):
            self.flags['statuses'] = []
            self.log("Status effects cleared.", 'system')
    
    def attempt_flee(self):
        """Try to flee from combat"""
        return self.combat_manager.attempt_flee()
    
    def open_chest(self):
        """Open a chest for loot"""
        if self.current_room.chest_looted:
            return
        
        self.current_room.chest_looted = True
        self.chests_opened += 1
        
        # Get difficulty multiplier
        difficulty = self.settings.get("difficulty", "Normal")
        loot_mult = self.difficulty_multipliers[difficulty]["loot_chance_mult"]
        
        # Random loot (adjusted by difficulty)
        if random.random() < (0.6 * loot_mult):  # Better loot chance on Easy
            loot_type = random.choice(['gold', 'gold', 'item', 'health'])
        else:
            loot_type = 'gold'
        
        if loot_type == 'gold':
            amount = random.randint(20, 50) + (self.floor * 10)
            amount = int(amount * loot_mult)
            self.gold += amount
            self.total_gold_earned += amount
            self.stats["gold_found"] += amount
            self.log(f"[CHEST] Opened chest: +{amount} gold!", 'loot')
        elif loot_type == 'health':
            heal = random.randint(15, 30)
            heal = int(heal * self.difficulty_multipliers[difficulty]["heal_mult"])
            self.health = min(self.health + heal, self.max_health)
            self.log(f"[CHEST] Opened chest: Health Potion! +{heal} HP", 'loot')
        else:
            # Use actual items from item_definitions instead of placeholder names
            items = ['Weighted Die', 'Hourglass Shard', 'Tuner\'s Hammer', 'Conductor Rod', 
                    'Honey Jar', 'Lucky Chip', 'Lockpick Kit', 'Silk Bundle', 'Blue Quartz']
            item = random.choice(items)
            if len(self.inventory) < self.max_inventory:
                self.inventory.append(item)
                # Track acquisition using centralized function
                self.inventory_equipment_manager.track_item_acquisition(item, "chest")
                self.log(f"[CHEST] Opened chest: {item}!", 'loot')
            else:
                self.log(f"[CHEST] Opened chest: {item}! But inventory is full.", 'system')
        
        self.update_display()
        self.show_exploration_options()
    
    def generate_ground_loot(self, room):
        """Generate what spawns on the ground when first entering a room"""
        return self.navigation_manager.generate_ground_loot(room)
    
    def describe_ground_items(self, room):
        """Show player what's on the ground"""
        return self.navigation_manager.describe_ground_items(room)
    
    def search_container(self, container_name):
        """Open container and show submenu with its contents"""
        return self.inventory_pickup_manager.search_container(container_name)
    
    def use_lockpick_on_container(self, container_name):
        """Use Lockpick Kit to unlock a locked container"""
        return self.inventory_pickup_manager.use_lockpick_on_container(container_name)
    
    def show_container_contents(self, container_name, gold_amount, item_found):
        """Show submenu displaying what's inside the opened container"""
        return self.inventory_pickup_manager.show_container_contents(container_name, gold_amount, item_found)
    
    def take_container_gold(self):
        """Take gold from container"""
        return self.inventory_pickup_manager.take_container_gold()
    
    def take_container_item(self):
        """Take item from container"""
        return self.inventory_pickup_manager.take_container_item()
    
    def take_all_from_container(self, gold_amount, item_name):
        """Take all items from container"""
        return self.inventory_pickup_manager.take_all_from_container(gold_amount, item_name)
    
    def close_container_and_refresh(self):
        """Close container dialog and return to ground items view"""
        return self.inventory_pickup_manager.close_container_and_refresh()
    
    def pickup_ground_gold(self):
        """Pick up loose gold from ground"""
        return self.inventory_pickup_manager.pickup_ground_gold()
    
    def pickup_ground_item(self, item_name):
        """Pick up a loose item from ground"""
        return self.inventory_pickup_manager.pickup_ground_item(item_name)
    
    def pickup_uncollected_item(self, item_name, skip_refresh=False):
        """Try to pick up an item that was previously left behind due to full inventory"""
        return self.inventory_pickup_manager.pickup_uncollected_item(item_name, skip_refresh)
    
    def pickup_dropped_item(self, item_name, skip_refresh=False):
        """Pick up an item that was previously dropped by the player"""
        return self.inventory_pickup_manager.pickup_dropped_item(item_name, skip_refresh)
    
    def rest(self):
        """Rest to heal - can only rest once per 3 rooms explored"""
        if self.rest_cooldown > 0:
            self.log(f"⛔ Cannot rest yet! Explore {self.rest_cooldown} more room{'s' if self.rest_cooldown > 1 else ''} to rest again.", 'enemy')
            return
        
        if self.in_combat:
            self.log("⛔ Cannot rest during combat!", 'enemy')
            return
        
        heal = 20 + self.heal_bonus
        
        # Apply difficulty multiplier to healing
        difficulty = self.settings.get("difficulty", "Normal")
        heal = int(heal * self.difficulty_multipliers[difficulty]["heal_mult"])
        
        old_hp = self.health
        self.health = min(self.health + heal, self.max_health)
        actual = self.health - old_hp
        
        if actual > 0:
            self.stats["times_rested"] += 1
            self.log(f"[REST] Rested and recovered {actual} HP. Must explore 3 rooms before resting again.", 'success')
            self.rest_cooldown = 3  # Must explore 3 rooms before resting again
            self.rooms_since_rest = 0
        else:
            self.log("You're already at full health!", 'system')
        
        # Update display immediately to show new rest cooldown
        self.update_display()
    
    def travel_to_store(self):
        """Fast travel to the store location"""
        if not self.store_found or not self.store_position:
            self.log("No store found on this floor yet!", 'system')
            return
        
        # Save current room name before teleporting
        old_room_name = self.current_room.data.get('name', 'Unknown Location') if hasattr(self.current_room, 'data') else 'Unknown Location'
        
        # Save current position
        old_pos = self.current_pos
        
        # Teleport to store
        self.current_pos = self.store_position
        self.current_room = self.store_room
        
        self.log(f"Traveled to the store from {old_room_name}!", 'system')
        
        # Update display and refresh exploration options
        self.update_display()
        self.draw_minimap()
        
        # Clear and refresh exploration options to show correct navigation buttons for store location
        self.show_exploration_options()
        
        # Then show the store interface
        self.show_store()
    
    def show_store(self, active_tab='buy'):
        """Display the store interface"""
        self.store_manager.show_store(active_tab)
    
    def _show_store_buy_content(self, parent):
        """Show the buy tab content"""
        self.store_manager._show_store_buy_content(parent)
    
    def _show_store_sell_content(self, parent):
        """Show the sell tab content"""
        self.store_manager._show_store_sell_content(parent)
    
    def _generate_store_inventory(self):
        """Generate store inventory based on floor level with randomization"""
        return self.store_manager._generate_store_inventory()
    
    def _calculate_sell_price(self, item_name):
        """Calculate sell price for an item (50% of buy price from store)"""
        return self.store_manager._calculate_sell_price(item_name)
    
    def _create_store_item_row(self, parent, item_name, price, is_buying=True, item_idx=None, item_count=1):
        """Create a row for a store item"""
        self.store_manager._create_store_item_row(parent, item_name, price, is_buying, item_idx, item_count)
    
    def _buy_item(self, item_name, price):
        """Purchase an item from the store"""
        self.store_manager._buy_item(item_name, price)
    
    def _sell_item(self, item_idx, price):
        """Sell an item from inventory"""
        self.store_manager._sell_item(item_idx, price)
    
    def descend_floor(self):
        """Go to next floor"""
        return self.navigation_manager.descend_floor()
    
    def get_unequipped_inventory_count(self):
        """Get count of inventory items that are NOT equipped"""
        equipped_item_names = [item for item in self.equipped_items.values() if item]
        unequipped_count = sum(1 for item in self.inventory if item not in equipped_item_names)
        return unequipped_count
    
    def show_inventory(self):
        """Show inventory dialog"""
        return self.inventory_display_manager.show_inventory()
    
    def create_item_tooltip(self, widget, item_name):
        """Create hover tooltip for inventory item"""
        return self.inventory_display_manager.create_item_tooltip(widget, item_name)
    
    def show_ground_items(self):
        """Show dialog with all items on the ground in current room"""
        return self.inventory_display_manager.show_ground_items()
    
    def pickup_from_ground(self, item_name, source_type):
        """Pick up item from ground dialog or search container"""
        return self.inventory_display_manager.pickup_from_ground(item_name, source_type)
    
    def pickup_all_ground_items(self):
        """Take all items from ground (gold + loose items + uncollected + dropped, but NOT containers)"""
        return self.inventory_equipment_manager.pickup_all_ground_items()

    
    def drop_item(self, idx):
        """Drop item from inventory"""
        return self.inventory_equipment_manager.drop_item(idx)
    
    def _add_item_to_inventory(self, item_name):
        """Add item to inventory and track floor level for equipment"""
        return self.inventory_equipment_manager.add_item_to_inventory(item_name)
    
    def equip_item(self, item_name, slot):
        """Equip an item to a slot"""
        return self.inventory_equipment_manager.equip_item(item_name, slot)
    
    def unequip_item(self, slot):
        """Unequip an item from a slot"""
        return self.inventory_equipment_manager.unequip_item(slot)
    
    def _apply_equipment_bonuses(self, item_name, skip_hp=False):
        """Apply bonuses from equipped item with floor scaling"""
        return self.inventory_equipment_manager.apply_equipment_bonuses(item_name, skip_hp)
    
    def _remove_equipment_bonuses(self, item_name):
        """Remove bonuses from unequipped item with floor scaling"""
        return self.inventory_equipment_manager.remove_equipment_bonuses(item_name)
    
    def _damage_equipment_durability(self, slot, amount):
        """Damage equipment durability, break if reaches 0"""
        equipped_item = self.equipped_items.get(slot)
        if not equipped_item:
            return
        
        # Initialize durability if not already tracked (shouldn't happen, but safety check)
        if equipped_item not in self.equipment_durability:
            item_def = self.item_definitions.get(equipped_item, {})
            max_dur = item_def.get('max_durability', 100)
            self.equipment_durability[equipped_item] = max_dur
            self.log(f"⚙️ Initialized {equipped_item} durability tracking at {max_dur}", 'system')
        
        # Reduce durability
        self.equipment_durability[equipped_item] -= amount
        current_dur = self.equipment_durability[equipped_item]
        
        # Get max durability
        item_def = self.item_definitions.get(equipped_item, {})
        max_dur = item_def.get('max_durability', 100)
        
        # Warn when durability is low
        if current_dur <= 20 and current_dur > 0:
            self.log(f"⚠️ {equipped_item} durability low! ({current_dur}/{max_dur})", 'system')
        
        # Break item if durability reaches 0
        if current_dur <= 0:
            broken_name = f"Broken {equipped_item}"
            
            # Track broken equipment stats
            if slot == "weapon":
                self.stats["weapons_broken"] += 1
            elif slot == "armor":
                self.stats["armor_broken"] += 1
            
            # Always keep broken items for repair/sell
            self.log(f"♡ {equipped_item} broke! It's now {broken_name}.", 'enemy')
            
            # Remove bonuses from equipped item
            self._remove_equipment_bonuses(equipped_item)
            
            # Unequip broken item
            self.equipped_items[slot] = None
            
            # Replace with broken version in inventory
            if equipped_item in self.inventory:
                inv_index = self.inventory.index(equipped_item)
                self.inventory[inv_index] = broken_name
                
                # Create broken item definition if it doesn't exist
                if broken_name not in self.item_definitions:
                    original_def = self.item_definitions.get(equipped_item, {})
                    self.item_definitions[broken_name] = {
                        "type": "broken_equipment",
                        "original_item": equipped_item,
                        "slot": slot,  # Track which slot this belonged to for repair kits
                        "sell_value": max(1, original_def.get('sell_value', 5) // 2),  # Half value
                        "desc": f"A broken {equipped_item}. Can be repaired or sold for scrap."
                    }
            
            # Remove from durability tracking
            del self.equipment_durability[equipped_item]
            
            self.update_display()
    
    def has_trap_in_current_room(self):
        """Check if the current room has traps or hazards that can be disarmed"""
        if not self.current_room:
            return False
        
        # Check if room has trap tag
        if 'trap' in self.current_room.data.get('tags', []):
            return True
        
        # Check threats for trap-related keywords
        threats = self.current_room.data.get('threats', [])
        trap_keywords = ['trap', 'spike', 'blade', 'pressure plate', 'poison gas', 
                        'toxic fumes', 'scythe', 'scything', 'thresher']
        
        for threat in threats:
            threat_lower = threat.lower()
            if any(keyword in threat_lower for keyword in trap_keywords):
                return True
        
        return False
    
    def use_item(self, idx):
        """Use an item from inventory"""
        return self.inventory_usage_manager.use_item(idx)
    
    def update_display(self):
        """Update all display elements with enhanced visuals"""
        # Skip enemy sprite updates during flash animation
        is_flashing = getattr(self, '_is_flashing', False)
        
        if hasattr(self, 'hp_bar'):
            # Update HP bar in stats section
            parent = self.hp_bar.master
            try:
                # Check if parent still exists
                parent.winfo_exists()
                self.hp_bar.destroy()
                self.hp_bar = self.create_hp_bar(parent, self.health, self.max_health, 
                                                width=int(180 * self.scale_factor), 
                                                height=int(18 * self.scale_factor))
                self.hp_bar.pack(side=tk.LEFT)
            except tk.TclError:
                # Parent was destroyed, skip update
                pass
        
        # Update action panel player HP bar
        if hasattr(self, 'action_panel_player_hp'):
            parent = self.action_panel_player_hp.master
            try:
                parent.winfo_exists()
                self.action_panel_player_hp.destroy()
                self.action_panel_player_hp = self.create_hp_bar(parent, 
                                                                  self.health, self.max_health, 
                                                                  width=int(130 * self.scale_factor), 
                                                                  height=int(12 * self.scale_factor))
                self.action_panel_player_hp.pack(anchor='w', pady=(2, 4))
            except tk.TclError:
                # Parent was destroyed, skip update
                pass
        
        # Update action panel enemy HP bar if in combat
        if self.in_combat and hasattr(self, 'action_panel_enemy_hp') and self.action_panel_enemy_hp:
            enemy = self.enemies[self.current_enemy_index] if self.enemies else None
            if enemy:
                self.action_panel_enemy_hp.destroy()
                self.action_panel_enemy_hp = self.create_hp_bar(self.enemy_hp_frame, 
                                                                 enemy['health'], enemy['max_health'], 
                                                                 width=int(150 * self.scale_factor), 
                                                                 height=int(22 * self.scale_factor))
                self.action_panel_enemy_hp.pack(anchor='e', pady=(2, 4))
                self.action_panel_enemy_label.config(text=enemy['name'])
            
        if hasattr(self, 'gold_label'):
            self.gold_label.config(text=f" Gold: {self.gold}")
        
        # Update dev mode indicator
        if hasattr(self, 'dev_indicator'):
            if self.dev_mode:
                self.dev_indicator.config(text="[DEV]")
            else:
                self.dev_indicator.config(text="")
        
        if hasattr(self, 'floor_label'):
            if self.floor == 0:
                self.floor_label.config(text=f" THE THRESHOLD")
            else:
                self.floor_label.config(text=f" FLOOR {self.floor}")
                
        if hasattr(self, 'progress_label'):
            # Show rest cooldown status prominently
            if self.rest_cooldown > 0:
                rest_status = f" | Rest in {self.rest_cooldown} room{'s' if self.rest_cooldown > 1 else ''}"
            else:
                rest_status = " | Rest Ready!"
            self.progress_label.config(text=f"Rooms Explored: {self.rooms_explored}{rest_status}")
        
        # Update movement button states based on blocked directions
        if hasattr(self, 'movement_buttons') and hasattr(self, 'current_room'):
            for direction, button in self.movement_buttons.items():
                if not self.current_room.exits.get(direction, False):
                    # Direction is blocked
                    button.config(state=tk.DISABLED, bg='#3a3a3a', fg='#666666')
                else:
                    # Direction is open
                    button.config(state=tk.NORMAL, bg=self.current_colors["button_primary"], fg='#000000')
    
    def show_starter_area(self):
        """Display the tutorial/starter area - delegates to NavigationManager"""
        self.navigation_manager.show_starter_area()
    
    def _show_starter_area_old(self):
        """Display the tutorial/starter area"""
        self.in_starter_area = True
        self.floor = 0
        
        # Force window update to get accurate dimensions
        self.root.update_idletasks()
        
        # Calculate initial scale factor based on current window size
        current_width = self.root.winfo_width()
        current_height = self.root.winfo_height()
        if current_width > 1 and current_height > 1:  # Window has been sized
            width_scale = current_width / self.base_window_width
            height_scale = current_height / self.base_window_height
            self.scale_factor = min(width_scale, height_scale)
            self.scale_factor = max(0.8, min(self.scale_factor, 2.5))
        
        # Setup basic UI first
        for widget in self.root.winfo_children():
            widget.destroy()
        
        self.game_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"])
        self.game_frame.pack(fill=tk.BOTH, expand=True)
        
        # Create scrollable content area
        canvas = tk.Canvas(self.game_frame, bg=self.current_colors["bg_primary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.game_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_primary"], troughcolor=self.current_colors["bg_dark"])
        main_area = tk.Frame(canvas, bg=self.current_colors["bg_primary"])
        
        # Create window and bind to canvas width changes
        canvas_window = canvas.create_window((0, 0), window=main_area, anchor="nw")
        
        def on_canvas_configure(event):
            # Update the scroll region
            canvas.configure(scrollregion=canvas.bbox("all"))
            # Make the frame match the canvas width
            canvas.itemconfig(canvas_window, width=event.width)
            
            # Only show scrollbar if content is taller than canvas
            bbox = canvas.bbox("all")
            if bbox:
                content_height = bbox[3] - bbox[1]
                canvas_height = event.height
                if content_height > canvas_height:
                    scrollbar.pack(side="right", fill="y")
                else:
                    scrollbar.pack_forget()
        
        canvas.bind("<Configure>", on_canvas_configure)
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True)
        # Don't pack scrollbar initially - let on_canvas_configure handle it
        
        # Stats bar at top
        stats_frame = tk.Frame(main_area, bg=self.current_colors["bg_secondary"], pady=self.scale_padding(10))
        stats_frame.pack(fill=tk.X, padx=self.scale_padding(10), pady=self.scale_padding(5))
        
        left_stats = tk.Frame(stats_frame, bg=self.current_colors["bg_secondary"])
        left_stats.pack(side=tk.LEFT, padx=self.scale_padding(20))
        
        self.hp_label = tk.Label(left_stats, text=f"HP: {self.health}/{self.max_health}",
                                font=('Arial', self.scale_font(14), 'bold'), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_red"])
        self.hp_label.pack(anchor='w')
        
        self.gold_label = tk.Label(left_stats, text=f"Gold: {self.gold}",
                                   font=('Arial', self.scale_font(12)), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"])
        self.gold_label.pack(anchor='w')
        
        # Settings/Menu button in top right
        menu_frame = tk.Frame(stats_frame, bg=self.current_colors["bg_secondary"])
        menu_frame.pack(side=tk.RIGHT, padx=self.scale_padding(10))
        
        tk.Button(menu_frame, text="☰", command=self.show_pause_menu,
                 font=('Arial', self.scale_font(16), 'bold'), bg=self.current_colors["button_secondary"], fg='#000000',
                 width=3, height=1).pack(side=tk.RIGHT, padx=self.scale_padding(2))
        
        tk.Button(menu_frame, text="?", command=self.show_keybindings,
                 font=('Arial', self.scale_font(16), 'bold'), bg=self.current_colors["button_secondary"], fg='#000000',
                 width=3, height=1).pack(side=tk.RIGHT, padx=self.scale_padding(2))
        
        right_stats = tk.Frame(stats_frame, bg=self.current_colors["bg_secondary"])
        right_stats.pack(side=tk.RIGHT, padx=self.scale_padding(20))
        
        self.floor_label = tk.Label(right_stats, text=f"THE THRESHOLD",
                                    font=('Arial', self.scale_font(14), 'bold'), bg=self.current_colors["bg_secondary"], fg=self.current_colors["button_primary"])
        self.floor_label.pack(anchor='e')
        
        self.progress_label = tk.Label(right_stats, text=f"Rooms: {self.rooms_explored}",
                                      font=('Arial', self.scale_font(10)), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"])
        self.progress_label.pack(anchor='e')
        
        # Title and description
        starter_data = self.world_lore['starting_area']
        
        title = tk.Label(main_area, text=starter_data['name'],
                        font=('Arial', self.scale_font(20), 'bold'), bg=self.current_colors["bg_primary"], fg=self.current_colors["text_gold"],
                        wraplength=self.get_scaled_wraplength(700), justify=tk.CENTER)
        title.pack(pady=self.scale_padding(20))
        
        desc = tk.Label(main_area, text=starter_data['description'],
                       font=('Arial', self.scale_font(14)), bg=self.current_colors["bg_primary"], fg=self.current_colors["text_primary"],
                       wraplength=self.get_scaled_wraplength(700), justify=tk.LEFT)
        desc.pack(pady=self.scale_padding(10), padx=self.scale_padding(30))
        
        # Ambient details
        ambient = tk.Label(main_area, text="• " + "\n• ".join(starter_data['ambient_details']),
                          font=('Arial', self.scale_font(9), 'italic'), bg=self.current_colors["bg_primary"], fg=self.current_colors["text_secondary"],
                          wraplength=self.get_scaled_wraplength(700), justify=tk.LEFT)
        ambient.pack(pady=self.scale_padding(10), padx=self.scale_padding(40))
        
        # Interactive elements frame - make it centered with max width
        interact_container = tk.Frame(main_area, bg=self.current_colors["bg_primary"])
        interact_container.pack(fill=tk.BOTH, expand=True, pady=self.scale_padding(20))
        
        interact_frame = tk.Frame(interact_container, bg=self.current_colors["bg_secondary"], relief=tk.RAISED, borderwidth=2)
        interact_frame.pack(fill=tk.BOTH, expand=True, padx=self.scale_padding(50))
        
        tk.Label(interact_frame, text="Welcome, Adventurer. Study these teachings before your journey begins.",
                font=('Arial', self.scale_font(12)), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                wraplength=self.get_scaled_wraplength(600), justify=tk.CENTER).pack(pady=self.scale_padding(10))
        
        # Signs
        signs_frame = tk.Frame(interact_frame, bg=self.current_colors["bg_secondary"])
        signs_frame.pack(fill=tk.X, padx=self.scale_padding(20), pady=self.scale_padding(10))
        
        tk.Label(signs_frame, text="Signs & Inscriptions:",
                font=('Arial', self.scale_font(11), 'bold'), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"]).pack(anchor='w')
        
        for i, sign in enumerate(starter_data['signs']):
            sign_btn = tk.Button(signs_frame, text=f"{sign['title']}",
                               command=lambda s=sign: self.read_sign(s),
                               font=('Arial', self.scale_font(10)), bg=self.current_colors["button_primary"], fg='#000000',
                               anchor='w')
            sign_btn.pack(fill=tk.X, pady=self.scale_padding(3), padx=self.scale_padding(10))
        
        # Chests
        chests_frame = tk.Frame(interact_frame, bg=self.current_colors["bg_secondary"])
        chests_frame.pack(fill=tk.X, padx=self.scale_padding(20), pady=self.scale_padding(10))
        
        tk.Label(chests_frame, text="Chests:",
                font=('Arial', self.scale_font(11), 'bold'), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"]).pack(anchor='w')
        
        for chest in starter_data['starter_chests']:
            if chest['id'] in self.starter_chests_opened:
                chest_label = tk.Label(chests_frame, text=f"[Empty] Chest {chest['id']} (already looted)",
                                      font=('Arial', self.scale_font(10)), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_secondary"],
                                      anchor='w')
                chest_label.pack(fill=tk.X, pady=self.scale_padding(3), padx=self.scale_padding(10))
            else:
                chest_btn = tk.Button(chests_frame, text=f"{chest['description']}",
                                    command=lambda c=chest: self.open_starter_chest(c),
                                    font=('Arial', self.scale_font(10)), bg=self.current_colors["button_secondary"], fg='#000000',
                                    anchor='w')
                chest_btn.pack(fill=tk.X, pady=self.scale_padding(3), padx=self.scale_padding(10))
        
        # Enter dungeon button
        enter_frame = tk.Frame(interact_frame, bg=self.current_colors["bg_secondary"])
        enter_frame.pack(pady=self.scale_padding(10))
        
        tk.Label(enter_frame, text="Beyond lies the First Calculation...",
                font=('Arial', self.scale_font(10), 'italic'), bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_secondary"]).pack(pady=self.scale_padding(3))
        
        tk.Button(enter_frame, text="[ENTER THE DUNGEON - FLOOR 1]",
                 command=self.enter_dungeon_from_starter,
                 font=('Arial', self.scale_font(12), 'bold'), bg=self.current_colors["text_red"], fg='#ffffff',
                 width=28, pady=self.scale_padding(10)).pack(pady=self.scale_padding(3))
        
        # Update scroll region after all content is added
        main_area.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        
        # Setup mousewheel scrolling
        self.setup_mousewheel_scrolling(canvas)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(main_area)
        
        self.update_display()
        
        # Schedule scrollbar check after UI is fully rendered
        def check_scrollbar():
            self.root.update_idletasks()
            canvas.event_generate('<Configure>')
        
        self.root.after(100, check_scrollbar)
    
    def read_sign(self, sign):
        """Display sign text in dialog"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_dark"], relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=600, height=500)
        
        # Header with title and X button
        header = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_dark"])
        header.pack(fill=tk.X, pady=(5, 0))
        
        tk.Label(header, text=sign['title'], font=('Arial', 14, 'bold'),
                bg=self.current_colors["bg_dark"], fg=self.current_colors["text_gold"], wraplength=520).pack(side=tk.LEFT, padx=10, pady=10)
        
        close_btn = tk.Label(header, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.current_colors["bg_dark"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.pack(side=tk.RIGHT, padx=5)
        close_btn.bind('<Button-1>', lambda e: self.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Create scrollable text
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_primary"])
        text_frame.pack(fill=tk.BOTH, expand=True, padx=15, pady=10)
        
        text_widget = tk.Text(text_frame, font=('Courier', 10), bg=self.current_colors["bg_primary"], fg=self.current_colors["text_primary"],
                             wrap=tk.WORD, relief=tk.FLAT, padx=10, pady=10)
        text_widget.pack(fill=tk.BOTH, expand=True)
        text_widget.insert('1.0', sign['text'])
        text_widget.config(state=tk.DISABLED)
    
    def open_starter_chest(self, chest):
        """Open a starter area chest - delegates to NavigationManager"""
        self.navigation_manager.open_starter_chest(chest)
    
    def _open_starter_chest_old(self, chest):
        """Open a starter area chest"""
        if chest['id'] in self.starter_chests_opened:
            return
        
        self.starter_chests_opened.append(chest['id'])
        
        # Add items
        for item in chest['items']:
            if len(self.inventory) < self.max_inventory:
                self.inventory.append(item)
                # Track acquisition using centralized function
                self.inventory_equipment_manager.track_item_acquisition(item, "chest")
        
        # Add gold
        if chest['gold'] > 0:
            self.gold += chest['gold']
            self.total_gold_earned += chest['gold']
            self.stats["gold_found"] += chest['gold']
        
        # Show loot dialog
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=500, height=400)
        
        # Header with title and X button
        header = tk.Frame(self.dialog_frame, bg='#1a0f08')
        header.pack(fill=tk.X, pady=(5, 0))
        
        tk.Label(header, text="[CHEST OPENED]", font=('Arial', 16, 'bold'),
                bg='#1a0f08', fg='#ffd700').pack(side=tk.LEFT, padx=10, pady=10)
        
        close_btn = tk.Label(header, text="✕", font=('Arial', 16, 'bold'),
                            bg='#1a0f08', fg='#ff4444', cursor="hand2", padx=5)
        close_btn.pack(side=tk.RIGHT, padx=5)
        close_btn.bind('<Button-1>', lambda e: [self.close_dialog(), self.update_display()])
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        tk.Label(self.dialog_frame, text=chest['description'],
                font=('Arial', 10), bg='#1a0f08', fg='#ffffff',
                wraplength=450, pady=10).pack()
        
        loot_frame = tk.Frame(self.dialog_frame, bg='#2c1810')
        loot_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        tk.Label(loot_frame, text="You found:", font=('Arial', 12, 'bold'),
                bg='#2c1810', fg='#ffd700').pack(pady=5)
        
        for item in chest['items']:
            tk.Label(loot_frame, text=f"• {item}", font=('Arial', 11),
                    bg='#2c1810', fg='#4ecdc4').pack()
        
        if chest['gold'] > 0:
            tk.Label(loot_frame, text=f"• {chest['gold']} Gold", font=('Arial', 11),
                    bg='#2c1810', fg='#ffd700').pack()
        
        tk.Label(self.dialog_frame, text=chest['lore'],
                font=('Arial', 9, 'italic'), bg='#1a0f08', fg='#888888',
                wraplength=450, pady=10).pack()
        
        tk.Button(self.dialog_frame, text="Continue", command=lambda: [self.close_dialog(), self.update_display()],
                 font=('Arial', 12, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=15, pady=10).pack(pady=10)
        
        self.update_display()
    
    def enter_dungeon_from_starter(self):
        """Enter the main dungeon from starter area - delegates to NavigationManager"""
        self.navigation_manager.enter_dungeon_from_starter()
    
    def _enter_dungeon_from_starter_old(self):
        """Leave starter area and begin floor 1"""
        self.in_starter_area = False
        self.floor = 1
        self.start_new_floor()
    
    # OLD show_stats() removed - using comprehensive version at line 8158+
    
    def _get_lore_entry_index(self, lore_key, item_key, reread_msg="You've read all these. This one seems familiar..."):
        """Delegates to lore_manager - kept for backward compatibility"""
        return self.lore_manager._get_lore_entry_index(lore_key, item_key, reread_msg)
    
    def show_journal_page(self, inventory_idx):
        """Show persistent lore from Guard Journal - same content each time"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        item_name = "Guard Journal"
        lore_key = "guards_journal_pages"
        item_key = f"{item_name}_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key, "You've read all the journal pages. This one seems familiar...")
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Guard Journal"] = self.stats["lore_found"].get("Guard Journal", 0) + 1
            # Add to lore codex for permanent access
            self.lore_codex.append({
                "type": "guards_journal",
                "title": item_name,
                "subtitle": entry.get("date", ""),
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 400, 0.6, 0.7)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text="◈ GUARD JOURNAL ◈",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=10)
        
        # Date
        tk.Label(self.dialog_frame, text=entry["date"],
                font=('Arial', 11, 'italic'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_secondary", "#cccccc")).pack(pady=5)
        
        # Separator
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        # Journal text with wrapping
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        # Close button
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a page from a guard's journal... The words feel unsettlingly familiar.", 'lore')
    
    def show_repair_selection_dialog(self, repair_kit_name, repair_kit_idx, repair_percent, repairable_items):
        """Show menu to select which item to repair"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 500, 0.6, 0.7)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text=f"⚒ {repair_kit_name} ⚒",
                font=('Arial', 14, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=15)
        
        tk.Label(self.dialog_frame, text=f"Select an item to repair ({int(repair_percent*100)}% restoration):",
                font=('Arial', 11), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff")).pack(pady=5)
        
        # Scrollable list of repairable items
        list_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        list_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        canvas = tk.Canvas(list_frame, bg=self.current_colors["bg_dark"], highlightthickness=0)
        scrollbar = tk.Scrollbar(list_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_dark"], troughcolor=self.current_colors["bg_secondary"])
        scrollable_frame = tk.Frame(canvas, bg=self.current_colors["bg_dark"])
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Add button for each repairable item
        for item_data in repairable_items:
            item_frame = tk.Frame(scrollable_frame, bg=self.current_colors["bg_secondary"],
                                 relief=tk.RAISED, borderwidth=2)
            item_frame.pack(fill=tk.X, padx=5, pady=3)
            
            # Item description
            tk.Label(item_frame, text=item_data['display'],
                    font=('Arial', 10), bg=self.current_colors["bg_secondary"],
                    fg=self.current_colors.get("text_primary", "#ffffff"),
                    anchor='w').pack(side=tk.LEFT, padx=10, pady=8, fill=tk.X, expand=True)
            
            # Repair button
            def create_repair_callback(item_info):
                def do_repair():
                    self.apply_repair(repair_kit_name, repair_kit_idx, repair_percent, item_info)
                return do_repair
            
            tk.Button(item_frame, text="Repair",
                     command=create_repair_callback(item_data),
                     font=('Arial', 9, 'bold'), bg=self.current_colors["button_primary"],
                     fg='#ffffff', width=10).pack(side=tk.RIGHT, padx=10, pady=5)
        
        # Close button
        tk.Button(self.dialog_frame, text="Cancel",
                 command=self.close_dialog,
                 font=('Arial', 11), bg=self.current_colors["button_secondary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
    
    def apply_repair(self, repair_kit_name, repair_kit_idx, repair_percent, item_data):
        """Apply the repair to the selected item"""
        if item_data['type'] == 'broken':
            # Restore broken item
            inv_idx = item_data['index']
            # Adjust index if repair kit was before this item
            if repair_kit_idx < inv_idx:
                inv_idx -= 1  # Account for repair kit being removed
            
            # Replace broken item with original
            self.inventory.pop(repair_kit_idx)  # Remove repair kit first
            self.inventory[inv_idx] = item_data['original']
            self.equipment_durability[item_data['original']] = item_data['restore_dur']
            
            # Track repair stats
            original_def = self.item_definitions.get(item_data['original'], {})
            if original_def.get('slot') == 'weapon':
                self.stats["weapons_repaired"] += 1
            elif original_def.get('slot') == 'armor':
                self.stats["armor_repaired"] += 1
            
            self.log(f"Used {repair_kit_name}! Restored {item_data['name']} to {item_data['original']} with {item_data['restore_dur']} durability", 'success')
            
        elif item_data['type'] == 'inventory':
            # Repair unequipped item in inventory
            self.equipment_durability[item_data['name']] = item_data['new_dur']
            self.inventory.pop(repair_kit_idx)  # Remove repair kit
            
            # Track repair stats
            item_def = self.item_definitions.get(item_data['name'], {})
            if item_def.get('slot') == 'weapon':
                self.stats["weapons_repaired"] += 1
            elif item_def.get('slot') == 'armor':
                self.stats["armor_repaired"] += 1
            
            self.log(f"Used {repair_kit_name} on {item_data['name']}! Restored {item_data['repair_amount']} durability", 'success')
            
        elif item_data['type'] == 'equipped':
            # Repair equipped item
            self.equipment_durability[item_data['name']] = item_data['new_dur']
            self.inventory.pop(repair_kit_idx)  # Remove repair kit
            
            # Track repair stats
            if item_data['slot'] == 'weapon':
                self.stats["weapons_repaired"] += 1
            elif item_data['slot'] == 'armor':
                self.stats["armor_repaired"] += 1
            
            self.log(f"Used {repair_kit_name} on {item_data['name']}! Restored {item_data['repair_amount']} durability", 'success')
        
        self.close_dialog()
        self.show_inventory()
        self.update_display()
    
    def show_lore_selection_dialog(self, item_name, copies_indices):
        """Show dropdown to select which copy of a lore item to read"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(600, 500, 0.6, 0.7)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_primary"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        # Header
        header = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_primary"])
        header.pack(fill=tk.X, padx=10, pady=15)
        tk.Label(header, text=f"◈ {item_name} Collection ◈",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_gold"]).pack()
        
        # Red X close button (top right corner) - placed on header frame
        close_btn = tk.Label(header, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.current_colors["bg_primary"], fg='#ff4444',
                            cursor="hand2", padx=5)
        close_btn.place(relx=1.0, rely=0.0, anchor='ne', x=-10, y=0)
        close_btn.bind('<Button-1>', lambda e: self.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        tk.Label(self.dialog_frame, text=f"Total Found: {len(copies_indices)}",
                font=('Arial', 12), bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_secondary"]).pack(pady=5)
        
        # Scrollable list of copies (lore codex style)
        canvas = tk.Canvas(self.dialog_frame, bg=self.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10)
        scrollable_frame = tk.Frame(canvas, bg=self.current_colors["bg_secondary"])
        
        scrollable_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw", width=canvas.winfo_width()-20)
        canvas.configure(yscrollcommand=scrollbar.set)
        self.setup_mousewheel_scrolling(canvas)
        
        # Create entry for each copy (matching lore codex style)
        for i, inventory_idx in enumerate(copies_indices):
            entry_item = tk.Frame(scrollable_frame, bg=self.current_colors["bg_dark"], 
                                 relief=tk.GROOVE, borderwidth=1)
            entry_item.pack(fill=tk.X, padx=10, pady=3)
            
            entry_header = tk.Frame(entry_item, bg=self.current_colors["bg_dark"])
            entry_header.pack(fill=tk.X, pady=5)
            
            # Copy number and position
            copy_label = tk.Label(entry_header, 
                                 text=f"{item_name} #{i+1} (Slot {inventory_idx+1} in inventory)",
                                 font=('Arial', 10),
                                 bg=self.current_colors["bg_dark"],
                                 fg=self.current_colors["text_primary"])
            copy_label.pack(side=tk.LEFT, padx=10)
            
            # Read button (matching lore codex style)
            read_btn = tk.Button(entry_header, text="Read",
                                command=lambda idx=inventory_idx: self._read_and_close(item_name, idx),
                                font=('Arial', 9, 'bold'),
                                bg=self.current_colors["button_primary"],
                                fg='#000000',
                                width=10,
                                pady=2)
            read_btn.pack(side=tk.RIGHT, padx=10)
        
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=15, pady=10)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y, pady=10)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(scrollable_frame)
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
    
    def _read_and_close(self, item_name, idx):
        """Helper to read lore item and keep the selection menu open - delegates to lore_manager"""
        self.lore_manager.read_and_close(item_name, idx)
    
    def _read_lore_item_with_return(self, item_name, idx, return_callback):
        """Delegates to lore_manager - kept for backward compatibility"""
        self.lore_manager.read_lore_item_with_return(item_name, idx, return_callback)
    
    def _read_lore_item(self, item_name, idx):
        """Delegates to lore_manager - kept for backward compatibility"""
        self.lore_manager.read_lore_item(item_name, idx)
    
    def show_quest_notice(self, inventory_idx):
        """Show quest notice lore - same content each time"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        item_name = "Quest Notice"
        lore_key = "quest_notices"
        item_key = f"{item_name}_{inventory_idx}"
        
        entry_index = self._get_lore_entry_index(lore_key, item_key, "You've read all the quest notices. This one seems familiar...")
        notice = self.lore_items[lore_key][entry_index]
        
        # Track stat (only increments once per unique entry)
        is_new = item_key not in self.lore_item_assignments
        if is_new:
            self.stats["lore_found"]["Quest Notice"] = self.stats["lore_found"].get("Quest Notice", 0) + 1
            # Add to lore codex
            self.lore_codex.append({
                "type": "quest_notice",
                "title": item_name,
                "subtitle": f"Reward: {notice['reward']}",
                "content": notice["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 450, 0.6, 0.75)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text="▤ QUEST NOTICE ▤",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=10)
        
        # Quest title
        tk.Label(self.dialog_frame, text=notice["title"],
                font=('Arial', 13, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_gold", "#ffd700")).pack(pady=5)
        
        # Reward
        tk.Label(self.dialog_frame, text=f"Reward: {notice['reward']}",
                font=('Arial', 11, 'italic'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_secondary", "#cccccc")).pack(pady=3)
        
        # Separator
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        # Quest text with wrapping
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=notice["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read an old quest notice... The dungeon's mysteries run deeper than you thought.", 'lore')
    
    def show_ledger_entry(self, inventory_idx):
        """Show scrawled note lore - same content each time"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        item_name = "Scrawled Note"
        lore_key = "scrawled_notes"
        
        # Create unique key for this specific item instance
        item_key = f"{item_name}_{inventory_idx}"
        
        # Check if this item already has an assigned entry
        if item_key in self.lore_item_assignments:
            entry_index = self.lore_item_assignments[item_key]
        else:
            # First time reading this item - assign a new entry
            total_entries = len(self.lore_items[lore_key])
            used_indices = self.used_lore_entries.get(lore_key, [])
            
            # Find an unused entry
            available_indices = [i for i in range(total_entries) if i not in used_indices]
            
            if not available_indices:
                # All entries have been used - start reusing from beginning
                entry_index = random.randint(0, total_entries - 1)
                self.log("You've read all the scrawled notes. This one seems familiar...", 'system')
            else:
                # Pick a random unused entry
                entry_index = random.choice(available_indices)
                # Mark this entry as used
                self.used_lore_entries[lore_key].append(entry_index)
            
            # Assign this entry to this item permanently
            self.lore_item_assignments[item_key] = entry_index
            # Mark this entry as used
            self.used_lore_entries[lore_key].append(entry_index)
        
        entry = self.lore_items[lore_key][entry_index]
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 450, 0.6, 0.75)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text="� SCRAWLED NOTE �",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=10)
        
        # Date
        tk.Label(self.dialog_frame, text=entry["date"],
                font=('Arial', 11, 'italic'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_secondary", "#cccccc")).pack(pady=3)
        
        # Account name
        tk.Label(self.dialog_frame, text=entry["account"],
                font=('Arial', 12, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_gold", "#ffd700")).pack(pady=3)
        
        # Separator
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        # Ledger text with wrapping
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        # Close button
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a hastily scrawled note... Someone left their warnings for you to find.", 'lore')
    
    def show_training_manual(self, item_name, inventory_idx):
        """Show training manual lore - same content each time"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "training_manual_pages"
        item_key = f"{item_name}_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key, "You've read all the training manual pages. This one seems familiar...")
        entry = self.lore_items[lore_key][entry_index]
        
        # Track stat (only increments once per unique entry)
        if is_new:
            self.stats["lore_found"]["Training Manual Page"] = self.stats["lore_found"].get("Training Manual Page", 0) + 1
            # Add to lore codex for permanent access
            self.lore_codex.append({
                "type": "training_manual",
                "title": item_name,
                "subtitle": entry["title"],
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 400, 0.6, 0.7)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        # Title
        title_text = "◈ TRAINING MANUAL SCRAP ◈" if "Scrap" in item_name else "◈ TRAINING MANUAL PAGE ◈"
        tk.Label(self.dialog_frame, text=title_text,
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=10)
        
        # Chapter title
        tk.Label(self.dialog_frame, text=entry["title"],
                font=('Arial', 11, 'italic'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_secondary", "#cccccc")).pack(pady=5)
        
        # Separator
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        # Manual text with wrapping
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        # Close button
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a training manual excerpt... The lessons are darker than expected.", 'lore')
    
    def show_scrawled_note(self, inventory_idx, item_name):
        """Show scrawled note lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "scrawled_notes"
        item_key = f"{item_name}_{inventory_idx}"
        
        entry_index = self._get_lore_entry_index(lore_key, item_key, "You've read all the scrawled notes. This one seems familiar...")
        entry = self.lore_items[lore_key][entry_index]
        
        # Track stat (only increments once per unique entry)
        is_new = item_key not in self.lore_item_assignments
        if is_new:
            self.stats["lore_found"]["Scrawled Note"] = self.stats["lore_found"].get("Scrawled Note", 0) + 1
            # Add to lore codex
            self.lore_codex.append({
                "type": "scrawled_note",
                "title": item_name,
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="▣ SCRAWLED NOTE ▣",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a hastily scrawled note... The warnings are chilling.", 'lore')
    
    def show_pressed_page(self, inventory_idx):
        """Show pressed page lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "pressed_pages"
        item_key = f"Pressed Page_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key)
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Pressed Page"] = self.stats["lore_found"].get("Pressed Page", 0) + 1
            # Add to lore codex
            self.lore_codex.append({
                "type": "pressed_page",
                "title": "Pressed Page",
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="※ PRESSED PAGE ※",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#90ee90")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a page from the Thorn Archive... The plants here are terrifying.", 'lore')
    
    def show_surgeons_note(self, inventory_idx):
        """Show surgeon's note lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "surgeons_notes"
        item_key = f"Surgeon's Note_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key)
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Surgeon's Note"] = self.stats["lore_found"].get("Surgeon's Note", 0) + 1
            # Add to lore codex
            self.lore_codex.append({
                "type": "surgeons_note",
                "title": "Surgeon's Note",
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="⚕️ SURGEON'S NOTE ⚕️",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#dc143c")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a surgeon's note... The medical findings are deeply disturbing.", 'lore')
    
    def show_puzzle_note(self, inventory_idx):
        """Show puzzle note lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "puzzle_notes"
        item_key = f"Puzzle Note_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key)
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Puzzle Note"] = self.stats["lore_found"].get("Puzzle Note", 0) + 1
            # Add to lore codex for permanent access
            self.lore_codex.append({
                "type": "puzzle_note",
                "title": "Puzzle Note",
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="◘ PUZZLE NOTE ◘",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#9370db")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a puzzle note... The Riddle Mill's secrets are unsettling.", 'lore')
    
    def show_star_chart(self, inventory_idx, item_name):
        """Show star chart lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "star_charts"
        item_key = f"{item_name}_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key)
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Star Chart"] = self.stats["lore_found"].get("Star Chart", 0) + 1
            # Add to lore codex for permanent access
            self.lore_codex.append({
                "type": "star_chart",
                "title": item_name,
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="⭐ STAR CHART SCRAP ⭐",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#ffd700")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read a star chart... The constellations are wrong. All wrong.", 'lore')
    
    def show_map_scrap(self, inventory_idx):
        """Show map scrap lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_key = "cracked_map_scraps"
        item_key = f"Cracked Map Scrap_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key)
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Cracked Map Scrap"] = self.stats["lore_found"].get("Cracked Map Scrap", 0) + 1
            # Add to lore codex for permanent access
            self.lore_codex.append({
                "type": "map_scrap",
                "title": "Cracked Map Scrap",
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="◎️ CRACKED MAP SCRAP ◎️",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#d2b48c")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Examined the cracked map... The dungeon doesn't follow normal geography.", 'lore')
    
    def show_prayer_strip(self, inventory_idx):
        """Show prayer strip lore"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        # Prayer strips use scrawled_notes as they're similar in tone
        lore_key = "scrawled_notes"
        item_key = f"Prayer Strip_{inventory_idx}"
        
        # Track stat BEFORE getting entry (so we know if it's new)
        is_new = item_key not in self.lore_item_assignments
        
        entry_index = self._get_lore_entry_index(lore_key, item_key)
        entry = self.lore_items[lore_key][entry_index]
        
        # Increment stat if this was a new lore item
        if is_new:
            self.stats["lore_found"]["Prayer Strip"] = self.stats["lore_found"].get("Prayer Strip", 0) + 1
            # Add to lore codex for permanent access
            self.lore_codex.append({
                "type": "prayer_strip",
                "title": "Prayer Strip",
                "subtitle": "",
                "content": entry["text"],
                "floor_found": self.floor
            })
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(550, 350, 0.6, 0.65)
        
        self.dialog_frame = tk.Frame(self.game_frame, bg=self.current_colors["bg_panel"],
                                      relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center',
                                width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="▼ PRAYER STRIP ▼",
                font=('Arial', 16, 'bold'), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_title", "#daa520")).pack(pady=10)
        
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors.get("text_accent", "#4ecdc4")).pack(fill=tk.X, padx=30, pady=10)
        
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        text_frame.pack(pady=10, padx=30, fill=tk.BOTH, expand=True)
        
        tk.Label(text_frame, text=entry["text"],
                font=('Arial', 12), bg=self.current_colors["bg_panel"],
                fg=self.current_colors.get("text_primary", "#ffffff"),
                wraplength=dialog_width-80, justify=tk.LEFT).pack()
        
        tk.Button(self.dialog_frame, text="Close",
                 command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        self.log(f"Read the prayer strip... The cult's devotion was absolute and terrifying.", 'lore')
    
    def show_character_status(self):
        """Show comprehensive character status with tabbed interface - delegated to ui_character_menu"""
        ui_character_menu.show_character_status(self)
    
    def close_dialog(self):
        """Close dialog"""
        if self.dialog_frame and self.dialog_frame.winfo_exists():
            self.dialog_frame.destroy()
            self.dialog_frame = None
            # Re-apply keybindings to ensure they work after dialog closes
            self.apply_keybindings()
    
    def close_dialog_and_refresh_inventory(self):
        """Close dialog and refresh inventory (for lore items)"""
        self.close_dialog()
        self.show_inventory()
    
    def show_key_usage_dialog(self, key_type, callback):
        """Show in-game dialog for using keys (Old Key or Boss Key)"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=500, height=300)
        
        if key_type == "Old Key":
            title = "⚿ LOCKED ELITE ROOM"
            message = "The door is sealed with an ancient lock.\n\nYou have an Old Key that fits!\n\nUse the key to unlock and enter,\nor turn back and save it for later?"
        else:  # Boss Key
            title = "☠ LOCKED BOSS ROOM"
            message = "The boss chamber door is sealed shut.\n\nYou have all 3 Boss Key Fragments!\n\nForge them to unlock the door and\nface the floor boss, or turn back?"
        
        tk.Label(self.dialog_frame, text=title, font=('Arial', 18, 'bold'),
                bg='#1a0f08', fg='#ffd700', pady=20).pack()
        
        tk.Label(self.dialog_frame, text=message, font=('Arial', 12),
                bg='#1a0f08', fg='#ffffff', pady=10, justify=tk.CENTER).pack()
        
        # Button frame
        btn_frame = tk.Frame(self.dialog_frame, bg='#1a0f08')
        btn_frame.pack(pady=20)
        
        def use_key():
            self.close_dialog()
            callback(True)
        
        def keep_key():
            self.close_dialog()
            callback(False)
        
        tk.Button(btn_frame, text="Unlock & Enter", command=use_key,
                 font=('Arial', 14, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=14, pady=10).pack(side=tk.LEFT, padx=10)
        
        tk.Button(btn_frame, text="Turn Back", command=keep_key,
                 font=('Arial', 14, 'bold'), bg='#ff6b6b', fg='#000000',
                 width=14, pady=10).pack(side=tk.LEFT, padx=10)
    
    def confirm_quit(self):
        """Confirm quit to menu"""
        if messagebox.askyesno("Quit Game", "Return to main menu? Any unsaved progress will be lost."):
            self.game_active = False
            self.close_dialog()
            self.show_main_menu()
    
    def show_save_slots(self):
        """Show unified save/load menu in save mode"""
        self.show_unified_save_load_menu(mode="save")
    
    def show_load_slots(self):
        """Show unified save/load menu in load mode"""
        self.show_unified_save_load_menu(mode="load")
    
    def show_unified_save_load_menu(self, mode="load"):
        """Unified save/load menu - handles both operations in one interface
        
        Args:
            mode: "save" or "load" - determines default action for Enter key
        """
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=950, height=700)
        
        # Track current mode and selected slot
        self.save_load_mode = mode
        self.selected_slot = None
        self.selected_slot_frame = None
        
        # Title
        title_text = "SAVE GAME" if mode == "save" else "LOAD GAME"
        tk.Label(self.dialog_frame, text=title_text, font=('Arial', 18, 'bold'),
                bg='#1a0f08', fg='#ffd700', pady=10).pack()
        
        # Main content frame (left list + right details)
        content_frame = tk.Frame(self.dialog_frame, bg='#1a0f08')
        content_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
        
        # LEFT PANEL - Save slot list
        left_panel = tk.Frame(content_frame, bg='#2c1810', relief=tk.SUNKEN, borderwidth=2)
        left_panel.pack(side=tk.LEFT, fill=tk.BOTH, expand=False, padx=(0, 5))
        left_panel.config(width=380)
        
        tk.Label(left_panel, text="Save Slots", font=('Arial', 12, 'bold'),
                bg='#2c1810', fg='#ffd700', pady=5).pack()
        
        # Scrollable list of saves
        list_canvas = tk.Canvas(left_panel, bg='#2c1810', highlightthickness=0, width=360)
        list_scrollbar = tk.Scrollbar(left_panel, orient="vertical", command=list_canvas.yview, width=10,
                                     bg='#2c1810', troughcolor='#1a0f08')
        self.slots_list_frame = tk.Frame(list_canvas, bg='#2c1810')
        
        self.slots_list_frame.bind("<Configure>", lambda e: list_canvas.configure(scrollregion=list_canvas.bbox("all")))
        list_canvas.create_window((0, 0), window=self.slots_list_frame, anchor="nw", width=340)
        list_canvas.configure(yscrollcommand=list_scrollbar.set)
        
        self.setup_mousewheel_scrolling(list_canvas)
        
        list_canvas.pack(side="left", fill="both", expand=True, padx=5, pady=5)
        list_scrollbar.pack(side="right", fill="y", pady=5)
        
        # RIGHT PANEL - Selected save details (scrollable)
        details_container = tk.Frame(content_frame, bg='#2c1810', relief=tk.SUNKEN, borderwidth=2)
        details_container.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        details_canvas = tk.Canvas(details_container, bg='#2c1810', highlightthickness=0)
        details_scrollbar = tk.Scrollbar(details_container, orient="vertical", command=details_canvas.yview, width=10,
                                        bg='#2c1810', troughcolor='#1a0f08')
        self.details_panel = tk.Frame(details_canvas, bg='#2c1810')
        
        self.details_panel.bind("<Configure>", lambda e: details_canvas.configure(scrollregion=details_canvas.bbox("all")))
        details_canvas.create_window((0, 0), window=self.details_panel, anchor="nw")
        details_canvas.configure(yscrollcommand=details_scrollbar.set)
        
        self.setup_mousewheel_scrolling(details_canvas)
        
        details_canvas.pack(side="left", fill="both", expand=True, padx=5, pady=5)
        details_scrollbar.pack(side="right", fill="y", pady=5)
        
        tk.Label(self.details_panel, text="Select a save slot", font=('Arial', 14),
                bg='#2c1810', fg='#888888', pady=180).pack()
        
        # Create save slot list items
        self.slot_widgets = {}
        for slot_num in range(1, 11):
            self._create_unified_slot_item(slot_num)
        
        # Bind mousewheel to all child widgets in slots list
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                list_canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(self.slots_list_frame)
        
        # Bind mousewheel to details panel
        def bind_details_mousewheel(widget):
            def on_mousewheel(event):
                details_canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_details_mousewheel(child)
        bind_details_mousewheel(self.details_panel)
        
        # Bottom buttons
        btn_frame = tk.Frame(self.dialog_frame, bg='#1a0f08')
        btn_frame.pack(pady=10)
        
        tk.Button(btn_frame, text="Back", command=self.close_dialog,
                 font=('Arial', 12), bg='#ff6b6b', fg='#000000',
                 width=15, pady=10).pack()
        
        # Bind keyboard shortcuts
        self.dialog_frame.bind('<Up>', lambda e: self._navigate_slots(-1))
        self.dialog_frame.bind('<Down>', lambda e: self._navigate_slots(1))
        self.dialog_frame.bind('<Return>', lambda e: self._default_action())
        self.dialog_frame.bind('<Delete>', lambda e: self._delete_selected_slot())
        self.dialog_frame.bind('<F2>', lambda e: self._rename_selected_slot())
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog())
        self.dialog_frame.focus_set()
    
    def _disable_menu_keybinds(self):
        """Disable menu keybindings when typing in entry fields"""
        if hasattr(self, 'dialog_frame') and self.dialog_frame:
            self.dialog_frame.unbind('<Up>')
            self.dialog_frame.unbind('<Down>')
            self.dialog_frame.unbind('<Return>')
            self.dialog_frame.unbind('<Delete>')
            self.dialog_frame.unbind('<F2>')
            self.dialog_frame.unbind('<Escape>')
    
    def _enable_menu_keybinds(self):
        """Re-enable menu keybindings after leaving entry fields"""
        if hasattr(self, 'dialog_frame') and self.dialog_frame:
            self.dialog_frame.bind('<Up>', lambda e: self._navigate_slots(-1))
            self.dialog_frame.bind('<Down>', lambda e: self._navigate_slots(1))
            self.dialog_frame.bind('<Return>', lambda e: self._default_action())
            self.dialog_frame.bind('<Delete>', lambda e: self._delete_selected_slot())
            self.dialog_frame.bind('<F2>', lambda e: self._rename_selected_slot())
            self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog())
            self.dialog_frame.focus_set()
    
    def _create_unified_slot_item(self, slot_num):
        """Create a list item for a save slot in the unified menu"""
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{slot_num}.json')
        
        # Check if save exists
        is_occupied = os.path.exists(save_file)
        save_data = None
        
        if is_occupied:
            try:
                with open(save_file, 'r') as f:
                    save_data = json.load(f)
            except:
                is_occupied = False
        
        # Create clickable slot item
        slot_item = tk.Frame(self.slots_list_frame, bg='#3d2415', relief=tk.RAISED, 
                            borderwidth=2, cursor='hand2')
        slot_item.pack(fill=tk.X, padx=5, pady=3)
        self.slot_widgets[slot_num] = slot_item
        
        if is_occupied and save_data:
            # Slot with save data
            save_name = save_data.get('save_name', '')
            slot_label = f"Save {slot_num}"
            if save_name:
                slot_label += f": {save_name}"
            
            tk.Label(slot_item, text=slot_label, font=('Arial', 10, 'bold'),
                    bg='#3d2415', fg='#ffd700', anchor='w').pack(fill=tk.X, padx=8, pady=(5, 2))
            
            # Location
            floor = save_data.get('floor', 1)
            tk.Label(slot_item, text=f"Floor {floor} - The Depths", font=('Consolas', 8),
                    bg='#3d2415', fg='#4ecdc4', anchor='w').pack(fill=tk.X, padx=8, pady=(0, 2))
            
            # Stats
            health = save_data.get('health', 0)
            max_health = save_data.get('max_health', 0)
            gold = save_data.get('gold', 0)
            tk.Label(slot_item, text=f"HP: {health}/{max_health} | Gold: {gold}", 
                    font=('Consolas', 8),
                    bg='#3d2415', fg='#ffffff', anchor='w').pack(fill=tk.X, padx=8, pady=(0, 2))
            
            # Timestamp
            save_time = save_data.get('save_time', 'Unknown')
            tk.Label(slot_item, text=save_time, font=('Consolas', 7),
                    bg='#3d2415', fg='#888888', anchor='w').pack(fill=tk.X, padx=8, pady=(0, 5))
        else:
            # Empty slot
            tk.Label(slot_item, text=f"Save {slot_num}", font=('Arial', 10, 'bold'),
                    bg='#3d2415', fg='#888888', anchor='w').pack(fill=tk.X, padx=8, pady=(5, 2))
            
            tk.Label(slot_item, text="[Empty Slot]", font=('Arial', 9),
                    bg='#3d2415', fg='#666666', anchor='w').pack(fill=tk.X, padx=8, pady=(0, 5))
        
        # Bind click to select this slot
        slot_item.bind('<Button-1>', lambda e, s=slot_num: self._select_slot(s))
        for widget in slot_item.winfo_children():
            widget.bind('<Button-1>', lambda e, s=slot_num: self._select_slot(s))
    
    def _select_slot(self, slot_num):
        """Select a save slot and show its details"""
        # Unhighlight previous selection
        if self.selected_slot_frame and self.selected_slot in self.slot_widgets:
            self.slot_widgets[self.selected_slot].config(bg='#3d2415', relief=tk.RAISED)
            for widget in self.slot_widgets[self.selected_slot].winfo_children():
                widget.config(bg='#3d2415')
        
        # Highlight new selection
        self.selected_slot = slot_num
        self.selected_slot_frame = self.slot_widgets[slot_num]
        self.selected_slot_frame.config(bg='#5d3425', relief=tk.SUNKEN)
        for widget in self.selected_slot_frame.winfo_children():
            widget.config(bg='#5d3425')
        
        # Show details
        self._show_slot_details(slot_num)
    
    def _show_slot_details(self, slot_num):
        """Display detailed info for selected save slot"""
        # Clear details panel
        for widget in self.details_panel.winfo_children():
            widget.destroy()
        
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{slot_num}.json')
        
        is_occupied = os.path.exists(save_file)
        save_data = None
        
        if is_occupied:
            try:
                with open(save_file, 'r') as f:
                    save_data = json.load(f)
            except:
                is_occupied = False
        
        # Header
        tk.Label(self.details_panel, text=f"Save Slot {slot_num}", font=('Arial', 16, 'bold'),
                bg='#2c1810', fg='#ffd700', pady=10).pack(anchor='center')
        
        # Details frame
        details = tk.Frame(self.details_panel, bg='#2c1810')
        details.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        if is_occupied and save_data:
            # Show existing save details
            save_name = save_data.get('save_name', '(Unnamed Save)')
            
            # Custom name - on same line
            name_line = tk.Frame(details, bg='#2c1810')
            name_line.pack(fill=tk.X, pady=(0, 10))
            tk.Label(name_line, text="Save Name: ", font=('Arial', 10, 'bold'),
                    bg='#2c1810', fg='#ffd700', anchor='w').pack(side=tk.LEFT)
            tk.Label(name_line, text=save_name if save_name else "(Unnamed Save)", 
                    font=('Arial', 10), bg='#2c1810', fg='#ffffff', anchor='w').pack(side=tk.LEFT)
            
            # Location - on same line
            floor = save_data.get('floor', 1)
            location_line = tk.Frame(details, bg='#2c1810')
            location_line.pack(fill=tk.X, pady=(0, 15))
            tk.Label(location_line, text="Current Location: ", font=('Arial', 10, 'bold'),
                    bg='#2c1810', fg='#ffd700', anchor='w').pack(side=tk.LEFT)
            tk.Label(location_line, text=f"Floor {floor} - The Depths", font=('Arial', 10),
                    bg='#2c1810', fg='#ffffff', anchor='w').pack(side=tk.LEFT)
            
            # Character stats
            tk.Label(details, text="Character Stats:", font=('Arial', 10, 'bold'),
                    bg='#2c1810', fg='#ffd700', anchor='w').pack(fill=tk.X, pady=(0, 5))
            
            stats_frame = tk.Frame(details, bg='#3d2415', relief=tk.SUNKEN, borderwidth=1)
            stats_frame.pack(fill=tk.X, pady=(0, 10))
            
            health = save_data.get('health', 0)
            max_health = save_data.get('max_health', 0)
            gold = save_data.get('gold', 0)
            score = save_data.get('run_score', 0)
            
            tk.Label(stats_frame, text=f"HP: {health} / {max_health}", font=('Consolas', 11),
                    bg='#3d2415', fg='#ffffff', anchor='w').pack(fill=tk.X, padx=10, pady=3)
            tk.Label(stats_frame, text=f"Gold: {gold}", font=('Consolas', 11),
                    bg='#3d2415', fg='#ffd700', anchor='w').pack(fill=tk.X, padx=10, pady=3)
            tk.Label(stats_frame, text=f"Score: {score}", font=('Consolas', 11),
                    bg='#3d2415', fg='#4ecdc4', anchor='w').pack(fill=tk.X, padx=10, pady=3)
            
            # Last accessed - on same line
            save_time = save_data.get('save_time', 'Unknown time')
            time_line = tk.Frame(details, bg='#2c1810')
            time_line.pack(fill=tk.X, pady=(5, 15))
            tk.Label(time_line, text="Last Saved: ", font=('Arial', 10, 'bold'),
                    bg='#2c1810', fg='#ffd700', anchor='w').pack(side=tk.LEFT)
            tk.Label(time_line, text=save_time, font=('Arial', 10),
                    bg='#2c1810', fg='#ffffff', anchor='w').pack(side=tk.LEFT)
            
            # Rename section
            rename_frame = tk.Frame(details, bg='#2c1810')
            rename_frame.pack(fill=tk.X, pady=(10, 15))
            
            tk.Label(rename_frame, text="Rename Save:", font=('Arial', 9, 'bold'),
                    bg='#2c1810', fg='#ffd700').pack(anchor='w')
            
            name_input_frame = tk.Frame(rename_frame, bg='#2c1810')
            name_input_frame.pack(fill=tk.X, pady=(5, 0))
            
            self.rename_entry = tk.Entry(name_input_frame, font=('Arial', 10), width=25)
            self.rename_entry.insert(0, save_name)
            self.rename_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
            
            # Unbind keybindings when entry is focused, rebind when unfocused
            self.rename_entry.bind('<FocusIn>', lambda e: self._disable_menu_keybinds())
            self.rename_entry.bind('<FocusOut>', lambda e: self._enable_menu_keybinds())
            
            tk.Button(name_input_frame, text="Rename", 
                     command=lambda: self._rename_slot(slot_num, self.rename_entry.get().strip()),
                     font=('Arial', 9), bg='#ffd700', fg='#000000',
                     width=10, pady=3).pack(side=tk.LEFT)
            
            # Spacer
            tk.Frame(details, bg='#2c1810', height=20).pack()
            
            # Action buttons in one centered row
            action_frame = tk.Frame(details, bg='#2c1810')
            action_frame.pack(pady=10)
            
            # Determine which button should be highlighted based on mode
            load_bg = '#4ecdc4' if self.save_load_mode == 'load' else '#3a9b93'
            save_bg = '#ff9f43' if self.save_load_mode == 'save' else '#cc7f36'
            
            # Load button (always available for occupied slots)
            load_btn = tk.Button(action_frame, text="Load", 
                     command=lambda: self.load_from_slot(slot_num),
                     font=('Arial', 10, 'bold'), bg=load_bg, fg='#000000',
                     width=14, pady=8)
            load_btn.pack(side=tk.LEFT, padx=5)
            
            # Save/Overwrite button (only enabled if in game and not in combat)
            in_game = hasattr(self, 'current_room') and self.current_room is not None
            can_save = in_game and not self.in_combat
            
            button_text = "Save/Overwrite" if can_save else ("Cannot Save During Combat" if self.in_combat else "Save/Overwrite")
            button_fg = '#000000' if can_save else '#ffffff'
            button_bg = save_bg if can_save else ('#8B0000' if self.in_combat else '#666666')
            overwrite_btn = tk.Button(action_frame, text=button_text, 
                     command=lambda: self._confirm_overwrite(slot_num),
                     font=('Arial', 10, 'bold'), bg=button_bg, fg=button_fg,
                     width=22, pady=8)
            overwrite_btn.pack(side=tk.LEFT, padx=5)
            if not can_save:
                overwrite_btn.config(state='disabled')
            
            # Delete button
            tk.Button(action_frame, text="Delete", 
                     command=lambda: self._confirm_delete(slot_num),
                     font=('Arial', 10), bg='#ff6b6b', fg='#000000',
                     width=14, pady=8).pack(side=tk.LEFT, padx=5)
            
        else:
            # Empty slot
            tk.Label(details, text="Empty Slot", font=('Arial', 14, 'bold'),
                    bg='#2c1810', fg='#888888', pady=20).pack()
            
            tk.Label(details, text="No save data in this slot.\nYou can save your current game here.", 
                    font=('Arial', 10), bg='#2c1810', fg='#666666', 
                    justify=tk.CENTER, pady=10).pack()
            
            # Spacer
            tk.Frame(details, bg='#2c1810', height=30).pack()
            
            # Action buttons for empty slot
            action_frame = tk.Frame(details, bg='#2c1810')
            action_frame.pack(fill=tk.X, pady=20)
            
            # Only allow saving if currently in a game and not in combat
            in_game = hasattr(self, 'current_room') and self.current_room is not None
            can_save = in_game and not self.in_combat
            
            button_text = "Save to This Slot" if can_save else ("Cannot Save During Combat" if self.in_combat else "Save to This Slot")
            button_fg = '#000000' if can_save else '#ffffff'
            save_bg = '#4ecdc4' if can_save else ('#8B0000' if self.in_combat else '#666666')
            save_btn = tk.Button(action_frame, text=button_text, 
                     command=lambda: self._save_to_empty_slot(slot_num),
                     font=('Arial', 12, 'bold'), bg=save_bg, fg=button_fg,
                     width=25, pady=12)
            save_btn.pack()
            if not can_save:
                save_btn.config(state='disabled')
                if not in_game:
                    tk.Label(action_frame, text="(No game in progress)", 
                            font=('Arial', 9, 'italic'), bg='#2c1810', fg='#888888',
                            pady=10).pack()
                elif self.in_combat:
                    tk.Label(action_frame, text="(Cannot save during combat)", 
                            font=('Arial', 9, 'italic'), bg='#2c1810', fg='#ff6b6b',
                            pady=10).pack()
    
    def _navigate_slots(self, direction):
        """Navigate up/down through save slots with arrow keys"""
        if not hasattr(self, 'selected_slot') or self.selected_slot is None:
            self._select_slot(1)
            return
        
        new_slot = self.selected_slot + direction
        if 1 <= new_slot <= 10:
            self._select_slot(new_slot)
    
    def _default_action(self):
        """Execute default action based on mode (Enter key)"""
        if not hasattr(self, 'selected_slot') or self.selected_slot is None:
            return
        
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{self.selected_slot}.json')
        is_occupied = os.path.exists(save_file)
        
        if self.save_load_mode == "save":
            # Save mode: default action is save/overwrite
            if is_occupied:
                self._confirm_overwrite(self.selected_slot)
            else:
                self._save_to_empty_slot(self.selected_slot)
        else:
            # Load mode: default action is load (only if occupied)
            if is_occupied:
                self.load_from_slot(self.selected_slot)
    
    def _delete_selected_slot(self):
        """Delete currently selected slot (Delete key)"""
        if hasattr(self, 'selected_slot') and self.selected_slot:
            self._confirm_delete(self.selected_slot)
    
    def _rename_selected_slot(self):
        """Focus rename entry for selected slot (F2 key)"""
        if hasattr(self, 'rename_entry'):
            self.rename_entry.focus_set()
            self.rename_entry.select_range(0, tk.END)
    
    def _save_to_empty_slot(self, slot_num):
        """Save to an empty slot"""
        # Get custom name if rename entry exists and is still valid
        custom_name = ""
        try:
            if hasattr(self, 'rename_entry') and self.rename_entry.winfo_exists():
                custom_name = self.rename_entry.get().strip()
        except:
            pass
        
        self.save_to_slot(slot_num, custom_name)
        self.close_dialog()
    
    def _confirm_overwrite(self, slot_num):
        """Show in-game confirmation overlay before overwriting"""
        # Store the custom name if available
        custom_name = ""
        try:
            if hasattr(self, 'rename_entry') and self.rename_entry.winfo_exists():
                custom_name = self.rename_entry.get().strip()
        except:
            pass
        
        # Create confirmation overlay inside the game window
        confirm_overlay = tk.Frame(self.dialog_frame, bg='#1a0f0a', relief=tk.RIDGE, borderwidth=3)
        confirm_overlay.place(relx=0.5, rely=0.5, anchor='center', width=500, height=250)
        confirm_overlay.lift()
        
        # Warning message
        tk.Label(confirm_overlay, text="⚠ OVERWRITE SAVE? ⚠",
                font=('Arial', 18, 'bold'), bg='#1a0f0a', fg='#ff6b6b',
                pady=20).pack()
        
        tk.Label(confirm_overlay, 
                text=f"Are you sure you want to overwrite Save Slot {slot_num}?\n\nThis will replace the existing save data.",
                font=('Arial', 12), bg='#1a0f0a', fg='#d4a574',
                pady=10, justify='center').pack()
        
        # Button frame
        btn_frame = tk.Frame(confirm_overlay, bg='#1a0f0a')
        btn_frame.pack(pady=20)
        
        def do_overwrite():
            confirm_overlay.destroy()
            self.save_to_slot(slot_num, custom_name)
            self.close_dialog()
        
        def cancel():
            confirm_overlay.destroy()
        
        tk.Button(btn_frame, text="YES, OVERWRITE",
                 command=do_overwrite,
                 font=('Arial', 12, 'bold'), bg='#ff6b6b', fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=10)
        
        tk.Button(btn_frame, text="CANCEL",
                 command=cancel,
                 font=('Arial', 12, 'bold'), bg='#666666', fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=10)
        
        # Bind Escape key to cancel
        confirm_overlay.bind('<Escape>', lambda e: cancel())
        confirm_overlay.focus_set()
    
    def _confirm_delete(self, slot_num):
        """Show in-game confirmation submenu before deleting"""
        # Create confirmation submenu
        confirm_dialog = tk.Toplevel(self.root)
        confirm_dialog.title("Delete Save?")
        confirm_dialog.configure(bg='#1a0f0a')
        confirm_dialog.geometry('500x250')
        
        # Center the dialog
        confirm_dialog.update_idletasks()
        x = (confirm_dialog.winfo_screenwidth() // 2) - (500 // 2)
        y = (confirm_dialog.winfo_screenheight() // 2) - (250 // 2)
        confirm_dialog.geometry(f'500x250+{x}+{y}')
        confirm_dialog.transient(self.root)
        confirm_dialog.grab_set()
        
        # Warning message
        tk.Label(confirm_dialog, text="⚠ DELETE SAVE? ⚠",
                font=('Arial', 18, 'bold'), bg='#1a0f0a', fg='#ff6b6b',
                pady=20).pack()
        
        tk.Label(confirm_dialog, 
                text=f"Are you sure you want to delete Save Slot {slot_num}?\n\nThis cannot be undone.",
                font=('Arial', 12), bg='#1a0f0a', fg='#d4a574',
                pady=10, justify='center').pack()
        
        # Button frame
        btn_frame = tk.Frame(confirm_dialog, bg='#1a0f0a')
        btn_frame.pack(pady=20)
        
        def do_delete():
            confirm_dialog.destroy()
            self.delete_save_slot(slot_num)
            # Refresh the menu
            self.show_unified_save_load_menu(self.save_load_mode)
        
        def cancel():
            confirm_dialog.destroy()
        
        tk.Button(btn_frame, text="YES, DELETE",
                 command=do_delete,
                 font=('Arial', 12, 'bold'), bg='#ff6b6b', fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=10)
        
        tk.Button(btn_frame, text="CANCEL",
                 command=cancel,
                 font=('Arial', 12, 'bold'), bg='#666666', fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=10)
        
        # Bind Escape key to cancel
        confirm_dialog.bind('<Escape>', lambda e: cancel())
    
    def _rename_slot(self, slot_num, new_name):
        """Rename a save slot"""
        self.update_save_name(slot_num, new_name)
        # Refresh the menu
        self.show_unified_save_load_menu(self.save_load_mode)
    
    def _create_save_slot_button(self, parent, slot_num):
        """Create a button for a save slot with custom name input"""
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{slot_num}.json')
        
        slot_frame = tk.Frame(parent, bg='#3d2415', relief=tk.RIDGE, borderwidth=2)
        slot_frame.pack(fill=tk.X, padx=5, pady=5)
        
        # Check if save exists
        save_name = ""
        if os.path.exists(save_file):
            try:
                with open(save_file, 'r') as f:
                    save_data = json.load(f)
                
                # Get save timestamp and custom name
                save_time = save_data.get('save_time', 'Unknown time')
                save_name = save_data.get('save_name', '')
                
                # Create info text
                name_display = f" '{save_name}'" if save_name else ""
                info_text = f"Slot {slot_num}{name_display} - Floor {save_data['floor']} | HP: {save_data['health']}/{save_data['max_health']} | Gold: {save_data['gold']}\n"
                info_text += f"Score: {save_data['run_score']} | Saved: {save_time}"
                
                tk.Label(slot_frame, text=info_text, font=('Consolas', 9),
                        bg='#3d2415', fg='#ffffff', justify=tk.LEFT, pady=5).pack(padx=10, anchor='w')
                
                btn_text = f"Save to Slot {slot_num} (Overwrite)"
                btn_color = '#ff9f43'
            except:
                info_text = f"Slot {slot_num} - Corrupted Save"
                tk.Label(slot_frame, text=info_text, font=('Consolas', 10),
                        bg='#3d2415', fg='#ff6b6b', pady=5).pack(padx=10, anchor='w')
                btn_text = f"Save to Slot {slot_num}"
                btn_color = '#4ecdc4'
        else:
            info_text = f"Slot {slot_num} - Empty"
            tk.Label(slot_frame, text=info_text, font=('Consolas', 10),
                    bg='#3d2415', fg='#888888', pady=5).pack(padx=10, anchor='w')
            btn_text = f"Save to Slot {slot_num}"
            btn_color = '#4ecdc4'
        
        # Name input field
        name_frame = tk.Frame(slot_frame, bg='#3d2415')
        name_frame.pack(padx=10, pady=(0, 5))
        
        tk.Label(name_frame, text="Name (optional):", font=('Arial', 9),
                bg='#3d2415', fg='#ffffff').pack(side=tk.LEFT, padx=(0, 5))
        
        name_entry = tk.Entry(name_frame, font=('Arial', 9), width=30)
        name_entry.insert(0, save_name)
        name_entry.pack(side=tk.LEFT)
        
        tk.Button(slot_frame, text=btn_text, 
                 command=lambda: self.save_to_slot(slot_num, name_entry.get().strip()),
                 font=('Arial', 10, 'bold'), bg=btn_color, fg='#000000',
                 width=25, pady=8).pack(padx=10, pady=5)
    
    def save_to_slot(self, slot_num, save_name=""):
        """Save game to specific slot with optional custom name"""
        # Prevent saving during combat (exploit prevention) - UI already blocks this but double check
        if self.in_combat:
            return
        
        try:
            import datetime
            
            # Serialize room data from the dungeon dictionary
            rooms_data = {}
            for pos, room in self.dungeon.items():
                rooms_data[f"{pos[0]},{pos[1]}"] = {
                    'room_data': room.data,  # Save complete room data
                    'x': room.x,
                    'y': room.y,
                    'visited': room.visited,
                    'cleared': room.cleared,
                    'has_stairs': room.has_stairs,
                    'has_chest': room.has_chest,
                    'chest_looted': room.chest_looted,
                    'enemies_defeated': room.enemies_defeated,
                    'has_combat': getattr(room, 'has_combat', None),
                    'exits': room.exits.copy(),
                    'blocked_exits': room.blocked_exits.copy(),
                    'collected_discoverables': room.collected_discoverables.copy(),
                    'uncollected_items': getattr(room, 'uncollected_items', []).copy(),
                    'dropped_items': getattr(room, 'dropped_items', []).copy(),
                    'is_mini_boss_room': getattr(room, 'is_mini_boss_room', False),
                    'is_boss_room': getattr(room, 'is_boss_room', False),
                    'ground_container': getattr(room, 'ground_container', None),
                    'ground_items': getattr(room, 'ground_items', []).copy(),
                    'ground_gold': getattr(room, 'ground_gold', 0),
                    'container_searched': getattr(room, 'container_searched', False),
                    'container_locked': getattr(room, 'container_locked', False)
                }
            
            save_data = {
                'save_time': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                'slot_num': slot_num,
                'save_name': save_name,
                'gold': self.gold,
                'health': self.health,
                'max_health': self.max_health,
                'max_inventory': self.max_inventory,
                'floor': self.floor,
                'run_score': self.run_score,
                'total_gold_earned': self.total_gold_earned,
                'rooms_explored': self.rooms_explored,
                'enemies_killed': self.enemies_killed,
                'chests_opened': self.chests_opened,
                'inventory': self.inventory.copy(),
                'equipped_items': self.equipped_items.copy(),
                'equipment_durability': self.equipment_durability.copy(),
                'equipment_floor_level': self.equipment_floor_level.copy(),
                'adventure_log': self.adventure_log.copy(),  # Save adventure log
                'num_dice': self.num_dice,
                'multiplier': self.multiplier,
                'damage_bonus': self.damage_bonus,
                'heal_bonus': self.heal_bonus,
                'reroll_bonus': self.reroll_bonus,
                'crit_chance': self.crit_chance,
                'flags': self.flags.copy(),
                'temp_effects': self.temp_effects.copy(),
                'temp_shield': self.temp_shield,
                'shop_discount': self.shop_discount,
                'stairs_found': self.stairs_found,
                'rest_cooldown': self.rest_cooldown,
                'current_pos': list(self.current_pos),
                'rooms': rooms_data,
                'store_found': self.store_found,
                'store_position': list(self.store_position) if self.store_position else None,
                # Boss tracking
                'mini_bosses_defeated': self.mini_bosses_defeated,
                'boss_defeated': self.boss_defeated,
                'mini_bosses_spawned_this_floor': self.mini_bosses_spawned_this_floor,
                'boss_spawned_this_floor': self.boss_spawned_this_floor,
                'rooms_explored_on_floor': self.rooms_explored_on_floor,
                'next_mini_boss_at': self.next_mini_boss_at,
                'next_boss_at': self.next_boss_at,
                'key_fragments_collected': getattr(self, 'key_fragments_collected', 0),
                'special_rooms': {f"{k[0]},{k[1]}": v for k, v in self.special_rooms.items()},
                'unlocked_rooms': [f"{k[0]},{k[1]}" for k in self.unlocked_rooms],
                # Save lore item persistence (new format)
                'used_lore_entries': {k: v.copy() for k, v in self.used_lore_entries.items()},
                'discovered_lore_items': self.discovered_lore_items.copy(),
                'lore_item_assignments': self.lore_item_assignments.copy(),
                'lore_item_counters': self.lore_item_counters.copy(),
                'lore_codex': self.lore_codex.copy(),  # Save discovered lore entries
                # Save settings with the game
                'settings': {
                    'color_scheme': self.settings.get('color_scheme', 'Classic'),
                    'difficulty': self.settings.get('difficulty', 'Normal'),
                    'text_speed': self.settings.get('text_speed', 'Medium'),
                    'keybindings': self.settings.get('keybindings', {
                        "inventory": "Tab",
                        "menu": "m",
                        "rest": "r",
                        "move_north": "w",
                        "move_south": "s",
                        "move_east": "d",
                        "move_west": "a"
                    })
                },
                # Save comprehensive stats
                'stats': self.stats.copy(),
                # Save purchased upgrades for current floor
                'purchased_upgrades_this_floor': list(self.purchased_upgrades_this_floor),
                # Save starter area tracking
                'in_starter_area': getattr(self, 'in_starter_area', False),
                'starter_chests_opened': getattr(self, 'starter_chests_opened', []).copy() if hasattr(self, 'starter_chests_opened') else [],
                'signs_read': getattr(self, 'signs_read', []).copy() if hasattr(self, 'signs_read') else [],
                'starter_rooms': [list(pos) for pos in getattr(self, 'starter_rooms', set())]
            }
            
            save_file = os.path.join(self.saves_dir, 
                                     f'dice_dungeon_save_slot_{slot_num}.json')
            
            with open(save_file, 'w') as f:
                json.dump(save_data, f, indent=2)
            
            # Update current save slot
            self.current_save_slot = slot_num
            
            # Clear and reinitialize the slot-specific debug log
            try:
                debug_log_file = os.path.join(self.saves_dir, 
                                             f'adventure_log_slot_{slot_num}.txt')
                with open(debug_log_file, 'w', encoding='utf-8') as f:
                    import datetime
                    f.write(f"=== SAVE SLOT {slot_num} - SAVED: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n\n")
                    # Write all existing log entries
                    for message, tag in self.adventure_log:
                        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
                        f.write(f"[{timestamp}] [{tag.upper()}] {message}\n")
            except:
                pass
            
            self.log(f"⚡ Game saved to Slot {slot_num}!", 'system')
            self.close_dialog()
        except Exception as e:
            messagebox.showerror("Save Error", f"Failed to save game: {str(e)}")
    
    def save_game(self):
        """Show save slot selection"""
        self.show_save_slots()
    
    def update_save_name(self, slot_num, new_name):
        """Update the custom name of a save file"""
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{slot_num}.json')
        try:
            # Load existing save data
            with open(save_file, 'r') as f:
                save_data = json.load(f)
            
            # Update the name
            save_data['save_name'] = new_name
            
            # Write back to file
            with open(save_file, 'w') as f:
                json.dump(save_data, f, indent=2)
            
            # Refresh the load screen to show updated name
            self.show_load_slots()
            
        except Exception as e:
            messagebox.showerror("Update Error", f"Failed to update save name: {str(e)}")
    
    def delete_save_slot(self, slot_num):
        """Delete a save slot"""
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{slot_num}.json')
        try:
            os.remove(save_file)
            self.show_load_slots()  # Refresh the list
        except Exception as e:
            messagebox.showerror("Delete Error", f"Failed to delete save: {str(e)}")
    
    def load_from_slot(self, slot_num):
        """Load game from specific slot"""
        save_file = os.path.join(self.saves_dir, 
                                 f'dice_dungeon_save_slot_{slot_num}.json')
        
        try:
            with open(save_file, 'r') as f:
                save_data = json.load(f)
            
            # Restore player stats
            self.gold = save_data['gold']
            self.health = save_data['health']
            self.max_health = save_data['max_health']
            self.floor = save_data['floor']
            self.run_score = save_data['run_score']
            self.total_gold_earned = save_data['total_gold_earned']
            self.rooms_explored = save_data['rooms_explored']
            self.enemies_killed = save_data['enemies_killed']
            self.chests_opened = save_data['chests_opened']
            self.inventory = save_data['inventory']
            self.equipped_items = save_data.get('equipped_items', {
                "weapon": None,
                "armor": None,
                "accessory": None,
                "backpack": None
            })
            # Ensure backpack slot exists for old saves
            if "backpack" not in self.equipped_items:
                self.equipped_items["backpack"] = None
            self.equipment_durability = save_data.get('equipment_durability', {})
            self.equipment_floor_level = save_data.get('equipment_floor_level', {})
            # Restore adventure log (UI population happens after setup_game_ui)
            self.adventure_log = save_data.get('adventure_log', [])
            
            # Set current save slot
            self.current_save_slot = slot_num
            
            # Initialize slot-specific debug log
            try:
                debug_log_file = os.path.join(self.saves_dir, 
                                             f'adventure_log_slot_{slot_num}.txt')
                with open(debug_log_file, 'w', encoding='utf-8') as f:
                    import datetime
                    f.write(f"=== SAVE SLOT {slot_num} - LOADED: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n\n")
                    # Write all existing log entries
                    for message, tag in self.adventure_log:
                        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
                        f.write(f"[{timestamp}] [{tag.upper()}] {message}\n")
            except:
                pass
            
            self.num_dice = save_data['num_dice']
            self.multiplier = save_data['multiplier']
            self.damage_bonus = save_data['damage_bonus']
            self.heal_bonus = save_data['heal_bonus']
            self.reroll_bonus = save_data['reroll_bonus']
            self.crit_chance = save_data['crit_chance']
            
            # ALWAYS recalculate equipment stats from equipped items to fix corrupted saves
            # Start with base values
            self.max_inventory = 10
            self.armor = 0
            
            # Add bonuses from currently equipped items
            for slot, item_name in self.equipped_items.items():
                if item_name and item_name in self.item_definitions:
                    item_def = self.item_definitions[item_name]
                    if 'inventory_bonus' in item_def:
                        self.max_inventory += item_def['inventory_bonus']
                    if 'armor_bonus' in item_def:
                        self.armor += item_def['armor_bonus']
            
            self.flags = save_data['flags']
            self.temp_effects = save_data['temp_effects']
            self.temp_shield = save_data['temp_shield']
            self.shop_discount = save_data['shop_discount']
            self.stairs_found = save_data.get('stairs_found', False)
            self.rest_cooldown = save_data.get('rest_cooldown', 0)
            
            # Restore boss tracking
            self.mini_bosses_defeated = save_data.get('mini_bosses_defeated', 0)
            self.boss_defeated = save_data.get('boss_defeated', False)
            self.mini_bosses_spawned_this_floor = save_data.get('mini_bosses_spawned_this_floor', 0)
            self.boss_spawned_this_floor = save_data.get('boss_spawned_this_floor', False)
            self.rooms_explored_on_floor = save_data.get('rooms_explored_on_floor', 0)
            
            # Restore boss spawn targets (set defaults for old saves)
            self.next_mini_boss_at = save_data.get('next_mini_boss_at', random.randint(6, 10))
            self.next_boss_at = save_data.get('next_boss_at', random.randint(20, 30) if self.floor >= 5 else None)
            
            # Restore key fragment counter (backward compatible with old saves)
            self.key_fragments_collected = save_data.get('key_fragments_collected', 0)
            
            # Compatibility fix: if all 3 mini-bosses defeated but no boss spawn target set, set it now
            if self.mini_bosses_defeated >= 3 and self.next_boss_at is None and not self.boss_defeated:
                self.next_boss_at = self.rooms_explored_on_floor + random.randint(4, 6)
                print(f"[SAVE COMPATIBILITY] Boss spawn target set to {self.next_boss_at} rooms (currently at {self.rooms_explored_on_floor})")
            
            # Restore special rooms tracking
            special_rooms_data = save_data.get('special_rooms', {})
            self.special_rooms = {}
            for pos_key, room_type in special_rooms_data.items():
                x, y = map(int, pos_key.split(','))
                self.special_rooms[(x, y)] = room_type
            
            # Restore unlocked rooms tracking
            unlocked_rooms_data = save_data.get('unlocked_rooms', [])
            self.unlocked_rooms = set()
            for pos_key in unlocked_rooms_data:
                x, y = map(int, pos_key.split(','))
                self.unlocked_rooms.add((x, y))
            
            # Restore lore item persistence (convert old format if needed)
            old_read_lore = save_data.get('read_lore_items', {})
            saved_used_entries = save_data.get('used_lore_entries', {})
            
            # Start with complete structure to ensure all categories exist
            self.used_lore_entries = {
                "guards_journal_pages": [],
                "quest_notices": [],
                "scrawled_notes": [],
                "training_manual_pages": [],
                "pressed_pages": [],
                "surgeons_notes": [],
                "puzzle_notes": [],
                "star_charts": [],
                "cracked_map_scraps": [],
                "old_letters": [],
                "prayer_strips": []
            }
            # Then update with saved values
            self.used_lore_entries.update(saved_used_entries)
            
            # Backward compatibility: if loading old save, initialize empty
            if old_read_lore and not save_data.get('used_lore_entries'):
                self.log("[SYSTEM] Converted old lore save format", 'system')
            
            self.discovered_lore_items = save_data.get('discovered_lore_items', [])
            self.lore_item_assignments = save_data.get('lore_item_assignments', {})
            self.lore_item_counters = save_data.get('lore_item_counters', {})
            self.lore_codex = save_data.get('lore_codex', [])  # Restore discovered lore entries
            
            # Migration: Fix old lore codex entries that might be missing type field
            type_mapping = {
                "Guard Journal": "guards_journal",
                "Quest Notice": "quest_notice",
                "Training Manual Page": "training_manual",
                "Scrawled Note": "scrawled_note",
                "Cracked Map Scrap": "map_scrap",
                "Pressed Page": "pressed_page",
                "Surgeon's Note": "surgeons_note",
                "Puzzle Note": "puzzle_note",
                "Star Chart": "star_chart",
                "Prayer Strip": "prayer_strip"
            }
            
            for entry in self.lore_codex:
                if "type" not in entry:
                    # Try to infer type from title
                    title = entry.get("title", "")
                    entry["type"] = type_mapping.get(title, "unknown")
                    self.log(f"[MIGRATION] Added type '{entry['type']}' to lore entry '{title}'", 'system')
            
            # Migration: Remove duplicate lore entries (same type, title, and content)
            seen = set()
            unique_codex = []
            for entry in self.lore_codex:
                # Create a unique key from type, title, and content
                key = (entry.get("type"), entry.get("title"), entry.get("content", "")[:100])
                if key not in seen:
                    seen.add(key)
                    unique_codex.append(entry)
                else:
                    self.log(f"[MIGRATION] Removed duplicate lore entry '{entry.get('title')}'", 'system')
            self.lore_codex = unique_codex
            
            # Restore store tracking
            self.store_found = save_data.get('store_found', False)
            store_pos = save_data.get('store_position', None)
            self.store_position = tuple(store_pos) if store_pos else None
            
            # DO NOT restore settings from save file - settings should always come from
            # the global settings file (dice_dungeon_settings.json) which persists
            # independently of game saves. This ensures color scheme, difficulty, and
            # keybindings remain consistent across all game sessions and saves.
            
            # Apply current settings (forced to Classic only)
            self.settings["color_scheme"] = "Classic"
            self.current_colors = self.color_schemes["Classic"]
            
            # Restore comprehensive stats (with defaults for old saves)
            if 'stats' in save_data:
                self.stats = save_data['stats']
                # Add missing fields for backward compatibility
                if "enemies_fled" not in self.stats:
                    self.stats["enemies_fled"] = 0
                if "rooms_explored" not in self.stats:
                    self.stats["rooms_explored"] = 0
                if "times_rested" not in self.stats:
                    self.stats["times_rested"] = 0
                # Ensure lore_found has all current types
                if "lore_found" not in self.stats:
                    self.stats["lore_found"] = {}
                for lore_type in ["Guard Journal", "Quest Notice", "Scrawled Note", "Training Manual Page", 
                                 "Pressed Page", "Surgeon's Note", "Puzzle Note", "Cracked Map Scrap",
                                 "Star Chart", "Old Letter", "Prayer Strip"]:
                    if lore_type not in self.stats["lore_found"]:
                        self.stats["lore_found"][lore_type] = 0
            else:
                # Initialize empty stats for old saves
                self.stats = {
                    "enemies_encountered": 0,
                    "enemies_fled": 0,
                    "enemies_defeated": 0,
                    "mini_bosses_defeated": 0,
                    "bosses_defeated": 0,
                    "total_damage_dealt": 0,
                    "total_damage_taken": 0,
                    "highest_single_damage": 0,
                    "critical_hits": 0,
                    "gold_found": 0,
                    "gold_spent": 0,
                    "items_purchased": 0,
                    "items_sold": 0,
                    "items_found": 0,
                    "items_used": 0,
                    "potions_used": 0,
                    "containers_searched": 0,
                    "weapons_broken": 0,
                    "armor_broken": 0,
                    "weapons_repaired": 0,
                    "armor_repaired": 0,
                    "rooms_explored": 0,
                    "times_rested": 0,
                    "lore_found": {
                        "Guard Journal": 0,
                        "Quest Notice": 0,
                        "Scrawled Note": 0,
                        "Training Manual Page": 0,
                        "Pressed Page": 0,
                        "Surgeon's Note": 0,
                        "Puzzle Note": 0,
                        "Cracked Map Scrap": 0,
                        "Star Chart": 0,
                        "Old Letter": 0,
                        "Prayer Strip": 0
                    },
                    "enemy_kills": {},
                    "most_damaged_enemy": {"name": "", "damage": 0},
                    "items_collected": {}  # Track all items ever collected
                }
            
            starter_rooms_data = save_data.get('starter_rooms', [])
            self.starter_rooms = set()
            for pos in starter_rooms_data:
                if isinstance(pos, list):
                    self.starter_rooms.add(tuple(pos))
                elif isinstance(pos, str):
                    x, y = map(int, pos.split(','))
                    self.starter_rooms.add((x, y))
            
            # Reset dice state
            self.dice_values = [0] * self.num_dice
            self.dice_locked = [False] * self.num_dice
            self.rolls_left = 3
            
            # Restore dungeon rooms from dictionary
            self.dungeon = {}
            for pos_key, room_save_data in save_data['rooms'].items():
                # Parse position from "x,y" format
                x, y = map(int, pos_key.split(','))
                
                # Recreate room with saved data
                room = Room(room_save_data['room_data'], room_save_data['x'], room_save_data['y'])
                room.visited = room_save_data['visited']
                room.cleared = room_save_data['cleared']
                room.has_stairs = room_save_data['has_stairs']
                room.has_chest = room_save_data['has_chest']
                room.chest_looted = room_save_data['chest_looted']
                room.enemies_defeated = room_save_data['enemies_defeated']
                room.has_combat = room_save_data.get('has_combat', None)
                room.exits = room_save_data['exits']
                room.blocked_exits = room_save_data['blocked_exits']
                room.collected_discoverables = room_save_data.get('collected_discoverables', [])
                room.uncollected_items = room_save_data.get('uncollected_items', [])
                room.dropped_items = room_save_data.get('dropped_items', [])
                room.is_mini_boss_room = room_save_data.get('is_mini_boss_room', False)
                room.is_boss_room = room_save_data.get('is_boss_room', False)
                room.ground_container = room_save_data.get('ground_container', None)
                room.ground_items = room_save_data.get('ground_items', [])
                room.ground_gold = room_save_data.get('ground_gold', 0)
                room.container_searched = room_save_data.get('container_searched', False)
                room.container_locked = room_save_data.get('container_locked', False)
                
                # Ensure has_combat is set for boss/mini-boss rooms (for old saves)
                if room.has_combat is None:
                    if room.is_boss_room or room.is_mini_boss_room:
                        room.has_combat = True
                    else:
                        # For old saves, default to True if room has threats
                        threats = room.data.get('threats', [])
                        has_combat_tag = 'combat' in room.data.get('tags', [])
                        room.has_combat = bool(threats or has_combat_tag)
                
                self.dungeon[(x, y)] = room
            
            # Set current position and room
            self.current_pos = tuple(save_data['current_pos'])
            self.current_room = self.dungeon[self.current_pos]
            
            # Restore store room reference if store was found
            if self.store_found and self.store_position and self.store_position in self.dungeon:
                self.store_room = self.dungeon[self.store_position]
            else:
                self.store_room = None
            
            # Reset combat state
            self.in_combat = False
            self.current_enemy = None
            
            # DON'T re-apply equipment bonuses - they're already included in saved stats!
            # The saved damage_bonus, crit_chance, etc. already have equipment bonuses applied.
            # Re-applying them would double the bonuses (e.g., Iron Sword +3 becomes +6).
            # Armor is handled separately via equipment_durability tracking.
            
            # Activate game
            self.game_active = True
            
            # Close dialog and setup UI
            self.close_dialog()
            
            # Setup UI and show current room
            self.setup_game_ui()
            
            # NOW populate the adventure log UI (after UI is created)
            if hasattr(self, 'log_text') and self.adventure_log:
                try:
                    self.log_text.config(state=tk.NORMAL)
                    self.log_text.delete('1.0', tk.END)  # Clear current log
                    for message, tag in self.adventure_log:
                        self.log_text.insert(tk.END, message + '\n', tag)
                    self.log_text.see(tk.END)
                    self.log_text.config(state=tk.DISABLED)
                except:
                    pass  # Silently fail if log UI isn't ready
            
            self.enter_room(self.current_room, skip_effects=True)
        except Exception as e:
            messagebox.showerror("Load Error", f"Failed to load game: {str(e)}")
    
    def load_game(self):
        """Show load slot selection"""
        self.show_load_slots()
    
    def show_victory(self):
        """Show victory screen after beating the boss"""
        self.game_active = False
        
        # Calculate final score with victory bonus
        victory_bonus = 5000
        final_score = self.run_score + victory_bonus
        
        self.log("\n" + "="*70, 'success')
        self.log("★ VICTORY! YOU DEFEATED THE DUNGEON BOSS! ★", 'success')
        self.log("="*70, 'success')
        self.log(f"Base Score: {self.run_score}", 'system')
        self.log(f"Victory Bonus: +{victory_bonus}", 'loot')
        self.log(f"Final Score: {final_score}", 'success')
        
        # Update run_score with bonus for high score tracking
        self.run_score = final_score
        
        # Save high score
        self.save_high_score()
        
        # Update action panel visual
        self.action_visual_canvas.delete("all")
        self.action_visual_canvas.create_text(150, 30, text="♛ VICTORY! ♛", 
                                              font=('Georgia', self.scale_font(14), 'bold'),
                                              fill='#ffd700')
        
        # Clear action buttons strip
        for widget in self.action_buttons_strip.winfo_children():
            widget.destroy()
        
        # Show victory message
        tk.Label(self.action_buttons_strip, 
                text="♛ VICTORY! ♛",
                font=('Arial', self.scale_font(20), 'bold'),
                bg=self.current_colors["bg_secondary"],
                fg='#ffd700',
                pady=self.scale_padding(8)).pack()
        
        tk.Label(self.action_buttons_strip,
                text=f"You defeated the boss and conquered the dungeon!\n\nFinal Score: {final_score}",
                font=('Arial', self.scale_font(12)),
                bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"],
                pady=self.scale_padding(8),
                justify=tk.CENTER).pack()
        
        # Stats summary
        stats_text = f"""Floor Reached: {self.floor}
Rooms Explored: {self.rooms_explored}
Enemies Defeated: {self.enemies_killed}
Gold Earned: {self.total_gold_earned}
Chests Opened: {self.chests_opened}"""
        
        tk.Label(self.action_buttons_strip,
                text=stats_text,
                font=('Consolas', self.scale_font(10)),
                bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"],
                pady=self.scale_padding(10),
                justify=tk.LEFT).pack()
        
        # Buttons
        btn_frame = tk.Frame(self.action_buttons_strip, bg=self.current_colors["bg_secondary"])
        btn_frame.pack(pady=20)
        
        tk.Button(btn_frame, text="View High Scores",
                 command=self.show_high_scores,
                 font=('Arial', 12, 'bold'), bg='#ffd700', fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=10)
        
        tk.Button(btn_frame, text="Main Menu",
                 command=self.show_main_menu,
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_primary"], fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=10)
    
    def game_over(self):
        """Handle game over"""
        self.game_active = False
        
        self.log("\n" + "="*50, 'system')
        self.log("☠ YOU DIED", 'enemy')
        self.log(f"Final Score: {self.run_score}", 'system')
        
        # Save high score
        self.save_high_score()
        
        # Show game over dialog
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=400, height=350)
        
        tk.Label(self.dialog_frame, text="[GAME OVER]", font=('Arial', 20, 'bold'),
                bg='#1a0f08', fg='#ff6b6b', pady=15).pack()
        
        stats = f"""
Floor Reached: {self.floor}
Rooms Explored: {self.rooms_explored}
Enemies Defeated: {self.enemies_killed}
Chests Opened: {self.chests_opened}
Gold Earned: {self.total_gold_earned}

Final Score: {self.run_score}
"""
        
        tk.Label(self.dialog_frame, text=stats, font=('Arial', 11),
                bg='#1a0f08', fg='#ffffff', justify=tk.LEFT).pack(pady=10)
        
        tk.Button(self.dialog_frame, text="Return to Menu", command=lambda: [self.close_dialog(), self.show_main_menu()],
                 font=('Arial', 12, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=20, pady=12).pack(pady=10)
    
    def save_high_score(self):
        """Save high score"""
        try:
            scores = []
            if os.path.exists(self.scores_file):
                with open(self.scores_file, 'r') as f:
                    scores = json.load(f)
            
            scores.append({
                'score': self.run_score,
                'floor': self.floor,
                'rooms': self.rooms_explored,
                'gold': self.total_gold_earned,
                'kills': self.enemies_killed,
                'stats': copy.deepcopy(self.stats)  # Deep copy to preserve nested dicts
            })
            
            scores.sort(key=lambda x: x['score'], reverse=True)
            scores = scores[:10]
            
            with open(self.scores_file, 'w') as f:
                json.dump(scores, f, indent=2)
        except Exception as e:
            print(f"Error saving score: {e}")
    
    def show_high_scores(self):
        """Show high scores - delegates to UI manager"""
        self.ui_dialogs_manager.show_high_scores()
    
    def show_settings(self, return_to=None):
        """Show settings - delegates to UI manager"""
        self.ui_dialogs_manager.show_settings(return_to)
    
    def _show_settings_implementation(self, return_to=None):
        """Show settings as submenu (works from main menu or in-game) - implementation"""
        # Store return location and original settings
        self.settings_return_to = return_to or 'main_menu'
        self.original_settings = json.dumps(self.settings)
        self.settings_modified = False
        
        # Determine parent: use game_frame if in-game, otherwise use root (for main menu)
        parent = self.root
        in_game = False
        if hasattr(self, 'game_frame') and self.game_frame is not None and self.game_frame.winfo_exists():
            parent = self.game_frame
            in_game = True
        
        # Clear action buttons strip for submenu (only if in-game)
        if in_game and hasattr(self, 'action_buttons_strip') and self.action_buttons_strip:
            for widget in self.action_buttons_strip.winfo_children():
                widget.destroy()
        
        # Close existing dialog if any
        if hasattr(self, 'dialog_frame') and self.dialog_frame and self.dialog_frame.winfo_exists():
            self.dialog_frame.destroy()
            self.dialog_frame = None
        
        # Configure colors
        bg_color = self.current_colors["bg_primary"]
        
        # Create main dialog frame
        dialog_width, dialog_height = self.get_responsive_dialog_size(750, 650)
        self.dialog_frame = tk.Frame(parent, bg=bg_color, relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center', width=dialog_width, height=dialog_height)
        
        # Create main container in dialog
        main_frame = tk.Frame(self.dialog_frame, bg=bg_color)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Title
        title_label = tk.Label(main_frame, text="SETTINGS", font=('Arial', 20, 'bold'),
                bg=bg_color, fg=self.current_colors["text_gold"])
        title_label.pack(pady=(0, 15))
        
        # Bottom buttons frame - create FIRST and pack at bottom
        button_frame = tk.Frame(main_frame, bg=bg_color)
        button_frame.pack(side=tk.BOTTOM, fill=tk.X, pady=(10, 0))
        
        # Create centered button container
        button_container = tk.Frame(button_frame, bg=bg_color)
        button_container.pack(expand=True)
        
        # Create scrollable content area - this will fill remaining space
        canvas = tk.Canvas(main_frame, bg=bg_color, highlightthickness=0)
        scrollbar = tk.Scrollbar(main_frame, orient="vertical", command=canvas.yview,
                                width=10, bg=bg_color, troughcolor=self.current_colors["bg_dark"])
        content_frame = tk.Frame(canvas, bg=bg_color)
        
        # Update scroll region when content changes
        def update_width(event=None):
            canvas.configure(scrollregion=canvas.bbox("all"))
            # Update window width to match canvas width
            canvas_width = canvas.winfo_width()
            if canvas_width > 1:  # Only update if canvas has been sized
                canvas.itemconfig(canvas_window, width=canvas_width - 20)
        
        canvas_window = canvas.create_window((0, 0), window=content_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Bind configuration changes
        content_frame.bind("<Configure>", update_width)
        canvas.bind("<Configure>", update_width)
        
        # Pack scrollable area (after button_frame is packed at bottom)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Difficulty Section
        diff_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"], 
                             relief=tk.RAISED, borderwidth=2)
        diff_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        tk.Label(diff_frame, text="DIFFICULTY", font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                pady=10).pack()
        
        current_diff = self.settings.get("difficulty", "Normal")
        
        diff_desc = tk.Label(diff_frame, text="", font=('Arial', 9, 'italic'),
                            bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"],
                            wraplength=600, pady=5)
        diff_desc.pack()
        
        diff_descriptions = {
            "Easy": "Relaxed experience • +50% damage • -30% enemy damage • +30% loot • +20% healing",
            "Normal": "Balanced gameplay • Standard values • Recommended for first playthrough",
            "Hard": "Challenging combat • -20% damage • +30% enemy damage/health • -20% loot",
            "Brutal": "Extreme difficulty • -40% damage • +60% enemy damage • +80% enemy health • -40% loot/healing"
        }
        
        diff_buttons_frame = tk.Frame(diff_frame, bg=self.current_colors["bg_secondary"])
        diff_buttons_frame.pack(pady=10)
        
        for difficulty in ["Easy", "Normal", "Hard", "Brutal"]:
            bg = self.current_colors["button_primary"] if difficulty == current_diff else self.current_colors["bg_dark"]
            fg = '#000000' if difficulty == current_diff else self.current_colors["text_primary"]
            
            btn = tk.Button(diff_buttons_frame, text=difficulty,
                          command=lambda d=difficulty: self.update_setting('difficulty', d),
                          font=('Arial', 12, 'bold'), bg=bg, fg=fg,
                          width=10, pady=8)
            btn.pack(side=tk.LEFT, padx=5)
            
            # Add hover effect to show description
            btn.bind('<Enter>', lambda e, desc=diff_descriptions[difficulty]: diff_desc.config(text=desc))
            btn.bind('<Leave>', lambda e: diff_desc.config(text=diff_descriptions[current_diff]))
        
        diff_desc.config(text=diff_descriptions[current_diff])
        
        # Graphics/Color Scheme Section
        graphics_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"],
                                 relief=tk.RAISED, borderwidth=2)
        graphics_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        tk.Label(graphics_frame, text="COLOR SCHEME", font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                pady=10).pack()
        
        current_scheme = self.settings.get("color_scheme", "Classic")
        
        tk.Label(graphics_frame, text="Choose your preferred visual theme",
                font=('Arial', 10), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"], pady=5).pack()
        
        # Show current color scheme
        tk.Label(graphics_frame, text=f"Current: {current_scheme}",
                font=('Arial', 9, 'italic'), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_gold"], pady=2).pack()
        
        scheme_buttons_frame = tk.Frame(graphics_frame, bg=self.current_colors["bg_secondary"])
        scheme_buttons_frame.pack(pady=10)
        
        # First row of color scheme buttons
        first_row = tk.Frame(scheme_buttons_frame, bg=self.current_colors["bg_secondary"])
        first_row.pack(pady=2)
        
        for scheme in ["Classic", "Dark", "Light"]:
            bg = self.current_colors["button_primary"] if scheme == current_scheme else self.current_colors["bg_dark"]
            fg = '#000000' if scheme == current_scheme else self.current_colors["text_primary"]
            
            tk.Button(first_row, text=scheme,
                     command=lambda s=scheme: self.update_setting('color_scheme', s),
                     font=('Arial', 11, 'bold'), bg=bg, fg=fg,
                     width=10, pady=8).pack(side=tk.LEFT, padx=5)
        
        # Second row of color scheme buttons
        second_row = tk.Frame(scheme_buttons_frame, bg=self.current_colors["bg_secondary"])
        second_row.pack(pady=2)
        
        for scheme in ["Neon", "Forest"]:
            bg = self.current_colors["button_primary"] if scheme == current_scheme else self.current_colors["bg_dark"]
            fg = '#000000' if scheme == current_scheme else self.current_colors["text_primary"]
            
            tk.Button(second_row, text=scheme,
                     command=lambda s=scheme: self.update_setting('color_scheme', s),
                     font=('Arial', 11, 'bold'), bg=bg, fg=fg,
                     width=10, pady=8).pack(side=tk.LEFT, padx=5)
        
        # Reset button
        reset_row = tk.Frame(scheme_buttons_frame, bg=self.current_colors["bg_secondary"])
        reset_row.pack(pady=5)
        
        tk.Button(reset_row, text="Reset to Classic",
                 command=lambda: self.update_setting('color_scheme', 'Classic'),
                 font=('Arial', 10), bg='#ff6b6b', fg='#ffffff',
                 width=15, pady=5).pack()
        
        # Audio Section
        audio_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"],
                              relief=tk.RAISED, borderwidth=2)
        audio_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        tk.Label(audio_frame, text="AUDIO", font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                pady=10).pack()
        
        tk.Label(audio_frame, text="♪ Coming Soon ♪",
                font=('Arial', 14, 'italic'), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"], pady=20).pack()
        
        # Text Speed Section
        text_speed_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"],
                                   relief=tk.RAISED, borderwidth=2)
        text_speed_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        tk.Label(text_speed_frame, text="TEXT ANIMATION SPEED", font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                pady=10).pack()
        
        current_speed = self.settings.get("text_speed", "Medium")
        
        speed_desc = tk.Label(text_speed_frame, text="", font=('Arial', 9, 'italic'),
                             bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"],
                             wraplength=600, pady=5)
        speed_desc.pack()
        
        speed_descriptions = {
            "Slow": "Slow typing animation • 15ms per character • More cinematic",
            "Medium": "Balanced speed • 13ms per character • Recommended",
            "Fast": "Quick typing • 7ms per character • Less waiting",
            "Instant": "No animation • All text appears immediately • Fastest"
        }
        
        speed_buttons_frame = tk.Frame(text_speed_frame, bg=self.current_colors["bg_secondary"])
        speed_buttons_frame.pack(pady=10)
        
        # Store speed buttons for updating selection
        speed_buttons = {}
        
        def select_speed(selected_speed):
            self.update_setting('text_speed', selected_speed)
            # Update button appearances
            for spd, btn in speed_buttons.items():
                if spd == selected_speed:
                    btn.config(bg=self.current_colors["button_primary"], fg='#000000')
                else:
                    btn.config(bg=self.current_colors["bg_dark"], fg=self.current_colors["text_primary"])
            speed_desc.config(text=speed_descriptions[selected_speed])
        
        for speed in ["Slow", "Medium", "Fast", "Instant"]:
            bg = self.current_colors["button_primary"] if speed == current_speed else self.current_colors["bg_dark"]
            fg = '#000000' if speed == current_speed else self.current_colors["text_primary"]
            
            btn = tk.Button(speed_buttons_frame, text=speed,
                          command=lambda s=speed: select_speed(s),
                          font=('Arial', 11, 'bold'), bg=bg, fg=fg,
                          width=10, pady=8)
            btn.pack(side=tk.LEFT, padx=5)
            speed_buttons[speed] = btn
            
            # Add hover effect to show description
            btn.bind('<Enter>', lambda e, desc=speed_descriptions[speed]: speed_desc.config(text=desc))
            btn.bind('<Leave>', lambda e, s=speed: speed_desc.config(text=speed_descriptions[self.settings.get('text_speed', 'Medium')]))
        
        speed_desc.config(text=speed_descriptions[current_speed])
        
        # Controls/Keybindings Section
        controls_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"],
                                 relief=tk.RAISED, borderwidth=2)
        controls_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        tk.Label(controls_frame, text="CONTROLS", font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                pady=10).pack()
        
        tk.Label(controls_frame, text="Click any key binding to change it",
                font=('Arial', 10, 'italic'), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"], pady=5).pack()
        
        # Get current keybindings
        current_keybindings = self.settings.get("keybindings", {
            "inventory": "Tab",
            "menu": "m", 
            "rest": "r",
            "move_north": "w",
            "move_south": "s", 
            "move_east": "d",
            "move_west": "a"
        })
        
        # Create keybinding buttons in a grid
        keybind_grid = tk.Frame(controls_frame, bg=self.current_colors["bg_secondary"])
        keybind_grid.pack(pady=10, padx=20, fill=tk.X)
        
        # Store keybind buttons for updates
        if not hasattr(self, 'keybind_buttons'):
            self.keybind_buttons = {}
        
        keybind_labels = {
            "inventory": "Open Inventory",
            "menu": "Open Menu", 
            "rest": "Rest",
            "move_north": "Move North",
            "move_south": "Move South",
            "move_east": "Move East", 
            "move_west": "Move West"
        }
        
        # Create two columns for better layout
        for i, (action, label) in enumerate(keybind_labels.items()):
            row = i // 2
            col = i % 2
            
            # Label for the action
            action_frame = tk.Frame(keybind_grid, bg=self.current_colors["bg_secondary"])
            action_frame.grid(row=row, column=col*2, padx=(0, 10), pady=5, sticky='w')
            
            tk.Label(action_frame, text=f"{label}:", 
                    font=('Arial', 10), bg=self.current_colors["bg_secondary"],
                    fg=self.current_colors["text_primary"], width=12, anchor='w').pack(side=tk.LEFT)
            
            # Button showing current key
            current_key = current_keybindings.get(action, "Unbound")
            key_button = tk.Button(action_frame, text=current_key,
                                  command=lambda a=action: self.start_key_remap(a),
                                  font=('Arial', 10, 'bold'), 
                                  bg=self.current_colors["button_primary"], fg='#000000',
                                  width=8)
            key_button.pack(side=tk.RIGHT)
            self.keybind_buttons[action] = key_button
        
        # Reset keybindings button
        reset_frame = tk.Frame(controls_frame, bg=self.current_colors["bg_secondary"])
        reset_frame.pack(pady=(10, 15))
        
        def reset_keybindings():
            defaults = {
                "inventory": "Tab",
                "menu": "m", 
                "rest": "r",
                "move_north": "w",
                "move_south": "s", 
                "move_east": "d",
                "move_west": "a"
            }
            self.settings["keybindings"] = defaults.copy()
            self.settings_modified = True
            
            # Update save button state
            if hasattr(self, 'save_button'):
                self.save_button.config(state=tk.NORMAL, bg='#4ecdc4')
            
            # Update button displays
            for action, button in self.keybind_buttons.items():
                button.configure(text=defaults[action])
        
        tk.Button(reset_frame, text="Reset to Defaults",
                 command=reset_keybindings,
                 font=('Arial', 10, 'bold'), bg="#FF9800", fg='#000000',
                 padx=15, pady=5).pack()
        
        # Dice Customization Section
        dice_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"],
                             relief=tk.RAISED, borderwidth=2)
        dice_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        tk.Label(dice_frame, text="DICE APPEARANCE", font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_gold"],
                pady=10).pack()
        
        tk.Label(dice_frame, text="Customize your dice appearance",
                font=('Arial', 10), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"], pady=5).pack()
        
        # Current style display
        current_style_name = self.dice_styles[self.current_dice_style]["label"]
        tk.Label(dice_frame, text=f"Current Style: {current_style_name}",
                font=('Arial', 9, 'italic'), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_gold"], pady=2).pack()
        
        # Preview area
        preview_frame = tk.Frame(dice_frame, bg='#0a0a0a', relief=tk.SUNKEN, borderwidth=2)
        preview_frame.pack(pady=10, padx=20)
        
        tk.Label(preview_frame, text="Preview:", font=('Arial', 9, 'bold'),
                bg='#0a0a0a', fg='#ffd700', padx=10, pady=5).pack()
        
        # Create preview dice container
        preview_dice_frame = tk.Frame(preview_frame, bg='#0a0a0a')
        preview_dice_frame.pack(padx=20, pady=10)
        
        # Store preview dice canvases for updates
        self.preview_dice = []
        
        # Create 3 preview dice showing values 1, 3, 6 using Canvas
        style = self.get_current_dice_style()
        for value in [1, 3, 6]:
            die_canvas = tk.Canvas(preview_dice_frame, width=64, height=64,
                                  bg='#0a0a0a', highlightthickness=0)
            die_canvas.pack(side=tk.LEFT, padx=8)
            
            # Render the die on the canvas
            self.render_die_on_canvas(die_canvas, value, style, size=64, locked=False)
            
            self.preview_dice.append((die_canvas, value))  # Store canvas and value
        
        # Preset selector
        tk.Label(dice_frame, text="Presets:", font=('Arial', 12, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"],
                pady=5).pack()
        
        # Create grid of preset buttons
        presets_grid = tk.Frame(dice_frame, bg=self.current_colors["bg_secondary"])
        presets_grid.pack(pady=5, padx=20)
        
        # First row of presets (4 buttons)
        preset_row1 = tk.Frame(presets_grid, bg=self.current_colors["bg_secondary"])
        preset_row1.pack(pady=2)
        
        for style_id in ["classic_white", "obsidian_gold", "bloodstone_red", "arcane_blue"]:
            style = self.dice_styles[style_id]
            is_current = (style_id == self.current_dice_style)
            
            # Use style-specific button colors
            if is_current:
                bg = '#ffd700'  # Gold highlight for current selection
                fg = '#000000'
            else:
                bg = style.get("button_bg", self.current_colors["bg_dark"])
                fg = style.get("button_fg", self.current_colors["text_primary"])
            
            tk.Button(preset_row1, text=style["label"],
                     command=lambda sid=style_id: self.apply_dice_style(sid),
                     font=('Arial', 10, 'bold'), bg=bg, fg=fg,
                     width=12, pady=6, relief=tk.RAISED, borderwidth=2).pack(side=tk.LEFT, padx=3)
        
        # Second row of presets (3 buttons)
        preset_row2 = tk.Frame(presets_grid, bg=self.current_colors["bg_secondary"])
        preset_row2.pack(pady=2)
        
        for style_id in ["bone_ink", "emerald_forest", "royal_purple"]:
            style = self.dice_styles[style_id]
            is_current = (style_id == self.current_dice_style)
            
            # Use style-specific button colors
            if is_current:
                bg = '#ffd700'  # Gold highlight for current selection
                fg = '#000000'
            else:
                bg = style.get("button_bg", self.current_colors["bg_dark"])
                fg = style.get("button_fg", self.current_colors["text_primary"])
            
            tk.Button(preset_row2, text=style["label"],
                     command=lambda sid=style_id: self.apply_dice_style(sid),
                     font=('Arial', 10, 'bold'), bg=bg, fg=fg,
                     width=12, pady=6, relief=tk.RAISED, borderwidth=2).pack(side=tk.LEFT, padx=3)
        
        # Third row for rose_quartz (centered)
        preset_row3 = tk.Frame(presets_grid, bg=self.current_colors["bg_secondary"])
        preset_row3.pack(pady=2)
        
        style = self.dice_styles["rose_quartz"]
        is_current = ("rose_quartz" == self.current_dice_style)
        
        if is_current:
            bg = '#ffd700'
            fg = '#000000'
        else:
            bg = style.get("button_bg", self.current_colors["bg_dark"])
            fg = style.get("button_fg", self.current_colors["text_primary"])
        
        tk.Button(preset_row3, text=style["label"],
                 command=lambda: self.apply_dice_style("rose_quartz"),
                 font=('Arial', 10, 'bold'), bg=bg, fg=fg,
                 width=12, pady=6, relief=tk.RAISED, borderwidth=2).pack(padx=3)
        
        # Override controls
        tk.Label(dice_frame, text="Custom Overrides:", font=('Arial', 12, 'bold'),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"],
                pady=8).pack()
        
        tk.Label(dice_frame, text="Mix and match elements from different styles",
                font=('Arial', 9, 'italic'), bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_primary"], pady=2).pack()
        
        override_frame = tk.Frame(dice_frame, bg=self.current_colors["bg_secondary"])
        override_frame.pack(pady=8, padx=20)
        
        # Face mode toggle
        face_mode_frame = tk.Frame(override_frame, bg=self.current_colors["bg_secondary"])
        face_mode_frame.pack(pady=5)
        
        tk.Label(face_mode_frame, text="Face Display:", font=('Arial', 10),
                bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_primary"]).pack(side=tk.LEFT, padx=5)
        
        current_face_mode = self.dice_style_overrides.get("face_mode") or self.dice_styles[self.current_dice_style]["face_mode"]
        
        # Store face mode buttons for updating selection
        face_mode_buttons = {}
        
        def select_face_mode(mode):
            self.apply_dice_override("face_mode", mode)
            # Update button appearances
            for face_mode, btn in face_mode_buttons.items():
                if face_mode == mode:
                    btn.config(bg=self.current_colors["button_primary"], fg='#000000')
                else:
                    btn.config(bg=self.current_colors["bg_dark"], fg=self.current_colors["text_primary"])
        
        numbers_btn = tk.Button(face_mode_frame, text="Numbers (1-6)",
                 command=lambda: select_face_mode("numbers"),
                 font=('Arial', 9, 'bold'),
                 bg=self.current_colors["button_primary"] if current_face_mode == "numbers" else self.current_colors["bg_dark"],
                 fg='#000000' if current_face_mode == "numbers" else self.current_colors["text_primary"],
                 width=14, pady=4)
        numbers_btn.pack(side=tk.LEFT, padx=3)
        face_mode_buttons["numbers"] = numbers_btn
        
        pips_btn = tk.Button(face_mode_frame, text="Pips (⚀⚁⚂⚃⚄⚅)",
                 command=lambda: select_face_mode("pips"),
                 font=('Arial', 9, 'bold'),
                 bg=self.current_colors["button_primary"] if current_face_mode == "pips" else self.current_colors["bg_dark"],
                 fg='#000000' if current_face_mode == "pips" else self.current_colors["text_primary"],
                 width=14, pady=4)
        pips_btn.pack(side=tk.LEFT, padx=3)
        face_mode_buttons["pips"] = pips_btn
        
        # Reset dice customization button
        dice_reset_frame = tk.Frame(dice_frame, bg=self.current_colors["bg_secondary"])
        dice_reset_frame.pack(pady=(10, 15))
        
        tk.Button(dice_reset_frame, text="Reset to Classic White",
                 command=self.reset_dice_customization,
                 font=('Arial', 10, 'bold'), bg='#ff6b6b', fg='#ffffff',
                 width=20, pady=5).pack()
        
        # Add buttons to the button_container that was created earlier
        # Save button  
        save_bg = '#4ecdc4' if self.settings_modified else '#666666'
        save_state = tk.NORMAL if self.settings_modified else tk.DISABLED
        
        self.save_button = tk.Button(button_container, text="Save Changes", 
                                     command=self.save_settings_only,
                                     font=('Arial', 13, 'bold'), bg=save_bg, fg='#000000',
                                     width=15, pady=8, state=save_state)
        self.save_button.grid(row=0, column=0, padx=(0, 10))
        
        # Save & Back button (save and close)
        tk.Button(button_container, text="Save & Back", command=self.save_and_close_settings,
                 font=('Arial', 13, 'bold'), bg=self.current_colors["button_secondary"], fg='#000000',
                 width=15, pady=8).grid(row=0, column=1, padx=(5, 5))
        
        # Cancel button (close without saving)
        tk.Button(button_container, text="Cancel", command=self.cancel_settings,
                 font=('Arial', 13, 'bold'), bg='#ff6b6b', fg='#ffffff',
                 width=15, pady=8).grid(row=0, column=2, padx=(10, 0))
        
        # Red X close button (top right corner) - saves changes automatically
        close_btn = tk.Label(main_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg=bg_color, fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        close_btn.bind('<Button-1>', lambda e: self.save_and_close_settings())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Setup mousewheel scrolling - bind to canvas and all children in content_frame
        # This ensures scrolling works when hovering over any widget in the settings
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        
        def bind_tree(widget):
            """Recursively bind mousewheel to widget and all children"""
            widget.bind("<MouseWheel>", _on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_tree(child)
        
        # Bind to canvas and all widgets in content_frame
        canvas.bind("<MouseWheel>", _on_mousewheel, add='+')
        bind_tree(content_frame)
        
        # Bind Escape key to save and close
        main_frame.bind('<Escape>', lambda e: self.save_and_close_settings() or "break")
        main_frame.focus_set()
    
    def cancel_settings(self):
        """Close settings submenu without saving"""
        # Restore original settings if modified
        if self.settings_modified:
            self.settings = json.loads(self.original_settings)
            self.settings["color_scheme"] = "Classic"
            self.current_colors = self.color_schemes["Classic"]
        
        self.settings_modified = False
        
        # Clean up
        if hasattr(self, 'original_settings'):
            delattr(self, 'original_settings')
        
        # Close submenu and restore action buttons (only if in-game)
        self.close_dialog()
        if hasattr(self, 'game_frame') and self.game_frame is not None and self.game_frame.winfo_exists():
            self.setup_action_buttons()
    
    def save_and_close_settings(self):
        """Save settings and close submenu"""
        if self.settings_modified:
            self.save_settings()
            # Refresh the underlying screen to show color changes
            self.refresh_ui_colors()
        
        self.settings_modified = False
        
        # Clean up
        if hasattr(self, 'original_settings'):
            delattr(self, 'original_settings')
        
        # Close submenu and restore action buttons (only if in-game)
        self.close_dialog()
        if hasattr(self, 'game_frame') and self.game_frame is not None and self.game_frame.winfo_exists():
            self.setup_action_buttons()
    
    def refresh_ui_colors(self):
        """Refresh the main UI colors when settings change"""
        if hasattr(self, 'settings_return_to'):
            if self.settings_return_to == 'main_menu':
                # Refresh main menu to show color changes
                self.show_main_menu()
            elif self.settings_return_to == 'game':
                # For in-game, update colors on existing widgets without regenerating content
                # This preserves game state while showing new colors
                self.update_existing_widget_colors()
    
    def update_existing_widget_colors(self):
        """Update colors on existing game UI widgets without regenerating content"""
        try:
            # Update main frame background if it exists
            if hasattr(self, 'main_frame') and self.main_frame.winfo_exists():
                self.main_frame.configure(bg=self.current_colors["bg_primary"])
            
            # Update all child widgets recursively
            for widget in self.root.winfo_children():
                self._update_widget_colors_recursive_game(widget)
                
        except Exception as e:
            # If something goes wrong, just silently continue
            # The colors will update on next screen transition
            print(f"Color update warning: {e}")
    
    def _update_widget_colors_recursive_game(self, widget):
        """Recursively update colors on game widgets"""
        try:
            widget_class = widget.winfo_class()
            
            # Update based on widget type
            if widget_class == 'Frame':
                current_bg = widget.cget('bg')
                # Map old colors to new color scheme
                if current_bg in ['#1a0f08', '#0a0a0a', '#e0e0e0', '#0d0221', '#0d1f0d']:
                    widget.configure(bg=self.current_colors["bg_primary"])
                elif current_bg in ['#3d2415', '#2c1810', '#1a1a1a', '#f5f5f5', '#1a0b3d', '#2d4a2d']:
                    widget.configure(bg=self.current_colors["bg_secondary"])
                elif current_bg in ['#4a2c1a', '#333333', '#cccccc', '#2d1b4e', '#3d5c3d']:
                    widget.configure(bg=self.current_colors["bg_dark"])
                    
            elif widget_class == 'Label':
                current_bg = widget.cget('bg')
                current_fg = widget.cget('fg')
                
                # Update background
                if current_bg in ['#1a0f08', '#0a0a0a', '#e0e0e0', '#0d0221', '#0d1f0d']:
                    widget.configure(bg=self.current_colors["bg_primary"])
                elif current_bg in ['#3d2415', '#2c1810', '#1a1a1a', '#f5f5f5', '#1a0b3d', '#2d4a2d']:
                    widget.configure(bg=self.current_colors["bg_secondary"])
                elif current_bg in ['#4a2c1a', '#333333', '#cccccc', '#2d1b4e', '#3d5c3d']:
                    widget.configure(bg=self.current_colors["bg_dark"])
                
                # Update foreground
                if current_fg in ['#ffd700', '#ffcc00', '#333333', '#ff00ff', '#90ee90']:
                    widget.configure(fg=self.current_colors["text_gold"])
                elif current_fg in ['#ffffff', '#000000', '#0d0221', '#90ee90']:
                    widget.configure(fg=self.current_colors["text_primary"])
                elif current_fg in ['#ff6b6b', '#ff4444', '#d32f2f']:
                    widget.configure(fg=self.current_colors["text_red"])
                elif current_fg in ['#4ecdc4', '#00ffff']:
                    widget.configure(fg=self.current_colors["button_primary"])
                    
            elif widget_class == 'Button':
                # Don't update button colors - they have specific meanings
                # Just update background frame colors
                pass
            
            # Recursively update children
            if hasattr(widget, 'winfo_children'):
                for child in widget.winfo_children():
                    self._update_widget_colors_recursive_game(child)
                    
        except Exception:
            # Widget might be destroyed, skip it
            pass
    
    def save_settings_only(self):
        """Save settings without closing the dialog"""
        if self.settings_modified:
            self.save_settings()
            self.settings_modified = False
            
            # Update save button to show settings are saved
            if hasattr(self, 'save_button'):
                self.save_button.config(state=tk.DISABLED, bg='#666666')
            
            # Refresh underlying UI colors if needed
            self.refresh_ui_colors()
            
            # Update the original settings to match current (so cancel won't revert)
            self.original_settings = json.dumps(self.settings)
    
    def update_setting(self, key, value):
        """Update a setting and mark as modified"""
        self.settings[key] = value
        self.settings_modified = True
        
        # Update save button state
        if hasattr(self, 'save_button'):
            self.save_button.config(state=tk.NORMAL, bg='#4ecdc4')
        
        # Apply color scheme immediately for preview (force Classic only)
        if key == 'color_scheme':
            self.settings["color_scheme"] = "Classic"
            self.current_colors = self.color_schemes["Classic"]
            # Refresh just the settings dialog colors without recursion
            self.refresh_settings_colors()
        # For difficulty changes, just update the button appearance without full refresh
        elif key == 'difficulty':
            # Find and update difficulty buttons without full refresh
            self.update_difficulty_buttons(value)
    
    def update_difficulty_buttons(self, current_diff):
        """Update difficulty button appearance without full refresh"""
        try:
            # Find the difficulty buttons frame and update button colors
            for widget in self.root.winfo_children():
                if hasattr(widget, 'winfo_children'):
                    for child in widget.winfo_children():
                        if hasattr(child, 'winfo_children'):
                            self._update_button_colors_recursive(child, current_diff)
        except Exception:
            # If we can't find the buttons, just do a full refresh
            self.show_settings()
    
    def _update_button_colors_recursive(self, widget, current_diff):
        """Recursively search for and update difficulty buttons"""
        try:
            for child in widget.winfo_children():
                if isinstance(child, tk.Button) and hasattr(child, 'cget'):
                    button_text = child.cget('text')
                    if button_text in ["Easy", "Normal", "Hard", "Brutal"]:
                        if button_text == current_diff:
                            child.config(bg=self.current_colors["button_primary"], fg='#000000')
                        else:
                            child.config(bg=self.current_colors["bg_dark"], fg=self.current_colors["text_primary"])
                elif hasattr(child, 'winfo_children'):
                    self._update_button_colors_recursive(child, current_diff)
        except Exception:
            pass
    
    def refresh_settings_colors(self):
        """Refresh settings dialog colors after color scheme change"""
        if not hasattr(self, 'dialog_frame') or not self.dialog_frame:
            return
            
        try:
            # Update dialog background
            self.dialog_frame.config(bg=self.current_colors["bg_primary"])
            
            # Recursively update all widgets in the settings dialog
            self._update_widget_colors_recursive(self.dialog_frame)
            
            # Also refresh the color scheme button selection to show the new active button
            self.refresh_color_scheme_buttons()
            
            # Update keybinding button colors if they exist
            if hasattr(self, 'keybind_buttons'):
                for button in self.keybind_buttons.values():
                    try:
                        if button.cget('bg') not in ['#ffff00', '#ff0000', '#00ff00']:  # Don't update if in special state
                            button.config(bg=self.current_colors["button_primary"])
                    except:
                        pass
            
        except Exception as e:
            # If refresh fails, do a complete settings dialog refresh
            print(f"Color refresh failed, doing full refresh: {e}")
            return_to = getattr(self, 'settings_return_to', 'main_menu')
            self.show_settings(return_to)
    
    def refresh_color_scheme_buttons(self):
        """Update color scheme button highlighting after color change"""
        current_scheme = self.settings.get("color_scheme", "Classic")
        
        try:
            # Find and update color scheme buttons
            self._update_color_scheme_buttons_recursive(self.dialog_frame, current_scheme)
        except Exception:
            pass
    
    def _update_color_scheme_buttons_recursive(self, widget, current_scheme):
        """Recursively find and update color scheme buttons"""
        try:
            for child in widget.winfo_children():
                if isinstance(child, tk.Button) and hasattr(child, 'cget'):
                    button_text = child.cget('text')
                    if button_text in ["Classic", "Dark", "Light", "Neon", "Forest"]:
                        if button_text == current_scheme:
                            child.config(bg=self.current_colors["button_primary"], fg='#000000')
                        else:
                            child.config(bg=self.current_colors["bg_dark"], fg=self.current_colors["text_primary"])
                elif hasattr(child, 'winfo_children'):
                    self._update_color_scheme_buttons_recursive(child, current_scheme)
        except Exception:
            pass
    
    def _update_widget_colors_recursive(self, widget):
        """Recursively update widget colors"""
        try:
            widget_type = widget.winfo_class()
            
            if widget_type == 'Frame':
                # Update all frames to use appropriate background colors
                try:
                    current_bg = widget.cget('bg')
                    # Map various background colors to the new scheme
                    if any(color in current_bg for color in ['#1a0f08', '#0a0a0a', '#000000', '#0d0221', '#0d1f0d']):
                        widget.config(bg=self.current_colors["bg_dark"])
                    elif any(color in current_bg for color in ['#3d2415', '#1a1a1a', '#e0e0e0', '#1a0b3d', '#2d4a2d']):
                        widget.config(bg=self.current_colors["bg_secondary"])
                    else:
                        widget.config(bg=self.current_colors["bg_primary"])
                except:
                    widget.config(bg=self.current_colors["bg_primary"])
                    
            elif widget_type == 'Label':
                try:
                    current_fg = widget.cget('fg')
                    # Update text colors based on content
                    widget_text = widget.cget('text').upper()
                    
                    if 'SETTINGS' in widget_text or 'COLOR SCHEME' in widget_text or 'DIFFICULTY' in widget_text:
                        widget.config(fg=self.current_colors["text_gold"], bg=self.current_colors["bg_secondary"])
                    elif 'Current:' in widget.cget('text'):
                        widget.config(fg=self.current_colors["text_gold"], bg=self.current_colors["bg_secondary"])
                    else:
                        widget.config(fg=self.current_colors["text_primary"], bg=self.current_colors["bg_secondary"])
                except:
                    widget.config(fg=self.current_colors["text_primary"], bg=self.current_colors["bg_secondary"])
                    
            elif widget_type == 'Button':
                try:
                    button_text = widget.cget('text')
                    # Don't update color scheme buttons here (handled separately)
                    if button_text not in ["Classic", "Dark", "Light", "Neon", "Forest"]:
                        if button_text == "Save Changes":
                            # Keep save button logic as is
                            pass
                        elif button_text == "Cancel":
                            widget.config(bg='#ff6b6b', fg='#ffffff')
                        elif "Reset to Classic" in button_text:
                            # Keep reset button red
                            pass
                        else:
                            # Update other buttons to current color scheme
                            widget.config(bg=self.current_colors["button_secondary"], fg='#000000')
                except:
                    pass
            
            # Recursively update children
            for child in widget.winfo_children():
                self._update_widget_colors_recursive(child)
                
        except Exception:
            pass
    
    def save_and_exit_settings(self):
        """Save settings and return to previous screen"""
        self.save_settings()
        self.settings_modified = False
        self.exit_settings()
    
    def exit_settings(self):
        """Exit settings, checking for unsaved changes"""
        # Check if settings were modified
        if self.settings_modified and json.dumps(self.settings) != self.original_settings:
            # Show confirmation dialog
            self.show_unsaved_changes_dialog()
        else:
            # No changes, just go back
            self.return_from_settings()
    
    def show_unsaved_changes_dialog(self):
        """Show dialog asking about unsaved changes"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(400, 250, 0.4, 0.35)
        
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        tk.Label(self.dialog_frame, text="UNSAVED CHANGES", font=('Arial', 16, 'bold'),
                bg='#1a0f08', fg='#ff6b6b', pady=15).pack()
        
        tk.Label(self.dialog_frame, text="You have unsaved changes.\nWhat would you like to do?",
                font=('Arial', 12), bg='#1a0f08', fg='#ffffff', pady=10).pack()
        
        btn_frame = tk.Frame(self.dialog_frame, bg='#1a0f08')
        btn_frame.pack(pady=20)
        
        tk.Button(btn_frame, text="Save & Exit", command=self.save_and_exit_from_dialog,
                 font=('Arial', 12, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=15, pady=10).pack(side=tk.LEFT, padx=5)
        
        tk.Button(btn_frame, text="Exit Without Saving", command=self.exit_without_saving,
                 font=('Arial', 12, 'bold'), bg='#ff6b6b', fg='#000000',
                 width=18, pady=10).pack(side=tk.LEFT, padx=5)
        
        tk.Button(btn_frame, text="Cancel", command=self.close_dialog,
                 font=('Arial', 12, 'bold'), bg='#95e1d3', fg='#000000',
                 width=12, pady=10).pack(side=tk.LEFT, padx=5)
    
    def save_and_exit_from_dialog(self):
        """Save settings and exit from unsaved changes dialog"""
        self.save_settings()
        self.settings_modified = False
        if self.dialog_frame:
            self.dialog_frame.destroy()
        self.return_from_settings()
    
    def exit_without_saving(self):
        """Exit without saving, restoring original settings (force Classic)"""
        self.settings = json.loads(self.original_settings)
        self.settings["color_scheme"] = "Classic"
        self.current_colors = self.color_schemes["Classic"]
        self.settings_modified = False
        if self.dialog_frame:
            self.dialog_frame.destroy()
        self.return_from_settings()
    
    def return_from_settings(self):
        """Return to the appropriate screen after settings"""
        # Clear settings mode flag
        self.in_settings = False
        
        # Clean up settings state
        if hasattr(self, 'original_settings'):
            delattr(self, 'original_settings')
        
        if self.settings_return_to == 'game':
            self.show_exploration_options()
        else:
            self.show_main_menu()
        
        self.settings_return_to = None
    
    def change_difficulty(self, difficulty):
        """Change game difficulty (kept for backwards compatibility)"""
        self.update_setting('difficulty', difficulty)
    
    def show_pause_menu(self):
        """Show pause menu with options"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], 
                                     relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=400, height=500)
        
        # Title
        title_text = "PAUSED"
        if self.dev_mode:
            title_text += " [DEV MODE]"
        tk.Label(self.dialog_frame, text=title_text, font=('Arial', 24, 'bold'),
                bg=self.current_colors["bg_primary"], fg=self.current_colors["text_gold"], 
                pady=20).pack()
        
        # Buttons
        button_width = 25
        button_pady = 10
        
        tk.Button(self.dialog_frame, text="Resume Game", 
                 command=self.close_dialog,
                 font=('Arial', 14, 'bold'), bg=self.current_colors["button_primary"], 
                 fg='#000000', width=button_width, pady=button_pady).pack(padx=20, pady=10)
        
        tk.Button(self.dialog_frame, text="Settings", 
                 command=self.show_settings_from_game,
                 font=('Arial', 14, 'bold'), bg=self.current_colors["button_secondary"], 
                 fg='#000000', width=button_width, pady=button_pady).pack(padx=20, pady=10)
        
        tk.Button(self.dialog_frame, text="Save/Load Game", 
                 command=self.show_load_slots,
                 font=('Arial', 14, 'bold'), bg=self.current_colors["button_secondary"], 
                 fg='#000000', width=button_width, pady=button_pady).pack(padx=20, pady=10)
        
        # Dev mode only: Dev Tools and Export Debug Log
        if self.dev_mode:
            tk.Button(self.dialog_frame, text="🛠 Dev Tools", 
                     command=self.show_dev_tools,
                     font=('Arial', 14, 'bold'), bg='#9b59b6', 
                     fg='#ffffff', width=button_width, pady=button_pady).pack(padx=20, pady=10)
            
            tk.Button(self.dialog_frame, text="Export Debug Log", 
                     command=self.export_adventure_log,
                     font=('Arial', 12), bg=self.current_colors["text_cyan"], 
                     fg='#000000', width=button_width, pady=8).pack(padx=20, pady=5)
        
        # Always show Return to Main Menu
        tk.Button(self.dialog_frame, text="Return to Main Menu", 
                 command=lambda: [self.close_dialog(), self.show_main_menu()],
                 font=('Arial', 14, 'bold'), bg=self.current_colors["button_secondary"], 
                 fg='#000000', width=button_width, pady=button_pady).pack(padx=20, pady=10)
        
        # Bind escape key to resume
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        
        # Bind numeric keys for dev mode activation sequence (1337)
        self.dialog_frame.bind('<Key>', self._check_dev_sequence)
        self.dialog_frame.focus_set()
    
    def _check_dev_sequence(self, event):
        """Check if dev mode activation sequence is entered"""
        if event.char.isdigit():
            self.dev_key_sequence.append(event.char)
            # Keep only last 4 digits
            self.dev_key_sequence = self.dev_key_sequence[-4:]
            
            # Check for secret code: 1337
            if ''.join(self.dev_key_sequence) == "1337":
                if not self.dev_mode:
                    self.dev_mode = True
                    self.dev_key_sequence = []
                    self.log("🛠 DEVELOPER MODE ACTIVATED", 'success')
                    # Refresh pause menu to show dev tools
                    self.show_pause_menu()
    
    def show_stats(self, stats_data=None, return_callback=None):
        """Show comprehensive statistics screen"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        # Use current stats if none provided (for in-game viewing)
        if stats_data is None:
            stats_data = self.stats
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(700, 600)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.dialog_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.current_colors["bg_primary"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        if return_callback:
            close_btn.bind('<Button-1>', lambda e: return_callback())
        else:
            close_btn.bind('<Button-1>', lambda e: self.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Title
        tk.Label(self.dialog_frame, text="▦ STATISTICS ▦",
                font=('Arial', 18, 'bold'),
                bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_gold"]).pack(pady=15)
        
        # Scrollable content
        canvas = tk.Canvas(self.dialog_frame, bg=self.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_secondary"], troughcolor=self.current_colors["bg_dark"])
        scrollable_frame = tk.Frame(canvas, bg=self.current_colors["bg_secondary"])
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        # Create canvas window with width constraint to eliminate blank space
        def update_width(event=None):
            canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
        
        canvas_window = canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.bind("<Configure>", update_width)
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Combat Statistics
        self._add_stats_section(scrollable_frame, "⚔️ COMBAT", [
            ("Enemies Encountered", stats_data.get("enemies_encountered", 0)),
            ("Enemies Fled", stats_data.get("enemies_fled", 0)),
            ("Enemies Defeated", stats_data.get("enemies_defeated", 0)),
            ("Mini-Bosses Defeated", stats_data.get("mini_bosses_defeated", 0)),
            ("Bosses Defeated", stats_data.get("bosses_defeated", 0)),
            ("Total Damage Dealt", stats_data.get("total_damage_dealt", 0)),
            ("Total Damage Taken", stats_data.get("total_damage_taken", 0)),
            ("Highest Single Damage", stats_data.get("highest_single_damage", 0)),
            ("Critical Hits", stats_data.get("critical_hits", 0))
        ])
        
        # Economy Statistics
        self._add_stats_section(scrollable_frame, "◉ GOLD & TRADE", [
            ("Gold Found", stats_data.get("gold_found", 0)),
            ("Gold Spent", stats_data.get("gold_spent", 0)),
            ("Items Purchased", stats_data.get("items_purchased", 0)),
            ("Items Sold", stats_data.get("items_sold", 0))
        ])
        
        # Items Statistics
        self._add_stats_section(scrollable_frame, "◈ ITEMS", [
            ("Items Found", stats_data.get("items_found", 0)),
            ("Items Used", stats_data.get("items_used", 0)),
            ("Potions Used", stats_data.get("potions_used", 0)),
            ("Containers Searched", stats_data.get("containers_searched", 0))
        ])
        
        # Equipment Statistics
        self._add_stats_section(scrollable_frame, "◊️ EQUIPMENT", [
            ("Weapons Broken", stats_data.get("weapons_broken", 0)),
            ("Armor Broken", stats_data.get("armor_broken", 0)),
            ("Weapons Repaired", stats_data.get("weapons_repaired", 0)),
            ("Armor Repaired", stats_data.get("armor_repaired", 0))
        ])
        
        # Lore Items Found - show actual available counts
        lore_data = stats_data.get("lore_found", {})
        # Actual lore counts from lore_items.json
        lore_max_counts = {
            "Guard Journal": 16,
            "Quest Notice": 12,
            "Training Manual Page": 10,
            "Scrawled Note": 10,
            "Cracked Map Scrap": 10,
            "Pressed Page": 6,
            "Surgeon's Note": 6,
            "Puzzle Note": 4,
            "Star Chart": 4,
            "Prayer Strip": 10
        }
        total_lore = sum(lore_data.values())
        max_lore = sum(lore_max_counts.values())  # 88 total
        lore_items = [(name, f"{count}/{lore_max_counts.get(name, 0)}") for name, count in sorted(lore_data.items())]
        lore_items.insert(0, ("TOTAL LORE FOUND", f"{total_lore}/{max_lore}"))
        self._add_stats_section(scrollable_frame, "◈ LORE COLLECTION", lore_items)
        
        # Most Defeated Enemies (top 5)
        enemy_kills = stats_data.get("enemy_kills", {})
        if enemy_kills:
            top_enemies = sorted(enemy_kills.items(), key=lambda x: x[1], reverse=True)[:5]
            self._add_stats_section(scrollable_frame, "†️ TOP ENEMIES DEFEATED", top_enemies)
        
        # Most Damaged Enemy
        most_damaged = stats_data.get("most_damaged_enemy", {})
        if most_damaged.get("name"):
            self._add_stats_section(scrollable_frame, "✸ MOST DAMAGED", [
                (most_damaged["name"], f"{most_damaged['damage']} damage")
            ])
        
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=20, pady=10)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Update scroll region after all content is added
        scrollable_frame.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        
        # Setup mousewheel scrolling
        self.setup_mousewheel_scrolling(canvas)
        
        self.dialog_frame.bind('<Escape>', lambda e: (return_callback() if return_callback else self.close_dialog()) or "break")
        self.dialog_frame.focus_set()
    
    def _add_stats_section(self, parent, title, items):
        """Helper to add a statistics section"""
        section_frame = tk.Frame(parent, bg=self.current_colors["bg_dark"], relief=tk.RAISED, borderwidth=2)
        section_frame.pack(fill=tk.X, padx=10, pady=8)
        
        # Section title
        tk.Label(section_frame, text=title,
                font=('Arial', 12, 'bold'),
                bg=self.current_colors["bg_dark"],
                fg=self.current_colors["text_cyan"]).pack(anchor=tk.W, padx=10, pady=5)
        
        # Stats items
        for label, value in items:
            item_frame = tk.Frame(section_frame, bg=self.current_colors["bg_dark"])
            item_frame.pack(fill=tk.X, padx=15, pady=2)
            
            tk.Label(item_frame, text=label,
                    font=('Arial', 10),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_secondary"]).pack(side=tk.LEFT)
            
            tk.Label(item_frame, text=str(value),
                    font=('Arial', 10, 'bold'),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_gold"]).pack(side=tk.RIGHT)
    
    def show_lore_codex(self, return_callback=None):
        """Show compact lore codex with expandable dropdown categories"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(700, 600)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text="📖 LORE CODEX 📖",
                font=('Arial', 18, 'bold'),
                bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_gold"]).pack(pady=(15, 5))
        
        # Total progress
        total_found = len(self.lore_codex)
        total_max = sum(self.lore_max_counts.values())
        tk.Label(self.dialog_frame, text=f"Total: {total_found}/{total_max}",
                font=('Arial', 11, 'bold'),
                bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_cyan"]).pack(pady=(0, 10))
        
        # Organize lore by type
        lore_by_type = {}
        for entry in self.lore_codex:
            lore_type = entry.get("type", "Unknown")
            if lore_type not in lore_by_type:
                lore_by_type[lore_type] = []
            lore_by_type[lore_type].append(entry)
        
        # Sort each category by floor found
        for lore_type in lore_by_type:
            lore_by_type[lore_type].sort(key=lambda x: x.get("floor_found", 0))
        
        # Define category display names and order
        category_info = {
            "guards_journal": ("Guard's Journal", "guards_journal_pages"),
            "quest_notice": ("Quest Notices", "quest_notices"),
            "training_manual": ("Training Manuals", "training_manual_pages"),
            "scrawled_note": ("Scrawled Notes", "scrawled_notes"),
            "map_scrap": ("Map Scraps", "map_scraps"),
            "pressed_page": ("Pressed Pages", "pressed_pages"),
            "surgeons_note": ("Surgeon's Notes", "surgeons_notes"),
            "puzzle_note": ("Puzzle Notes", "puzzle_notes"),
            "star_chart": ("Star Charts", "star_charts"),
            "old_letter": ("Old Letters", "old_letters"),
            "prayer_strip": ("Prayer Strips", "prayer_strips")
        }
        
        # Create scrollable category list
        canvas = tk.Canvas(self.dialog_frame, bg=self.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_secondary"], troughcolor=self.current_colors["bg_dark"])
        scrollable_frame = tk.Frame(canvas, bg=self.current_colors["bg_secondary"])
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Track expanded state for each category
        if not hasattr(self, '_lore_expanded'):
            self._lore_expanded = {}
        
        # Display categories with dropdowns
        for lore_type, (display_name, json_key) in category_info.items():
            category_lore = lore_by_type.get(lore_type, [])
            count = len(category_lore)
            max_count = self.lore_max_counts.get(json_key, 0)
            
            # Compact category header (clickable to expand/collapse)
            category_frame = tk.Frame(scrollable_frame, bg=self.current_colors["bg_dark"], relief=tk.RAISED, borderwidth=1)
            category_frame.pack(fill=tk.X, padx=10, pady=2)
            
            # Header is clickable to toggle expansion
            header_frame = tk.Frame(category_frame, bg=self.current_colors["bg_dark"], cursor="hand2")
            header_frame.pack(fill=tk.X)
            
            # Expansion indicator
            expanded = self._lore_expanded.get(lore_type, False)
            arrow = "▼" if expanded else "►"
            arrow_label = tk.Label(header_frame, text=arrow,
                    font=('Arial', 10),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_cyan"],
                    width=2)
            arrow_label.pack(side=tk.LEFT, padx=(5, 0))
            
            # Category name
            name_label = tk.Label(header_frame, text=display_name,
                    font=('Arial', 11, 'bold'),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_cyan"])
            name_label.pack(side=tk.LEFT, padx=5)
            
            # Count (color based on completion)
            count_color = self.current_colors["text_gold"] if count == max_count and count > 0 else self.current_colors["text_secondary"]
            count_label = tk.Label(header_frame, text=f"{count}/{max_count}",
                    font=('Arial', 10, 'bold'),
                    bg=self.current_colors["bg_dark"],
                    fg=count_color)
            count_label.pack(side=tk.RIGHT, padx=10, pady=5)
            
            # Container for expanded content (hidden by default)
            content_frame = tk.Frame(category_frame, bg=self.current_colors["bg_secondary"])
            if expanded:
                content_frame.pack(fill=tk.X, padx=5, pady=5)
            
            # Populate content if we have lore entries
            if count > 0:
                for i, entry in enumerate(category_lore):
                    entry_item = tk.Frame(content_frame, bg=self.current_colors["bg_dark"], relief=tk.GROOVE, borderwidth=1)
                    entry_item.pack(fill=tk.X, padx=5, pady=2)
                    
                    # Clickable entry header
                    entry_header = tk.Frame(entry_item, bg=self.current_colors["bg_dark"], cursor="hand2")
                    entry_header.pack(fill=tk.X)
                    
                    # Show unique identifier if available
                    unique_id = entry.get('unique_id', '')
                    id_text = f" #{unique_id}" if unique_id else ""
                    
                    # Title and floor with unique ID
                    title_text = f"{entry['title']}{id_text} (Floor {entry['floor_found']})"
                    entry_title = tk.Label(entry_header, text=title_text,
                            font=('Arial', 9),
                            bg=self.current_colors["bg_dark"],
                            fg=self.current_colors["text_primary"])
                    entry_title.pack(side=tk.LEFT, padx=8, pady=3)
                    
                    # Read button
                    read_btn = tk.Button(entry_header, text="Read",
                            command=lambda e=entry: self.show_lore_entry_popup(e, lambda: self.show_lore_codex(None)),
                            font=('Arial', 8, 'bold'),
                            bg=self.current_colors["button_primary"],
                            fg='#000000',
                            width=8,
                            pady=1)
                    read_btn.pack(side=tk.RIGHT, padx=5, pady=2)
            else:
                # Show "none found" message when expanded
                if expanded:
                    tk.Label(content_frame, text="None discovered yet",
                            font=('Arial', 9, 'italic'),
                            bg=self.current_colors["bg_secondary"],
                            fg=self.current_colors["text_secondary"]).pack(pady=5)
            
            # Toggle function - use default parameters to capture current values
            def toggle_category(event=None, lt=lore_type, cf=content_frame, al=arrow_label, c=canvas):
                current = self._lore_expanded.get(lt, False)
                self._lore_expanded[lt] = not current
                
                if self._lore_expanded[lt]:
                    al.config(text="▼")
                    cf.pack(fill=tk.X, padx=5, pady=5)
                else:
                    al.config(text="►")
                    cf.pack_forget()
                
                # Update scroll region
                c.update_idletasks()
                c.configure(scrollregion=c.bbox("all"))
            
            # Bind click to entire header
            header_frame.bind("<Button-1>", toggle_category)
            arrow_label.bind("<Button-1>", toggle_category)
            name_label.bind("<Button-1>", toggle_category)
            count_label.bind("<Button-1>", toggle_category)
        
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=15, pady=10)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y, pady=10)
        
        # Update scroll region after all content is added
        scrollable_frame.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        
        # Setup mousewheel scrolling
        self.setup_mousewheel_scrolling(canvas)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(scrollable_frame)
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.dialog_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.current_colors["bg_primary"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        if return_callback:
            close_btn.bind('<Button-1>', lambda e: return_callback())
        else:
            close_btn.bind('<Button-1>', lambda e: self.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        self.dialog_frame.bind('<Escape>', lambda e: (return_callback() if return_callback else self.close_dialog()) or "break")
        self.dialog_frame.focus_set()
    
    def show_lore_entry_popup(self, lore_entry, return_callback=None):
        """Delegates to lore_manager - kept for backward compatibility"""
        self.lore_manager.show_lore_entry_popup(lore_entry, return_callback)
    
    def show_lore_category(self, lore_type, category_name, main_return_callback):
        """Show all lore entries for a specific category"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(700, 600)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text=category_name,
                font=('Arial', 18, 'bold'),
                bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_gold"]).pack(pady=15)
        
        # Filter lore by type
        category_lore = [entry for entry in self.lore_codex if entry.get("type") == lore_type]
        
        # Sort by floor found
        category_lore.sort(key=lambda x: x.get("floor_found", 0))
        
        # Create scrollable list
        canvas = tk.Canvas(self.dialog_frame, bg=self.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_secondary"], troughcolor=self.current_colors["bg_dark"])
        scrollable_frame = tk.Frame(canvas, bg=self.current_colors["bg_secondary"])
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Setup mousewheel scrolling
        self.setup_mousewheel_scrolling(canvas)
        
        # Add each lore entry
        for entry in category_lore:
            entry_frame = tk.Frame(scrollable_frame, bg=self.current_colors["bg_dark"], relief=tk.RAISED, borderwidth=2)
            entry_frame.pack(fill=tk.X, padx=10, pady=5)
            
            # Header with title and floor found
            header_frame = tk.Frame(entry_frame, bg=self.current_colors["bg_dark"])
            header_frame.pack(fill=tk.X, padx=10, pady=5)
            
            tk.Label(header_frame, text=entry["title"],
                    font=('Arial', 12, 'bold'),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_cyan"]).pack(side=tk.LEFT)
            
            tk.Label(header_frame, text=f"Floor {entry['floor_found']}",
                    font=('Arial', 10, 'italic'),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_secondary"]).pack(side=tk.RIGHT)
            
            # Subtitle if present
            if entry.get("subtitle"):
                tk.Label(entry_frame, text=entry["subtitle"],
                        font=('Arial', 10, 'italic'),
                        bg=self.current_colors["bg_dark"],
                        fg=self.current_colors["text_secondary"]).pack(anchor=tk.W, padx=10, pady=(0, 5))
            
            # Content preview (first 100 characters)
            preview_text = entry["content"][:100] + ("..." if len(entry["content"]) > 100 else "")
            tk.Label(entry_frame, text=preview_text,
                    font=('Arial', 10),
                    bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_primary"],
                    wraplength=dialog_width-80,
                    justify=tk.LEFT).pack(anchor=tk.W, padx=10, pady=(0, 5))
            
            # Read button
            tk.Button(entry_frame, text="Read",
                     command=lambda e=entry, lt=lore_type, cn=category_name: self.show_codex_entry_from_category(e, lt, cn, main_return_callback),
                     font=('Arial', 9, 'bold'),
                     bg=self.current_colors["button_primary"],
                     fg='#000000', width=12, pady=3).pack(pady=5)
        
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=20, pady=10)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(scrollable_frame)
        
        # Back button
        btn_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_primary"])
        btn_frame.pack(pady=15)
        
        tk.Button(btn_frame, text="Back to Categories",
                 command=lambda: self.show_lore_codex(main_return_callback),
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_secondary"],
                 fg='#ffffff', width=20, pady=8).pack()
        
        self.dialog_frame.bind('<Escape>', lambda e: self.show_lore_codex(main_return_callback) or "break")
        self.dialog_frame.focus_set()
    
    def show_codex_entry_from_category(self, lore_entry, lore_type, category_name, main_return_callback):
        """Show full lore entry from category view"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(600, 500)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text=lore_entry["title"],
                font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_panel"],
                fg=self.current_colors["text_gold"]).pack(pady=10)
        
        # Subtitle and floor found
        info_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        info_frame.pack(pady=5)
        
        if lore_entry.get("subtitle"):
            tk.Label(info_frame, text=lore_entry["subtitle"],
                    font=('Arial', 11, 'italic'),
                    bg=self.current_colors["bg_panel"],
                    fg=self.current_colors["text_secondary"]).pack()
        
        tk.Label(info_frame, text=f"Discovered on Floor {lore_entry['floor_found']}",
                font=('Arial', 10, 'italic'),
                bg=self.current_colors["bg_panel"],
                fg=self.current_colors["text_secondary"]).pack(pady=3)
        
        # Content in scrollable text widget
        text_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_dark"], relief=tk.SUNKEN, borderwidth=2)
        text_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        text_widget = tk.Text(text_frame,
                             wrap=tk.WORD,
                             font=('Arial', 11),
                             bg=self.current_colors["bg_dark"],
                             fg=self.current_colors["text_primary"],
                             relief=tk.FLAT,
                             padx=15,
                             pady=15)
        text_scrollbar = tk.Scrollbar(text_frame, command=text_widget.yview)
        text_widget.configure(yscrollcommand=text_scrollbar.set)
        
        text_widget.insert('1.0', lore_entry["content"])
        text_widget.configure(state=tk.DISABLED)
        
        text_widget.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        text_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Back button
        tk.Button(self.dialog_frame, text="Back to List",
                 command=lambda: self.show_lore_category(lore_type, category_name, main_return_callback),
                 font=('Arial', 12, 'bold'), bg=self.current_colors["button_secondary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.show_lore_category(lore_type, category_name, main_return_callback) or "break")
        self.dialog_frame.focus_set()
    
    def show_codex_entry(self, lore_index, return_callback):
        """Show full lore entry from codex"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        lore_entry = self.lore_codex[lore_index]
        
        dialog_width, dialog_height = self.get_responsive_dialog_size(600, 500)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text=lore_entry["title"],
                font=('Arial', 16, 'bold'),
                bg=self.current_colors["bg_panel"],
                fg=self.current_colors["text_gold"]).pack(pady=10)
        
        # Subtitle and floor found
        info_frame = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_panel"])
        info_frame.pack(pady=5)
        
        if lore_entry.get("subtitle"):
            tk.Label(info_frame, text=lore_entry["subtitle"],
                    font=('Arial', 11, 'italic'),
                    bg=self.current_colors["bg_panel"],
                    fg=self.current_colors["text_secondary"]).pack()
        
        tk.Label(info_frame, text=f"(Discovered on Floor {lore_entry['floor_found']})",
                font=('Arial', 10, 'italic'),
                bg=self.current_colors["bg_panel"],
                fg=self.current_colors["text_secondary"]).pack(pady=3)
        
        # Separator
        tk.Frame(self.dialog_frame, height=2, bg=self.current_colors["text_accent"]).pack(fill=tk.X, padx=30, pady=10)
        
        # Scrollable content
        canvas = tk.Canvas(self.dialog_frame, bg=self.current_colors["bg_panel"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_panel"], troughcolor=self.current_colors["bg_dark"])
        text_frame = tk.Frame(canvas, bg=self.current_colors["bg_panel"])
        
        text_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

        
        

        
        def update_width(event=None):

        
            canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)

        
        

        
        canvas_window = canvas.create_window((0, 0), window=text_frame, anchor="nw")

        
        canvas.bind("<Configure>", update_width)

        
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Setup mousewheel scrolling
        self.setup_mousewheel_scrolling(canvas)
        
        # Full content
        tk.Label(text_frame, text=lore_entry["content"],
                font=('Arial', 12),
                bg=self.current_colors["bg_panel"],
                fg=self.current_colors["text_primary"],
                wraplength=dialog_width-100,
                justify=tk.LEFT).pack(padx=20, pady=10)
        
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=20, pady=(0, 10))
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y, pady=(0, 10))
        
        # Back button
        tk.Button(self.dialog_frame, text="Back to Codex",
                 command=lambda: self.show_lore_codex(return_callback),
                 font=('Arial', 12, 'bold'),
                 bg=self.current_colors["button_secondary"],
                 fg='#ffffff', width=15, pady=8).pack(pady=15)
        
        self.dialog_frame.bind('<Escape>', lambda e: self.show_lore_codex(return_callback) or "break")
        self.dialog_frame.focus_set()
    
    def apply_dice_style(self, style_id):
        """Apply a dice style preset"""
        self.current_dice_style = style_id
        # Clear overrides when selecting a preset
        self.dice_style_overrides = {"bg": None, "pip_color": None, "face_mode": None}
        self.settings_modified = True
        
        # Update save button state
        if hasattr(self, 'save_button'):
            self.save_button.config(state=tk.NORMAL, bg='#4ecdc4')
        
        # Update preview dice
        self.update_preview_dice()
        
        # Update actual dice display if in combat
        if hasattr(self, 'dice_buttons') and self.dice_buttons:
            self.update_dice_display()
    
    def get_current_dice_style(self):
        """Get the current dice style - delegate to DiceManager"""
        return self.dice_manager.get_current_dice_style()
    
    def render_die_on_canvas(self, canvas, value, style, size=64, locked=False):
        """Render a die on a canvas - delegate to DiceManager"""
        return self.dice_manager.render_die_on_canvas(canvas, value, style, size, locked)
    
    def apply_dice_override(self, property_name, value):
        """Apply an override to the current dice style"""
        self.dice_style_overrides[property_name] = value
        self.settings_modified = True
        
        # Update save button state
        if hasattr(self, 'save_button'):
            self.save_button.config(state=tk.NORMAL, bg='#4ecdc4')
        
        # Update preview dice
        self.update_preview_dice()
        
        # Update actual dice display if in combat
        if hasattr(self, 'dice_buttons') and self.dice_buttons:
            self.update_dice_display()
    
    def reset_dice_customization(self):
        """Reset dice customization to default Classic White"""
        self.current_dice_style = "classic_white"
        self.dice_style_overrides = {"bg": None, "pip_color": None, "face_mode": None}
        self.settings_modified = True
        
        # Update save button state
        if hasattr(self, 'save_button'):
            self.save_button.config(state=tk.NORMAL, bg='#4ecdc4')
        
        # Update preview dice
        self.update_preview_dice()
        
        # Update actual dice display if in combat
        if hasattr(self, 'dice_buttons') and self.dice_buttons:
            self.update_dice_display()
    
    def update_preview_dice(self):
        """Update the preview dice canvases in the settings panel"""
        if not hasattr(self, 'preview_dice'):
            return
        
        style = self.get_current_dice_style()
        
        for canvas, value in self.preview_dice:
            # Re-render the die on the canvas with updated style
            self.render_die_on_canvas(canvas, value, style, size=64, locked=False)
    
    def show_settings_from_game(self):
        """Helper to show settings from in-game menu"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        self.show_settings(return_to='game')
    
    def toggle_dev_mode(self):
        """Toggle developer mode on/off"""
        self.dev_mode = not self.dev_mode
        
        # Update button appearance and visibility
        if self.dev_mode:
            self.dev_mode_button.config(bg='#ff9f43', fg='#000000')
            self.dev_mode_button.pack(side=tk.LEFT, padx=self.scale_padding(2))
            self.log("[DEV MODE] Developer mode ENABLED - Debug features unlocked", 'system')
        else:
            self.dev_mode_button.config(bg='#333333', fg='#888888')
            self.dev_mode_button.pack_forget()
            self.log("[DEV MODE] Developer mode disabled", 'system')
    

    
    def start_key_remap(self, action):
        """Start key remapping for the specified action in settings dialog."""
        if not hasattr(self, 'dialog_frame') or not self.dialog_frame or not self.dialog_frame.winfo_exists():
            return
            
        button = self.keybind_buttons[action]
        original_text = button.cget("text")
        button.configure(text="Press new key...", bg="#ffff00", state="disabled")
        
        # Get current keybindings
        current_keybindings = self.settings.get("keybindings", {
            "inventory": "Tab",
            "menu": "m", 
            "rest": "r",
            "move_north": "w",
            "move_south": "s", 
            "move_east": "d",
            "move_west": "a"
        })
        
        def on_key_press(event):
            new_key = event.keysym
            
            # Handle special keys
            if new_key in ['Escape', 'Return', 'BackSpace', 'Delete']:
                if new_key == 'Escape':
                    # Cancel - restore original
                    button.configure(text=original_text, bg=self.current_colors["button_primary"], state="normal")
                    self.dialog_frame.unbind('<KeyPress>')
                    return
                elif new_key in ['Return', 'BackSpace', 'Delete']:
                    # These are reserved keys, don't allow
                    button.configure(text="Invalid key!", bg="#ff0000")
                    self.dialog_frame.after(1000, lambda: button.configure(text=original_text, bg=self.current_colors["button_primary"], state="normal"))
                    self.dialog_frame.unbind('<KeyPress>')
                    return
            
            # Convert Tab to readable format
            if new_key == 'Tab':
                display_key = 'Tab'
            elif new_key.lower() != new_key:
                # Keep original case for special keys
                display_key = new_key
            else:
                # Convert to lowercase for regular keys
                display_key = new_key.lower()
            
            # Check if key is already used
            for other_action, other_key in current_keybindings.items():
                if other_action != action and other_key.lower() == display_key.lower():
                    button.configure(text=f"Already used!", bg="#ff0000")
                    self.dialog_frame.after(1500, lambda: button.configure(text=original_text, bg=self.current_colors["button_primary"], state="normal"))
                    self.dialog_frame.unbind('<KeyPress>')
                    return
            
            # Update the keybinding
            current_keybindings[action] = display_key
            self.settings["keybindings"] = current_keybindings
            self.settings_modified = True
            
            # Update save button state
            if hasattr(self, 'save_button'):
                self.save_button.config(state=tk.NORMAL, bg='#4ecdc4')
            
            button.configure(text=display_key, bg="#00ff00", state="normal")
            self.dialog_frame.after(1000, lambda: button.configure(bg=self.current_colors["button_primary"]))
            self.dialog_frame.unbind('<KeyPress>')
        
        self.dialog_frame.bind('<KeyPress>', on_key_press)
        self.dialog_frame.focus_set()
    

    
    def change_color_scheme(self, scheme):
        """Change color scheme (forced to Classic only)"""
        self.settings["color_scheme"] = "Classic"
        self.current_colors = self.color_schemes["Classic"]
        self.save_settings()
        self.show_settings()  # Refresh with new colors
    
    def show_keybindings(self):
        """Show help menu with gameplay mechanics and controls"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        # Responsive sizing
        dialog_width, dialog_height = self.get_responsive_dialog_size(700, 650)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], 
                                      relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, 
                                width=dialog_width, height=dialog_height)
        
        # Header with title and X button
        header = tk.Frame(self.dialog_frame, bg=self.current_colors["bg_primary"])
        header.pack(fill=tk.X, pady=(10, 5))
        
        tk.Label(header, text="? HELP & CONTROLS ?", font=('Arial', 18, 'bold'),
                bg=self.current_colors["bg_primary"], fg=self.current_colors["text_gold"]).pack(pady=5)
        
        close_btn = tk.Label(header, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.current_colors["bg_primary"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=1.0, rely=0.0, anchor='ne', x=-10, y=0)
        close_btn.bind('<Button-1>', lambda e: self.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Scrollable content
        canvas = tk.Canvas(self.dialog_frame, bg=self.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.current_colors["bg_secondary"], troughcolor=self.current_colors["bg_dark"])
        content_frame = tk.Frame(canvas, bg=self.current_colors["bg_secondary"])
        
        content_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        def update_width(event=None):
            canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
        
        canvas_window = canvas.create_window((0, 0), window=content_frame, anchor="nw")
        canvas.bind("<Configure>", update_width)
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True, padx=10, pady=5)
        scrollbar.pack(side="right", fill="y", pady=5)
        
        # Help sections - game mechanics and controls
        sections = [
            ("HOW TO PLAY", [
                ("", "GOAL: Explore the dungeon, defeat enemies, find stairs, and descend deeper!"),
            ]),
            ("⬆⬇⬅➡ EXPLORATION", [
                ("", "Use WASD or arrow keys to explore new rooms"),
                ("", "Each room may contain enemies, chests, or stairs"),
                ("", "You MUST find stairs to descend deeper into the dungeon"),
                ("", "Deeper floors = tougher enemies + better loot"),
            ]),
            ("⚔ COMBAT", [
                ("", "Enemies block your path until defeated"),
                ("", "Click dice to roll, click again to lock/unlock"),
                ("", "Create combos for massive damage"),
                ("", "Flee if in danger (50% success, costs HP)"),
            ]),
            ("DICE COMBOS", [
                ("", "Pair (2 of a kind): value × 2"),
                ("", "Triple (3 of a kind): value × 5"),
                ("", "Quad (4 of a kind): value × 10"),
                ("", "Five of a Kind: value × 20"),
                ("", "Full House: +50 bonus"),
                ("", "Flush (5+ same): value × 15"),
                ("", "Straights: +25 to +40 bonus"),
            ]),
            ("◉ LOOTING & ITEMS", [
                ("", "Open chests for gold, items, or health"),
                ("", "Manage inventory (20 item limit, upgradeable)"),
                ("", "Visit shops to buy/sell items"),
                ("", "Equip weapons, armor, and accessories"),
            ]),
            ("[RESTING]", [
                ("", "Press R to rest and recover 20 HP"),
                ("", "After resting, you must explore 3 rooms before resting again"),
                ("", "Cannot rest during combat"),
            ]),
            ("CONTROLS", [
                ("TAB / I", "Open Inventory"),
                ("G", "Character Status"),
                ("R", "Rest (heal 20 HP, 3-room cooldown)"),
                ("ESC / M", "Menu / Close Dialog"),
                ("WASD / Arrows", "Move (disabled in combat)"),
            ]),
            ("💡 TIPS", [
                ("", "Save HP for boss fights"),
                ("", "Lock dice strategically for big combos"),
                ("", "Check character status (C) to see your stats"),
                ("", "Hover over items for descriptions"),
            ])
        ]
        
        for section_title, items in sections:
            # Section header
            section_header = tk.Frame(content_frame, bg=self.current_colors["bg_panel"], 
                                     relief=tk.RIDGE, borderwidth=2)
            section_header.pack(fill=tk.X, padx=10, pady=(10, 5))
            
            tk.Label(section_header, text=section_title, font=('Arial', 13, 'bold'),
                    bg=self.current_colors["bg_panel"], fg=self.current_colors["text_cyan"], 
                    pady=5).pack()
            
            # Items list
            for key, description in items:
                item_frame = tk.Frame(content_frame, bg=self.current_colors["bg_secondary"])
                item_frame.pack(fill=tk.X, padx=20, pady=2)
                
                if key:  # Control binding
                    tk.Label(item_frame, text=key, font=('Consolas', 10, 'bold'),
                            bg=self.current_colors["bg_dark"], fg=self.current_colors["text_gold"], 
                            width=14, anchor='center',
                            relief=tk.RAISED, borderwidth=1, pady=2).pack(side=tk.LEFT, padx=5)
                    
                    tk.Label(item_frame, text=description, font=('Arial', 10),
                            bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_white"], 
                            anchor='w').pack(side=tk.LEFT, padx=10)
                else:  # Info/tip without key
                    tk.Label(item_frame, text=f"• {description}", font=('Arial', 10),
                            bg=self.current_colors["bg_secondary"], fg=self.current_colors["text_white"], 
                            anchor='w', wraplength=550).pack(side=tk.LEFT, padx=15, pady=2)
        
        # Update scroll region and setup mousewheel
        content_frame.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        self.setup_mousewheel_scrolling(canvas)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(content_frame)
        
        # ESC to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
    
    def show_dev_tools(self):
        """Open comprehensive Dev Tools in dialog"""
        from tkinter import ttk
        
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        # Create dialog frame
        dialog_width, dialog_height = self.get_responsive_dialog_size(800, 600)
        
        self.dialog_frame = tk.Frame(self.root, bg=self.current_colors["bg_primary"], relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=dialog_width, height=dialog_height)
        
        # Title
        tk.Label(self.dialog_frame, text="🛠 DEVELOPER TOOLS 🛠",
                font=('Arial', 18, 'bold'),
                bg=self.current_colors["bg_primary"],
                fg=self.current_colors["text_gold"]).pack(pady=(15, 5))
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.dialog_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.current_colors["bg_primary"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        close_btn.bind('<Button-1>', lambda e: self.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Bind Escape to close
        self.dialog_frame.bind('<Escape>', lambda e: self.close_dialog() or "break")
        self.dialog_frame.focus_set()
        
        # Style the notebook to match game theme
        style = ttk.Style()
        style.theme_use('default')
        style.configure('DevTools.TNotebook', 
                       background=self.current_colors["bg_primary"],
                       borderwidth=0,
                       tabmargins=0)
        style.configure('DevTools.TNotebook.Tab',
                       background=self.current_colors["bg_secondary"],
                       foreground=self.current_colors["text_gold"],
                       padding=[15, 8],
                       borderwidth=0)
        style.map('DevTools.TNotebook.Tab',
                 background=[('selected', self.current_colors["bg_panel"])],
                 foreground=[('selected', '#ffd700')])
        
        # Create notebook for tabs
        notebook = ttk.Notebook(self.dialog_frame, style='DevTools.TNotebook')
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=(5, 10))
        
        # ===== TAB 1: ENEMY SPAWNING =====
        enemy_tab_outer = tk.Frame(notebook, bg=self.current_colors["bg_primary"])
        notebook.add(enemy_tab_outer, text="Enemies")
        
        # Create scrollable area for enemy tab
        enemy_canvas = tk.Canvas(enemy_tab_outer, bg=self.current_colors["bg_primary"], highlightthickness=0)
        enemy_outer_scrollbar = tk.Scrollbar(enemy_tab_outer, orient="vertical", command=enemy_canvas.yview, width=10)
        enemy_tab = tk.Frame(enemy_canvas, bg=self.current_colors["bg_primary"])
        
        enemy_tab.bind("<Configure>", lambda e: enemy_canvas.configure(scrollregion=enemy_canvas.bbox("all")))
        
        def update_enemy_tab_width(event=None):
            enemy_canvas.itemconfig(enemy_tab_window, width=enemy_canvas.winfo_width()-10)
        
        enemy_tab_window = enemy_canvas.create_window((0, 0), window=enemy_tab, anchor="nw")
        enemy_canvas.bind("<Configure>", update_enemy_tab_width)
        enemy_canvas.configure(yscrollcommand=enemy_outer_scrollbar.set)
        
        self.setup_mousewheel_scrolling(enemy_canvas)
        
        enemy_canvas.pack(side="left", fill="both", expand=True)
        enemy_outer_scrollbar.pack(side="right", fill="y")
        
        # Get complete enemy list from sprite system instead of enemy_types.json
        # This ensures we show ALL enemies, not just those with special mechanics
        sprite_based_enemies = []
        if hasattr(self, 'enemy_sprites') and self.enemy_sprites:
            # Get all enemy names from the sprite system
            sprite_based_enemies = sorted(list(self.enemy_sprites.keys()))
        
        # Also include enemies from enemy_types.json that might not have sprites
        config_enemies = sorted([name for name in self.enemy_types.keys() if name != '_meta'])
        
        # Combine both lists and remove duplicates
        all_enemies = sorted(list(set(sprite_based_enemies + config_enemies)))
        enemy_list = all_enemies
        
        print(f"DEBUG: Found {len(enemy_list)} total enemies from sprites and config")
        print(f"DEBUG: Sprite enemies: {len(sprite_based_enemies)}, Config enemies: {len(config_enemies)}")
        print(f"DEBUG: Sample enemies: {enemy_list[:10]}...")  # Show first 10
        
        # Search and filter controls
        enemy_controls_frame = tk.Frame(enemy_tab, bg=self.current_colors["bg_secondary"])
        enemy_controls_frame.pack(fill=tk.X, padx=20, pady=10)
        
        tk.Label(enemy_controls_frame, text="Search:", bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_cyan"], font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=5)
        enemy_search_var = tk.StringVar()
        enemy_search_entry = tk.Entry(enemy_controls_frame, textvariable=enemy_search_var, width=20)
        enemy_search_entry.pack(side=tk.LEFT, padx=5)
        
        tk.Label(enemy_controls_frame, text="Sort:", bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_cyan"], font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=(20, 5))
        enemy_sort_var = tk.StringVar(value="name_asc")
        
        # Sort buttons
        sort_options = [("name_asc", "A-Z"), ("name_desc", "Z-A"), ("hp_asc", "HP↑"), ("hp_desc", "HP↓")]
        for sort_type, label in sort_options:
            def set_enemy_sort(st=sort_type):
                enemy_sort_var.set(st)
                refresh_enemy_list()
            btn = tk.Button(enemy_controls_frame, text=label, command=set_enemy_sort,
                    font=('Arial', 8), bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_secondary"], width=5, pady=2)
            btn.pack(side=tk.LEFT, padx=2)
        
        # Category filter frame (new row)
        filter_frame = tk.Frame(enemy_tab, bg=self.current_colors["bg_secondary"])
        filter_frame.pack(fill=tk.X, padx=20, pady=5)
        
        tk.Label(filter_frame, text="Filter:", bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_cyan"], font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=5)
        
        enemy_filter_var = tk.StringVar(value="all")
        
        filter_options = [
            ("all", "All Enemies", "#95a5a6"),
            ("regular", "Regular", "#95a5a6"),
            ("elite", "Elite", "#f39c12"),
            ("miniboss", "Mini-Boss", "#e67e22"),
            ("boss", "Floor Boss", "#e74c3c")
        ]
        
        for filter_type, label, color in filter_options:
            def set_filter(ft=filter_type):
                enemy_filter_var.set(ft)
                refresh_enemy_list()
            btn = tk.Button(filter_frame, text=label, command=set_filter,
                    font=('Arial', 9, 'bold'), bg=color,
                    fg='#ffffff', width=10, pady=4)
            btn.pack(side=tk.LEFT, padx=2)
        
        # Spawn options
        options_frame = tk.Frame(enemy_tab, bg=self.current_colors["bg_secondary"])
        options_frame.pack(fill=tk.X, padx=20, pady=5)
        
        is_boss_var = tk.BooleanVar(value=False)
        tk.Checkbutton(options_frame, text="Spawn as Boss", variable=is_boss_var, bg=self.current_colors["bg_secondary"],
                      fg='#ffffff', selectcolor='#000000', font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=5)
        
        is_miniboss_var = tk.BooleanVar(value=False)
        tk.Checkbutton(options_frame, text="Spawn as Mini-Boss", variable=is_miniboss_var, bg=self.current_colors["bg_secondary"],
                      fg='#ffffff', selectcolor='#000000', font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=5)
        
        # Create scrollable canvas for enemy list
        enemy_list_canvas = tk.Canvas(enemy_tab, bg=self.current_colors["bg_primary"], highlightthickness=0, height=400)
        enemy_list_scrollbar = tk.Scrollbar(enemy_tab, orient="vertical", command=enemy_list_canvas.yview, width=10)
        enemy_scroll_frame = tk.Frame(enemy_list_canvas, bg=self.current_colors["bg_primary"])
        
        enemy_scroll_frame.bind("<Configure>", lambda e: enemy_list_canvas.configure(scrollregion=enemy_list_canvas.bbox("all")))
        
        def update_enemy_list_width(event=None):
            enemy_list_canvas.itemconfig(enemy_list_window, width=enemy_list_canvas.winfo_width()-10)
        
        enemy_list_window = enemy_list_canvas.create_window((0, 0), window=enemy_scroll_frame, anchor="nw")
        enemy_list_canvas.bind("<Configure>", update_enemy_list_width)
        enemy_list_canvas.configure(yscrollcommand=enemy_list_scrollbar.set)
        
        self.setup_mousewheel_scrolling(enemy_list_canvas)
        
        enemy_list_canvas.pack(side="left", fill="both", expand=True, padx=(20, 0))
        enemy_list_scrollbar.pack(side="left", fill="y", padx=(0, 20))
        
        def calculate_enemy_stats(enemy_name, as_boss=False, as_mini_boss=False):
            """Calculate enemy stats using exact same logic as trigger_combat"""
            # Base stats
            base_hp = 30 + (self.floor * 10)
            
            # Add enemy-specific HP multipliers based on enemy name/type
            enemy_hp_multipliers = {
                # Weak enemies
                "Goblin": 0.7, "Rat": 0.6, "Spider": 0.6, "Imp": 0.7, "Slime": 0.8,
                "Bat": 0.5, "Sprite": 0.6, "Wisp": 0.5, "Grub": 0.4,
                
                # Normal enemies (1.0 multiplier - default)
                "Skeleton": 1.0, "Orc": 1.0, "Zombie": 1.1, "Bandit": 0.9,
                
                # Strong enemies
                "Troll": 1.5, "Ogre": 1.4, "Knight": 1.3, "Guard": 1.2, "Warrior": 1.1,
                "Beast": 1.3, "Wolf": 1.1, "Bear": 1.4, "Boar": 1.2,
                
                # Elite enemies
                "Demon": 2.0, "Dragon": 2.5, "Lich": 1.8, "Vampire": 1.6, "Wraith": 1.4,
                "Golem": 2.2, "Hydra": 2.3, "Phoenix": 2.0, "Titan": 2.8,
                
                # Special/Boss enemies
                "Lord": 3.0, "King": 3.5, "Ancient": 3.2, "Primordial": 4.0,
                "Crystal Golem": 1.8, "Shadow Hydra": 2.1, "Necromancer": 1.6,
                "Gelatinous Slime": 1.3, "Demon Lord": 2.8, "Demon Prince": 2.4
            }
            
            # Find multiplier for this enemy (check for partial name matches)
            multiplier = 1.0  # Default
            enemy_lower = enemy_name.lower()
            
            for enemy_key, mult in enemy_hp_multipliers.items():
                if enemy_key.lower() in enemy_lower:
                    multiplier = mult
                    break
            
            # Apply enemy-specific multiplier
            base_hp = int(base_hp * multiplier)
            hp_min = base_hp - 5
            hp_max = base_hp + 10
            
            # Dice calculation
            if as_boss:
                dice_count = min(5 + (self.floor // 2), 8)
            elif as_mini_boss:
                dice_count = min(4 + (self.floor // 2), 7)
            else:
                dice_count = min(3 + (self.floor // 2), 6)
            
            # Apply boss multipliers
            if as_boss:
                hp_min = int(hp_min * 8.0)
                hp_max = int(hp_max * 8.0)
            elif as_mini_boss:
                hp_min = int(hp_min * 3.0)
                hp_max = int(hp_max * 3.0)
            
            # Apply difficulty multiplier
            difficulty = self.settings.get("difficulty", "Normal")
            diff_mult = self.difficulty_multipliers[difficulty]["enemy_health_mult"]
            hp_min = int(hp_min * diff_mult)
            hp_max = int(hp_max * diff_mult)
            
            # Apply dev multipliers
            hp_min = int(hp_min * self.dev_config["enemy_hp_mult"])
            hp_max = int(hp_max * self.dev_config["enemy_hp_mult"])
            dice_count = int(dice_count * self.dev_config["enemy_dice_mult"])
            
            return hp_min, hp_max, dice_count
        
        def get_enemy_category(enemy_name):
            """Categorize enemies as Regular, Elite, Mini-Boss, or Floor Boss"""
            enemy_config = self.enemy_types.get(enemy_name, {})
            
            # Check if enemy has boss abilities defined - this is the PRIMARY indicator
            has_boss_abilities = bool(enemy_config.get("boss_abilities"))
            
            # Use calculated HP and name patterns to determine category
            hp_min, hp_max, _ = calculate_enemy_stats(enemy_name)
            avg_hp = (hp_min + hp_max) / 2
            enemy_lower = enemy_name.lower()
            
            # Floor Boss indicators - typically named "Lord", "King", "Ancient", "Dragon", etc.
            boss_keywords = ["lord", "king", "queen", "ancient", "primordial", "elder", "supreme", 
                           "dragon", "titan", "colossus", "emperor", "empress", "leviathan", "behemoth"]
            
            # Check for boss keywords in name
            is_boss_name = any(keyword in enemy_lower for keyword in boss_keywords)
            
            # Categorize based on boss abilities FIRST, then name/HP
            if has_boss_abilities and (is_boss_name or avg_hp >= 200):
                return "Floor Boss"
            elif has_boss_abilities:
                # Has boss abilities but not boss-level HP/name = Mini-Boss
                return "Mini-Boss"
            elif is_boss_name or avg_hp >= 200:
                # Boss name/HP but no abilities = just a strong Elite
                return "Elite"
            elif avg_hp >= 50:
                return "Elite"
            else:
                return "Regular"
        
        def refresh_enemy_list():
            for widget in enemy_scroll_frame.winfo_children():
                widget.destroy()
            
            search_term = enemy_search_var.get().lower()
            current_sort = enemy_sort_var.get()
            current_filter = enemy_filter_var.get()
            
            # Filter enemies by search and category
            filtered_enemies = []
            for enemy_name in enemy_list:
                if search_term and search_term not in enemy_name.lower():
                    continue
                
                # Apply category filter
                if current_filter != "all":
                    category = get_enemy_category(enemy_name)
                    if current_filter == "regular" and category != "Regular":
                        continue
                    elif current_filter == "elite" and category != "Elite":
                        continue
                    elif current_filter == "miniboss" and category != "Mini-Boss":
                        continue
                    elif current_filter == "boss" and category != "Floor Boss":
                        continue
                
                filtered_enemies.append(enemy_name)
            
            # Sort enemies
            if current_sort == "name_asc":
                filtered_enemies.sort()
            elif current_sort == "name_desc":
                filtered_enemies.sort(reverse=True)
            elif current_sort == "hp_asc":
                filtered_enemies.sort(key=lambda x: calculate_enemy_stats(x)[0])  # Sort by min HP
            elif current_sort == "hp_desc":
                filtered_enemies.sort(key=lambda x: calculate_enemy_stats(x)[0], reverse=True)  # Sort by min HP
            
            print(f"DEBUG: Filtered enemies: {len(filtered_enemies)} of {len(enemy_list)}")
            
            if not filtered_enemies:
                tk.Label(enemy_scroll_frame, text="No enemies found", font=('Arial', 10, 'italic'),
                        bg=self.current_colors["bg_primary"], fg=self.current_colors["text_secondary"]).pack(pady=20)
                return
            
            for enemy_name in filtered_enemies:
                enemy_config = self.enemy_types.get(enemy_name, {})
                category = get_enemy_category(enemy_name)
                
                # Calculate accurate stats for regular enemy
                hp_min, hp_max, dice_count = calculate_enemy_stats(enemy_name, 
                                                                   as_boss=is_boss_var.get(), 
                                                                   as_mini_boss=is_miniboss_var.get())
                
                row_frame = tk.Frame(enemy_scroll_frame, bg=self.current_colors["bg_dark"])
                row_frame.pack(fill=tk.X, padx=5, pady=1)
                
                def spawn_this_enemy(name=enemy_name):
                    self.trigger_combat(name, is_mini_boss=is_miniboss_var.get(), is_boss=is_boss_var.get())
                    self.log(f"🛠 DEV: Spawned {name}", 'system')
                    self.close_dialog()
                
                # Make row clickable
                row_frame.bind("<Button-1>", lambda e, name=enemy_name: spawn_this_enemy(name))
                row_frame.config(cursor="hand2")
                
                # Category badge with updated colors
                badge_colors = {
                    "Regular": "#95a5a6", 
                    "Elite": "#f39c12", 
                    "Mini-Boss": "#e67e22",
                    "Floor Boss": "#e74c3c"
                }
                badge = tk.Label(row_frame, text=f"[{category}]", font=('Arial', 7, 'bold'),
                        bg=badge_colors.get(category, "#95a5a6"), fg='#ffffff')
                badge.pack(side=tk.LEFT, padx=2)
                badge.bind("<Button-1>", lambda e, name=enemy_name: spawn_this_enemy(name))
                badge.config(cursor="hand2")
                
                # Enemy name
                name_label = tk.Label(row_frame, text=f"☠ {enemy_name}", font=('Arial', 9),
                        bg=self.current_colors["bg_dark"], fg=self.current_colors["text_secondary"])
                name_label.pack(side=tk.LEFT, pady=2, padx=5)
                name_label.bind("<Button-1>", lambda e, name=enemy_name: spawn_this_enemy(name))
                name_label.config(cursor="hand2")
                
                # Stats - show range if different, single value if same
                if hp_min == hp_max:
                    hp_text = f"HP:{hp_min}"
                else:
                    hp_text = f"HP:{hp_min}-{hp_max}"
                
                stats_label = tk.Label(row_frame, text=f"{hp_text} | Dice:{dice_count}", font=('Arial', 8),
                        bg=self.current_colors["bg_dark"], fg=self.current_colors["text_gold"])
                stats_label.pack(side=tk.RIGHT, padx=5)
                stats_label.bind("<Button-1>", lambda e, name=enemy_name: spawn_this_enemy(name))
                stats_label.config(cursor="hand2")
        
        enemy_search_var.trace('w', lambda *args: refresh_enemy_list())
        refresh_enemy_list()
        
        # ===== TAB 2: ITEM SPAWNING =====
        item_tab_outer = tk.Frame(notebook, bg=self.current_colors["bg_primary"])
        notebook.add(item_tab_outer, text="Items")
        
        # Create scrollable area for item tab
        item_outer_canvas = tk.Canvas(item_tab_outer, bg=self.current_colors["bg_primary"], highlightthickness=0)
        item_outer_scrollbar = tk.Scrollbar(item_tab_outer, orient="vertical", command=item_outer_canvas.yview, width=10)
        item_tab = tk.Frame(item_outer_canvas, bg=self.current_colors["bg_primary"])
        
        item_tab.bind("<Configure>", lambda e: item_outer_canvas.configure(scrollregion=item_outer_canvas.bbox("all")))
        
        def update_item_tab_width(event=None):
            item_outer_canvas.itemconfig(item_tab_window, width=item_outer_canvas.winfo_width()-10)
        
        item_tab_window = item_outer_canvas.create_window((0, 0), window=item_tab, anchor="nw")
        item_outer_canvas.bind("<Configure>", update_item_tab_width)
        item_outer_canvas.configure(yscrollcommand=item_outer_scrollbar.set)
        
        self.setup_mousewheel_scrolling(item_outer_canvas)
        
        item_outer_canvas.pack(side="left", fill="both", expand=True)
        item_outer_scrollbar.pack(side="right", fill="y")
        
        # Get complete item list from item_definitions (excluding _meta)
        item_list = sorted([item for item in self.item_definitions.keys() if item != '_meta'])
        print(f"DEBUG: Found {len(item_list)} items: {item_list[:10]}...")  # Show first 10
        
        # Search and filter controls
        item_controls_frame = tk.Frame(item_tab, bg=self.current_colors["bg_secondary"])
        item_controls_frame.pack(fill=tk.X, padx=20, pady=10)
        
        tk.Label(item_controls_frame, text="Search:", bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_cyan"], font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=5)
        item_search_var = tk.StringVar()
        item_search_entry = tk.Entry(item_controls_frame, textvariable=item_search_var, width=20)
        item_search_entry.pack(side=tk.LEFT, padx=5)
        
        tk.Label(item_controls_frame, text="Filter:", bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_cyan"], font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=(20, 5))
        
        item_filter_var = tk.StringVar(value="All")
        item_categories = ["All", "Weapon", "Armor", "Accessory", "Consumable", "Combat Item", "Utility", "Upgrade", "Repair Kit", "Other"]
        
        # Filter buttons
        for category in item_categories:
            def set_item_filter(cat=category):
                item_filter_var.set(cat)
                refresh_item_list()
            btn = tk.Button(item_controls_frame, text=category, command=set_item_filter,
                    font=('Arial', 7), bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_secondary"], padx=3, pady=2)
            btn.pack(side=tk.LEFT, padx=1)
        
        tk.Label(item_controls_frame, text="Sort:", bg=self.current_colors["bg_secondary"],
                fg=self.current_colors["text_cyan"], font=('Arial', 10, 'bold')).pack(side=tk.LEFT, padx=(20, 5))
        item_sort_var = tk.StringVar(value="name_asc")
        
        # Sort buttons
        item_sort_options = [("name_asc", "A-Z"), ("name_desc", "Z-A"), ("type_asc", "Type")]
        for sort_type, label in item_sort_options:
            def set_item_sort(st=sort_type):
                item_sort_var.set(st)
                refresh_item_list()
            btn = tk.Button(item_controls_frame, text=label, command=set_item_sort,
                    font=('Arial', 8), bg=self.current_colors["bg_dark"],
                    fg=self.current_colors["text_secondary"], width=5, pady=2)
            btn.pack(side=tk.LEFT, padx=2)
        
        # Create scrollable canvas for item list
        item_canvas = tk.Canvas(item_tab, bg=self.current_colors["bg_primary"], highlightthickness=0, height=400)
        item_scrollbar = tk.Scrollbar(item_tab, orient="vertical", command=item_canvas.yview, width=10)
        item_scroll_frame = tk.Frame(item_canvas, bg=self.current_colors["bg_primary"])
        
        item_scroll_frame.bind("<Configure>", lambda e: item_canvas.configure(scrollregion=item_canvas.bbox("all")))
        
        def update_item_width(event=None):
            item_canvas.itemconfig(item_canvas_window, width=item_canvas.winfo_width()-10)
        
        item_canvas_window = item_canvas.create_window((0, 0), window=item_scroll_frame, anchor="nw")
        item_canvas.bind("<Configure>", update_item_width)
        item_canvas.configure(yscrollcommand=item_scrollbar.set)
        
        self.setup_mousewheel_scrolling(item_canvas)
        
        item_canvas.pack(side="left", fill="both", expand=True, padx=(20, 0))
        item_scrollbar.pack(side="left", fill="y", padx=(0, 20))
        
        def get_item_category(item_name):
            item_def = self.item_definitions.get(item_name, {})
            item_type = item_def.get("type", "other")
            slot = item_def.get("slot", None)
            
            if slot == "weapon":
                return "Weapon"
            elif slot == "armor":
                return "Armor"
            elif slot == "accessory":
                return "Accessory"
            elif item_type in ["heal", "potion"]:
                return "Consumable"
            elif item_type == "upgrade":
                return "Upgrade"
            elif item_type in ["buff", "shield"]:
                return "Combat Item"
            elif item_type in ["token", "tool", "cleanse"]:
                return "Utility"
            elif item_type == "repair":
                return "Repair Kit"
            else:
                return "Other"
        
        def refresh_item_list():
            for widget in item_scroll_frame.winfo_children():
                widget.destroy()
            
            search_term = item_search_var.get().lower()
            current_filter = item_filter_var.get()
            current_sort = item_sort_var.get()
            
            # Filter items
            filtered_items = []
            for item_name in item_list:
                if search_term and search_term not in item_name.lower():
                    continue
                category = get_item_category(item_name)
                if current_filter != "All" and category != current_filter:
                    continue
                filtered_items.append(item_name)
            
            # Sort items
            if current_sort == "name_asc":
                filtered_items.sort()
            elif current_sort == "name_desc":
                filtered_items.sort(reverse=True)
            elif current_sort == "type_asc":
                filtered_items.sort(key=lambda x: get_item_category(x))
            
            if not filtered_items:
                tk.Label(item_scroll_frame, text="No items found", font=('Arial', 10, 'italic'),
                        bg=self.current_colors["bg_primary"], fg=self.current_colors["text_secondary"]).pack(pady=20)
                return
            
            for item_name in filtered_items:
                item_def = self.item_definitions.get(item_name, {})
                category = get_item_category(item_name)
                
                row_frame = tk.Frame(item_scroll_frame, bg=self.current_colors["bg_dark"])
                row_frame.pack(fill=tk.X, padx=5, pady=1)
                
                # Category badge
                badge_colors = {
                    "Weapon": "#e74c3c", "Armor": "#3498db", "Accessory": "#9b59b6",
                    "Consumable": "#27ae60", "Combat Item": "#e67e22", "Utility": "#f39c12",
                    "Upgrade": "#1abc9c", "Repair Kit": "#95a5a6", "Other": "#7f8c8d"
                }
                tk.Label(row_frame, text=f"[{category}]", font=('Arial', 7),
                        bg=badge_colors.get(category, "#95a5a6"), fg='#ffffff').pack(side=tk.LEFT, padx=2)
                
                # Item name
                name_label = tk.Label(row_frame, text=f"📦 {item_name}", font=('Arial', 9),
                        bg=self.current_colors["bg_dark"], fg=self.current_colors["text_secondary"])
                name_label.pack(side=tk.LEFT, pady=2, padx=5)
                
                # Action buttons
                def give_this_item(name=item_name):
                    if len(self.inventory) < self.max_inventory:
                        self.inventory.append(name)
                        # Track item collection
                        if "items_collected" not in self.stats:
                            self.stats["items_collected"] = {}
                        self.stats["items_collected"][name] = self.stats["items_collected"].get(name, 0) + 1
                        # Track items found for dev spawning
                        self.stats["items_found"] += 1
                        self.log(f"🛠 DEV: Added {name} to inventory", 'success')
                        self.update_display()
                    else:
                        self.log("Inventory full!", 'warning')
                
                def spawn_this_item(name=item_name):
                    if hasattr(self, 'current_room') and self.current_room:
                        self.current_room.ground_items.append(name)
                        self.log(f"🛠 DEV: Spawned {name} in room", 'success')
                    else:
                        self.log("No active room!", 'warning')
                
                btn_frame = tk.Frame(row_frame, bg=self.current_colors["bg_dark"])
                btn_frame.pack(side=tk.RIGHT, padx=2)
                
                tk.Button(btn_frame, text="Give", command=give_this_item,
                         bg='#3498db', fg='#ffffff', font=('Arial', 7, 'bold'),
                         padx=4, pady=1).pack(side=tk.LEFT, padx=1)
                tk.Button(btn_frame, text="Spawn", command=spawn_this_item,
                         bg='#27ae60', fg='#ffffff', font=('Arial', 7, 'bold'),
                         padx=4, pady=1).pack(side=tk.LEFT, padx=1)
        
        item_search_var.trace('w', lambda *args: refresh_item_list())
        refresh_item_list()
        
        # ===== TAB 3: PLAYER CONTROLS =====
        player_tab_outer = tk.Frame(notebook, bg=self.current_colors["bg_primary"])
        notebook.add(player_tab_outer, text="Player")
        
        # Create scrollable area for player tab
        player_outer_canvas = tk.Canvas(player_tab_outer, bg=self.current_colors["bg_primary"], highlightthickness=0)
        player_outer_scrollbar = tk.Scrollbar(player_tab_outer, orient="vertical", command=player_outer_canvas.yview, width=10)
        player_tab = tk.Frame(player_outer_canvas, bg=self.current_colors["bg_primary"])
        
        player_tab.bind("<Configure>", lambda e: player_outer_canvas.configure(scrollregion=player_outer_canvas.bbox("all")))
        
        def update_player_tab_width(event=None):
            player_outer_canvas.itemconfig(player_tab_window, width=player_outer_canvas.winfo_width()-10)
        
        player_tab_window = player_outer_canvas.create_window((0, 0), window=player_tab, anchor="nw")
        player_outer_canvas.bind("<Configure>", update_player_tab_width)
        player_outer_canvas.configure(yscrollcommand=player_outer_scrollbar.set)
        
        self.setup_mousewheel_scrolling(player_outer_canvas)
        
        player_outer_canvas.pack(side="left", fill="both", expand=True)
        player_outer_scrollbar.pack(side="right", fill="y")
        
        # Gold controls
        tk.Label(player_tab, text="Gold Management", font=('Arial', 14, 'bold'),
                bg=self.current_colors["bg_primary"], fg=self.current_colors["text_gold"]).pack(pady=10)
        
        gold_frame = tk.Frame(player_tab, bg='#3c2820')
        gold_frame.pack(fill=tk.X, padx=20, pady=5)
        
        tk.Label(gold_frame, text="Amount:", bg='#3c2820', fg='#ffffff').grid(row=0, column=0, padx=5, pady=5)
        gold_var = tk.IntVar(value=100)
        tk.Spinbox(gold_frame, from_=1, to=10000, textvariable=gold_var, width=10).grid(row=0, column=1, padx=5)
        
        def add_gold():
            amount = gold_var.get()
            self.gold += amount
            self.log(f"🛠 DEV: Added {amount} gold", 'gold_gained')
            self.update_display()
        
        tk.Button(gold_frame, text="Add Gold", command=add_gold,
                 bg='#f39c12', fg='#000000', font=('Arial', 10, 'bold')).grid(row=0, column=2, padx=10)
        
        # Health controls
        tk.Label(player_tab, text="Health Management", font=('Arial', 14, 'bold'),
                bg=self.current_colors["bg_primary"], fg=self.current_colors["text_gold"]).pack(pady=10)
        
        health_frame = tk.Frame(player_tab, bg='#3c2820')
        health_frame.pack(fill=tk.X, padx=20, pady=5)
        
        tk.Label(health_frame, text="Damage:", bg='#3c2820', fg='#ffffff').grid(row=0, column=0, padx=5, pady=5)
        damage_var = tk.IntVar(value=10)
        tk.Spinbox(health_frame, from_=1, to=100, textvariable=damage_var, width=10).grid(row=0, column=1, padx=5)
        
        def damage_player():
            amount = damage_var.get()
            if not self.dev_invincible:
                self.health = max(0, self.health - amount)
                self.log(f"🛠 DEV: Damaged player for {amount}", 'damage_taken')
                self.update_health_display()
            else:
                self.log("🛠 DEV: Invincible mode active!", 'system')
        
        def heal_player():
            self.health = self.max_health
            self.log(f"🛠 DEV: Fully healed", 'healing')
            self.update_health_display()
        
        tk.Button(health_frame, text="Damage Player", command=damage_player,
                 bg='#e74c3c', fg='#ffffff', font=('Arial', 10, 'bold')).grid(row=0, column=2, padx=5)
        tk.Button(health_frame, text="Full Heal", command=heal_player,
                 bg='#27ae60', fg='#ffffff', font=('Arial', 10, 'bold')).grid(row=0, column=3, padx=5)
        
        # God mode toggle
        god_mode_var = tk.BooleanVar(value=self.dev_invincible)
        
        def toggle_god_mode():
            self.dev_invincible = god_mode_var.get()
            status = "ON" if self.dev_invincible else "OFF"
            self.log(f"🛠 DEV: God Mode {status}", 'success')
        
        tk.Checkbutton(health_frame, text="⚡ GOD MODE (Invincible)", variable=god_mode_var,
                      command=toggle_god_mode, bg='#3c2820', fg='#9b59b6',
                      selectcolor='#000000', font=('Arial', 11, 'bold')).grid(row=1, column=0, columnspan=4, pady=10)
        
        # Player stats
        tk.Label(player_tab, text="Player Stats", font=('Arial', 14, 'bold'),
                bg=self.current_colors["bg_primary"], fg=self.current_colors["text_gold"]).pack(pady=10)
        
        stats_frame = tk.Frame(player_tab, bg='#3c2820')
        stats_frame.pack(fill=tk.X, padx=20, pady=5)
        
        # Max HP
        tk.Label(stats_frame, text="Max HP:", bg='#3c2820', fg='#ffffff').grid(row=0, column=0, padx=5, pady=5, sticky='e')
        max_hp_var = tk.IntVar(value=self.max_health)
        max_hp_scale = tk.Scale(stats_frame, from_=10, to=500, orient=tk.HORIZONTAL, variable=max_hp_var,
                               bg='#3c2820', fg='#ffffff', highlightthickness=0, length=200)
        max_hp_scale.grid(row=0, column=1, padx=5, pady=5)
        
        def update_max_hp(val):
            self.max_health = int(val)
            self.health = min(self.health, self.max_health)
            self.update_health_display()
        
        max_hp_scale.config(command=update_max_hp)
        
        # Crit chance
        tk.Label(stats_frame, text="Crit %:", bg='#3c2820', fg='#ffffff').grid(row=1, column=0, padx=5, pady=5, sticky='e')
        crit_var = tk.DoubleVar(value=self.crit_chance * 100)
        crit_scale = tk.Scale(stats_frame, from_=0, to=100, orient=tk.HORIZONTAL, variable=crit_var,
                             bg='#3c2820', fg='#ffffff', highlightthickness=0, length=200, resolution=1)
        crit_scale.grid(row=1, column=1, padx=5, pady=5)
        
        def update_crit(val):
            self.crit_chance = float(val) / 100.0
        
        crit_scale.config(command=update_crit)
        
        # ===== TAB 3: GAMEPLAY PARAMETERS =====
        params_tab = tk.Frame(notebook, bg='#2c1810')
        notebook.add(params_tab, text="Parameters")
        
        tk.Label(params_tab, text="Live Gameplay Multipliers", font=('Arial', 14, 'bold'),
                bg='#2c1810', fg='#f39c12').pack(pady=10)
        
        # Create scrollable frame for parameters
        params_canvas = tk.Canvas(params_tab, bg='#2c1810', highlightthickness=0)
        params_scrollbar = tk.Scrollbar(params_tab, orient="vertical", command=params_canvas.yview, width=10,
                                       bg='#2c1810', troughcolor='#1a0f08')
        params_scrollable = tk.Frame(params_canvas, bg='#2c1810')
        
        params_scrollable.bind("<Configure>", lambda e: params_canvas.configure(scrollregion=params_canvas.bbox("all")))
        params_canvas.create_window((0, 0), window=params_scrollable, anchor="nw")
        params_canvas.configure(yscrollcommand=params_scrollbar.set)
        
        params_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        params_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Define all parameter sliders
        param_configs = [
            ("Enemy HP Multiplier", "enemy_hp_mult", 0.1, 5.0, 0.1),
            ("Enemy Damage Multiplier", "enemy_damage_mult", 0.1, 5.0, 0.1),
            ("Player Damage Multiplier", "player_damage_mult", 0.1, 5.0, 0.1),
            ("Gold Drop Multiplier", "gold_drop_mult", 0.1, 10.0, 0.1),
            ("Item Spawn Rate Multiplier", "item_spawn_rate_mult", 0.0, 5.0, 0.1),
            ("Shop Buy Price Multiplier", "shop_buy_price_mult", 0.1, 5.0, 0.1),
            ("Shop Sell Price Multiplier", "shop_sell_price_mult", 0.1, 5.0, 0.1),
            ("Durability Loss Multiplier", "durability_loss_mult", 0.0, 5.0, 0.1),
            ("Enemy Dice Multiplier", "enemy_dice_mult", 0.5, 3.0, 0.1)
        ]
        
        param_vars = {}
        param_labels = {}
        
        for idx, (name, key, min_val, max_val, resolution) in enumerate(param_configs):
            frame = tk.Frame(params_scrollable, bg='#3c2820', relief=tk.RAISED, borderwidth=1)
            frame.pack(fill=tk.X, padx=5, pady=5)
            
            current_val = self.dev_config.get(key, 1.0)
            param_vars[key] = tk.DoubleVar(value=current_val)
            
            label_text = f"{name}: {current_val:.2f}x"
            param_labels[key] = tk.Label(frame, text=label_text, bg='#3c2820', fg='#ffffff',
                                        font=('Arial', 10, 'bold'), width=35, anchor='w')
            param_labels[key].pack(side=tk.TOP, padx=10, pady=5)
            
            def make_update(k, lbl, n):
                def update(val):
                    self.dev_config[k] = float(val)
                    lbl.config(text=f"{n}: {float(val):.2f}x")
                return update
            
            scale = tk.Scale(frame, from_=min_val, to=max_val, orient=tk.HORIZONTAL,
                           variable=param_vars[key], bg='#3c2820', fg='#ffffff',
                           highlightthickness=0, length=400, resolution=resolution,
                           command=make_update(key, param_labels[key], name))
            scale.pack(side=tk.TOP, padx=10, pady=5)
        
        # ===== TAB 4: WORLD & NAVIGATION =====
        world_tab = tk.Frame(notebook, bg='#2c1810')
        notebook.add(world_tab, text="World")
        
        tk.Label(world_tab, text="World Navigation", font=('Arial', 14, 'bold'),
                bg='#2c1810', fg='#f39c12').pack(pady=10)
        
        nav_frame = tk.Frame(world_tab, bg='#3c2820')
        nav_frame.pack(fill=tk.X, padx=20, pady=5)
        
        tk.Label(nav_frame, text="Floor:", bg='#3c2820', fg='#ffffff').grid(row=0, column=0, padx=5, pady=5)
        floor_var = tk.IntVar(value=self.floor)
        tk.Spinbox(nav_frame, from_=1, to=100, textvariable=floor_var, width=10).grid(row=0, column=1, padx=5)
        
        def jump_floor():
            target_floor = floor_var.get()
            self.floor = target_floor
            self.log(f"🛠 DEV: Jumped to floor {target_floor}", 'system')
            # Reset room
            if hasattr(self, 'generate_floor'):
                self.generate_floor()
        
        def next_floor_dev():
            self.floor_up()
            self.log(f"🛠 DEV: Advanced to floor {self.floor}", 'system')
        
        tk.Button(nav_frame, text="Jump to Floor", command=jump_floor,
                 bg='#3498db', fg='#ffffff', font=('Arial', 10, 'bold')).grid(row=0, column=2, padx=5)
        tk.Button(nav_frame, text="Next Floor", command=next_floor_dev,
                 bg='#27ae60', fg='#ffffff', font=('Arial', 10, 'bold')).grid(row=0, column=3, padx=5)
        
        # Store debugging buttons
        def test_store():
            """Test function to debug store inventory generation"""
            print(f"[TEST] Current floor: {self.floor}")
            print(f"[TEST] Testing store inventory generation...")
            test_inventory = self.store_manager._generate_store_inventory()
            print(f"[TEST] Generated {len(test_inventory)} items")
            messagebox.showinfo("Store Test", f"Generated {len(test_inventory)} store items for floor {self.floor}.\nCheck console for details.")
        
        def refresh_store_debug():
            """Force refresh store inventory for debugging"""
            self.floor_store_inventory = None
            print(f"[DEBUG] Clearing store inventory, will regenerate on next store visit")
            messagebox.showinfo("Store Debug", "Store inventory cleared. Visit store again to see regenerated items.")
        
        tk.Button(nav_frame, text="Test Store", command=test_store,
                 bg='#e67e22', fg='#ffffff', font=('Arial', 10, 'bold')).grid(row=1, column=0, padx=5, pady=5)
        tk.Button(nav_frame, text="Clear Store", command=refresh_store_debug,
                 bg='#e74c3c', fg='#ffffff', font=('Arial', 10, 'bold')).grid(row=1, column=1, padx=5, pady=5)
        
        # ===== TAB 5: DEBUG INFO =====
        info_tab = tk.Frame(notebook, bg='#2c1810')
        notebook.add(info_tab, text="Info")
        
        tk.Label(info_tab, text="Debug Information", font=('Arial', 14, 'bold'),
                bg='#2c1810', fg='#f39c12').pack(pady=10)
        
        info_text = tk.Text(info_tab, bg='#1a1410', fg='#ffffff', font=('Consolas', 10),
                           wrap=tk.WORD, height=25, width=70)
        info_text.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        def refresh_info():
            info_text.delete('1.0', tk.END)
            info = f"""CURRENT GAME STATE
{'='*60}
Floor: {self.floor}
Health: {self.health}/{self.max_health}
Gold: {self.gold}
Inventory: {len(self.inventory)}/{self.max_inventory}
Dice: {self.num_dice}
Combat Active: {self.in_combat if hasattr(self, 'in_combat') else False}

DEVELOPER FLAGS
{'='*60}
Dev Mode: {self.dev_mode}
God Mode: {self.dev_invincible}

GAMEPLAY MULTIPLIERS
{'='*60}
Enemy HP: {self.dev_config['enemy_hp_mult']:.2f}x
Enemy Damage: {self.dev_config['enemy_damage_mult']:.2f}x
Player Damage: {self.dev_config['player_damage_mult']:.2f}x
Gold Drops: {self.dev_config['gold_drop_mult']:.2f}x
Shop Buy Price: {self.dev_config['shop_buy_price_mult']:.2f}x
Shop Sell Price: {self.dev_config['shop_sell_price_mult']:.2f}x

EQUIPPED ITEMS
{'='*60}
Weapon: {self.equipped_items.get('weapon', 'None')}
Armor: {self.equipped_items.get('armor', 'None')}
Accessory: {self.equipped_items.get('accessory', 'None')}
Backpack: {self.equipped_items.get('backpack', 'None')}
"""
            info_text.insert('1.0', info)
        
        refresh_info()
        
        tk.Button(info_tab, text="↻ Refresh", command=refresh_info,
                 bg='#3498db', fg='#ffffff', font=('Arial', 10, 'bold')).pack(pady=10)

if __name__ == "__main__":
    # Import required modules for splash screen
    import threading
    import time
    
    class SplashScreen:
        def __init__(self):
            self.splash = tk.Tk()
            self.splash.title("Dice Dungeon Explorer")
            self.splash.resizable(False, False)
            self.splash.configure(bg='#0a0604')
            
            # Calculate center position - increased size for better text visibility
            width = 650
            height = 450
            x = (self.splash.winfo_screenwidth() // 2) - (width // 2)
            y = (self.splash.winfo_screenheight() // 2) - (height // 2)
            self.splash.geometry(f'{width}x{height}+{x}+{y}')
            
            # Remove window decorations for true splash screen effect
            self.splash.overrideredirect(True)
            
            # Set window icon
            try:
                import os
                icon_path = os.path.join(os.path.dirname(__file__), "assets", "DD Logo.png")
                if os.path.exists(icon_path):
                    icon = tk.PhotoImage(file=icon_path)
                    self.splash.iconphoto(True, icon)
            except:
                pass
            
            # Create main frame
            main_frame = tk.Frame(self.splash, bg='#0a0604', relief=tk.RAISED, borderwidth=3)
            main_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)
            
            # Logo - smaller to leave more room for text
            try:
                logo_path = os.path.join(os.path.dirname(__file__), "assets", "DD Logo.png")
                if os.path.exists(logo_path):
                    # Load and resize logo - slightly smaller
                    from PIL import Image, ImageTk
                    img = Image.open(logo_path)
                    img = img.resize((120, 120), Image.LANCZOS)
                    self.logo_image = ImageTk.PhotoImage(img)
                    
                    logo_label = tk.Label(main_frame, image=self.logo_image, bg='#0a0604')
                    logo_label.pack(pady=(30, 15))
                else:
                    # Fallback text logo
                    tk.Label(main_frame, text="DD", font=('Arial', 42, 'bold'), 
                            bg='#0a0604', fg='#d4af37').pack(pady=(40, 15))
            except Exception as e:
                # Fallback text logo if PIL not available
                tk.Label(main_frame, text="DD", font=('Arial', 42, 'bold'), 
                        bg='#0a0604', fg='#d4af37').pack(pady=(40, 15))
            
            # Game title
            tk.Label(main_frame, text="DICE DUNGEON EXPLORER", 
                    font=('Arial', 22, 'bold'), bg='#0a0604', fg='#d4af37').pack(pady=8)
            
            # Subtitle
            tk.Label(main_frame, text="Explore • Fight • Loot • Survive", 
                    font=('Arial', 12, 'italic'), bg='#0a0604', fg='#8b7355').pack(pady=5)
            
            # Loading area - more space and better positioning
            loading_frame = tk.Frame(main_frame, bg='#0a0604')
            loading_frame.pack(pady=(30, 30), expand=True)
            
            # Loading text with dots on same line - fixed width to prevent movement
            text_frame = tk.Frame(loading_frame, bg='#0a0604')
            text_frame.pack()
            
            self.loading_label = tk.Label(text_frame, text="Loading game engine", 
                                        font=('Arial', 14), bg='#0a0604', fg='#e8dcc4')
            self.loading_label.pack(side=tk.LEFT)
            
            # Animated loading dots - on same line as text
            self.dots_label = tk.Label(text_frame, text="", 
                                     font=('Arial', 14), bg='#0a0604', fg='#d4af37')
            self.dots_label.pack(side=tk.LEFT)
            
            # Progress tracking - slower animation
            self.progress = 0
            self.max_progress = 25  # Slower - 5 seconds at 200ms intervals
            self.loading_messages = [
                "Loading game engine",
                "Loading content system", 
                "Initializing dice mechanics",
                "Loading enemy data",
                "Loading item definitions",
                "Preparing world lore",
                "Starting adventure"
            ]
            self.message_index = 0
            
            # Start loading animation
            self.animate_loading()
            
            # Start the main application after delay
            self.splash.after(5000, self.launch_game)  # 5 second splash
        
        def animate_loading(self):
            """Animate the loading screen - change messages in fixed position, slower animation"""
            if self.progress < self.max_progress:
                # Update dots animation - slower cycling
                dots = "." * ((self.progress % 3) + 1)  # Cycle through 1-3 dots
                self.dots_label.config(text=dots)
                
                # Update loading message occasionally - spread across 5 seconds
                message_interval = max(1, self.max_progress // len(self.loading_messages))
                if self.progress % message_interval == 0 and self.message_index < len(self.loading_messages):
                    self.loading_label.config(text=self.loading_messages[self.message_index])
                    self.message_index += 1
                
                self.progress += 1
                self.splash.after(200, self.animate_loading)  # 200ms intervals (slower)
            else:
                # Loading complete
                self.loading_label.config(text="Ready")
                self.dots_label.config(text="!")
        
        def launch_game(self):
            """Close splash and launch main game"""
            self.splash.destroy()
            
            # Now launch the main game
            root = tk.Tk()
            app = DiceDungeonExplorer(root)
            root.mainloop()
    
    # Show splash screen
    splash = SplashScreen()
    splash.splash.mainloop()
