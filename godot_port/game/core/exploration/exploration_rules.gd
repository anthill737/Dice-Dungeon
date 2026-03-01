class_name ExplorationRules
extends RefCounted
## Constants and rule checks for dungeon exploration.
## All probability/spacing values from GAME_TESTING_REFERENCE.md and Python navigation.py.

# Exit blocking
const EXIT_BLOCK_CHANCE := 0.3
const MIN_ENTRANCE_EXITS := 2

# Combat
const COMBAT_CHANCE := 0.4

# Chest
const CHEST_CHANCE := 0.2

# Stairs
const STAIRS_MIN_ROOMS := 3
const STAIRS_CHANCE := 0.1

# Store
const STORE_MIN_ROOMS := 2
const STORE_GUARANTEE_ROOMS := 15

# Mini-boss spacing
const MINIBOSS_MAX_PER_FLOOR := 3
const MINIBOSS_INTERVAL_MIN := 6
const MINIBOSS_INTERVAL_MAX := 10

# Boss spacing (rooms after 3rd miniboss killed)
const BOSS_SPAWN_DELAY_MIN := 4
const BOSS_SPAWN_DELAY_MAX := 6

# Ground loot
const CONTAINER_CHANCE := 0.6
const CONTAINER_LOCK_CHANCE := 0.30
const CONTAINER_LOCK_MIN_FLOOR := 2
const LOOSE_LOOT_CHANCE := 0.4
const LOOSE_GOLD_VS_ITEMS := 0.5
const LOOSE_GOLD_MIN := 5
const LOOSE_GOLD_MAX := 20
const LOOSE_ITEMS_MIN := 1
const LOOSE_ITEMS_MAX := 2

const LOOSE_ITEM_POOL: Array[String] = [
	"Health Potion", "Weighted Die", "Lucky Chip", "Honey Jar",
	"Lockpick Kit", "Antivenom Leaf", "Silk Bundle",
]

# Non-combat room preference
const NON_COMBAT_PREFER_CHANCE := 0.20


static func store_chance_for_floor(floor_idx: int) -> float:
	if floor_idx == 1: return 0.35
	if floor_idx == 2: return 0.25
	if floor_idx == 3: return 0.20
	return 0.15
