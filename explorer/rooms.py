"""
Room class for Dice Dungeon Explorer
"""

class Room:
    """Represents a dungeon room position"""
    def __init__(self, room_data, x, y):
        self.data = room_data
        self.x = x
        self.y = y
        self.visited = False
        self.cleared = False
        self.has_stairs = False
        self.has_chest = False
        self.chest_looted = False
        self.enemies_defeated = False
        self.has_combat = None  # Determined at room creation (None = not yet determined)
        self.exits = {'N': True, 'S': True, 'E': True, 'W': True}  # Start with all open, will block some
        self.blocked_exits = []  # Track permanently blocked exits (dead ends)
        self.collected_discoverables = []  # Track which discoverables have been collected
        self.uncollected_items = []  # Track items that couldn't be picked up due to full inventory
        self.dropped_items = []  # Track items dropped by player in this room
        self.is_mini_boss_room = False  # Flag for mini-boss rooms
        self.is_boss_room = False  # Flag for main boss rooms
        
        # Container system - track what spawned in room
        self.ground_container = None  # Name of container on ground (if any)
        self.ground_items = []  # Loose items on ground
        self.ground_gold = 0  # Loose gold on ground
        self.container_searched = False  # Whether container has been opened
        self.container_locked = False  # Whether container is locked (requires lockpick)
