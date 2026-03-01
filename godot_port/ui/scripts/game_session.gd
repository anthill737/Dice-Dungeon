extends Node
## Autoload singleton holding core engines + shared state for all UI scenes.
## UI scripts read/write game state exclusively through this node.

var game_state: GameState
var rng: RNG
var exploration: ExplorationEngine
var combat: CombatEngine
var inventory_engine: InventoryEngine
var store_engine: StoreEngine

var rooms_db: Array = []
var items_db: Dictionary = {}
var enemy_types_db: Dictionary = {}

var _data_loaded: bool = false

signal state_changed()
signal combat_started()
signal combat_ended()
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


func move_direction(direction: String) -> RoomState:
	if exploration == null:
		return null
	var room := exploration.move(direction)
	_emit_logs(exploration.logs)
	state_changed.emit()
	return room


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


func end_combat(victory: bool) -> void:
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
	state_changed.emit()
	combat_ended.emit()


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


func _emit_logs(logs: Array) -> void:
	for msg in logs:
		log_message.emit(str(msg))
	logs.clear()
