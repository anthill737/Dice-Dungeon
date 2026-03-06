class_name RoomAccessResolver
extends RefCounted
## Determines whether a player can enter a room and handles lock resolution.
##
## Extracted from ExplorationEngine.move() so room-access logic lives in a
## dedicated resolver instead of being spread across the movement pipeline.
##
## Responsibilities:
##   - detect locked elite / boss rooms via FloorState.special_rooms
##   - check player inventory for Old Key / boss key fragments
##   - consume Old Key or fragments on unlock
##   - mark room as permanently unlocked in FloorState.unlocked_rooms
##   - return structured access result for callers (engine + UI)
##
## UI should only display prompts; all state mutation happens here.

enum AccessResult {
	ALLOWED,
	LOCKED_NO_KEY,
	LOCKED_HAS_KEY,
}


class AccessCheck extends RefCounted:
	var result: AccessResult = AccessResult.ALLOWED
	var gate_type: String = ""
	var room_type: String = ""
	var key_fragments: int = 0


## Check whether the player can enter the room at `pos`.
## Does NOT mutate state — purely a query.
static func check_access(pos: Vector2i, floor_st: FloorState, state: GameState) -> AccessCheck:
	var ac := AccessCheck.new()

	if not floor_st.special_rooms.has(pos):
		return ac
	if floor_st.unlocked_rooms.has(pos):
		return ac

	var room_type: String = floor_st.special_rooms[pos]
	ac.room_type = room_type

	if room_type == "mini_boss":
		if state.inventory.has("Old Key"):
			ac.result = AccessResult.LOCKED_HAS_KEY
			ac.gate_type = "has_key_mini_boss"
		else:
			ac.result = AccessResult.LOCKED_NO_KEY
			ac.gate_type = "locked_mini_boss"
	elif room_type == "boss":
		ac.key_fragments = floor_st.key_fragments
		if floor_st.key_fragments >= 3:
			ac.result = AccessResult.LOCKED_HAS_KEY
			ac.gate_type = "has_key_boss"
		else:
			ac.result = AccessResult.LOCKED_NO_KEY
			ac.gate_type = "locked_boss"

	return ac


## Unlock a mini-boss room by consuming exactly one Old Key.
## Returns true on success. Mutates state and floor_st.
static func unlock_mini_boss(pos: Vector2i, floor_st: FloorState, state: GameState) -> bool:
	if not state.inventory.has("Old Key"):
		return false
	state.inventory.erase("Old Key")
	floor_st.unlocked_rooms[pos] = true
	return true


## Unlock a boss room by consuming 3 key fragments.
## Returns true on success. Mutates floor_st.
static func unlock_boss(pos: Vector2i, floor_st: FloorState) -> bool:
	if floor_st.key_fragments < 3:
		return false
	floor_st.key_fragments = 0
	floor_st.unlocked_rooms[pos] = true
	return true


## Convenience: is a room already unlocked (or was never locked)?
static func is_accessible(pos: Vector2i, floor_st: FloorState) -> bool:
	if not floor_st.special_rooms.has(pos):
		return true
	return floor_st.unlocked_rooms.has(pos)
