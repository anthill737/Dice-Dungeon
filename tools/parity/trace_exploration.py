#!/usr/bin/env python3
"""
Exploration trace generator (Python side).

Runs real Python exploration logic with a portable LCG RNG that produces
identical sequences in both Python and Godot, enabling exact parity checks.

Usage:
    python3 tools/parity/trace_exploration.py <seed> <moves> <floor>

    seed   - integer seed for the portable LCG
    moves  - comma-separated direction list, e.g. "E,E,N,W,S"
    floor  - floor index (int, default 1)

Outputs JSON array of step records to stdout.

Source-of-truth files:
    a) Room generation / type selection:
       - dice_dungeon_content/engine/rooms_loader.py :: pick_room_for_floor()
       - explorer/navigation.py :: explore_direction() lines 140-157
    b) Blocked exits:
       - explorer/navigation.py :: explore_direction() lines 161-181
    c) Chest spawn:
       - explorer/navigation.py :: _continue_room_entry() line 393
         (DEAD CODE: room.visited is True before check)
    d) Store spawn + once-per-floor:
       - explorer/navigation.py :: _continue_room_entry() lines 373-390
    e) Stairs spawn + boss_dead gating:
       - explorer/navigation.py :: _continue_room_entry() line 368
       - explorer/navigation.py :: descend_floor() line 709
    f) Miniboss spacing + cap + unlocking:
       - explorer/navigation.py :: explore_direction() lines 123-128
       - explorer/combat.py :: lines 218-261
    g) Boss spawn timing + fragment gating:
       - explorer/navigation.py :: explore_direction() lines 134-138
       - explorer/combat.py :: lines 195-202, 256-260
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dice_dungeon_content.engine.rooms_loader import load_rooms, pick_room_for_floor
from explorer.rooms import Room


# ---------------------------------------------------------------------------
# Portable LCG — identical implementation in Godot (PortableLCG class).
# Produces the same sequence given the same seed on both sides.
# ---------------------------------------------------------------------------

class PortableLCG:
    """Minimal LCG matching the Godot PortableLCG implementation exactly."""

    MODULUS = (1 << 31) - 1   # 2^31 - 1 = 2147483647
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
# Headless exploration engine — uses real Python logic without Tkinter
# ---------------------------------------------------------------------------

class HeadlessGame:
    """Minimal shim replicating the game attributes NavigationManager reads."""

    def __init__(self, rng, rooms, floor_num):
        self.rng = rng
        self._rooms = rooms
        self.floor = floor_num

        # Position / map
        self.dungeon = {}
        self.current_pos = (0, 0)
        self.current_room = None

        # Spawn tracking
        self.rooms_explored = 0
        self.rooms_explored_on_floor = 0
        self.mini_bosses_spawned_this_floor = 0
        self.boss_spawned_this_floor = False
        self.next_mini_boss_at = 0
        self.next_boss_at = None

        # Boss gating
        self.key_fragments_collected = 0
        self.mini_bosses_defeated = 0
        self.boss_defeated = False
        self.special_rooms = {}
        self.unlocked_rooms = set()
        self.locked_rooms = set()
        self.is_boss_fight = False
        self.starter_rooms = set()

        # Store / stairs
        self.stairs_found = False
        self.store_found = False
        self.store_position = None
        self.store_room = None

        # Inventory / stats (needed for key checks)
        self.inventory = []

        # Combat flags
        self.in_combat = False
        self.in_interaction = False
        self.combat_accuracy_penalty = 0.0
        self.rest_cooldown = 0

        # Logs
        self._logs = []

    def log(self, msg, _tag='system'):
        self._logs.append(str(msg))

    def start_floor(self):
        """Mirror NavigationManager.start_new_floor() RNG calls exactly."""
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

        # RNG call #1
        self.next_mini_boss_at = self.rng.randint(6, 10)
        # RNG call #2 (conditional)
        if self.floor >= 5:
            self.next_boss_at = self.rng.randint(20, 30)
        else:
            self.next_boss_at = None

        self.store_found = False
        self.store_position = None
        self.store_room = None

        # RNG call #3: pick room
        room_data = pick_room_for_floor(self._rooms, self.floor, rng=self.rng)
        entrance = Room(room_data, 0, 0)
        entrance.visited = True
        entrance.has_combat = False

        # RNG calls #4-7: exit blocking
        for d in ['N', 'S', 'E', 'W']:
            if self.rng.random() < 0.3:
                entrance.exits[d] = False
                entrance.blocked_exits.append(d)

        # RNG call #8 (conditional): ensure >= 2 exits
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
        """
        Mirror NavigationManager.explore_direction() exactly.
        Returns a step record dict or None if blocked.
        """
        # Check current room blocked exits
        if direction in self.current_room.blocked_exits:
            return None
        if not self.current_room.exits.get(direction, True):
            return None

        opposite_map = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}
        moves = {'N': (0, 1), 'S': (0, -1), 'E': (1, 0), 'W': (-1, 0)}
        dx, dy = moves[direction]
        x, y = self.current_pos
        new_pos = (x + dx, y + dy)

        # Check destination blocked exit from other side
        if new_pos in self.dungeon:
            dest_room = self.dungeon[new_pos]
            if opposite_map[direction] in dest_room.blocked_exits:
                return None

        # Check gating
        if new_pos in self.special_rooms and new_pos not in self.unlocked_rooms:
            rt = self.special_rooms[new_pos]
            if rt == 'mini_boss' and "Old Key" not in self.inventory:
                return {"blocked": True, "reason": "locked_mini_boss"}
            elif rt == 'boss':
                if self.key_fragments_collected < 3:
                    return {"blocked": True, "reason": "locked_boss"}

        # Revisit
        if new_pos in self.dungeon:
            self.current_pos = new_pos
            self.current_room = self.dungeon[new_pos]
            return self._make_step_record(self.current_room, new_pos, revisit=True)

        # New room
        self.rooms_explored_on_floor += 1

        should_be_mini_boss = False
        should_be_boss = False

        # Miniboss check
        if (self.mini_bosses_spawned_this_floor < 3
                and self.rooms_explored_on_floor >= self.next_mini_boss_at):
            should_be_mini_boss = True
            self.mini_bosses_spawned_this_floor += 1
            self.next_mini_boss_at = self.rooms_explored_on_floor + self.rng.randint(6, 10)

        # Boss check
        if not self.boss_spawned_this_floor:
            if (self.next_boss_at is not None
                    and self.rooms_explored_on_floor >= self.next_boss_at):
                should_be_boss = True
                self.boss_spawned_this_floor = True

        # Room selection
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

        # Exit blocking
        for d in ['N', 'S', 'E', 'W']:
            if self.rng.random() < 0.3:
                new_room.exits[d] = False
                new_room.blocked_exits.append(d)

        # Ensure entry direction open
        opp = opposite_map[direction]
        new_room.exits[opp] = True
        if opp in new_room.blocked_exits:
            new_room.blocked_exits.remove(opp)

        # Ensure at least 1 other exit
        other_exits = [d for d in ['N', 'S', 'E', 'W'] if d != opp]
        open_other = [d for d in other_exits if new_room.exits[d]]
        if len(open_other) == 0:
            to_open = self.rng.choice(other_exits)
            new_room.exits[to_open] = True
            if to_open in new_room.blocked_exits:
                new_room.blocked_exits.remove(to_open)

        self.dungeon[new_pos] = new_room

        # Set room type flags
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

        # Update position
        self.current_pos = new_pos
        self.current_room = new_room

        # rooms_explored increment (mirrors _complete_room_entry)
        self.rooms_explored += 1

        # Starter rooms (floor 1, first 3)
        if self.rooms_explored <= 3 and self.floor == 1:
            self.starter_rooms.add(self.current_pos)

        # Skip combat in starter rooms
        if self.current_pos in self.starter_rooms:
            new_room.has_combat = False

        # First visit processing — mirrors _continue_room_entry
        new_room.visited = True

        # 1. Ground loot
        self._generate_ground_loot(new_room)

        # 2. apply_on_enter — no RNG calls in our headless version

        # 3. Stairs check
        if (not self.stairs_found
                and self.rooms_explored >= 3
                and self.rng.random() < 0.1):
            new_room.has_stairs = True
            self.stairs_found = True

        # 4. Store check
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

        # 5. Chest check (DEAD CODE — room.visited already True)
        if not new_room.has_chest and not new_room.visited:
            if self.rng.random() < 0.2:
                new_room.has_chest = True

        # 6. Enemy selection / peaceful message — consumes RNG
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

        return self._make_step_record(new_room, new_pos)

    def _generate_ground_loot(self, room):
        """Mirror NavigationManager.generate_ground_loot() exactly."""
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

    def _make_step_record(self, room, pos, revisit=False):
        has_store = getattr(room, 'has_store', False)
        return {
            "coord": list(pos),
            "room_name": room.data.get("name", "Unknown"),
            "room_id": room.data.get("id", -1),
            "has_combat": bool(room.has_combat) if room.has_combat is not None else False,
            "has_chest": bool(room.has_chest),
            "has_store": bool(has_store),
            "has_stairs": bool(room.has_stairs),
            "is_miniboss": bool(getattr(room, 'is_mini_boss_room', False)),
            "is_boss": bool(getattr(room, 'is_boss_room', False)),
            "blocked_exits": {
                "N": not room.exits.get('N', True) or ('N' in room.blocked_exits),
                "S": not room.exits.get('S', True) or ('S' in room.blocked_exits),
                "E": not room.exits.get('E', True) or ('E' in room.blocked_exits),
                "W": not room.exits.get('W', True) or ('W' in room.blocked_exits),
            },
            "ground_container": room.ground_container or "",
            "ground_gold": room.ground_gold,
            "ground_items": list(room.ground_items),
            "container_locked": bool(room.container_locked),
            "revisit": revisit,
        }


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <seed> <moves> [floor]", file=sys.stderr)
        sys.exit(1)

    seed = int(sys.argv[1])
    moves = sys.argv[2].split(",")
    floor_num = int(sys.argv[3]) if len(sys.argv) > 3 else 1

    rooms_json = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "dice_dungeon_content", "data", "rooms_v2.json",
    )
    rooms = load_rooms(rooms_json)

    rng = PortableLCG(seed)
    game = HeadlessGame(rng, rooms, floor_num)
    entrance = game.start_floor()

    steps = []
    steps.append({
        "step": 0,
        "direction": "START",
        **game._make_step_record(entrance, (0, 0)),
    })

    for i, direction in enumerate(moves):
        direction = direction.strip().upper()
        if not direction:
            continue
        result = game.explore_direction(direction)
        if result is None:
            steps.append({
                "step": i + 1,
                "direction": direction,
                "blocked": True,
                "reason": "exit_blocked",
            })
        elif result.get("blocked"):
            steps.append({
                "step": i + 1,
                "direction": direction,
                **result,
            })
        else:
            steps.append({
                "step": i + 1,
                "direction": direction,
                **result,
            })

    print(json.dumps(steps, indent=2))


if __name__ == "__main__":
    main()
