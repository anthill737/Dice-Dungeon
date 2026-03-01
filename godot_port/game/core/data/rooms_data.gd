class_name RoomsData
extends RefCounted
## Loader for rooms_v2.json — array of room definitions.

const _FILENAME := "rooms_v2.json"
const REQUIRED_KEYS := ["id", "name", "difficulty", "threats", "flavor", "discoverables"]

var rooms: Array = []


func load() -> bool:
	rooms = JsonLoader.load_json_array(_FILENAME)
	if rooms.is_empty():
		return false
	for room in rooms:
		for key in REQUIRED_KEYS:
			if not room.has(key):
				push_error("RoomsData: room missing key '%s': %s" % [key, room])
				return false
	return true
