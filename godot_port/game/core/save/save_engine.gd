class_name SaveEngine
extends RefCounted
## Save/Load engine — headless core, no UI.
##
## Mirrors Python save_to_slot / load_from_slot exactly.
## Serialises GameState + FloorState into a JSON dict compatible with the
## Python save layout (dice_dungeon_save_slot_{n}.json).
##
## Python does NOT persist RNG state. After load the RNG is a fresh
## DefaultRNG (non-deterministic). This engine matches that behaviour:
## RNG state is NOT included in the save dict. For parity tests the
## caller supplies a PortableLCG and its _state is stored separately
## by the test harness (not by this engine).
##
## Slot management: 10 slots (1-10), logic only, no file IO.

const MAX_SLOTS := 10


# ------------------------------------------------------------------
# Serialize — mirrors Python save_to_slot()
# ------------------------------------------------------------------

static func serialize(game: GameState, floor_st: FloorState, slot_num: int = 1, save_name: String = "") -> Dictionary:
	var rooms_data := {}
	for pos_key in floor_st.rooms:
		var pos: Vector2i = pos_key
		var room: RoomState = floor_st.rooms[pos]
		var key := "%d,%d" % [pos.x, pos.y]
		rooms_data[key] = _serialize_room(room)

	var special_rooms := {}
	for pos_key in floor_st.special_rooms:
		var pos: Vector2i = pos_key
		special_rooms["%d,%d" % [pos.x, pos.y]] = floor_st.special_rooms[pos]

	var unlocked_rooms: Array = []
	for pos_key in floor_st.unlocked_rooms:
		var pos: Vector2i = pos_key
		unlocked_rooms.append("%d,%d" % [pos.x, pos.y])

	var starter_rooms: Array = []
	for pos_key in floor_st.starter_rooms:
		var pos: Vector2i = pos_key
		starter_rooms.append([pos.x, pos.y])

	var equipped_out := {}
	for slot in game.equipped_items:
		var item_val: String = game.equipped_items[slot]
		equipped_out[slot] = item_val if not item_val.is_empty() else null

	var purchased_list: Array = []
	for k in game.purchased_upgrades_this_floor:
		purchased_list.append(k)

	var save_data := {
		"save_time": Time.get_datetime_string_from_system(false, true).replace("T", " "),
		"slot_num": slot_num,
		"save_name": save_name,
		"gold": game.gold,
		"health": game.health,
		"max_health": game.max_health,
		"max_inventory": game.max_inventory,
		"armor": game.armor,
		"floor": game.floor,
		"run_score": 0,
		"total_gold_earned": game.total_gold_earned,
		"rooms_explored": floor_st.rooms_explored,
		"enemies_killed": 0,
		"chests_opened": 0,
		"inventory": game.inventory.duplicate(),
		"equipped_items": equipped_out,
		"equipment_durability": game.equipment_durability.duplicate(true),
		"equipment_floor_level": game.equipment_floor_level.duplicate(true),
		"adventure_log": [],
		"num_dice": game.num_dice,
		"multiplier": game.multiplier,
		"damage_bonus": game.damage_bonus,
		"heal_bonus": 0,
		"reroll_bonus": game.reroll_bonus,
		"crit_chance": game.crit_chance,
		"flags": game.flags.duplicate(true),
		"temp_effects": game.temp_effects.duplicate(true),
		"temp_shield": game.temp_shield,
		"shop_discount": game.shop_discount,
		"stairs_found": floor_st.stairs_found,
		"rest_cooldown": 0,
		"current_pos": [floor_st.current_pos.x, floor_st.current_pos.y],
		"rooms": rooms_data,
		"store_found": floor_st.store_found,
		"store_position": [floor_st.store_pos.x, floor_st.store_pos.y] if floor_st.store_found else null,
		"mini_bosses_defeated": floor_st.mini_bosses_defeated,
		"boss_defeated": floor_st.boss_defeated,
		"mini_bosses_spawned_this_floor": floor_st.mini_bosses_spawned,
		"boss_spawned_this_floor": floor_st.boss_spawned,
		"rooms_explored_on_floor": floor_st.rooms_explored_on_floor,
		"next_mini_boss_at": floor_st.next_mini_boss_at,
		"next_boss_at": floor_st.next_boss_at if floor_st.next_boss_at >= 0 else null,
		"key_fragments_collected": floor_st.key_fragments,
		"special_rooms": special_rooms,
		"unlocked_rooms": unlocked_rooms,
		"used_lore_entries": _dict_deep_copy(game.used_lore_entries),
		"discovered_lore_items": [],
		"lore_item_assignments": _dict_deep_copy(game.lore_item_assignments),
		"lore_item_counters": {},
		"lore_codex": _array_deep_copy(game.lore_codex),
		"settings": {
			"color_scheme": "Classic",
			"difficulty": "Normal",
			"text_speed": "Medium",
			"keybindings": {},
		},
		"stats": game.stats.duplicate(true),
		"purchased_upgrades_this_floor": purchased_list,
		"in_starter_area": false,
		"starter_chests_opened": [],
		"signs_read": [],
		"starter_rooms": starter_rooms,
	}

	return save_data


# ------------------------------------------------------------------
# Deserialize — mirrors Python load_from_slot()
# ------------------------------------------------------------------

static func deserialize(save_data: Dictionary, game: GameState, floor_st: FloorState) -> void:
	game.gold = int(save_data.get("gold", 0))
	game.health = int(save_data.get("health", 50))
	game.max_health = int(save_data.get("max_health", 50))
	game.floor = int(save_data.get("floor", 1))
	game.total_gold_earned = int(save_data.get("total_gold_earned", 0))
	game.inventory = Array(save_data.get("inventory", []))

	var eq: Dictionary = save_data.get("equipped_items", {})
	game.equipped_items = {
		"weapon": _str_or_empty(eq.get("weapon")),
		"armor": _str_or_empty(eq.get("armor")),
		"accessory": _str_or_empty(eq.get("accessory")),
		"backpack": _str_or_empty(eq.get("backpack")),
	}

	game.equipment_durability = _dict_deep_copy(save_data.get("equipment_durability", {}))
	game.equipment_floor_level = _dict_deep_copy(save_data.get("equipment_floor_level", {}))

	game.num_dice = int(save_data.get("num_dice", 3))
	game.multiplier = float(save_data.get("multiplier", 1.0))
	game.damage_bonus = int(save_data.get("damage_bonus", 0))
	game.reroll_bonus = int(save_data.get("reroll_bonus", 0))
	game.crit_chance = float(save_data.get("crit_chance", 0.1))

	game.max_inventory = int(save_data.get("max_inventory", 20))
	game.armor = int(save_data.get("armor", 0))

	game.flags = _dict_deep_copy(save_data.get("flags", {"disarm_token": 0, "escape_token": 0, "statuses": []}))
	game.temp_effects = _dict_deep_copy(save_data.get("temp_effects", {}))
	game.temp_shield = int(save_data.get("temp_shield", 0))
	game.shop_discount = float(save_data.get("shop_discount", 0.0))

	if save_data.has("stats"):
		game.stats = _dict_deep_copy(save_data["stats"])
	else:
		game.stats = {
			"items_used": 0, "potions_used": 0, "items_found": 0,
			"items_sold": 0, "items_purchased": 0, "gold_found": 0,
			"gold_spent": 0, "containers_searched": 0,
		}

	var pur = save_data.get("purchased_upgrades_this_floor", [])
	game.purchased_upgrades_this_floor = {}
	if pur is Array:
		for p in pur:
			game.purchased_upgrades_this_floor[str(p)] = true
	elif pur is Dictionary:
		game.purchased_upgrades_this_floor = _dict_deep_copy(pur)

	# Lore state
	game.used_lore_entries = _dict_deep_copy(save_data.get("used_lore_entries", {}))
	game.lore_item_assignments = _dict_deep_copy(save_data.get("lore_item_assignments", {}))
	game.lore_codex = _array_deep_copy(save_data.get("lore_codex", []))

	# Deduplicate codex by item_key
	var _seen_keys := {}
	var _deduped: Array = []
	for entry in game.lore_codex:
		var ik = entry.get("item_key", "")
		if ik.is_empty() or not _seen_keys.has(ik):
			_deduped.append(entry)
			if not ik.is_empty():
				_seen_keys[ik] = true
	game.lore_codex = _deduped

	# Combat state reset on load
	game.in_combat = false
	game.temp_combat_damage = 0
	game.temp_combat_crit = 0.0
	game.temp_combat_rerolls = 0

	# --- FloorState ---
	floor_st.floor_index = int(save_data.get("floor", 1))

	var cur_pos = save_data.get("current_pos", [0, 0])
	floor_st.current_pos = Vector2i(int(cur_pos[0]), int(cur_pos[1]))

	floor_st.rooms_explored = int(save_data.get("rooms_explored", 0))
	floor_st.rooms_explored_on_floor = int(save_data.get("rooms_explored_on_floor", 0))

	floor_st.mini_bosses_spawned = int(save_data.get("mini_bosses_spawned_this_floor", 0))
	floor_st.mini_bosses_defeated = int(save_data.get("mini_bosses_defeated", 0))
	floor_st.boss_spawned = bool(save_data.get("boss_spawned_this_floor", false))
	floor_st.boss_defeated = bool(save_data.get("boss_defeated", false))
	floor_st.key_fragments = int(save_data.get("key_fragments_collected", 0))

	var nma = save_data.get("next_mini_boss_at", 8)
	floor_st.next_mini_boss_at = int(nma) if nma != null else 8

	var nba = save_data.get("next_boss_at", null)
	floor_st.next_boss_at = int(nba) if nba != null else -1

	floor_st.stairs_found = bool(save_data.get("stairs_found", false))
	floor_st.store_found = bool(save_data.get("store_found", false))

	var sp = save_data.get("store_position", null)
	if sp != null and sp is Array and sp.size() >= 2:
		floor_st.store_pos = Vector2i(int(sp[0]), int(sp[1]))
	else:
		floor_st.store_pos = Vector2i(-999, -999)

	# Special rooms
	floor_st.special_rooms = {}
	var sr_data: Dictionary = save_data.get("special_rooms", {})
	for pos_key in sr_data:
		var parts := (pos_key as String).split(",")
		if parts.size() >= 2:
			floor_st.special_rooms[Vector2i(int(parts[0]), int(parts[1]))] = sr_data[pos_key]

	# Unlocked rooms
	floor_st.unlocked_rooms = {}
	var ur_data = save_data.get("unlocked_rooms", [])
	if ur_data is Array:
		for pos_key in ur_data:
			var parts := (pos_key as String).split(",")
			if parts.size() >= 2:
				floor_st.unlocked_rooms[Vector2i(int(parts[0]), int(parts[1]))] = true

	# Starter rooms
	floor_st.starter_rooms = {}
	var star_data = save_data.get("starter_rooms", [])
	if star_data is Array:
		for pos in star_data:
			if pos is Array and pos.size() >= 2:
				floor_st.starter_rooms[Vector2i(int(pos[0]), int(pos[1]))] = true
			elif pos is String:
				var parts := (pos as String).split(",")
				if parts.size() >= 2:
					floor_st.starter_rooms[Vector2i(int(parts[0]), int(parts[1]))] = true

	# Rooms
	floor_st.rooms = {}
	var rooms_dict: Dictionary = save_data.get("rooms", {})
	for pos_key in rooms_dict:
		var parts := (pos_key as String).split(",")
		if parts.size() < 2:
			continue
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		var rd: Dictionary = rooms_dict[pos_key]
		floor_st.rooms[pos] = _deserialize_room(rd)

	# Reconstruct has_store from store_pos for backward compat with old saves
	if floor_st.store_found and floor_st.store_pos != Vector2i(-999, -999):
		if floor_st.rooms.has(floor_st.store_pos):
			floor_st.rooms[floor_st.store_pos].has_store = true


# ------------------------------------------------------------------
# save_to_string / load_from_string — API for deterministic tests
# ------------------------------------------------------------------

static func save_to_string(game: GameState, floor_st: FloorState, slot_num: int = 1, save_name: String = "") -> String:
	var d := serialize(game, floor_st, slot_num, save_name)
	return JSON.stringify(d, "  ")


static func load_from_string(json_str: String, game: GameState, floor_st: FloorState) -> bool:
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		push_error("SaveEngine.load_from_string: parse error: %s" % json.get_error_message())
		return false
	if not json.data is Dictionary:
		push_error("SaveEngine.load_from_string: root is not a Dictionary")
		return false
	deserialize(json.data, game, floor_st)
	return true


# ------------------------------------------------------------------
# Slot management (logic only, no file IO)
# ------------------------------------------------------------------

static func slot_filename(slot_num: int) -> String:
	return "dice_dungeon_save_slot_%d.json" % slot_num


static func is_valid_slot(slot_num: int) -> bool:
	return slot_num >= 1 and slot_num <= MAX_SLOTS


static func save_to_slot(game: GameState, floor_st: FloorState, saves_dir: String, slot_num: int, save_name: String = "") -> bool:
	if not is_valid_slot(slot_num):
		push_error("SaveEngine: invalid slot %d" % slot_num)
		return false
	var path := saves_dir.path_join(slot_filename(slot_num))
	var json_str := save_to_string(game, floor_st, slot_num, save_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveEngine: cannot open %s for writing" % path)
		return false
	f.store_string(json_str)
	f.close()
	return true


static func load_from_slot(saves_dir: String, slot_num: int, game: GameState, floor_st: FloorState) -> bool:
	if not is_valid_slot(slot_num):
		push_error("SaveEngine: invalid slot %d" % slot_num)
		return false
	var path := saves_dir.path_join(slot_filename(slot_num))
	if not FileAccess.file_exists(path):
		push_error("SaveEngine: slot file not found: %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SaveEngine: cannot open %s for reading" % path)
		return false
	var json_str := f.get_as_text()
	f.close()
	return load_from_string(json_str, game, floor_st)


static func delete_slot(saves_dir: String, slot_num: int) -> bool:
	if not is_valid_slot(slot_num):
		return false
	var path := saves_dir.path_join(slot_filename(slot_num))
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(path)
	return true


static func rename_slot(saves_dir: String, slot_num: int, new_name: String) -> bool:
	if not is_valid_slot(slot_num):
		return false
	var path := saves_dir.path_join(slot_filename(slot_num))
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var json_str := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return false
	if not json.data is Dictionary:
		return false
	json.data["save_name"] = new_name
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_string(JSON.stringify(json.data, "  "))
	out.close()
	return true


static func list_slots(saves_dir: String) -> Array:
	var result: Array = []
	for i in range(1, MAX_SLOTS + 1):
		var path := saves_dir.path_join(slot_filename(i))
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
					result.append({
						"slot": i,
						"save_name": json.data.get("save_name", ""),
						"save_time": json.data.get("save_time", ""),
						"floor": int(json.data.get("floor", 1)),
						"health": int(json.data.get("health", 50)),
						"gold": int(json.data.get("gold", 0)),
					})
				f.close()
		else:
			result.append({"slot": i, "empty": true})
	return result


# ------------------------------------------------------------------
# Room serialization helpers
# ------------------------------------------------------------------

static func _serialize_room(room: RoomState) -> Dictionary:
	return {
		"room_data": room.data.duplicate(true),
		"x": room.x,
		"y": room.y,
		"visited": room.visited,
		"cleared": room.cleared,
		"has_stairs": room.has_stairs,
		"has_chest": room.has_chest,
		"chest_looted": room.chest_looted,
		"enemies_defeated": room.enemies_defeated,
		"has_combat": room.has_combat,
		"has_store": room.has_store,
		"exits": room.exits.duplicate(true),
		"blocked_exits": Array(room.blocked_exits).duplicate(),
		"collected_discoverables": [],
		"uncollected_items": Array(room.uncollected_items).duplicate(),
		"dropped_items": Array(room.dropped_items).duplicate(),
		"is_mini_boss_room": room.is_mini_boss_room,
		"is_boss_room": room.is_boss_room,
		"ground_container": room.ground_container if not room.ground_container.is_empty() else null,
		"ground_items": Array(room.ground_items).duplicate(),
		"ground_gold": room.ground_gold,
		"container_searched": room.container_searched,
		"container_locked": room.container_locked,
		"combat_escaped": room.combat_escaped,
	}


static func _deserialize_room(rd: Dictionary) -> RoomState:
	var room_data: Dictionary = rd.get("room_data", {})
	var room := RoomState.new(room_data, int(rd.get("x", 0)), int(rd.get("y", 0)))
	room.visited = bool(rd.get("visited", false))
	room.cleared = bool(rd.get("cleared", false))
	room.has_stairs = bool(rd.get("has_stairs", false))
	room.has_chest = bool(rd.get("has_chest", false))
	room.chest_looted = bool(rd.get("chest_looted", false))
	room.enemies_defeated = bool(rd.get("enemies_defeated", false))

	var hc = rd.get("has_combat", null)
	if hc == null:
		if bool(rd.get("is_boss_room", false)) or bool(rd.get("is_mini_boss_room", false)):
			room.has_combat = true
		else:
			var threats: Array = room_data.get("threats", [])
			var has_combat_tag: bool = (room_data.get("tags", []) as Array).has("combat")
			room.has_combat = not threats.is_empty() or has_combat_tag
	else:
		room.has_combat = bool(hc)

	room.has_store = bool(rd.get("has_store", false))

	room.exits = _dict_deep_copy(rd.get("exits", {"N": true, "S": true, "E": true, "W": true}))

	var be = rd.get("blocked_exits", [])
	room.blocked_exits = []
	if be is Array:
		for b in be:
			room.blocked_exits.append(str(b))

	room.is_mini_boss_room = bool(rd.get("is_mini_boss_room", false))
	room.is_boss_room = bool(rd.get("is_boss_room", false))

	var gc = rd.get("ground_container", null)
	room.ground_container = str(gc) if gc != null else ""

	room.container_searched = bool(rd.get("container_searched", false))
	room.container_locked = bool(rd.get("container_locked", false))
	room.combat_escaped = bool(rd.get("combat_escaped", false))
	room.ground_gold = int(rd.get("ground_gold", 0))

	var gi = rd.get("ground_items", [])
	room.ground_items = []
	if gi is Array:
		for item in gi:
			room.ground_items.append(str(item))

	var ui = rd.get("uncollected_items", [])
	room.uncollected_items = []
	if ui is Array:
		for item in ui:
			room.uncollected_items.append(str(item))

	var di = rd.get("dropped_items", [])
	room.dropped_items = []
	if di is Array:
		for item in di:
			room.dropped_items.append(str(item))

	return room


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

static func _str_or_empty(val) -> String:
	if val == null:
		return ""
	return str(val)


static func _dict_deep_copy(d) -> Dictionary:
	if d == null:
		return {}
	if d is Dictionary:
		var out := {}
		for k in d:
			var v = d[k]
			if v is Dictionary:
				out[k] = _dict_deep_copy(v)
			elif v is Array:
				out[k] = _array_deep_copy(v)
			else:
				out[k] = v
		return out
	return {}


static func _array_deep_copy(a) -> Array:
	if a == null:
		return []
	if a is Array:
		var out: Array = []
		for v in a:
			if v is Dictionary:
				out.append(_dict_deep_copy(v))
			elif v is Array:
				out.append(_array_deep_copy(v))
			else:
				out.append(v)
		return out
	return []
