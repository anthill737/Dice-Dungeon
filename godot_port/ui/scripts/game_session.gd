extends Node
## Autoload singleton holding core engines + shared state for all UI scenes.
## UI scripts read/write game state exclusively through this node.
##
## Combat lifecycle
## ────────────────
## 1. Player enters a room with has_combat && !enemies_defeated && !combat_escaped
##    → combat_pending = true (movement blocked, Attack/Flee shown)
## 2a. Player clicks Attack → accept_combat() → CombatEngine created
## 2b. Player clicks Flee   → attempt_flee_pending()
##       success → room.combat_escaped = true, combat_pending cleared
##       failure → stays pending, player may retry or attack
## 3. During active combat the player may also flee via flee_from_combat()
##       success → room.combat_escaped = true, combat + pending cleared
##       failure → stays in combat

var game_state: GameState
var rng: RNG
var exploration: ExplorationEngine
var combat: CombatEngine
var inventory_engine: InventoryEngine
var store_engine: StoreEngine
var lore_engine: LoreEngine

var rooms_db: Array = []
var items_db: Dictionary = {}
var enemy_types_db: Dictionary = {}
var lore_db: Dictionary = {}

## True between entering a combat room and resolving the encounter
## (Attack pressed or flee succeeded).  Movement is blocked while true.
var combat_pending: bool = false

var _data_loaded: bool = false

## Session trace — persists across scene transitions, reset on new/load game.
var trace: SessionTrace = SessionTrace.new()

signal state_changed()
signal combat_started()
signal combat_ended()
signal combat_pending_changed()
signal log_message(msg: String)


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	var rd := RoomsData.new()
	if rd.load():
		rooms_db = rd.rooms
	trace.record("room_template_pool_size", {"count": rooms_db.size()})
	var id := ItemsData.new()
	if id.load():
		items_db = id.items
	var ed := EnemyTypesData.new()
	if ed.load():
		enemy_types_db = ed.enemies
	var ld := LoreData.new()
	if ld.load():
		lore_db = ld.lore
	_data_loaded = true


func is_data_loaded() -> bool:
	return _data_loaded


func start_new_game() -> void:
	rng = DefaultRNG.new()
	game_state = GameState.new()
	game_state.reset()

	_apply_difficulty_settings()

	exploration = ExplorationEngine.new(rng, game_state, rooms_db)
	inventory_engine = InventoryEngine.new(rng, game_state, items_db)
	store_engine = StoreEngine.new(game_state, items_db)
	lore_engine = LoreEngine.new(rng, game_state, lore_db)
	combat = null
	combat_pending = false

	trace.reset(-1, "DefaultRNG")
	trace.difficulty = game_state.difficulty
	trace.record("run_started", {
		"difficulty": game_state.difficulty,
		"max_health": game_state.max_health,
		"num_dice": game_state.num_dice,
	})

	exploration.start_floor(1)
	_emit_logs(exploration.logs)
	_trace_sync_position()
	state_changed.emit()


func _apply_difficulty_settings() -> void:
	if game_state == null:
		return
	var sm = Engine.get_singleton("SettingsManager") if Engine.has_singleton("SettingsManager") else null
	if sm == null:
		sm = get_node_or_null("/root/SettingsManager")
	if sm != null:
		game_state.difficulty = sm.difficulty
		game_state.difficulty_mults = sm.get_difficulty_multipliers()
	else:
		game_state.difficulty = "Normal"


func get_current_room() -> RoomState:
	if exploration == null or exploration.floor == null:
		return null
	return exploration.floor.get_current_room()


func get_floor_state() -> FloorState:
	if exploration == null:
		return null
	return exploration.floor


# -------------------------------------------------------------------
# Movement
# -------------------------------------------------------------------

func move_direction(direction: String) -> RoomState:
	if exploration == null:
		return null

	if is_combat_blocking():
		log_message.emit("Cannot move — fight or flee first!")
		trace.record("move_attempted", {"dir": direction, "success": false, "reason": "combat_blocking"})
		return null

	var old_pos: Vector2i = exploration.floor.current_pos if exploration.floor != null else Vector2i.ZERO
	var room := exploration.move(direction)
	_emit_logs(exploration.logs)

	if room == null:
		trace.record("move_attempted", {"dir": direction, "success": false, "reason": "blocked"})
	else:
		_trace_sync_position()
		trace.record("move_attempted", {"dir": direction, "success": true})
		_trace_room_entered(room)
		_log_room_enter(room)
		_check_combat_pending(room)

	state_changed.emit()
	return room


func _check_combat_pending(room: RoomState) -> void:
	if room == null:
		return
	if room.has_combat and not room.enemies_defeated and not room.combat_escaped:
		combat_pending = true
		var threats: Array = room.threats if not room.threats.is_empty() else Array(room.data.get("threats", []))
		if not threats.is_empty():
			log_message.emit("Enemies ahead! Attack or Flee?")
		else:
			log_message.emit("Something lurks ahead! Attack or Flee?")
		trace.record("combat_pending_started", {
			"threats": threats.duplicate(),
			"room_name": room.room_name,
		})
		combat_pending_changed.emit()


# -------------------------------------------------------------------
# Combat lifecycle
# -------------------------------------------------------------------

## Player chose Attack from the pending-choice prompt.
func accept_combat() -> void:
	combat_pending = false
	var room := get_current_room()
	if room == null:
		return
	start_combat_for_room(room)
	combat_pending_changed.emit()


func start_combat_for_room(room: RoomState) -> void:
	if room == null or not room.has_combat or room.enemies_defeated:
		return

	var threats: Array = room.threats if not room.threats.is_empty() else Array(room.data.get("threats", []))

	game_state.in_combat = true
	combat = CombatEngine.new(rng, game_state, game_state.num_dice, enemy_types_db)

	var enemy_name: String = threats[0] if not threats.is_empty() else "Monster"
	var enemy_data: Dictionary = enemy_types_db.get(enemy_name, {})
	var base_hp: int = int(enemy_data.get("health", 20))
	var hp: int = int(float(base_hp) * game_state.difficulty_mults.get("enemy_health_mult", 1.0))
	var dice: int = int(enemy_data.get("num_dice", 2))
	combat.add_enemy(enemy_name, hp, dice)

	var enemy_list: Array = []
	for e in combat.enemies:
		enemy_list.append({"name": e.name, "hp": e.health, "dice": e.num_dice})
	trace.record("combat_started", {"enemies": enemy_list})

	log_message.emit("Combat begins against %s!" % enemy_name)
	combat_started.emit()
	state_changed.emit()


## Player chose Flee from the pending-choice prompt (before combat starts).
## Uses core 50 % chance.  No CombatEngine exists yet.
func attempt_flee_pending() -> bool:
	var success := rng.randf() < 0.5
	trace.record("flee_attempted", {"context": "pending", "success": success})
	if success:
		var room := get_current_room()
		if room != null:
			room.combat_escaped = true
		combat_pending = false
		log_message.emit("Fled successfully!")
		combat_pending_changed.emit()
		state_changed.emit()
	else:
		log_message.emit("Failed to flee!")
	return success


## Player chose Flee from within the active combat panel.
func flee_from_combat() -> bool:
	if combat == null:
		return false
	var success := combat.attempt_flee()
	trace.record("flee_attempted", {"context": "combat", "success": success})
	if success:
		var room := get_current_room()
		if room != null:
			room.combat_escaped = true
		log_message.emit("Fled successfully!")
		_end_combat_internal(false)
	else:
		log_message.emit("Failed to flee!")
	return success


func end_combat(victory: bool) -> void:
	_end_combat_internal(victory)


func _end_combat_internal(victory: bool) -> void:
	var room := get_current_room()
	if combat == null:
		return

	if victory:
		trace.record("combat_victory", {})
	else:
		trace.record("combat_defeat", {})

	if victory and room != null:
		exploration.on_combat_clear(room)
		_emit_logs(exploration.logs)
	elif room != null:
		exploration.on_combat_fail(room)
		_emit_logs(exploration.logs)

	inventory_engine.clear_combat_temps()
	combat = null
	combat_pending = false
	state_changed.emit()
	combat_ended.emit()
	combat_pending_changed.emit()


# -------------------------------------------------------------------
# Queries
# -------------------------------------------------------------------

## Movement is blocked during both pending-choice and active combat.
func is_combat_blocking() -> bool:
	return combat_pending or combat != null


func is_combat_active() -> bool:
	return combat != null


func is_pending_choice() -> bool:
	return combat_pending and combat == null


# -------------------------------------------------------------------
# Exploration helpers
# -------------------------------------------------------------------

func open_chest() -> Dictionary:
	var room := get_current_room()
	if room == null:
		return {}
	var result := exploration.open_chest(room)
	_emit_logs(exploration.logs)
	if not result.is_empty():
		trace.record("item_picked_up", {
			"source": "chest",
			"gold": int(result.get("gold", 0)),
			"item": str(result.get("item", "")),
		})
	state_changed.emit()
	return result


func pickup_ground_gold() -> int:
	var room := get_current_room()
	if room == null:
		return 0
	var amount := exploration.pickup_ground_gold(room)
	_emit_logs(exploration.logs)
	if amount > 0:
		trace.record("item_picked_up", {
			"source": "ground",
			"gold": amount,
		})
	state_changed.emit()
	return amount


func pickup_ground_item(index: int) -> String:
	var room := get_current_room()
	if room == null:
		return ""
	var item := exploration.pickup_ground_item(room, index)
	_emit_logs(exploration.logs)
	if not item.is_empty():
		trace.record("item_picked_up", {
			"source": "ground",
			"item_id": item,
			"name": item,
			"qty": 1,
		})
	state_changed.emit()
	return item


func descend_stairs() -> RoomState:
	if exploration == null:
		return null
	var room := exploration.descend_floor()
	_emit_logs(exploration.logs)
	if room != null:
		trace.record("floor_descended", {
			"new_floor": exploration.floor.floor_index,
		})
		_trace_sync_position()
		_trace_room_entered(room)
	state_changed.emit()
	return room


func attempt_rest() -> void:
	if game_state == null:
		return
	var base_heal := 10
	var heal_mult: float = game_state.difficulty_mults.get("heal_mult", 1.0)
	var heal := mini(int(float(base_heal) * heal_mult), game_state.max_health - game_state.health)
	if heal > 0:
		game_state.health += heal
		log_message.emit("Rested and recovered %d HP." % heal)
	else:
		log_message.emit("Already at full health.")
	state_changed.emit()


func get_saves_dir() -> String:
	var dir := "user://saves"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return dir


# -------------------------------------------------------------------
# Session trace — combat detail hooks (called by CombatPanel / UI)
# -------------------------------------------------------------------

func trace_dice_rolled(values: Array) -> void:
	trace.record("dice_rolled", {"values": values.duplicate()})


func trace_dice_locked(index: int, value: int) -> void:
	trace.record("dice_locked", {"index": index, "value": value})


func trace_reroll_used(remaining: int) -> void:
	trace.record("reroll_used", {"remaining": remaining})


func trace_attack_committed(target: String, damage: int, combo: int) -> void:
	trace.record("attack_committed", {"target": target, "damage": damage, "combo": combo})


func trace_enemy_attack(enemy: String, damage: int) -> void:
	trace.record("enemy_attack", {"enemy": enemy, "damage": damage})


func trace_status_applied(status_name: String) -> void:
	trace.record("status_applied", {"status": status_name})


func trace_status_tick(status_name: String, damage: int) -> void:
	trace.record("status_tick", {"status": status_name, "damage": damage})


func trace_status_removed(status_name: String) -> void:
	trace.record("status_removed", {"status": status_name})


# -------------------------------------------------------------------
# Session trace — inventory hooks (called by UI panels)
# -------------------------------------------------------------------

func trace_item_used(item_name: String, effect_type: String) -> void:
	trace.record("item_used", {"name": item_name, "effect": effect_type})


func trace_item_equipped(item_name: String, slot: String) -> void:
	trace.record("item_equipped", {"name": item_name, "slot": slot})


func trace_item_unequipped(item_name: String, slot: String) -> void:
	trace.record("item_unequipped", {"name": item_name, "slot": slot})


func trace_item_dropped(item_name: String) -> void:
	trace.record("item_dropped", {"name": item_name})


func trace_durability_changed(item_name: String, new_dur: int, broken: bool) -> void:
	trace.record("durability_changed", {"name": item_name, "durability": new_dur, "broken": broken})


func trace_repaired(item_name: String, new_dur: int) -> void:
	trace.record("repaired", {"name": item_name, "durability": new_dur})


# -------------------------------------------------------------------
# Session trace — store hooks
# -------------------------------------------------------------------

func trace_store_entered() -> void:
	trace.record("store_entered", {})


func trace_store_bought(item_name: String, price: int) -> void:
	trace.record("store_bought", {"item": item_name, "price": price})


func trace_store_sold(item_name: String, price: int) -> void:
	trace.record("store_sold", {"item": item_name, "price": price})


func trace_upgrade_bought(upgrade_type: String, cost: int, new_value: Variant) -> void:
	trace.record("upgrade_bought", {"type": upgrade_type, "cost": cost, "new_value": str(new_value)})


# -------------------------------------------------------------------
# Session trace — save/load hooks
# -------------------------------------------------------------------

func trace_saved(slot: int, name: String) -> void:
	trace.record("saved", {"slot": slot, "name": name})


func trace_loaded(slot: int, name: String) -> void:
	trace.record("loaded", {"slot": slot, "name": name})


func trace_deleted_slot(slot: int) -> void:
	trace.record("deleted_slot", {"slot": slot})


func trace_renamed_slot(slot: int, new_name: String) -> void:
	trace.record("renamed_slot", {"slot": slot, "new_name": new_name})


# -------------------------------------------------------------------
# Session trace — settings (optional)
# -------------------------------------------------------------------

func trace_settings_changed(key: String, value: Variant) -> void:
	trace.record("settings_changed", {"key": key, "value": str(value)})


# -------------------------------------------------------------------
# Session trace — export
# -------------------------------------------------------------------

func export_session_trace() -> Dictionary:
	return trace.export_all()


# -------------------------------------------------------------------
# Logging
# -------------------------------------------------------------------

func _log_room_enter(room: RoomState) -> void:
	if room == null or exploration == null:
		return
	var fs := exploration.floor
	var pos := fs.current_pos
	var is_starter := fs.starter_rooms.has(pos)
	var suppressed := is_starter and room.has_combat == false and not room.threats.is_empty()
	print("[ROOM ENTER] floor=%d coord=(%d,%d) name=%s type=%s has_combat=%s enemies=%d starter=%s suppressed=%s escaped=%s" % [
		game_state.floor, pos.x, pos.y,
		room.room_name,
		room.room_type,
		str(room.has_combat),
		room.threats.size() if room.has_combat else 0,
		str(is_starter),
		str(suppressed),
		str(room.combat_escaped),
	])


func _emit_logs(logs: Array) -> void:
	for msg in logs:
		log_message.emit(str(msg))
	logs.clear()


# -------------------------------------------------------------------
# Trace internal helpers
# -------------------------------------------------------------------

func _trace_sync_position() -> void:
	if exploration == null or exploration.floor == null:
		return
	trace.set_floor(exploration.floor.floor_index)
	trace.set_coord(exploration.floor.current_pos)


func _trace_room_entered(room: RoomState) -> void:
	if room == null or exploration == null:
		return
	trace.record("room_entered", {
		"room_name": room.room_name,
		"room_type": room.room_type,
		"tags": room.tags.duplicate(),
		"threats": room.threats.duplicate(),
		"has_combat": room.has_combat,
		"chest": room.has_chest,
		"store": room.has_store,
		"stairs": room.has_stairs,
		"miniboss": room.is_mini_boss_room,
		"boss": room.is_boss_room,
		"blocked_exits": room.blocked_exits.duplicate(),
	})
