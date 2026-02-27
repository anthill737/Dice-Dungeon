class_name ExplorationEngine
extends RefCounted
## Headless dungeon exploration engine.
## Drives room generation, movement, spawn gating, and interaction stubs.
## Fully deterministic when given a DeterministicRNG.

var rng: RNG
var state: GameState
var floor: FloorState
var rooms_db: Array = []            ## loaded from rooms_v2.json
var mechanics: MechanicsEngine
var logs: Array[String] = []

const DIRS := ["N", "S", "E", "W"]


func _init(p_rng: RNG, p_state: GameState, p_rooms_db: Array) -> void:
	rng = p_rng
	state = p_state
	rooms_db = p_rooms_db
	mechanics = MechanicsEngine.new(func(msg: String): logs.append(msg))


# ------------------------------------------------------------------
# Floor lifecycle
# ------------------------------------------------------------------

func start_floor(floor_index: int) -> RoomState:
	floor = FloorState.new()
	floor.floor_index = floor_index
	floor.next_mini_boss_at = rng.rand_int(
		ExplorationRules.MINIBOSS_INTERVAL_MIN,
		ExplorationRules.MINIBOSS_INTERVAL_MAX)
	if floor_index >= 5:
		floor.next_boss_at = rng.rand_int(20, 30)

	# Generate entrance room
	var room_data := _pick_room_for_floor(floor_index)
	var entrance := RoomState.new(room_data, 0, 0)
	entrance.visited = true
	entrance.has_combat = false  # Entrance never has combat

	_roll_blocked_exits(entrance, "")
	_ensure_min_exits(entrance, ExplorationRules.MIN_ENTRANCE_EXITS)

	floor.rooms[Vector2i.ZERO] = entrance
	floor.current_pos = Vector2i.ZERO

	mechanics.settle_temp_effects(state, "floor_transition")
	logs.append("=== Floor %d ===" % floor_index)
	logs.append("Entered: %s" % room_data.get("name", "Unknown"))
	return entrance


# ------------------------------------------------------------------
# Movement
# ------------------------------------------------------------------

func can_move(direction: String) -> bool:
	var room := floor.get_current_room()
	if room == null:
		return false
	if direction in room.blocked_exits:
		return false
	if not room.exits.get(direction, true):
		return false
	return true


func move(direction: String) -> RoomState:
	if not can_move(direction):
		return null

	var delta := RoomState.dir_delta(direction)
	var new_pos := floor.current_pos + delta

	# Revisiting existing room
	if floor.has_room_at(new_pos):
		var existing: RoomState = floor.rooms[new_pos]
		floor.current_pos = new_pos
		logs.append("Returned to: %s" % existing.data.get("name", "Room"))
		return existing

	# Generate new room
	floor.rooms_explored_on_floor += 1
	floor.rooms_explored += 1

	var room := _generate_room(new_pos, direction)
	floor.rooms[new_pos] = room
	floor.current_pos = new_pos

	# First-visit processing
	_on_first_visit(room)

	return room


# ------------------------------------------------------------------
# Room generation
# ------------------------------------------------------------------

func _generate_room(pos: Vector2i, from_direction: String) -> RoomState:
	var should_be_mini_boss := false
	var should_be_boss := false

	# Mini-boss spawn check
	if floor.mini_bosses_spawned < ExplorationRules.MINIBOSS_MAX_PER_FLOOR:
		if floor.rooms_explored_on_floor >= floor.next_mini_boss_at:
			should_be_mini_boss = true
			floor.mini_bosses_spawned += 1
			floor.next_mini_boss_at = floor.rooms_explored_on_floor + rng.rand_int(
				ExplorationRules.MINIBOSS_INTERVAL_MIN,
				ExplorationRules.MINIBOSS_INTERVAL_MAX)

	# Boss spawn check
	if not floor.boss_spawned and floor.next_boss_at > 0:
		if floor.rooms_explored_on_floor >= floor.next_boss_at:
			should_be_boss = true
			floor.boss_spawned = true

	# Pick room data
	var room_data: Dictionary
	if should_be_boss:
		var boss_pool := rooms_db.filter(func(r): return r.get("difficulty") == "Boss")
		room_data = rng.choice(boss_pool) if not boss_pool.is_empty() else _pick_room_for_floor(floor.floor_index)
	elif should_be_mini_boss:
		var elite_pool := rooms_db.filter(func(r): return r.get("difficulty") == "Elite")
		room_data = rng.choice(elite_pool) if not elite_pool.is_empty() else _pick_room_for_floor(floor.floor_index)
	else:
		room_data = _pick_room_for_floor(floor.floor_index)

	var room := RoomState.new(room_data, pos.x, pos.y)

	# Block exits
	_roll_blocked_exits(room, from_direction)

	# Ensure entry direction is open
	var opp := RoomState.opposite_dir(from_direction)
	if not opp.is_empty():
		room.exits[opp] = true
		room.blocked_exits.erase(opp)

	# Ensure at least 1 other open exit (besides entry)
	var others: Array[String] = []
	for d in DIRS:
		if d != opp:
			others.append(d)
	var open_others := others.filter(func(d): return room.exits.get(d, true))
	if open_others.is_empty() and not others.is_empty():
		var to_open: String = rng.choice(others)
		room.exits[to_open] = true
		room.blocked_exits.erase(to_open)

	# Set room type flags
	if should_be_boss:
		room.is_boss_room = true
		room.has_combat = true
	elif should_be_mini_boss:
		room.is_mini_boss_room = true
		room.has_combat = true
	else:
		var threats: Array = room_data.get("threats", [])
		var has_combat_tag: bool = room_data.get("tags", []).has("combat")
		if not threats.is_empty() or has_combat_tag:
			room.has_combat = rng.randf() < ExplorationRules.COMBAT_CHANCE
		else:
			room.has_combat = false

	return room


func _on_first_visit(room: RoomState) -> void:
	room.visited = true

	# Generate ground loot
	_generate_ground_loot(room)

	# Apply on_enter mechanics
	mechanics.apply_on_enter(state, room.data)

	# Stairs check
	if not floor.stairs_found and floor.rooms_explored >= ExplorationRules.STAIRS_MIN_ROOMS:
		if rng.randf() < ExplorationRules.STAIRS_CHANCE:
			room.has_stairs = true
			floor.stairs_found = true
			logs.append("Found stairs to the next floor!")

	# Store check
	if not floor.store_found and floor.rooms_explored >= ExplorationRules.STORE_MIN_ROOMS:
		var chance := ExplorationRules.store_chance_for_floor(floor.floor_index)
		if floor.rooms_explored >= ExplorationRules.STORE_GUARANTEE_ROOMS or rng.randf() < chance:
			room.has_store = true
			floor.store_found = true
			floor.store_pos = room.coords()
			logs.append("Discovered a mysterious shop!")

	# Chest check
	if not room.has_chest and rng.randf() < ExplorationRules.CHEST_CHANCE:
		room.has_chest = true
		logs.append("There's a chest here!")

	# Log entry
	logs.append("Entered: %s" % room.data.get("name", "Room"))
	if room.has_combat:
		var threats: Array = room.data.get("threats", [])
		if not threats.is_empty():
			logs.append("Enemy: %s" % rng.choice(threats))
		else:
			logs.append("Enemy lurks here!")


func _generate_ground_loot(room: RoomState) -> void:
	var is_mini_boss := room.is_mini_boss_room
	var discoverables: Array = room.data.get("discoverables", [])

	# Container
	if not discoverables.is_empty():
		if is_mini_boss:
			room.ground_container = rng.choice(discoverables)
		elif rng.randf() < ExplorationRules.CONTAINER_CHANCE:
			room.ground_container = rng.choice(discoverables)

		if not room.ground_container.is_empty() and floor.floor_index >= ExplorationRules.CONTAINER_LOCK_MIN_FLOOR:
			if rng.randf() < ExplorationRules.CONTAINER_LOCK_CHANCE:
				room.container_locked = true

	# Loose loot (not in mini-boss rooms)
	if not is_mini_boss and rng.randf() < ExplorationRules.LOOSE_LOOT_CHANCE:
		if rng.randf() < ExplorationRules.LOOSE_GOLD_VS_ITEMS:
			room.ground_gold = rng.rand_int(ExplorationRules.LOOSE_GOLD_MIN, ExplorationRules.LOOSE_GOLD_MAX)
		else:
			var num_items := rng.rand_int(ExplorationRules.LOOSE_ITEMS_MIN, ExplorationRules.LOOSE_ITEMS_MAX)
			for i in num_items:
				room.ground_items.append(rng.choice(ExplorationRules.LOOSE_ITEM_POOL))


# ------------------------------------------------------------------
# Room clear / combat hooks
# ------------------------------------------------------------------

func on_combat_clear(room: RoomState) -> void:
	room.enemies_defeated = true
	room.cleared = true
	mechanics.apply_on_clear(state, room.data)

	if room.is_mini_boss_room:
		floor.mini_bosses_defeated += 1
		floor.key_fragments += 1
		logs.append("Mini-boss defeated! Key fragment: %d/3" % floor.key_fragments)
		if floor.mini_bosses_defeated == 3:
			floor.next_boss_at = floor.rooms_explored_on_floor + rng.rand_int(
				ExplorationRules.BOSS_SPAWN_DELAY_MIN,
				ExplorationRules.BOSS_SPAWN_DELAY_MAX)
			logs.append("The floor boss will appear soon...")

	if room.is_boss_room:
		floor.boss_defeated = true
		logs.append("Boss defeated! Stairs are now usable.")


func on_combat_fail(room: RoomState) -> void:
	mechanics.apply_on_fail(state, room.data)


# ------------------------------------------------------------------
# Interaction stubs (headless)
# ------------------------------------------------------------------

func open_chest(room: RoomState) -> Dictionary:
	## Returns {"gold": int, "item": String} and modifies room state.
	if not room.has_chest or room.chest_looted:
		return {}
	room.chest_looted = true

	var loot_roll := rng.randf()
	var gold := 0
	var item := ""

	if loot_roll < 0.6:
		# 60% chance for loot type selection
		var type_roll := rng.randf()
		if type_roll < 0.5:
			gold = rng.rand_int(20, 50) + (floor.floor_index * 10)
		elif type_roll < 0.75:
			gold = rng.rand_int(20, 50) + (floor.floor_index * 10)
			item = rng.choice(ExplorationRules.LOOSE_ITEM_POOL)
		else:
			item = rng.choice(ExplorationRules.LOOSE_ITEM_POOL)
	else:
		gold = rng.rand_int(20, 50) + (floor.floor_index * 10)

	if gold > 0:
		state.gold += gold
		state.total_gold_earned += gold
	if not item.is_empty():
		state.ground_items.append(item)

	logs.append("Opened chest: +%d gold%s" % [gold, (", " + item) if not item.is_empty() else ""])
	return {"gold": gold, "item": item}


func inspect_ground_items(room: RoomState) -> Array:
	var items: Array = []
	if not room.ground_container.is_empty() and not room.container_searched:
		items.append({"type": "container", "name": room.ground_container, "locked": room.container_locked})
	if room.ground_gold > 0:
		items.append({"type": "gold", "amount": room.ground_gold})
	for item_name in room.ground_items:
		items.append({"type": "item", "name": item_name})
	return items


func pickup_ground_gold(room: RoomState) -> int:
	var amount := room.ground_gold
	if amount > 0:
		state.gold += amount
		state.total_gold_earned += amount
		room.ground_gold = 0
		logs.append("Picked up %d gold" % amount)
	return amount


func pickup_ground_item(room: RoomState, index: int) -> String:
	if index < 0 or index >= room.ground_items.size():
		return ""
	var item_name: String = room.ground_items[index]
	room.ground_items.remove_at(index)
	state.ground_items.append(item_name)
	logs.append("Picked up %s" % item_name)
	return item_name


func search_container(room: RoomState) -> Dictionary:
	if room.ground_container.is_empty() or room.container_searched:
		return {}
	if room.container_locked:
		logs.append("Container is locked!")
		return {"locked": true}

	room.container_searched = true
	var loot_roll := rng.randf()
	var gold := 0
	var item := ""

	if loot_roll < 0.15:
		pass  # nothing
	elif loot_roll < 0.50:
		gold = rng.rand_int(5, 15)
	elif loot_roll < 0.80:
		item = rng.choice(ExplorationRules.LOOSE_ITEM_POOL)
	else:
		gold = rng.rand_int(5, 15)
		item = rng.choice(ExplorationRules.LOOSE_ITEM_POOL)

	room.container_gold = gold
	room.container_item = item
	logs.append("Searched %s: %s" % [room.ground_container,
		("+%d gold, %s" % [gold, item]) if gold > 0 and not item.is_empty()
		else ("+%d gold" % gold) if gold > 0
		else item if not item.is_empty()
		else "empty"])
	return {"gold": gold, "item": item}


func can_use_stairs() -> bool:
	var room := floor.get_current_room()
	return room != null and room.has_stairs and floor.boss_defeated


func can_enter_miniboss_room(room: RoomState) -> bool:
	return state.ground_items.has("Old Key")


func can_enter_boss_room() -> bool:
	return floor.key_fragments >= 3


func enter_store(_room: RoomState) -> Array:
	## Placeholder: returns a minimal store inventory.
	logs.append("Browsing store...")
	return ["Health Potion", "Repair Kit", "Lockpick Kit"]


# ------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------

func _pick_room_for_floor(floor_idx: int) -> Dictionary:
	var target: String
	if floor_idx <= 3: target = "Easy"
	elif floor_idx <= 6: target = "Medium"
	elif floor_idx <= 9: target = "Hard"
	else: target = "Elite"

	var pool := rooms_db.filter(func(r): return r.get("difficulty") == target)
	if pool.is_empty():
		pool = rooms_db

	if rng.randf() < ExplorationRules.NON_COMBAT_PREFER_CHANCE:
		var non_combat_tags := ["lore", "puzzle", "event", "rest", "environment"]
		var nc_pool := pool.filter(func(r):
			var tags: Array = r.get("tags", [])
			return tags.any(func(t): return t in non_combat_tags) and not tags.has("combat"))
		if not nc_pool.is_empty():
			pool = nc_pool

	return rng.choice(pool)


func _roll_blocked_exits(room: RoomState, from_direction: String) -> void:
	for d in DIRS:
		if rng.randf() < ExplorationRules.EXIT_BLOCK_CHANCE:
			room.exits[d] = false
			if d not in room.blocked_exits:
				room.blocked_exits.append(d)


func _ensure_min_exits(room: RoomState, min_count: int) -> void:
	var open_dirs := DIRS.filter(func(d): return room.exits.get(d, true))
	while open_dirs.size() < min_count:
		var blocked := DIRS.filter(func(d): return not room.exits.get(d, true))
		if blocked.is_empty():
			break
		var to_open: String = rng.choice(blocked)
		room.exits[to_open] = true
		room.blocked_exits.erase(to_open)
		open_dirs.append(to_open)
