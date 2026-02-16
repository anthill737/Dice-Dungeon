"""
Dice Dungeon Classic
A roguelike dice game with multipliers, power-ups, and strategic risk/reward gameplay
"""

import tkinter as tk
from tkinter import messagebox
import random
import json
import os
import sys

class DiceDungeonRPG:
    def __init__(self, root):
        self.root = root
        self.scale_factor = 1.0  # Font scaling factor for display size consistency
        self.root.title("Dice Dungeon Classic")
        self.root.geometry("650x700")  # Increased height for 10-line combat log
        self.root.minsize(650, 700)  # Allow resizing
        self.root.configure(bg='#2c1810')
        
        # High scores file — use APPDATA when running as EXE
        if getattr(sys, 'frozen', False):
            appdata = os.environ.get('APPDATA', os.path.expanduser('~'))
            scores_dir = os.path.join(appdata, 'DiceDungeon')
            os.makedirs(scores_dir, exist_ok=True)
            self.scores_file = os.path.join(scores_dir, 'dice_dungeon_scores.json')
            # Migrate old scores from EXE-adjacent location
            old_scores = os.path.join(os.path.dirname(sys.executable), 'dice_dungeon_scores.json')
            if os.path.isfile(old_scores) and not os.path.exists(self.scores_file):
                try:
                    import shutil
                    shutil.copy2(old_scores, self.scores_file)
                except Exception:
                    pass
        else:
            self.scores_file = os.path.join(os.path.dirname(__file__), 'dice_dungeon_scores.json')
        
        # Player stats
        self.gold = 0
        self.health = 100
        self.max_health = 100
        self.floor = 1
        self.run_score = 0
        self.total_gold_earned = 0  # Track cumulative gold for high scores
        self.game_active = False
        
        # Dice state
        self.num_dice = 3  # Start with 3 dice
        self.max_dice = 8  # Maximum 8 dice
        self.dice_values = []
        self.dice_locked = []
        self.rolls_left = 3
        
        # Power-ups and multipliers
        self.multiplier = 1.0
        self.damage_bonus = 0
        self.heal_bonus = 0
        self.reroll_bonus = 0
        self.crit_chance = 0.1
        
        # Shop items
        self.shop_items = [
            {"name": "Extra Die", "cost": 50, "effect": "dice", 
             "desc": "Add another die to your rolls for bigger combos"},
            {"name": "Damage Boost", "cost": 40, "effect": "damage",
             "desc": "Permanently increase damage by +10"},
            {"name": "Heal Potion", "cost": 30, "effect": "heal",
             "desc": "Instantly restore 40 HP"},
            {"name": "Lucky Charm", "cost": 60, "effect": "crit",
             "desc": "Increase critical hit chance by +10%"},
            {"name": "Reroll Token", "cost": 25, "effect": "reroll",
             "desc": "Gain +1 extra roll each turn"},
            {"name": "Gold Multiplier", "cost": 80, "effect": "multiplier",
             "desc": "Increase all gold earned by +25%"}
        ]
        
        # Enemy
        self.enemy_health = 50
        self.enemy_max_health = 50
        self.enemy_name = "Goblin"
        self.enemy_num_dice = 2  # Enemies start with 2 dice
        self.last_damage_was_crit = False
        
        # Flavor text for enemies
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
            "You strike with precision!",
            "Your dice guide your blade!",
            "A devastating combo!",
            "You channel the power of fate!",
            "Your attack connects!",
            "A well-placed strike!",
            "The dice gods smile upon you!",
            "You unleash your fury!",
            "A tactical masterpiece!",
            "Your weapon finds its mark!",
            "Lightning-fast reflexes!",
            "You dance between danger!",
            "A calculated assault!",
            "Your training pays off!",
            "Raw power unleashed!"
        ]
        
        self.player_crits = [
            "*** CRITICAL HIT! *** A perfect strike!",
            "*** CRITICAL! *** You found a weak spot!",
            "*** MASSIVE HIT! *** The dice align perfectly!",
            "*** CRITICAL STRIKE! *** Devastating!",
            "*** PERFECT! *** Maximum damage!",
            "*** BRUTAL! *** A legendary blow!",
            "*** INCREDIBLE! *** The stars align!",
            "*** FLAWLESS! *** Unstoppable force!",
            "*** OBLITERATED! *** Pure destruction!",
            "*** ANNIHILATION! *** Nothing can stop you!"
        ]
        
        self.main_frame = None
        self.game_frame = None
        self.dialog_frame = None  # For in-window dialogs
        
        self.show_main_menu()
    
    def scale_font(self, base_size):
        """Scale font size for display size consistency"""
        return max(8, int(base_size * self.scale_factor * 1.15))
    
    def show_main_menu(self):
        # Clear any existing frames
        for widget in self.root.winfo_children():
            widget.destroy()
        
        self.main_frame = tk.Frame(self.root, bg='#2c1810')
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Logo
        try:
            logo_path = os.path.join(os.path.dirname(__file__), "assets", "DD Logo.png")
            if os.path.exists(logo_path):
                # Load and resize logo
                from PIL import Image, ImageTk
                img = Image.open(logo_path)
                img = img.resize((150, 150), Image.LANCZOS)
                self.logo_image = ImageTk.PhotoImage(img)
                
                logo_label = tk.Label(self.main_frame, image=self.logo_image, bg='#2c1810')
                logo_label.pack(pady=(20, 10))
            else:
                # Fallback to text title if no logo
                tk.Label(self.main_frame, text="DICE DUNGEON CLASSIC", 
                        font=('Arial', self.scale_font(32), 'bold'), bg='#2c1810', fg='#ffd700',
                        pady=30).pack()
        except Exception as e:
            # Fallback to text title if PIL not available
            tk.Label(self.main_frame, text="DICE DUNGEON CLASSIC", 
                    font=('Arial', self.scale_font(32), 'bold'), bg='#2c1810', fg='#ffd700',
                    pady=30).pack()
        
        # Title
        tk.Label(self.main_frame, text="DICE DUNGEON CLASSIC", 
                font=('Arial', self.scale_font(26), 'bold'), bg='#2c1810', fg='#ffd700',
                pady=10).pack()
        
        # Subtitle
        tk.Label(self.main_frame, text="Roll, Fight, Survive", 
                font=('Arial', self.scale_font(16)), bg='#2c1810', fg='#ffffff',
                pady=10).pack()
        
        # Buttons
        button_frame = tk.Frame(self.main_frame, bg='#2c1810', pady=30)
        button_frame.pack()
        
        tk.Button(button_frame, text="START NEW RUN", 
                 command=self.start_game_from_menu,
                 font=('Arial', self.scale_font(12), 'bold'), bg='#4ecdc4', fg='#000000',
                 padx=20, pady=10, width=20).pack(pady=5)
        
        tk.Button(button_frame, text="HIGH SCORES", 
                 command=self.show_high_scores,
                 font=('Arial', self.scale_font(12), 'bold'), bg='#ffd700', fg='#000000',
                 padx=20, pady=10, width=20).pack(pady=5)
        
        tk.Button(button_frame, text="RETURN TO LAUNCHER", 
                 command=self.return_to_launcher_from_menu,
                 font=('Arial', self.scale_font(12), 'bold'), bg='#ff9f43', fg='#000000',
                 padx=20, pady=10, width=20).pack(pady=5)
        
        tk.Button(button_frame, text="QUIT", 
                 command=self.root.quit,
                 font=('Arial', self.scale_font(12), 'bold'), bg='#e94560', fg='#ffffff',
                 padx=20, pady=10, width=20).pack(pady=5)
        
        # Instructions
        instructions = """
        HOW TO PLAY:
        - Roll dice and lock the ones you want to keep
        - Build combinations: Pairs, Triples, Straights, etc.
        - Attack enemies with your dice combos
        - Earn gold and buy powerful upgrades
        - Survive as many floors as possible!
        """
        
        tk.Label(self.main_frame, text=instructions, 
                font=('Arial', self.scale_font(11)), bg='#2c1810', fg='#95e1d3',
                justify=tk.LEFT, pady=20).pack()
    
    def show_high_scores(self):
        scores = self.load_high_scores()
        
        # Create high scores window
        hs_window = tk.Toplevel(self.root)
        hs_window.title("HIGH SCORES")
        hs_window.geometry("600x500")
        hs_window.configure(bg='#2c1810')
        
        tk.Label(hs_window, text="*** HIGH SCORES ***", 
                font=('Arial', self.scale_font(22), 'bold'), bg='#2c1810', fg='#ffd700',
                pady=20).pack()
        
        if scores:
            # Header
            header_frame = tk.Frame(hs_window, bg='#3d2415')
            header_frame.pack(fill=tk.X, padx=20, pady=10)
            
            tk.Label(header_frame, text="RANK", font=('Arial', self.scale_font(11), 'bold'),
                    bg='#3d2415', fg='#ffffff', width=8).pack(side=tk.LEFT)
            tk.Label(header_frame, text="SCORE", font=('Arial', self.scale_font(11), 'bold'),
                    bg='#3d2415', fg='#ffffff', width=12).pack(side=tk.LEFT)
            tk.Label(header_frame, text="FLOOR", font=('Arial', self.scale_font(11), 'bold'),
                    bg='#3d2415', fg='#ffffff', width=10).pack(side=tk.LEFT)
            tk.Label(header_frame, text="GOLD", font=('Arial', self.scale_font(11), 'bold'),
                    bg='#3d2415', fg='#ffffff', width=12).pack(side=tk.LEFT)
            
            # Scores
            for i, score in enumerate(scores[:10], 1):
                score_frame = tk.Frame(hs_window, bg='#4a2c1a' if i % 2 == 0 else '#3d2415')
                score_frame.pack(fill=tk.X, padx=20, pady=2)
                
                rank_color = '#ffd700' if i == 1 else '#c0c0c0' if i == 2 else '#cd7f32' if i == 3 else '#ffffff'
                
                tk.Label(score_frame, text=f"#{i}", font=('Arial', self.scale_font(11), 'bold'),
                        bg=score_frame['bg'], fg=rank_color, width=8).pack(side=tk.LEFT)
                tk.Label(score_frame, text=str(score['score']), font=('Arial', self.scale_font(11)),
                        bg=score_frame['bg'], fg='#ffffff', width=12).pack(side=tk.LEFT)
                tk.Label(score_frame, text=f"Floor {score['floor']}", font=('Arial', self.scale_font(11)),
                        bg=score_frame['bg'], fg='#ffffff', width=10).pack(side=tk.LEFT)
                tk.Label(score_frame, text=str(score['gold']), font=('Arial', self.scale_font(11)),
                        bg=score_frame['bg'], fg='#ffffff', width=12).pack(side=tk.LEFT)
        else:
            tk.Label(hs_window, text="No high scores yet!\n\nPlay a game to set a record.", 
                    font=('Arial', self.scale_font(14)), bg='#2c1810', fg='#ffffff',
                    pady=50).pack()
        
        tk.Button(hs_window, text="CLOSE", command=hs_window.destroy,
                 font=('Arial', self.scale_font(12), 'bold'), bg='#e94560', fg='#ffffff',
                 padx=30, pady=10).pack(pady=30)
    
    def load_high_scores(self):
        if os.path.exists(self.scores_file):
            try:
                with open(self.scores_file, 'r') as f:
                    return json.load(f)
            except:
                return []
        return []
    
    def save_high_score(self):
        scores = self.load_high_scores()
        scores.append({
            'score': self.run_score,
            'floor': self.floor,
            'gold': self.total_gold_earned  # Use cumulative gold earned
        })
        # Sort by score descending
        scores.sort(key=lambda x: x['score'], reverse=True)
        # Keep top 10
        scores = scores[:10]
        
        with open(self.scores_file, 'w') as f:
            json.dump(scores, f, indent=2)
    
    def start_game_from_menu(self):
        self.main_frame.destroy()
        self.setup_ui()
        self.game_active = True
        self.start_new_floor()
        
    def setup_ui(self):
        # Create game frame directly without canvas/scrollbar
        self.game_frame = tk.Frame(self.root, bg='#2c1810')
        self.game_frame.pack(fill="both", expand=True)
        
        # Now build the UI in game_frame
        self._build_game_ui()
    
    def _on_mousewheel(self, event):
        # Disabled - no scrollbar anymore
        pass
    
    def show_dialog(self, content_builder, width=400, height=300):
        """Show a modal dialog inside the main window"""
        # Destroy any existing dialog
        if self.dialog_frame and self.dialog_frame.winfo_exists():
            self.dialog_frame.destroy()
        
        # Create overlay
        self.dialog_frame = tk.Frame(self.root, bg='#000000')
        self.dialog_frame.place(relx=0, rely=0, relwidth=1, relheight=1)
        
        # Semi-transparent overlay effect (by using a dark frame)
        overlay = tk.Frame(self.dialog_frame, bg='#000000')
        overlay.place(relx=0, rely=0, relwidth=1, relheight=1)
        
        # Dialog content - use relative sizing to adapt to window size
        max_width = min(width, self.root.winfo_width() - 40)
        max_height = min(height, self.root.winfo_height() - 40)
        
        dialog_content = tk.Frame(self.dialog_frame, bg='#2c1810', relief=tk.RAISED, borderwidth=3)
        dialog_content.place(relx=0.5, rely=0.5, anchor='center', width=max_width, height=max_height)
        
        # Bind to window resize to keep dialog centered and sized properly
        def on_resize(event):
            if self.dialog_frame and self.dialog_frame.winfo_exists():
                new_width = min(width, self.root.winfo_width() - 40)
                new_height = min(height, self.root.winfo_height() - 40)
                dialog_content.place_configure(width=new_width, height=new_height)
        
        self.root.bind('<Configure>', on_resize)
        
        # Call the content builder function to populate the dialog
        content_builder(dialog_content)
        
        return dialog_content
    
    def close_dialog(self):
        """Close the current dialog"""
        if self.dialog_frame and self.dialog_frame.winfo_exists():
            self.dialog_frame.destroy()
            self.dialog_frame = None
        # Unbind resize event
        self.root.unbind('<Configure>')
    
    def close_shop_and_continue(self):
        """Close the shop and proceed to next floor if opened from floor complete"""
        self.close_dialog()
        # If shop was opened from floor complete, automatically start next floor
        if hasattr(self, 'shop_from_floor_complete') and self.shop_from_floor_complete:
            self.shop_from_floor_complete = False  # Reset flag
            self.floor_up()
    
    def show_hamburger_menu(self):
        """Show in-window menu with game options"""
        def build_menu(dialog):
            tk.Label(dialog, text="MENU", font=('Arial', self.scale_font(16), 'bold'),
                    bg='#2c1810', fg='#ffd700', pady=15).pack()
            
            btn_frame = tk.Frame(dialog, bg='#2c1810')
            btn_frame.pack(expand=True)
            
            tk.Button(btn_frame, text="View High Scores", 
                     command=lambda: (self.close_dialog(), self.show_high_scores()),
                     font=('Arial', self.scale_font(11), 'bold'), bg='#ffd700', fg='#000000',
                     width=20, pady=10).pack(pady=8)
            
            tk.Button(btn_frame, text="Return to Main Menu", 
                     command=lambda: (self.close_dialog(), self.return_to_menu()),
                     font=('Arial', self.scale_font(11), 'bold'), bg='#ff6b6b', fg='#ffffff',
                     width=20, pady=10).pack(pady=8)
            
            tk.Button(btn_frame, text="Return to Launcher", 
                     command=lambda: (self.close_dialog(), self.return_to_launcher()),
                     font=('Arial', self.scale_font(11), 'bold'), bg='#ff9f43', fg='#000000',
                     width=20, pady=10).pack(pady=8)
            
            tk.Button(btn_frame, text="Resume Game", 
                     command=self.close_dialog,
                     font=('Arial', self.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                     width=20, pady=10).pack(pady=8)
        
        self.show_dialog(build_menu, width=350, height=340)
    
    def show_help(self):
        """Show game rules and combo explanations"""
        def build_help(dialog):
            # Title
            tk.Label(dialog, text="HOW TO PLAY", font=('Arial', self.scale_font(14), 'bold'),
                    bg='#2c1810', fg='#ffd700', pady=8).pack()
            
            # Container for scrollable content - limit its height
            content_container = tk.Frame(dialog, bg='#2c1810')
            content_container.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
            
            # Scrollable help text with fixed max height
            canvas = tk.Canvas(content_container, bg='#2c1810', highlightthickness=0, height=350)
            scrollbar = tk.Scrollbar(content_container, orient="vertical", command=canvas.yview)
            help_frame = tk.Frame(canvas, bg='#2c1810')
            
            help_frame.bind(
                "<Configure>",
                lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
            )
            
            canvas.create_window((0, 0), window=help_frame, anchor="nw")
            canvas.configure(yscrollcommand=scrollbar.set)
            
            help_text = """
DICE COMBOS & BONUSES:

Base Damage: Sum of all dice

PAIRS (2 matching):
  Example: 5-5 = +10 bonus
  Formula: Value × 2

TRIPLES (3 matching):
  Example: 4-4-4 = +20 bonus
  Formula: Value × 5

QUADS (4 matching):
  Example: 6-6-6-6 = +60 bonus
  Formula: Value × 10

FIVE OF A KIND:
  Example: 3-3-3-3-3 = +60 bonus
  Formula: Value × 20

FLUSH (5+ dice all same):
  Example: 4-4-4-4-4 = +60 bonus
  Formula: Value × 15
  Requires at least 5 dice!

FULL HOUSE (3 + 2):
  Example: 5-5-5-2-2 = +50 bonus
  A powerful combo!

STRAIGHTS:
  Full (5): 1-2-3-4-5 or 2-3-4-5-6
    Bonus: +40
  Small (4): Any 4 consecutive
    Example: 2-3-4-5 = +25 bonus
  Mini (3): Any 3 consecutive
    Example: 3-4-5 = +15 bonus

GAMEPLAY:
• Start with 3 dice (max 8)
• 3 rolls per turn
• Lock dice you want to keep
• Build the best combo
• Attack when ready!
• Enemies also roll dice!

POWER-UPS:
• Damage Boost: +10 damage
• Crit Chance: Double damage (2x)
• Extra Dice: More combo potential
• Gold Multiplier: More shopping power
            """
            
            tk.Label(help_frame, text=help_text, font=('Consolas', 9),
                    bg='#2c1810', fg='#ffffff', justify=tk.LEFT,
                    padx=10, pady=5).pack()
            
            canvas.pack(side="left", fill="both", expand=True)
            scrollbar.pack(side="right", fill="y")
            
            # Button container - always visible at bottom
            btn_container = tk.Frame(dialog, bg='#2c1810')
            btn_container.pack(pady=8, fill=tk.X, side=tk.BOTTOM)
            
            tk.Button(btn_container, text="Got It!", command=self.close_dialog,
                     font=('Arial', self.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                     width=15, pady=8).pack()
        
        self.show_dialog(build_help, width=450, height=500)
    
    def _build_game_ui(self):
        # Header
        header = tk.Frame(self.game_frame, bg='#4a2c1a', pady=5)
        header.pack(fill=tk.X, padx=5, pady=3)
        
        # Right side buttons frame
        right_buttons = tk.Frame(header, bg='#4a2c1a')
        right_buttons.pack(side=tk.RIGHT)
        
        # Help button
        help_btn = tk.Button(right_buttons, text="?", font=('Arial', self.scale_font(14), 'bold'),
                            bg='#4a2c1a', fg='#4ecdc4', relief=tk.FLAT,
                            padx=5, pady=0, command=self.show_help)
        help_btn.pack(side=tk.LEFT, padx=2)
        
        # Hamburger menu button
        menu_btn = tk.Button(right_buttons, text="☰", font=('Arial', self.scale_font(16), 'bold'),
                            bg='#4a2c1a', fg='#ffd700', relief=tk.FLAT,
                            padx=5, pady=0, command=self.show_hamburger_menu)
        menu_btn.pack(side=tk.LEFT, padx=2)
        
        title = tk.Label(header, text="DICE DUNGEON CLASSIC", 
                        font=('Arial', self.scale_font(14), 'bold'), bg='#4a2c1a', fg='#ffd700')
        title.pack()
        
        # Stats frame - more compact
        stats_frame = tk.Frame(self.game_frame, bg='#3d2415', pady=5)
        stats_frame.pack(fill=tk.X, padx=5, pady=3)
        
        # Player stats
        player_frame = tk.Frame(stats_frame, bg='#3d2415')
        player_frame.pack(side=tk.LEFT, padx=10)
        
        tk.Label(player_frame, text="PLAYER", font=('Arial', self.scale_font(9), 'bold'), 
                bg='#3d2415', fg='#4ecdc4').pack()
        
        self.health_label = tk.Label(player_frame, text="HP: 100/100", 
                                     font=('Arial', self.scale_font(9)), bg='#3d2415', fg='#ff6b6b')
        self.health_label.pack()
        
        self.gold_label = tk.Label(player_frame, text="Gold: 0", 
                                   font=('Arial', self.scale_font(9)), bg='#3d2415', fg='#ffd700')
        self.gold_label.pack()
        
        # Floor info
        center_frame = tk.Frame(stats_frame, bg='#3d2415')
        center_frame.pack(side=tk.LEFT, padx=10)
        
        self.floor_label = tk.Label(center_frame, text="FLOOR 1", 
                                    font=('Arial', self.scale_font(12), 'bold'), bg='#3d2415', fg='#ffe66d')
        self.floor_label.pack()
        
        self.score_label = tk.Label(center_frame, text="Score: 0", 
                                    font=('Arial', self.scale_font(9)), bg='#3d2415', fg='#95e1d3')
        self.score_label.pack()
        
        # Enemy stats
        enemy_frame = tk.Frame(stats_frame, bg='#3d2415')
        enemy_frame.pack(side=tk.LEFT, padx=10)
        
        self.enemy_name_label = tk.Label(enemy_frame, text="GOBLIN", 
                                         font=('Arial', self.scale_font(12), 'bold'), bg='#3d2415', fg='#e94560')
        self.enemy_name_label.pack()
        
        self.enemy_health_label = tk.Label(enemy_frame, text="HP: 50/50", 
                                           font=('Arial', self.scale_font(11)), bg='#3d2415', fg='#ff8787')
        self.enemy_health_label.pack()
        
        # Power-ups display
        powers_frame = tk.Frame(self.game_frame, bg='#3d2415', pady=5)
        powers_frame.pack(fill=tk.X, padx=10)
        
        self.powers_label = tk.Label(powers_frame, text="", 
                                     font=('Arial', self.scale_font(9)), bg='#3d2415', fg='#b8e6d5')
        self.powers_label.pack()
        
        # Dice area
        dice_frame = tk.Frame(self.game_frame, bg='#2c1810', pady=20)
        dice_frame.pack()
        
        tk.Label(dice_frame, text="YOUR DICE", font=('Arial', self.scale_font(14), 'bold'), 
                bg='#2c1810', fg='#ffffff').pack()
        
        self.dice_buttons_frame = tk.Frame(dice_frame, bg='#2c1810')
        self.dice_buttons_frame.pack(pady=10)
        
        self.dice_buttons = []
        
        # Rolls left
        self.rolls_label = tk.Label(dice_frame, text="Rolls Left: 3", 
                                    font=('Arial', self.scale_font(12), 'bold'), bg='#2c1810', fg='#ffe66d')
        self.rolls_label.pack(pady=5)
        
        # Action buttons
        action_frame = tk.Frame(self.game_frame, bg='#2c1810', pady=10)
        action_frame.pack()
        
        self.roll_btn = tk.Button(action_frame, text="ROLL DICE", 
                                  command=self.roll_dice,
                                  font=('Arial', self.scale_font(14), 'bold'), bg='#4ecdc4', fg='#000000',
                                  padx=30, pady=15, width=12)
        self.roll_btn.pack(side=tk.LEFT, padx=5)
        
        self.attack_btn = tk.Button(action_frame, text="ATTACK!", 
                                    command=self.attack_enemy,
                                    font=('Arial', self.scale_font(14), 'bold'), bg='#e94560', fg='#ffffff',
                                    padx=30, pady=15, width=12)
        self.attack_btn.pack(side=tk.LEFT, padx=5)
        
        # Info panel
        info_frame = tk.Frame(self.game_frame, bg='#3d2415', pady=10)
        info_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        tk.Label(info_frame, text="COMBAT LOG", font=('Arial', self.scale_font(11), 'bold'), 
                bg='#3d2415', fg='#ffd700').pack()
        
        self.log_text = tk.Text(info_frame, height=10, width=80, 
                               font=('Consolas', 9), bg='#1a1a1a', fg='#00ff00',
                               state=tk.DISABLED, wrap=tk.WORD)
        self.log_text.pack(pady=5)
        
        # Configure color tags for combat log
        self.log_text.tag_config('enemy', foreground='#ff4444')
        self.log_text.tag_config('player', foreground='#00ff00')
        self.log_text.tag_config('system', foreground='#ffd700')
        self.log_text.tag_config('crit', foreground='#ff00ff', font=('Consolas', 9, 'bold'))
    
    def create_dice_buttons(self):
        # Clear existing
        for widget in self.dice_buttons_frame.winfo_children():
            widget.destroy()
        
        self.dice_buttons = []
        
        for i in range(self.num_dice):
            frame = tk.Frame(self.dice_buttons_frame, bg='#2c1810')
            frame.pack(side=tk.LEFT, padx=5)
            
            value = self.dice_values[i] if i < len(self.dice_values) else 0
            locked = self.dice_locked[i] if i < len(self.dice_locked) else False
            
            die_btn = tk.Button(frame, text=str(value) if value > 0 else "?",
                               font=('Arial', self.scale_font(24), 'bold'),
                               width=3, height=1,
                               bg='#ffd700' if locked else '#ffffff',
                               fg='#000000',
                               command=lambda idx=i: self.toggle_lock(idx))
            die_btn.pack()
            
            lock_label = tk.Label(frame, text="LOCKED" if locked else "Click to Lock",
                                 font=('Arial', self.scale_font(8)), bg='#2c1810', 
                                 fg='#ffd700' if locked else '#888888')
            lock_label.pack()
            
            self.dice_buttons.append((die_btn, lock_label))
    
    def toggle_lock(self, idx):
        if idx < len(self.dice_locked) and len(self.dice_values) > idx and self.dice_values[idx] > 0:
            self.dice_locked[idx] = not self.dice_locked[idx]
            die_btn, lock_label = self.dice_buttons[idx]
            
            if self.dice_locked[idx]:
                die_btn.config(bg='#ffd700')
                lock_label.config(text="LOCKED", fg='#ffd700')
            else:
                die_btn.config(bg='#ffffff')
                lock_label.config(text="Click to Lock", fg='#888888')
    
    def roll_dice(self):
        if self.rolls_left <= 0:
            self.log("No rolls left! Attack or Rest.", 'system')
            return
        
        # Roll unlocked dice
        for i in range(self.num_dice):
            if not self.dice_locked[i]:
                self.dice_values[i] = random.randint(1, 6)
        
        self.rolls_left -= 1
        
        # Update display
        for i in range(self.num_dice):
            if i < len(self.dice_buttons):
                die_btn, _ = self.dice_buttons[i]
                die_btn.config(text=str(self.dice_values[i]))
        
        self.rolls_label.config(text=f"Rolls Left: {self.rolls_left}")
        
        # Calculate potential damage and show combos
        damage = self.calculate_damage()
        combo_info = self.get_combo_description()
        
        self.log(f"Rolled! Dice: {self.dice_values}", 'player')
        if combo_info:
            self.log(f"Combo: {combo_info}", 'system')
        self.log(f"Potential Damage: {damage}", 'player')
        
        if self.rolls_left == 0:
            self.roll_btn.config(state=tk.DISABLED)
    
    def get_combo_description(self):
        """Get a description of what combos are in the current dice"""
        if not self.dice_values:
            return ""
        
        from collections import Counter
        counts = Counter(self.dice_values)
        combos = []
        
        # Check for full house (3 of one, 2 of another)
        sorted_counts = sorted(counts.values(), reverse=True)
        if len(sorted_counts) >= 2 and sorted_counts[0] == 3 and sorted_counts[1] == 2:
            combos.append(f"FULL HOUSE! (+50 MEGA bonus!)")
        
        # Check for sets
        for value, count in counts.items():
            if count == 2:
                combos.append(f"PAIR of {value}s (+{value*2} bonus)")
            elif count == 3:
                combos.append(f"TRIPLE {value}s (+{value*5} bonus!)")
            elif count == 4:
                combos.append(f"QUAD {value}s (+{value*10} HUGE bonus!)")
            elif count >= 5:
                # Check if ALL dice are the same AND at least 5 dice (flush)
                if count == len(self.dice_values) and count >= 5:
                    combos.append(f"FLUSH! All {value}s! (+{value*15} ULTIMATE bonus!!!)")
                else:
                    combos.append(f"FIVE {value}s (+{value*20} MASSIVE bonus!!!)")
        
        # Check for straights
        sorted_dice = sorted(set(self.dice_values))
        
        # Full straights (5 consecutive)
        if sorted_dice == [1,2,3,4,5]:
            combos.append("FULL STRAIGHT 1-5 (+40 bonus!)")
        elif sorted_dice == [2,3,4,5,6]:
            combos.append("FULL STRAIGHT 2-6 (+40 bonus!)")
        # Small straights (4 consecutive)
        elif [1,2,3,4] in [sorted_dice[i:i+4] for i in range(len(sorted_dice)-3)] or \
             [2,3,4,5] in [sorted_dice[i:i+4] for i in range(len(sorted_dice)-3)] or \
             [3,4,5,6] in [sorted_dice[i:i+4] for i in range(len(sorted_dice)-3)]:
            combos.append("SMALL STRAIGHT (4) (+25 bonus)")
        # Mini straights (3 consecutive)
        elif any([sorted_dice[i:i+3] == [j, j+1, j+2] for i in range(len(sorted_dice)-2) for j in range(1,5)]):
            combos.append("MINI STRAIGHT (3) (+15 bonus)")
        
        if combos:
            return " | ".join(combos)
        else:
            return "No combos (base damage only)"
    
    def calculate_damage(self):
        if not self.dice_values:
            return 0
        
        # Reset crit flag
        self.last_damage_was_crit = False
        
        # Base damage: sum of dice
        base = sum(self.dice_values)
        
        # Bonus for sets (matching numbers)
        from collections import Counter
        counts = Counter(self.dice_values)
        set_bonus = 0
        
        # Track what bonuses we're applying for debug
        bonus_details = []
        
        # Check for full house FIRST (3 of one, 2 of another)
        sorted_counts = sorted(counts.values(), reverse=True)
        has_full_house = len(sorted_counts) >= 2 and sorted_counts[0] == 3 and sorted_counts[1] == 2
        if has_full_house:
            set_bonus += 50
            bonus_details.append("FULL HOUSE: +50")
        
        # Check for flush (all dice the same value AND at least 5 dice)
        has_flush = False
        for value, count in counts.items():
            if count == len(self.dice_values) and count >= 5:
                bonus_amt = value * 15
                set_bonus += bonus_amt
                bonus_details.append(f"FLUSH (all {value}s): +{bonus_amt}")
                has_flush = True
                break
        
        # Regular sets (only if not flush, to avoid double counting)
        if not has_flush:
            for value, count in counts.items():
                if count == 2:
                    bonus_amt = value * 2
                    set_bonus += bonus_amt
                    bonus_details.append(f"Pair of {value}s: +{bonus_amt}")
                elif count == 3:
                    bonus_amt = value * 5
                    set_bonus += bonus_amt
                    bonus_details.append(f"Triple {value}s: +{bonus_amt}")
                elif count == 4:
                    bonus_amt = value * 10
                    set_bonus += bonus_amt
                    bonus_details.append(f"Quad {value}s: +{bonus_amt}")
                elif count >= 5:
                    bonus_amt = value * 20
                    set_bonus += bonus_amt
                    bonus_details.append(f"Five {value}s: +{bonus_amt}")
        
        # Check for straights
        sorted_dice = sorted(set(self.dice_values))
        
        # Full straights (5 consecutive)
        if sorted_dice == [1,2,3,4,5] or sorted_dice == [2,3,4,5,6]:
            set_bonus += 40
            bonus_details.append("Full Straight: +40")
        # Small straights (4 consecutive)
        elif [1,2,3,4] in [sorted_dice[i:i+4] for i in range(len(sorted_dice)-3)] or \
             [2,3,4,5] in [sorted_dice[i:i+4] for i in range(len(sorted_dice)-3)] or \
             [3,4,5,6] in [sorted_dice[i:i+4] for i in range(len(sorted_dice)-3)]:
            set_bonus += 25
            bonus_details.append("Small Straight (4): +25")
        # Mini straights (3 consecutive)
        elif any([sorted_dice[i:i+3] == [j, j+1, j+2] for i in range(len(sorted_dice)-2) for j in range(1,5)]):
            set_bonus += 15
            bonus_details.append("Mini Straight (3): +15")
        
        # Apply bonuses
        total = base + set_bonus + self.damage_bonus
        
        # Check for crit BEFORE logging
        if random.random() < self.crit_chance:
            total = int(total * 2)
            self.last_damage_was_crit = True
        
        # Apply multiplier
        final_damage = int(total * self.multiplier)
        
        # Log the calculation breakdown
        if bonus_details:
            breakdown = f"  Base: {base} | {' | '.join(bonus_details)}"
            if self.damage_bonus > 0:
                breakdown += f" | Bonus Items: +{self.damage_bonus}"
            breakdown += f" = {total}"
            if self.last_damage_was_crit:
                breakdown += " *** CRITICAL HIT! (2x damage) ***"
            if self.multiplier > 1.0:
                breakdown += f" × {self.multiplier:.2f} multiplier = {final_damage}"
            self.log(breakdown, 'crit' if self.last_damage_was_crit else 'system')
        elif self.damage_bonus > 0:
            breakdown = f"  Base: {base} | Bonus Items: +{self.damage_bonus} = {total}"
            if self.last_damage_was_crit:
                breakdown += " *** CRITICAL HIT! (2x damage) ***"
            self.log(breakdown, 'crit' if self.last_damage_was_crit else 'system')
        
        return final_damage
    
    def attack_enemy(self):
        damage = self.calculate_damage()
        self.enemy_health -= damage
        
        # Player attack flavor text
        if self.last_damage_was_crit:
            self.log(random.choice(self.player_crits), 'crit')
        else:
            self.log(random.choice(self.player_attacks), 'player')
        
        self.log(f"You deal {damage} damage!", 'player')
        
        # Enemy reaction based on damage
        if damage > 30:
            # High damage - enemy is hurt
            enemy_reaction = self.enemy_hurt.get(self.enemy_name, ["*groans*"])
            self.log(f"{self.enemy_name}: '{random.choice(enemy_reaction)}'", 'enemy')
        elif damage > 0:
            # Low damage - enemy taunts
            enemy_taunt = self.enemy_taunts.get(self.enemy_name, ["You'll have to do better!"])
            self.log(f"{self.enemy_name}: '{random.choice(enemy_taunt)}'", 'enemy')
        
        if self.enemy_health <= 0:
            # Enemy death message
            death_msg = self.enemy_death.get(self.enemy_name, ["*dies*"])
            self.log(f"{self.enemy_name}: '{random.choice(death_msg)}'", 'enemy')
            self.defeat_enemy()
        else:
            # Enemy counterattack - roll dice!
            enemy_dice = [random.randint(1, 6) for _ in range(self.enemy_num_dice)]
            enemy_base = sum(enemy_dice)
            enemy_floor_bonus = self.floor  # Small bonus per floor
            enemy_damage = enemy_base + enemy_floor_bonus
            
            # Enemy attack flavor text with dice
            attack_phrases = [
                f"{self.enemy_name} rolls {enemy_dice} and retaliates!",
                f"{self.enemy_name} strikes back with {enemy_dice}!",
                f"{self.enemy_name} counterattacks! Rolled {enemy_dice}",
                f"{self.enemy_name} lashes out! Dice: {enemy_dice}"
            ]
            self.log(random.choice(attack_phrases), 'enemy')
            
            # Show enemy damage breakdown
            self.log(f"  Enemy: Base {enemy_base} + Floor Bonus {enemy_floor_bonus} = {enemy_damage}", 'enemy')
            
            self.health -= enemy_damage
            self.log(f"{self.enemy_name} deals {enemy_damage} damage!", 'enemy')
            
            if self.health <= 0:
                self.game_over()
            else:
                # Reset for next turn
                self.reset_turn()
        
        self.update_display()
    
    def defeat_enemy(self):
        gold_earned = random.randint(10, 30) + (self.floor * 5)
        gold_with_multiplier = int(gold_earned * self.multiplier)
        
        self.gold += gold_with_multiplier
        self.total_gold_earned += gold_with_multiplier  # Track cumulative
        self.run_score += 100 + (self.floor * 50)
        
        self.log(f"*** ENEMY DEFEATED! ***", 'system')
        self.log(f"Earned {gold_with_multiplier} gold!", 'system')
        
        self.update_display()
        
        # Show floor complete options
        self.show_floor_complete_menu(gold_earned)
    
    def show_floor_complete_menu(self, gold_earned):
        """Show floor complete options in an in-window dialog"""
        def build_menu(dialog):
            tk.Label(dialog, text=f"*** FLOOR {self.floor} COMPLETE! ***", 
                    font=('Arial', self.scale_font(14), 'bold'), bg='#2c1810', fg='#ffd700',
                    pady=10).pack()
            
            # Stats
            stats_frame = tk.Frame(dialog, bg='#3d2415', pady=8)
            stats_frame.pack(fill=tk.X, padx=20, pady=8)
            
            tk.Label(stats_frame, text=f"Gold Earned: {int(gold_earned * self.multiplier)}", 
                    font=('Arial', self.scale_font(10)), bg='#3d2415', fg='#ffffff').pack()
            tk.Label(stats_frame, text=f"Total Gold: {self.gold}", 
                    font=('Arial', self.scale_font(10)), bg='#3d2415', fg='#ffd700').pack()
            tk.Label(stats_frame, text=f"Run Score: {self.run_score}", 
                    font=('Arial', self.scale_font(10)), bg='#3d2415', fg='#4ecdc4').pack()
            tk.Label(stats_frame, text=f"Your HP: {self.health}/{self.max_health}", 
                    font=('Arial', self.scale_font(10)), bg='#3d2415', fg='#ff6b6b').pack()
            
            tk.Label(dialog, text="Choose your next action:", 
                    font=('Arial', self.scale_font(10)), bg='#2c1810', fg='#ffffff',
                    pady=8).pack()
            
            # Options
            btn_frame = tk.Frame(dialog, bg='#2c1810')
            btn_frame.pack(pady=8)
            
            tk.Button(btn_frame, text="SHOP", 
                     command=lambda: (self.close_dialog(), self.open_shop_dialog(from_floor_complete=True)),
                     font=('Arial', self.scale_font(10), 'bold'), bg='#ffd700', fg='#000000',
                     width=12, pady=8).pack(side=tk.LEFT, padx=5)
            
            tk.Button(btn_frame, text="REST (+30 HP)", 
                     command=lambda: self.rest_and_continue(),
                     font=('Arial', self.scale_font(10), 'bold'), bg='#95e1d3', fg='#000000',
                     width=12, pady=8).pack(side=tk.LEFT, padx=5)
            
            tk.Button(btn_frame, text="NEXT FLOOR", 
                     command=lambda: (self.close_dialog(), self.floor_up()),
                     font=('Arial', self.scale_font(10), 'bold'), bg='#4ecdc4', fg='#000000',
                     width=12, pady=8).pack(side=tk.LEFT, padx=5)
        
        self.show_dialog(build_menu, width=400, height=380)
    
    def rest_and_continue(self):
        """Rest and then proceed to next floor"""
        heal = 30 + self.heal_bonus
        self.health = min(self.health + heal, self.max_health)
        self.log(f"You rest and recover {heal} HP")
        self.update_display()
        self.close_dialog()
        self.floor += 1
        self.start_new_floor()
    
    def show_continue_menu(self):
        menu = tk.Toplevel(self.root)
        menu.title("Ready?")
        menu.geometry("400x300")
        menu.configure(bg='#2c1810')
        menu.grab_set()
        
        # Center the window
        menu.update_idletasks()
        x = (menu.winfo_screenwidth() // 2) - (400 // 2)
        y = (menu.winfo_screenheight() // 2) - (300 // 2)
        menu.geometry(f'400x300+{x}+{y}')
        
        tk.Label(menu, text="What now?", 
                font=('Arial', self.scale_font(16), 'bold'), bg='#2c1810', fg='#ffffff',
                pady=20).pack()
        
        tk.Label(menu, text=f"Your HP: {self.health}/{self.max_health}", 
                font=('Arial', self.scale_font(12)), bg='#2c1810', fg='#ff6b6b',
                pady=5).pack()
        tk.Label(menu, text=f"Your Gold: {self.gold}", 
                font=('Arial', self.scale_font(12)), bg='#2c1810', fg='#ffd700',
                pady=5).pack()
        
        btn_frame = tk.Frame(menu, bg='#2c1810', pady=20)
        btn_frame.pack()
        
        tk.Button(btn_frame, text="SHOP", 
                 command=lambda: (menu.destroy(), self.open_shop_dialog(from_floor_complete=True)),
                 font=('Arial', self.scale_font(11), 'bold'), bg='#ffd700', fg='#000000',
                 padx=15, pady=10, width=12).pack(side=tk.LEFT, padx=5)
        
        tk.Button(btn_frame, text="NEXT FLOOR", 
                 command=lambda: (menu.destroy(), self.floor_up()),
                 font=('Arial', self.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                 padx=15, pady=10, width=12).pack(side=tk.LEFT, padx=5)
    
    def floor_up(self):
        self.floor += 1
        self.start_new_floor()
    
    def start_new_floor(self):
        # Scale enemy
        self.enemy_max_health = 50 + (self.floor * 20)
        self.enemy_health = self.enemy_max_health
        
        enemies = ["Goblin", "Orc", "Troll", "Dragon", "Demon", "Lich", "Hydra"]
        self.enemy_name = enemies[min(self.floor - 1, len(enemies) - 1)]
        
        # Enemy gets more dice as floors progress
        self.enemy_num_dice = min(2 + (self.floor // 3), 6)  # Start at 2, max 6 dice
        
        # Reset dice
        self.dice_values = [0] * self.num_dice
        self.dice_locked = [False] * self.num_dice
        self.rolls_left = 3 + self.reroll_bonus
        
        self.create_dice_buttons()
        self.update_display()
        self.roll_btn.config(state=tk.NORMAL)
        
        self.log(f"=== FLOOR {self.floor}: {self.enemy_name} Appears! ===", 'system')
        self.log(f"{self.enemy_name} wields {self.enemy_num_dice} dice!", 'enemy')
    
    def reset_turn(self):
        # Unlock all dice and roll new ones
        self.dice_locked = [False] * self.num_dice
        self.rolls_left = 3 + self.reroll_bonus
        
        # Roll all dice for new turn
        for i in range(self.num_dice):
            self.dice_values[i] = random.randint(1, 6)
        
        # Update dice display
        for i in range(len(self.dice_buttons)):
            die_btn, lock_label = self.dice_buttons[i]
            die_btn.config(bg='#ffffff', text=str(self.dice_values[i]))
            lock_label.config(text="Click to Lock", fg='#888888')
        
        self.roll_btn.config(state=tk.NORMAL)
        self.rolls_label.config(text=f"Rolls Left: {self.rolls_left}")
    
    def open_shop_dialog(self, from_floor_complete=False):
        """Show shop in a full-screen style dialog like Explorer mode"""
        # Store context for when shop closes
        self.shop_from_floor_complete = from_floor_complete
        
        # Close existing dialog if any
        if self.dialog_frame and self.dialog_frame.winfo_exists():
            self.dialog_frame.destroy()
        
        # Create larger dialog frame
        dialog_width = 550
        dialog_height = 500
        
        self.dialog_frame = tk.Frame(self.game_frame, bg='#2c1810', relief=tk.RIDGE, borderwidth=3)
        self.dialog_frame.place(relx=0.5, rely=0.5, anchor='center', width=dialog_width, height=dialog_height)
        
        # Grab focus and bind ESC to close and continue
        self.dialog_frame.focus_set()
        self.dialog_frame.bind('<Escape>', lambda e: self.close_shop_and_continue() or "break")
        
        # Title
        tk.Label(self.dialog_frame, text="*** SHOP ***", font=('Arial', self.scale_font(16), 'bold'),
                bg='#2c1810', fg='#ffd700', pady=10).pack()
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.dialog_frame, text="✕", font=('Arial', self.scale_font(16), 'bold'),
                            bg='#2c1810', fg='#ff4444',
                            cursor="hand2", padx=5)
        close_btn.place(relx=1.0, rely=0.0, anchor='ne', x=-10, y=5)
        close_btn.bind('<Button-1>', lambda e: self.close_shop_and_continue())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Gold label that we can update
        self.shop_gold_label = tk.Label(self.dialog_frame, text=f"Your Gold: {self.gold}", 
                font=('Arial', self.scale_font(12), 'bold'), bg='#2c1810', fg='#ffd700', pady=5)
        self.shop_gold_label.pack()
        
        # Scrollable items
        canvas = tk.Canvas(self.dialog_frame, bg='#2c1810', highlightthickness=0)
        scrollbar = tk.Scrollbar(self.dialog_frame, orient="vertical", command=canvas.yview, width=10)
        items_frame = tk.Frame(canvas, bg='#2c1810')
        
        items_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        
        canvas.create_window((0, 0), window=items_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Setup mousewheel scrolling (Explorer style)
        def on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        
        def bind_mousewheel_to_tree(widget):
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        
        # Bind to canvas and all children
        canvas.bind("<MouseWheel>", on_mousewheel)
        bind_mousewheel_to_tree(items_frame)
        
        # Create item rows
        for item in self.shop_items:
            frame = tk.Frame(items_frame, bg='#4a2c1a', relief=tk.RIDGE, borderwidth=1)
            frame.pack(fill=tk.X, padx=10, pady=5)
            
            container = tk.Frame(frame, bg='#4a2c1a')
            container.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
            
            # Left side - Item info
            info_frame = tk.Frame(container, bg='#4a2c1a')
            info_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
            
            tk.Label(info_frame, text=item['name'], font=('Arial', self.scale_font(11), 'bold'),
                    bg='#4a2c1a', fg='#ffffff', anchor='w').pack(fill=tk.X, pady=2)
            
            tk.Label(info_frame, text=item['desc'], font=('Arial', self.scale_font(9)),
                    bg='#4a2c1a', fg='#b8e6d5', wraplength=350,
                    justify=tk.LEFT, anchor='w').pack(fill=tk.X, pady=2)
            
            # Right side - Price and buy button
            action_frame = tk.Frame(container, bg='#4a2c1a')
            action_frame.pack(side=tk.RIGHT, padx=5)
            
            tk.Label(action_frame, text=f"{item['cost']}g", font=('Arial', self.scale_font(11), 'bold'),
                    bg='#4a2c1a', fg='#ffd700').pack(pady=3)
            
            # Check if can afford
            can_afford = self.gold >= item['cost']
            btn_state = tk.NORMAL if can_afford else tk.DISABLED
            btn_text = "BUY" if can_afford else "Can't Afford"
            
            # Check if max dice
            if item['effect'] == 'dice' and self.num_dice >= self.max_dice:
                btn_state = tk.DISABLED
                btn_text = "Max Dice"
            
            tk.Button(action_frame, text=btn_text, 
                     command=lambda i=item: self.buy_item_dialog_update(i),
                     font=('Arial', self.scale_font(9), 'bold'), bg='#4ecdc4', fg='#000000',
                     width=10, pady=5, state=btn_state).pack(pady=3)
        
        canvas.pack(side="left", fill="both", expand=True, padx=10, pady=10)
        scrollbar.pack(side="right", fill="y")
        
        # Bottom buttons
        button_frame = tk.Frame(self.dialog_frame, bg='#2c1810')
        button_frame.pack(pady=10)
        
        tk.Button(button_frame, text="Next Floor", command=self.close_shop_and_continue,
                 font=('Arial', self.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                 width=12, pady=8).pack(side=tk.LEFT, padx=5)
    
    def buy_item_dialog_update(self, item):
        """Buy item and update the shop display"""
        # Check if trying to buy dice at max
        if item['effect'] == 'dice' and self.num_dice >= self.max_dice:
            messagebox.showinfo("Max Dice Reached", f"You already have the maximum of {self.max_dice} dice!")
            return
        
        if self.gold >= item['cost']:
            self.gold -= item['cost']
            
            if item['effect'] == 'dice':
                self.num_dice += 1
                self.dice_values.append(0)
                self.dice_locked.append(False)
                self.log(f"Purchased {item['name']}! Now have {self.num_dice} dice.")
            elif item['effect'] == 'damage':
                self.damage_bonus += 10
                self.log(f"Purchased {item['name']}! Damage increased by 10.")
            elif item['effect'] == 'heal':
                healed = min(40, self.max_health - self.health)
                self.health = min(self.health + 40, self.max_health)
                self.log(f"Purchased {item['name']}! Restored {healed} HP.")
            elif item['effect'] == 'crit':
                self.crit_chance += 0.1
                self.log(f"Purchased {item['name']}! Critical hit chance increased by 10%.")
            elif item['effect'] == 'reroll':
                self.reroll_bonus += 1
                self.log(f"Purchased {item['name']}! +1 extra reroll each turn.")
            elif item['effect'] == 'multiplier':
                self.multiplier_bonus += 1
                self.log(f"Purchased {item['name']}! Bonus multiplier increased by 1.")
            
            # Update gold label
            if hasattr(self, 'shop_gold_label') and self.shop_gold_label.winfo_exists():
                self.shop_gold_label.config(text=f"Your Gold: {self.gold}")
            
            # Refresh the shop to update button states
            self.close_dialog()
            self.open_shop_dialog()
        else:
            messagebox.showinfo("Not Enough Gold", f"You need {item['cost']} gold but only have {self.gold}.")
    
    def buy_item_dialog(self, item, gold_label):
        # Check if trying to buy dice at max
        if item['effect'] == 'dice' and self.num_dice >= self.max_dice:
            messagebox.showinfo("Max Dice Reached", f"You already have the maximum of {self.max_dice} dice!")
            return
        
        if self.gold >= item['cost']:
            self.gold -= item['cost']
            
            if item['effect'] == 'dice':
                self.num_dice += 1
                self.dice_values.append(0)
                self.dice_locked.append(False)
            elif item['effect'] == 'damage':
                self.damage_bonus += 10
            elif item['effect'] == 'heal':
                self.health = min(self.health + 40, self.max_health)
            elif item['effect'] == 'crit':
                self.crit_chance += 0.1
            elif item['effect'] == 'reroll':
                self.reroll_bonus += 1
            elif item['effect'] == 'multiplier':
                self.multiplier += 0.25
            
            self.log(f"Purchased: {item['name']}", 'system')
            self.update_display()
            self.create_dice_buttons()
            gold_label.config(text=f"Your Gold: {self.gold}")
        else:
            messagebox.showwarning("Not Enough Gold", "You need more gold!")
    
    def open_shop(self, floor_complete=False):
        shop = tk.Toplevel(self.root)
        shop.title("SHOP")
        shop.geometry("700x650")
        shop.configure(bg='#3d2415')
        if floor_complete:
            shop.grab_set()  # Make modal during floor complete
        
        tk.Label(shop, text="*** SHOP ***", font=('Arial', self.scale_font(18), 'bold'),
                bg='#3d2415', fg='#ffd700').pack(pady=10)
        
        gold_label = tk.Label(shop, text=f"Your Gold: {self.gold}", font=('Arial', self.scale_font(12)),
                             bg='#3d2415', fg='#ffffff')
        gold_label.pack(pady=5)
        
        # Scrollable frame for items
        canvas = tk.Canvas(shop, bg='#3d2415', highlightthickness=0, height=400)
        scrollbar = tk.Scrollbar(shop, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg='#3d2415')
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        for item in self.shop_items:
            frame = tk.Frame(scrollable_frame, bg='#4a2c1a', pady=10, padx=10)
            frame.pack(fill=tk.X, padx=20, pady=5)
            
            # Item name and cost
            top_frame = tk.Frame(frame, bg='#4a2c1a')
            top_frame.pack(fill=tk.X)
            
            tk.Label(top_frame, text=item['name'], font=('Arial', self.scale_font(12), 'bold'),
                    bg='#4a2c1a', fg='#ffffff').pack(side=tk.LEFT, padx=5)
            
            tk.Label(top_frame, text=f"{item['cost']} gold", font=('Arial', self.scale_font(11)),
                    bg='#4a2c1a', fg='#ffd700').pack(side=tk.LEFT, padx=10)
            
            tk.Button(top_frame, text="BUY", command=lambda i=item, gl=gold_label: self.buy_item(i, gl),
                     font=('Arial', self.scale_font(10), 'bold'), bg='#4ecdc4', fg='#000000',
                     padx=15, pady=5).pack(side=tk.RIGHT, padx=5)
            
            # Description
            tk.Label(frame, text=item['desc'], font=('Arial', self.scale_font(9)),
                    bg='#4a2c1a', fg='#b8e6d5', wraplength=550,
                    justify=tk.LEFT).pack(fill=tk.X, padx=5, pady=(5,0))
        
        canvas.pack(side="left", fill="both", expand=True, padx=10)
        scrollbar.pack(side="right", fill="y")
        
        # Close button - more compact
        close_btn = tk.Button(shop, text="Close Shop" if not floor_complete else "Next Floor", 
                             command=lambda: self.close_shop(shop, floor_complete),
                             font=('Arial', self.scale_font(10), 'bold'), bg='#e94560', fg='#ffffff',
                             padx=15, pady=8, width=15)
        close_btn.pack(pady=10)
    
    def close_shop(self, shop_window, floor_complete):
        shop_window.destroy()
        if floor_complete:
            # Instead of another menu, just show a simple dialog
            result = messagebox.askyesno("Ready?", 
                                        f"HP: {self.health}/{self.max_health}\nGold: {self.gold}\n\nProceed to Floor {self.floor + 1}?",
                                        icon='question')
            if result:
                self.floor += 1
                self.start_new_floor()
            else:
                # Give option to rest or continue
                self.show_continue_menu()
    
    def buy_item(self, item, gold_label):
        if self.gold >= item['cost']:
            self.gold -= item['cost']
            
            if item['effect'] == 'dice':
                self.num_dice += 1
                self.dice_values.append(0)
                self.dice_locked.append(False)
            elif item['effect'] == 'damage':
                self.damage_bonus += 10
            elif item['effect'] == 'heal':
                self.health = min(self.health + 40, self.max_health)
            elif item['effect'] == 'crit':
                self.crit_chance += 0.1
            elif item['effect'] == 'reroll':
                self.reroll_bonus += 1
            elif item['effect'] == 'multiplier':
                self.multiplier += 0.25
            
            self.log(f"Purchased: {item['name']}")
            self.update_display()
            self.create_dice_buttons()
            
            # Update shop gold display
            gold_label.config(text=f"Your Gold: {self.gold}")
        else:
            messagebox.showwarning("Not Enough Gold", "You need more gold!")
    
    def update_display(self):
        self.health_label.config(text=f"HP: {self.health}/{self.max_health}")
        self.gold_label.config(text=f"Gold: {self.gold}")
        self.floor_label.config(text=f"FLOOR {self.floor}")
        self.score_label.config(text=f"Score: {self.run_score}")
        
        self.enemy_name_label.config(text=self.enemy_name.upper())
        self.enemy_health_label.config(text=f"HP: {max(0, self.enemy_health)}/{self.enemy_max_health}")
        
        # Power-ups summary
        powers = []
        if self.multiplier > 1:
            powers.append(f"Gold x{self.multiplier:.2f}")
        if self.damage_bonus > 0:
            powers.append(f"+{self.damage_bonus} DMG")
        if self.crit_chance > 0.1:
            powers.append(f"{self.crit_chance*100:.0f}% Crit")
        if self.reroll_bonus > 0:
            powers.append(f"+{self.reroll_bonus} Rolls")
        if self.num_dice > 5:
            powers.append(f"{self.num_dice} Dice")
        
        self.powers_label.config(text=" | ".join(powers) if powers else "No power-ups yet")
    
    def log(self, message, tag='player'):
        """Log a message with optional color tag (player, enemy, system, crit)"""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + "\n", tag)
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
    
    def game_over(self):
        self.game_active = False
        self.save_high_score()
        
        message = f"Game Over!\n\n"
        message += f"Floor Reached: {self.floor}\n"
        message += f"Final Score: {self.run_score}\n"
        message += f"Total Gold Earned: {self.total_gold_earned}\n\n"
        
        # Check if it's a high score
        scores = self.load_high_scores()
        if scores and self.run_score >= scores[0]['score']:
            message += "*** NEW HIGH SCORE! ***\n\n"
        
        message += "Return to main menu?"
        
        if messagebox.askyesno("Defeated!", message):
            self.return_to_menu()
        else:
            self.root.quit()
    
    def return_to_menu(self):
        if self.game_active:
            if not messagebox.askyesno("Quit Run?", "Are you sure you want to quit this run?"):
                return
            self.save_high_score()
        
        # Unbind mousewheel
        try:
            self.main_canvas.unbind_all("<MouseWheel>")
        except:
            pass
        
        for widget in self.root.winfo_children():
            widget.destroy()
        self.show_main_menu()
    
    def return_to_launcher_from_menu(self):
        """Return to launcher from main menu (no confirmation needed)"""
        self.root.destroy()
        
        # Launch the launcher
        import dice_dungeon_launcher
        root = tk.Tk()
        app = dice_dungeon_launcher.GameLauncher(root)
        root.mainloop()
    
    def return_to_launcher(self):
        """Return to game launcher"""
        def confirm_quit():
            if self.game_active:
                self.save_high_score()
            
            # Close this game window
            self.root.destroy()
            
            # Launch the launcher
            import dice_dungeon_launcher
            root = tk.Tk()
            app = dice_dungeon_launcher.GameLauncher(root)
            root.mainloop()
        
        if self.game_active:
            def build_confirm(dialog):
                tk.Label(dialog, text="RETURN TO LAUNCHER?", font=('Arial', self.scale_font(16), 'bold'),
                        bg='#2c1810', fg='#ff6b6b', pady=15).pack()
                
                tk.Label(dialog, text="Your current run will be lost.\nAre you sure?",
                        font=('Arial', self.scale_font(11)), bg='#2c1810', fg='#ffffff',
                        pady=10).pack()
                
                btn_frame = tk.Frame(dialog, bg='#2c1810')
                btn_frame.pack(expand=True, pady=15)
                
                tk.Button(btn_frame, text="Yes, Quit to Launcher", 
                         command=lambda: (self.close_dialog(), confirm_quit()),
                         font=('Arial', self.scale_font(11), 'bold'), bg='#ff6b6b', fg='#ffffff',
                         width=20, pady=10).pack(pady=5)
                
                tk.Button(btn_frame, text="Cancel", 
                         command=self.close_dialog,
                         font=('Arial', self.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                         width=20, pady=10).pack(pady=5)
            
            self.show_dialog(build_confirm, width=400, height=250)
        else:
            confirm_quit()


def main():
    root = tk.Tk()
    game = DiceDungeonRPG(root)
    root.mainloop()

if __name__ == "__main__":
    main()
