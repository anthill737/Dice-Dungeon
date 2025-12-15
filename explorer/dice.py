"""
Dice System Manager - Handles all dice mechanics for Dice Dungeon
Manages: Rolling, locking, display, animation, rendering, combo calculation, damage preview
"""
import random
import tkinter as tk
from collections import Counter
from debug_logger import get_logger


class DiceManager:
    """Manages all dice-related mechanics including rolling, rendering, and damage calculation"""
    
    def __init__(self, game):
        """Initialize DiceManager with reference to main game"""
        self.game = game
        self.debug_logger = get_logger()
    
    def toggle_dice(self, idx):
        """Toggle dice lock state for a specific die"""
        if idx < len(self.game.dice_locked):
            # Prevent toggling force-locked dice
            forced_locks = getattr(self.game, 'forced_dice_locks', [])
            if idx in forced_locks:
                self.game.log("This die is force-locked by an enemy ability!", 'system')
                return
            
            self.game.dice_locked[idx] = not self.game.dice_locked[idx]
            self.update_dice_display()
    
    def roll_dice(self):
        """Roll all unlocked dice with animation"""
        self.debug_logger.dice("roll_dice CALLED", rolls_left=self.game.rolls_left, combat_state=getattr(self.game, 'combat_state', 'unknown'))
        
        # Don't allow rolling during enemy's turn
        if hasattr(self.game, 'combat_state') and self.game.combat_state == 'enemy_turn':
            self.debug_logger.warning("DICE", "Cannot roll during enemy turn")
            return
        
        if self.game.rolls_left <= 0:
            self.debug_logger.warning("DICE", "No rolls left")
            return
        
        # Determine which dice to roll (exclude both manually locked and force-locked dice)
        forced_locks = getattr(self.game, 'forced_dice_locks', [])
        dice_to_roll = [i for i in range(self.game.num_dice) 
                       if not self.game.dice_locked[i] and i not in forced_locks]
        
        if not dice_to_roll:
            self.game.log("All dice are locked!", 'system')
            return
        
        # Generate final values for dice being rolled
        final_values = {}
        restricted_values = getattr(self.game, 'dice_restricted_values', [])
        
        for i in dice_to_roll:
            if restricted_values:
                # Roll only from restricted values (boss curse)
                final_values[i] = random.choice(restricted_values)
            else:
                # Normal roll
                final_values[i] = random.randint(1, 6)
        
        # Start animation (15 frames = 375ms total at 25ms per frame, reduced from 20 frames/500ms)
        self._animate_dice_roll(dice_to_roll, final_values, frame=0, max_frames=15)
    
    def _animate_dice_roll(self, dice_to_roll, final_values, frame, max_frames):
        """Animate dice rolling through random numbers"""
        if frame < max_frames:
            # Show random values during animation
            for i in dice_to_roll:
                self.game.dice_values[i] = random.randint(1, 6)
            self.update_dice_display()
            
            # Schedule next frame (25ms delay for smooth animation)
            self.game.root.after(25, lambda: self._animate_dice_roll(dice_to_roll, final_values, frame + 1, max_frames))
        else:
            # Animation complete - set final values
            for i in dice_to_roll:
                self.game.dice_values[i] = final_values[i]
            
            self.game.rolls_left -= 1
            self.game.has_rolled = True
            self.game.combat_state = "player_rolled"  # Player has rolled, can now attack
            
            # Update rolls label
            max_rolls = 3 + self.game.reroll_bonus
            if hasattr(self.game, 'rolls_label'):
                self.game.rolls_label.config(text=f"Rolls Remaining: {self.game.rolls_left}/{max_rolls}")
            
            # Enable attack button once player has rolled at least once
            if hasattr(self.game, 'attack_button') and self.game.has_rolled:
                self.game.attack_button.config(state='normal', bg='#ff6b6b', fg='#ffffff')
            
            # Re-enable roll button if there are rolls left
            if hasattr(self.game, 'roll_button'):
                if self.game.rolls_left > 0:
                    self.game.roll_button.config(state=tk.NORMAL)
                else:
                    self.game.roll_button.config(state=tk.DISABLED)
            
            self.update_dice_display()
            
            # Show rolled dice values with potential damage preview inline
            dice_str = ", ".join(str(self.game.dice_values[i]) for i in range(self.game.num_dice) if self.game.dice_values[i] > 0)
            
            # Add restriction warning if active
            restricted_values = getattr(self.game, 'dice_restricted_values', [])
            restriction_note = f" [Restricted to {restricted_values}]" if restricted_values else ""
            
            # Calculate potential damage for preview
            potential_info = self._get_damage_preview_text()
            if potential_info:
                self.game.log(f"⚄ You rolled: [{dice_str}]{restriction_note} - {potential_info}", 'player')
            else:
                self.game.log(f"⚄ You rolled: [{dice_str}]{restriction_note}", 'player')
            
            # Clear the damage preview label since we're showing it in the log now
            if hasattr(self.game, 'damage_preview_label'):
                self.game.damage_preview_label.config(text="")
    
    def reset_turn(self):
        """Reset turn state: unlock dice, restore rolls (without rolling)"""
        # Unlock all dice except force-locked ones
        forced_locks = getattr(self.game, 'forced_dice_locks', [])
        for i in range(self.game.num_dice):
            if i not in forced_locks:
                self.game.dice_locked[i] = False
        
        # Preserve force-locked dice values when resetting
        preserved_values = {}
        for idx in forced_locks:
            if idx < len(self.game.dice_values):
                preserved_values[idx] = self.game.dice_values[idx]
        
        # Reset dice values to 0, but restore force-locked values
        self.game.dice_values = [0] * self.game.num_dice
        for idx, value in preserved_values.items():
            self.game.dice_values[idx] = value
        
        self.game.rolls_left = 3 + self.game.reroll_bonus
        
        # Reset has_rolled flag so player must roll before attacking
        self.game.has_rolled = False
        
        # Update dice display
        self.update_dice_display()
        
        # Update rolls label
        max_rolls = 3 + self.game.reroll_bonus
        if hasattr(self.game, 'rolls_label'):
            self.game.rolls_label.config(text=f"Rolls Remaining: {self.game.rolls_left}/{max_rolls}")
        
        # Clear damage preview
        if hasattr(self.game, 'damage_preview_label'):
            self.game.damage_preview_label.config(text="")
    
    def update_dice_display(self):
        """Update dice canvas display with current values and lock states"""
        if not hasattr(self.game, 'dice_canvases'):
            return
        
        style = self.get_current_dice_style()
        dice_obscured = getattr(self.game, 'dice_obscured', False)
        
        for i, canvas in enumerate(self.game.dice_canvases):
            if i >= len(self.game.dice_values):
                continue
            
            # Clear the canvas
            canvas.delete("all")
            
            if self.game.dice_values[i] == 0:
                # Not yet rolled - show "?"
                canvas.create_rectangle(0, 0, 72, 72, fill='#cccccc', outline='#666666', width=3)
                canvas.create_text(36, 36, text="?", font=('Arial', 32, 'bold'), fill='#666666')
            elif dice_obscured and self.game.dice_values[i] > 0:
                # Dice values are obscured by boss ability - show "?" with dark tint
                canvas.create_rectangle(0, 0, 72, 72, fill='#4a4a4a', outline='#8b008b', width=3)
                canvas.create_text(36, 36, text="?", font=('Arial', 32, 'bold'), fill='#8b008b')
                # Add curse indicator
                canvas.create_text(36, 60, text="CURSED", font=('Arial', 7, 'bold'), fill='#8b008b')
            elif self.game.dice_locked[i] or i in getattr(self.game, 'forced_dice_locks', []):
                # Locked die (manually or force-locked) - render normal die first
                self.render_die_on_canvas(canvas, self.game.dice_values[i], style, size=72, locked=False)
                
                # Add 80% transparent dark overlay using multiple stipple rectangles for darker effect
                canvas.create_rectangle(0, 0, 72, 72, fill='#000000', stipple='gray75', outline='')
                canvas.create_rectangle(0, 0, 72, 72, fill='#000000', stipple='gray50', outline='')
                
                # Add "LOCKED" text below the die value area
                lock_text = "CURSED" if i in getattr(self.game, 'forced_dice_locks', []) else "LOCKED"
                lock_color = '#ff4444' if i in getattr(self.game, 'forced_dice_locks', []) else '#ffd700'
                canvas.create_text(36, 62, text=lock_text, 
                                 font=('Arial', 8, 'bold'), 
                                 fill=lock_color, anchor='center')
            else:
                # Rolled but not locked - use normal style
                self.render_die_on_canvas(canvas, self.game.dice_values[i], style, size=72, locked=False)
    
    def get_current_dice_style(self):
        """Get the current dice style with any overrides applied"""
        return self.game.combat_manager.get_current_dice_style()
    
    def _get_die_face_text(self, value, face_mode):
        """Get the display text for a die face based on face mode"""
        if face_mode == "pips":
            # Use dice pip symbols (⚀⚁⚂⚃⚄⚅)
            pip_symbols = {1: "⚀", 2: "⚁", 3: "⚂", 4: "⚃", 5: "⚄", 6: "⚅"}
            return pip_symbols.get(value, str(value))
        else:
            # Use numbers
            return str(value)
    
    def render_die_on_canvas(self, canvas, value, style, size=64, locked=False):
        """
        Render a die on a Canvas with proper pip patterns or numbers.
        
        Args:
            canvas: tkinter Canvas widget
            value: Die value (1-6)
            style: Style dictionary with bg, border, pip_color, face_mode
            size: Canvas size in pixels (square)
            locked: Whether to use locked colors
        """
        # Clear canvas
        canvas.delete("all")
        
        # Determine colors based on locked state
        if locked:
            bg_color = style.get("locked_bg", style["bg"])
            border_color = style.get("locked_border", style["border"])
            pip_color = style.get("locked_pip", style["pip_color"])
        else:
            bg_color = style["bg"]
            border_color = style["border"]
            pip_color = style["pip_color"]
        
        # Draw background square with border
        border_width = max(2, size // 20)
        canvas.create_rectangle(
            0, 0, size, size,
            fill=bg_color,
            outline=border_color,
            width=border_width
        )
        
        face_mode = style.get("face_mode", "numbers")
        
        if face_mode == "pips":
            # Draw classic dice pip patterns
            self._draw_dice_pips(canvas, value, pip_color, size)
        else:
            # Draw large centered number
            font_size = max(24, size // 2)
            canvas.create_text(
                size // 2, size // 2,
                text=str(value),
                font=('Arial', font_size, 'bold'),
                fill=pip_color
            )
    
    def _draw_dice_pips(self, canvas, value, color, size):
        """Draw traditional dice pip patterns on a canvas."""
        # Calculate pip size and positions
        pip_radius = max(3, size // 10)
        margin = size // 4
        center = size // 2
        
        # Define pip positions for each value
        # Positions are (x, y) relative to canvas
        positions = {
            1: [(center, center)],  # Center
            2: [(margin, margin), (size - margin, size - margin)],  # Diagonal
            3: [(margin, margin), (center, center), (size - margin, size - margin)],  # Diagonal + center
            4: [(margin, margin), (margin, size - margin), 
                (size - margin, margin), (size - margin, size - margin)],  # Four corners
            5: [(margin, margin), (margin, size - margin),
                (center, center),
                (size - margin, margin), (size - margin, size - margin)],  # Four corners + center
            6: [(margin, margin), (margin, center), (margin, size - margin),
                (size - margin, margin), (size - margin, center), (size - margin, size - margin)]  # Two columns
        }
        
        # Draw pips as filled circles
        pips = positions.get(value, [(center, center)])
        for x, y in pips:
            canvas.create_oval(
                x - pip_radius, y - pip_radius,
                x + pip_radius, y + pip_radius,
                fill=color,
                outline=color
            )
    
    def _get_damage_preview_text(self):
        """Get potential damage preview text without displaying it"""
        if not any(self.game.dice_values):
            return ""
        
        # Calculate damage silently (without logging combos)
        counts = Counter(self.game.dice_values)
        bonus_damage = 0
        
        # Check for combos silently
        for value, count in counts.items():
            if count >= 5:
                bonus_damage += value * 20
            elif count == 4:
                bonus_damage += value * 10
            elif count == 3:
                bonus_damage += value * 5
            elif count == 2:
                bonus_damage += value * 2
        
        # Check for Full House
        if len(counts) == 2 and 3 in counts.values() and 2 in counts.values():
            bonus_damage += 50
        
        # Check for Flush (all same)
        if len(counts) == 1 and len(self.game.dice_values) >= 5:
            value = list(counts.keys())[0]
            bonus_damage += value * 15
        
        # Check for Straights
        sorted_dice = sorted(set(self.game.dice_values))
        if sorted_dice == [1,2,3,4,5,6]:
            bonus_damage += 40
        elif len(sorted_dice) >= 4:
            for i in range(len(sorted_dice) - 3):
                if sorted_dice[i:i+4] == list(range(sorted_dice[i], sorted_dice[i]+4)):
                    bonus_damage += 25
                    break
        
        base_damage = sum(self.game.dice_values)
        # Multiplier only applies to base dice damage, not bonuses (matches calculate_damage)
        total = int((base_damage * self.game.multiplier) + bonus_damage + self.game.damage_bonus)
        
        # Apply difficulty multiplier
        difficulty = self.game.settings.get("difficulty", "Normal")
        total = int(total * self.game.difficulty_multipliers[difficulty]["player_damage_mult"])
        total = int(total * self.game.dev_config["player_damage_mult"])
        
        # Return formatted text
        if bonus_damage > 0:
            return f"Potential: {total} damage (Base: {base_damage} + Combos: {bonus_damage})"
        else:
            return f"Potential: {total} damage"
    
    def _preview_damage(self):
        """Preview potential damage (kept for compatibility, now just updates label)"""
        preview_text = self._get_damage_preview_text()
        if preview_text and hasattr(self.game, 'damage_preview_label'):
            self.game.damage_preview_label.config(text=preview_text)
    
    def calculate_damage(self):
        """Calculate damage from dice (same as classic RPG)"""
        if not any(self.game.dice_values):
            return 0
        
        counts = Counter(self.game.dice_values)
        base_damage = 0
        bonus_damage = 0
        
        # Check for combos (silently - already displayed in roll message)
        for value, count in counts.items():
            if count >= 5:
                bonus_damage += value * 20
            elif count == 4:
                bonus_damage += value * 10
            elif count == 3:
                bonus_damage += value * 5
            elif count == 2:
                bonus_damage += value * 2
        
        # Check for Full House
        if len(counts) == 2 and 3 in counts.values() and 2 in counts.values():
            bonus_damage += 50
        
        # Check for Flush (all same)
        if len(counts) == 1 and len(self.game.dice_values) >= 5:
            value = list(counts.keys())[0]
            bonus_damage += value * 15
        
        # Check for Straights
        sorted_dice = sorted(set(self.game.dice_values))
        if sorted_dice == [1,2,3,4,5,6]:
            bonus_damage += 40
        elif len(sorted_dice) >= 4:
            for i in range(len(sorted_dice) - 3):
                if sorted_dice[i:i+4] == list(range(sorted_dice[i], sorted_dice[i]+4)):
                    bonus_damage += 25
                    break
        
        base_damage = sum(self.game.dice_values)
        # Multiplier only applies to base dice damage, not bonuses
        total = int((base_damage * self.game.multiplier) + bonus_damage + self.game.damage_bonus)
        
        return total
