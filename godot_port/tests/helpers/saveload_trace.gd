class_name SaveLoadTrace
extends RefCounted
## Generates save/load trace data for parity testing.
##
## Mirrors the Python tools/parity/trace_saveload.py script:
##   1. Run exploration for N steps
##   2. Execute inventory actions
##   3. Snapshot before save
##   4. Serialize via SaveEngine
##   5. Deserialize back
##   6. Snapshot after load
##   7. Continue exploration for remaining steps
##   8. Snapshot at end


static func generate(
		seed_val: int,
		moves: Array,
		inv_actions: Array,
		save_at_step: int,
		floor_num: int = 1
) -> Dictionary:
	var rooms_data := RoomsData.new()
	if not rooms_data.load():
		push_error("SaveLoadTrace: failed to load rooms DB")
		return {}

	var items_data := ItemsData.new()
	if not items_data.load():
		push_error("SaveLoadTrace: failed to load items DB")
		return {}

	var items_db: Dictionary = items_data.items.duplicate(true)
	if items_db.has("_meta"):
		items_db.erase("_meta")

	var rng := PortableLCG.new(seed_val)
	var state := GameState.new()
	state.floor = floor_num
	var engine := ExplorationEngine.new(rng, state, rooms_data.rooms)
	var inv_engine := InventoryEngine.new(rng, state, items_db)
	engine.start_floor(floor_num)

	# Execute moves up to save_at_step
	var steps_done := 0
	for i in range(mini(save_at_step, moves.size())):
		var direction: String = moves[i].strip_edges().to_upper()
		if direction.is_empty():
			continue
		_move_or_force_unlock(engine, direction)
		steps_done += 1

	# Execute inventory actions before save
	for action_str in inv_actions:
		var parts: Array = (action_str as String).split(":")
		var cmd: String = parts[0]

		if cmd == "pickup":
			var item: String = parts[1] if parts.size() > 1 else "Health Potion"
			inv_engine.add_item_to_inventory(item)
		elif cmd == "equip":
			var item: String = parts[1] if parts.size() > 1 else ""
			var slot: String = parts[2] if parts.size() > 2 else ""
			inv_engine.equip_item(item, slot)
		elif cmd == "degrade":
			var item: String = parts[1] if parts.size() > 1 else ""
			var amt: int = int(parts[2]) if parts.size() > 2 else 1
			inv_engine.degrade_durability(item, amt)
		elif cmd == "add_status":
			var status: String = parts[1] if parts.size() > 1 else ""
			if not status.is_empty():
				var statuses: Array = state.flags.get("statuses", [])
				if not statuses.has(status):
					statuses.append(status)
					state.flags["statuses"] = statuses
		elif cmd == "set_gold":
			state.gold = int(parts[1]) if parts.size() > 1 else 0

	# Snapshot before save
	var snapshot_before_save := _make_snapshot(state, engine.floor)

	# Save RNG state
	var rng_state_at_save: int = rng._state

	# Serialize
	var save_dict := SaveEngine.serialize(state, engine.floor)

	# Create fresh state objects for load
	var load_state := GameState.new()
	var load_floor := FloorState.new()

	# Deserialize
	SaveEngine.deserialize(save_dict, load_state, load_floor)

	# Snapshot after load
	var snapshot_after_load := _make_snapshot(load_state, load_floor)

	# Restore RNG state for deterministic continuation
	rng._state = rng_state_at_save

	# Create new exploration engine with loaded state
	var load_engine := ExplorationEngine.new(rng, load_state, rooms_data.rooms)
	load_engine.floor = load_floor

	# Continue executing remaining moves
	for i in range(save_at_step, moves.size()):
		var direction: String = moves[i].strip_edges().to_upper()
		if direction.is_empty():
			continue
		_move_or_force_unlock(load_engine, direction)

	# Snapshot at end
	var snapshot_end := _make_snapshot(load_state, load_engine.floor)

	return {
		"seed": seed_val,
		"rng_state_at_save": rng_state_at_save,
		"save_json": save_dict,
		"snapshot_before_save": snapshot_before_save,
		"snapshot_after_load": snapshot_after_load,
		"snapshot_end": snapshot_end,
	}


## Force-unlock locked rooms when move() returns null due to gating.
## Python trace enters these rooms directly; this keeps parity.
static func _move_or_force_unlock(engine: ExplorationEngine, direction: String) -> void:
	var room := engine.move(direction)
	if room != null:
		return
	var gate := engine.last_move_gate
	if gate.is_empty():
		return
	var delta := RoomState.dir_delta(direction)
	var pos := engine.floor.current_pos + delta
	if engine.floor.rooms.has(pos) and not engine.floor.rooms[pos].visited:
		engine.floor.unlocked_rooms[pos] = true
		engine.move(direction)


static func _make_snapshot(state: GameState, floor_st: FloorState) -> Dictionary:
	var equipped := {}
	for slot in state.equipped_items:
		equipped[slot] = state.equipped_items[slot] if not (state.equipped_items[slot] as String).is_empty() else ""

	var durability := {}
	for item in state.equipment_durability:
		durability[item] = int(state.equipment_durability[item])

	return {
		"inventory": state.inventory.duplicate(),
		"equipped": equipped,
		"durability": durability,
		"gold": state.gold,
		"health": state.health,
		"max_health": state.max_health,
		"damage_bonus": state.damage_bonus,
		"crit_chance": snapped(state.crit_chance, 0.0001),
		"reroll_bonus": state.reroll_bonus,
		"armor": state.armor,
		"temp_shield": state.temp_shield,
		"max_inventory": state.max_inventory,
		"num_dice": state.num_dice,
		"floor": state.floor,
		"current_pos": [floor_st.current_pos.x, floor_st.current_pos.y],
		"rooms_explored": floor_st.rooms_explored,
		"rooms_explored_on_floor": floor_st.rooms_explored_on_floor,
		"stairs_found": floor_st.stairs_found,
		"store_found": floor_st.store_found,
		"boss_defeated": floor_st.boss_defeated,
		"mini_bosses_defeated": floor_st.mini_bosses_defeated,
		"key_fragments": floor_st.key_fragments,
		"next_mini_boss_at": floor_st.next_mini_boss_at,
		"next_boss_at": floor_st.next_boss_at if floor_st.next_boss_at >= 0 else null,
		"room_count": floor_st.rooms.size(),
		"statuses": (state.flags.get("statuses", []) as Array).duplicate(),
		"stats": state.stats.duplicate(),
	}
