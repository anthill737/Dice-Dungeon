class_name FloorState
extends RefCounted
## Tracks per-floor exploration state. Reset when descending to a new floor.

var floor_index: int = 1
var rooms: Dictionary = {}            ## Vector2i -> RoomState
var current_pos: Vector2i = Vector2i.ZERO
var rooms_explored: int = 0           ## total rooms entered (excl. entrance)
var rooms_explored_on_floor: int = 0  ## rooms created this floor (for spawn spacing)

## Boss gating
var mini_bosses_spawned: int = 0
var mini_bosses_defeated: int = 0
var boss_spawned: bool = false
var boss_defeated: bool = false
var key_fragments: int = 0
var next_mini_boss_at: int = 8        ## set by RNG at floor start
var next_boss_at: int = -1            ## set when 3rd miniboss defeated (-1 = not set)

## One-time spawns
var stairs_found: bool = false
var store_found: bool = false
var store_pos: Vector2i = Vector2i(-999, -999)


func get_current_room() -> RoomState:
	return rooms.get(current_pos)


func has_room_at(pos: Vector2i) -> bool:
	return rooms.has(pos)
