class_name LoreData
extends RefCounted
## Loader for lore_items.json — dictionary with lore categories.

const _FILENAME := "lore_items.json"
const EXPECTED_CATEGORIES := [
	"guards_journal_pages", "quest_notices", "training_manual_pages",
	"scrawled_notes", "pressed_pages", "surgeons_notes", "puzzle_notes",
	"star_charts", "cracked_map_scraps", "old_letters", "prayer_strips",
]

var lore: Dictionary = {}


func load() -> bool:
	lore = JsonLoader.load_json_dict(_FILENAME)
	if lore.is_empty():
		return false
	for cat in EXPECTED_CATEGORIES:
		if not lore.has(cat):
			push_error("LoreData: missing category '%s'" % cat)
			return false
		if not lore[cat] is Array:
			push_error("LoreData: category '%s' is not an array" % cat)
			return false
	return true
