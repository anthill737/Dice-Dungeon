class_name AdventureLogService
extends RefCounted
## Append-only adventure log with signal notification.
##
## UI listens to entry_added to render new lines; the full history is
## available via get_entries() for save-game snapshots or replays.

signal entry_added(entry: String)

var _entries: Array = []


func append(entry: String) -> void:
	_entries.append(entry)
	entry_added.emit(entry)


func clear() -> void:
	_entries.clear()


func get_entries() -> Array:
	return _entries.duplicate()


func size() -> int:
	return _entries.size()
