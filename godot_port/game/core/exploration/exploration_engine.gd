class_name ExplorationEngine
extends RefCounted
## Headless dungeon exploration engine.
## Faithful port of Python explorer/navigation.py.
## RNG call ordering matches Python exactly.

const _AccessResolver := preload("res://game/core/exploration/room_access_resolver.gd")

var rng: RNG
var state: GameState
var floor: FloorState
var rooms_db: Array = []
var container_db: Dictionary = {}
var mechanics: MechanicsEngine
var logs: Array[String] = []
var last_move_was_revisit: bool = false
## Set by move() when a newly generated room triggers gating.
## Callers check this after move() returns null to decide if a dialog is needed.
var last_move_gate: String = ""

const DIRS := ["N", "S", "E", "W"]

## Python peaceful messages (used when combat room rolls no combat)
const PEACEFUL_MESSAGES := [
	"The room is quiet. You explore cautiously...",
	"You sense danger but nothing attacks.",
	"The threats here seem to have moved on.",
	"You carefully avoid any lurking dangers.",
	"The room appears safe for now.",
]


func _init(p_rng: RNG, p_state: GameState, p_rooms_db: Array, p_container_db: Dictionary = {}) -> void:
	rng = p_rng if p_rng != null else DefaultRNG.new()
	state = p_state
	rooms_db = p_rooms_db
	container_db = p_container_db
	mechanics = MechanicsEngine.new(func(msg: String): logs.append(msg))
	_log_room_template_diagnostics()


func _log_room_template_diagnostics() -> void:
	var path := JsonLoader.resolve_data_path("rooms_v2.json")
	var exists := FileAccess.file_exists(path)
	var size := 0
	if exists:
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			size = f.get_length()
			f.close()
	print("[ROOM_TEMPLATES] path=%s exists=%s file_bytes=%d templates_loaded=%d" % [
		path, str(exists), size, rooms_db.size()])
	if rooms_db.is_empty():
		push_warning("ExplorationEngine: rooms_db is EMPTY — room templates failed to load")


# ------------------------------------------------------------------
# Floor lifecycle — mirrors Python start_new_floor()
# ------------------------------------------------------------------

func start_floor(floor_index: int) -> RoomState:
	floor = FloorState.new()
	floor.floor_index = floor_index
	state.floor = floor_index

	## Python RNG call #1: rng.randint(6, 10)
	floor.next_mini_boss_at = rng.rand_int(6, 10)

	## Python RNG call #2: rng.randint(20, 30) if floor >= 5 else None
	if floor_index >= 5:
		floor.next_boss_at = rng.rand_int(20, 30)
	else:
		floor.next_boss_at = -1

	## Python RNG call #3: pick_room_for_floor() → rng.random() + rng.choice()
	var room_data := _pick_room_for_floor(floor_index)
	var entrance := RoomState.new(room_data, 0, 0)
	entrance.visited = true
	entrance.has_combat = false

	## Python RNG calls #4-7: exit blocking for N,S,E,W (exactly 4 rng.random() calls)
	for d in DIRS:
		if rng.randf() < ExplorationRules.EXIT_BLOCK_CHANCE:
			entrance.exits[d] = false
			entrance.blocked_exits.append(d)

	## Python RNG call #8 (conditional): ensure >= 2 open exits
	## Python opens exactly ONE blocked exit if needed, not a loop
	var open_exits: Array = DIRS.filter(func(d): return entrance.exits.get(d, true))
	if open_exits.size() < 2:
		var blocked: Array = DIRS.filter(func(d): return not entrance.exits.get(d, true))
		if not blocked.is_empty():
			var to_open: String = rng.choice(blocked)
			entrance.exits[to_open] = true
			entrance.blocked_exits.erase(to_open)

	floor.rooms[Vector2i.ZERO] = entrance
	floor.current_pos = Vector2i.ZERO

	## Mark starting position as starter room (no combat) — Python floor 1 only
	if floor_index == 1:
		floor.starter_rooms[Vector2i.ZERO] = true

	mechanics.settle_temp_effects(state, "floor_transition")

	## Python then calls enter_room(entrance, is_first=True)
	## For entrance: is_first=True, room.visited already True, so is_first_visit=False
	## This means NO ground loot, NO mechanics, NO stairs/store/chest rolls
	## (entrance is treated as already-visited)
	logs.append("=== Floor %d ===" % floor_index)
	logs.append("==================================================")
	logs.append("Entered: %s" % room_data.get("name", "Unknown"))
	var entrance_flavor: String = room_data.get("flavor", "")
	if not entrance_flavor.is_empty():
		logs.append(entrance_flavor)
	return entrance


## Descend to next floor — mirrors Python descend_floor().
## Returns the entrance room of the new floor, or null if stairs unusable.
func descend_floor() -> RoomState:
	if not can_use_stairs():
		logs.append("Cannot descend: boss not defeated or no stairs here.")
		return null
	floor.floor_index += 1
	state.floor = floor.floor_index
	state.purchased_upgrades_this_floor = {}
	return start_floor(floor.floor_index)


# ------------------------------------------------------------------
# Movement — mirrors Python explore_direction()
# ------------------------------------------------------------------

func can_move(direction: String) -> bool:
	var room := floor.get_current_room()
	if room == null:
		return false
	if direction in room.blocked_exits:
		return false
	if not room.exits.get(direction, true):
		return false

	## Python: check if destination room has blocked exit on opposite side
	var delta := RoomState.dir_delta(direction)
	var new_pos := floor.current_pos + delta
	if floor.has_room_at(new_pos):
		var dest: RoomState = floor.rooms[new_pos]
		var opp := RoomState.opposite_dir(direction)
		if opp in dest.blocked_exits:
			return false

	return true


## Check whether a locked special room at pos can be entered.
## Returns "" if entry is allowed, otherwise a gate_type string.
## Delegates to RoomAccessResolver for the actual logic.
func check_room_gating(pos: Vector2i) -> String:
	var ac := _AccessResolver.check_access(pos, floor, state)
	return ac.gate_type


## Unlock a mini-boss room by consuming an Old Key. Returns true on success.
func use_old_key(pos: Vector2i) -> bool:
	if not _AccessResolver.unlock_mini_boss(pos, floor, state):
		return false
	logs.append("[KEY USED] The Old Key turns in the lock with a satisfying click!")
	logs.append("The elite room door swings open!")
	return true


## Unlock a boss room by consuming 3 key fragments. Returns true on success.
func use_boss_key(pos: Vector2i) -> bool:
	if not _AccessResolver.unlock_boss(pos, floor):
		return false
	logs.append("The 3 fragments merge into a complete key!")
	logs.append("The massive boss door grinds open!")
	return true


func move(direction: String) -> RoomState:
	last_move_gate = ""
	if not can_move(direction):
		return null

	var delta := RoomState.dir_delta(direction)
	var new_pos := floor.current_pos + delta

	## Python: check special room gating BEFORE allowing entry
	var gate := check_room_gating(new_pos)
	if gate == "locked_mini_boss":
		logs.append("⚡ A locked door blocks your path!")
		logs.append("You need an Old Key to proceed.")
		return null
	elif gate == "locked_boss":
		logs.append("☠ A sealed boss door blocks your path!")
		logs.append("You need 3 key fragments. You have %d." % floor.key_fragments)
		return null
	elif gate == "has_key_mini_boss" or gate == "has_key_boss":
		last_move_gate = gate
		return null

	# Revisiting existing room — Python handles this in explore_direction
	if floor.has_room_at(new_pos):
		var existing: RoomState = floor.rooms[new_pos]

		if existing.visited:
			# Normal revisit — Python does NOT make RNG calls
			last_move_was_revisit = true
			floor.current_pos = new_pos
			logs.append("==================================================")
			logs.append("Entered: %s" % existing.data.get("name", "Room"))
			var revisit_flavor: String = existing.data.get("flavor", "")
			if not revisit_flavor.is_empty():
				logs.append(revisit_flavor)
			# Python parity: describe remaining ground items on revisit too
			_describe_ground_loot(existing)
			return existing

		# Room was generated but not entered (was locked, now unlocked).
		# Process as first visit — Python _complete_room_entry path.
		last_move_was_revisit = false
		floor.current_pos = new_pos
		floor.rooms_explored += 1

		if state.rest_cooldown > 0:
			state.rest_cooldown -= 1

		if floor.floor_index == 1 and floor.rooms_explored <= 3:
			floor.starter_rooms[new_pos] = true

		if floor.starter_rooms.has(new_pos):
			existing.has_combat = false

		_on_first_visit(existing)
		return existing

	last_move_was_revisit = false
	# New room — Python increments rooms_explored_on_floor BEFORE spawn checks
	floor.rooms_explored_on_floor += 1

	# Generate room (miniboss/boss checks, room selection, exits, combat roll)
	var room := _generate_room(new_pos, direction)
	floor.rooms[new_pos] = room

	## Python: after generation, special_rooms may be set. Check gating on the
	## newly generated room BEFORE allowing entry — mirrors Python enter_room()
	## lock check that fires after the room is created but before entry completes.
	var post_gate := check_room_gating(new_pos)
	if post_gate != "":
		last_move_gate = post_gate
		if post_gate == "locked_mini_boss":
			logs.append("⚡ A locked door blocks your path!")
			logs.append("You need an Old Key to proceed.")
		elif post_gate == "locked_boss":
			logs.append("☠ A sealed boss door blocks your path!")
			logs.append("You need 3 key fragments. You have %d." % floor.key_fragments)
		return null

	floor.current_pos = new_pos

	# Python _complete_room_entry: is_first_visit = not room.visited (True for new rooms)
	# Then room.visited = True
	# Then rooms_explored += 1 (for non-entrance rooms)
	floor.rooms_explored += 1

	# Python: decrement rest cooldown on first visit
	if state.rest_cooldown > 0:
		state.rest_cooldown -= 1

	## Python: first 3 rooms on floor 1 are starter rooms (never combat)
	if floor.floor_index == 1 and floor.rooms_explored <= 3:
		floor.starter_rooms[new_pos] = true

	## Python _continue_room_entry: combat skipped for starter rooms.
	## Applied AFTER starter_rooms is updated so the current room is included.
	if floor.starter_rooms.has(new_pos):
		room.has_combat = false

	# Python _continue_room_entry first-visit path:
	# 1. generate_ground_loot
	# 2. apply_on_enter
	# 3. stairs roll (conditional)
	# 4. store roll (conditional)
	# 5. chest roll — DEAD CODE in Python (room.visited already True)
	# 6. enemy selection or peaceful message
	_on_first_visit(room)

	return room


# ------------------------------------------------------------------
# Room generation — mirrors Python explore_direction() lines 117-205
# ------------------------------------------------------------------

func _generate_room(pos: Vector2i, from_direction: String) -> RoomState:
	var should_be_mini_boss := false
	var should_be_boss := false

	## Python: miniboss check uses rooms_explored_on_floor (just incremented)
	if floor.mini_bosses_spawned < ExplorationRules.MINIBOSS_MAX_PER_FLOOR:
		if floor.rooms_explored_on_floor >= floor.next_mini_boss_at:
			should_be_mini_boss = true
			floor.mini_bosses_spawned += 1
			print("[MINIBOSS] spawned at rooms_explored_on_floor=%d, threshold=%d, count=%d/3" % [
				floor.rooms_explored_on_floor, floor.next_mini_boss_at, floor.mini_bosses_spawned])
			## Python RNG call: rng.randint(6, 10) for next interval
			floor.next_mini_boss_at = floor.rooms_explored_on_floor + rng.rand_int(
				ExplorationRules.MINIBOSS_INTERVAL_MIN,
				ExplorationRules.MINIBOSS_INTERVAL_MAX)

	## Python: boss check uses rooms_explored_on_floor
	if not floor.boss_spawned and floor.next_boss_at > 0:
		if floor.rooms_explored_on_floor >= floor.next_boss_at:
			should_be_boss = true
			floor.boss_spawned = true

	## Python RNG calls: room selection
	## For boss: rng.choice(boss_rooms) — single call, no non-combat preference
	## For miniboss: rng.choice(elite_rooms) — single call, no non-combat preference
	## For normal: _pick_room_for_floor → rng.random() + rng.choice()
	var room_data: Dictionary
	if should_be_boss:
		var boss_pool := rooms_db.filter(func(r): return r.get("difficulty") == "Boss")
		if not boss_pool.is_empty():
			room_data = rng.choice(boss_pool)
		else:
			room_data = _pick_room_for_floor(floor.floor_index)
	elif should_be_mini_boss:
		var elite_pool := rooms_db.filter(func(r): return r.get("difficulty") == "Elite")
		if not elite_pool.is_empty():
			room_data = rng.choice(elite_pool)
		else:
			room_data = _pick_room_for_floor(floor.floor_index)
	else:
		room_data = _pick_room_for_floor(floor.floor_index)

	var room := RoomState.new(room_data, pos.x, pos.y)

	## Python RNG calls: 4 exit-blocking rolls (N, S, E, W)
	for d in DIRS:
		if rng.randf() < ExplorationRules.EXIT_BLOCK_CHANCE:
			room.exits[d] = false
			if d not in room.blocked_exits:
				room.blocked_exits.append(d)

	## Python: ensure entry direction is open
	var opp := RoomState.opposite_dir(from_direction)
	if not opp.is_empty():
		room.exits[opp] = true
		room.blocked_exits.erase(opp)

	## Python: ensure at least 1 OTHER open exit (besides entry)
	## Uses: other_exits = [d for d in DIRS if d != opposite]
	## Then: open_other = [d for d in other_exits if room.exits[d]]
	## If empty: rng.choice(other_exits) — note: chooses from ALL others, not just blocked
	var other_dirs: Array = DIRS.filter(func(d): return d != opp)
	var open_others: Array = other_dirs.filter(func(d): return room.exits.get(d, true) and d not in room.blocked_exits)
	if open_others.is_empty() and not other_dirs.is_empty():
		## Python RNG call: rng.choice(other_exits)
		var to_open: String = rng.choice(other_dirs)
		room.exits[to_open] = true
		room.blocked_exits.erase(to_open)

	## Python: set room type flags — AFTER exits
	if should_be_boss or room_data.get("difficulty") == "Boss" or (room_data.get("tags", []) as Array).has("boss"):
		room.is_boss_room = true
		room.has_combat = true
		floor.special_rooms[pos] = "boss"
	elif should_be_mini_boss or room_data.get("difficulty") == "Elite":
		room.is_mini_boss_room = true
		room.has_combat = true
		floor.special_rooms[pos] = "mini_boss"
	else:
		## Python RNG call: rng.random() < 0.4 for combat (only if threats or combat tag)
		var threats: Array = room_data.get("threats", [])
		var has_combat_tag: bool = (room_data.get("tags", []) as Array).has("combat")
		if not threats.is_empty() or has_combat_tag:
			room.has_combat = rng.randf() < ExplorationRules.COMBAT_CHANCE
		else:
			room.has_combat = false

	return room


# ------------------------------------------------------------------
# First-visit processing — mirrors Python _continue_room_entry()
# Exact RNG call ordering preserved.
# ------------------------------------------------------------------

func _on_first_visit(room: RoomState) -> void:
	room.visited = true

	## STEP 1: generate_ground_loot (multiple RNG calls)
	_generate_ground_loot(room)

	## STEP 2: apply_on_enter mechanics (no RNG calls)
	mechanics.apply_on_enter(state, room.data)

	## STEP 3: stairs check
	## Python: only rolls if ALL conditions met. The rng.random() call is
	## consumed ONLY when conditions pass.
	## Never spawn stairs in miniboss or boss rooms.
	var is_special_room := room.is_mini_boss_room or room.is_boss_room
	if not is_special_room and not floor.stairs_found and floor.rooms_explored >= ExplorationRules.STAIRS_MIN_ROOMS:
		if rng.randf() < ExplorationRules.STAIRS_CHANCE:
			room.has_stairs = true
			floor.stairs_found = true
			logs.append("Found stairs to the next floor!")

	## STEP 4: store check
	## Python: rng.random() consumed only when rooms >= 2, !store_found, and rooms < 15
	## Prevent store from spawning in the same room as stairs.
	if not floor.store_found and floor.rooms_explored >= ExplorationRules.STORE_MIN_ROOMS:
		if floor.rooms_explored >= ExplorationRules.STORE_GUARANTEE_ROOMS:
			if not room.has_stairs:
				room.has_store = true
				floor.store_found = true
				floor.store_pos = room.coords()
				logs.append("Discovered a mysterious shop!")
		else:
			var chance := ExplorationRules.store_chance_for_floor(floor.floor_index)
			if rng.randf() < chance:
				if not room.has_stairs:
					room.has_store = true
					floor.store_found = true
					floor.store_pos = room.coords()
					logs.append("Discovered a mysterious shop!")

	## STEP 5: chest check — DEAD CODE in Python
	## Python line 393: `not room.visited` is always False because room.visited
	## was set to True in _complete_room_entry before _continue_room_entry is called.
	## So rng.random() is NEVER consumed here. We replicate this exactly:
	## The condition below can never be true because room.visited is already true.
	if not room.has_chest and not room.visited:
		if rng.randf() < ExplorationRules.CHEST_CHANCE:
			room.has_chest = true
			logs.append("There's a chest here!")

	## STEP 6: combat/enemy selection
	## Python: if combat and threats → rng.choice(combat_threats)
	##         if no combat and (threats or combat_tag) → rng.choice(peaceful_messages)
	var threats: Array = room.data.get("threats", [])
	var has_combat_tag: bool = (room.data.get("tags", []) as Array).has("combat")

	var room_name: String = room.data.get("name", "Room")
	var flavor: String = room.data.get("flavor", "")

	if room.has_combat and not room.enemies_defeated:
		if not threats.is_empty():
			var enemy_name: String = rng.choice(threats)
			logs.append("==================================================")
			logs.append("Entered: %s" % room_name)
			if not flavor.is_empty():
				logs.append(flavor)
			logs.append("Enemy: %s" % enemy_name)
		else:
			logs.append("==================================================")
			logs.append("Entered: %s" % room_name)
			if not flavor.is_empty():
				logs.append(flavor)
			logs.append("Enemy lurks here!")
	else:
		logs.append("==================================================")
		logs.append("Entered: %s" % room_name)
		if not flavor.is_empty():
			logs.append(flavor)
		if not threats.is_empty() or has_combat_tag:
			## Python RNG call: rng.choice(peaceful_messages)
			logs.append(rng.choice(PEACEFUL_MESSAGES))

	## STEP 7: describe ground loot — Python parity (navigation.py describe_ground_items)
	_describe_ground_loot(room)


# ------------------------------------------------------------------
# Ground loot — mirrors Python generate_ground_loot() exactly
# ------------------------------------------------------------------

func _generate_ground_loot(room: RoomState) -> void:
	var is_mini_boss := room.is_mini_boss_room
	var discoverables: Array = room.data.get("discoverables", [])

	## Python: container spawn
	if not discoverables.is_empty():
		if is_mini_boss:
			## Python RNG call: rng.choice(discoverables) — 100% for miniboss
			room.ground_container = rng.choice(discoverables)
		else:
			## Python RNG call: rng.random() < 0.6
			if rng.randf() < ExplorationRules.CONTAINER_CHANCE:
				## Python RNG call: rng.choice(discoverables)
				room.ground_container = rng.choice(discoverables)

		## Python: 30% lock chance on floor 2+
		if not room.ground_container.is_empty() and floor.floor_index >= ExplorationRules.CONTAINER_LOCK_MIN_FLOOR:
			## Python RNG call: rng.random() < 0.30
			if rng.randf() < ExplorationRules.CONTAINER_LOCK_CHANCE:
				room.container_locked = true

	## Python: 40% loose loot (not for miniboss rooms)
	## Python RNG call: rng.random() < 0.4
	if not is_mini_boss:
		if rng.randf() < ExplorationRules.LOOSE_LOOT_CHANCE:
			## Python RNG call: rng.random() < 0.5
			if rng.randf() < ExplorationRules.LOOSE_GOLD_VS_ITEMS:
				## Python RNG call: rng.randint(5, 20)
				room.ground_gold = rng.rand_int(ExplorationRules.LOOSE_GOLD_MIN, ExplorationRules.LOOSE_GOLD_MAX)
			else:
				## Python RNG call: rng.randint(1, 2)
				var num_items := rng.rand_int(ExplorationRules.LOOSE_ITEMS_MIN, ExplorationRules.LOOSE_ITEMS_MAX)
				for i in num_items:
					## Python RNG call: rng.choice(available_items)
					room.ground_items.append(rng.choice(ExplorationRules.LOOSE_ITEM_POOL))


# ------------------------------------------------------------------
# Describe ground loot — Python parity: navigation.py describe_ground_items()
# Appends a single "You notice on the ground: …" log line when anything
# is present. No RNG calls; pure log output only.
# ------------------------------------------------------------------

func _describe_ground_loot(room: RoomState) -> void:
	var things: Array = []

	# Container: only if unsearched OR locked OR still has loot
	var container_has_loot := room.container_gold > 0 or not room.container_item.is_empty()
	if not room.ground_container.is_empty() and (not room.container_searched or room.container_locked or container_has_loot):
		var suffix := " [LOCKED]" if room.container_locked else (" [searched]" if room.container_searched else "")
		things.append("a %s%s" % [room.ground_container, suffix])

	if room.ground_gold > 0:
		things.append("%d gold coins" % room.ground_gold)

	for item_name in room.ground_items:
		things.append(item_name)

	if not things.is_empty():
		logs.append("You notice on the ground: %s" % ", ".join(things))


# ------------------------------------------------------------------
# Room clear / combat hooks
# ------------------------------------------------------------------

func on_combat_clear(room: RoomState) -> void:
	room.enemies_defeated = true
	room.cleared = true
	mechanics.apply_on_clear(state, room.data)

	var room_pos := room.coords()

	if room.is_mini_boss_room:
		floor.mini_bosses_defeated += 1
		floor.key_fragments += 1
		floor.unlocked_rooms[room_pos] = true
		logs.append("Mini-boss defeated! Key fragment: %d/3" % floor.key_fragments)
		if floor.mini_bosses_defeated == 3:
			## Python RNG call: rng.randint(4, 6)
			floor.next_boss_at = floor.rooms_explored_on_floor + rng.rand_int(
				ExplorationRules.BOSS_SPAWN_DELAY_MIN,
				ExplorationRules.BOSS_SPAWN_DELAY_MAX)
			logs.append("The floor boss will appear soon...")

	if room.is_boss_room:
		floor.boss_defeated = true
		floor.unlocked_rooms[room_pos] = true
		logs.append("Boss defeated! Stairs are now usable.")


func on_combat_fail(room: RoomState) -> void:
	mechanics.apply_on_fail(state, room.data)


# ------------------------------------------------------------------
# Interaction stubs
# ------------------------------------------------------------------

func open_chest(room: RoomState) -> Dictionary:
	if not room.has_chest or room.chest_looted:
		return {}
	room.chest_looted = true

	var loot_roll := rng.randf()
	var gold := 0
	var item := ""

	if loot_roll < 0.6:
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
		if state.inventory.size() < state.max_inventory:
			state.inventory.append(item)
		else:
			room.uncollected_items.append(item)
			logs.append("Inventory full! %s left behind." % item)

	logs.append("Opened chest: +%d gold%s" % [gold, (", " + item) if not item.is_empty() else ""])
	return {"gold": gold, "item": item}


func inspect_ground_items(room: RoomState) -> Array:
	var items: Array = []
	# Show container if: unsearched, locked, or has remaining loot
	var container_has_loot := room.container_gold > 0 or not room.container_item.is_empty()
	var show_container := not room.ground_container.is_empty() and (not room.container_searched or room.container_locked or container_has_loot)
	if show_container:
		items.append({"type": "container", "name": room.ground_container, "locked": room.container_locked, "searched": room.container_searched})
	if room.ground_gold > 0:
		items.append({"type": "gold", "amount": room.ground_gold})
	for item_name in room.ground_items:
		items.append({"type": "item", "name": item_name})
	for item_name in room.uncollected_items:
		items.append({"type": "uncollected", "name": item_name})
	for item_name in room.dropped_items:
		items.append({"type": "dropped", "name": item_name})
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
	if state.inventory.size() >= state.max_inventory:
		logs.append("Inventory full! Cannot pick up %s." % item_name)
		return ""
	room.ground_items.remove_at(index)
	state.inventory.append(item_name)
	logs.append("Picked up %s" % item_name)
	return item_name


func search_container(room: RoomState) -> Dictionary:
	if room.ground_container.is_empty():
		return {}
	if room.container_locked:
		logs.append("Container is locked!")
		return {"locked": true}

	# Already searched — return persisted contents without re-rolling
	if room.container_searched:
		return {"gold": room.container_gold, "item": room.container_item}

	room.container_searched = true

	# Use per-container JSON definitions for loot resolution (Python parity)
	var cdef: Dictionary = container_db.get(room.ground_container, {})
	var result: Dictionary
	if not cdef.is_empty():
		result = ContainerResolver.resolve_loot(rng, cdef)
	else:
		# Fallback for containers not in definitions — use hardcoded ranges
		var loot_roll := rng.randf()
		var gold := 0
		var item := ""
		if loot_roll < 0.15:
			pass
		elif loot_roll < 0.50:
			gold = rng.rand_int(5, 15)
		elif loot_roll < 0.80:
			item = rng.choice(ExplorationRules.LOOSE_ITEM_POOL)
		else:
			gold = rng.rand_int(5, 15)
			item = rng.choice(ExplorationRules.LOOSE_ITEM_POOL)
		result = {"gold": gold, "item": item}

	var gold: int = int(result.get("gold", 0))
	var item: String = str(result.get("item", ""))

	room.container_gold = gold
	room.container_item = item
	logs.append("Searched %s: %s" % [room.ground_container,
		("+%d gold, %s" % [gold, item]) if gold > 0 and not item.is_empty()
		else ("+%d gold" % gold) if gold > 0
		else item if not item.is_empty()
		else "empty"])
	return {"gold": gold, "item": item}


## Take gold from an already-searched container. Returns amount taken.
func take_container_gold(room: RoomState) -> int:
	var amount := room.container_gold
	if amount > 0:
		state.gold += amount
		state.total_gold_earned += amount
		room.container_gold = 0
		logs.append("Collected %d gold!" % amount)
	return amount


## Take the item from an already-searched container. Returns item name or "".
func take_container_item(room: RoomState) -> String:
	var item_name := room.container_item
	if item_name.is_empty():
		return ""
	if state.inventory.size() >= state.max_inventory:
		room.uncollected_items.append(item_name)
		room.container_item = ""
		logs.append("Inventory full! %s left behind." % item_name)
		return ""
	state.inventory.append(item_name)
	room.container_item = ""
	logs.append("Picked up %s!" % item_name)
	return item_name


## Take all container contents at once.
func take_all_container(room: RoomState) -> Dictionary:
	var gold := take_container_gold(room)
	var item := take_container_item(room)
	return {"gold": gold, "item": item}


## Pick up all loose ground items, gold, uncollected, and dropped. Not containers.
## Returns count of items taken.
func pickup_all_ground(room: RoomState) -> int:
	var picked := 0

	if room.ground_gold > 0:
		pickup_ground_gold(room)
		picked += 1

	while not room.ground_items.is_empty():
		var result := pickup_ground_item(room, 0)
		if result.is_empty():
			break
		picked += 1

	while not room.uncollected_items.is_empty():
		var item_name: String = room.uncollected_items[0]
		if state.inventory.size() >= state.max_inventory:
			logs.append("Inventory full! Cannot pick up remaining items.")
			break
		room.uncollected_items.remove_at(0)
		state.inventory.append(item_name)
		logs.append("Picked up %s" % item_name)
		picked += 1

	while not room.dropped_items.is_empty():
		var item_name: String = room.dropped_items[0]
		if state.inventory.size() >= state.max_inventory:
			logs.append("Inventory full! Cannot pick up remaining items.")
			break
		room.dropped_items.remove_at(0)
		state.inventory.append(item_name)
		logs.append("Picked up %s" % item_name)
		picked += 1

	if picked > 0:
		logs.append("Collected %d item(s)." % picked)
	return picked


func can_use_stairs() -> bool:
	var room := floor.get_current_room()
	return room != null and room.has_stairs and floor.boss_defeated


func can_enter_miniboss_room() -> bool:
	return state.inventory.has("Old Key")


func can_enter_boss_room() -> bool:
	return floor.key_fragments >= 3


## Unlock a miniboss room by consuming an Old Key. Returns true on success.
func unlock_miniboss_room(pos: Vector2i) -> bool:
	if not can_enter_miniboss_room():
		return false
	state.inventory.erase("Old Key")
	floor.unlocked_rooms[pos] = true
	logs.append("Used Old Key to unlock elite room.")
	return true


## Unlock a boss room by consuming 3 key fragments. Returns true on success.
func unlock_boss_room(pos: Vector2i) -> bool:
	if not can_enter_boss_room():
		return false
	floor.key_fragments = 0
	floor.unlocked_rooms[pos] = true
	logs.append("Key fragments merged! Boss door opened.")
	return true


func enter_store(_room: RoomState) -> Array:
	logs.append("Browsing store...")
	return ["Health Potion", "Repair Kit", "Lockpick Kit"]


## Fast travel to the store if discovered on current floor.
## Returns the store RoomState or null if unavailable.
func travel_to_store() -> RoomState:
	if not floor.store_found or floor.store_pos == Vector2i(-999, -999):
		logs.append("No store found on this floor yet!")
		return null
	if floor.current_pos == floor.store_pos:
		logs.append("You are already at the store!")
		return null
	var old_room := floor.get_current_room()
	var old_name: String = old_room.data.get("name", "Unknown Location") if old_room else "Unknown"
	floor.current_pos = floor.store_pos
	var store_room := floor.get_current_room()
	logs.append("Traveled to the store from %s!" % old_name)
	return store_room


# ------------------------------------------------------------------
# Room selection — mirrors Python pick_room_for_floor() in rooms_loader.py
# ------------------------------------------------------------------

func _pick_room_for_floor(floor_idx: int) -> Dictionary:
	if rooms_db.is_empty():
		return {}
	var target: String
	if floor_idx <= 3: target = "Easy"
	elif floor_idx <= 6: target = "Medium"
	elif floor_idx <= 9: target = "Hard"
	elif floor_idx <= 12: target = "Elite"
	else:
		target = "Elite"
		if floor_idx % 3 == 0:
			target = "Boss"

	var pool := rooms_db.filter(func(r): return r.get("difficulty") == target)
	if pool.is_empty():
		pool = rooms_db

	## Python RNG call: rng.random() < 0.20 (non-combat preference)
	if rng.randf() < ExplorationRules.NON_COMBAT_PREFER_CHANCE:
		var non_combat_tags := ["lore", "puzzle", "event", "rest", "environment"]
		var nc_pool := pool.filter(func(r):
			var tags: Array = r.get("tags", [])
			return tags.any(func(t): return t in non_combat_tags) and not tags.has("combat"))
		if not nc_pool.is_empty():
			pool = nc_pool

	## Python RNG call: rng.choice(pool)
	return rng.choice(pool)
