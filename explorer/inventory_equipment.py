"""
Inventory Equipment Manager - Part 2 of Inventory System

Handles all inventory item interactions and equipment management:
- Pick up all ground items (batch collection)
- Drop items from inventory
- Add items to inventory with floor tracking
- Equip/unequip items with validation
- Apply/remove equipment bonuses with floor scaling
"""

import tkinter as tk


class InventoryEquipmentManager:
    """Manages inventory item interactions and equipment"""
    
    def __init__(self, game):
        """Initialize with reference to main game instance"""
        self.game = game
    
    def pickup_all_ground_items(self):
        """Take all items from ground (gold + loose items + uncollected + dropped, but NOT containers)"""
        items_taken = 0
        
        # Pick up gold
        if self.game.current_room.ground_gold > 0:
            amount = self.game.current_room.ground_gold
            self.game.gold += amount
            self.game.total_gold_earned += amount
            self.game.stats["gold_found"] += amount
            self.game.log(f"Picked up {amount} gold!", 'loot')
            self.game.current_room.ground_gold = 0
            items_taken += 1
        
        # Pick up loose items
        for item in self.game.current_room.ground_items[:]:
            if len(self.game.inventory) >= self.game.max_inventory:
                break
            self.game.current_room.ground_items.remove(item)
            self.game.try_add_to_inventory(item, "ground")
            items_taken += 1
        
        # NOTE: Containers are NOT auto-searched by "Take All" - they must be manually searched
        
        # Pick up all uncollected items (stop if inventory gets full)
        if hasattr(self.game.current_room, 'uncollected_items'):
            while self.game.current_room.uncollected_items and len(self.game.inventory) < self.game.max_inventory:
                item = self.game.current_room.uncollected_items[0]
                count_before = len(self.game.inventory)
                self.game.pickup_uncollected_item(item, skip_refresh=True)
                
                # If item is still in list, inventory must be full - break to avoid infinite loop
                if item in self.game.current_room.uncollected_items:
                    break
                    
                # Only count if inventory increased
                if len(self.game.inventory) > count_before:
                    items_taken += 1
        
        # Pick up all dropped items (stop if inventory gets full)
        if hasattr(self.game.current_room, 'dropped_items'):
            while self.game.current_room.dropped_items and len(self.game.inventory) < self.game.max_inventory:
                item = self.game.current_room.dropped_items[0]
                count_before = len(self.game.inventory)
                self.game.pickup_dropped_item(item, skip_refresh=True)
                
                # If item is still in list, inventory must be full - break to avoid infinite loop
                if item in self.game.current_room.dropped_items:
                    break
                    
                # Only count if inventory increased
                if len(self.game.inventory) > count_before:
                    items_taken += 1
        
        # Show result and close
        if items_taken > 0:
            self.game.log(f"✓ Collected {items_taken} item(s).", 'success')
        
        # Calculate pickupable items left on ground (excluding containers)
        pickupable_items_left = 0
        if self.game.current_room.ground_gold > 0:
            pickupable_items_left += 1
        pickupable_items_left += len(self.game.current_room.ground_items)
        pickupable_items_left += len(self.game.current_room.uncollected_items) if hasattr(self.game.current_room, 'uncollected_items') else 0
        pickupable_items_left += len(self.game.current_room.dropped_items) if hasattr(self.game.current_room, 'dropped_items') else 0
        
        # Show notification ONLY if inventory is full AND pickupable items were left behind
        if pickupable_items_left > 0 and len(self.game.inventory) >= self.game.max_inventory:
            self.game.log(f"❌ INVENTORY FULL! {pickupable_items_left} item(s) left on ground.", 'system')
        
        # Update display once at the end
        self.game.update_display()
        
        # Only close dialog if no items left on ground (including container)
        total_items_on_ground = pickupable_items_left
        if self.game.current_room.ground_container and not self.game.current_room.container_searched:
            total_items_on_ground += 1
        
        if total_items_on_ground > 0:
            # Refresh the ground items display to show updated state
            self.game.show_ground_items()
            self.game.show_exploration_options()  # Update button count
        else:
            # Close dialog and refresh exploration view only if ground is empty
            self.game.close_dialog()
            self.game.show_exploration_options()
    
    def drop_item(self, idx):
        """Drop item from inventory"""
        if 0 <= idx < len(self.game.inventory):
            item_name = self.game.inventory[idx]
            
            # Check if item is equipped
            for slot, equipped in self.game.equipped_items.items():
                if equipped == item_name:
                    self.game.log(f"Cannot drop equipped item! Unequip {item_name} first.", 'system')
                    return
            
            # Remove from inventory and add to current room's dropped items
            removed_item = self.game.inventory.pop(idx)
            
            # Initialize dropped_items if not present (for old saves)
            if not hasattr(self.game.current_room, 'dropped_items'):
                self.game.current_room.dropped_items = []
            
            self.game.current_room.dropped_items.append(removed_item)
            self.game.log(f"▢ Dropped {removed_item} in this room ({len(self.game.inventory)}/{self.game.max_inventory})", 'system')
            self.game.update_display()
            
            # Refresh exploration options so dropped item appears immediately
            self.game.show_exploration_options()
            # Then reopen inventory on top
            self.game.show_inventory()
    
    def add_item_to_inventory(self, item_name):
        """Add item to inventory and track floor level for equipment"""
        self.game.inventory.append(item_name)
        
        # Track floor level for equipment items
        item_def = self.game.item_definitions.get(item_name, {})
        if item_def.get('type') == 'equipment':
            self.game.equipment_floor_level[item_name] = self.game.floor
    
    def equip_item(self, item_name, slot):
        """Equip an item to a slot"""
        if item_name not in self.game.inventory:
            self.game.log(f"[ERROR] {item_name} not in inventory!", 'system')
            return
        
        # Validate slot
        if slot not in self.game.equipped_items:
            self.game.log(f"[ERROR] Invalid equipment slot: {slot}", 'system')
            return
        
        # Get item definition to check for bonuses
        item_def = self.game.item_definitions.get(item_name, {})
        item_slot = item_def.get('slot', None)
        
        # Verify item's slot matches the requested slot
        if item_slot != slot:
            self.game.log(f"[ERROR] {item_name} cannot be equipped to {slot} slot (requires {item_slot})", 'system')
            return
        
        # Check if this exact item is already equipped somewhere
        for existing_slot, existing_item in self.game.equipped_items.items():
            if existing_item == item_name:
                self.game.log(f"[SYSTEM] {item_name} is already equipped in {existing_slot} slot", 'system')
                return
        
        # Unequip current item in slot if exists
        if self.game.equipped_items[slot]:
            old_item = self.game.equipped_items[slot]
            self.remove_equipment_bonuses(old_item)
            self.game.log(f"Unequipped {old_item}", 'system')
        
        # Equip new item
        self.game.equipped_items[slot] = item_name
        
        # Initialize durability ONLY if this item doesn't have durability tracked yet
        # This prevents the exploit of unequipping/re-equipping to restore durability
        item_def = self.game.item_definitions.get(item_name, {})
        if item_name not in self.game.equipment_durability:
            max_dur = item_def.get('max_durability', 100)
            self.game.equipment_durability[item_name] = max_dur
        
        self.apply_equipment_bonuses(item_name)
        self.game.log(f"Equipped {item_name} to {slot} slot!", 'success')
        
        self.game.update_display()
        self.game.show_inventory()  # Refresh
    
    def unequip_item(self, slot):
        """Unequip an item from a slot"""
        if slot not in self.game.equipped_items:
            self.game.log(f"[ERROR] Invalid equipment slot: {slot}", 'system')
            return
            
        if not self.game.equipped_items.get(slot):
            self.game.log(f"[SYSTEM] No item equipped in {slot} slot", 'system')
            return
        
        item_name = self.game.equipped_items[slot]
        
        # Verify item is still in inventory (shouldn't be removed)
        if item_name not in self.game.inventory:
            self.game.log(f"[ERROR] {item_name} not found in inventory!", 'system')
            self.game.equipped_items[slot] = None  # Clear the slot anyway
            return
        
        self.remove_equipment_bonuses(item_name)
        self.game.equipped_items[slot] = None
        self.game.log(f"Unequipped {item_name} from {slot} slot", 'system')
        
        self.game.update_display()
        self.game.show_inventory()  # Refresh
    
    def apply_equipment_bonuses(self, item_name, skip_hp=False):
        """Apply bonuses from equipped item with floor scaling"""
        if item_name not in self.game.item_definitions:
            return
        
        item_def = self.game.item_definitions[item_name]
        
        # Get floor level for scaling (default to current floor if not tracked)
        floor_level = self.game.equipment_floor_level.get(item_name, self.game.floor)
        floor_bonus = max(0, floor_level - 1)  # Floor 1 = no bonus, Floor 2 = +1, etc.
        
        # Apply bonuses based on item properties with floor scaling
        if 'damage_bonus' in item_def:
            base_damage = item_def['damage_bonus']
            scaled_damage = base_damage + floor_bonus  # +1 per floor after 1
            self.game.damage_bonus += scaled_damage
        if 'crit_bonus' in item_def:
            self.game.crit_chance += item_def['crit_bonus']
        # Skip reroll_bonus for combat ability items like Mystic Ring
        if 'reroll_bonus' in item_def and 'combat_ability' not in item_def:
            self.game.reroll_bonus += item_def['reroll_bonus']
        if 'max_hp_bonus' in item_def and not skip_hp:
            base_hp = item_def['max_hp_bonus']
            scaled_hp = base_hp + (floor_bonus * 3)  # +3 HP per floor after 1
            self.game.max_health += scaled_hp
            # Don't heal when equipping - only increase max HP capacity
        if 'armor_bonus' in item_def:
            self.game.armor += item_def['armor_bonus']
        if 'inventory_bonus' in item_def:
            self.game.max_inventory += item_def['inventory_bonus']
        
        # Initialize durability for equipment
        max_durability = item_def.get('max_durability', 100)  # Default 100 durability
        if item_name not in self.game.equipment_durability:
            self.game.equipment_durability[item_name] = max_durability
    
    def remove_equipment_bonuses(self, item_name):
        """Remove bonuses from unequipped item with floor scaling"""
        if item_name not in self.game.item_definitions:
            return
        
        item_def = self.game.item_definitions[item_name]
        
        # Get floor level for scaling (default to current floor if not tracked)
        floor_level = self.game.equipment_floor_level.get(item_name, self.game.floor)
        floor_bonus = max(0, floor_level - 1)  # Floor 1 = no bonus, Floor 2 = +1, etc.
        
        # Remove bonuses with floor scaling
        if 'damage_bonus' in item_def:
            base_damage = item_def['damage_bonus']
            scaled_damage = base_damage + floor_bonus
            self.game.damage_bonus -= scaled_damage
        if 'crit_bonus' in item_def:
            self.game.crit_chance -= item_def['crit_bonus']
        # Skip reroll_bonus for combat ability items like Mystic Ring
        if 'reroll_bonus' in item_def and 'combat_ability' not in item_def:
            self.game.reroll_bonus -= item_def['reroll_bonus']
        if 'max_hp_bonus' in item_def:
            base_hp = item_def['max_hp_bonus']
            scaled_hp = base_hp + (floor_bonus * 3)
            self.game.max_health -= scaled_hp
            # Don't reduce current HP below 1
            self.game.health = max(1, min(self.game.health, self.game.max_health))
        if 'armor_bonus' in item_def:
            self.game.armor -= item_def['armor_bonus']
        if 'inventory_bonus' in item_def:
            self.game.max_inventory -= item_def['inventory_bonus']
