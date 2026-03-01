class_name ItemsData
extends RefCounted
## Loader for items_definitions.json — dictionary keyed by item name.

const _FILENAME := "items_definitions.json"

var items: Dictionary = {}


func load() -> bool:
	items = JsonLoader.load_json_dict(_FILENAME)
	if items.is_empty():
		return false
	# Every non-meta entry must have at least a "type" or "desc" key
	for item_name in items:
		if item_name == "_meta":
			continue
		var entry: Dictionary = items[item_name]
		if not entry.has("type") and not entry.has("desc"):
			push_error("ItemsData: item '%s' missing 'type' and 'desc'" % item_name)
			return false
	return true
