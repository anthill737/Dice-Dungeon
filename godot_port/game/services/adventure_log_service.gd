class_name AdventureLogService
extends RefCounted
## Append-only adventure log with signal notification.
##
## Each entry is a Dictionary with "text" and optional "tag" / "category".
## UI listens to entry_added to render new lines; the full history is
## available via get_entries() for save-game snapshots or replays.

signal entry_added(entry: Dictionary)

var _entries: Array = []


func append(text: String, tag: String = "system", category: String = "") -> void:
	var entry := {"text": text, "tag": tag}
	if not category.is_empty():
		entry["category"] = category
	_entries.append(entry)
	entry_added.emit(entry)


func clear() -> void:
	_entries.clear()


func get_entries() -> Array:
	return _entries.duplicate()


func get_text_entries() -> Array:
	var texts: Array = []
	for e in _entries:
		if e is Dictionary:
			texts.append(str(e.get("text", "")))
		else:
			texts.append(str(e))
	return texts


func size() -> int:
	return _entries.size()
