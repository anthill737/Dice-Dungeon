class_name AdventureLogService
extends RefCounted
## Append-only adventure log with signal notification.
##
## Each entry is a Dictionary with: text, tag, category, source, action_id.
## UI listens to entry_added to render new lines; the full history is
## available via get_entries() for save-game snapshots or replays.

signal entry_added(entry: Dictionary)

const VALID_CATEGORIES := [
	"ROOM", "COMBAT", "SYSTEM", "DISCOVERY", "LOOT",
	"INTERACTION", "HAZARD", "STORE",
]

var _entries: Array = []
var _next_action_id: int = 0


func append(text: String, tag: String = "system", category: String = "SYSTEM", source: String = "system") -> void:
	if category.is_empty() or category not in VALID_CATEGORIES:
		category = "SYSTEM"
	var entry := {
		"text": text,
		"tag": tag,
		"category": category,
		"source": source,
		"action_id": _next_action_id,
	}
	_next_action_id += 1
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
