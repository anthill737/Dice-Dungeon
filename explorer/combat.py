"""
Combat Manager Module

Handles combat mechanics including dice rolling, damage calculation, 
enemy attacks, and combat flow.

All methods use self.game.* to reference the main game state.
"""

import random
import tkinter as tk
from collections import Counter
from debug_logger import get_logger
import os
from PIL import Image, ImageTk


class CombatManager:
    """Manages all combat-related functionality"""
    
    def __init__(self, game):
        """
        Initialize combat manager with reference to main game
        
        Args:
            game: Reference to DiceDungeonExplorer instance
        """
        self.game = game
        self.debug_logger = get_logger()
    
    def toggle_dice(self, idx):
        """Toggle dice lock"""
        if self.game.dice_values[idx] == 0:
            return
        
        # Block toggling during attack sequences
        if hasattr(self.game, 'combat_state') and self.game.combat_state in ["resolving_player_attack", "resolving_enemy_attack"]:
            return
        
        self.game.dice_locked[idx] = not self.game.dice_locked[idx]
        self.game.dice_manager.update_dice_display()
    
    def roll_dice(self):
        """Roll unlocked dice with animation"""
        # Block rolling during attack sequence
        if hasattr(self.game, 'combat_state') and self.game.combat_state in ["resolving_player_attack", "resolving_enemy_attack"]:
            return
        
        if self.game.rolls_left <= 0:
            self.game.log("No rolls left! You must ATTACK now!", 'system')
            return
        
        # Disable roll button immediately to prevent spam
        if hasattr(self.game, 'roll_button'):
            self.game.roll_button.config(state=tk.DISABLED)
        
        # Determine which dice to roll
        dice_to_roll = [i for i in range(self.game.num_dice) if not self.game.dice_locked[i]]
        
        if not dice_to_roll:
            self.game.log("All dice are locked! Unlock some dice or ATTACK!", 'system')
            return
        
        # Calculate final values first
        final_values = {}
        for i in dice_to_roll:
            final_values[i] = random.randint(1, 6)
        
        # Animate the roll (8 frames, ~25ms each = ~200ms total)
        self.game._animate_dice_roll(dice_to_roll, final_values, 0, 8)
    
    def get_current_dice_style(self):
        """Get the current dice style with any overrides applied"""
        base_style = self.game.dice_styles.get(self.game.current_dice_style, self.game.dice_styles["classic_white"])
        style = base_style.copy()
        
        # Apply overrides
        if self.game.dice_style_overrides.get("bg"):
            style["bg"] = self.game.dice_style_overrides["bg"]
        if self.game.dice_style_overrides.get("pip_color"):
            style["pip_color"] = self.game.dice_style_overrides["pip_color"]
        if self.game.dice_style_overrides.get("face_mode"):
            style["face_mode"] = self.game.dice_style_overrides["face_mode"]
        
        return style
    
    def attack_enemy(self):
        """Initiate combat sequence - immediately log attack and disable controls"""
        self.debug_logger.combat("attack_enemy CALLED", 
                                 has_dice=any(self.game.dice_values),
                                 dice_values=self.game.dice_values,
                                 combat_state=getattr(self.game, 'combat_state', 'unknown'))
        
        if not any(self.game.dice_values):
            self.game.log("Roll the dice first!", 'system')
            self.debug_logger.warning("COMBAT", "No dice rolled yet")
            return
        
        # Block multiple attacks during sequence
        if hasattr(self.game, 'combat_state') and self.game.combat_state in ["resolving_player_attack", "resolving_enemy_attack"]:
            return
        
        # Set state and disable all interaction FIRST
        self.game.combat_state = "resolving_player_attack"
        
        # Disable roll button immediately when attacking
        if hasattr(self.game, 'current_roll_button') and self.game.current_roll_button:
            self.game.current_roll_button.configure(state='disabled', bg='#666666')
        
        self._disable_combat_controls()
        
        # Calculate and announce damage immediately
        self._calculate_and_announce_player_damage()
    
    def enemy_defeated(self):
        """Enemy is defeated"""
        # Import at module level to avoid circular dependency
        import dice_dungeon_explorer
        complete_room_success = dice_dungeon_explorer.complete_room_success
        
        self.game.in_combat = False
        self.game.current_room.enemies_defeated = True
        self.game.enemies_killed += 1
        
        # Hide enemy column and dice section after combat
        if hasattr(self.game, 'enemy_column'):
            self.game.enemy_column.pack_forget()
        if hasattr(self.game, 'dice_section'):
            self.game.dice_section.pack_forget()
        
        # Hide player sprite box after combat (exploration doesn't show it)
        if hasattr(self.game, 'player_sprite_box'):
            self.game.player_sprite_box.pack_forget()
        
        # Track stats
        self.game.stats["enemies_defeated"] += 1
        
        # Track enemy-specific kills
        enemy_name = self.game.enemy_name
        if enemy_name not in self.game.stats["enemy_kills"]:
            self.game.stats["enemy_kills"][enemy_name] = 0
        self.game.stats["enemy_kills"][enemy_name] += 1
        
        # Clear combat stats tracking flag
        if hasattr(self.game, 'combat_stats_tracked'):
            delattr(self.game, 'combat_stats_tracked')
        
        # Check if this was a boss fight
        is_mini_boss = getattr(self.game.current_room, 'is_mini_boss_room', False)
        is_boss = getattr(self.game.current_room, 'is_boss_room', False)
        
        if is_mini_boss:
            self.game.stats["mini_bosses_defeated"] += 1
        if is_boss:
            self.game.stats["bosses_defeated"] += 1
        
        enemy_type = self.game.enemy_name.split()[0]
        if enemy_type in self.game.enemy_death:
            self.game.log(random.choice(self.game.enemy_death[enemy_type]), 'enemy')
        
        # Clear temporary combat buffs
        self.game.clear_combat_buffs()
        
        # Rewards - scale based on boss type
        if is_boss:
            # Main boss rewards - amazing loot for clearing the floor
            gold_reward = random.randint(200, 350) + (self.game.floor * 100)
            self.game.gold += gold_reward
            self.game.total_gold_earned += gold_reward
            self.game.stats["gold_found"] += gold_reward
            self.game.run_score += 1000 + (self.game.floor * 200)
            
            self.game.log(f"{'='*60}", 'success')
            self.game.log(f"☠ FLOOR BOSS DEFEATED! ☠", 'success')
            self.game.log(f"+{gold_reward} gold!", 'loot')
            
            # Guarantee multiple rare equipment drops
            rare_equipment = [
                "Greatsword", "War Axe", "Assassin's Blade",
                "Plate Armor", "Dragon Scale", "Enchanted Cloak",
                "Greater Health Potion", "Greater Health Potion", "Greater Health Potion",
                "Strength Elixir", "Strength Elixir"
            ]
            
            # Give 3-5 random items from the rare loot pool
            num_rewards = random.randint(3, 5)
            for _ in range(num_rewards):
                boss_drop = random.choice(rare_equipment)
                self.game.try_add_to_inventory(boss_drop, "reward")
            
            self.game.boss_defeated = True
            
            # Permanently unlock this room after defeating boss
            self.game.unlocked_rooms.add(self.game.current_pos)
            
            self.game.log("[BOSS DEFEATED] The path forward is clear!", 'success')
            self.game.log("[STAIRS] Continue exploring to find the stairs to the next floor.", 'system')
            self.game.log(f"{'='*60}", 'success')
            
        elif is_mini_boss:
            # Mini-boss rewards - guaranteed good loot
            gold_reward = random.randint(50, 80) + (self.game.floor * 20)
            self.game.gold += gold_reward
            self.game.total_gold_earned += gold_reward
            self.game.stats["gold_found"] += gold_reward
            self.game.run_score += 500 + (self.game.floor * 50)
            
            self.game.log(f"[MINI-BOSS DEFEATED]", 'success')
            self.game.log(f"+{gold_reward} gold!", 'loot')
            
            # Give Boss Key Fragment (initialize if missing for old saves)
            if not hasattr(self.game, 'key_fragments_collected'):
                self.game.key_fragments_collected = 0
            self.game.key_fragments_collected += 1
            self.game.log(f"[KEY FRAGMENT] Obtained Boss Key Fragment! ({self.game.key_fragments_collected}/3)", 'loot')
            
            # Guaranteed useful loot - scale with floor for better equipment
            if self.game.floor >= 8:
                # High floors: best equipment
                useful_loot = [
                    "Greater Health Potion", "Greater Health Potion",
                    "Strength Elixir",
                    "Greatsword", "War Axe", "Assassin's Blade",
                    "Plate Armor", "Dragon Scale", "Enchanted Cloak"
                ]
            elif self.game.floor >= 5:
                # Mid floors: medium equipment
                useful_loot = [
                    "Health Potion", "Greater Health Potion",
                    "Strength Elixir",
                    "Iron Sword", "Battle Axe", "Steel Sword",
                    "Chain Vest", "Scale Mail", "Iron Shield"
                ]
            else:
                # Early floors: basic equipment
                useful_loot = [
                    "Health Potion", "Health Potion",
                    "Strength Elixir",
                    "Steel Dagger", "Iron Sword", "Hand Axe",
                    "Leather Armor", "Chain Vest", "Wooden Shield"
                ]
            bonus_loot = random.choice(useful_loot)
            self.game.try_add_to_inventory(bonus_loot, "reward")
            
            self.game.mini_bosses_defeated += 1
            
            # When 3rd mini-boss is defeated, set boss spawn target for 4-6 rooms from now
            if self.game.mini_bosses_defeated == 3:
                self.game.next_boss_at = self.game.rooms_explored_on_floor + random.randint(4, 6)
                self.game.log(f"[BOSS APPROACHING] The floor boss will appear soon...", 'enemy')
            
            # Permanently unlock this room after defeating mini-boss
            self.game.unlocked_rooms.add(self.game.current_pos)
            self.game.log("[UNLOCKED] This room is now permanently accessible!", 'success')
        else:
            # Normal enemy rewards
            gold_reward = random.randint(10, 30) + (self.game.floor * 5)
            self.game.gold += gold_reward
            self.game.total_gold_earned += gold_reward
            self.game.stats["gold_found"] += gold_reward
            self.game.run_score += 100 + (self.game.floor * 20)
            
            self.game.log(f"+{gold_reward} gold!", 'loot')
        
        # Reset boss fight flag
        self.game.is_boss_fight = False
        
        # Apply room clear effects
        complete_room_success(self.game, self.game.log)
        
        self.game.update_display()
        self.game.show_exploration_options()
    
    def attempt_flee(self):
        """Try to flee from combat"""
        # Cannot flee from boss fights!
        if self.game.is_boss_fight:
            self.game.log("❌ You cannot flee from a boss fight! Fight or die!", 'enemy')
            return
        
        # Check if player has an escape token for guaranteed escape
        has_escape_token = self.game.flags.get('escape_token', 0) > 0
        
        if has_escape_token:
            # Consume escape token for guaranteed flee
            self.game.flags['escape_token'] -= 1
            self.game.log("✨ Used Escape Token - fled safely without damage!", 'success')
            self.game.in_combat = False
            self.game.update_display()
            self.game.show_exploration_options()
        else:
            # 50% chance to flee, but lose some HP
            if random.random() < 0.5:
                damage = random.randint(5, 15)
                self.game.health -= damage
                self.game.log(f"[FLEE] You fled! Lost {damage} HP in the escape.", 'system')
                
                if self.game.health <= 0:
                    self.game.game_over()
                else:
                    self.game.in_combat = False
                    self.game.update_display()
                    self.game.show_exploration_options()
            else:
                self.game.log("❌ Can't escape! Enemy blocks the way!", 'enemy')
                # Failed escape - start combat turn (show dice and let player attack)
                self.game.root.after(1000, self.game.start_combat_turn)

    # ======================================================================
    # COMBAT FLOW METHODS - Migrated from DiceDungeonExplorer
    # ======================================================================


    # ======================================================================
    # trigger_combat
    # ======================================================================
    def trigger_combat(self, enemy_name, is_mini_boss=False, is_boss=False):
        """Start combat with enemy"""
        self.debug_logger.combat("trigger_combat CALLED", enemy=enemy_name, mini_boss=is_mini_boss, boss=is_boss)

        # Mark combat active immediately so other systems (like exploration UI) know to stay hidden
        self.game.in_combat = True
        self.game.combat_turn_count = 0  # Reset turn counter for spawning mechanics
        
        # Show action panel for combat encounter
        if hasattr(self, 'action_panel'):
            self.game.action_panel.pack(fill=tk.X, side=tk.TOP, padx=self.game.scale_padding(3), pady=self.game.scale_padding(2))
            self.game.action_panel.update_idletasks()  # Force UI update
            self.debug_logger.ui("action_panel shown in trigger_combat")

        
        # Reset rolls for fresh combat start (including reroll bonus from items)
        self.game.rolls_left = 3 + self.game.reroll_bonus
        self.game.dice_values = [0] * self.game.num_dice
        self.game.dice_locked = [False] * self.game.num_dice
        
        # Scale enemy with floor
        base_hp = 30 + (self.game.floor * 10)
        enemy_hp = base_hp + random.randint(-5, 10)
        
        # Determine enemy dice count - increased to be more competitive with player
        if is_boss:
            enemy_dice = min(5 + (self.game.floor // 2), 8)  # Start at 5, cap at 8
        elif is_mini_boss:
            enemy_dice = min(4 + (self.game.floor // 2), 7)  # Start at 4, cap at 7
        else:
            enemy_dice = min(3 + (self.game.floor // 2), 6)  # Start at 3, cap at 6
        
        # Apply boss multipliers
        if is_boss:
            boss_mult = 8.0
            enemy_hp = int(enemy_hp * boss_mult)
            boss_title = f"☠ FLOOR BOSS ☠"
            self.game.log(f"\n{'='*60}", 'enemy')
            self.game.log(f"{boss_title}", 'enemy')
            self.game.log(f"⚔️  {enemy_name.upper()}  ⚔️", 'enemy')
            self.game.log(f"{'='*60}", 'enemy')
        elif is_mini_boss:
            mini_boss_mult = 3.0
            enemy_hp = int(enemy_hp * mini_boss_mult)
            self.game.log(f"\n[MINI-BOSS] ⚡ {enemy_name.upper()} ⚡", 'enemy')
            self.game.log(f"A powerful guardian blocks your path!", 'enemy')
        else:
            if not (is_mini_boss or is_boss):
                self.game.log(f"\n{enemy_name} blocks your path!", 'enemy')
        
        # Apply difficulty multiplier to enemy health
        difficulty = self.game.settings.get("difficulty", "Normal")
        enemy_hp = int(enemy_hp * self.game.difficulty_multipliers[difficulty]["enemy_health_mult"])
        
        # Apply dev mode multipliers
        enemy_hp = int(enemy_hp * self.game.dev_config["enemy_hp_mult"])
        enemy_dice = int(enemy_dice * self.game.dev_config["enemy_dice_mult"])
        
        # Initialize enemies list with the primary enemy
        enemy_config = self.game.enemy_types.get(enemy_name, {})
        self.game.enemies = [{
            "name": enemy_name,
            "health": enemy_hp,
            "max_health": enemy_hp,
            "num_dice": enemy_dice,
            "is_boss": is_boss,
            "is_mini_boss": is_mini_boss,
            "config": enemy_config,
            "spawns_used": 0,  # Track how many times this enemy has spawned
            "has_split": False,  # Track if this enemy has already split
            "turn_spawned": 0  # Track when spawned for turn-based spawning
        }]
        
        # Set legacy properties for compatibility
        self.game.enemy_name = enemy_name
        self.game.enemy_health = enemy_hp
        self.game.enemy_max_health = enemy_hp
        self.game.enemy_num_dice = enemy_dice
        self.game.is_boss_fight = is_mini_boss or is_boss
        self.game.current_enemy_index = 0
        self.game.mystic_ring_used = False  # Reset Mystic Ring for new combat
        
        self.game.log(f"Enemy HP: {enemy_hp} | Dice: {enemy_dice}", 'enemy')
        
        # Hide dice section until combat starts
        if hasattr(self, 'dice_section'):
            self.game.dice_section.pack_forget()
        
        # Hide player sprite box during combat
        if hasattr(self.game, 'player_sprite_box'):
            self.game.player_sprite_box.pack_forget()
        
        # Show enemy info in action panel
        self.game.action_panel_enemy_label.config(text=enemy_name)
        
        if self.game.action_panel_enemy_hp:
            self.game.action_panel_enemy_hp.pack_forget()
        
        self.game.action_panel_enemy_hp = self.game.create_hp_bar(self.game.enemy_hp_frame, enemy_hp, enemy_hp, 
                                                         width=int(150 * self.game.scale_factor), 
                                                         height=int(22 * self.game.scale_factor))
        self.game.action_panel_enemy_hp.pack(anchor='e', pady=(2, 4))
        
        # Hide enemy sprite initially - only show when player clicks Attack
        if hasattr(self.game, 'enemy_sprite_area'):
            self.game.enemy_sprite_area.pack_forget()
            
            # Clear any existing sprite
            for widget in self.game.enemy_sprite_area.winfo_children():
                widget.destroy()
        # Hide dice and combat buttons until combat actually starts
        for widget in self.game.dice_frame.winfo_children():
            widget.destroy()
        for widget in self.game.combat_buttons_frame.winfo_children():
            widget.destroy()
        
        # Only clear action buttons when showing combat options
        # This preserves exploration buttons (rest, inventory, store, etc.)
        for widget in self.game.action_buttons_strip.winfo_children():
            widget.destroy()
        
        combat_frame = tk.Frame(self.game.action_buttons_strip, bg=self.game.current_colors["bg_panel"])
        combat_frame.pack(pady=self.game.scale_padding(1))
        
        attack_btn = tk.Button(combat_frame, text="Attack",
                 command=self.start_combat_turn,
                 font=('Arial', self.game.scale_font(9), 'bold'), bg='#e74c3c', fg='white',
                 width=12, pady=self.game.scale_padding(4))
        attack_btn.pack(side=tk.LEFT, padx=2)
        self.debug_logger.button("Attack button created in trigger_combat", command="start_combat_turn")
        self.debug_logger.button("Attack button created", command="start_combat_turn", state="normal")
        
        self.game.flee_button = tk.Button(combat_frame, text="Flee",
                 command=self.attempt_flee,
                 font=('Arial', self.game.scale_font(9), 'bold'), bg='#f39c12', fg='#000000',
                 width=12, pady=self.game.scale_padding(4))
        self.game.flee_button.pack(side=tk.LEFT, padx=2)
        
        # Update scroll region to ensure combat UI is visible
        self.game.update_scroll_region()
    


    # ======================================================================
    # spawn_additional_enemy
    # ======================================================================
    def spawn_additional_enemy(self, spawner_enemy, spawn_type, hp_mult, dice_count):
        """Spawn an additional enemy during combat"""
        # Calculate spawned enemy stats with base 30 HP + floor scaling
        base_hp = 30 + (self.game.floor * 10)
        spawn_hp = base_hp
        
        # Apply difficulty multiplier
        difficulty = self.game.settings.get("difficulty", "Normal")
        spawn_hp = int(spawn_hp * self.game.difficulty_multipliers[difficulty]["enemy_health_mult"])
        
        # Create spawned enemy
        spawned_enemy = {
            "name": spawn_type,
            "health": spawn_hp,
            "max_health": spawn_hp,
            "num_dice": dice_count,
            "is_boss": False,
            "is_mini_boss": False,
            "config": self.game.enemy_types.get(spawn_type, {}),
            "spawns_used": 0,
            "has_split": False,
            "turn_spawned": self.game.combat_turn_count,
            "is_spawned": True  # Mark as spawned for gold/XP calculations
        }
        
        # Add to enemies list
        self.game.enemies.append(spawned_enemy)
        
        # Log the spawn
        self.game.log(f"⚠️ {spawner_enemy['name']} summons a {spawn_type}! ⚠️", 'enemy')
        self.game.log(f"[SPAWNED] {spawn_type} - HP: {spawn_hp} | Dice: {dice_count}", 'enemy')
        
        # Update spawner's spawn count
        spawner_enemy["spawns_used"] += 1
        
        # Update display to show multiple enemies
        self.update_enemy_display()
    


    # ======================================================================
    # split_enemy
    # ======================================================================
    def split_enemy(self, enemy, split_type, split_count, hp_percent, dice_modifier=0):
        """Split an enemy into smaller enemies"""
        # Calculate split enemy stats with base 30 HP + floor scaling
        base_hp = 30 + (self.game.floor * 10)
        split_hp = base_hp
        split_dice = enemy["num_dice"] + dice_modifier  # dice_modifier is usually negative
        split_dice = max(1, split_dice)  # Minimum 1 die
        
        # Apply difficulty multiplier
        difficulty = self.game.settings.get("difficulty", "Normal")
        split_hp = int(split_hp * self.game.difficulty_multipliers[difficulty]["enemy_health_mult"])
        
        # Create split enemies
        split_enemies = []
        for i in range(split_count):
            split_enemy = {
                "name": split_type,
                "health": split_hp,
                "max_health": split_hp,
                "num_dice": split_dice,
                "is_boss": False,
                "is_mini_boss": False,
                "config": self.game.enemy_types.get(split_type, {}),
                "spawns_used": 0,
                "has_split": True,  # Mark as already split to prevent infinite splitting
                "turn_spawned": self.game.combat_turn_count,
                "is_split": True  # Mark as split for gold/XP calculations
            }
            split_enemies.append(split_enemy)
        
        # Log the split
        self.game.log(f"✸ {enemy['name']} splits into {split_count} {split_type}s! ✸", 'enemy')
        for split_enemy in split_enemies:
            self.game.log(f"[SPLIT] {split_enemy['name']} - HP: {split_hp} | Dice: {split_dice}", 'enemy')
        
        # Remove original enemy and add split enemies
        if enemy in self.game.enemies:
            enemy_index = self.game.enemies.index(enemy)
            self.game.enemies.pop(enemy_index)
            # Insert split enemies at the same position
            for split_enemy in reversed(split_enemies):
                self.game.enemies.insert(enemy_index, split_enemy)
        
        # Update target index if needed
        if self.game.current_enemy_index >= len(self.game.enemies):
            self.game.current_enemy_index = 0
        
        # Update display
        self.update_enemy_display()
    


    # ======================================================================
    # update_enemy_display
    # ======================================================================
    def update_enemy_display(self):
        """Update the display to show all active enemies"""
        if len(self.game.enemies) == 0:
            return
        
        # Update primary enemy for compatibility with existing code
        primary_enemy = self.game.enemies[0]
        self.game.enemy_name = primary_enemy["name"]
        self.game.enemy_health = primary_enemy["health"]
        self.game.enemy_max_health = primary_enemy["max_health"]
        self.game.enemy_num_dice = primary_enemy["num_dice"]
        
        # Log all enemies if multiple
        if len(self.game.enemies) > 1:
            enemy_names = ", ".join([e["name"] for e in self.game.enemies])
            total_hp = sum([e["health"] for e in self.game.enemies])
            self.game.log(f"[ENEMIES] {enemy_names} | Total HP: {total_hp}", 'enemy')
    


    # ======================================================================
    # check_spawn_conditions
    # ======================================================================
    def check_spawn_conditions(self):
        """Check if any enemies should spawn additional enemies"""
        for enemy in self.game.enemies:
            config = enemy.get("config", {})
            
            # Skip if can't spawn or already at max spawns
            if not config.get("can_spawn", False):
                continue
            
            max_spawns = config.get("max_spawns", 0)
            if enemy["spawns_used"] >= max_spawns:
                continue
            
            spawn_trigger = config.get("spawn_trigger", "")
            
            # HP threshold trigger (one-time spawn at specific HP %)
            if spawn_trigger == "hp_threshold":
                current_hp_percent = enemy["health"] / enemy["max_health"]
                threshold = config.get("spawn_hp_threshold", 0.5)
                
                if current_hp_percent <= threshold and enemy["spawns_used"] == 0:
                    spawn_count = config.get("spawn_count", 1)
                    for _ in range(spawn_count):
                        if enemy["spawns_used"] < max_spawns:
                            self.spawn_additional_enemy(
                                enemy,
                                config.get("spawn_type", "Skeleton"),
                                config.get("spawn_hp_mult", 0.3),
                                config.get("spawn_dice", 2)
                            )
            
            # Multiple HP thresholds (spawn at 75%, 50%, 25%, etc.)
            elif spawn_trigger == "hp_thresholds":
                current_hp_percent = enemy["health"] / enemy["max_health"]
                thresholds = config.get("spawn_hp_thresholds", [])
                spawns_used = enemy["spawns_used"]
                
                # Check each threshold in order
                for i, threshold in enumerate(thresholds):
                    if i >= spawns_used and current_hp_percent <= threshold:
                        if enemy["spawns_used"] < max_spawns:
                            spawn_count = config.get("spawn_count", 1)
                            for _ in range(spawn_count):
                                self.spawn_additional_enemy(
                                    enemy,
                                    config.get("spawn_type", "Imp"),
                                    config.get("spawn_hp_mult", 0.25),
                                    config.get("spawn_dice", 2)
                                )
                        break  # Only spawn once per threshold crossed
            
            # Turn-based spawning (every N turns)
            elif spawn_trigger == "turn_count":
                interval = config.get("spawn_turn_interval", 3)
                turns_since_spawn = self.game.combat_turn_count - enemy.get("turn_spawned", 0)
                
                if turns_since_spawn > 0 and turns_since_spawn % interval == 0:
                    if enemy["spawns_used"] < max_spawns:
                        spawn_count = config.get("spawn_count", 1)
                        for _ in range(spawn_count):
                            if enemy["spawns_used"] < max_spawns:
                                self.spawn_additional_enemy(
                                    enemy,
                                    config.get("spawn_type", "Goblin"),
                                    config.get("spawn_hp_mult", 0.4),
                                    config.get("spawn_dice", 2)
                                )
    


    # ======================================================================
    # check_split_conditions
    # ======================================================================
    def check_split_conditions(self, enemy):
        """Check if an enemy should split"""
        config = enemy.get("config", {})
        
        # Skip if already split (prevent infinite splitting)
        if enemy.get("has_split", False):
            return False
        
        # Check split-on-HP threshold (splits when damaged below threshold)
        if config.get("splits_on_hp", False):
            current_hp_percent = enemy["health"] / enemy["max_health"]
            threshold = config.get("split_hp_threshold", 0.3)
            
            if current_hp_percent <= threshold:
                self.split_enemy(
                    enemy,
                    config.get("split_into_type", "Shard"),
                    config.get("split_count", 2),
                    config.get("split_hp_percent", 0.5),
                    config.get("split_dice", 0)
                )
                return True
        
        return False
    


    # ======================================================================
    # select_target
    # ======================================================================
    def select_target(self, target_index):
        """Select which enemy to target"""
        if target_index < len(self.game.enemies):
            self.game.current_enemy_index = target_index
            target = self.game.enemies[target_index]
            self.game.log(f"● Target locked: {target['name']} ({target['health']}/{target['max_health']} HP)", 'system')
            
            # Update target button visuals if they exist
            if hasattr(self.game, 'target_buttons') and self.game.target_buttons:
                for i, btn in enumerate(self.game.target_buttons):
                    if i == target_index:
                        btn.config(bg='#ff6b6b', relief=tk.SUNKEN)
                    else:
                        btn.config(bg='#8b0000', relief=tk.RAISED)
            
            # Update enemy sprite to show the targeted enemy
            if hasattr(self.game, 'enemy_sprite_label') and self.game.enemy_sprite_label:
                enemy_name = target['name']
                if enemy_name in self.game.enemy_sprites:
                    self.game.enemy_sprite_label.configure(image=self.game.enemy_sprites[enemy_name])
                    self.game.enemy_sprite_label.image = self.game.enemy_sprites[enemy_name]
    


    # ======================================================================
    # process_status_effects
    # ======================================================================
    def process_status_effects(self):
        """Process active status effects each combat turn"""
        statuses = self.game.flags.get('statuses', [])
        if not statuses:
            return
        
        for status in statuses:
            # Damage-over-time effects
            if 'poison' in status.lower() or 'rot' in status.lower():
                damage = 3  # Base DoT damage
                if not self.game.dev_invincible:
                    self.game.health -= damage
                    self.game.log(f"☠ [{status}] You take {damage} damage!", 'enemy')
                else:
                    self.game.log(f"☠ [{status}] Blocked by God Mode!", 'system')
            
            elif 'bleed' in status.lower():
                damage = 2
                if not self.game.dev_invincible:
                    self.game.health -= damage
                    self.game.log(f"▪ [{status}] You take {damage} bleed damage!", 'enemy')
                else:
                    self.game.log(f"▪ [{status}] Blocked by God Mode!", 'system')
            
            elif 'burn' in status.lower() or 'heat' in status.lower():
                damage = 2
                if not self.game.dev_invincible:
                    self.game.health -= damage
                    self.game.log(f"✹ [{status}] You take {damage} fire damage!", 'fire')
                else:
                    self.game.log(f"✹ [{status}] Blocked by God Mode!", 'system')
            
            # Debuff effects
            elif 'choke' in status.lower() or 'soot' in status.lower():
                # Reduces damage by 20%
                self.game.log(f"≋ [{status}] Your attacks are weakened!", 'system')
            
            elif 'hunger' in status.lower():
                # Reduces healing by 50%
                self.game.log(f"◆ [{status}] You feel weakened from hunger...", 'system')
        
        # Check if player died from status effects
        if self.game.health <= 0:
            self.game.game_over()
    


    # ======================================================================
    # start_combat_turn
    # ======================================================================
    def start_combat_turn(self):
        """Begin a combat turn with dice rolling"""
        self.debug_logger.combat("start_combat_turn CALLED", in_combat=self.game.in_combat, 
                                 has_enemy=hasattr(self.game, 'enemy_name'))
        
        if not self.game.in_combat:
            self.debug_logger.warning("COMBAT", "Not in combat, calling trigger_combat()")
            self.trigger_combat()
            return
        
        self.debug_logger.state("Combat turn starting", combat_state="player_rolled")
        
        # Show action panel for combat - FORCE repack to ensure it's visible
        if hasattr(self.game, 'action_panel'):
            # First unpack it completely
            self.game.action_panel.pack_forget()
            # Then pack it again with explicit parameters (after room_frame so room shows first)
            self.game.action_panel.pack(fill=tk.X, side=tk.TOP, padx=self.game.scale_padding(3), pady=self.game.scale_padding(2), after=self.game.room_frame)
            self.debug_logger.ui("action_panel repacked")
        
        # Show dice section for combat
        if hasattr(self.game, 'dice_section'):
            # Force repack
            self.game.dice_section.pack_forget()
            self.game.dice_section.pack(side=tk.TOP, fill=tk.BOTH, expand=True, padx=20, pady=10)
            self.debug_logger.ui("dice_section repacked")
        
        # Show player sprite box during combat
        if hasattr(self.game, 'player_sprite_box'):
            self.game.player_sprite_box.pack(anchor='w', pady=(4, 0))
        
        # Show and configure enemy column for combat
        if hasattr(self.game, 'enemy_column'):
            self.game.enemy_column.pack(side='right', fill='y')
            self.game.enemy_column.configure(height=160)
        
        # Show enemy sprite now that combat has started
        if hasattr(self.game, 'enemy_sprite_area') and len(self.game.enemies) > 0:
            enemy = self.game.enemies[self.game.current_enemy_index]
            enemy_name = enemy['name']
            
            self.game.enemy_sprite_area.pack(anchor='e')
            
            # Clear any existing sprite
            for widget in self.game.enemy_sprite_area.winfo_children():
                widget.destroy()
            
            # Load and display actual sprite if available
            if enemy_name in self.game.enemy_sprites:
                sprite_label = tk.Label(self.game.enemy_sprite_area, 
                                       image=self.game.enemy_sprites[enemy_name],
                                       bg='#1a1410')
                sprite_label.place(relx=0.5, rely=0.5, anchor='center')
                self.game.enemy_sprite_label = sprite_label
            else:
                # Fallback to placeholder text
                self.game.enemy_sprite_label = tk.Label(self.game.enemy_sprite_area, 
                                                   text="Enemy\nSprite", 
                                                   font=('Arial', 7), 
                                                   bg='#1a1410', 
                                                   fg='#555555')
                self.game.enemy_sprite_label.place(relx=0.5, rely=0.5, anchor='center')
        
        # Reset Mystic Ring at start of each combat (first turn only)
        if not hasattr(self.game, 'combat_turn_count'):
            self.game.combat_turn_count = 0
            self.game.mystic_ring_used = False
        self.game.combat_turn_count += 1
        
        # Reset combat state to idle (waiting for player to roll)
        self.game.combat_state = "idle"  # States: idle, player_rolled, resolving_player_attack, resolving_enemy_attack
        
        # Reset dice completely for new turn
        self.game.rolls_left = 3 + self.game.reroll_bonus
        self.game.dice_values = [0] * self.game.num_dice
        self.game.dice_locked = [False] * self.game.num_dice
        self.game.has_rolled = False  # Track if player has rolled at least once
        
        # Update rolls label to reflect fresh start
        max_rolls = 3 + self.game.reroll_bonus
        if hasattr(self.game, 'rolls_label'):
            self.game.rolls_label.config(text=f"Rolls Remaining: {self.game.rolls_left}/{max_rolls}")
        
        # Process status effects at start of turn
        self.process_status_effects()
        
        # Clear old combat UI widgets (including the initial attack/flee buttons)
        for widget in self.game.dice_frame.winfo_children():
            widget.destroy()
        for widget in self.game.combat_buttons_frame.winfo_children():
            widget.destroy()
        for widget in self.game.action_buttons_strip.winfo_children():
            widget.destroy()
        
        # Dice display - using canvas for proper style rendering
        dice_display = tk.Frame(self.game.dice_frame, bg=self.game.current_colors["bg_panel"])
        dice_display.pack(pady=5)
        self.debug_logger.ui("Dice display frame created")
        
        self.game.dice_buttons = []
        self.game.dice_canvases = []
        for i in range(self.game.num_dice):
            # Create a container frame for each die
            die_container = tk.Frame(dice_display, bg=self.game.current_colors["bg_panel"])
            die_container.grid(row=0, column=i, padx=5)
            
            # Create canvas for die rendering (larger for visibility)
            canvas = tk.Canvas(die_container, width=72, height=72,
                             bg=self.game.current_colors["bg_panel"], highlightthickness=0, cursor="hand2")
            canvas.pack()
            
            # Bind click event to toggle dice
            canvas.bind('<Button-1>', lambda e, idx=i: self.game.dice_manager.toggle_dice(idx))
            
            # Store canvas and render initial state
            self.game.dice_canvases.append(canvas)
            self.game.dice_buttons.append(canvas)  # Keep for compatibility
            
            # Render initial "?" state
            style = self.get_current_dice_style()
            canvas.create_rectangle(0, 0, 72, 72, fill='#cccccc', outline='#666666', width=3)
            canvas.create_text(36, 36, text="?", font=('Arial', 32, 'bold'), fill='#666666')
        
        # Target selection (if multiple enemies) - moved to action_buttons_strip area
        if len(self.game.enemies) > 1:
            target_label = tk.Label(self.game.action_buttons_strip, text="● SELECT TARGET:", 
                                   font=('Arial', self.game.scale_font(11), 'bold'), 
                                   bg=self.game.current_colors["bg_panel"], 
                                   fg='#ff6b6b')
            target_label.pack(pady=(self.game.scale_padding(6), self.game.scale_padding(3)))
            
            target_frame = tk.Frame(self.game.action_buttons_strip, bg=self.game.current_colors["bg_panel"])
            target_frame.pack(pady=5)
            
            self.game.target_buttons = []
            for i, enemy in enumerate(self.game.enemies):
                hp_percent = int((enemy['health'] / enemy['max_health']) * 100)
                target_text = f"{enemy['name']}\n{enemy['health']}/{enemy['max_health']} HP ({hp_percent}%)\n{enemy['num_dice']} dice"
                
                # Highlight selected target
                if i == self.game.current_enemy_index:
                    bg_color = '#ff6b6b'
                    fg_color = '#ffffff'
                    relief = tk.SUNKEN
                else:
                    bg_color = '#8b0000'
                    fg_color = '#ffffff'
                    relief = tk.RAISED
                
                btn = tk.Button(target_frame, text=target_text,
                               command=lambda idx=i: self.select_target(idx),
                               font=('Arial', 10, 'bold'), bg=bg_color, fg=fg_color,
                               width=18, pady=8, relief=relief)
                btn.grid(row=0, column=i, padx=5)
                self.game.target_buttons.append(btn)
        
        # Action buttons
        btn_frame = tk.Frame(self.game.combat_buttons_frame, bg=self.game.current_colors["bg_panel"])
        btn_frame.pack(pady=self.game.scale_padding(4))
        
        self.game.roll_button = tk.Button(btn_frame, text="⚄ Roll Dice",
                 command=self.game.dice_manager.roll_dice,
                 font=('Arial', self.game.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                 width=13, pady=self.game.scale_padding(8), relief=tk.FLAT, state=tk.NORMAL)
        self.game.roll_button.pack(side=tk.LEFT, padx=4)
        self.debug_logger.button("Roll Dice button created", command="roll_dice", state="NORMAL")
        
        # Store reference for enabling/disabling during combat
        self.game.current_roll_button = self.game.roll_button
        
        # Explicitly ensure button is enabled and properly colored
        self.game.roll_button.config(state=tk.NORMAL, bg='#4ecdc4', fg='#000000')
        self.debug_logger.button("Roll Dice button configured", state="NORMAL", bg="#4ecdc4")
        
        # Check if Mystic Ring is equipped and can be used
        if self.game.equipped_items.get('accessory') == 'Mystic Ring' and not self.game.mystic_ring_used:
            self.game.mystic_ring_button = tk.Button(btn_frame, text="◊ Mystic Ring",
                     command=self.use_mystic_ring,
                     font=('Arial', self.game.scale_font(11), 'bold'), bg='#9b59b6', fg='#ffffff',
                     width=13, pady=self.game.scale_padding(8), relief=tk.FLAT)
            self.game.mystic_ring_button.pack(side=tk.LEFT, padx=4)
        
        self.game.attack_button = tk.Button(btn_frame, text="⚔️ ATTACK!",
                 command=self.attack_enemy,
                 font=('Arial', self.game.scale_font(11), 'bold'), bg='#666666', fg='#333333',
                 width=13, pady=self.game.scale_padding(8), state=tk.DISABLED, relief=tk.FLAT)
        self.game.attack_button.pack(side=tk.LEFT, padx=4)
        self.debug_logger.button("ATTACK! button created", command="attack_enemy", state="DISABLED", bg="#666666")
        
        # Try to force widgets to be visible by lifting them
        self.game.action_panel.lift()
        self.game.dice_section.lift()
        
        # Force complete UI update
        self.game.root.update()
        
        # Debug: Check if widgets are actually visible AFTER update
        self.debug_logger.debug("GEOMETRY", f"AFTER UPDATE - action_panel ismapped: {self.game.action_panel.winfo_ismapped()}")
        self.debug_logger.debug("GEOMETRY", f"AFTER UPDATE - dice_section ismapped: {self.game.dice_section.winfo_ismapped()}")
        self.debug_logger.debug("GEOMETRY", f"AFTER UPDATE - action_panel size: {self.game.action_panel.winfo_width()}x{self.game.action_panel.winfo_height()}")
        self.debug_logger.debug("GEOMETRY", f"AFTER UPDATE - dice_section size: {self.game.dice_section.winfo_width()}x{self.game.dice_section.winfo_height()}")
        
        # Update scroll region to ensure combat UI is visible
        self.game.update_scroll_region()
        
        self.debug_logger.combat("start_combat_turn COMPLETE - combat UI ready")
    


    # ======================================================================
    # use_mystic_ring
    # ======================================================================
    def use_mystic_ring(self):
        """Use Mystic Ring to gain +1 reroll this combat"""
        if self.game.mystic_ring_used:
            self.game.log("You've already used the Mystic Ring this combat!", 'system')
            return
        
        # Grant +1 reroll
        self.game.rolls_left += 1
        self.game.mystic_ring_used = True
        
        self.game.log("◊ [MYSTIC RING] The ring glows with power! +1 reroll granted!", 'success')
        
        # Update rolls display
        max_rolls = 3 + self.game.reroll_bonus
        if hasattr(self, 'rolls_label'):
            self.game.rolls_label.config(text=f"Rolls Remaining: {self.game.rolls_left}/{max_rolls}")
        
        # Disable the Mystic Ring button
        if hasattr(self, 'mystic_ring_button'):
            self.game.mystic_ring_button.config(state=tk.DISABLED, bg='#555555', text="◊ Used")
    


    # ======================================================================
    # use_fire_potion
    # ======================================================================
    def use_fire_potion(self, target_index=None):
        """Throw Fire Potion at enemy to inflict burn damage"""
        if not self.game.enemies:
            self.game.log("No enemy to throw it at!", 'system')
            return
        
        # Calculate burn damage (8 initial damage, 3 turns: 8, 5, 2)
        initial_damage = 8
        
        # Get target enemy (use provided index or current target)
        if target_index is None:
            target_index = self.game.current_enemy_index
        if target_index >= len(self.game.enemies):
            target_index = 0
        
        target_enemy = self.game.enemies[target_index]
        
        # Apply initial burn damage
        target_enemy['health'] -= initial_damage
        
        # Set burn status for 3 turns of diminishing damage
        self.game.enemy_burn_status[target_index] = {
            'initial_damage': initial_damage,
            'turns_remaining': 3
        }
        
        self.game.log(f"🔥 [FIRE POTION] You throw the potion at {target_enemy['name']}!", 'fire')
        self.game.log(f"🔥 It explodes for {initial_damage} damage and ignites them!", 'fire')
        self.game.log(f"🔥 {target_enemy['name']} is burning! (3 turns)", 'fire')
        
        # Update display and check if enemy died
        self.game.update_display()
        
        # Animate enemy taking damage (shake and flash)
        self._animate_enemy_damage(initial_damage)
        
        # Check if enemy died from burn
        if target_enemy['health'] <= 0:
            self.game.root.after(800, lambda: self._check_enemy_death_from_burn(target_index))
    


    def _check_enemy_death_from_burn(self, target_index):
        """Check if enemy died from Fire Potion burn"""
        if target_index < len(self.game.enemies):
            enemy = self.game.enemies[target_index]
            if enemy['health'] <= 0:
                self.game.log(f"💀 {enemy['name']} burned to death!", 'fire')
                self.game.root.after(300, lambda: self._play_enemy_defeat_animation(target_index))
    


    # ======================================================================
    # _disable_combat_controls
    # ======================================================================
    def _disable_combat_controls(self):
        """Disable all combat controls during attack sequences"""
        # Disable attack button
        if hasattr(self, 'attack_button'):
            try:
                self.game.attack_button.config(state=tk.DISABLED, bg='#666666', fg='#333333')
            except tk.TclError:
                pass  # Widget no longer exists
        
        # Disable flee button
        if hasattr(self, 'flee_button'):
            try:
                self.game.flee_button.config(state=tk.DISABLED, bg='#999999', fg='#555555')
            except tk.TclError:
                pass  # Widget no longer exists
    


    # ======================================================================
    # _animate_enemy_damage
    # ======================================================================
    def _animate_enemy_damage(self, damage):
        """Trigger enemy damage animation (shake and flash) with sprite animation for Acid Hydra"""
        self._flash_enemy_hp(damage)
        
        # Play damage animation sprite sequence for Acid Hydra
        if hasattr(self, 'enemies') and len(self.game.enemies) > 0:
            current_enemy = self.game.enemies[min(self.game.current_enemy_index, len(self.game.enemies) - 1)]
            enemy_name = current_enemy.get('name', '')
            
            if 'Acid Hydra' in enemy_name:
                self._play_enemy_animation('acid_hydra', 'taking-punch', 'south', 6, 50)
    


    # ======================================================================
    # _play_enemy_animation
    # ======================================================================
    def _play_enemy_animation(self, enemy_folder, animation_name, direction, num_frames, frame_delay_ms):
        """Play an enemy sprite animation sequence"""
        if not hasattr(self.game, 'enemy_sprite_label') or not self.game.enemy_sprite_label:
            return
        
        base_dir = os.path.dirname(os.path.abspath(__file__))
        animation_dir = os.path.join(base_dir, 'assets', 'sprites', 'enemies', enemy_folder, 
                                     'animations', animation_name, direction)
        
        if not os.path.exists(animation_dir):
            print(f"Animation directory not found: {animation_dir}")
            return
        
        # Load animation frames
        frames = []
        for i in range(num_frames):
            frame_path = os.path.join(animation_dir, f'frame_{i:03d}.png')
            if os.path.exists(frame_path):
                try:
                    img = Image.open(frame_path)
                    # Resize to fit sprite area (90x90)
                    img.thumbnail((90, 90), Image.Resampling.NEAREST)
                    photo = ImageTk.PhotoImage(img)
                    frames.append(photo)
                except Exception as e:
                    print(f"Error loading animation frame {frame_path}: {e}")
        
        if frames:
            print(f"Playing {len(frames)} frames for {animation_name}")
            self._play_animation_frames(frames, 0, frame_delay_ms)
        else:
            print(f"No frames loaded for {animation_name}")
    


    # ======================================================================
    # _play_animation_frames
    # ======================================================================
    def _play_animation_frames(self, frames, current_frame, delay_ms):
        """Recursively play animation frames"""
        if not hasattr(self.game, 'enemy_sprite_label') or not self.game.enemy_sprite_label:
            return
        
        if current_frame < len(frames):
            try:
                self.game.enemy_sprite_label.configure(image=frames[current_frame])
                self.game.enemy_sprite_label.image = frames[current_frame]  # Keep reference
                self.game.root.after(delay_ms, lambda: self._play_animation_frames(frames, current_frame + 1, delay_ms))
            except Exception as e:
                print(f"Error displaying frame {current_frame}: {e}")
        else:
            # Animation complete - restore static sprite
            if hasattr(self, 'enemies') and len(self.game.enemies) > 0:
                current_enemy = self.game.enemies[min(self.game.current_enemy_index, len(self.game.enemies) - 1)]
                enemy_name = current_enemy.get('name', '')
                if enemy_name in self.game.enemy_sprites:
                    try:
                        self.game.enemy_sprite_label.configure(image=self.game.enemy_sprites[enemy_name])
                        self.game.enemy_sprite_label.image = self.game.enemy_sprites[enemy_name]
                    except Exception as e:
                        print(f"Error restoring sprite: {e}")
    


    # ======================================================================
    # _animate_player_damage
    # ======================================================================
    def _animate_player_damage(self, damage):
        """Trigger player damage animation (shake and flash)"""
        self._flash_player_hp(damage)
    


    # ======================================================================
    # _apply_player_damage
    # ======================================================================
    def _apply_player_damage(self, damage):
        """Apply damage to enemy with visual feedback (LEGACY - being replaced)"""
        # Damage weapon durability
        self.game._damage_equipment_durability("weapon", 3)
        
        # Set flag to prevent display update from resetting flash colors
        self.game._is_flashing = True
        
        # Apply damage to target
        if len(self.game.enemies) > 0:
            target_index = min(self.game.current_enemy_index, len(self.game.enemies) - 1)
            target = self.game.enemies[target_index]
            
            target["health"] -= damage
            self.game.enemy_health = target["health"]
            
            # Update display first to show new HP values
            self.game.update_display()
            
            # Flash immediately since we already waited for text to display
            self._flash_enemy_hp(damage)
            
            # Check if enemy splits before dying
            if target["health"] > 0:
                self.check_split_conditions(target)
            
            if target["health"] <= 0:
                # Check for death-based splitting
                config = target.get("config", {})
                if config.get("splits_on_death", False) and not target.get("has_split", False):
                    self.split_enemy(
                        target,
                        config.get("split_into_type", "Shard"),
                        config.get("split_count", 2),
                        config.get("split_hp_percent", 0.5),
                        config.get("split_dice", -1)
                    )
                    self.update_enemy_display()
                    # Proceed to enemy turn after delay
                    self.game.root.after(600, self._start_enemy_turn_sequence)
                else:
                    # Enemy defeated - play defeat animation
                    # Trigger defeat animation, then clean up
                    self._play_enemy_defeat_animation(target_index)
            else:
                # Enemy survived
                self.game.log(f"Enemy HP: {max(0, target['health'])}/{target['max_health']}", 'enemy')
                
                enemy_type = target['name'].split()[0]
                if enemy_type in self.game.enemy_hurt:
                    self.game.log(random.choice(self.game.enemy_hurt[enemy_type]), 'enemy')
                
                self.check_spawn_conditions()
                
                # Proceed to enemy turn after delay
                self.game.root.after(700, self._start_enemy_turn_sequence)
        else:
            # Fallback to old system
            self.game.enemy_health -= damage
            
            # Update display first to show new HP values
            self.game.update_display()
            
            # Then flash
            self._flash_enemy_hp()
            
            if self.game.enemy_health <= 0:
                self.game.combat_state = "idle"
                # Play defeat animation before calling enemy_defeated
                self._play_enemy_defeat_animation_legacy()
            else:
                self.game.log(f"Enemy HP: {max(0, self.game.enemy_health)}/{self.game.enemy_max_health}", 'enemy')
                enemy_type = self.game.enemy_name.split()[0]
                if enemy_type in self.game.enemy_hurt:
                    self.game.log(random.choice(self.game.enemy_hurt[enemy_type]), 'enemy')
                
                # Proceed to enemy turn after delay
                self.game.root.after(400, self._start_enemy_turn_sequence)
    


    # ======================================================================
    # _play_enemy_defeat_animation
    # ======================================================================
    def _play_enemy_defeat_animation(self, target_index):
        """Play dramatic defeat animation for enemy before removing them"""
        # Check if this is Acid Hydra - play sprite death animation
        if hasattr(self, 'enemies') and target_index < len(self.game.enemies):
            enemy_name = self.game.enemies[target_index].get('name', '')
            
            if 'Acid Hydra' in enemy_name:
                # Play PixelLab death animation (7 frames at 60ms each = 420ms)
                self._play_enemy_death_animation('acid_hydra', 'falling-back-death', 'south', 7, 60)
                # Wait for animation to complete, then fade out
                self.game.root.after(450, lambda: self._fade_out_enemy(target_index, 10))
                return
        
        # Fallback: Shake and flash the enemy (intense version)
        self._flash_enemy_hp_intense()
        
        # After shake/flash completes, fade out and remove
        self.game.root.after(900, lambda: self._fade_out_enemy(target_index, 10))
    


    # ======================================================================
    # _play_enemy_defeat_animation_legacy
    # ======================================================================
    def _play_enemy_defeat_animation_legacy(self):
        """Play defeat animation for legacy single enemy system"""
        # Check if this is Acid Hydra
        if hasattr(self, 'enemies') and len(self.game.enemies) > 0:
            current_enemy = self.game.enemies[min(self.game.current_enemy_index, len(self.game.enemies) - 1)]
            enemy_name = current_enemy.get('name', '')
            
            if 'Acid Hydra' in enemy_name:
                # Play PixelLab death animation (7 frames at 60ms each = 420ms)
                self._play_enemy_death_animation('acid_hydra', 'falling-back-death', 'south', 7, 60)
                self.game.root.after(450, lambda: self.enemy_defeated())
                return
        
        # Fallback to slide-down animation for other enemies
        self._shrink_enemy_sprite(1.0, 15)
        self.game.root.after(400, lambda: self.enemy_defeated())
    


    # ======================================================================
    # _play_enemy_death_animation
    # ======================================================================
    def _play_enemy_death_animation(self, enemy_folder, animation_name, direction, num_frames, frame_delay_ms):
        """Play an enemy death animation sequence"""
        if not hasattr(self.game, 'enemy_sprite_label') or not self.game.enemy_sprite_label:
            return
        
        base_dir = os.path.dirname(os.path.abspath(__file__))
        animation_dir = os.path.join(base_dir, 'assets', 'sprites', 'enemies', enemy_folder, 
                                     'animations', animation_name, direction)
        
        if not os.path.exists(animation_dir):
            # Fallback to slide-down
            self._shrink_enemy_sprite(1.0, 15)
            return
        
        # Load animation frames
        frames = []
        for i in range(num_frames):
            frame_path = os.path.join(animation_dir, f'frame_{i:03d}.png')
            if os.path.exists(frame_path):
                try:
                    img = Image.open(frame_path)
                    # Resize to fit sprite area (90x90)
                    img.thumbnail((90, 90), Image.Resampling.NEAREST)
                    photo = ImageTk.PhotoImage(img)
                    frames.append(photo)
                except Exception as e:
                    print(f"Error loading death animation frame {frame_path}: {e}")
        
        if frames:
            self._play_death_animation_frames(frames, 0, frame_delay_ms)
        else:
            # Fallback to slide-down if frames failed to load
            self._shrink_enemy_sprite(1.0, 15)
    


    # ======================================================================
    # _play_death_animation_frames
    # ======================================================================
    def _play_death_animation_frames(self, frames, current_frame, delay_ms):
        """Recursively play death animation frames"""
        if not hasattr(self.game, 'enemy_sprite_label') or not self.game.enemy_sprite_label:
            return
        
        if current_frame < len(frames):
            try:
                self.game.enemy_sprite_label.configure(image=frames[current_frame])
                self.game.enemy_sprite_label.image = frames[current_frame]  # Keep reference
                self.game.root.after(delay_ms, lambda: self._play_death_animation_frames(frames, current_frame + 1, delay_ms))
            except:
                pass
        # Animation complete - sprite will be hidden by enemy_defeated()
    


    # ======================================================================
    # _shrink_enemy_sprite
    # ======================================================================
    def _shrink_enemy_sprite(self, scale, frames_remaining):
        """Slide enemy sprite down out of frame like Pokemon defeat"""
        if not hasattr(self.game, 'enemy_sprite_area') or not self.game.enemy_sprite_area or not self.game.enemy_sprite_area.winfo_exists():
            return
        
        if frames_remaining <= 0:
            # Animation complete - hide sprite
            try:
                self.game.enemy_sprite_area.pack_forget()
            except:
                pass
            return
        
        # Calculate downward slide distance (slide down 120 pixels over 15 frames)
        slide_distance = int((1.0 - (frames_remaining / 15.0)) * 120)
        
        try:
            # Get current pack info
            pack_info = self.game.enemy_sprite_area.pack_info()
            
            # Slide down by increasing top padding
            self.game.enemy_sprite_area.pack_configure(pady=(slide_distance, 0))
            
            # Fade effect - reduce opacity by changing background
            fade_level = int(255 * (frames_remaining / 15.0))
            fade_color = f'#{fade_level:02x}0000'  # Fade to dark red
            self.game.enemy_sprite_area.configure(bg=fade_color)
            
            # Schedule next frame (25ms for smooth animation)
            self.game.root.after(25, lambda: self._shrink_enemy_sprite(scale, frames_remaining - 1))
        except:
            pass
    


    # ======================================================================
    # _flash_enemy_hp_intense
    # ======================================================================
    def _flash_enemy_hp_intense(self):
        """Intense flash and shake for enemy defeat"""
        # Flash HP bar multiple times
        if hasattr(self, 'action_panel_enemy_hp') and self.game.action_panel_enemy_hp:
            self._multi_flash(self.game.action_panel_enemy_hp, 0, 3)
        
        # Flash enemy sprite area multiple times
        if hasattr(self.game, 'enemy_sprite_area') and self.game.enemy_sprite_area:
            self._multi_flash_frame(self.game.enemy_sprite_area, 0, 3)
        
        # Flash enemy sprite label
        if hasattr(self.game, 'enemy_sprite_label') and self.game.enemy_sprite_label:
            try:
                self._multi_flash_label(self.game.enemy_sprite_label, 0, 3)
            except:
                pass
        
        # Intense shake animation
        if hasattr(self.game, 'enemy_sprite_area') and self.game.enemy_sprite_area:
            # Use very high damage value for intense defeat shake
            self._shake_widget(self.game.enemy_sprite_area, 0, 100)
    


    # ======================================================================
    # _multi_flash
    # ======================================================================
    def _multi_flash(self, widget, flash_count, max_flashes):
        """Flash a canvas widget multiple times"""
        if flash_count >= max_flashes:
            return
        
        original_bg = widget.cget('bg')
        widget.config(bg='#ff0000')
        self.game.root.after(150, lambda: widget.config(bg=original_bg))
        self.game.root.after(300, lambda: self._multi_flash(widget, flash_count + 1, max_flashes))
    


    # ======================================================================
    # _multi_flash_frame
    # ======================================================================
    def _multi_flash_frame(self, widget, flash_count, max_flashes):
        """Flash a frame widget multiple times"""
        if flash_count >= max_flashes:
            return
        
        original_bg = widget.cget('bg')
        widget.config(bg='#ff0000')
        self.game.root.after(150, lambda: widget.config(bg=original_bg))
        self.game.root.after(300, lambda: self._multi_flash_frame(widget, flash_count + 1, max_flashes))
    


    # ======================================================================
    # _multi_flash_label
    # ======================================================================
    def _multi_flash_label(self, widget, flash_count, max_flashes):
        """Flash a label widget multiple times"""
        if flash_count >= max_flashes:
            return
        
        original_bg = widget.cget('bg')
        widget.config(bg='#ff3333')
        self.game.root.after(150, lambda: widget.config(bg=original_bg))
        self.game.root.after(300, lambda: self._multi_flash_label(widget, flash_count + 1, max_flashes))
    


    # ======================================================================
    # _fade_out_enemy
    # ======================================================================
    def _fade_out_enemy(self, target_index, frames_remaining):
        """Fade out and shrink enemy sprite area before removal"""
        if frames_remaining <= 0:
            # Animation complete - remove enemy
            self.game.enemies.pop(target_index)
            if self.game.current_enemy_index >= len(self.game.enemies):
                self.game.current_enemy_index = max(0, len(self.game.enemies) - 1)
            
            if len(self.game.enemies) == 0:
                # All enemies defeated
                self.game.combat_state = "idle"
                self.enemy_defeated()
            else:
                # More enemies remain
                self.update_enemy_display()
                # Proceed to enemy turn after delay
                self.game.root.after(1000, self._start_enemy_turn_sequence)
            return
        
        # Fade effect: gradually darken the background
        if hasattr(self.game, 'enemy_sprite_area') and self.game.enemy_sprite_area:
            # Calculate fade color (from current to black)
            fade_percent = frames_remaining / 10.0
            # Darken from dark red to black
            r = int(26 * fade_percent)  # From #1a to #00
            g = int(20 * fade_percent)  # From #14 to #00  
            b = int(16 * fade_percent)  # From #10 to #00
            fade_color = f"#{r:02x}{g:02x}{b:02x}"
            self.game.enemy_sprite_area.config(bg=fade_color)
        
        # Continue fading
        self.game.root.after(70, lambda: self._fade_out_enemy(target_index, frames_remaining - 1))
    


    # ======================================================================
    # _flash_enemy_hp
    # ======================================================================
    def _flash_enemy_hp(self, damage=0):
        """Flash enemy sprite area and sprite box to show damage taken with shake animation"""
        # Flash enemy sprite area
        if hasattr(self.game, 'enemy_sprite_area') and self.game.enemy_sprite_area:
            original_bg = self.game.enemy_sprite_area.cget('bg')
            self.game.enemy_sprite_area.config(bg='#ff0000')
            self.game.enemy_sprite_area.update()
            # Restore color and clear flash flag after delay
            def restore_color():
                if hasattr(self.game, 'enemy_sprite_area'):
                    self.game.enemy_sprite_area.config(bg=original_bg)
                if hasattr(self, '_is_flashing'):
                    self.game._is_flashing = False
            self.game.root.after(700, restore_color)
        
        # Flash enemy sprite label
        if hasattr(self.game, 'enemy_sprite_label') and self.game.enemy_sprite_label:
            try:
                original_bg = self.game.enemy_sprite_label.cget('bg')
                # Set label to bright red too (was #ff3333, now same as frame)
                self.game.enemy_sprite_label.config(bg='#ff0000')
                self.game.enemy_sprite_label.update()
                self.game.root.after(700, lambda: self.game.enemy_sprite_label.config(bg=original_bg) if hasattr(self.game, 'enemy_sprite_label') else None)
            except:
                pass
        
        # Force root update to show color changes immediately
        self.game.root.update_idletasks()
        
        # Shake animation for enemy sprite area with intensity based on damage
        if hasattr(self.game, 'enemy_sprite_area') and self.game.enemy_sprite_area:
            self._shake_widget(self.game.enemy_sprite_area, 0, damage)
    


    # ======================================================================
    # _flash_player_hp
    # ======================================================================
    def _flash_player_hp(self, damage=0):
        """Flash player sprite box and sprite label to show damage taken with shake animation"""
        # Don't flash HP bar - only flash sprite box
        
        # Flash player sprite box
        if hasattr(self.game, 'player_sprite_box') and self.game.player_sprite_box:
            original_bg = self.game.player_sprite_box.cget('bg')
            self.game.player_sprite_box.config(bg='#ff0000')
            self.game.player_sprite_box.update()
            self.game.root.after(700, lambda: self.game.player_sprite_box.config(bg=original_bg) if hasattr(self.game, 'player_sprite_box') else None)
        
        # Flash player sprite label - use same bright red as box for more visibility
        if hasattr(self.game, 'player_sprite_label') and self.game.player_sprite_label:
            try:
                original_bg = self.game.player_sprite_label.cget('bg')
                self.game.player_sprite_label.config(bg='#ff0000')
                self.game.player_sprite_label.update()
                self.game.root.after(700, lambda: self.game.player_sprite_label.config(bg=original_bg) if hasattr(self.game, 'player_sprite_label') else None)
            except:
                pass
        
        # Force root update to show color changes immediately
        self.game.root.update_idletasks()
        
        # Shake animation for player sprite box with intensity based on damage
        if hasattr(self.game, 'player_sprite_box') and self.game.player_sprite_box:
            self._shake_widget(self.game.player_sprite_box, 0, damage)
    


    # ======================================================================
    # _shake_widget
    # ======================================================================
    def _shake_widget(self, widget, frame, damage):
        """Shake a widget back and forth to show impact - intensity scales with damage"""
        # Check if widget still exists
        if not widget or not widget.winfo_exists():
            return
        
        # Calculate shake intensity based on damage
        if damage <= 10:
            max_frames = 4
            offset_magnitude = 3
        elif damage <= 20:
            max_frames = 6
            offset_magnitude = 5
        elif damage <= 30:
            max_frames = 8
            offset_magnitude = 7
        else:
            max_frames = 10
            offset_magnitude = 9
        
        if frame >= max_frames:
            return
        
        # Alternate shake direction
        offset = offset_magnitude if frame % 2 == 0 else -offset_magnitude
        
        # Apply shake by adjusting pady
        try:
            current_pady = widget.pack_info().get('pady', (4, 0))
            if isinstance(current_pady, tuple):
                base_pady = current_pady[0] if isinstance(current_pady[0], int) else 4
            else:
                base_pady = current_pady if isinstance(current_pady, int) else 4
            
            widget.pack_configure(pady=(base_pady + offset, 0))
        except:
            return
        
        # Schedule next frame
        self.game.root.after(30, lambda: self._shake_widget(widget, frame + 1, damage))
    


    # ======================================================================
    # _start_enemy_turn_sequence
    # ======================================================================
    def _start_enemy_turn_sequence(self):
        """Begin enemy turn - announce and execute enemy actions"""
        self.game.combat_state = "enemy_turn"  # Prevent player from rolling during enemy turn
        
        # Disable roll button during enemy turn
        if hasattr(self, 'current_roll_button'):
            self.game.current_roll_button.config(state=tk.DISABLED, bg='#666666')
        
        # Increment turn counter
        self.game.combat_turn_count += 1
        
        # Apply burn damage to enemies
        enemies_died_from_burn = self._apply_burn_damage()
        
        # If enemies died from burn, handle their deaths and check if combat ends
        if enemies_died_from_burn:
            # Wait a moment for burn message to be read, then check for dead enemies
            self.game.root.after(1000, self._check_burn_deaths)
            return
        
        # Apply poison damage
        if hasattr(self, 'combat_poison_damage') and self.game.combat_poison_damage > 0:
            if not self.game.dev_invincible:
                # Log poison message FIRST
                self.game.log(f"☠ Poison damage! You lose {self.game.combat_poison_damage} HP.", 'enemy')
                # Wait for message, then apply damage and animate
                def apply_poison():
                    self.game.health -= self.game.combat_poison_damage
                    self.game.update_display()
                    self._animate_player_damage(self.game.combat_poison_damage)
                self.game.root.after(700, apply_poison)
                self.game.root.after(2400, self.game._check_poison_death)  # Check death after animation
                return
            else:
                self.game.log(f"☠ Poison damage blocked by God Mode!", 'system')
        
        # Check for spawning
        self.check_spawn_conditions()
        
        # Announce enemy is preparing to attack
        self.game.root.after(1000, self._announce_enemy_attack)
    


    # ======================================================================
    # _apply_burn_damage
    # ======================================================================
    def _apply_burn_damage(self):
        """Apply burn damage to all burning enemies and reduce turn count"""
        if not self.game.enemy_burn_status:
            return False  # No burn damage applied
        
        enemies_died = []
        enemies_to_remove = []
        
        for i, enemy in enumerate(self.game.enemies):
            if i in self.game.enemy_burn_status:
                burn_info = self.game.enemy_burn_status[i]
                initial_damage = burn_info['initial_damage']
                turns_remaining = burn_info['turns_remaining']
                
                # Fixed burn damage sequence: Turn 1: 8, Turn 2: 5, Turn 3: 2
                if turns_remaining == 3:
                    damage = 8
                elif turns_remaining == 2:
                    damage = 5
                elif turns_remaining == 1:
                    damage = 2
                else:
                    damage = 0
                
                # Apply damage to enemy
                enemy['health'] -= damage
                self.game.log(f"🔥 {enemy['name']} takes {damage} burn damage! ({turns_remaining} turns remaining)", 'fire')
                
                # Animate damage if this is the currently targeted enemy
                if i == self.game.current_enemy_index:
                    self._animate_enemy_damage(damage)
                
                # Reduce turns
                burn_info['turns_remaining'] -= 1
                
                # Remove burn status if no turns left
                if burn_info['turns_remaining'] <= 0:
                    enemies_to_remove.append(i)
                    self.game.log(f"🔥 {enemy['name']}'s burn fades away.", 'system')
                
                # Check if enemy died from burn
                if enemy['health'] <= 0:
                    self.game.log(f"💀 {enemy['name']} burned to death!", 'combat')
                    enemies_died.append(i)
        
        # Clean up expired burn statuses
        for i in enemies_to_remove:
            del self.game.enemy_burn_status[i]
        
        # Update display after burn damage
        self.game.update_display()
        
        # Return True if any enemies died from burn
        return len(enemies_died) > 0
    


    # ======================================================================
    # _check_burn_deaths
    # ======================================================================
    def _check_burn_deaths(self):
        """Check if any enemies died from burn damage and handle their deaths"""
        # Remove dead enemies and trigger defeat animations
        dead_enemies = [i for i, enemy in enumerate(self.game.enemies) if enemy['health'] <= 0]
        
        if dead_enemies:
            # Play defeat animation for first dead enemy
            self._play_enemy_defeat_animation(dead_enemies[0])
            # Note: _play_enemy_defeat_animation will call _remove_dead_enemy which handles
            # checking if combat should end or continue to next enemy turn
        else:
            # No enemies actually dead (shouldn't happen), continue to enemy turn
            self._continue_after_burn_check()
    


    def _continue_after_burn_check(self):
        """Continue to enemy turn after burn damage check"""
        # Check for spawning
        self.check_spawn_conditions()
        
        # Announce enemy is preparing to attack
        self.game.root.after(500, self._announce_enemy_attack)
    


    # ======================================================================
    # _check_poison_death
    # ======================================================================
    def _check_poison_death(self):
        """Check if player died from poison, otherwise continue to enemy turn"""
        if self.game.health <= 0 and not self.game.dev_invincible:
            self.game.game_over()
        else:
            self._announce_enemy_attack()
    


    # ======================================================================
    # _announce_enemy_attack
    # ======================================================================
    def _announce_enemy_attack(self):
        """Announce enemy is attacking and roll dice with animation"""
        # Roll enemy dice
        self.game.enemy_roll_results = []
        
        if len(self.game.enemies) > 0:
            # For multiple enemies, show dice for first enemy only (for now)
            first_enemy = self.game.enemies[0]
            num_dice = first_enemy["num_dice"]
            enemy_dice = [random.randint(1, 6) for _ in range(num_dice)]
            
            # Animate enemy dice roll
            self._show_and_animate_enemy_dice(enemy_dice, num_dice)
            
            # Store all enemy rolls
            for enemy in self.game.enemies:
                if enemy == first_enemy:
                    self.game.enemy_roll_results.append({
                        'name': enemy['name'],
                        'dice': enemy_dice,
                        'enemy_ref': enemy
                    })
                else:
                    # Other enemies roll but aren't animated
                    other_dice = [random.randint(1, 6) for _ in range(enemy["num_dice"])]
                    self.game.enemy_roll_results.append({
                        'name': enemy['name'],
                        'dice': other_dice,
                        'enemy_ref': enemy
                    })
        else:
            # Fallback single enemy
            num_dice = self.game.enemy_num_dice
            enemy_dice = [random.randint(1, 6) for _ in range(num_dice)]
            
            self._show_and_animate_enemy_dice(enemy_dice, num_dice)
            
            self.game.enemy_roll_results.append({
                'name': self.game.enemy_name,
                'dice': enemy_dice,
                'enemy_ref': None
            })
        
        # After showing rolls, announce attacks one enemy at a time
        self.game.root.after(700, lambda: self._announce_enemy_attacks_sequentially(0))
    


    # ======================================================================
    # _show_and_animate_enemy_dice
    # ======================================================================
    def _show_and_animate_enemy_dice(self, final_values, num_dice):
        """Show and animate enemy dice rolling"""
        # Always recreate enemy dice display to handle different dice counts
        for widget in self.game.enemy_dice_frame.winfo_children():
            widget.destroy()
        
        self.game.enemy_dice_canvases = []
        self.game.enemy_dice_values = [0] * len(final_values)
        
        # Create dice in a 2x2 grid layout for better visibility
        # Row 1
        row1 = tk.Frame(self.game.enemy_dice_frame, bg=self.game.current_colors["bg_panel"])
        row1.pack(side=tk.TOP)
        
        # Row 2
        row2 = tk.Frame(self.game.enemy_dice_frame, bg=self.game.current_colors["bg_panel"])
        row2.pack(side=tk.TOP)
        
        # Create canvases for each die value
        for i in range(len(final_values)):
            # Alternate between row1 and row2 (2 dice per row)
            parent = row1 if i < 2 else row2
            canvas = tk.Canvas(parent, width=28, height=28, 
                             bg=self.game.current_colors["bg_panel"], highlightthickness=0)
            canvas.pack(side=tk.LEFT, padx=1, pady=1)
            self.game.enemy_dice_canvases.append(canvas)
        
        # Show enemy dice frame - it's already packed, just make it visible
        self.game.enemy_dice_frame.pack(side=tk.RIGHT, padx=(0, 4))
        
        # Start animation
        self._animate_enemy_dice_roll(final_values, 0, 8)
    


    # ======================================================================
    # _animate_enemy_dice_roll
    # ======================================================================
    def _animate_enemy_dice_roll(self, final_values, frame, max_frames):
        """Animate enemy dice rolling through random numbers"""
        if frame < max_frames:
            # Show random values during animation
            for i, canvas in enumerate(self.game.enemy_dice_canvases):
                if i < len(final_values):
                    self.game.enemy_dice_values[i] = random.randint(1, 6)
                    self._render_enemy_die(canvas, self.game.enemy_dice_values[i])
            
            # Schedule next frame (25ms delay for smooth animation)
            self.game.root.after(25, lambda: self._animate_enemy_dice_roll(final_values, frame + 1, max_frames))
        else:
            # Animation complete - set final values and log
            self.game.enemy_dice_values = final_values[:]
            for i, canvas in enumerate(self.game.enemy_dice_canvases):
                if i < len(final_values):
                    self._render_enemy_die(canvas, final_values[i])
            
            # Log the roll result
            enemy_name = self.game.enemies[0]['name'] if self.game.enemies else self.game.enemy_name
            dice_str = ", ".join(str(d) for d in final_values)
            self.game.log(f"{enemy_name} rolls: [{dice_str}]", 'enemy')
    


    # ======================================================================
    # _render_enemy_die
    # ======================================================================
    def _render_enemy_die(self, canvas, value):
        """Render a single enemy die on canvas (smaller, red-tinted)"""
        canvas.delete("all")
        
        # Enemy dice style - dark red theme
        bg_color = "#4a0000"  # Dark red
        border_color = "#8b0000"  # Medium red
        pip_color = "#ffffff"  # White pips
        
        # Draw die background (28x28 canvas)
        canvas.create_rectangle(1, 1, 27, 27, fill=bg_color, outline=border_color, width=2)
        
        # Draw pips based on value (scaled for 28x28 canvas)
        size = 28
        margin = 7
        center = size // 2
        pip_radius = 2
        
        positions = {
            1: [(center, center)],
            2: [(margin, margin), (size - margin, size - margin)],
            3: [(margin, margin), (center, center), (size - margin, size - margin)],
            4: [(margin, margin), (margin, size - margin), 
                (size - margin, margin), (size - margin, size - margin)],
            5: [(margin, margin), (margin, size - margin),
                (center, center),
                (size - margin, margin), (size - margin, size - margin)],
            6: [(margin, margin), (margin, center), (margin, size - margin),
                (size - margin, margin), (size - margin, center), (size - margin, size - margin)]
        }
        
        pips = positions.get(value, [(center, center)])
        for x, y in pips:
            canvas.create_oval(
                x - pip_radius, y - pip_radius,
                x + pip_radius, y + pip_radius,
                fill=pip_color,
                outline=pip_color
            )
    


    # ======================================================================
    # _announce_enemy_attacks_sequentially
    # ======================================================================
    def _announce_enemy_attacks_sequentially(self, enemy_index):
        """Announce each enemy's roll and attack one at a time for clarity"""
        if enemy_index >= len(self.game.enemy_roll_results):
            # All enemies announced, now calculate total damage
            self._calculate_total_enemy_damage()
            return
        
        roll_result = self.game.enemy_roll_results[enemy_index]
        enemy_name = roll_result['name']
        enemy_dice = roll_result['dice']
        
        # Log the dice roll (skip first enemy since it was already logged during animation)
        if enemy_index > 0:
            dice_str = ", ".join(str(d) for d in enemy_dice)
            self.game.log(f"{enemy_name} rolls: [{dice_str}]", 'enemy')
        
        # Calculate damage for this enemy
        enemy = roll_result.get('enemy_ref')
        if enemy:
            enemy_damage = sum(enemy_dice) + (self.game.floor * 2)
            
            # Apply all multipliers
            difficulty = self.game.settings.get("difficulty", "Normal")
            total_mult = self.game.difficulty_multipliers[difficulty]["enemy_damage_mult"]
            total_mult *= self.game.difficulty_multipliers[difficulty]["player_damage_taken_mult"]
            total_mult *= 0.95
            
            if self.game.floor <= 3:
                total_mult *= 1.15
            
            enemy_damage = int(enemy_damage * total_mult)
            
            if hasattr(self.game, 'combat_enemy_damage_boost') and self.game.combat_enemy_damage_boost > 0:
                enemy_damage += int(enemy_damage * self.game.combat_enemy_damage_boost)
        else:
            # Fallback for single enemy
            enemy_damage = sum(enemy_dice) + (self.game.floor * 2)
            difficulty = self.game.settings.get("difficulty", "Normal")
            mult1 = self.game.difficulty_multipliers[difficulty]["enemy_damage_mult"]
            mult2 = self.game.difficulty_multipliers[difficulty]["player_damage_taken_mult"]
            mult3 = 1.15 if self.game.floor <= 3 else 1.0
            total_mult = mult1 * mult2 * 0.95 * mult3
            enemy_damage = int(enemy_damage * total_mult)
            
            if hasattr(self.game, 'combat_enemy_damage_boost') and self.game.combat_enemy_damage_boost > 0:
                enemy_damage += int(enemy_damage * self.game.combat_enemy_damage_boost)
        
        # Store this enemy's damage
        roll_result['damage'] = enemy_damage
        
        # Log attack announcement
        self.game.log(f"⚔️ {enemy_name} attacks for {enemy_damage} damage!", 'enemy')
        
        # Wait before announcing next enemy (500ms delay between enemies)
        self.game.root.after(500, lambda: self._announce_enemy_attacks_sequentially(enemy_index + 1))
    

    # ======================================================================
    # _calculate_total_enemy_damage
    # ======================================================================
    def _calculate_total_enemy_damage(self):
        """Calculate total damage from all enemies after individual announcements"""
        total_damage = sum(roll_result.get('damage', 0) for roll_result in self.game.enemy_roll_results)
        
        # Store for later application
        self._pending_enemy_damage = total_damage
        
        # Wait for final attack message to display, then check armor
        self.game.root.after(500, self._apply_armor_and_announce_final_damage)
    


    # ======================================================================
    # _apply_armor_and_announce_final_damage
    # ======================================================================
    def _apply_armor_and_announce_final_damage(self):
        """Apply armor reduction and announce final damage player will take"""
        total_damage = self._pending_enemy_damage
        
        # Apply shield absorption FIRST
        if hasattr(self.game, 'temp_shield') and self.game.temp_shield > 0:
            shield_absorbed = min(self.game.temp_shield, total_damage)
            self.game.temp_shield -= shield_absorbed
            total_damage -= shield_absorbed
            
            self.game.log(f"Your shield absorbs {shield_absorbed} damage! (Shield: {self.game.temp_shield} remaining)", 'success')
        
        # Apply armor reduction
        if self.game.armor > 0 and total_damage > 0:
            armor_reduction = min(self.game.armor * 0.15, 0.60)
            reduced_damage = int(total_damage * (1 - armor_reduction))
            damage_blocked = total_damage - reduced_damage
            total_damage = reduced_damage
            
            # Announce armor blocking
            self.game.log(f"Your armor blocks {damage_blocked} damage!", 'success')
            
            # Damage armor durability
            self.game._damage_equipment_durability("armor", 5)
        
        # Store final damage
        self._pending_enemy_damage = total_damage
        
        # Announce final damage taken
        if total_damage > 0:
            self.game.log(f"You take {total_damage} damage!", 'enemy')
        else:
            self.game.log("All damage blocked!", 'success')
        
        # Wait for damage message to display, then apply and animate
        self.game.root.after(700, self._apply_enemy_damage_and_animate)
    


    # ======================================================================
    # _apply_enemy_damage_and_animate
    # ======================================================================
    def _apply_enemy_damage_and_animate(self):
        """Apply enemy damage to player and animate (called AFTER all messages displayed)"""
        total_damage = self._pending_enemy_damage
        
        # Apply damage to player
        if not self.game.dev_invincible:
            self.game.health -= total_damage
            self.game.stats["total_damage_taken"] += total_damage
            
            # Update display
            self.game.update_display()
            
            # Animate player taking damage
            self._animate_player_damage(total_damage)
        else:
            self.game.log("[GOD MODE] Damage negated!", 'system')
        
        # After animation completes, check game state
        self.game.root.after(1800, self._check_combat_end)
    


    # ======================================================================
    # _check_combat_end
    # ======================================================================
    def _check_combat_end(self):
        """Check if player died or if combat round completes"""
        # Check if player died
        if self.game.health <= 0 and not self.game.dev_invincible:
            self.game.game_over()
            return
        
        # Show enemy taunt
        if len(self.game.enemies) > 0:
            target_index = min(self.game.current_enemy_index, len(self.game.enemies) - 1)
            if target_index < len(self.game.enemies):
                target = self.game.enemies[target_index]
                config = target.get('config', {})
                if 'taunt' in config and config['taunt']:
                    self.game.log(config['taunt'], 'enemy')
        
        # Combat round complete - start new player turn
        self._end_combat_round()
    


    # ======================================================================
    # _execute_enemy_attacks
    # ======================================================================
    def _execute_enemy_attacks(self):
        """Execute enemy attacks and apply damage (LEGACY - being replaced)"""
        total_damage = 0
        
        if len(self.game.enemies) > 0:
            for roll_result in self.game.enemy_roll_results:
                enemy = roll_result['enemy_ref']
                enemy_dice = roll_result['dice']
                enemy_base_damage = sum(enemy_dice) + (self.game.floor * 2)
                
                # Apply multipliers
                difficulty = self.game.settings.get("difficulty", "Normal")
                enemy_damage = int(enemy_base_damage * self.game.difficulty_multipliers[difficulty]["enemy_damage_mult"])
                enemy_damage = int(enemy_damage * self.game.difficulty_multipliers[difficulty]["player_damage_taken_mult"])
                enemy_damage = int(enemy_damage * self.game.dev_config["enemy_damage_mult"])
                
                # Hazard boost
                if hasattr(self, 'combat_enemy_damage_boost') and self.game.combat_enemy_damage_boost > 0:
                    hazard_bonus = int(enemy_damage * self.game.combat_enemy_damage_boost)
                    enemy_damage += hazard_bonus
                
                # Global reduction and floor boost
                enemy_damage = int(enemy_damage * 0.95)
                if self.game.floor <= 3:
                    enemy_damage = int(enemy_damage * 1.15)
                
                total_damage += enemy_damage
                self.game.log(f"⚔️ {roll_result['name']} attacks for {enemy_damage} damage!", 'enemy')
            
            # Apply armor
            if self.game.armor > 0:
                armor_reduction = min(self.game.armor * 0.15, 0.60)
                reduced_damage = int(total_damage * (1 - armor_reduction))
                damage_blocked = total_damage - reduced_damage
                total_damage = reduced_damage
                self.game.log(f"Armor blocks {damage_blocked} damage! ({int(armor_reduction*100)}% reduction)", 'success')
            
            self.game._damage_equipment_durability("armor", 5)
            
            if self.game.dev_invincible:
                self.game.log(f"⚡ GOD MODE: Blocked {total_damage} damage!", 'success')
                self.game.stats["total_damage_taken"] += total_damage
            else:
                # Log all messages first
                self.game.log(f"You take {total_damage} total damage!", 'enemy')
                
                # Calculate delay accounting for ALL messages that were just logged
                # Each enemy attack message + optional armor message + final damage message
                total_message_chars = len(self.game.enemy_roll_results) * 50  # Enemy attack messages
                if self.game.armor > 0:
                    total_message_chars += 50  # Armor block message
                total_message_chars += 40  # Final damage message
                text_delay = min(total_message_chars * 70, 1500)  # Longer max delay
                
                # Apply damage and animate AFTER messages finish displaying
                def apply_damage_and_animate():
                    self.game.health -= total_damage
                    self.game.stats["total_damage_taken"] += total_damage
                    self.game.update_display()
                    self._flash_player_hp(total_damage)
                
                self.game.root.after(text_delay, apply_damage_and_animate)
        else:
            # Fallback
            roll_result = self.game.enemy_roll_results[0]
            enemy_dice = roll_result['dice']
            enemy_damage = sum(enemy_dice) + (self.game.floor * 2)
            
            difficulty = self.game.settings.get("difficulty", "Normal")
            enemy_damage = int(enemy_damage * self.game.difficulty_multipliers[difficulty]["enemy_damage_mult"])
            enemy_damage = int(enemy_damage * self.game.difficulty_multipliers[difficulty]["player_damage_taken_mult"])
            enemy_damage = int(enemy_damage * 0.95)
            if self.game.floor <= 3:
                enemy_damage = int(enemy_damage * 1.15)
            
            if hasattr(self, 'combat_enemy_damage_boost') and self.game.combat_enemy_damage_boost > 0:
                enemy_damage += int(enemy_damage * self.game.combat_enemy_damage_boost)
            
            if self.game.armor > 0:
                armor_reduction = min(self.game.armor * 0.15, 0.60)
                reduced_damage = int(enemy_damage * (1 - armor_reduction))
                damage_blocked = enemy_damage - reduced_damage
                enemy_damage = reduced_damage
                self.game.log(f"Armor blocks {damage_blocked} damage!", 'success')
            
            self.game._damage_equipment_durability("armor", 5)
            
            # Log all messages first
            self.game.log(f"⚔️ {self.game.enemy_name} attacks for {enemy_damage} damage!", 'enemy')
            self.game.log(f"You take {enemy_damage} damage!", 'enemy')
            
            # Calculate delay for both attack and damage messages
            total_message_chars = 50  # Attack message
            if self.game.armor > 0:
                total_message_chars += 40  # Armor message
            total_message_chars += 30  # Damage message
            text_delay = min(total_message_chars * 70, 1200)
            
            # Apply damage and animate AFTER messages finish displaying
            def apply_damage_and_animate():
                self.game.health -= enemy_damage
                self.game.stats["total_damage_taken"] += enemy_damage
                self.game.update_display()
                self._flash_player_hp(enemy_damage)
            
            self.game.root.after(text_delay, apply_damage_and_animate)
        
        # Check if player died
        if self.game.health <= 0:
            self.game.game_over()
        else:
            # Show taunt
            if len(self.game.enemies) > 0:
                taunter = random.choice(self.game.enemies)
                enemy_type = taunter['name'].split()[0]
            else:
                enemy_type = self.game.enemy_name.split()[0]
            
            if enemy_type in self.game.enemy_taunts:
                self.game.log(random.choice(self.game.enemy_taunts[enemy_type]), 'enemy')
            
            # End of round - re-enable controls and start new turn
            self.game.root.after(500, self._end_combat_round)
    


    # ======================================================================
    # _end_combat_round
    # ======================================================================
    def _end_combat_round(self):
        """End combat round and prepare for next turn"""
        self.game.combat_state = "idle"
        
        # Note: No need to re-enable roll button here since start_combat_turn
        # will create a new enabled button
        
        self.game.update_display()
        self.start_combat_turn()
    


    # ======================================================================
    # _calculate_and_announce_player_damage
    # ======================================================================
    def _calculate_and_announce_player_damage(self):
        """Calculate player damage and announce it (message first, damage application later)"""
        # Store dice values before consuming them
        attack_dice = self.game.dice_values.copy()
        
        # Check for fumble
        if hasattr(self, 'combat_fumble_chance') and self.game.combat_fumble_chance > 0:
            if random.random() < self.game.combat_fumble_chance:
                non_zero_dice = [d for d in attack_dice if d > 0]
                if non_zero_dice:
                    lowest_die = min(non_zero_dice)
                    attack_dice.remove(lowest_die)
                    self.game.log(f"⚠️ You fumble! Lost a {lowest_die} from your attack.", 'enemy')
        
        # Temporarily restore dice for calculation
        self.game.dice_values = attack_dice
        damage = self.game.dice_manager.calculate_damage()
        
        # Apply difficulty multipliers
        difficulty = self.game.settings.get("difficulty", "Normal")
        damage = int(damage * self.game.difficulty_multipliers[difficulty]["player_damage_mult"])
        
        # Check for crit
        crit_chance = self.game.crit_chance
        if hasattr(self, 'combat_crit_penalty') and self.game.combat_crit_penalty > 0:
            crit_chance = max(0, crit_chance - self.game.combat_crit_penalty)
        
        is_crit = random.random() < crit_chance
        if is_crit:
            damage = int(damage * 1.5)
            self.game.stats["critical_hits"] += 1
            self.game.log(random.choice(self.game.player_crits), 'crit')
        
        # Track stats
        self.game.stats["total_damage_dealt"] += damage
        if damage > self.game.stats["highest_single_damage"]:
            self.game.stats["highest_single_damage"] = damage
        
        # Store damage for later application
        self._pending_player_damage = damage
        
        # LOG COMBINED ATTACK AND DAMAGE MESSAGE
        self.game.log(f"⚔️ You attack and deal {damage} damage!", 'player')
        
        # Wait for damage message to display, then apply damage and animate
        self.game.root.after(700, self._apply_player_damage_and_animate)
    


    # ======================================================================
    # _apply_player_damage_and_animate
    # ======================================================================
    def _apply_player_damage_and_animate(self):
        """Apply player damage to enemy and trigger animations (called AFTER damage message displayed)"""
        damage = self._pending_player_damage
        
        # NOW consume the dice (visual update)
        self.game.dice_values = [0] * self.game.num_dice
        self.game.dice_locked = [False] * self.game.num_dice
        self.game.dice_manager.update_dice_display()
        
        # Damage weapon durability
        self.game._damage_equipment_durability("weapon", 3)
        
        # Set flag to prevent display update from resetting flash colors
        self.game._is_flashing = True
        
        # Apply damage to enemy
        if len(self.game.enemies) > 0:
            target_index = min(self.game.current_enemy_index, len(self.game.enemies) - 1)
            target = self.game.enemies[target_index]
            
            target["health"] -= damage
            self.game.enemy_health = target["health"]
            
            # Update display to show new HP
            self.game.update_display()
            
            # Check if enemy will die from this damage
            if target["health"] <= 0:
                # Skip damage animation, go straight to death check
                self.game.root.after(100, lambda: self._check_enemy_status_after_damage(target, damage))
            else:
                # Enemy survives - play damage animation
                self._animate_enemy_damage(damage)
                # Check what happens next after animation completes
                # Animation takes roughly: flash (700ms) + brief pause
                self.game.root.after(1800, lambda: self._check_enemy_status_after_damage(target, damage))
        else:
            # No enemy (shouldn't happen, but handle gracefully)
            self._check_enemy_status_after_damage(None, damage)
    


    # ======================================================================
    # _check_enemy_status_after_damage
    # ======================================================================
    def _check_enemy_status_after_damage(self, target, damage):
        """Check if enemy died or if combat continues to enemy turn"""
        if target is None or len(self.game.enemies) == 0:
            # Edge case: no enemy, end combat
            self.game.combat_state = "idle"
            return
        
        # Check if enemy splits before dying
        if target["health"] > 0:
            self.check_split_conditions(target)
        
        # Check if enemy is dead
        if target["health"] <= 0:
            # Enemy defeated - handle death logic
            config = target.get("config", {})
            if config.get("splits_on_death", False) and not target.get("has_split", False):
                self.split_enemy(
                    target,
                    config.get("split_into_type", "Shard"),
                    config.get("split_count", 2),
                    config.get("split_hp_percent", 0.5),
                    config.get("split_dice", -1)
                )
                self.update_enemy_display()
                # Combat continues with new enemies
                self.game.root.after(1000, self._start_enemy_turn_sequence)
            else:
                # Enemy truly defeated
                self._handle_enemy_defeat(target)
        else:
            # Enemy survived, proceed to enemy turn
            self.game.root.after(300, self._start_enemy_turn_sequence)
    


    # ======================================================================
    # _handle_enemy_defeat
    # ======================================================================
    def _handle_enemy_defeat(self, target):
        """Handle enemy defeat with animation"""
        # Check if this is Acid Hydra - play sprite death animation
        enemy_name = target.get('name', '')
        
        if 'Acid Hydra' in enemy_name:
            # Play PixelLab death animation (7 frames at 60ms each = 420ms)
            self._play_enemy_death_animation('acid_hydra', 'falling-back-death', 'south', 7, 60)
            # Wait for animation to complete, then finalize defeat
            self.game.root.after(900, lambda: self._finalize_enemy_defeat(target))
        else:
            # Fallback: Animate enemy defeat (big shake with high damage value)
            self._animate_enemy_damage(100)  # Max damage for dramatic effect
            # After defeat animation, proceed with defeat logic
            self.game.root.after(1600, lambda: self._finalize_enemy_defeat(target))
    


    # ======================================================================
    # _finalize_enemy_defeat
    # ======================================================================
    def _finalize_enemy_defeat(self, target):
        """Complete enemy defeat sequence"""
        self.game.log(f"{target['name']} has been defeated!", 'success')
        
        # Remove from enemies list
        if target in self.game.enemies:
            self.game.enemies.remove(target)
        
        # If no more enemies, combat ends
        if len(self.game.enemies) == 0:
            self.game.root.after(400, self.game.enemy_defeated)
        else:
            # More enemies remain
            if self.game.current_enemy_index >= len(self.game.enemies):
                self.game.current_enemy_index = 0
            self.update_enemy_display()
            self.game.root.after(1000, self._start_enemy_turn_sequence)
    


    # ======================================================================
    # _animate_player_damage
    # ======================================================================
    def _animate_player_damage(self, damage):
        """Trigger player damage animation (shake and flash)"""
        self._flash_player_hp(damage)
    


    # ======================================================================
    # _execute_player_attack
    # ======================================================================
    def _execute_player_attack(self):
        """Execute player attack damage calculation and application"""
        # Consume dice
        attack_dice = self.game.dice_values.copy()
        self.game.dice_values = [0] * self.game.num_dice
        self.game.dice_locked = [False] * self.game.num_dice
        self.game.dice_manager.update_dice_display()
        
        # Check for fumble
        if hasattr(self, 'combat_fumble_chance') and self.game.combat_fumble_chance > 0:
            if random.random() < self.game.combat_fumble_chance:
                non_zero_dice = [d for d in attack_dice if d > 0]
                if non_zero_dice:
                    lowest_die = min(non_zero_dice)
                    attack_dice.remove(lowest_die)
                    self.game.log(f"⚠️ You fumble! Lost a {lowest_die} from your attack.", 'enemy')
        
        # Restore dice for calculation
        self.game.dice_values = attack_dice
        
        # Calculate damage with combo logging
        damage = self.game.dice_manager.calculate_damage()
        
        # Apply modifiers
        difficulty = self.game.settings.get("difficulty", "Normal")
        damage = int(damage * self.game.difficulty_multipliers[difficulty]["player_damage_mult"])
        damage = int(damage * self.game.dev_config["player_damage_mult"])
        
        # Check for crit
        crit_chance = self.game.crit_chance
        if hasattr(self, 'combat_crit_penalty') and self.game.combat_crit_penalty > 0:
            crit_chance = max(0, crit_chance - self.game.combat_crit_penalty)
        
        is_crit = random.random() < crit_chance
        if is_crit:
            damage = int(damage * 1.5)
            self.game.stats["critical_hits"] += 1
            self.game.log(random.choice(self.game.player_crits), 'crit')
        
        # Track stats
        self.game.stats["total_damage_dealt"] += damage
        if damage > self.game.stats["highest_single_damage"]:
            self.game.stats["highest_single_damage"] = damage
        
        # Log damage dealt
        self.game.log(f"[HIT] You deal {damage} damage!", 'player')
        
        # Calculate delay for message to display (typewriter effect)
        text_delay = min(len(f"[HIT] You deal {damage} damage!") * 70, 700)
        
        # Apply damage and animate after message displays
        self.game.root.after(text_delay, lambda: self._apply_player_damage(damage))
    

