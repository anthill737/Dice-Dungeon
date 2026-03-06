class_name WorldLoreData
extends RefCounted
## Loader for world_lore.json — dictionary with world narrative data.

const _FILENAME := "world_lore.json"
const REQUIRED_KEYS := ["world_concept", "starting_area", "flavor_text_database"]

var world_lore: Dictionary = {}


func load() -> bool:
	world_lore = JsonLoader.load_json_dict(_FILENAME)
	if world_lore.is_empty():
		return false
	for key in REQUIRED_KEYS:
		if not world_lore.has(key):
			push_error("WorldLoreData: missing key '%s'" % key)
			return false
	return true
