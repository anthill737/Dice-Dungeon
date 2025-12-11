"""
Dice Dungeon Explorer
A roguelike dice game with dungeon exploration integrated with content system
"""

import tkinter as tk
from tkinter import messagebox
import random
import json
import os
import sys
from collections import Counter

# Add content engine to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dice_dungeon_content', 'engine'))

from rooms_loader import load_rooms, pick_room_for_floor
from mechanics_engine import apply_on_enter, apply_on_clear, apply_on_fail, settle_temp_effects, get_effective_stats
from integration_hooks import attach_content, start_room_for_floor, complete_room_success, complete_room_fail, on_floor_transition, apply_effective_modifiers

class Room:
    """Represents a dungeon room position"""
    def __init__(self, room_data, x, y):
        self.data = room_data  # The actual room definition from JSON
        self.x = x
        self.y = y
        self.visited = False
        self.cleared = False
        self.exits = {'N': None, 'S': None, 'E': None, 'W': None}

class DiceDungeonExplorer:
    def __init__(self, root):
        self.root = root
        self.root.title("Dice Dungeon Explorer")
        self.root.geometry("900x700")
        self.root.minsize(600, 500)
        self.root.configure(bg='#2c1810')
        
        # High scores file
        self.scores_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dice_dungeon_explorer_scores.json')
        
        # Load content system
        try:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            attach_content(self, base_dir)
            self.content_loaded = True
        except Exception as e:
            messagebox.showerror("Content Load Error", f"Failed to load game content:\n{e}")
            self.content_loaded = False
            self.root.quit()
            return
        
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
        
        # Content system tracking (required by mechanics_engine)
        self.inventory = []
        self.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
        self.temp_effects = {}
        self.temp_shield = 0
        self.shop_discount = 0.0
        
        # Exploration state
        self.dungeon = {}  # Dict of (x,y) -> Room
        self.current_pos = (0, 0)
        self.current_room = None
        self.in_combat = False
        
        # Enemy state
        self.enemy_health = 0
        self.enemy_max_health = 0
        self.enemy_name = ""
        self.enemy_num_dice = 2
        self.last_damage_was_crit = False
        
        # Flavor text
        self.initialize_flavor_text()
        
        # UI elements
        self.main_frame = None
        self.game_frame = None
        self.dialog_frame = None
        self.dice_buttons = []
        
        # Show main menu
        self.show_main_menu()
    
    def initialize_flavor_text(self):
        """Initialize combat flavor text"""
        self.enemy_taunts = {
            "Goblin": ["*snickers* Is that all?", "You hit like a merchant!", "Goblins never die!"],
            "Orc": ["WEAK HUMAN!", "Orc smash you!", "You bore me..."],
            "Troll": ["*laughs deeply*", "Troll regenerate! You lose!", "Puny adventurer!"],
            "Dragon": ["Your flames are nothing compared to mine!", "I've faced GODS!", "Amusing..."],
            "Demon": ["Your soul is MINE!", "I smell your fear...", "Pitiful mortal!"],
            "Lich": ["Death is only the beginning...", "Your magic is child's play!", "I've lived for eons!"]
        }
        
        self.enemy_hurt = {
            "Goblin": ["Ow! That hurt!", "*squeals in pain*", "You'll pay for that!"],
            "Orc": ["ARGH!", "You dare?!", "*roars in anger*"],
            "Troll": ["*grunts*", "Barely felt that!", "Troll skin tough!"],
            "Dragon": ["Impossible!", "*roars furiously*", "You... hurt me?!"],
            "Demon": ["CURSE YOU!", "*hisses*", "This cannot be!"],
            "Lich": ["My defenses!", "*cackles madly*", "Impressive... for a mortal."]
        }
        
        self.enemy_death = {
            "Goblin": ["No... not like this... *collapses*", "*final squeak*"],
            "Orc": ["Orc... defeated... *falls*", "Impossible..."],
            "Troll": ["Even trolls... can die...", "*crashes down*"],
            "Dragon": ["My hoard... *crashes to ground*", "I... am... eternal... *dies*"],
            "Demon": ["Back to the void! *dissolves*", "I'll return!"],
            "Lich": ["My phylactery! *crumbles to dust*", "This isn't over!"]
        }
        
        self.player_attacks = [
            "You strike with precision!", "Your dice guide your blade!", "A devastating combo!",
            "You channel the power of fate!", "Your attack connects!", "A well-placed strike!"
        ]
        
        self.player_crits = [
            "*** CRITICAL HIT! *** A perfect strike!", "*** CRITICAL! *** You found a weak spot!",
            "*** MASSIVE HIT! *** The dice align perfectly!"
        ]
    
    def log(self, message, tag='system'):
        """Add message to the log"""
        if not hasattr(self, 'log_text'):
            print(f"[{tag}] {message}")  # Fallback to console
            return
        
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + '\n', tag)
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
    
    def show_main_menu(self):
        """Show the main menu"""
        if not self.content_loaded:
            return
        
        if self.main_frame:
            self.main_frame.destroy()
        
        self.main_frame = tk.Frame(self.root, bg='#2c1810')
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Title
        tk.Label(self.main_frame, text="DICE DUNGEON EXPLORER", 
                font=('Arial', 24, 'bold'), bg='#2c1810', fg='#ffd700',
                pady=30).pack()
        
        tk.Label(self.main_frame, text="Explore procedurally generated dungeons", 
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
                 command=self.show_high_scores_menu,
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
        
        # Reset content tracking
        self.inventory = []
        self.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
        self.temp_effects = {}
        self.temp_shield = 0
        self.shop_discount = 0.0
        
        # Start first floor
        self.game_active = True
        self.start_new_floor()
    
    def start_new_floor(self):
        """Initialize a new floor"""
        # Clear dungeon
        self.dungeon = {}
        self.current_pos = (0, 0)
        self.in_combat = False
        
        # Pick a room for this floor using the content system
        room_data = pick_room_for_floor(self._rooms, self.floor)
        
        # Create entrance room
        entrance = Room(room_data, 0, 0)
        entrance.visited = True
        self.dungeon[(0, 0)] = entrance
        self.current_room = entrance
        self._current_room = room_data  # For mechanics engine
        
        # Setup exploration UI
        self.setup_exploration_ui()
        
        # Apply floor transition effects
        on_floor_transition(self)
        
        # Log room entry
        self.log(f"=== FLOOR {self.floor} ===", 'system')
        self.log(f"Room: {room_data['name']} ({room_data['difficulty']})", 'system')
        self.log(room_data['flavor'], 'system')
        
        # Apply room entry effects
        apply_on_enter(self, room_data, self.log)
        
        # Update effective stats
        apply_effective_modifiers(self)
        
        self.update_display()
    
    def setup_exploration_ui(self):
        """Setup the exploration interface"""
        if self.main_frame:
            self.main_frame.destroy()
        if self.game_frame:
            self.game_frame.destroy()
        
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
    
    def _build_exploration_ui(self):
        """Build the exploration UI elements"""
        # Header
        header = tk.Frame(self.scroll_frame, bg='#1a0f08', pady=10)
        header.pack(fill=tk.X)
        
        tk.Label(header, text="DICE DUNGEON EXPLORER", font=('Arial', 18, 'bold'),
                bg='#1a0f08', fg='#ffd700').pack(side=tk.LEFT, padx=20)
        
        # Menu button
        tk.Button(header, text="☰", command=self.show_game_menu,
                 font=('Arial', 16, 'bold'), bg='#4a2c1a', fg='#ffffff',
                 width=3, pady=5).pack(side=tk.RIGHT, padx=10)
        
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
        
        # Floor info
        floor_frame = tk.Frame(stats_frame, bg='#3d2415')
        floor_frame.pack(side=tk.LEFT, padx=20)
        
        self.floor_label = tk.Label(floor_frame, text=f"FLOOR {self.floor}",
                                    font=('Arial', 12, 'bold'), bg='#3d2415', fg='#4ecdc4')
        self.floor_label.pack()
        
        self.rooms_label = tk.Label(floor_frame, text=f"Rooms: {self.rooms_explored}",
                                    font=('Arial', 10), bg='#3d2415', fg='#ffffff')
        self.rooms_label.pack()
        
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
        
        tk.Label(actions_frame, text="EXPLORE", font=('Arial', 12, 'bold'),
                bg='#2c1810', fg='#ffffff').pack()
        
        # Direction buttons
        dir_frame = tk.Frame(actions_frame, bg='#2c1810')
        dir_frame.pack(pady=5)
        
        self.north_btn = tk.Button(dir_frame, text="↑ NORTH", command=lambda: self.explore_direction('N'),
                                   font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                   width=12, pady=8)
        self.north_btn.grid(row=0, column=1, padx=5, pady=5)
        
        self.west_btn = tk.Button(dir_frame, text="← WEST", command=lambda: self.explore_direction('W'),
                                  font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                  width=12, pady=8)
        self.west_btn.grid(row=1, column=0, padx=5, pady=5)
        
        self.east_btn = tk.Button(dir_frame, text="EAST →", command=lambda: self.explore_direction('E'),
                                  font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                  width=12, pady=8)
        self.east_btn.grid(row=1, column=2, padx=5, pady=5)
        
        self.south_btn = tk.Button(dir_frame, text="↓ SOUTH", command=lambda: self.explore_direction('S'),
                                   font=('Arial', 10, 'bold'), bg='#4ecdc4', fg='#000000',
                                   width=12, pady=8)
        self.south_btn.grid(row=2, column=1, padx=5, pady=5)
        
        # Other actions
        action_btns = tk.Frame(actions_frame, bg='#2c1810')
        action_btns.pack(pady=10)
        
        tk.Button(action_btns, text="REST (Heal 20)", command=self.rest,
                 font=('Arial', 11, 'bold'), bg='#95e1d3', fg='#000000',
                 width=15, pady=8).pack(side=tk.LEFT, padx=5)
        
        tk.Button(action_btns, text="NEXT FLOOR", command=self.descend_floor,
                 font=('Arial', 11, 'bold'), bg='#ffd700', fg='#000000',
                 width=15, pady=8).pack(side=tk.LEFT, padx=5)
        
        tk.Button(action_btns, text="VIEW INVENTORY", command=self.show_inventory,
                 font=('Arial', 11, 'bold'), bg='#9b59b6', fg='#ffffff',
                 width=15, pady=8).pack(side=tk.LEFT, padx=5)
        
        # Adventure log
        log_frame = tk.Frame(self.scroll_frame, bg='#2c1810')
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        tk.Label(log_frame, text="ADVENTURE LOG", font=('Arial', 12, 'bold'),
                bg='#2c1810', fg='#ffd700').pack()
        
        self.log_text = tk.Text(log_frame, height=12, bg='#1a0f08', fg='#00ff00',
                               font=('Consolas', 9), wrap=tk.WORD, state=tk.DISABLED)
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Configure text tags
        self.log_text.tag_config('player', foreground='#4ecdc4')
        self.log_text.tag_config('enemy', foreground='#ff6b6b')
        self.log_text.tag_config('system', foreground='#ffd700')
        self.log_text.tag_config('crit', foreground='#ff00ff')
        self.log_text.tag_config('item', foreground='#9b59b6')
    
    def update_display(self):
        """Update all display elements"""
        if not hasattr(self, 'hp_label'):
            return
        
        self.hp_label.config(text=f"HP: {self.health}/{self.max_health}")
        self.gold_label.config(text=f"Gold: {self.gold}")
        self.floor_label.config(text=f"FLOOR {self.floor}")
        self.rooms_label.config(text=f"Rooms: {self.rooms_explored}")
        
        if self.current_room and self.current_room.data:
            room_data = self.current_room.data
            self.room_name_label.config(text=room_data['name'])
            
            # Build room description with tags
            desc_parts = [room_data['flavor']]
            if room_data.get('tags'):
                desc_parts.append(f"\nTags: {', '.join(room_data['tags'])}")
            if room_data.get('threats'):
                desc_parts.append(f"\nThreats: {', '.join(room_data['threats'])}")
            
            self.room_desc_label.config(text='\n'.join(desc_parts))
        
        self.update_direction_buttons()
    
    def update_direction_buttons(self):
        """Enable/disable direction buttons"""
        if not self.current_room:
            return
        
        for direction, btn in [('N', self.north_btn), ('S', self.south_btn),
                               ('E', self.east_btn), ('W', self.west_btn)]:
            can_explore = self.get_adjacent_pos(direction) not in self.dungeon
            btn.config(state=tk.NORMAL if can_explore else tk.DISABLED)
    
    def get_adjacent_pos(self, direction):
        """Get adjacent position"""
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
        """Explore in given direction"""
        new_pos = self.get_adjacent_pos(direction)
        
        if new_pos in self.dungeon:
            self.log("Already explored that direction!", 'system')
            return
        
        # Pick a new room for this floor
        room_data = pick_room_for_floor(self._rooms, self.floor)
        new_room = Room(room_data, new_pos[0], new_pos[1])
        self.dungeon[new_pos] = new_room
        
        # Connect rooms
        opposite = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}
        self.current_room.exits[direction] = new_pos
        new_room.exits[opposite[direction]] = self.current_pos
        
        # Move to new room
        self.current_pos = new_pos
        self.current_room = new_room
        self.current_room.visited = True
        self._current_room = room_data
        self.rooms_explored += 1
        
        self.log(f"\n{'='*50}", 'system')
        self.log(f"Discovered: {room_data['name']} ({room_data['difficulty']})", 'system')
        self.log(room_data['flavor'], 'system')
        
        # Show discoverables
        if room_data.get('discoverables'):
            self.log(f"You notice: {', '.join(room_data['discoverables'])}", 'system')
        
        # Apply room effects
        apply_on_enter(self, room_data, self.log)
        apply_effective_modifiers(self)
        
        # Check for combat
        if 'combat' in room_data.get('tags', []):
            self.trigger_combat(room_data)
        
        self.update_display()
    
    def trigger_combat(self, room_data):
        """Trigger combat based on room threats"""
        threats = room_data.get('threats', [])
        if threats:
            enemy_name = random.choice(threats)
            self.log(f"\n⚔️  {enemy_name} blocks your path!", 'enemy')
            
            # Check if we have combat mechanics in the room
            mechanics = room_data.get('mechanics', {})
            if mechanics:
                self.log("(Mechanics applied - check room effects above)", 'system')
    
    def rest(self):
        """Rest to heal"""
        heal = 20 + self.heal_bonus
        old_hp = self.health
        self.health = min(self.health + heal, self.max_health)
        actual_heal = self.health - old_hp
        
        if actual_heal > 0:
            self.log(f"💚 You rest and recover {actual_heal} HP", 'system')
        else:
            self.log("You're already at full health!", 'system')
        
        self.update_display()
    
    def descend_floor(self):
        """Go to next floor"""
        if self.current_room:
            complete_room_success(self, self.log)
        
        self.floor += 1
        self.run_score += 100 * self.floor
        self.log(f"\n{'='*50}", 'system')
        self.log(f"🔽 Descending to Floor {self.floor}...", 'system')
        self.start_new_floor()
    
    def show_inventory(self):
        """Show player inventory"""
        if not self.inventory:
            self.log("Your inventory is empty.", 'system')
            return
        
        self.log("\n=== INVENTORY ===", 'item')
        for item in self.inventory:
            self.log(f"• {item}", 'item')
        
        # Show flags
        if self.flags['disarm_token'] > 0:
            self.log(f"🛡️  Disarm Tokens: {self.flags['disarm_token']}", 'item')
        if self.flags['escape_token'] > 0:
            self.log(f"🏃 Escape Tokens: {self.flags['escape_token']}", 'item')
        if self.flags['statuses']:
            self.log(f"⚡ Active Statuses: {', '.join(self.flags['statuses'])}", 'item')
    
    def show_game_menu(self):
        """Show in-game menu"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        # Create dialog
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=300, height=250)
        
        tk.Label(self.dialog_frame, text="MENU", font=('Arial', 16, 'bold'),
                bg='#1a0f08', fg='#ffd700', pady=15).pack()
        
        tk.Button(self.dialog_frame, text="Resume", command=self.close_dialog,
                 font=('Arial', 12), bg='#4ecdc4', fg='#000000',
                 width=15, pady=10).pack(pady=5)
        
        tk.Button(self.dialog_frame, text="View Stats", command=self.show_stats_dialog,
                 font=('Arial', 12), bg='#95e1d3', fg='#000000',
                 width=15, pady=10).pack(pady=5)
        
        tk.Button(self.dialog_frame, text="Return to Menu", command=self.return_to_menu,
                 font=('Arial', 12), bg='#ff6b6b', fg='#000000',
                 width=15, pady=10).pack(pady=5)
    
    def show_stats_dialog(self):
        """Show detailed stats"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
        
        self.dialog_frame = tk.Frame(self.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, width=400, height=450)
        
        tk.Label(self.dialog_frame, text="STATS", font=('Arial', 16, 'bold'),
                bg='#1a0f08', fg='#ffd700', pady=10).pack()
        
        stats_text = tk.Text(self.dialog_frame, height=15, bg='#2c1810', fg='#ffffff',
                            font=('Consolas', 10), wrap=tk.WORD)
        stats_text.pack(padx=10, pady=5, fill=tk.BOTH, expand=True)
        
        # Build stats display
        stats = f"""
HP: {self.health}/{self.max_health}
Gold: {self.gold}
Total Gold Earned: {self.total_gold_earned}
Floor: {self.floor}
Rooms Explored: {self.rooms_explored}
Run Score: {self.run_score}

=== DICE ===
Number of Dice: {self.num_dice}

=== POWER-UPS ===
Damage Multiplier: {self.multiplier:.1f}x
Damage Bonus: +{self.damage_bonus}
Heal Bonus: +{self.heal_bonus}
Reroll Bonus: +{self.reroll_bonus}
Crit Chance: {self.crit_chance*100:.0f}%

=== CONTENT SYSTEM ===
Inventory: {len(self.inventory)} items
Disarm Tokens: {self.flags['disarm_token']}
Escape Tokens: {self.flags['escape_token']}
Active Statuses: {len(self.flags['statuses'])}
Temp Effects: {len(self.temp_effects)}
Temp Shield: {self.temp_shield}
"""
        
        stats_text.insert('1.0', stats.strip())
        stats_text.config(state=tk.DISABLED)
        
        tk.Button(self.dialog_frame, text="Close", command=self.close_dialog,
                 font=('Arial', 12), bg='#4ecdc4', fg='#000000',
                 width=15, pady=10).pack(pady=10)
    
    def close_dialog(self):
        """Close current dialog"""
        if self.dialog_frame:
            self.dialog_frame.destroy()
            self.dialog_frame = None
    
    def return_to_menu(self):
        """Return to main menu"""
        self.game_active = False
        self.close_dialog()
        if self.game_frame:
            self.game_frame.destroy()
        self.show_main_menu()
    
    def show_high_scores_menu(self):
        """Show high scores"""
        if not os.path.exists(self.scores_file):
            messagebox.showinfo("High Scores", "No high scores yet! Play a game to set one.")
            return
        
        try:
            with open(self.scores_file, 'r') as f:
                scores = json.load(f)
        except:
            messagebox.showinfo("High Scores", "No high scores yet!")
            return
        
        # Create dialog
        if self.main_frame:
            self.main_frame.destroy()
        
        self.main_frame = tk.Frame(self.root, bg='#2c1810')
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        tk.Label(self.main_frame, text="HIGH SCORES", font=('Arial', 20, 'bold'),
                bg='#2c1810', fg='#ffd700', pady=20).pack()
        
        # Display scores
        scores_text = tk.Text(self.main_frame, height=15, bg='#1a0f08', fg='#00ff00',
                             font=('Consolas', 11), wrap=tk.NONE, state=tk.DISABLED)
        scores_text.pack(padx=20, pady=10, fill=tk.BOTH, expand=True)
        
        scores_text.config(state=tk.NORMAL)
        scores_text.insert('1.0', "Rank  Score    Floor  Rooms  Gold\n")
        scores_text.insert(tk.END, "="*45 + "\n")
        
        for i, score in enumerate(scores[:10], 1):
            line = f"{i:2d}.  {score['score']:6d}   {score['floor']:3d}    {score['rooms']:3d}   {score['gold']:5d}\n"
            scores_text.insert(tk.END, line)
        
        scores_text.config(state=tk.DISABLED)
        
        tk.Button(self.main_frame, text="Back to Menu", command=self.show_main_menu,
                 font=('Arial', 12, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=20, pady=12).pack(pady=20)

if __name__ == "__main__":
    root = tk.Tk()
    app = DiceDungeonExplorer(root)
    root.mainloop()
