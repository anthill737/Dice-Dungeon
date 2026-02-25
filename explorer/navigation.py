"""
Navigation Manager

Handles all room navigation and exploration logic including:
- Room movement and direction exploration
- Room entry with key validation (boss/mini-boss rooms)
- Floor transitions and initialization
- Exploration UI and ground loot generation
- Special room spawning (boss, mini-boss, stairs, store)
"""

import tkinter as tk
from tkinter import messagebox

# Import content engine functions
try:
    import sys
    import os
    from explorer.path_utils import get_base_dir
    sys.path.insert(0, get_base_dir())
    from dice_dungeon_content.engine.integration_hooks import (
        apply_on_enter, on_floor_transition, apply_effective_modifiers
    )
    from dice_dungeon_content.engine.rooms_loader import pick_room_for_floor
    from explorer.rooms import Room
except ImportError:
    # Fallback if content engine unavailable
    def apply_on_enter(game, room_data, log_func): pass
    def on_floor_transition(game): pass
    def apply_effective_modifiers(game): pass
    def pick_room_for_floor(rooms, floor, rng=None): return {}
    class Room: pass


class NavigationManager:
    """Manages room navigation, exploration, and floor transitions"""
    
    def __init__(self, game):
        """Initialize with reference to main game instance"""
        self.game = game
    
    def explore_direction(self, direction):
        """Move in a direction"""
        # Don't allow movement while typewriter is active
        if hasattr(self.game, 'typewriter_active') and self.game.typewriter_active:
            return
        
        # Don't allow movement during combat or interactions
        if getattr(self.game, 'in_combat', False) or getattr(self.game, 'in_interaction', False):
            return
        
        # Reset environmental hazard penalties when leaving a room
        self.game.combat_accuracy_penalty = 0.0
        if hasattr(self.game, 'combat_crit_penalty'):
            self.game.combat_crit_penalty = 0
        if hasattr(self.game, 'combat_fumble_chance'):
            self.game.combat_fumble_chance = 0
        if hasattr(self.game, 'combat_enemy_damage_boost'):
            self.game.combat_enemy_damage_boost = 0
        if hasattr(self.game, 'combat_poison_damage'):
            self.game.combat_poison_damage = 0
        
        # Check if direction is blocked from current room
        if direction in self.game.current_room.blocked_exits:
            self.game.log("That path is blocked!", 'system')
            return
        
        # Also check traditional exits system
        if not self.game.current_room.exits.get(direction, True):
            self.game.log("That direction is blocked!", 'system')
            return
        
        new_pos = self.get_adjacent_pos(direction)
        
        # Check if trying to enter through a blocked exit from the other side
        opposite = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}
        if new_pos in self.game.dungeon:
            destination_room = self.game.dungeon[new_pos]
            if opposite[direction] in destination_room.blocked_exits:
                self.game.log("That path is blocked from the other side!", 'system')
                return
        
        # CRITICAL: Check if there's a locked room blocking this direction
        # This prevents players from creating rooms beyond locked rooms
        if new_pos in self.game.special_rooms and new_pos not in self.game.unlocked_rooms:
            room_type = self.game.special_rooms[new_pos]
            
            if room_type == 'mini_boss':
                if "Old Key" not in self.game.inventory:
                    self.game.log("⚡ A locked door blocks your path!", 'enemy')
                    self.game.log("You need an Old Key to proceed.", 'enemy')
                    return
            elif room_type == 'boss':
                fragments_have = getattr(self.game, 'key_fragments_collected', 0)
                if fragments_have < 3:
                    self.game.log("☠ A sealed boss door blocks your path!", 'enemy')
                    self.game.log(f"You need 3 key fragments. You have {fragments_have}.", 'enemy')
                    return
        
        # Check if already explored
        if new_pos in self.game.dungeon:
            existing_room = self.game.dungeon[new_pos]
            
            # Restore special room flags if this is a locked special room
            if new_pos in self.game.special_rooms and new_pos not in self.game.unlocked_rooms:
                room_type = self.game.special_rooms[new_pos]
                if room_type == 'mini_boss':
                    existing_room.is_mini_boss_room = True
                elif room_type == 'boss':
                    existing_room.is_boss_room = True
            
            # Don't update position yet - enter_room will do it after key validation
            self.enter_room(existing_room, new_pos=new_pos)
            return
        
        # Increment rooms explored
        self.game.rooms_explored_on_floor += 1
        
        # Determine if this should be a special room (boss or mini-boss)
        should_be_mini_boss = False
        should_be_boss = False
        
        # Mini-boss spawn logic: spawn at random intervals (8-12 rooms), max 3 per floor
        if self.game.mini_bosses_spawned_this_floor < 3 and self.game.rooms_explored_on_floor >= self.game.next_mini_boss_at:
            should_be_mini_boss = True
            self.game.mini_bosses_spawned_this_floor += 1
            # Set next mini-boss target for the next one (will be used after current one is defeated)
            self.game.next_mini_boss_at = self.game.rooms_explored_on_floor + self.game.rng.randint(6, 10)
        
        # Boss spawn logic: 
        # - Boss spawns 5-8 rooms after defeating all 3 mini-bosses
        # - next_boss_at is set when the 3rd mini-boss is defeated
        # - Only spawn ONE boss per floor
        if not self.game.boss_spawned_this_floor:
            # Check if we have a boss spawn target set and reached it
            if self.game.next_boss_at is not None and self.game.rooms_explored_on_floor >= self.game.next_boss_at:
                should_be_boss = True
                self.game.boss_spawned_this_floor = True
        
        # Select appropriate room based on special room determination
        if should_be_boss:
            # Force Boss difficulty room
            boss_rooms = [r for r in self.game._rooms if r.get('difficulty') == 'Boss']
            if boss_rooms:
                room_data = self.game.rng.choice(boss_rooms)
            else:
                room_data = pick_room_for_floor(self.game._rooms, self.game.floor, rng=self.game.rng)
        elif should_be_mini_boss:
            # Force Elite difficulty room for mini-boss
            elite_rooms = [r for r in self.game._rooms if r.get('difficulty') == 'Elite']
            if elite_rooms:
                room_data = self.game.rng.choice(elite_rooms)
            else:
                room_data = pick_room_for_floor(self.game._rooms, self.game.floor, rng=self.game.rng)
        else:
            # Normal room selection
            room_data = pick_room_for_floor(self.game._rooms, self.game.floor, rng=self.game.rng)
        
        new_room = Room(room_data, new_pos[0], new_pos[1])
        
        # Randomly block some exits (30% chance per direction)
        for dir in ['N', 'S', 'E', 'W']:
            if self.game.rng.random() < 0.3:
                new_room.exits[dir] = False
                new_room.blocked_exits.append(dir)
        
        # Ensure we can go back
        opposite = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}
        new_room.exits[opposite[direction]] = True
        if opposite[direction] in new_room.blocked_exits:
            new_room.blocked_exits.remove(opposite[direction])
        
        # Ensure at least 1 other exit (besides the one we came from)
        other_exits = [d for d in ['N', 'S', 'E', 'W'] if d != opposite[direction]]
        open_other = [d for d in other_exits if new_room.exits[d]]
        if len(open_other) == 0:
            # Force open one random direction
            to_open = self.game.rng.choice(other_exits)
            new_room.exits[to_open] = True
            if to_open in new_room.blocked_exits:
                new_room.blocked_exits.remove(to_open)
        
        self.game.dungeon[new_pos] = new_room
        
        # Mark room as special based on our spawn logic or room data
        if should_be_boss or room_data.get('difficulty') == 'Boss' or 'boss' in room_data.get('tags', []):
            new_room.is_boss_room = True
            self.game.special_rooms[new_pos] = 'boss'
            new_room.has_combat = True  # Boss rooms always have combat
        elif should_be_mini_boss or room_data.get('difficulty') == 'Elite':
            # Elite rooms have a chance to be mini-bosses
            new_room.is_mini_boss_room = True
            self.game.special_rooms[new_pos] = 'mini_boss'
            new_room.has_combat = True  # Mini-boss rooms always have combat
        else:
            # Normal rooms: 40% chance of combat (decided once at creation)
            threats = room_data.get('threats', [])
            has_combat_tag = 'combat' in room_data.get('tags', [])
            if threats or has_combat_tag:
                new_room.has_combat = self.game.rng.random() < 0.4
            else:
                new_room.has_combat = False
        
        # Enter new room - will set current_pos if entry is successful
        self.enter_room(new_room, new_pos=new_pos)
    
    def get_adjacent_pos(self, direction):
        """Get position in direction"""
        x, y = self.game.current_pos
        moves = {'N': (0, 1), 'S': (0, -1), 'E': (1, 0), 'W': (-1, 0)}
        dx, dy = moves[direction]
        return (x + dx, y + dy)
    
    def enter_room(self, room, is_first=False, skip_effects=False, new_pos=None):
        """Enter a room and process events"""
        
        # Determine which position to check for special room flags
        # Use new_pos if entering a new room, otherwise use current_pos for re-entry
        check_pos = new_pos if new_pos else self.game.current_pos
        
        # Restore special room flags if needed (for re-entry scenarios)
        # This ensures the flag is correct even if it was temporarily disabled
        if check_pos in self.game.special_rooms and check_pos not in self.game.unlocked_rooms:
            room_type = self.game.special_rooms[check_pos]
            if room_type == 'mini_boss':
                room.is_mini_boss_room = True
            elif room_type == 'boss':
                room.is_boss_room = True
        
        # Check for boss/mini-boss rooms BEFORE entering
        # This way we can block entry if the player doesn't have/use the key
        if getattr(room, 'is_boss_room', False) and not skip_effects:
            # Check if this room has already been unlocked
            if check_pos not in self.game.unlocked_rooms:
                # Initialize key_fragments_collected if missing (for old saves)
                if not hasattr(self.game, 'key_fragments_collected'):
                    self.game.key_fragments_collected = 0
                
                # Room is locked - check for key
                if self.game.key_fragments_collected >= 3:
                    # Show in-game dialog for boss key usage
                    def on_boss_key_decision(use_key):
                        if use_key:
                            self.game.key_fragments_collected = 0  # Consume the fragments
                            self.game.unlocked_rooms.add(new_pos if new_pos else self.game.current_pos)  # Mark room as unlocked
                            self.game.log(f"The 3 fragments merge into a complete key!", 'success')
                            self.game.log(f"The massive boss door grinds open!", 'success')
                            # Now actually enter the room
                            self._complete_room_entry(room, is_first, skip_effects, new_pos)
                        else:
                            self.game.log("You decide to prepare more before facing the boss.", 'system')
                            self.game.log("You turn back. The boss room remains sealed.", 'enemy')
                            # Don't enter - update display and go back to previous room
                            self.game.update_display()
                            self.show_exploration_options()
                    
                    # Show the dialog and return - callback will handle entry
                    self.game.log("☠ An enormous sealed door looms before you! ☠", 'enemy')
                    self.game.log("Three keyhole slots glow faintly in the door.", 'system')
                    self.game.show_key_usage_dialog("Boss Key", on_boss_key_decision)
                    return  # Exit here, callback will continue
                else:
                    # Not enough fragments
                    fragments_needed = 3 - self.game.key_fragments_collected
                    self.game.log("☠ An enormous sealed door looms before you! ☠", 'enemy')
                    self.game.log(f"The door has 3 keyhole slots. You have {self.game.key_fragments_collected} fragment(s).", 'system')
                    self.game.log(f"You need {fragments_needed} more key fragment(s) to unlock this door!", 'enemy')
                    # Don't enter - show exploration options
                    self.show_exploration_options()
                    return
        
        elif getattr(room, 'is_mini_boss_room', False) and not skip_effects:
            # Check if this room has already been unlocked
            if check_pos not in self.game.unlocked_rooms:
                # Room is locked - check for key
                if "Old Key" in self.game.inventory:
                    # Show in-game dialog for old key usage
                    def on_old_key_decision(use_key):
                        if use_key:
                            self.game.inventory.remove("Old Key")
                            self.game.unlocked_rooms.add(new_pos if new_pos else self.game.current_pos)  # Mark room as unlocked
                            self.game.log("[KEY USED] The Old Key turns in the lock with a satisfying click!", 'success')
                            self.game.log("The elite room door swings open!", 'success')
                            # Now actually enter the room
                            self._complete_room_entry(room, is_first, skip_effects, new_pos)
                        else:
                            self.game.log("You decide to save your Old Key for later.", 'system')
                            self.game.log("You turn back. The elite room remains locked.", 'enemy')
                            # Don't enter - update display and go back to previous room
                            self.game.update_display()
                            self.show_exploration_options()
                    
                    # Show the dialog and return - callback will handle entry
                    self.game.log("⚡ A reinforced door blocks your path! ⚡", 'enemy')
                    self.game.log("The door is sealed with an ornate lock.", 'system')
                    self.game.show_key_usage_dialog("Old Key", on_old_key_decision)
                    return  # Exit here, callback will continue
                else:
                    # No Old Key
                    self.game.log("⚡ A reinforced door blocks your path! ⚡", 'enemy')
                    self.game.log("The door is sealed with an ornate lock.", 'system')
                    self.game.log("You need an Old Key to unlock this door.", 'enemy')
                    # Don't enter - show exploration options
                    self.show_exploration_options()
                    return
        
        # If we get here, the room can be entered normally
        self._complete_room_entry(room, is_first, skip_effects, new_pos)
    
    def _complete_room_entry(self, room, is_first, skip_effects, new_pos=None):
        """Complete the room entry after key checks"""
        # Track if this is the first visit to this room
        is_first_visit = not room.visited
        
        # Set instant text mode for revisited rooms (text displays instantly)
        # New rooms get the typing effect
        self.game.instant_text_mode = not is_first_visit
        
        # Update current position - this is when we officially move into the room
        if new_pos:
            self.game.current_pos = new_pos
        
        self.game.current_room = room
        self.game._current_room = room.data
        room.visited = True
        
        # Only increment rooms_explored counter on first visit (not starting room)
        if not is_first and is_first_visit:
            self.game.rooms_explored += 1
            self.game.stats["rooms_explored"] = self.game.rooms_explored
            
            # Track first 3 rooms as safe starter rooms (no combat ever)
            if self.game.rooms_explored <= 3 and self.game.floor == 1:
                self.game.starter_rooms.add(self.game.current_pos)
        
        # Decrement rest cooldown only when exploring NEW rooms
        if is_first_visit and self.game.rest_cooldown > 0:
            self.game.rest_cooldown -= 1
        
        # Update UI
        self.game.room_title.config(text=f"{room.data['name']}")
        self.game.room_desc.config(text=room.data['flavor'])
        
        # Log entry
        self.game.log(f"\n{'='*50}", 'system')
        self.game.log(f"Entered: {room.data['name']}", 'system')
        
        # Continue with normal room entry, passing first visit flag
        self._continue_room_entry(room, skip_effects, is_first_visit)
    
    def _continue_room_entry(self, room, skip_effects, is_first_visit):
        """Continue room entry after key decisions"""
        self.game.log(room.data['flavor'], 'system')
        
        # Generate ground loot on first visit
        if is_first_visit and not skip_effects:
            self.generate_ground_loot(room)
        
        # Show what's on the ground
        self.describe_ground_items(room)
        
        # Apply room entry effects ONLY on first visit (unless loading a save)
        if not skip_effects and is_first_visit:
            apply_on_enter(self.game, room.data, self.game.log)
            apply_effective_modifiers(self.game)
        
        # Randomly add stairs (10% chance in any room after 3+ rooms explored) - ONLY on first visit
        if not skip_effects and is_first_visit and not self.game.stairs_found and self.game.rooms_explored >= 3 and self.game.rng.random() < 0.1:
            room.has_stairs = True
            self.game.stairs_found = True
            self.game.log("⚡ You found stairs to the next floor!", 'success')
        
        # Randomly add store (chance decreases on deeper floors, once per floor) - ONLY on first visit
        # Floor 1: 35%, Floor 2: 25%, Floor 3: 20%, Floor 4+: 15%
        # GUARANTEED after 15 rooms to prevent bad luck
        store_chance = 0.15  # Default for floor 4+
        if self.game.floor == 1:
            store_chance = 0.35
        elif self.game.floor == 2:
            store_chance = 0.25
        elif self.game.floor == 3:
            store_chance = 0.20
        
        # Guarantee store spawn after 15 rooms
        if not skip_effects and is_first_visit and not self.game.store_found and self.game.rooms_explored >= 2:
            if self.game.rooms_explored >= 15 or self.game.rng.random() < store_chance:
                self.game.store_found = True
                self.game.store_position = self.game.current_pos
                self.game.store_room = room
                self.game.log("You discovered a mysterious shop!", 'loot')
        
        # Randomly add chest (20% chance, only in unvisited rooms)
        if not skip_effects and not room.has_chest and not room.visited and self.game.rng.random() < 0.2:
            room.has_chest = True
            self.game.log("✨ There's a chest here!", 'loot')
        
        # Update display and minimap BEFORE checking for combat
        # This ensures the player sees their position update even when combat starts
        self.game.update_display()
        self.game.draw_minimap()
        
        # Trigger combat if applicable
        # Check if combat should happen based on room's pre-rolled combat flag
        # Skip combat in starter rooms (first 3 rooms on floor 1)
        # ALSO skip combat if enemies have already been defeated in this room
        is_starter_room = self.game.current_pos in self.game.starter_rooms
        
        # Pre-fetch combat info for both combat and peaceful paths
        combat_threats = room.data.get('threats', [])
        has_combat_tag = 'combat' in room.data.get('tags', [])
        
        # Only trigger combat if: room has combat AND enemies haven't been defeated yet
        if not is_starter_room and room.has_combat and not room.enemies_defeated and not skip_effects:
            # Check room type for special enemy selection
            is_boss = getattr(room, 'is_boss_room', False)
            is_mini_boss = getattr(room, 'is_mini_boss_room', False) and not is_boss
            
            if combat_threats:
                enemy_name = self.game.rng.choice(combat_threats)
            else:
                enemy_name = "Monster"
            
            if not skip_effects:
                self.game.trigger_combat(enemy_name, is_mini_boss=is_mini_boss, is_boss=is_boss)
                return  # Combat UI will be shown, don't show exploration options yet
            else:
                # If loading, just show options without triggering combat
                self.show_exploration_options()
        else:
            # No combat - peaceful exploration
            if combat_threats or has_combat_tag:
                # Room had potential threats but they were avoided
                peaceful_messages = [
                    "The room is quiet. You explore cautiously...",
                    "You sense danger but nothing attacks.",
                    "The threats here seem to have moved on.",
                    "You carefully avoid any lurking dangers.",
                    "The room appears safe for now."
                ]
                self.game.log(self.game.rng.choice(peaceful_messages), 'system')
            
            # Show exploration options
            self.show_exploration_options()
    
    def show_exploration_options(self):
        """Show options for exploring - new layout"""
        # Skip if combat is still active to avoid collapsing the panel mid-fight
        if getattr(self.game, 'in_combat', False):
            if hasattr(self.game, 'debug_logger'):
                self.game.debug_logger.ui("show_exploration_options skipped (in combat)")
            return

        # Hide entire action panel during exploration (contains combat UI)
        if hasattr(self.game, 'action_panel'):
            self.game.action_panel.pack_forget()
            if hasattr(self.game, 'debug_logger'):
                self.game.debug_logger.ui("action_panel hidden for exploration")
        
        # Hide dice section, enemy column, and player sprite box during exploration
        if hasattr(self.game, 'dice_section'):
            self.game.dice_section.pack_forget()
        if hasattr(self.game, 'enemy_column'):
            self.game.enemy_column.pack_forget()
        if hasattr(self.game, 'player_sprite_box'):
            self.game.player_sprite_box.pack_forget()
        
        # Clear action buttons strip
        for widget in self.game.action_buttons_strip.winfo_children():
            widget.destroy()
        
        # Hide enemy info in action panel
        if self.game.action_panel_enemy_hp:
            self.game.action_panel_enemy_hp.pack_forget()
        self.game.action_panel_enemy_label.config(text="---")
        if hasattr(self.game, 'enemy_sprite_area'):
            self.game.enemy_sprite_area.pack_forget()
            # Only update sprite label if it still exists
            if hasattr(self.game, 'enemy_sprite_label') and self.game.enemy_sprite_label.winfo_exists():
                self.game.enemy_sprite_label.config(text="Enemy\nSprite")
        
        # Hide enemy dice
        if hasattr(self.game, 'enemy_dice_frame'):
            self.game.enemy_dice_frame.pack_forget()
        
        # === UTILITY BUTTONS directly in strip ===
        if self.game.current_room.has_chest and not self.game.current_room.chest_looted:
            tk.Button(self.game.action_buttons_strip, text="Chest",
                     command=self.game.open_chest,
                     font=('Arial', self.game.scale_font(8), 'bold'), 
                     bg=self.game.current_colors["text_purple"], fg='#ffffff',
                     width=7, height=1).pack(side=tk.LEFT, padx=1)
        
        # Check Ground button (if items exist)
        container_has_items = (self.game.current_room.container_gold > 0 or 
                              self.game.current_room.container_item is not None)
        ground_items_exist = (
            (self.game.current_room.ground_container and (not self.game.current_room.container_searched or container_has_items)) or
            self.game.current_room.ground_gold > 0 or
            len(self.game.current_room.ground_items) > 0 or
            (hasattr(self.game.current_room, 'uncollected_items') and self.game.current_room.uncollected_items) or
            (hasattr(self.game.current_room, 'dropped_items') and self.game.current_room.dropped_items)
        )
        
        if ground_items_exist:
            # Count total items on ground
            total_ground_items = 0
            if self.game.current_room.ground_container and (not self.game.current_room.container_searched or container_has_items):
                total_ground_items += 1
            if self.game.current_room.ground_gold > 0:
                total_ground_items += 1
            total_ground_items += len(self.game.current_room.ground_items)
            if hasattr(self.game.current_room, 'uncollected_items'):
                total_ground_items += len(self.game.current_room.uncollected_items)
            if hasattr(self.game.current_room, 'dropped_items'):
                total_ground_items += len(self.game.current_room.dropped_items)
            
            item_word = "item" if total_ground_items == 1 else "items"
            tk.Button(self.game.action_buttons_strip, text=f"{total_ground_items} {item_word}",
                     command=self.game.show_ground_items,
                     font=('Arial', self.game.scale_font(8), 'bold'), 
                     bg=self.game.current_colors["text_orange"], fg='#ffffff',
                     width=9, height=1).pack(side=tk.LEFT, padx=1)
        
        # Rest button with cooldown indicator
        rest_text = "Rest"
        rest_bg = self.game.current_colors["button_secondary"]
        rest_state = tk.NORMAL
        if self.game.rest_cooldown > 0:
            rest_text = f"Rest ({self.game.rest_cooldown})"
            rest_bg = '#666666'  # Grey instead of black
            rest_state = tk.DISABLED  # Disable button when on cooldown
        
        tk.Button(self.game.action_buttons_strip, text=rest_text,
                 command=self.game.rest,
                 font=('Arial', self.game.scale_font(8), 'bold'), bg=rest_bg, fg='#000000',
                 width=7, height=1, state=rest_state).pack(side=tk.LEFT, padx=1)
        
        tk.Button(self.game.action_buttons_strip, text="Inv",
                 command=self.game.show_inventory,
                 font=('Arial', self.game.scale_font(8), 'bold'), 
                 bg=self.game.current_colors["button_secondary"], fg='#000000',
                 width=5, height=1).pack(side=tk.LEFT, padx=1)
        
        # Store button - show if store has been found on this floor
        if self.game.store_found:
            if self.game.current_pos == self.game.store_position:
                # At store location - show "Browse Store"
                tk.Button(self.game.action_buttons_strip, text="Store",
                         command=self.game.show_store,
                         font=('Arial', self.game.scale_font(8), 'bold'), 
                         bg=self.game.current_colors["text_gold"], fg='#000000',
                         width=7, height=1).pack(side=tk.LEFT, padx=1)
            else:
                # Away from store - show "Travel to Store"
                tk.Button(self.game.action_buttons_strip, text="→Store",
                         command=self.game.travel_to_store,
                         font=('Arial', self.game.scale_font(8), 'bold'), 
                         bg=self.game.current_colors["text_purple"], fg='#ffffff',
                         width=7, height=1).pack(side=tk.LEFT, padx=1)
        
        if self.game.current_room.has_stairs:
            stairs_btn = tk.Button(self.game.action_buttons_strip, text="Stairs",
                     command=self.descend_floor,
                     font=('Arial', self.game.scale_font(8), 'bold'), 
                     bg=self.game.current_colors["text_gold"], fg='#000000',
                     width=7, height=1)
            stairs_btn.pack(side=tk.LEFT, padx=1)
            
            # Disable button if boss not defeated
            if not self.game.boss_defeated:
                stairs_btn.config(state=tk.DISABLED, bg='#666666', fg='#333333')
        
        # Update scroll region to ensure all content is visible
        self.game.update_scroll_region()
        
        # Return focus to root window to ensure keybindings work
        # Use after_idle to ensure focus is applied after all UI updates complete
        self.game.root.after_idle(lambda: self.game.root.focus_force())
    
    def generate_ground_loot(self, room):
        """Generate what spawns on the ground when first entering a room"""
        # Mini-boss rooms ALWAYS have containers (guaranteed loot)
        is_mini_boss = getattr(room, 'is_mini_boss_room', False)
        
        # Container spawn logic
        if room.data.get('discoverables'):
            if is_mini_boss:
                # 100% container spawn for mini-boss rooms
                room.ground_container = self.game.rng.choice(room.data['discoverables'])
            elif self.game.rng.random() < 0.6:
                # 60% chance for normal rooms
                room.ground_container = self.game.rng.choice(room.data['discoverables'])
            
            # 30% chance for container to be locked on floor 2+
            if room.ground_container and self.game.floor >= 2 and self.game.rng.random() < 0.30:
                room.container_locked = True
        
        # 40% chance for loose items/gold to spawn directly on ground (not for mini-boss rooms)
        if not is_mini_boss and self.game.rng.random() < 0.4:
            # 50/50 split between gold or items
            if self.game.rng.random() < 0.5:
                # Loose gold
                room.ground_gold = self.game.rng.randint(5, 20)
            else:
                # Loose items - pick 1-2 random items
                num_items = self.game.rng.randint(1, 2)
                available_items = ['Health Potion', 'Weighted Die', 'Lucky Chip', 'Honey Jar', 
                                 'Lockpick Kit', 'Antivenom Leaf', 'Silk Bundle']
                for _ in range(num_items):
                    item = self.game.rng.choice(available_items)
                    room.ground_items.append(item)
    
    def describe_ground_items(self, room):
        """Show player what's on the ground"""
        things_noticed = []
        
        # Only show container if it exists AND hasn't been searched
        if room.ground_container and not room.container_searched:
            things_noticed.append(f"a {room.ground_container}")
        
        # Only show gold if there's actually gold remaining
        if room.ground_gold > 0:
            things_noticed.append(f"{room.ground_gold} gold coins")
        
        # Only show items that are still there
        if room.ground_items:
            for item in room.ground_items:
                things_noticed.append(item)
        
        # Only log if there's actually something to notice
        if things_noticed:
            self.game.log(f"You notice on the ground: {', '.join(things_noticed)}", 'system')
    
    def start_new_floor(self):
        """Initialize a new floor"""
        self.game.dungeon = {}
        self.game.current_pos = (0, 0)
        self.game.stairs_found = False
        self.game.in_combat = False
        self.game.in_interaction = False
        self.game.combat_accuracy_penalty = 0.0  # Reset hazard penalties for new floor
        
        # Reset boss system for new floor
        self.game.key_fragments_collected = 0
        self.game.mini_bosses_defeated = 0
        self.game.boss_defeated = False
        self.game.mini_bosses_spawned_this_floor = 0  # Reset floor spawn counter
        self.game.boss_spawned_this_floor = False  # Reset floor spawn flag
        self.game.special_rooms = {}
        self.game.locked_rooms = set()
        self.game.unlocked_rooms = set()
        self.game.is_boss_fight = False
        self.game.rooms_explored_on_floor = 0  # Track rooms explored to trigger boss spawns
        self.game.next_mini_boss_at = self.game.rng.randint(6, 10)  # Random target for first mini-boss
        self.game.next_boss_at = self.game.rng.randint(20, 30) if self.game.floor >= 5 else None  # Random target for boss
        
        # Reset store tracking for new floor
        self.game.store_found = False
        self.game.store_position = None
        self.game.store_room = None
        self.game.floor_store_inventory = None  # Reset for new floor
        
        # Pick entrance room
        room_data = pick_room_for_floor(self.game._rooms, self.game.floor, rng=self.game.rng)
        entrance = Room(room_data, 0, 0)
        entrance.visited = True
        entrance.has_combat = False  # Entrance never has combat
        
        # Randomly block some exits to create dead ends (30% chance per direction)
        for direction in ['N', 'S', 'E', 'W']:
            if self.game.rng.random() < 0.3:
                entrance.exits[direction] = False
                entrance.blocked_exits.append(direction)
        
        # Ensure at least 2 exits are open
        open_exits = [d for d in ['N', 'S', 'E', 'W'] if entrance.exits[d]]
        if len(open_exits) < 2:
            # Randomly open a blocked exit
            blocked = [d for d in ['N', 'S', 'E', 'W'] if not entrance.exits[d]]
            if blocked:
                to_open = self.game.rng.choice(blocked)
                entrance.exits[to_open] = True
                if to_open in entrance.blocked_exits:
                    entrance.blocked_exits.remove(to_open)
        
        self.game.dungeon[(0, 0)] = entrance
        self.game.current_room = entrance
        self.game._current_room = room_data
        
        # Mark starting position as a starter room (no combat)
        if self.game.floor == 1:
            self.game.starter_rooms.add((0, 0))
        
        # Setup UI
        self.game.setup_game_ui()
        
        # Apply floor transition
        on_floor_transition(self.game)
        
        # Enter first room
        self.enter_room(entrance, is_first=True)
    
    def descend_floor(self):
        """Go to next floor"""
        if not self.game.current_room.has_stairs:
            self.game.log("No stairs here! Keep exploring.", 'system')
            return
        
        if not self.game.boss_defeated:
            msg = "The stairs are blocked by a mysterious force.\n\nYou must defeat the floor boss first!"
            self.game.log(msg.replace('\n\n', ' '), 'system')
            messagebox.showwarning("Stairs Blocked", msg)
            return
        
        self.game.floor += 1
        self.game.run_score += 100 * self.game.floor
        
        # Track highest floor
        if "highest_floor" not in self.game.stats:
            self.game.stats["highest_floor"] = 1
        self.game.stats["highest_floor"] = max(self.game.stats["highest_floor"], self.game.floor)
        
        # Reset floor-specific trackers
        self.game.purchased_upgrades_this_floor.clear()
        
        self.game.log(f"\n[STAIRS] Descending deeper to Floor {self.game.floor}...", 'success')
        self.start_new_floor()
    
    def show_starter_area(self):
        """Display the tutorial/starter area - managed version"""
        self.game.in_starter_area = True
        self.game.floor = 0
        
        # Force window update to get accurate dimensions
        self.game.root.update_idletasks()
        
        # Calculate initial scale factor based on current window size
        current_width = self.game.root.winfo_width()
        current_height = self.game.root.winfo_height()
        if current_width > 1 and current_height > 1:
            width_scale = current_width / self.game.base_window_width
            height_scale = current_height / self.game.base_window_height
            self.game.scale_factor = min(width_scale, height_scale)
            self.game.scale_factor = max(0.8, min(self.game.scale_factor, 2.5))
        
        # Setup basic UI first
        for widget in self.game.root.winfo_children():
            widget.destroy()
        
        self.game.game_frame = tk.Frame(self.game.root, bg=self.game.current_colors["bg_primary"])
        self.game.game_frame.pack(fill=tk.BOTH, expand=True)
        
        # Create scrollable content area
        canvas = tk.Canvas(self.game.game_frame, bg=self.game.current_colors["bg_primary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.game.game_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.game.current_colors["bg_primary"], troughcolor=self.game.current_colors["bg_dark"])
        main_area = tk.Frame(canvas, bg=self.game.current_colors["bg_primary"])
        
        # Store reference to chests frame for updates
        self.starter_chests_frame = None
        
        # Create window and bind to canvas width changes
        canvas_window = canvas.create_window((0, 0), window=main_area, anchor="nw")
        
        def on_canvas_configure(event):
            canvas.configure(scrollregion=canvas.bbox("all"))
            canvas.itemconfig(canvas_window, width=event.width)
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
        
        # Stats bar at top
        stats_frame = tk.Frame(main_area, bg=self.game.current_colors["bg_secondary"], pady=self.game.scale_padding(10))
        stats_frame.pack(fill=tk.X, padx=self.game.scale_padding(10), pady=self.game.scale_padding(5))
        
        left_stats = tk.Frame(stats_frame, bg=self.game.current_colors["bg_secondary"])
        left_stats.pack(side=tk.LEFT, padx=self.game.scale_padding(20))
        
        self.game.hp_label = tk.Label(left_stats, text=f"HP: {self.game.health}/{self.game.max_health}",
                                font=('Arial', self.game.scale_font(14), 'bold'), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_red"])
        self.game.hp_label.pack(anchor='w')
        
        self.game.gold_label = tk.Label(left_stats, text=f"Gold: {self.game.gold}",
                                   font=('Arial', self.game.scale_font(12)), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_gold"])
        self.game.gold_label.pack(anchor='w')
        
        # Settings/Menu button in top right
        menu_frame = tk.Frame(stats_frame, bg=self.game.current_colors["bg_secondary"])
        menu_frame.pack(side=tk.RIGHT, padx=self.game.scale_padding(10))
        
        tk.Button(menu_frame, text="☰", command=self.game.show_pause_menu,
                 font=('Arial', self.game.scale_font(16), 'bold'), bg=self.game.current_colors["button_secondary"], fg='#000000',
                 width=3, height=1).pack(side=tk.RIGHT, padx=self.game.scale_padding(2))
        
        tk.Button(menu_frame, text="?", command=self.game.show_tutorial,
                 font=('Arial', self.game.scale_font(16), 'bold'), bg=self.game.current_colors["button_secondary"], fg='#000000',
                 width=3, height=1).pack(side=tk.RIGHT, padx=self.game.scale_padding(2))
        
        right_stats = tk.Frame(stats_frame, bg=self.game.current_colors["bg_secondary"])
        right_stats.pack(side=tk.RIGHT, padx=self.game.scale_padding(20))
        
        self.game.floor_label = tk.Label(right_stats, text=f"THE THRESHOLD",
                                    font=('Arial', self.game.scale_font(14), 'bold'), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["button_primary"])
        self.game.floor_label.pack(anchor='e')
        
        self.game.progress_label = tk.Label(right_stats, text=f"Rooms: {self.game.rooms_explored}",
                                      font=('Arial', self.game.scale_font(10)), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_primary"])
        self.game.progress_label.pack(anchor='e')
        
        # Title and description
        starter_data = self.game.world_lore['starting_area']
        
        title = tk.Label(main_area, text=starter_data['name'],
                        font=('Arial', self.game.scale_font(18), 'bold'), bg=self.game.current_colors["bg_primary"], fg=self.game.current_colors["text_gold"],
                        wraplength=self.game.get_scaled_wraplength(700), justify=tk.CENTER)
        title.pack(pady=self.game.scale_padding(15))
        
        desc = tk.Label(main_area, text=starter_data['description'],
                       font=('Arial', self.game.scale_font(12)), bg=self.game.current_colors["bg_primary"], fg=self.game.current_colors["text_primary"],
                       wraplength=self.game.get_scaled_wraplength(700), justify=tk.LEFT)
        desc.pack(pady=self.game.scale_padding(8), padx=self.game.scale_padding(30))
        
        # Ambient details
        ambient = tk.Label(main_area, text="• " + "\n• ".join(starter_data['ambient_details']),
                          font=('Arial', self.game.scale_font(11), 'italic'), bg=self.game.current_colors["bg_primary"], fg=self.game.current_colors["text_secondary"],
                          wraplength=self.game.get_scaled_wraplength(700), justify=tk.LEFT)
        ambient.pack(pady=self.game.scale_padding(5), padx=self.game.scale_padding(40))
        
        # Interactive elements frame
        interact_container = tk.Frame(main_area, bg=self.game.current_colors["bg_primary"])
        interact_container.pack(fill=tk.BOTH, expand=True, pady=self.game.scale_padding(10))
        
        interact_frame = tk.Frame(interact_container, bg=self.game.current_colors["bg_secondary"], relief=tk.RAISED, borderwidth=2)
        interact_frame.pack(fill=tk.BOTH, expand=True, padx=self.game.scale_padding(50))
        
        tk.Label(interact_frame, text="Welcome, Adventurer. Study these teachings before your journey begins.\n\nIn the dungeon, you'll encounter interactive elements like chests, signs, floor buttons, and containers.\nClick on them to search for items and discover secrets. Open the chests below to get a few starter items",
                font=('Arial', self.game.scale_font(11)), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_gold"],
                wraplength=self.game.get_scaled_wraplength(600), justify=tk.CENTER).pack(pady=self.game.scale_padding(8))
        
        # Tutorial button
        tutorial_frame = tk.Frame(interact_frame, bg=self.game.current_colors["bg_secondary"])
        tutorial_frame.pack(fill=tk.X, padx=self.game.scale_padding(20), pady=self.game.scale_padding(8))
        
        tk.Button(tutorial_frame, text="📜 Show Tutorial - How to Play",
                 command=self.game.show_tutorial,
                 font=('Arial', self.game.scale_font(11), 'bold'), bg=self.game.current_colors["button_primary"], fg='#000000',
                 width=30, pady=self.game.scale_padding(8)).pack()
        
        # Signs
        signs_frame = tk.Frame(interact_frame, bg=self.game.current_colors["bg_secondary"])
        signs_frame.pack(fill=tk.X, padx=self.game.scale_padding(20), pady=self.game.scale_padding(5))
        
        tk.Label(signs_frame, text="Signs & Inscriptions:",
                font=('Arial', self.game.scale_font(11), 'bold'), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_primary"]).pack(anchor='w')
        
        for i, sign in enumerate(starter_data['signs']):
            sign_btn = tk.Button(signs_frame, text=f"{sign['title']}",
                               command=lambda s=sign: self.game.read_sign(s),
                               font=('Arial', self.game.scale_font(10)), bg=self.game.current_colors["button_primary"], fg='#000000',
                               anchor='w')
            sign_btn.pack(fill=tk.X, pady=self.game.scale_padding(3), padx=self.game.scale_padding(10))
        
        # Chests
        self.starter_chests_frame = tk.Frame(interact_frame, bg=self.game.current_colors["bg_secondary"])
        self.starter_chests_frame.pack(fill=tk.X, padx=self.game.scale_padding(20), pady=self.game.scale_padding(5))
        
        tk.Label(self.starter_chests_frame, text="Chests:",
                font=('Arial', self.game.scale_font(11), 'bold'), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_primary"]).pack(anchor='w')
        
        # Store chest button references for updating
        self.chest_buttons = {}
        self._render_chest_buttons(starter_data)
        
        # Enter dungeon button
        enter_frame = tk.Frame(interact_frame, bg=self.game.current_colors["bg_secondary"])
        enter_frame.pack(pady=self.game.scale_padding(10))
        
        tk.Button(enter_frame, text="ENTER THE DUNGEON - FLOOR 1",
                 command=self.enter_dungeon_from_starter,
                 font=('Arial', self.game.scale_font(13), 'bold'), bg=self.game.current_colors["text_red"], fg='#ffffff',
                 width=28, pady=self.game.scale_padding(10)).pack(pady=self.game.scale_padding(3))
        
        # Update scroll region after all content is added
        main_area.update_idletasks()
        canvas.configure(scrollregion=canvas.bbox("all"))
        
        # Setup mousewheel scrolling
        self.game.setup_mousewheel_scrolling(canvas)
        
        # Bind mousewheel to all child widgets
        def bind_mousewheel_to_tree(widget):
            def on_mousewheel(event):
                canvas.yview_scroll(int(-1*(event.delta/120)), "units")
            widget.bind("<MouseWheel>", on_mousewheel, add='+')
            for child in widget.winfo_children():
                bind_mousewheel_to_tree(child)
        bind_mousewheel_to_tree(main_area)
        
        self.game.update_display()
        
        # Schedule scrollbar check after UI is fully rendered
        def check_scrollbar():
            self.game.root.update_idletasks()
            canvas.event_generate('<Configure>')
        self.game.root.after(100, check_scrollbar)
        
        # Show tutorial automatically for first-time players
        if not self.game.tutorial_seen:
            self.game.root.after(200, self.game.show_tutorial)
    
    def _render_chest_buttons(self, starter_data):
        """Render chest buttons without rebuilding entire UI"""
        # Clear existing chest buttons
        for widget in self.starter_chests_frame.winfo_children():
            if isinstance(widget, (tk.Button, tk.Label)) and widget != self.starter_chests_frame.winfo_children()[0]:  # Skip the "Chests:" label
                widget.destroy()
        
        # Re-render chest buttons with current state
        for chest in starter_data['starter_chests']:
            # Use first few words of description as button label
            short_label = chest['description'].split('.')[0][:35] + ("..." if len(chest['description'].split('.')[0]) > 35 else "")
            
            if chest['id'] in self.game.starter_chests_opened:
                chest_label = tk.Label(self.starter_chests_frame, text=f"{short_label} (already looted)",
                                      font=('Arial', self.game.scale_font(10)), bg=self.game.current_colors["bg_secondary"], fg=self.game.current_colors["text_secondary"],
                                      anchor='w')
                chest_label.pack(fill=tk.X, pady=self.game.scale_padding(3), padx=self.game.scale_padding(10))
            else:
                chest_btn = tk.Button(self.starter_chests_frame, text=short_label,
                                    command=lambda c=chest: self.open_starter_chest(c),
                                    font=('Arial', self.game.scale_font(10)), bg=self.game.current_colors["button_secondary"], fg='#000000',
                                    anchor='w')
                chest_btn.pack(fill=tk.X, pady=self.game.scale_padding(3), padx=self.game.scale_padding(10))
                self.chest_buttons[chest['id']] = chest_btn
    
    def open_starter_chest(self, chest):
        """Open a starter area chest with proper description"""
        if chest['id'] in self.game.starter_chests_opened:
            return
        
        self.game.starter_chests_opened.append(chest['id'])
        
        # Add items
        for item in chest['items']:
            if len(self.game.inventory) < self.game.max_inventory:
                self.game.inventory.append(item)
                # Track item collection
                if "items_collected" not in self.game.stats:
                    self.game.stats["items_collected"] = {}
                self.game.stats["items_collected"][item] = self.game.stats["items_collected"].get(item, 0) + 1
                self.game.stats["items_found"] += 1
        
        # Add gold
        if chest['gold'] > 0:
            self.game.gold += chest['gold']
            self.game.total_gold_earned += chest['gold']
            self.game.stats["gold_found"] += chest['gold']
        
        # Show loot dialog
        if self.game.dialog_frame:
            self.game.dialog_frame.destroy()
        
        self.game.dialog_frame = tk.Frame(self.game.root, bg='#1a0f08', relief=tk.RAISED, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER, 
                                     width=int(500 * self.game.scale_factor), height=int(450 * self.game.scale_factor))
        
        # Header with title and X button
        header = tk.Frame(self.game.dialog_frame, bg='#1a0f08')
        header.pack(fill=tk.X, pady=(5, 0))
        
        tk.Label(header, text="CHEST OPENED", font=('Arial', self.game.scale_font(16), 'bold'),
                bg='#1a0f08', fg='#ffd700').pack(side=tk.LEFT, padx=10, pady=10)
        
        close_btn = tk.Label(header, text="✕", font=('Arial', self.game.scale_font(16), 'bold'),
                            bg='#1a0f08', fg='#ff4444', cursor="hand2", padx=5)
        close_btn.pack(side=tk.RIGHT, padx=5)
        close_btn.bind('<Button-1>', lambda e: self._close_chest_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Chest description
        tk.Label(self.game.dialog_frame, text=chest['description'],
                font=('Arial', self.game.scale_font(11), 'bold'), bg='#1a0f08', fg='#4ecdc4',
                wraplength=450, pady=10).pack()
        
        loot_frame = tk.Frame(self.game.dialog_frame, bg='#2c1810')
        loot_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        tk.Label(loot_frame, text="You found:", font=('Arial', self.game.scale_font(12), 'bold'),
                bg='#2c1810', fg='#ffd700').pack(pady=5)
        
        for item in chest['items']:
            tk.Label(loot_frame, text=f"• {item}", font=('Arial', self.game.scale_font(11)),
                    bg='#2c1810', fg='#4ecdc4').pack()
        
        if chest['gold'] > 0:
            tk.Label(loot_frame, text=f"• {chest['gold']} Gold", font=('Arial', self.game.scale_font(11)),
                    bg='#2c1810', fg='#ffd700').pack()
        
        tk.Label(self.game.dialog_frame, text=chest['lore'],
                font=('Arial', self.game.scale_font(9), 'italic'), bg='#1a0f08', fg='#888888',
                wraplength=450, pady=10).pack()
        
        tk.Button(self.game.dialog_frame, text="Continue", command=self._close_chest_dialog,
                 font=('Arial', self.game.scale_font(12), 'bold'), bg='#4ecdc4', fg='#000000',
                 width=15, pady=10).pack(pady=10)
    
    def _close_chest_dialog(self):
        """Close chest dialog and update buttons without rebuilding entire UI"""
        self.game.close_dialog()
        # Update only the chest buttons instead of rebuilding everything
        if hasattr(self, 'starter_chests_frame') and self.starter_chests_frame:
            starter_data = self.game.world_lore['starting_area']
            self._render_chest_buttons(starter_data)
        # Update stats display
        self.game.update_display()
    
    def enter_dungeon_from_starter(self):
        """Enter the main dungeon from starter area"""
        self.game.in_starter_area = False
        self.game.start_new_floor()
