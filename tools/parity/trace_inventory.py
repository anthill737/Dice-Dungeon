#!/usr/bin/env python3
"""
Inventory parity trace generator (Python side).

Runs headless inventory/equipment/store operations with a portable LCG RNG
that produces identical sequences in both Python and Godot, enabling exact
parity checks.

Usage:
    python3 tools/parity/trace_inventory.py <seed> <actions> [floor]

    seed    - integer seed for the portable LCG
    actions - comma-separated action list, e.g. "pickup,equip,use_heal,sell"
    floor   - floor index (int, default 1)

Outputs JSON trace to stdout.

Supported actions:
    pickup:<item>         - add item to inventory
    equip:<item>:<slot>   - equip item to slot
    unequip:<slot>        - unequip from slot
    use:<index>           - use item at inventory index
    degrade:<item>:<amt>  - degrade durability on equipped item
    repair:<kit>:<target> - use repair kit on target item
    buy:<item>            - buy item from store at its store price
    sell:<item>           - sell item from inventory
    upgrade:<name>        - buy a permanent upgrade from store
    set_gold:<amount>     - set gold to a specific amount
    set_combat:<0|1>      - set in_combat flag
    add_status:<name>     - add a status effect
    snapshot              - capture current state (always captured at end)
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


# ---------------------------------------------------------------------------
# Portable LCG — identical to Godot PortableLCG
# ---------------------------------------------------------------------------

class PortableLCG:
    MODULUS = (1 << 31) - 1
    MULTIPLIER = 48271

    def __init__(self, seed: int):
        self._state = seed % self.MODULUS
        if self._state == 0:
            self._state = 1

    def _next(self) -> int:
        self._state = (self._state * self.MULTIPLIER) % self.MODULUS
        return self._state

    def random(self) -> float:
        return self._next() / self.MODULUS

    def randint(self, a: int, b: int) -> int:
        return a + (self._next() % (b - a + 1))

    def choice(self, seq):
        idx = self._next() % len(seq)
        return seq[idx]


# ---------------------------------------------------------------------------
# Headless inventory/equipment/store engine
# ---------------------------------------------------------------------------

class HeadlessInventoryGame:
    def __init__(self, rng, items_db, floor_num):
        self.rng = rng
        self.item_definitions = items_db
        self.floor = floor_num

        # Player state
        self.health = 50
        self.max_health = 50
        self.gold = 0
        self.total_gold_earned = 0
        self.damage_bonus = 0
        self.crit_chance = 0.1
        self.reroll_bonus = 0
        self.armor = 0
        self.temp_shield = 0
        self.max_inventory = 20
        self.in_combat = False

        # Inventory
        self.inventory = []
        self.equipped_items = {"weapon": None, "armor": None, "accessory": None, "backpack": None}
        self.equipment_durability = {}
        self.equipment_floor_level = {}

        # Combat temps
        self.temp_combat_damage = 0
        self.temp_combat_crit = 0.0
        self.temp_combat_rerolls = 0

        # Store
        self.purchased_upgrades_this_floor = set()
        self.num_dice = 3
        self.max_dice = 5

        # Stats
        self.stats = {
            "items_used": 0,
            "potions_used": 0,
            "items_found": 0,
            "items_sold": 0,
            "items_purchased": 0,
            "gold_found": 0,
            "gold_spent": 0,
            "containers_searched": 0,
        }

        # Flags
        self.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}

        self._logs = []

    def log(self, msg):
        self._logs.append(str(msg))

    # --- Snapshot ---

    def snapshot(self):
        equipped = {}
        for slot, item in self.equipped_items.items():
            equipped[slot] = item if item else ""

        durability = {}
        for item, dur in self.equipment_durability.items():
            durability[item] = dur

        return {
            "inventory": list(self.inventory),
            "equipped": equipped,
            "durability": durability,
            "gold": self.gold,
            "health": self.health,
            "max_health": self.max_health,
            "damage_bonus": self.damage_bonus,
            "crit_chance": round(self.crit_chance, 4),
            "reroll_bonus": self.reroll_bonus,
            "armor": self.armor,
            "temp_shield": self.temp_shield,
            "max_inventory": self.max_inventory,
            "statuses": list(self.flags.get("statuses", [])),
            "num_dice": self.num_dice,
            "stats": dict(self.stats),
        }

    # --- Add item ---

    def add_item(self, item_name, source="found"):
        if len(self.inventory) >= self.max_inventory:
            self.log(f"Inventory full! Cannot add {item_name}.")
            return False
        self.inventory.append(item_name)
        if source in ["found", "reward", "chest", "ground"]:
            self.stats["items_found"] += 1
        item_def = self.item_definitions.get(item_name, {})
        if item_def.get("type") == "equipment":
            self.equipment_floor_level[item_name] = self.floor
        return True

    # --- Equip ---

    def equip_item(self, item_name, slot):
        if item_name not in self.inventory:
            self.log(f"{item_name} not in inventory!")
            return

        item_def = self.item_definitions.get(item_name, {})
        item_slot = item_def.get("slot", None)
        if item_slot != slot:
            self.log(f"{item_name} cannot go in {slot} slot.")
            return

        for existing_slot, existing_item in self.equipped_items.items():
            if existing_item == item_name:
                self.log(f"{item_name} is already equipped in {existing_slot}")
                return

        if slot not in self.equipped_items:
            self.log(f"Invalid slot: {slot}")
            return

        old_item = self.equipped_items[slot]
        if old_item:
            self.remove_equipment_bonuses(old_item)
            self.log(f"Unequipped {old_item}")

        self.equipped_items[slot] = item_name

        if item_name not in self.equipment_durability:
            max_dur = item_def.get("max_durability", 100)
            self.equipment_durability[item_name] = max_dur

        self.apply_equipment_bonuses(item_name)
        self.log(f"Equipped {item_name} to {slot} slot!")

    # --- Unequip ---

    def unequip_item(self, slot):
        if slot not in self.equipped_items:
            return
        item_name = self.equipped_items.get(slot)
        if not item_name:
            return
        if item_name not in self.inventory:
            self.equipped_items[slot] = None
            return
        self.remove_equipment_bonuses(item_name)
        self.equipped_items[slot] = None
        self.log(f"Unequipped {item_name} from {slot}")

    # --- Equipment bonuses (mirrors Python exactly) ---

    def apply_equipment_bonuses(self, item_name, skip_hp=False):
        item_def = self.item_definitions.get(item_name, {})
        if not item_def:
            return

        floor_level = self.equipment_floor_level.get(item_name, self.floor)
        floor_bonus = max(0, floor_level - 1)

        if 'damage_bonus' in item_def:
            base_damage = item_def['damage_bonus']
            scaled_damage = base_damage + floor_bonus
            self.damage_bonus += scaled_damage
        if 'crit_bonus' in item_def:
            self.crit_chance += item_def['crit_bonus']
        if 'reroll_bonus' in item_def and 'combat_ability' not in item_def:
            self.reroll_bonus += item_def['reroll_bonus']
        if 'max_hp_bonus' in item_def and not skip_hp:
            base_hp = item_def['max_hp_bonus']
            scaled_hp = base_hp + (floor_bonus * 3)
            self.max_health += scaled_hp
            self.health += scaled_hp
        if 'armor_bonus' in item_def:
            self.armor += item_def['armor_bonus']
        if 'inventory_bonus' in item_def:
            self.max_inventory += item_def['inventory_bonus']

        if item_name not in self.equipment_durability:
            max_dur = item_def.get('max_durability', 100)
            self.equipment_durability[item_name] = max_dur

    def remove_equipment_bonuses(self, item_name):
        item_def = self.item_definitions.get(item_name, {})
        if not item_def:
            return

        floor_level = self.equipment_floor_level.get(item_name, self.floor)
        floor_bonus = max(0, floor_level - 1)

        if 'damage_bonus' in item_def:
            base_damage = item_def['damage_bonus']
            scaled_damage = base_damage + floor_bonus
            self.damage_bonus -= scaled_damage
        if 'crit_bonus' in item_def:
            self.crit_chance -= item_def['crit_bonus']
        if 'reroll_bonus' in item_def and 'combat_ability' not in item_def:
            self.reroll_bonus -= item_def['reroll_bonus']
        if 'max_hp_bonus' in item_def:
            base_hp = item_def['max_hp_bonus']
            scaled_hp = base_hp + (floor_bonus * 3)
            self.max_health -= scaled_hp
            self.health = max(1, self.health - scaled_hp)
            self.health = min(self.health, self.max_health)
        if 'armor_bonus' in item_def:
            self.armor -= item_def['armor_bonus']
        if 'inventory_bonus' in item_def:
            self.max_inventory -= item_def['inventory_bonus']

    # --- Durability ---

    def degrade_durability(self, item_name, amount=1):
        if item_name not in self.equipment_durability:
            return
        self.equipment_durability[item_name] = max(0, self.equipment_durability[item_name] - amount)
        if self.equipment_durability[item_name] <= 0:
            self._break_equipment(item_name)

    def _break_equipment(self, item_name):
        slot_found = None
        for slot, item in self.equipped_items.items():
            if item == item_name:
                slot_found = slot
                break

        if slot_found:
            self.remove_equipment_bonuses(item_name)
            self.equipped_items[slot_found] = None

        idx = self.inventory.index(item_name) if item_name in self.inventory else -1
        if idx >= 0:
            self.inventory[idx] = "Broken " + item_name

        del self.equipment_durability[item_name]

        item_def = self.item_definitions.get(item_name, {})
        broken_name = "Broken " + item_name
        if broken_name not in self.item_definitions:
            self.item_definitions[broken_name] = {
                "type": "broken_equipment",
                "original_item": item_name,
                "slot": item_def.get("slot", "weapon"),
                "sell_value": max(1, item_def.get("sell_value", 5) // 2),
                "desc": f"A broken {item_name}. Can be repaired or sold for scrap.",
            }

        self.log(f"{item_name} has broken!")

    # --- Repair ---

    def repair_item(self, kit_name, kit_idx, target_name):
        kit_def = self.item_definitions.get(kit_name, {})
        if kit_def.get("type") != "repair":
            return

        repair_type = kit_def.get("repair_type", "any")
        repair_percent = kit_def.get("repair_percent", 0.40)

        if target_name.startswith("Broken "):
            self._repair_broken(kit_idx, target_name, repair_type, repair_percent)
        else:
            self._repair_durability(kit_idx, target_name, repair_type, repair_percent)

    def _repair_broken(self, kit_idx, broken_name, repair_type, repair_pct):
        broken_def = self.item_definitions.get(broken_name, {})
        if broken_def.get("type") != "broken_equipment":
            return

        original = broken_def.get("original_item", "")
        slot = broken_def.get("slot", "")

        if repair_type != "any" and repair_type != slot:
            return

        original_def = self.item_definitions.get(original, {})
        max_dur = original_def.get("max_durability", 100)
        restored_dur = int(max_dur * repair_pct)

        broken_idx = self.inventory.index(broken_name) if broken_name in self.inventory else -1
        if broken_idx < 0:
            return

        self.inventory[broken_idx] = original
        self.equipment_durability[original] = restored_dur
        self.equipment_floor_level[original] = self.floor

        # Remove repair kit
        if kit_idx < len(self.inventory):
            self.inventory.pop(kit_idx)

        self.stats["items_used"] += 1
        self.log(f"Repaired {broken_name}! Restored to {original} ({restored_dur} durability)")

    def _repair_durability(self, kit_idx, item_name, repair_type, repair_pct):
        item_def = self.item_definitions.get(item_name, {})
        item_slot = item_def.get("slot", "")

        if repair_type != "any" and repair_type != item_slot:
            return

        if item_name not in self.equipment_durability:
            return

        max_dur = item_def.get("max_durability", 100)
        current_dur = self.equipment_durability[item_name]

        if current_dur >= max_dur:
            return

        repair_amount = int(max_dur * repair_pct)
        new_dur = min(current_dur + repair_amount, max_dur)

        self.equipment_durability[item_name] = new_dur

        if kit_idx < len(self.inventory):
            self.inventory.pop(kit_idx)

        self.stats["items_used"] += 1
        self.log(f"Repaired {item_name}: {current_dur} → {new_dur}")

    # --- Use item ---

    def use_item(self, idx):
        if idx < 0 or idx >= len(self.inventory):
            return

        item_name = self.inventory[idx]
        base_name = item_name.split(' #')[0] if ' #' in item_name else item_name
        item_def = self.item_definitions.get(base_name, {})
        item_type = item_def.get('type', 'unknown')

        if item_type == 'heal':
            heal_amount = item_def.get('heal', 0)
            old_hp = self.health
            self.health = min(self.health + heal_amount, self.max_health)
            self.inventory.pop(idx)
            self.stats["items_used"] += 1
            self.stats["potions_used"] += 1

        elif item_type == 'buff':
            if not self.in_combat:
                return
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.damage_bonus += bonus
                self.temp_combat_damage += bonus
            if 'crit_bonus' in item_def:
                bonus = item_def['crit_bonus']
                self.crit_chance += bonus
                self.temp_combat_crit += bonus
            if 'extra_rolls' in item_def:
                bonus = item_def['extra_rolls']
                self.reroll_bonus += bonus
                self.temp_combat_rerolls += bonus
            self.inventory.pop(idx)
            self.stats["items_used"] += 1

        elif item_type == 'shield':
            if not self.in_combat:
                return
            shield_amount = item_def.get('shield', 0)
            self.temp_shield += shield_amount
            self.inventory.pop(idx)
            self.stats["items_used"] += 1

        elif item_type == 'cleanse':
            if self.flags.get('statuses', []):
                self.flags['statuses'] = []
                self.inventory.pop(idx)
                self.stats["items_used"] += 1

        elif item_type == 'consumable_blessing':
            blessing_type = self.rng.choice(['heal', 'crit', 'gold'])
            if blessing_type == 'heal':
                old_hp = self.health
                self.health = min(self.health + 15, self.max_health)
            elif blessing_type == 'crit':
                self.flags['prayer_blessing_combats'] = self.flags.get('prayer_blessing_combats', 0) + 3
                self.crit_chance += 0.05
            else:
                gold_amount = self.rng.randint(5, 10)
                self.gold += gold_amount
                self.stats["gold_found"] += gold_amount
            self.inventory.pop(idx)
            self.stats["items_used"] += 1

        elif item_type == 'upgrade':
            applied = False
            if 'max_hp_bonus' in item_def:
                bonus = item_def['max_hp_bonus']
                self.max_health += bonus
                self.health += bonus
                applied = True
            if 'damage_bonus' in item_def:
                bonus = item_def['damage_bonus']
                self.damage_bonus += bonus
                applied = True
            if 'reroll_bonus' in item_def:
                bonus = item_def['reroll_bonus']
                self.reroll_bonus += bonus
                applied = True
            if 'crit_bonus' in item_def:
                bonus = item_def['crit_bonus']
                self.crit_chance += bonus
                applied = True
            if applied:
                self.inventory.pop(idx)
                self.stats["items_used"] += 1

    # --- Store: sell price calculation ---

    def calculate_sell_price(self, item_name):
        buy_price = 0
        floor_val = self.floor
        price_map = {
            "Health Potion": 30 + (floor_val * 5),
            "Extra Die": 100 + (floor_val * 20),
            "Lucky Chip": 70 + (floor_val * 15),
            "Honey Jar": 20 + (floor_val * 4),
            "Healing Poultice": 50 + (floor_val * 10),
            "Weighted Die": 60 + (floor_val * 15),
            "Lockpick Kit": 50 + (floor_val * 10),
            "Conductor Rod": 70 + (floor_val * 15),
            "Hourglass Shard": 80 + (floor_val * 20),
            "Tuner's Hammer": 85 + (floor_val * 22),
            "Cooled Ember": 90 + (floor_val * 23),
            "Blue Quartz": 90 + (floor_val * 20),
            "Silk Bundle": 120 + (floor_val * 30),
            "Disarm Token": 150,
            "Antivenom Leaf": 40 + (floor_val * 10),
            "Smoke Pot": 55 + (floor_val * 12),
            "Black Candle": 65 + (floor_val * 15),
            "Iron Sword": 120 + (floor_val * 30),
            "Steel Dagger": 100 + (floor_val * 25),
            "Hand Axe": 120 + (floor_val * 30),
            "War Axe": 180 + (floor_val * 40),
            "Rapier": 160 + (floor_val * 35),
            "Greatsword": 280 + (floor_val * 60),
            "Assassin's Blade": 260 + (floor_val * 55),
            "Leather Armor": 110 + (floor_val * 28),
            "Chain Vest": 130 + (floor_val * 32),
            "Plate Armor": 220 + (floor_val * 50),
            "Dragon Scale": 300 + (floor_val * 65),
            "Traveler's Pack": 100 + (floor_val * 25),
            "Merchant's Satchel": 180 + (floor_val * 40),
            "Lucky Coin": 140 + (floor_val * 35),
            "Mystic Ring": 150 + (floor_val * 38),
            "Crown of Fortune": 250 + (floor_val * 55),
            "Timekeeper's Watch": 270 + (floor_val * 58),
        }

        if item_name in price_map:
            buy_price = price_map[item_name]
        elif item_name in self.item_definitions:
            item_data = self.item_definitions[item_name]
            if 'sell_value' in item_data:
                return item_data['sell_value']
            rarity = item_data.get('rarity', 'common').lower()
            base_prices = {
                'common': 30, 'uncommon': 60, 'rare': 120,
                'epic': 250, 'legendary': 500
            }
            buy_price = base_prices.get(rarity, 30)
        else:
            buy_price = 20

        return max(5, buy_price // 2)

    # --- Store: buy ---

    def store_buy(self, item_name, price):
        if self.gold < price:
            return

        item_def = self.item_definitions.get(item_name, {})
        item_type = item_def.get('type', '')

        if item_name == "Extra Die":
            if self.num_dice >= self.max_dice:
                return
            self.num_dice += 1
            self.purchased_upgrades_this_floor.add(item_name)
            self.gold -= price
            self.stats["gold_spent"] += price
            self.stats["items_purchased"] += 1
            return

        if item_type == "upgrade":
            if 'max_hp_bonus' in item_def:
                bonus = item_def['max_hp_bonus']
                self.max_health += bonus
                self.health += bonus
            if 'damage_bonus' in item_def:
                self.damage_bonus += item_def['damage_bonus']
            if 'reroll_bonus' in item_def:
                self.reroll_bonus += item_def['reroll_bonus']
            if 'crit_bonus' in item_def:
                self.crit_chance += item_def['crit_bonus']
            self.purchased_upgrades_this_floor.add(item_name)
            self.gold -= price
            self.stats["gold_spent"] += price
            self.stats["items_purchased"] += 1
            return

        if item_type == "equipment":
            if len(self.inventory) >= self.max_inventory:
                return
            self.inventory.append(item_name)
            max_dur = item_def.get('max_durability', 100)
            self.equipment_durability[item_name] = max_dur
            self.equipment_floor_level[item_name] = self.floor
            self.gold -= price
            self.stats["gold_spent"] += price
            self.stats["items_purchased"] += 1
            return

        # Consumable
        if len(self.inventory) >= self.max_inventory:
            return
        self.inventory.append(item_name)
        self.stats["items_found"] += 1
        self.gold -= price
        self.stats["gold_spent"] += price
        self.stats["items_purchased"] += 1

    # --- Store: sell ---

    def store_sell(self, item_name):
        if item_name not in self.inventory:
            return

        is_equipped = item_name in self.equipped_items.values()
        count = self.inventory.count(item_name)
        if is_equipped and count <= 1:
            return

        item_def = self.item_definitions.get(item_name, {})
        item_type = item_def.get('type', '')

        if item_type == 'quest_item':
            quest_reward = item_def.get('gold_reward', 0)
            self.inventory.remove(item_name)
            self.gold += quest_reward
            self.total_gold_earned += quest_reward
            return

        sell_price = self.calculate_sell_price(item_name)
        self.inventory.remove(item_name)
        self.gold += sell_price
        self.total_gold_earned += sell_price
        self.stats["items_sold"] += 1

    # --- Store inventory ---

    def generate_store_inventory(self):
        store_items = []
        effective_floor = max(1, self.floor)

        store_items.append(("Health Potion", 30 + (effective_floor * 5)))
        store_items.append(("Weapon Repair Kit", 60 + (effective_floor * 15)))
        store_items.append(("Armor Repair Kit", 60 + (effective_floor * 15)))

        if effective_floor >= 5:
            store_items.append(("Master Repair Kit", 120 + (effective_floor * 30)))

        upgrades = [
            ("Max HP Upgrade", 400 + (effective_floor * 100)),
            ("Damage Upgrade", 500 + (effective_floor * 120)),
            ("Fortune Upgrade", 450 + (effective_floor * 110)),
        ]
        if effective_floor >= 2:
            upgrades.append(("Critical Upgrade", 200 + (effective_floor * 50)))

        for name, price in upgrades:
            if name not in self.purchased_upgrades_this_floor:
                store_items.append((name, price))

        if effective_floor >= 1:
            store_items.extend([
                ("Lucky Chip", 70 + (effective_floor * 15)),
                ("Honey Jar", 20 + (effective_floor * 4)),
                ("Healing Poultice", 50 + (effective_floor * 10)),
            ])

        if effective_floor >= 2:
            store_items.extend([
                ("Weighted Die", 60 + (effective_floor * 15)),
                ("Lockpick Kit", 50 + (effective_floor * 10)),
                ("Conductor Rod", 70 + (effective_floor * 15)),
            ])

        if effective_floor >= 3:
            store_items.extend([
                ("Hourglass Shard", 80 + (effective_floor * 20)),
                ("Tuner's Hammer", 85 + (effective_floor * 22)),
                ("Antivenom Leaf", 40 + (effective_floor * 10)),
            ])

        if effective_floor >= 4:
            store_items.extend([
                ("Cooled Ember", 90 + (effective_floor * 23)),
                ("Smoke Pot", 55 + (effective_floor * 12)),
                ("Black Candle", 65 + (effective_floor * 15)),
            ])

        if effective_floor >= 1:
            store_items.extend([
                ("Iron Sword", 120 + (effective_floor * 30)),
                ("Steel Dagger", 100 + (effective_floor * 25)),
            ])

        if effective_floor >= 2:
            store_items.extend([
                ("War Axe", 220 + (effective_floor * 50)),
                ("Rapier", 160 + (effective_floor * 35)),
            ])

        if effective_floor >= 4:
            store_items.extend([
                ("Greatsword", 280 + (effective_floor * 60)),
                ("Assassin's Blade", 260 + (effective_floor * 55)),
            ])

        if effective_floor >= 1:
            store_items.extend([
                ("Leather Armor", 110 + (effective_floor * 28)),
                ("Chain Vest", 130 + (effective_floor * 32)),
            ])

        if effective_floor >= 3:
            store_items.extend([
                ("Plate Armor", 220 + (effective_floor * 50)),
                ("Dragon Scale", 300 + (effective_floor * 65)),
            ])

        if effective_floor >= 1:
            store_items.append(("Traveler's Pack", 100 + (effective_floor * 25)))

        if effective_floor >= 2:
            store_items.extend([
                ("Lucky Coin", 140 + (effective_floor * 35)),
                ("Mystic Ring", 150 + (effective_floor * 38)),
                ("Merchant's Satchel", 180 + (effective_floor * 40)),
                ("Extra Die", 500 + (effective_floor * 50)),
            ])

        if effective_floor >= 4:
            store_items.extend([
                ("Crown of Fortune", 250 + (effective_floor * 55)),
                ("Timekeeper's Watch", 270 + (effective_floor * 58)),
            ])

        if effective_floor >= 3:
            store_items.extend([
                ("Blue Quartz", 90 + (effective_floor * 20)),
                ("Silk Bundle", 120 + (effective_floor * 30)),
            ])

        return store_items

    # --- Clear combat temps ---

    def clear_combat_temps(self):
        self.damage_bonus -= self.temp_combat_damage
        self.crit_chance -= self.temp_combat_crit
        self.reroll_bonus -= self.temp_combat_rerolls
        self.temp_combat_damage = 0
        self.temp_combat_crit = 0.0
        self.temp_combat_rerolls = 0
        self.temp_shield = 0
        self.in_combat = False


def load_items_db():
    items_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "dice_dungeon_content", "data", "items_definitions.json",
    )
    with open(items_path, "r") as f:
        data = json.load(f)
    if "_meta" in data:
        del data["_meta"]
    return data


def get_store_price(game, item_name):
    store_inv = game.generate_store_inventory()
    for name, price in store_inv:
        if name == item_name:
            return price
    return 0


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <seed> <actions> [floor]", file=sys.stderr)
        sys.exit(1)

    seed = int(sys.argv[1])
    actions_str = sys.argv[2]
    floor_num = int(sys.argv[3]) if len(sys.argv) > 3 else 1

    items_db = load_items_db()
    rng = PortableLCG(seed)
    game = HeadlessInventoryGame(rng, items_db, floor_num)

    actions = [a.strip() for a in actions_str.split(",") if a.strip()]

    snapshots = []

    for action in actions:
        parts = action.split(":")
        cmd = parts[0]

        if cmd == "pickup":
            item = parts[1] if len(parts) > 1 else "Health Potion"
            game.add_item(item)

        elif cmd == "equip":
            item = parts[1] if len(parts) > 1 else ""
            slot = parts[2] if len(parts) > 2 else ""
            game.equip_item(item, slot)

        elif cmd == "unequip":
            slot = parts[1] if len(parts) > 1 else ""
            game.unequip_item(slot)

        elif cmd == "use":
            idx = int(parts[1]) if len(parts) > 1 else 0
            game.use_item(idx)

        elif cmd == "degrade":
            item = parts[1] if len(parts) > 1 else ""
            amt = int(parts[2]) if len(parts) > 2 else 1
            game.degrade_durability(item, amt)

        elif cmd == "repair":
            kit = parts[1] if len(parts) > 1 else ""
            target = parts[2] if len(parts) > 2 else ""
            kit_idx = game.inventory.index(kit) if kit in game.inventory else -1
            if kit_idx >= 0:
                game.repair_item(kit, kit_idx, target)

        elif cmd == "buy":
            item = parts[1] if len(parts) > 1 else ""
            price = get_store_price(game, item)
            game.store_buy(item, price)

        elif cmd == "sell":
            item = parts[1] if len(parts) > 1 else ""
            game.store_sell(item)

        elif cmd == "upgrade":
            item = parts[1] if len(parts) > 1 else ""
            price = get_store_price(game, item)
            game.store_buy(item, price)

        elif cmd == "set_gold":
            amount = int(parts[1]) if len(parts) > 1 else 0
            game.gold = amount

        elif cmd == "set_combat":
            game.in_combat = (parts[1] == "1") if len(parts) > 1 else False

        elif cmd == "add_status":
            status = parts[1] if len(parts) > 1 else ""
            if status and status not in game.flags.get("statuses", []):
                game.flags.setdefault("statuses", []).append(status)

        elif cmd == "snapshot":
            snapshots.append(game.snapshot())

    # Always append final snapshot
    snapshots.append(game.snapshot())

    print(json.dumps(snapshots, indent=2))


if __name__ == "__main__":
    main()
