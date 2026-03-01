#!/usr/bin/env python3
"""
Save/load parity trace generator (Python side).

Runs headless exploration + inventory for N steps, saves to JSON string,
loads from JSON string, continues for M more steps, and outputs snapshots
at each checkpoint for parity comparison with the Godot SaveEngine.

Usage:
    python3 tools/parity/trace_saveload.py <seed> <moves> <inv_actions> <save_at_step> [floor]

    seed           - integer seed for the portable LCG
    moves          - comma-separated direction list  (e.g. "E,E,N,W,S,E,N,E")
    inv_actions    - comma-separated inventory actions (e.g. "pickup:Iron Sword,equip:Iron Sword:weapon")
    save_at_step   - step index at which to save
    floor          - floor index (int, default 1)

Outputs JSON to stdout:
    {
        "seed": ...,
        "save_json": { ... },
        "snapshot_before_save": { ... },
        "snapshot_after_load": { ... },
        "snapshot_end": { ... }
    }
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dice_dungeon_content.engine.rooms_loader import load_rooms, pick_room_for_floor
from explorer.rooms import Room


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

    def get_state(self) -> int:
        return self._state

    def set_state(self, state: int) -> None:
        self._state = state


# ---------------------------------------------------------------------------
# Headless exploration engine (from trace_exploration.py)
# ---------------------------------------------------------------------------

class HeadlessGame:
    def __init__(self, rng, rooms, floor_num, items_db):
        self.rng = rng
        self._rooms = rooms
        self.floor = floor_num
        self.item_definitions = items_db

        self.dungeon = {}
        self.current_pos = (0, 0)
        self.current_room = None

        self.rooms_explored = 0
        self.rooms_explored_on_floor = 0
        self.mini_bosses_spawned_this_floor = 0
        self.boss_spawned_this_floor = False
        self.next_mini_boss_at = 0
        self.next_boss_at = None

        self.key_fragments_collected = 0
        self.mini_bosses_defeated = 0
        self.boss_defeated = False
        self.special_rooms = {}
        self.unlocked_rooms = set()
        self.locked_rooms = set()
        self.is_boss_fight = False
        self.starter_rooms = set()

        self.stairs_found = False
        self.store_found = False
        self.store_position = None
        self.store_room = None

        self.inventory = []
        self.equipped_items = {"weapon": None, "armor": None, "accessory": None, "backpack": None}
        self.equipment_durability = {}
        self.equipment_floor_level = {}

        self.health = 50
        self.max_health = 50
        self.gold = 0
        self.total_gold_earned = 0
        self.max_inventory = 20
        self.damage_bonus = 0
        self.crit_chance = 0.1
        self.reroll_bonus = 0
        self.armor = 0
        self.temp_shield = 0
        self.shop_discount = 0.0
        self.multiplier = 1.0
        self.num_dice = 3
        self.max_dice = 5

        self.in_combat = False
        self.in_interaction = False
        self.combat_accuracy_penalty = 0.0
        self.rest_cooldown = 0
        self.temp_combat_damage = 0
        self.temp_combat_crit = 0.0
        self.temp_combat_rerolls = 0

        self.flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
        self.temp_effects = {}
        self.purchased_upgrades_this_floor = set()

        self.stats = {
            "items_used": 0, "potions_used": 0, "items_found": 0,
            "items_sold": 0, "items_purchased": 0, "gold_found": 0,
            "gold_spent": 0, "containers_searched": 0,
        }

        self._logs = []

    def log(self, msg, _tag='system'):
        self._logs.append(str(msg))

    def start_floor(self):
        self.dungeon = {}
        self.current_pos = (0, 0)
        self.stairs_found = False
        self.in_combat = False
        self.in_interaction = False
        self.combat_accuracy_penalty = 0.0

        self.key_fragments_collected = 0
        self.mini_bosses_defeated = 0
        self.boss_defeated = False
        self.mini_bosses_spawned_this_floor = 0
        self.boss_spawned_this_floor = False
        self.special_rooms = {}
        self.locked_rooms = set()
        self.unlocked_rooms = set()
        self.is_boss_fight = False
        self.rooms_explored_on_floor = 0

        self.next_mini_boss_at = self.rng.randint(6, 10)
        if self.floor >= 5:
            self.next_boss_at = self.rng.randint(20, 30)
        else:
            self.next_boss_at = None

        self.store_found = False
        self.store_position = None
        self.store_room = None

        room_data = pick_room_for_floor(self._rooms, self.floor, rng=self.rng)
        entrance = Room(room_data, 0, 0)
        entrance.visited = True
        entrance.has_combat = False

        for d in ['N', 'S', 'E', 'W']:
            if self.rng.random() < 0.3:
                entrance.exits[d] = False
                entrance.blocked_exits.append(d)

        open_exits = [d for d in ['N', 'S', 'E', 'W'] if entrance.exits[d]]
        if len(open_exits) < 2:
            blocked = [d for d in ['N', 'S', 'E', 'W'] if not entrance.exits[d]]
            if blocked:
                to_open = self.rng.choice(blocked)
                entrance.exits[to_open] = True
                if to_open in entrance.blocked_exits:
                    entrance.blocked_exits.remove(to_open)

        self.dungeon[(0, 0)] = entrance
        self.current_room = entrance

        if self.floor == 1:
            self.starter_rooms.add((0, 0))

        return entrance

    def explore_direction(self, direction):
        if direction in self.current_room.blocked_exits:
            return None
        if not self.current_room.exits.get(direction, True):
            return None

        opposite_map = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}
        moves = {'N': (0, 1), 'S': (0, -1), 'E': (1, 0), 'W': (-1, 0)}
        dx, dy = moves[direction]
        x, y = self.current_pos
        new_pos = (x + dx, y + dy)

        if new_pos in self.dungeon:
            dest_room = self.dungeon[new_pos]
            if opposite_map[direction] in dest_room.blocked_exits:
                return None

        if new_pos in self.special_rooms and new_pos not in self.unlocked_rooms:
            rt = self.special_rooms[new_pos]
            if rt == 'mini_boss' and "Old Key" not in self.inventory:
                return {"blocked": True, "reason": "locked_mini_boss"}
            elif rt == 'boss':
                if self.key_fragments_collected < 3:
                    return {"blocked": True, "reason": "locked_boss"}

        if new_pos in self.dungeon:
            self.current_pos = new_pos
            self.current_room = self.dungeon[new_pos]
            return "revisit"

        self.rooms_explored_on_floor += 1

        should_be_mini_boss = False
        should_be_boss = False

        if (self.mini_bosses_spawned_this_floor < 3
                and self.rooms_explored_on_floor >= self.next_mini_boss_at):
            should_be_mini_boss = True
            self.mini_bosses_spawned_this_floor += 1
            self.next_mini_boss_at = self.rooms_explored_on_floor + self.rng.randint(6, 10)

        if not self.boss_spawned_this_floor:
            if (self.next_boss_at is not None
                    and self.rooms_explored_on_floor >= self.next_boss_at):
                should_be_boss = True
                self.boss_spawned_this_floor = True

        if should_be_boss:
            boss_rooms = [r for r in self._rooms if r.get('difficulty') == 'Boss']
            if boss_rooms:
                room_data = self.rng.choice(boss_rooms)
            else:
                room_data = pick_room_for_floor(self._rooms, self.floor, rng=self.rng)
        elif should_be_mini_boss:
            elite_rooms = [r for r in self._rooms if r.get('difficulty') == 'Elite']
            if elite_rooms:
                room_data = self.rng.choice(elite_rooms)
            else:
                room_data = pick_room_for_floor(self._rooms, self.floor, rng=self.rng)
        else:
            room_data = pick_room_for_floor(self._rooms, self.floor, rng=self.rng)

        new_room = Room(room_data, new_pos[0], new_pos[1])

        for d in ['N', 'S', 'E', 'W']:
            if self.rng.random() < 0.3:
                new_room.exits[d] = False
                new_room.blocked_exits.append(d)

        opp = opposite_map[direction]
        new_room.exits[opp] = True
        if opp in new_room.blocked_exits:
            new_room.blocked_exits.remove(opp)

        other_exits = [d for d in ['N', 'S', 'E', 'W'] if d != opp]
        open_other = [d for d in other_exits if new_room.exits[d]]
        if len(open_other) == 0:
            to_open = self.rng.choice(other_exits)
            new_room.exits[to_open] = True
            if to_open in new_room.blocked_exits:
                new_room.blocked_exits.remove(to_open)

        self.dungeon[new_pos] = new_room

        if (should_be_boss or room_data.get('difficulty') == 'Boss'
                or 'boss' in room_data.get('tags', [])):
            new_room.is_boss_room = True
            self.special_rooms[new_pos] = 'boss'
            new_room.has_combat = True
        elif should_be_mini_boss or room_data.get('difficulty') == 'Elite':
            new_room.is_mini_boss_room = True
            self.special_rooms[new_pos] = 'mini_boss'
            new_room.has_combat = True
        else:
            threats = room_data.get('threats', [])
            has_combat_tag = 'combat' in room_data.get('tags', [])
            if threats or has_combat_tag:
                new_room.has_combat = self.rng.random() < 0.4
            else:
                new_room.has_combat = False

        self.current_pos = new_pos
        self.current_room = new_room

        self.rooms_explored += 1

        if self.rooms_explored <= 3 and self.floor == 1:
            self.starter_rooms.add(self.current_pos)

        if self.current_pos in self.starter_rooms:
            new_room.has_combat = False

        new_room.visited = True
        self._generate_ground_loot(new_room)

        # Apply on_enter mechanics (mirrors Godot MechanicsEngine.apply_on_enter)
        self._apply_on_enter(room_data)

        if (not self.stairs_found
                and self.rooms_explored >= 3
                and self.rng.random() < 0.1):
            new_room.has_stairs = True
            self.stairs_found = True

        if not self.store_found and self.rooms_explored >= 2:
            store_chance = 0.15
            if self.floor == 1:
                store_chance = 0.35
            elif self.floor == 2:
                store_chance = 0.25
            elif self.floor == 3:
                store_chance = 0.20

            if self.rooms_explored >= 15 or self.rng.random() < store_chance:
                self.store_found = True
                self.store_position = self.current_pos
                new_room.has_store = True

        if not new_room.has_chest and not new_room.visited:
            if self.rng.random() < 0.2:
                new_room.has_chest = True

        threats = room_data.get('threats', [])
        has_combat_tag = 'combat' in room_data.get('tags', [])
        is_starter = self.current_pos in self.starter_rooms

        if not is_starter and new_room.has_combat and not new_room.enemies_defeated:
            if threats:
                _enemy = self.rng.choice(threats)
        else:
            if threats or has_combat_tag:
                peaceful_messages = [
                    "The room is quiet. You explore cautiously...",
                    "You sense danger but nothing attacks.",
                    "The threats here seem to have moved on.",
                    "You carefully avoid any lurking dangers.",
                    "The room appears safe for now.",
                ]
                _msg = self.rng.choice(peaceful_messages)

        return "ok"

    def _generate_ground_loot(self, room):
        is_mini_boss = getattr(room, 'is_mini_boss_room', False)
        discoverables = room.data.get('discoverables', [])

        if discoverables:
            if is_mini_boss:
                room.ground_container = self.rng.choice(discoverables)
            elif self.rng.random() < 0.6:
                room.ground_container = self.rng.choice(discoverables)

            if room.ground_container and self.floor >= 2 and self.rng.random() < 0.30:
                room.container_locked = True

        if not is_mini_boss and self.rng.random() < 0.4:
            if self.rng.random() < 0.5:
                room.ground_gold = self.rng.randint(5, 20)
            else:
                num_items = self.rng.randint(1, 2)
                available_items = [
                    'Health Potion', 'Weighted Die', 'Lucky Chip', 'Honey Jar',
                    'Lockpick Kit', 'Antivenom Leaf', 'Silk Bundle',
                ]
                for _ in range(num_items):
                    item = self.rng.choice(available_items)
                    room.ground_items.append(item)

    def _apply_on_enter(self, room_data):
        """Simplified on_enter mechanics, mirrors MechanicsEngine._apply_bundle."""
        mechanics = room_data.get('mechanics', {})
        if not isinstance(mechanics, dict):
            return
        on_enter = mechanics.get('on_enter', {})
        if not isinstance(on_enter, dict) or not on_enter:
            return

        if on_enter.get('cleanse', False):
            self.flags['statuses'] = []
        if on_enter.get('disarm_token', False):
            self.flags['disarm_token'] = self.flags.get('disarm_token', 0) + 1
        if on_enter.get('escape_token', False):
            self.flags['escape_token'] = self.flags.get('escape_token', 0) + 1

        status = on_enter.get('status', None)
        if status and isinstance(status, str):
            statuses = self.flags.get('statuses', [])
            if status not in statuses:
                statuses.append(status)
                self.flags['statuses'] = statuses

        shield_val = int(on_enter.get('shield', 0))
        if shield_val > 0:
            self.temp_shield += shield_val

    # --- Inventory operations ---

    def add_item(self, item_name, source="found"):
        if len(self.inventory) >= self.max_inventory:
            return False
        self.inventory.append(item_name)
        if source in ["found", "reward", "chest", "ground"]:
            self.stats["items_found"] += 1
        item_def = self.item_definitions.get(item_name, {})
        if item_def.get("type") == "equipment":
            self.equipment_floor_level[item_name] = self.floor
        return True

    def equip_item(self, item_name, slot):
        if item_name not in self.inventory:
            return
        item_def = self.item_definitions.get(item_name, {})
        item_slot = item_def.get("slot", None)
        if item_slot != slot:
            return
        for es, ei in self.equipped_items.items():
            if ei == item_name:
                return
        if slot not in self.equipped_items:
            return

        old_item = self.equipped_items[slot]
        if old_item:
            self._remove_equipment_bonuses(old_item)

        self.equipped_items[slot] = item_name

        if item_name not in self.equipment_durability:
            max_dur = item_def.get("max_durability", 100)
            self.equipment_durability[item_name] = max_dur

        self._apply_equipment_bonuses(item_name)

    def _apply_equipment_bonuses(self, item_name, skip_hp=False):
        item_def = self.item_definitions.get(item_name, {})
        if not item_def:
            return
        floor_level = self.equipment_floor_level.get(item_name, self.floor)
        floor_bonus = max(0, floor_level - 1)

        if 'damage_bonus' in item_def:
            self.damage_bonus += item_def['damage_bonus'] + floor_bonus
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
            self.equipment_durability[item_name] = item_def.get('max_durability', 100)

    def _remove_equipment_bonuses(self, item_name):
        item_def = self.item_definitions.get(item_name, {})
        if not item_def:
            return
        floor_level = self.equipment_floor_level.get(item_name, self.floor)
        floor_bonus = max(0, floor_level - 1)

        if 'damage_bonus' in item_def:
            self.damage_bonus -= item_def['damage_bonus'] + floor_bonus
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
            self._remove_equipment_bonuses(item_name)
            self.equipped_items[slot_found] = None
        idx = self.inventory.index(item_name) if item_name in self.inventory else -1
        if idx >= 0:
            self.inventory[idx] = "Broken " + item_name
        del self.equipment_durability[item_name]
        broken_name = "Broken " + item_name
        item_def = self.item_definitions.get(item_name, {})
        if broken_name not in self.item_definitions:
            self.item_definitions[broken_name] = {
                "type": "broken_equipment",
                "original_item": item_name,
                "slot": item_def.get("slot", "weapon"),
                "sell_value": max(1, item_def.get("sell_value", 5) // 2),
                "desc": f"A broken {item_name}. Can be repaired or sold for scrap.",
            }

    def add_status(self, status_name):
        if status_name and status_name not in self.flags.get("statuses", []):
            self.flags.setdefault("statuses", []).append(status_name)

    # --- Save ---

    def save_to_dict(self, slot_num=1, save_name=""):
        rooms_data = {}
        for pos, room in self.dungeon.items():
            key = f"{pos[0]},{pos[1]}"
            rooms_data[key] = {
                'room_data': room.data,
                'x': room.x,
                'y': room.y,
                'visited': room.visited,
                'cleared': room.cleared,
                'has_stairs': room.has_stairs,
                'has_chest': room.has_chest,
                'chest_looted': room.chest_looted,
                'enemies_defeated': room.enemies_defeated,
                'has_combat': room.has_combat,
                'exits': room.exits.copy(),
                'blocked_exits': room.blocked_exits.copy(),
                'collected_discoverables': getattr(room, 'collected_discoverables', []).copy(),
                'uncollected_items': getattr(room, 'uncollected_items', []).copy(),
                'dropped_items': getattr(room, 'dropped_items', []).copy(),
                'is_mini_boss_room': getattr(room, 'is_mini_boss_room', False),
                'is_boss_room': getattr(room, 'is_boss_room', False),
                'ground_container': getattr(room, 'ground_container', None),
                'ground_items': getattr(room, 'ground_items', []).copy(),
                'ground_gold': getattr(room, 'ground_gold', 0),
                'container_searched': getattr(room, 'container_searched', False),
                'container_locked': getattr(room, 'container_locked', False),
            }

        special_rooms_out = {f"{k[0]},{k[1]}": v for k, v in self.special_rooms.items()}
        unlocked_rooms_out = [f"{k[0]},{k[1]}" for k in self.unlocked_rooms]
        starter_rooms_out = [list(pos) for pos in self.starter_rooms]

        equipped_out = {}
        for slot, item in self.equipped_items.items():
            equipped_out[slot] = item

        return {
            'save_time': '',
            'slot_num': slot_num,
            'save_name': save_name,
            'gold': self.gold,
            'health': self.health,
            'max_health': self.max_health,
            'max_inventory': self.max_inventory,
            'armor': self.armor,
            'floor': self.floor,
            'run_score': 0,
            'total_gold_earned': self.total_gold_earned,
            'rooms_explored': self.rooms_explored,
            'enemies_killed': 0,
            'chests_opened': 0,
            'inventory': self.inventory.copy(),
            'equipped_items': equipped_out,
            'equipment_durability': self.equipment_durability.copy(),
            'equipment_floor_level': self.equipment_floor_level.copy(),
            'adventure_log': [],
            'num_dice': self.num_dice,
            'multiplier': self.multiplier,
            'damage_bonus': self.damage_bonus,
            'heal_bonus': 0,
            'reroll_bonus': self.reroll_bonus,
            'crit_chance': self.crit_chance,
            'flags': {k: (v.copy() if isinstance(v, list) else v) for k, v in self.flags.items()},
            'temp_effects': self.temp_effects.copy(),
            'temp_shield': self.temp_shield,
            'shop_discount': self.shop_discount,
            'stairs_found': self.stairs_found,
            'rest_cooldown': self.rest_cooldown,
            'current_pos': list(self.current_pos),
            'rooms': rooms_data,
            'store_found': self.store_found,
            'store_position': list(self.store_position) if self.store_position else None,
            'mini_bosses_defeated': self.mini_bosses_defeated,
            'boss_defeated': self.boss_defeated,
            'mini_bosses_spawned_this_floor': self.mini_bosses_spawned_this_floor,
            'boss_spawned_this_floor': self.boss_spawned_this_floor,
            'rooms_explored_on_floor': self.rooms_explored_on_floor,
            'next_mini_boss_at': self.next_mini_boss_at,
            'next_boss_at': self.next_boss_at,
            'key_fragments_collected': self.key_fragments_collected,
            'special_rooms': special_rooms_out,
            'unlocked_rooms': unlocked_rooms_out,
            'used_lore_entries': {},
            'discovered_lore_items': [],
            'lore_item_assignments': {},
            'lore_item_counters': {},
            'lore_codex': [],
            'settings': {
                'color_scheme': 'Classic',
                'difficulty': 'Normal',
                'text_speed': 'Medium',
                'keybindings': {},
            },
            'stats': self.stats.copy(),
            'purchased_upgrades_this_floor': list(self.purchased_upgrades_this_floor),
            'in_starter_area': False,
            'starter_chests_opened': [],
            'signs_read': [],
            'starter_rooms': starter_rooms_out,
        }

    def load_from_dict(self, save_data):
        self.gold = save_data['gold']
        self.health = save_data['health']
        self.max_health = save_data['max_health']
        self.floor = save_data['floor']
        self.total_gold_earned = save_data['total_gold_earned']
        self.rooms_explored = save_data.get('rooms_explored', 0)
        self.inventory = save_data['inventory']
        self.equipped_items = save_data.get('equipped_items', {
            "weapon": None, "armor": None, "accessory": None, "backpack": None
        })
        if "backpack" not in self.equipped_items:
            self.equipped_items["backpack"] = None
        self.equipment_durability = save_data.get('equipment_durability', {})
        self.equipment_floor_level = save_data.get('equipment_floor_level', {})
        self.num_dice = save_data['num_dice']
        self.multiplier = save_data['multiplier']
        self.damage_bonus = save_data['damage_bonus']
        self.reroll_bonus = save_data['reroll_bonus']
        self.crit_chance = save_data['crit_chance']

        self.max_inventory = save_data.get('max_inventory', 20)
        self.armor = save_data.get('armor', 0)

        self.flags = save_data['flags']
        self.temp_effects = save_data['temp_effects']
        self.temp_shield = save_data['temp_shield']
        self.shop_discount = save_data['shop_discount']
        self.stairs_found = save_data.get('stairs_found', False)
        self.rest_cooldown = save_data.get('rest_cooldown', 0)

        self.mini_bosses_defeated = save_data.get('mini_bosses_defeated', 0)
        self.boss_defeated = save_data.get('boss_defeated', False)
        self.mini_bosses_spawned_this_floor = save_data.get('mini_bosses_spawned_this_floor', 0)
        self.boss_spawned_this_floor = save_data.get('boss_spawned_this_floor', False)
        self.rooms_explored_on_floor = save_data.get('rooms_explored_on_floor', 0)
        self.next_mini_boss_at = save_data.get('next_mini_boss_at', 8)
        self.next_boss_at = save_data.get('next_boss_at', None)
        self.key_fragments_collected = save_data.get('key_fragments_collected', 0)

        self.special_rooms = {}
        for pos_key, room_type in save_data.get('special_rooms', {}).items():
            x, y = map(int, pos_key.split(','))
            self.special_rooms[(x, y)] = room_type

        self.unlocked_rooms = set()
        for pos_key in save_data.get('unlocked_rooms', []):
            x, y = map(int, pos_key.split(','))
            self.unlocked_rooms.add((x, y))

        self.starter_rooms = set()
        for pos in save_data.get('starter_rooms', []):
            if isinstance(pos, list):
                self.starter_rooms.add(tuple(pos))
            elif isinstance(pos, str):
                x, y = map(int, pos.split(','))
                self.starter_rooms.add((x, y))

        self.store_found = save_data.get('store_found', False)
        store_pos = save_data.get('store_position', None)
        self.store_position = tuple(store_pos) if store_pos else None

        self.in_combat = False
        self.temp_combat_damage = 0
        self.temp_combat_crit = 0.0
        self.temp_combat_rerolls = 0

        if 'stats' in save_data:
            self.stats = save_data['stats']
        else:
            self.stats = {
                "items_used": 0, "potions_used": 0, "items_found": 0,
                "items_sold": 0, "items_purchased": 0, "gold_found": 0,
                "gold_spent": 0, "containers_searched": 0,
            }

        pur = save_data.get('purchased_upgrades_this_floor', [])
        self.purchased_upgrades_this_floor = set()
        if isinstance(pur, list):
            self.purchased_upgrades_this_floor = set(pur)

        # Rebuild dungeon
        self.dungeon = {}
        for pos_key, room_save_data in save_data['rooms'].items():
            x, y = map(int, pos_key.split(','))
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

            if room.has_combat is None:
                if room.is_boss_room or room.is_mini_boss_room:
                    room.has_combat = True
                else:
                    threats = room.data.get('threats', [])
                    has_combat_tag = 'combat' in room.data.get('tags', [])
                    room.has_combat = bool(threats or has_combat_tag)

            self.dungeon[(x, y)] = room

        self.current_pos = tuple(save_data['current_pos'])
        self.current_room = self.dungeon[self.current_pos]

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
            "num_dice": self.num_dice,
            "floor": self.floor,
            "current_pos": list(self.current_pos),
            "rooms_explored": self.rooms_explored,
            "rooms_explored_on_floor": self.rooms_explored_on_floor,
            "stairs_found": self.stairs_found,
            "store_found": self.store_found,
            "boss_defeated": self.boss_defeated,
            "mini_bosses_defeated": self.mini_bosses_defeated,
            "key_fragments": self.key_fragments_collected,
            "next_mini_boss_at": self.next_mini_boss_at,
            "next_boss_at": self.next_boss_at,
            "room_count": len(self.dungeon),
            "statuses": list(self.flags.get("statuses", [])),
            "stats": dict(self.stats),
        }


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


def main():
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <seed> <moves> <inv_actions> <save_at_step> [floor]",
              file=sys.stderr)
        sys.exit(1)

    seed = int(sys.argv[1])
    moves_str = sys.argv[2]
    inv_actions_str = sys.argv[3]
    save_at_step = int(sys.argv[4])
    floor_num = int(sys.argv[5]) if len(sys.argv) > 5 else 1

    moves = [m.strip().upper() for m in moves_str.split(",") if m.strip()]
    inv_actions = [a.strip() for a in inv_actions_str.split(",") if a.strip()]

    rooms_json = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "dice_dungeon_content", "data", "rooms_v2.json",
    )
    rooms = load_rooms(rooms_json)
    items_db = load_items_db()

    rng = PortableLCG(seed)
    game = HeadlessGame(rng, rooms, floor_num, items_db)
    game.start_floor()

    # Execute moves up to save_at_step
    for i in range(min(save_at_step, len(moves))):
        game.explore_direction(moves[i])

    # Execute inventory actions before save
    for action in inv_actions:
        parts = action.split(":")
        cmd = parts[0]
        if cmd == "pickup":
            item = parts[1] if len(parts) > 1 else "Health Potion"
            game.add_item(item)
        elif cmd == "equip":
            item = parts[1] if len(parts) > 1 else ""
            slot = parts[2] if len(parts) > 2 else ""
            game.equip_item(item, slot)
        elif cmd == "degrade":
            item = parts[1] if len(parts) > 1 else ""
            amt = int(parts[2]) if len(parts) > 2 else 1
            game.degrade_durability(item, amt)
        elif cmd == "add_status":
            status = parts[1] if len(parts) > 1 else ""
            game.add_status(status)
        elif cmd == "set_gold":
            game.gold = int(parts[1]) if len(parts) > 1 else 0

    # Snapshot before save
    snapshot_before_save = game.snapshot()

    # Save RNG state
    rng_state_at_save = rng.get_state()

    # Save to dict
    save_dict = game.save_to_dict()

    # Load from dict (into same game object, mirrors Python behavior)
    game.load_from_dict(save_dict)

    # Restore RNG state for deterministic continuation
    rng.set_state(rng_state_at_save)

    # Snapshot after load
    snapshot_after_load = game.snapshot()

    # Continue executing remaining moves
    for i in range(save_at_step, len(moves)):
        game.explore_direction(moves[i])

    # Snapshot at end
    snapshot_end = game.snapshot()

    result = {
        "seed": seed,
        "rng_state_at_save": rng_state_at_save,
        "save_json": save_dict,
        "snapshot_before_save": snapshot_before_save,
        "snapshot_after_load": snapshot_after_load,
        "snapshot_end": snapshot_end,
    }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
