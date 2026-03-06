class_name ContentManager
extends RefCounted
## Centralised data store — loads and caches every JSON DB from res://data.
##
## Individual loader classes (RoomsData, ItemsData, …) remain unchanged;
## ContentManager orchestrates them once and then exposes typed getters so
## callers never touch file I/O or loader internals directly.

var _rooms_data: RoomsData
var _items_data: ItemsData
var _enemy_types_data: EnemyTypesData
var _lore_data: LoreData
var _world_lore_data: WorldLoreData
var _container_data: ContainerData

var _loaded: bool = false


func load_all() -> bool:
	_rooms_data = RoomsData.new()
	_items_data = ItemsData.new()
	_enemy_types_data = EnemyTypesData.new()
	_lore_data = LoreData.new()
	_world_lore_data = WorldLoreData.new()
	_container_data = ContainerData.new()

	var ok := true
	if not _rooms_data.load():
		ok = false
	if not _items_data.load():
		ok = false
	if not _enemy_types_data.load():
		ok = false
	if not _lore_data.load():
		ok = false
	if not _world_lore_data.load():
		ok = false
	if not _container_data.load():
		ok = false

	_loaded = ok
	return ok


func is_loaded() -> bool:
	return _loaded


# ----- Rooms -----

func get_room_templates() -> Array:
	return _rooms_data.rooms if _rooms_data else []


func get_room(index: int) -> Dictionary:
	var rooms := get_room_templates()
	if index < 0 or index >= rooms.size():
		return {}
	return rooms[index]


# ----- Items -----

func get_items_db() -> Dictionary:
	return _items_data.items if _items_data else {}


func get_item_def(id: String) -> Dictionary:
	return get_items_db().get(id, {})


# ----- Enemies -----

func get_enemy_types_db() -> Dictionary:
	return _enemy_types_data.enemies if _enemy_types_data else {}


func get_enemy_def(name: String) -> Dictionary:
	return get_enemy_types_db().get(name, {})


# ----- Lore -----

func get_lore_db() -> Dictionary:
	return _lore_data.lore if _lore_data else {}


func get_lore_entry(category: String) -> Array:
	return get_lore_db().get(category, [])


# ----- World Lore -----

func get_world_lore() -> Dictionary:
	return _world_lore_data.world_lore if _world_lore_data else {}


# ----- Containers -----

func get_container_db() -> Dictionary:
	return _container_data.containers if _container_data else {}


func get_container_def(name: String) -> Dictionary:
	return get_container_db().get(name, {})
