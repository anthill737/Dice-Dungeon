class_name SaveLoadService
extends RefCounted
## Thin coordination wrapper around SaveEngine.
##
## Owns the saves directory path and delegates all serialisation work to
## the pure SaveEngine core class.  No UI code, no direct scene switching.

signal saved(slot: int, save_name: String)
signal loaded(slot: int)
signal deleted(slot: int)
signal renamed(slot: int, new_name: String)

var _saves_dir: String


func _init(saves_dir: String = "user://saves") -> void:
	_saves_dir = saves_dir
	if not DirAccess.dir_exists_absolute(_saves_dir):
		DirAccess.make_dir_recursive_absolute(_saves_dir)


func get_saves_dir() -> String:
	return _saves_dir


func save_to_slot(game: GameState, floor_st: FloorState, slot: int, save_name: String = "") -> bool:
	var ok := SaveEngine.save_to_slot(game, floor_st, _saves_dir, slot, save_name)
	if ok:
		saved.emit(slot, save_name)
	return ok


func load_from_slot(slot: int, game: GameState, floor_st: FloorState) -> bool:
	var ok := SaveEngine.load_from_slot(_saves_dir, slot, game, floor_st)
	if ok:
		loaded.emit(slot)
	return ok


func delete_slot(slot: int) -> bool:
	var ok := SaveEngine.delete_slot(_saves_dir, slot)
	if ok:
		deleted.emit(slot)
	return ok


func rename_slot(slot: int, new_name: String) -> bool:
	var ok := SaveEngine.rename_slot(_saves_dir, slot, new_name)
	if ok:
		renamed.emit(slot, new_name)
	return ok


func list_slots() -> Array:
	return SaveEngine.list_slots(_saves_dir)


func slot_has_save(slot_id: int) -> bool:
	if not SaveEngine.is_valid_slot(slot_id):
		return false
	var path := _saves_dir.path_join(SaveEngine.slot_filename(slot_id))
	return FileAccess.file_exists(path)
