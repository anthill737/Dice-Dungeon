"""
Dice Dungeon
A roguelike dice game with dungeon exploration - Betrayal at House on the Hill style
"""

import tkinter as tk
from tkinter import messagebox
import random
import json
import os
from collections import Counter

class Room:
    """Represents a dungeon room"""
    def __init__(self, room_type, x, y):
        self.type = room_type
        self.x = x
        self.y = y
        self.visited = False
        self.cleared = False
        self.exits = {'N': None, 'S': None, 'E': None, 'W': None}
        
class DiceDungeonExplorer:
    def __init__(self, root):
        self.root = root
        self.root.title("Dice Dungeon")
        self.root.geometry("900x700")
        self.root.minsize(600, 500)
        self.root.configure(bg='#2c1810')
        
        # High scores file
        self.scores_file = os.path.join(os.path.dirname(__file__), 'dice_dungeon_explorer_scores.json')
        
        # Player stats
        self.gold = 0
        self.health = 100
        self.max_health = 100
        self.floor = 1
        self.run_score = 0
        self.total_gold_earned = 0
        self.rooms_explored = 0
        self.game_active = False
        
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
        
        # Exploration state
        self.dungeon = {}  # Dict of (x,y) -> Room
        self.current_pos = (0, 0)  # Current position
        self.current_room = None
        self.in_combat = False
        
        # Enemy state
        self.enemy_health = 0
        self.enemy_max_health = 0
        self.enemy_name = ""
        self.enemy_num_dice = 2
        self.last_damage_was_crit = False
        
        # Room types database with rarity and difficulty
        self.room_types = self.initialize_room_types()
        
        # Flavor text (from original game)
        self.initialize_flavor_text()
        
        # UI elements
        self.main_frame = None
        self.game_frame = None
        self.dialog_frame = None
        
        # Show main menu
        self.show_main_menu()
    
    def initialize_room_types(self):
        """Initialize room type database - will be expanded to 100 rooms"""
        return {
            # COMMON ROOMS (60% spawn rate)
            'empty_corridor': {
                'name': 'Empty Corridor',
                'rarity': 'common',
                'difficulty': 1,
                'desc': 'A dimly lit stone corridor. Nothing of interest here.',
                'tags': ['safe'],
                'events': []
            },
            'guard_post': {
                'name': 'Guard Post',
                'rarity': 'common',
                'difficulty': 2,
                'desc': 'An abandoned guard post with broken weapons scattered about.',
                'tags': ['combat'],
                'events': ['spawn_goblin', 'find_small_gold']
            },
            'storage_room': {
                'name': 'Storage Room',
                'rarity': 'common',
                'difficulty': 1,
                'desc': 'Dusty crates and barrels fill this small room.',
                'tags': ['loot'],
                'events': ['find_gold', 'find_health_potion']
            },
            'dining_hall': {
                'name': 'Dining Hall',
                'rarity': 'common',
                'difficulty': 1,
                'desc': 'Long tables and benches. Food remnants suggest recent activity.',
                'tags': ['rest'],
                'events': ['rest_point', 'find_food']
            },
            
            # UNCOMMON ROOMS (25% spawn rate)
            'armory': {
                'name': 'Armory',
                'rarity': 'uncommon',
                'difficulty': 2,
                'desc': 'Weapon racks line the walls. Most are empty but some remain.',
                'tags': ['loot', 'combat'],
                'events': ['find_weapon', 'spawn_orc']
            },
            'treasure_vault': {
                'name': 'Treasure Vault',
                'rarity': 'uncommon',
                'difficulty': 3,
                'desc': 'A locked vault. The door hangs open, revealing riches within.',
                'tags': ['loot', 'trap'],
                'events': ['find_large_gold', 'trap_damage']
            },
            'library': {
                'name': 'Library',
                'rarity': 'uncommon',
                'difficulty': 1,
                'desc': 'Towering bookshelves filled with ancient tomes.',
                'tags': ['puzzle', 'loot'],
                'events': ['find_scroll', 'knowledge_bonus']
            },
            'chapel': {
                'name': 'Chapel',
                'rarity': 'uncommon',
                'difficulty': 1,
                'desc': 'A small shrine with candles still burning.',
                'tags': ['rest', 'blessing'],
                'events': ['heal_boost', 'blessing']
            },
            
            # RARE ROOMS (12% spawn rate)
            'boss_chamber': {
                'name': 'Boss Chamber',
                'rarity': 'rare',
                'difficulty': 5,
                'desc': 'A massive chamber. You sense a powerful presence here.',
                'tags': ['combat', 'boss'],
                'events': ['spawn_boss', 'rare_loot']
            },
            'magic_fountain': {
                'name': 'Magic Fountain',
                'rarity': 'rare',
                'difficulty': 2,
                'desc': 'Crystal clear water flows from an ornate fountain.',
                'tags': ['blessing', 'rest'],
                'events': ['full_heal', 'stat_boost']
            },
            'merchant_camp': {
                'name': 'Merchant Camp',
                'rarity': 'rare',
                'difficulty': 1,
                'desc': 'A traveling merchant has set up shop here.',
                'tags': ['shop'],
                'events': ['open_shop']
            },
            
            # LEGENDARY ROOMS (3% spawn rate)
            'dragon_hoard': {
                'name': 'Dragon Hoard',
                'rarity': 'legendary',
                'difficulty': 5,
                'desc': 'Mountains of gold and treasure! But a dragon sleeps atop it.',
                'tags': ['combat', 'boss', 'loot'],
                'events': ['spawn_dragon', 'massive_treasure']
            },
            'shrine_of_power': {
                'name': 'Shrine of Power',
                'rarity': 'legendary',
                'difficulty': 1,
                'desc': 'An ancient shrine radiating divine energy.',
                'tags': ['blessing', 'permanent'],
                'events': ['permanent_buff']
            },
            
            # SPECIAL ROOMS
            'entrance': {
                'name': 'Dungeon Entrance',
                'rarity': 'special',
                'difficulty': 0,
                'desc': 'The entrance to this floor of the dungeon.',
                'tags': ['safe', 'start'],
                'events': []
            },
            'stairs_down': {
                'name': 'Stairs Down',
                'rarity': 'special',
                'difficulty': 0,
                'desc': 'Stone stairs descending into darkness. The next floor awaits.',
                'tags': ['exit', 'safe'],
                'events': ['next_floor']
            }
        }
    
    def initialize_flavor_text(self):
        """Initialize combat flavor text"""
        self.enemy_taunts = {
            "Goblin": ["*snickers* Is that all?", "You hit like a merchant!", "Goblins never die!"],
            "Orc": ["WEAK HUMAN!", "Orc smash you!", "You bore me..."],
            "Troll": ["*laughs deeply*", "Troll regenerate! You lose!", "Puny adventurer!"],
            "Dragon": ["Your flames are nothing compared to mine!", "I've faced GODS!", "Amusing..."],
            "Demon": ["Your soul is MINE!", "I smell your fear...", "Pitiful mortal!"],
            "Lich": ["Death is only the beginning...", "Your magic is child's play!", "I've lived for eons!"],
            "Hydra": ["Cut off one head, two more appear!", "*all heads roar*", "You cannot win!"]
        }
        
        self.enemy_hurt = {
            "Goblin": ["Ow! That hurt!", "*squeals in pain*", "You'll pay for that!"],
            "Orc": ["ARGH!", "You dare?!", "*roars in anger*"],
            "Troll": ["*grunts*", "Barely felt that!", "Troll skin tough!"],
            "Dragon": ["Impossible!", "*roars furiously*", "You... hurt me?!"],
            "Demon": ["CURSE YOU!", "*hisses*", "This cannot be!"],
            "Lich": ["My defenses!", "*cackles madly*", "Impressive... for a mortal."],
            "Hydra": ["*shrieks*", "All heads feel that!", "*thrashes wildly*"]
        }
        
        self.enemy_death = {
            "Goblin": ["No... not like this... *collapses*", "*final squeak*", "Tell my tribe..."],
            "Orc": ["Orc... defeated... *falls*", "Impossible...", "*last roar*"],
            "Troll": ["Even trolls... can die...", "*crashes down*", "You... strong..."],
            "Dragon": ["My hoard... *crashes to ground*", "I... am... eternal... *dies*", "*final roar echoes*"],
            "Demon": ["Back to the void! *dissolves*", "I'll return!", "*screams as it fades*"],
            "Lich": ["My phylactery! *crumbles to dust*", "This isn't over!", "*evil laugh fades*"],
            "Hydra": ["*all heads collapse*", "Finally... rest...", "*massive thud*"]
        }
        
        self.player_attacks = [
            "You strike with precision!", "Your dice guide your blade!", "A devastating combo!",
            "You channel the power of fate!", "Your attack connects!", "A well-placed strike!",
            "The dice gods smile upon you!", "You unleash your fury!", "A tactical masterpiece!",
            "Your weapon finds its mark!", "Lightning-fast reflexes!", "You dance between danger!",
            "A calculated assault!", "Your training pays off!", "Raw power unleashed!"
        ]
        
        self.player_crits = [
            "*** CRITICAL HIT! *** A perfect strike!", "*** CRITICAL! *** You found a weak spot!",
            "*** MASSIVE HIT! *** The dice align perfectly!", "*** CRITICAL STRIKE! *** Devastating!",
            "*** PERFECT! *** Maximum damage!", "*** BRUTAL! *** A legendary blow!",
            "*** INCREDIBLE! *** The stars align!", "*** FLAWLESS! *** Unstoppable force!",
            "*** OBLITERATED! *** Pure destruction!", "*** ANNIHILATION! *** Nothing can stop you!"
        ]
    
    def show_main_menu(self):
        """Show the main menu"""
        if self.main_frame:
            self.main_frame.destroy()
        
        self.main_frame = tk.Frame(self.root, bg='#2c1810')
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Title
        tk.Label(self.main_frame, text="DICE DUNGEON", 
                font=('Arial', 24, 'bold'), bg='#2c1810', fg='#ffd700',
                pady=30).pack()
        
        tk.Label(self.main_frame, text="Explore. Battle. Survive.", 
                font=('Arial', 14), bg='#2c1810', fg='#ffffff',
                pady=10).pack()
        
        # Buttons
        btn_frame = tk.Frame(self.main_frame, bg='#2c1810')
        btn_frame.pack(pady=40)
        
        tk.Button(btn_frame, text="START ADVENTURE", 
                 command=self.start_new_game,
                 font=('Arial', 14, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=20, pady=15).pack(pady=10)
        
        tk.Button(btn_frame, text="VIEW HIGH SCORES", 
                 command=self.show_high_scores_screen,
                 font=('Arial', 12, 'bold'), bg='#ffd700', fg='#000000',
                 width=20, pady=12).pack(pady=10)
        
        tk.Button(btn_frame, text="QUIT", 
                 command=self.root.quit,
                 font=('Arial', 12, 'bold'), bg='#ff6b6b', fg='#000000',
                 width=20, pady=12).pack(pady=10)
    
    def start_new_game(self):
        """Initialize a new game"""
        # Reset stats
        self.gold = 0
        self.health = 100
        self.max_health = 100
        self.floor = 1
        self.run_score = 0
        self.total_gold_earned = 0
        self.rooms_explored = 0
        
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
        
        # Start first floor
        self.game_active = True
        self.start_new_floor()
    
    def start_new_floor(self):
        """Initialize a new floor"""
        # Clear dungeon
        self.dungeon = {}
        self.current_pos = (0, 0)
        self.in_combat = False
        
        # Create entrance room
        entrance = Room(self.room_types['entrance'], 0, 0)
        entrance.visited = True
        entrance.cleared = True
        self.dungeon[(0, 0)] = entrance
        self.current_room = entrance
        
        # Setup exploration UI
        self.setup_exploration_ui()
        
        self.log(f"=== FLOOR {self.floor} ===", 'system')
        self.log("You descend into a darker level of the dungeon...", 'system')
        self.log(f"Current room: {self.room_types['entrance']['name']}", 'system')
    
    def setup_exploration_ui(self):
        """Setup the exploration interface"""
        if self.main_frame:
            self.main_frame.destroy()
        
        self.game_frame = tk.Frame(self.root, bg='#2c1810')
        self.game_frame.pack(fill=tk.BOTH, expand=True)
        
        # Create scrollable canvas
        self.canvas = tk.Canvas(self.game_frame, bg='#2c1810', highlightthickness=0)
        self.scrollbar = tk.Scrollbar(self.game_frame, orient="vertical", command=self.canvas.yview)
        self.scroll_frame = tk.Frame(self.canvas, bg='#2c1810')
        
        self.scroll_frame.bind(
            "<Configure>",
            lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all"))
        )
        
        self.canvas.create_window((0, 0), window=self.scroll_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        
        self.canvas.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")
        
        # Build UI elements
        self._build_exploration_ui()
        
        # Bind resize event
        self.root.bind('<Configure>', self.on_window_resize)
    
    def _build_exploration_ui(self):
        """Build the exploration UI elements"""
        # Header with menu
        header = tk.Frame(self.scroll_frame, bg='#1a0f08', pady=10)
        header.pack(fill=tk.X)
        
        tk.Label(header, text="DICE DUNGEON", font=('Arial', 18, 'bold'),
                bg='#1a0f08', fg='#ffd700').pack(side=tk.LEFT, padx=20)
        
        # Menu button
        tk.Button(header, text="☰", command=self.show_hamburger_menu,
                 font=('Arial', 16, 'bold'), bg='#4a2c1a', fg='#ffffff',
                 width=3, pady=5).pack(side=tk.RIGHT, padx=10)
        
        # Help button
        tk.Button(header, text="?", command=self.show_help,
                 font=('Arial', 14, 'bold'), bg='#4a2c1a', fg='#ffffff',
                 width=3, pady=5).pack(side=tk.RIGHT, padx=5)
        
        # Stats panel
        stats_frame = tk.Frame(self.scroll_frame, bg='#3d2415', pady=10)
        stats_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Player stats
        player_frame = tk.Frame(stats_frame, bg='#3d2415')
        player_frame.pack(side=tk.LEFT, padx=20)
        
        self.hp_label = tk.Label(player_frame, text=f"HP: {self.health}/{self.max_health}",
                                font=('Arial', 12, 'bold'), bg='#3d2415', fg='#ff6b6b')
        self.hp_label.pack()
        
        self.gold_label = tk.Label(player_frame, text=f"Gold: {self.gold}",
                                   font=('Arial', 12), bg='#3d2415', fg='#ffd700')
        self.gold_label.pack()
        
        # Floor and room info
        floor_frame = tk.Frame(stats_frame, bg='#3d2415')
        floor_frame.pack(side=tk.LEFT, padx=20)
        
        self.floor_label = tk.Label(floor_frame, text=f"FLOOR {self.floor}",
                                    font=('Arial', 12, 'bold'), bg='#3d2415', fg='#4ecdc4')
        self.floor_label.pack()
        
        self.rooms_label = tk.Label(floor_frame, text=f"Rooms: {self.rooms_explored}",
                                    font=('Arial', 10), bg='#3d2415', fg='#ffffff')
        self.rooms_label.pack()
        
        # Score
        score_frame = tk.Frame(stats_frame, bg='#3d2415')
        score_frame.pack(side=tk.LEFT, padx=20)
        
        self.score_label = tk.Label(score_frame, text=f"Score: {self.run_score}",
                                    font=('Arial', 12), bg='#3d2415', fg='#95e1d3')
        self.score_label.pack()
        
        # Map display
        map_frame = tk.Frame(self.scroll_frame, bg='#2c1810', pady=10)
        map_frame.pack(fill=tk.X, padx=10)
        
        tk.Label(map_frame, text="MAP", font=('Arial', 14, 'bold'),
                bg='#2c1810', fg='#ffd700').pack()
        
        self.map_canvas = tk.Canvas(map_frame, bg='#1a0f08', width=400, height=200,
                                    highlightthickness=2, highlightbackground='#4a2c1a')
        self.map_canvas.pack(pady=5)
        
        # Current room info
        room_frame = tk.Frame(self.scroll_frame, bg='#3d2415', pady=15)
        room_frame.pack(fill=tk.X, padx=10, pady=10)
        
        self.room_name_label = tk.Label(room_frame, text="",
                                        font=('Arial', 16, 'bold'), bg='#3d2415', fg='#ffd700')
        self.room_name_label.pack()
        
        self.room_desc_label = tk.Label(room_frame, text="", wraplength=500,
                                        font=('Arial', 11), bg='#3d2415', fg='#ffffff',
                                        justify=tk.LEFT)
        self.room_desc_label.pack(pady=5)
        
        # Actions
        actions_frame = tk.Frame(self.scroll_frame, bg='#2c1810')
        actions_frame.pack(pady=10)
        
        tk.Label(actions_frame, text="ACTIONS", font=('Arial', 12, 'bold'),
                bg='#2c1810', fg='#ffffff').pack()
        
        btn_container = tk.Frame(actions_frame, bg='#2c1810')
        btn_container.pack(pady=5)
        
        # Direction buttons
        dir_frame = tk.Frame(btn_container, bg='#2c1810')
        dir_frame.pack()
        
        # North
        self.north_btn = tk.Button(dir_frame, text="↑ NORTH", command=lambda: self.explore_direction('N'),
                                   font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                   width=12, pady=8)
        self.north_btn.grid(row=0, column=1, padx=5, pady=5)
        
        # West and East
        self.west_btn = tk.Button(dir_frame, text="← WEST", command=lambda: self.explore_direction('W'),
                                  font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                  width=12, pady=8)
        self.west_btn.grid(row=1, column=0, padx=5, pady=5)
        
        self.east_btn = tk.Button(dir_frame, text="EAST →", command=lambda: self.explore_direction('E'),
                                  font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                  width=12, pady=8)
        self.east_btn.grid(row=1, column=2, padx=5, pady=5)
        
        # South
        self.south_btn = tk.Button(dir_frame, text="↓ SOUTH", command=lambda: self.explore_direction('S'),
                                   font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                   width=12, pady=8)
        self.south_btn.grid(row=2, column=1, padx=5, pady=5)
        
        # Other actions
        action_btns = tk.Frame(btn_container, bg='#2c1810')
        action_btns.pack(pady=10)
        
        self.rest_btn = tk.Button(action_btns, text="REST (Heal 20)", command=self.rest,
                                  font=('Arial', 11, 'bold'), bg='#95e1d3', fg='#000000',
                                  width=15, pady=8)
        self.rest_btn.pack(side=tk.LEFT, padx=5)
        
        self.interact_btn = tk.Button(action_btns, text="INTERACT", command=self.interact_with_room,
                                      font=('Arial', 11, 'bold'), bg='#ffd700', fg='#000000',
                                      width=15, pady=8)
        self.interact_btn.pack(side=tk.LEFT, padx=5)
        
        # Combat log
        log_frame = tk.Frame(self.scroll_frame, bg='#2c1810')
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        tk.Label(log_frame, text="ADVENTURE LOG", font=('Arial', 12, 'bold'),
                bg='#2c1810', fg='#ffd700').pack()
        
        self.log_text = tk.Text(log_frame, height=12, bg='#1a0f08', fg='#00ff00',
                               font=('Consolas', 9), wrap=tk.WORD, state=tk.DISABLED)
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Configure text tags for colored output
        self.log_text.tag_config('player', foreground='#4ecdc4')
        self.log_text.tag_config('enemy', foreground='#ff6b6b')
        self.log_text.tag_config('system', foreground='#ffd700')
        self.log_text.tag_config('crit', foreground='#ff00ff')
        
        self.update_display()
    
    def update_display(self):
        """Update all display elements"""
        if not hasattr(self, 'hp_label'):
            return
        
        # Update stats
        self.hp_label.config(text=f"HP: {self.health}/{self.max_health}")
        self.gold_label.config(text=f"Gold: {self.gold}")
        self.floor_label.config(text=f"FLOOR {self.floor}")
        self.rooms_label.config(text=f"Rooms: {self.rooms_explored}")
        self.score_label.config(text=f"Score: {self.run_score}")
        
        # Update room info
        if self.current_room:
            room_type = self.current_room.type
            self.room_name_label.config(text=room_type['name'])
            self.room_desc_label.config(text=room_type['desc'])
        
        # Update map
        self.draw_map()
        
        # Update direction buttons
        self.update_direction_buttons()
    
    def draw_map(self):
        """Draw the dungeon map"""
        self.map_canvas.delete("all")
        
        # Calculate bounds
        if not self.dungeon:
            return
        
        xs = [pos[0] for pos in self.dungeon.keys()]
        ys = [pos[1] for pos in self.dungeon.keys()]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        
        # Room size and spacing
        room_size = 30
        spacing = 40
        
        # Center the map
        offset_x = 200 - ((max_x + min_x) * spacing // 2)
        offset_y = 100 - ((max_y + min_y) * spacing // 2)
        
        # Draw connections first
        for pos, room in self.dungeon.items():
            x, y = pos
            cx = offset_x + x * spacing
            cy = offset_y - y * spacing  # Flip Y for screen coordinates
            
            # Draw connections
            for direction, connected in room.exits.items():
                if connected and connected in self.dungeon:
                    nx, ny = connected
                    ncx = offset_x + nx * spacing
                    ncy = offset_y - ny * spacing
                    self.map_canvas.create_line(cx, cy, ncx, ncy, fill='#4a2c1a', width=2)
        
        # Draw rooms
        for pos, room in self.dungeon.items():
            x, y = pos
            cx = offset_x + x * spacing
            cy = offset_y - y * spacing
            
            # Determine room color based on state
            if pos == self.current_pos:
                color = '#ffd700'  # Current room - gold
            elif room.cleared:
                color = '#4ecdc4'  # Cleared - cyan
            elif room.visited:
                color = '#95e1d3'  # Visited - light cyan
            else:
                color = '#666666'  # Unvisited - gray
            
            # Draw room square
            size = room_size // 2
            self.map_canvas.create_rectangle(cx-size, cy-size, cx+size, cy+size,
                                            fill=color, outline='#ffffff', width=2)
            
            # Draw room type indicator
            if room.type['rarity'] == 'rare':
                self.map_canvas.create_text(cx, cy, text="!", fill='#ff6b6b', font=('Arial', 14, 'bold'))
            elif room.type['rarity'] == 'legendary':
                self.map_canvas.create_text(cx, cy, text="★", fill='#ff00ff', font=('Arial', 14, 'bold'))
    
    def update_direction_buttons(self):
        """Enable/disable direction buttons based on available exits"""
        if not self.current_room:
            return
        
        # Check each direction
        for direction, btn in [('N', self.north_btn), ('S', self.south_btn),
                               ('E', self.east_btn), ('W', self.west_btn)]:
            # Enable if not yet explored in that direction
            can_explore = self.get_adjacent_pos(direction) not in self.dungeon
            btn.config(state=tk.NORMAL if can_explore else tk.DISABLED)
    
    def get_adjacent_pos(self, direction):
        """Get the position adjacent to current position in given direction"""
        x, y = self.current_pos
        if direction == 'N':
            return (x, y + 1)
        elif direction == 'S':
            return (x, y - 1)
        elif direction == 'E':
            return (x + 1, y)
        elif direction == 'W':
            return (x - 1, y)
    
    def explore_direction(self, direction):
        """Explore in the given direction"""
        new_pos = self.get_adjacent_pos(direction)
        
        # Check if already explored
        if new_pos in self.dungeon:
            self.log("You've already explored that direction!", 'system')
            return
        
        # Generate new room
        new_room = self.generate_random_room(new_pos[0], new_pos[1])
        self.dungeon[new_pos] = new_room
        
        # Connect rooms
        self.current_room.exits[direction] = new_pos
        opposite = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}
        new_room.exits[opposite[direction]] = self.current_pos
        
        # Move to new room
        self.current_pos = new_pos
        self.current_room = new_room
        self.current_room.visited = True
        self.rooms_explored += 1
        
        self.log(f"You explore {direction} and discover: {new_room.type['name']}", 'system')
        self.log(new_room.type['desc'], 'system')
        
        # Trigger room events
        self.trigger_room_events()
        
        self.update_display()
    
    def generate_random_room(self, x, y):
        """Generate a random room based on rarity"""
        # Determine rarity based on roll
        roll = random.random()
        
        if roll < 0.03:  # 3% legendary
            rarity = 'legendary'
        elif roll < 0.15:  # 12% rare
            rarity = 'rare'
        elif roll < 0.40:  # 25% uncommon
            rarity = 'uncommon'
        else:  # 60% common
            rarity = 'common'
        
        # Filter rooms by rarity
        available_rooms = [rt for rt in self.room_types.values() 
                          if rt['rarity'] == rarity]
        
        # Pick random room of that rarity
        room_type = random.choice(available_rooms)
        
        return Room(room_type, x, y)
    
    def trigger_room_events(self):
        """Trigger events based on current room"""
        if not self.current_room or not self.current_room.type['events']:
            return
        
        # Pick random event from room
        event = random.choice(self.current_room.type['events'])
        
        # Handle different event types
        if event == 'spawn_goblin':
            self.spawn_enemy("Goblin", 30, 2)
        elif event == 'spawn_orc':
            self.spawn_enemy("Orc", 50, 3)
        elif event == 'spawn_boss':
            self.spawn_boss()
        elif event == 'spawn_dragon':
            self.spawn_enemy("Dragon", 150, 5)
        elif event == 'find_gold':
            amount = random.randint(10, 30)
            self.gold += amount
            self.log(f"You found {amount} gold!", 'system')
        elif event == 'find_small_gold':
            amount = random.randint(5, 15)
            self.gold += amount
            self.log(f"You found {amount} gold!", 'system')
        elif event == 'find_large_gold':
            amount = random.randint(50, 100)
            self.gold += amount
            self.log(f"You found {amount} gold!", 'system')
        elif event == 'find_health_potion':
            heal = 30
            self.health = min(self.health + heal, self.max_health)
            self.log(f"You found a health potion! Healed {heal} HP", 'system')
        elif event == 'rest_point':
            self.log("This looks like a good place to rest.", 'system')
        elif event == 'full_heal':
            self.health = self.max_health
            self.log("The magic fountain fully restores your health!", 'system')
        elif event == 'next_floor':
            self.log("The stairs beckon you deeper into the dungeon...", 'system')
        
        self.update_display()
    
    def spawn_enemy(self, name, health, num_dice):
        """Spawn an enemy in the current room"""
        self.enemy_name = name
        self.enemy_health = health + (self.floor * 10)
        self.enemy_max_health = self.enemy_health
        self.enemy_num_dice = min(num_dice + (self.floor // 3), 6)
        self.in_combat = True
        
        self.log(f"{name} appears! HP: {self.enemy_health}", 'enemy')
        self.log(f"{name} wields {self.enemy_num_dice} dice!", 'enemy')
        
        # Switch to combat UI
        self.setup_combat_ui()
    
    def spawn_boss(self):
        """Spawn a floor boss"""
        bosses = ["Troll", "Demon", "Lich", "Hydra"]
        boss = random.choice(bosses)
        health = 80 + (self.floor * 30)
        dice = min(3 + (self.floor // 2), 6)
        
        self.log("*** BOSS ENCOUNTER ***", 'system')
        self.spawn_enemy(boss, health, dice)
    
    def setup_combat_ui(self):
        """Switch to combat interface"""
        # Will implement dice combat UI similar to original game
        self.log("Combat UI - TODO: Implement dice rolling interface", 'system')
        # For now, placeholder
        pass
    
    def rest(self):
        """Rest to heal"""
        if self.in_combat:
            self.log("You cannot rest during combat!", 'enemy')
            return
        
        heal = 20 + self.heal_bonus
        self.health = min(self.health + heal, self.max_health)
        self.log(f"You rest and recover {heal} HP", 'system')
        self.update_display()
    
    def interact_with_room(self):
        """Interact with the current room"""
        if not self.current_room:
            return
        
        room_type = self.current_room.type
        
        if 'next_floor' in room_type['events']:
            self.descend_floor()
        elif 'open_shop' in room_type['events']:
            self.log("Opening shop... (TODO)", 'system')
        else:
            self.log("Nothing to interact with here.", 'system')
    
    def descend_floor(self):
        """Go to the next floor"""
        self.floor += 1
        self.run_score += 100 * self.floor
        self.log(f"You descend to Floor {self.floor}!", 'system')
        self.start_new_floor()
    
    def log(self, message, tag='system'):
        """Add message to the log"""
        if not hasattr(self, 'log_text'):
            return
        
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + '\n', tag)
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
    
    def on_window_resize(self, event=None):
        """Handle window resize"""
        pass
    
    def show_hamburger_menu(self):
        """Show the hamburger menu"""
        self.log("Menu - TODO", 'system')
    
    def show_help(self):
        """Show help dialog"""
        self.log("Help - TODO", 'system')
    
    def show_high_scores_screen(self):
        """Show high scores"""
        self.log("High Scores - TODO", 'system')

if __name__ == "__main__":
    root = tk.Tk()
    app = DiceDungeonExplorer(root)
    root.mainloop()
