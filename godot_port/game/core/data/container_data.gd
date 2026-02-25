class_name ContainerData
extends RefCounted
## Loader for container_definitions.json — dictionary keyed by container name.

const _FILENAME := "container_definitions.json"
const REQUIRED_KEYS := ["description", "loot_table", "weights", "loot_pools"]

var containers: Dictionary = {}


func load() -> bool:
	containers = JsonLoader.load_json_dict(_FILENAME)
	if containers.is_empty():
		return false
	for name in containers:
		var entry: Dictionary = containers[name]
		for key in REQUIRED_KEYS:
			if not entry.has(key):
				push_error("ContainerData: container '%s' missing key '%s'" % [name, key])
				return false
	return true
