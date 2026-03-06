class_name RoomState
extends RefCounted
## State of a single dungeon room. Mirrors Python explorer/rooms.py Room class.

var data: Dictionary = {}     ## room template from rooms_v2.json
var x: int = 0
var y: int = 0
var visited: bool = false
var cleared: bool = false

## Bound template fields (populated from data dict at creation)
var room_name: String = "Unknown"
var room_type: String = ""
var tags: Array = []
var threats: Array = []

## Exits
var exits: Dictionary = {"N": true, "S": true, "E": true, "W": true}
var blocked_exits: Array[String] = []

## Content flags (set during generation)
var has_combat: bool = false
var has_chest: bool = false
var chest_looted: bool = false
var has_stairs: bool = false
var has_store: bool = false
var is_mini_boss_room: bool = false
var is_boss_room: bool = false
var enemies_defeated: bool = false
var combat_escaped: bool = false  ## true after a successful flee; encounter ignored

## Ground loot (generated on first visit)
var ground_container: String = ""   ## container name (empty = none)
var container_searched: bool = false
var container_locked: bool = false
var container_gold: int = 0
var container_item: String = ""
var ground_items: Array[String] = []
var ground_gold: int = 0

## Tracking
var uncollected_items: Array[String] = []
var dropped_items: Array[String] = []


func _init(p_data: Dictionary = {}, p_x: int = 0, p_y: int = 0) -> void:
	data = p_data
	x = p_x
	y = p_y
	room_name = str(p_data.get("name", "Unknown"))
	room_type = str(p_data.get("difficulty", ""))
	tags = Array(p_data.get("tags", []))
	threats = Array(p_data.get("threats", []))


func coords() -> Vector2i:
	return Vector2i(x, y)


static func opposite_dir(dir: String) -> String:
	match dir:
		"N": return "S"
		"S": return "N"
		"E": return "W"
		"W": return "E"
	return ""


static func dir_delta(dir: String) -> Vector2i:
	match dir:
		"N": return Vector2i(0, 1)
		"S": return Vector2i(0, -1)
		"E": return Vector2i(1, 0)
		"W": return Vector2i(-1, 0)
	return Vector2i.ZERO
