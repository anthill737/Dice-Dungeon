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

var rooms_db: Array = []
var items_db: Dictionary = {}
var enemy_types_db: Dictionary = {}

## True between entering a combat room and resolving the encounter
## (Attack pressed or flee succeeded).  Movement is blocked while true.
var combat_pending: bool = false

var _data_loaded: bool = false

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
	var id := ItemsData.new()
	if id.load():
		items_db = id.items
	var ed := EnemyTypesData.new()
	if ed.load():
		enemy_types_db = ed.enemies
	_data_loaded = true


func is_data_loaded() -> bool:
	return _data_loaded


func start_new_game() -> void:
	rng = DefaultRNG.new()
	game_state = GameState.new()
	game_state.reset()

	exploration = ExplorationEngine.new(rng, game_state, rooms_db)
	inventory_engine = InventoryEngine.new(rng, game_state, items_db)
	store_engine = StoreEngine.new(game_state, items_db)
	combat = null
	combat_pending = false

	exploration.start_floor(1)
	_emit_logs(exploration.logs)
	state_changed.emit()


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
		return null

	var room := exploration.move(direction)
	_emit_logs(exploration.logs)

	if room != null:
		_log_room_enter(room)
		_check_combat_pending(room)

	state_changed.emit()
	return room


func _check_combat_pending(room: RoomState) -> void:
	if room == null:
		return
	if room.has_combat and not room.enemies_defeated and not room.combat_escaped:
		combat_pending = true
		var threats: Array = room.data.get("threats", [])
		if not threats.is_empty():
			log_message.emit("Enemies ahead! Attack or Flee?")
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

	var threats: Array = room.data.get("threats", [])
	if threats.is_empty():
		return

	game_state.in_combat = true
	combat = CombatEngine.new(rng, game_state, game_state.num_dice, enemy_types_db)

	var enemy_name: String = threats[0]
	var enemy_data: Dictionary = enemy_types_db.get(enemy_name, {})
	var hp: int = int(enemy_data.get("health", 20))
	var dice: int = int(enemy_data.get("num_dice", 2))
	combat.add_enemy(enemy_name, hp, dice)

	log_message.emit("Combat begins against %s!" % enemy_name)
	combat_started.emit()
	state_changed.emit()


## Player chose Flee from the pending-choice prompt (before combat starts).
## Uses core 50 % chance.  No CombatEngine exists yet.
func attempt_flee_pending() -> bool:
	var success := rng.randf() < 0.5
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
	state_changed.emit()
	return result


func pickup_ground_gold() -> int:
	var room := get_current_room()
	if room == null:
		return 0
	var amount := exploration.pickup_ground_gold(room)
	_emit_logs(exploration.logs)
	state_changed.emit()
	return amount


func pickup_ground_item(index: int) -> String:
	var room := get_current_room()
	if room == null:
		return ""
	var item := exploration.pickup_ground_item(room, index)
	_emit_logs(exploration.logs)
	state_changed.emit()
	return item


func descend_stairs() -> RoomState:
	if exploration == null:
		return null
	var room := exploration.descend_floor()
	_emit_logs(exploration.logs)
	state_changed.emit()
	return room


func attempt_rest() -> void:
	if game_state == null:
		return
	var heal := mini(10, game_state.max_health - game_state.health)
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
# Logging
# -------------------------------------------------------------------

func _log_room_enter(room: RoomState) -> void:
	if room == null or exploration == null:
		return
	var fs := exploration.floor
	var pos := fs.current_pos
	var is_starter := fs.starter_rooms.has(pos)
	var threats: Array = room.data.get("threats", [])
	var suppressed := is_starter and room.has_combat == false and not threats.is_empty()
	print("[ROOM ENTER] floor=%d coord=(%d,%d) type=%s has_combat=%s enemies=%d starter=%s suppressed=%s escaped=%s" % [
		game_state.floor, pos.x, pos.y,
		room.data.get("name", "Unknown"),
		str(room.has_combat),
		threats.size() if room.has_combat else 0,
		str(is_starter),
		str(suppressed),
		str(room.combat_escaped),
	])


func _emit_logs(logs: Array) -> void:
	for msg in logs:
		log_message.emit(str(msg))
	logs.clear()
