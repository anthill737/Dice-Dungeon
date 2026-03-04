class_name RewardResolver
extends RefCounted
## Pure deterministic reward calculation — no UI, no Nodes.
##
## Mirrors Python's enemy_defeated() reward logic exactly.
## Given combat outcome + RNG, returns structured reward data.

# ------------------------------------------------------------------
# Types
# ------------------------------------------------------------------

class RewardResult extends RefCounted:
	var gold: int = 0
	var score: int = 0
	var items: Array = []            ## Array[String] item names
	var key_fragment: bool = false
	var key_fragments_total: int = 0
	var is_boss: bool = false
	var is_mini_boss: bool = false
	var logs: Array = []


# ------------------------------------------------------------------
# Loot pools — exact Python parity
# ------------------------------------------------------------------

const BOSS_RARE_EQUIPMENT: Array = [
	"Greatsword", "War Axe", "Assassin's Blade",
	"Plate Armor", "Dragon Scale", "Enchanted Cloak",
	"Greater Health Potion", "Greater Health Potion", "Greater Health Potion",
	"Strength Elixir", "Strength Elixir",
]

const MINI_BOSS_LOOT_HIGH: Array = [
	"Greater Health Potion", "Greater Health Potion",
	"Strength Elixir",
	"Greatsword", "War Axe", "Assassin's Blade",
	"Plate Armor", "Dragon Scale", "Enchanted Cloak",
]

const MINI_BOSS_LOOT_MID: Array = [
	"Health Potion", "Greater Health Potion",
	"Strength Elixir",
	"Iron Sword", "Battle Axe", "Steel Sword",
	"Chain Vest", "Scale Mail", "Iron Shield",
]

const MINI_BOSS_LOOT_EARLY: Array = [
	"Health Potion", "Health Potion",
	"Strength Elixir",
	"Steel Dagger", "Iron Sword", "Hand Axe",
	"Leather Armor", "Chain Vest", "Wooden Shield",
]


# ------------------------------------------------------------------
# API
# ------------------------------------------------------------------

## Calculate rewards for defeating all enemies.
## `floor_num` is the current floor number.
## `key_fragments_before` is fragments collected before this fight.
static func resolve(rng: RNG, floor_num: int,
		is_boss: bool, is_mini_boss: bool,
		key_fragments_before: int = 0) -> RewardResult:

	var result := RewardResult.new()
	result.is_boss = is_boss
	result.is_mini_boss = is_mini_boss

	if is_boss:
		_resolve_boss(rng, floor_num, result)
	elif is_mini_boss:
		_resolve_mini_boss(rng, floor_num, key_fragments_before, result)
	else:
		_resolve_normal(rng, floor_num, result)

	return result


# ------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------

static func _resolve_boss(rng: RNG, floor_num: int, result: RewardResult) -> void:
	result.gold = rng.rand_int(200, 350) + (floor_num * 100)
	result.score = 1000 + (floor_num * 200)

	result.logs.append("=" .repeat(60))
	result.logs.append("☠ FLOOR BOSS DEFEATED! ☠")
	result.logs.append("+%d gold!" % result.gold)

	var num_rewards: int = rng.rand_int(3, 5)
	for _i in num_rewards:
		var drop: String = rng.choice(BOSS_RARE_EQUIPMENT)
		result.items.append(drop)

	result.logs.append("[BOSS DEFEATED] The path forward is clear!")
	result.logs.append("[STAIRS] Continue exploring to find the stairs to the next floor.")
	result.logs.append("=" .repeat(60))


static func _resolve_mini_boss(rng: RNG, floor_num: int,
		key_fragments_before: int, result: RewardResult) -> void:
	result.gold = rng.rand_int(50, 80) + (floor_num * 20)
	result.score = 500 + (floor_num * 50)
	result.key_fragment = true
	result.key_fragments_total = key_fragments_before + 1

	result.logs.append("Mini-boss defeated!")
	result.logs.append("+%d gold!" % result.gold)
	result.logs.append("Obtained Boss Key Fragment! (%d/3)" % result.key_fragments_total)

	var pool: Array
	if floor_num >= 8:
		pool = MINI_BOSS_LOOT_HIGH
	elif floor_num >= 5:
		pool = MINI_BOSS_LOOT_MID
	else:
		pool = MINI_BOSS_LOOT_EARLY

	var loot: String = rng.choice(pool)
	result.items.append(loot)


static func _resolve_normal(rng: RNG, floor_num: int, result: RewardResult) -> void:
	result.gold = rng.rand_int(10, 30) + (floor_num * 5)
	result.score = 100 + (floor_num * 20)
	result.logs.append("+%d gold!" % result.gold)
