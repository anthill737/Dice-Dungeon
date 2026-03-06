class_name ContainerResolver
extends RefCounted
## Deterministic container loot resolution using per-container JSON definitions.
## Mirrors Python inventory_pickup.py search_container() logic exactly.
##
## Python flow:
##   1. Look up container in container_definitions by name
##   2. Use loot_table categories and loot_pools for item selection
##   3. Hardcoded probability breakpoints: 15% nothing, 35% gold, 30% item, 20% both
##   4. Gold ranges come from loot_pools["gold"]["min"/"max"]
##   5. Item categories exclude "gold" and "nothing" from loot_table
##   6. Item is picked by: rng.choice(item_categories) then rng.choice(pool)


## Resolve container loot deterministically.
## Returns {"gold": int, "item": String} with the generated contents.
## The container_def should be the dictionary from container_definitions.json
## for the given container name.
static func resolve_loot(rng: RNG, container_def: Dictionary) -> Dictionary:
	var loot_table: Array = container_def.get("loot_table", [])
	var loot_pools: Dictionary = container_def.get("loot_pools", {})

	var loot_roll := rng.randf()
	var gold := 0
	var item := ""

	if loot_roll < 0.15:
		pass
	elif loot_roll < 0.50:
		gold = _resolve_gold(rng, loot_pools)
	elif loot_roll < 0.80:
		item = _resolve_item(rng, loot_table, loot_pools)
	else:
		gold = _resolve_gold(rng, loot_pools)
		item = _resolve_item(rng, loot_table, loot_pools)

	return {"gold": gold, "item": item}


## Resolve a gold amount from the container's gold pool.
static func _resolve_gold(rng: RNG, loot_pools: Dictionary) -> int:
	var gold_data: Dictionary = loot_pools.get("gold", {})
	if gold_data.is_empty():
		return rng.rand_int(5, 15)
	var gold_min: int = int(gold_data.get("min", 5))
	var gold_max: int = int(gold_data.get("max", 15))
	return rng.rand_int(gold_min, gold_max)


## Resolve an item from the container's item pools.
## Python: picks a random non-gold/non-nothing category, then picks from that pool.
static func _resolve_item(rng: RNG, loot_table: Array, loot_pools: Dictionary) -> String:
	var item_categories: Array = []
	for cat in loot_table:
		if cat != "gold" and cat != "nothing":
			item_categories.append(cat)

	if item_categories.is_empty():
		return ""

	var category: String = rng.choice(item_categories)
	var item_pool = loot_pools.get(category, [])

	if item_pool is Array and not (item_pool as Array).is_empty():
		return str(rng.choice(item_pool))
	return ""
