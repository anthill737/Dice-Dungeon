class_name ExplorationTrace
extends RefCounted
## Generates exploration trace arrays for parity testing.
##
## Uses PortableLCG (cross-language deterministic RNG) and the real
## ExplorationEngine to produce step records in the same JSON schema
## as the Python trace_exploration.py script.


static func generate(seed_val: int, moves: Array, floor_num: int = 1) -> Array:
	var rooms_data := RoomsData.new()
	if not rooms_data.load():
		push_error("ExplorationTrace: failed to load rooms DB")
		return []

	var rng := PortableLCG.new(seed_val)
	var state := GameState.new()
	var engine := ExplorationEngine.new(rng, state, rooms_data.rooms)
	var entrance := engine.start_floor(floor_num)

	var steps: Array = []
	steps.append(_room_record(entrance, Vector2i.ZERO, 0, "START", false))

	for i in moves.size():
		var direction: String = moves[i].strip_edges().to_upper()
		if direction.is_empty():
			continue

		var room := engine.move(direction)
		if room == null:
			steps.append(_blocked_record(i + 1, direction, engine))
		else:
			var is_revisit := engine.floor.rooms_explored_on_floor == 0 or room.visited
			## Actually detect revisit: if the room was already visited before this move
			## move() sets visited=true during _on_first_visit, so for new rooms
			## rooms_explored just incremented. We check if this was a new room by
			## seeing if rooms_explored_on_floor was incremented for this step.
			## A simpler approach: new rooms have their step index not yet recorded.
			var revisit := _is_revisit(engine, room)
			steps.append(_room_record(room, engine.floor.current_pos, i + 1, direction, revisit))

	return steps


static func _is_revisit(engine: ExplorationEngine, _room: RoomState) -> bool:
	return engine.last_move_was_revisit


static func _room_record(room: RoomState, pos: Vector2i, step: int, direction: String, revisit: bool) -> Dictionary:
	return {
		"step": step,
		"direction": direction,
		"coord": [pos.x, pos.y],
		"room_name": room.data.get("name", "Unknown"),
		"room_id": int(room.data.get("id", -1)),
		"has_combat": room.has_combat,
		"has_chest": room.has_chest,
		"has_store": room.has_store,
		"has_stairs": room.has_stairs,
		"is_miniboss": room.is_mini_boss_room,
		"is_boss": room.is_boss_room,
		"blocked_exits": {
			"N": not room.exits.get("N", true) or ("N" in room.blocked_exits),
			"S": not room.exits.get("S", true) or ("S" in room.blocked_exits),
			"E": not room.exits.get("E", true) or ("E" in room.blocked_exits),
			"W": not room.exits.get("W", true) or ("W" in room.blocked_exits),
		},
		"ground_container": room.ground_container if not room.ground_container.is_empty() else "",
		"ground_gold": room.ground_gold,
		"ground_items": Array(room.ground_items),
		"container_locked": room.container_locked,
		"revisit": revisit,
	}


static func _blocked_record(step: int, direction: String, engine: ExplorationEngine) -> Dictionary:
	var reason := "exit_blocked"
	## Check if the last log indicates gating
	if not engine.logs.is_empty():
		var last: String = engine.logs[engine.logs.size() - 1]
		if "locked_mini_boss" in last:
			reason = "locked_mini_boss"
		elif "locked_boss" in last:
			reason = "locked_boss"
	return {
		"step": step,
		"direction": direction,
		"blocked": true,
		"reason": reason,
	}
