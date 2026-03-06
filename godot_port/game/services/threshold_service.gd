class_name ThresholdService
extends RefCounted
## Manages threshold/starter area state and logic.
## Keeps gameplay logic out of the threshold UI script.
## Content comes from world_lore.json "starting_area".
## Persistence: reads/writes GameState.threshold_chests_opened so that
## save/load correctly tracks which starter chests have been opened.

var _world_lore: Dictionary = {}


func _init(world_lore: Dictionary = {}) -> void:
	_world_lore = world_lore


func get_starter_data() -> Dictionary:
	return _world_lore.get("starting_area", {})


func get_area_name() -> String:
	return get_starter_data().get("name", "The Threshold Chamber")


func get_description() -> String:
	return get_starter_data().get("description", "")


func get_ambient_details() -> Array:
	return get_starter_data().get("ambient_details", [])


func get_signs() -> Array:
	return get_starter_data().get("signs", [])


func get_starter_chests() -> Array:
	return get_starter_data().get("starter_chests", [])


func is_chest_opened(chest_id: int, game_state: GameState) -> bool:
	if game_state == null:
		return false
	return game_state.threshold_chests_opened.has(chest_id)


## Open a starter chest and apply its rewards to game state.
## Returns {"items": Array, "gold": int, "lore": String} or empty if already opened.
func open_chest(chest_data: Dictionary, game_state: GameState, inventory_engine: InventoryEngine) -> Dictionary:
	var chest_id: int = int(chest_data.get("id", 0))
	if game_state == null:
		return {}
	if game_state.threshold_chests_opened.has(chest_id):
		return {}

	game_state.threshold_chests_opened.append(chest_id)

	var items: Array = chest_data.get("items", [])
	var gold: int = int(chest_data.get("gold", 0))
	var lore_text: String = chest_data.get("lore", "")

	game_state.gold += gold
	game_state.total_gold_earned += gold
	for item_name in items:
		if inventory_engine != null:
			inventory_engine.add_item_to_inventory(str(item_name), "chest")
		else:
			game_state.inventory.append(str(item_name))

	return {"items": items, "gold": gold, "lore": lore_text}
