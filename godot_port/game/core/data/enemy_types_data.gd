class_name EnemyTypesData
extends RefCounted
## Loader for enemy_types.json — dictionary keyed by enemy name.

const _FILENAME := "enemy_types.json"

var enemies: Dictionary = {}


func load() -> bool:
	enemies = JsonLoader.load_json_dict(_FILENAME)
	if enemies.is_empty():
		return false
	for enemy_name in enemies:
		var entry: Dictionary = enemies[enemy_name]
		if not entry is Dictionary:
			push_error("EnemyTypesData: entry '%s' is not a dictionary" % enemy_name)
			return false
	return true
