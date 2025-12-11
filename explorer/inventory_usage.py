"""
Inventory Usage Manager

Handles all item usage logic including:
- Consumable items (heal, buff, shield, cleanse)
- Repair kits and broken equipment
- Lore and readable_lore items
- Special items (tokens, tools, keys, upgrades)
- Combat-specific items (throwables, boss drops)
- Utility and quest items
"""

import random
import tkinter as tk


class InventoryUsageManager:
    """Manages item usage and application of item effects"""
    
    def __init__(self, game):
        """Initialize with reference to main game instance"""
        self.game = game
    
    def use_item(self, idx):
        """Use an item from inventory"""
        if idx < 0 or idx >= len(self.game.inventory):
            return
        
        item_name = self.game.inventory[idx]
        
        item_def = self.game.item_definitions.get(item_name, {})
        item_type = item_def.get('type', 'unknown')
        
        # Handle different item types
        if item_type == 'heal':
            # Consumable healing item
            heal_amount = item_def.get('heal', 0)
            old_hp = self.game.health
            self.game.health = min(self.game.health + heal_amount, self.game.max_health)
            actual_heal = self.game.health - old_hp
            self.game.inventory.pop(idx)
            
            # Track stats
            self.game.stats["items_used"] += 1
            self.game.stats["potions_used"] += 1
            
            self.game.log(f"Used {item_name}! Restored {actual_heal} health.", 'loot')
            self.game.close_dialog()
            self.game.update_display()  # Update HP display
            self.game.show_inventory()
            
        elif item_type == 'buff':
            # Temporary combat buffs - can only use in combat
            if not self.game.in_combat:
                self.game.log(f"Can only use {item_name} during combat!", 'system')
                return
            
            # Apply temporary buffs (tracked separately so they can be cleared after combat)
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.game.damage_bonus += bonus
                self.game.temp_combat_damage += bonus
                self.game.log(f"Used {item_name}! +{bonus} damage this combat.", 'loot')
            if 'crit_bonus' in item_def:
                bonus = item_def['crit_bonus']
                self.game.crit_chance += bonus
                self.game.temp_combat_crit += bonus
                self.game.log(f"Used {item_name}! +{int(bonus*100)}% crit chance this combat.", 'loot')
            if 'extra_rolls' in item_def:
                bonus = item_def['extra_rolls']
                self.game.reroll_bonus += bonus
                self.game.temp_combat_rerolls += bonus
                self.game.log(f"Used {item_name}! +{bonus} reroll(s) this combat.", 'loot')
            
            self.game.inventory.pop(idx)
            
            # Track stats
            self.game.stats["items_used"] += 1
            
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'shield':
            # Temporary shield - can only use in combat
            if not self.game.in_combat:
                self.game.log(f"Can only use {item_name} during combat!", 'system')
                return
            
            shield_amount = item_def.get('shield', 0)
            self.game.temp_shield += shield_amount
            self.game.inventory.pop(idx)
            
            # Track stats
            self.game.stats["items_used"] += 1
            
            self.game.log(f"Used {item_name}! Gained {shield_amount} temporary shield.", 'loot')
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'cleanse':
            # Cleanse negative effects
            if self.game.flags.get('statuses', []):
                self.game.flags['statuses'] = []
                self.game.inventory.pop(idx)
                self.game.log(f"Used {item_name}! All negative effects removed.", 'loot')
            else:
                self.game.log(f"No negative effects to cleanse!", 'system')
                return
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'token':
            # Escape/disarm tokens - check if appropriate to use
            if item_def.get('escape_token'):
                # Escape tokens can be saved for later, always usable
                self.game.flags['escape_token'] = self.game.flags.get('escape_token', 0) + 1
                self.game.inventory.pop(idx)
                self.game.log(f"Activated {item_name}! Can escape one punishment/trap.", 'loot')
            elif item_def.get('disarm_token'):
                # Disarm tokens require a trap to be present
                if not self.game.has_trap_in_current_room():
                    self.game.log(f"There are no traps here to disarm with {item_name}!", 'system')
                    return
                self.game.flags['disarm_token'] = self.game.flags.get('disarm_token', 0) + 1
                self.game.inventory.pop(idx)
                self.game.log(f"Activated {item_name}! Can auto-disarm one trap.", 'loot')
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'tool':
            # Tools with disarm capability - require trap to be present
            if item_def.get('disarm_token'):
                if not self.game.has_trap_in_current_room():
                    self.game.log(f"There are no traps or hazards here to use {item_name} on!", 'system')
                    return
                self.game.flags['disarm_token'] = self.game.flags.get('disarm_token', 0) + 1
                self.game.inventory.pop(idx)
                self.game.log(f"Used {item_name}! Can bypass one hazard.", 'loot')
            else:
                self.game.log(f"{item_name} is a narrative tool. Save it for special situations!", 'system')
                return
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'sellable':
            # Can't use - only for selling
            sell_value = item_def.get('sell_value', 0)
            self.game.log(f"{item_name} can't be used. Sell it for {sell_value} gold at a shop!", 'system')
            
        elif item_type == 'repair':
            # Repair kits - restore durability to equipment OR repair broken items
            repair_type = item_def.get('repair_type', 'any')
            repair_percent = item_def.get('repair_percent', 0.40)
            
            # Collect all repairable items
            repairable_items = []
            
            # Check broken items in inventory
            for i, inv_item in enumerate(self.game.inventory):
                if i == idx:  # Skip the repair kit itself
                    continue
                
                # Check if this is a broken item (by name pattern)
                if inv_item.startswith("Broken "):
                    # Recreate broken item definition if missing (can happen after save/load)
                    if inv_item not in self.game.item_definitions:
                        original_item = inv_item.replace("Broken ", "")
                        # Try to determine slot from original item
                        original_def = self.game.item_definitions.get(original_item, {})
                        slot = original_def.get('slot', 'weapon')  # Default to weapon if unknown
                        
                        self.game.item_definitions[inv_item] = {
                            "type": "broken_equipment",
                            "original_item": original_item,
                            "slot": slot,
                            "sell_value": max(1, original_def.get('sell_value', 5) // 2),
                            "desc": f"A broken {original_item}. Can be repaired or sold for scrap."
                        }
                    
                    broken_def = self.game.item_definitions.get(inv_item, {})
                    if broken_def.get('type') == 'broken_equipment':
                        original_item = broken_def.get('original_item')
                        slot = broken_def.get('slot')
                        
                        # Check if repair kit matches this slot
                        if repair_type == 'any' or repair_type == slot:
                            original_def = self.game.item_definitions.get(original_item, {})
                            max_dur = original_def.get('max_durability', 100)
                            restored_dur = int(max_dur * repair_percent)
                            repairable_items.append({
                                'type': 'broken',
                                'index': i,
                                'name': inv_item,
                                'original': original_item,
                                'restore_dur': restored_dur,
                                'display': f"{inv_item} → Restore to {original_item} ({restored_dur} durability)"
                            })
            
            # Check unequipped items in inventory that need repair
            for i, inv_item in enumerate(self.game.inventory):
                if i == idx:  # Skip the repair kit itself
                    continue
                
                # Skip broken items (already handled above)
                if inv_item.startswith("Broken "):
                    continue
                
                # Check if this is equipment with durability
                if inv_item in self.game.equipment_durability:
                    item_def_repair = self.game.item_definitions.get(inv_item, {})
                    item_slot = item_def_repair.get('slot')
                    
                    # Check if repair kit matches this slot
                    if repair_type == 'any' or repair_type == item_slot:
                        max_dur = item_def_repair.get('max_durability', 100)
                        current_dur = self.game.equipment_durability[inv_item]
                        
                        # Only add if not equipped and needs repair
                        is_equipped = inv_item in self.game.equipped_items.values()
                        if not is_equipped and current_dur < max_dur:
                            repair_amount = int(max_dur * repair_percent)
                            new_dur = min(current_dur + repair_amount, max_dur)
                            actual_repair = new_dur - current_dur
                            repairable_items.append({
                                'type': 'inventory',
                                'index': i,
                                'name': inv_item,
                                'current_dur': current_dur,
                                'new_dur': new_dur,
                                'repair_amount': actual_repair,
                                'display': f"{inv_item} - {current_dur}/{max_dur} → {new_dur}/{max_dur} (+{actual_repair})"
                            })
            
            # Check equipped items that need repair
            for slot, equipped_item in self.game.equipped_items.items():
                if not equipped_item:
                    continue
                
                # Check if this item type matches the repair kit
                if repair_type == 'any' or repair_type == slot:
                    if equipped_item in self.game.equipment_durability:
                        equip_def = self.game.item_definitions.get(equipped_item, {})
                        max_dur = equip_def.get('max_durability', 100)
                        current_dur = self.game.equipment_durability[equipped_item]
                        
                        if current_dur < max_dur:
                            repair_amount = int(max_dur * repair_percent)
                            new_dur = min(current_dur + repair_amount, max_dur)
                            actual_repair = new_dur - current_dur
                            repairable_items.append({
                                'type': 'equipped',
                                'slot': slot,
                                'name': equipped_item,
                                'current_dur': current_dur,
                                'new_dur': new_dur,
                                'repair_amount': actual_repair,
                                'display': f"{equipped_item} (equipped) - {current_dur}/{max_dur} → {new_dur}/{max_dur} (+{actual_repair})"
                            })
            
            if not repairable_items:
                if repair_type == 'weapon':
                    self.game.log(f"No weapons that need repairs!", 'system')
                elif repair_type == 'armor':
                    self.game.log(f"No armor that needs repairs!", 'system')
                else:
                    self.game.log(f"No equipment that needs repairs!", 'system')
                return
            
            # Show selection dialog
            self.game.show_repair_selection_dialog(item_name, idx, repair_percent, repairable_items)
            
        elif item_type == 'lore':
            # Simple lore items - just show description
            desc = item_def.get('desc', 'An interesting item.')
            self.game.log(f"◈ {item_name}: {desc}", 'lore')
            
        elif item_type == 'readable_lore':
            # Readable lore items with full narrative content
            # Check if there are multiple copies of this item
            copies_indices = [i for i, inv_item in enumerate(self.game.inventory) if inv_item == item_name]
            
            if len(copies_indices) > 1:
                # Multiple copies - show selection dialog
                self.game.show_lore_selection_dialog(item_name, copies_indices)
            else:
                # Single copy - read directly
                self.game.lore_manager.read_lore_item(item_name, idx)
            
        elif item_type == 'consumable_blessing':
            # Prayer Candle - random blessing
            blessing_type = random.choice(['heal', 'crit', 'gold'])
            if blessing_type == 'heal':
                heal_amount = 15
                old_hp = self.game.health
                self.game.health = min(self.game.health + heal_amount, self.game.max_health)
                actual_heal = self.game.health - old_hp
                self.game.log(f"The Prayer Candle's light washes over you... Restored {actual_heal} health!", 'loot')
            elif blessing_type == 'crit':
                # Store blessing that lasts 3 combats
                self.game.flags['prayer_blessing_combats'] = self.game.flags.get('prayer_blessing_combats', 0) + 3
                self.game.crit_chance += 0.05
                self.game.log(f"The Prayer Candle fills you with confidence... +5% crit chance for 3 combats!", 'loot')
            else:  # gold
                gold_amount = random.randint(5, 10)
                self.game.gold += gold_amount
                self.game.stats["gold_found"] += gold_amount
                self.game.log(f"The Prayer Candle reveals hidden gold... Found {gold_amount} gold!", 'loot')
            
            self.game.inventory.pop(idx)
            self.game.close_dialog()
            self.game.show_inventory()
            self.game.update_display()
            
        elif item_type == 'quest_item':
            # Bounty Poster - can only turn in at stores
            self.game.log(f"{item_name} can be turned in at any store for {item_def.get('gold_reward', 0)} gold!", 'system')
            
        elif item_type == 'combat_consumable':
            # Combat consumables like Fire Potion - need enemy selection
            if not self.game.in_combat:
                self.game.log(f"Can only use {item_name} during combat!", 'system')
                return
            
            if item_name == "Fire Potion":
                # Close inventory and show enemy selection for Fire Potion
                self.game.close_dialog()
                self.game.show_fire_potion_target_selection(idx)
            else:
                self.game.log(f"Combat consumable {item_name} not implemented yet!", 'system')
        
        elif item_type == 'consumable':
            # Generic consumables like Fresh Candle or Health Potion
            effect_type = item_def.get('effect_type', 'unknown')
            
            if effect_type == 'heal':
                # Healing consumable
                heal_amount = item_def.get('effect_value', 20)
                old_hp = self.game.health
                self.game.health = min(self.game.health + heal_amount, self.game.max_health)
                actual_heal = self.game.health - old_hp
                self.game.inventory.pop(idx)
                self.game.log(f"Used {item_name}! Restored {actual_heal} health.", 'loot')
                self.game.close_dialog()
                self.game.show_inventory()
                self.game.update_display()
                
            elif effect_type == 'light':
                # Reveals hidden content or provides light buff
                self.game.flags['has_light'] = True
                self.game.flags['light_duration'] = self.game.flags.get('light_duration', 0) + 3  # 3 rooms
                self.game.inventory.pop(idx)
                self.game.log(f"Used {item_name}! Light reveals hidden paths for the next 3 rooms.", 'loot')
                self.game.close_dialog()
                self.game.show_inventory()
                
            else:
                self.game.log(f"Unknown effect for {item_name}.", 'system')
                
        elif item_type == 'key':
            # Keys - can't be used from inventory, used automatically when entering locked rooms
            if item_name == "Boss Key":
                self.game.log(f"{item_name} will automatically unlock the boss room door when you reach it!", 'system')
            elif item_name == "Old Key":
                self.game.log(f"{item_name} will automatically unlock a locked door when you encounter one!", 'system')
            else:
                self.game.log(f"{item_name} is used automatically. Keep it in your inventory!", 'system')
            
        elif item_type == 'upgrade':
            # Permanent upgrades - apply immediately
            applied = False
            if 'max_hp_bonus' in item_def:
                bonus = item_def['max_hp_bonus']
                self.game.max_health += bonus
                self.game.health += bonus  # Also heal by that amount
                self.game.log(f"Used {item_name}! Maximum HP permanently increased by {bonus}!", 'success')
                applied = True
                
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.game.damage_bonus += bonus
                self.game.log(f"Used {item_name}! Damage permanently increased by {bonus}!", 'success')
                applied = True
                
            if 'reroll_bonus' in item_def:
                bonus = item_def['reroll_bonus']
                self.game.reroll_bonus += bonus
                self.game.log(f"Used {item_name}! Rerolls permanently increased by {bonus}!", 'success')
                applied = True
                
            if 'crit_bonus' in item_def:
                bonus = item_def['crit_bonus']
                self.game.crit_chance += bonus
                self.game.log(f"Used {item_name}! Crit chance permanently increased by {int(bonus*100)}%!", 'success')
                applied = True
            
            if applied:
                self.game.inventory.pop(idx)
                self.game.close_dialog()
                self.game.show_inventory()
                self.game.update_display()
            else:
                self.game.log(f"Unknown upgrade type for {item_name}.", 'system')
            
        elif item_type == 'throwable':
            # Throwable items - one-time use weapon that doesn't consume your turn
            if not self.game.in_combat:
                self.game.log(f"Can only use {item_name} during combat!", 'system')
                return
            
            damage = item_def.get('damage', 5)
            self.game.log(f"You throw {item_name} at {self.game.enemy_name}!", 'player')
            self.game.log(f"Damage: {damage}", 'player')
            
            # Apply damage to both legacy enemy_health AND enemies list
            self.game.enemy_health -= damage
            if self.game.enemies and len(self.game.enemies) > 0:
                target_enemy = self.game.enemies[self.game.current_enemy_index]
                target_enemy["health"] -= damage
            
            self.game.inventory.pop(idx)
            
            if self.game.enemy_health <= 0:
                self.game.close_dialog()
                self.game.enemy_defeated()
            else:
                self.game.log(f"Enemy HP: {max(0, self.game.enemy_health)}/{self.game.enemy_max_health}", 'enemy')
                self.game.log(f"Throwable item used! You still have your attack turn.", 'system')
                self.game.close_dialog()
                self.game.show_inventory()  # Refresh inventory instead of taking enemy turn
        
        elif item_type == 'utility':
            # Narrative/utility items - no immediate effect
            desc = item_def.get('desc', 'A utility item.')
            self.game.log(f"{item_name}: {desc}", 'system')
            self.game.log(f"This item may be useful in specific situations. Keep it in your inventory!", 'system')
            
        elif item_type == 'status_buff':
            # Status protection buffs (like Goggles, Ear Pad)
            status = item_def.get('status', '')
            duration = item_def.get('duration', 'floor')
            
            self.game.flags[f'protection_{status}'] = True
            if duration == 'floor':
                self.game.flags[f'protection_{status}_floor'] = self.game.floor
                
            self.game.inventory.pop(idx)
            self.game.log(f"Used {item_name}! Protected from {status} for this floor.", 'loot')
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'boss_drop':
            # Boss drop items - combat buffs similar to regular buffs
            if not self.game.in_combat:
                self.game.log(f"Can only use {item_name} during combat!", 'system')
                return
            
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.game.damage_bonus += bonus
                self.game.temp_combat_damage += bonus
                self.game.log(f"Used {item_name}! +{bonus} damage this combat.", 'loot')
                
            if 'extra_rolls' in item_def:
                bonus = item_def['extra_rolls']
                self.game.reroll_bonus += bonus
                self.game.temp_combat_rerolls += bonus
                self.game.log(f"Used {item_name}! +{bonus} reroll(s) this combat.", 'loot')
                
            if 'gold_mult' in item_def:
                self.game.flags['gold_bonus_multiplier'] = item_def['gold_mult']
                self.game.log(f"Used {item_name}! Gold gains increased by {int(item_def['gold_mult']*100)}% this combat!", 'loot')
                
            if 'gold_flat' in item_def:
                gold_amount = item_def['gold_flat']
                self.game.gold += gold_amount
                self.game.stats["gold_found"] += gold_amount
                self.game.log(f"Used {item_name}! Gained {gold_amount} gold!", 'loot')
                
            self.game.inventory.pop(idx)
            self.game.close_dialog()
            self.game.show_inventory()
            self.game.update_display()
            
        elif item_type == 'trap_aid':
            # Items that help with traps - apply bonuses
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.game.damage_bonus += bonus
                self.game.temp_combat_damage += bonus
                self.game.log(f"Used {item_name}! +{bonus} damage.", 'loot')
                
            if 'extra_rolls' in item_def:
                bonus = item_def['extra_rolls']
                self.game.reroll_bonus += bonus
                self.game.temp_combat_rerolls += bonus
                self.game.log(f"Used {item_name}! +{bonus} reroll(s).", 'loot')
                
            self.game.inventory.pop(idx)
            self.game.close_dialog()
            self.game.show_inventory()
            
        elif item_type == 'broken_equipment':
            # Broken equipment - can't be used, needs repair
            self.game.log(f"{item_name} is broken! Use a Repair Kit to fix it, or sell it for scrap.", 'system')
            
        elif item_type == 'equipment':
            # Equipment items - handled by separate equip/unequip system
            self.game.log(f"{item_name} is equipment. Use the Equipment menu to equip it!", 'system')
        
        else:
            self.game.log(f"Cannot use {item_name}.", 'system')
