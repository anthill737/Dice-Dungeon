class_name LoreEngine
extends RefCounted
## Headless lore engine — mirrors Python explorer/lore.py.
##
## Manages lore entry assignment, codex population, and read tracking.
## NO UI — all operations mutate GameState and return result dicts.

var rng: RNG
var state: GameState
var lore_db: Dictionary = {}
var logs: Array[String] = []

const LORE_TYPE_MAP := {
	"Guard Journal":          ["guards_journal", "guards_journal_pages"],
	"Quest Notice":           ["quest_notice",   "quest_notices"],
	"Scrawled Note":          ["scrawled_note",  "scrawled_notes"],
	"Ledger Entry":           ["scrawled_note",  "scrawled_notes"],
	"Training Manual Page":   ["training_manual","training_manual_pages"],
	"Training Manual Scrap":  ["training_manual","training_manual_pages"],
	"Pressed Page":           ["pressed_page",   "pressed_pages"],
	"Surgeon Note":           ["surgeons_note",  "surgeons_notes"],
	"Surgeon's Note":         ["surgeons_note",  "surgeons_notes"],
	"Puzzle Note":            ["puzzle_note",    "puzzle_notes"],
	"Star Chart Scrap":       ["star_chart",     "star_charts"],
	"Star Chart":             ["star_chart",     "star_charts"],
	"Cracked Map Scrap":      ["map_scrap",      "cracked_map_scraps"],
	"Prayer Strip":           ["prayer_strip",   "prayer_strips"],
	"Old Letter":             ["old_letter",     "old_letters"],
}

const TITLE_MAP := {
	"guards_journal":  "Guard Journal",
	"quest_notice":    "Quest Notice",
	"scrawled_note":   "Scrawled Note",
	"training_manual": "Training Manual Page",
	"pressed_page":    "Pressed Page",
	"surgeons_note":   "Surgeon's Note",
	"puzzle_note":     "Puzzle Note",
	"star_chart":      "Star Chart",
	"map_scrap":       "Cracked Map Scrap",
	"prayer_strip":    "Prayer Strip",
	"old_letter":      "Old Letter",
}

const CATEGORY_DISPLAY := {
	"guards_journal":  "Guard Journals",
	"quest_notice":    "Quest Notices",
	"scrawled_note":   "Scrawled Notes",
	"training_manual": "Training Manuals",
	"pressed_page":    "Pressed Pages",
	"surgeons_note":   "Surgeon's Notes",
	"puzzle_note":     "Puzzle Notes",
	"star_chart":      "Star Charts",
	"map_scrap":       "Cracked Map Scraps",
	"prayer_strip":    "Prayer Strips",
	"old_letter":      "Old Letters",
}


func _init(p_rng: RNG, p_state: GameState, p_lore_db: Dictionary = {}) -> void:
	rng = p_rng if p_rng != null else DefaultRNG.new()
	state = p_state
	lore_db = p_lore_db


## Resolve item_name to [lore_type, lore_key] or empty array if not readable_lore.
func resolve_lore_type(item_name: String) -> Array:
	var base := item_name.split(" #")[0] if " #" in item_name else item_name
	if LORE_TYPE_MAP.has(base):
		return LORE_TYPE_MAP[base].duplicate()
	return []


## Assign or retrieve a lore entry index for a specific item instance.
## Mirrors Python _get_lore_entry_index.
func _get_lore_entry_index(lore_key: String, item_key: String) -> int:
	if state.lore_item_assignments.has(item_key):
		return int(state.lore_item_assignments[item_key])

	var entries: Array = lore_db.get(lore_key, [])
	var total: int = entries.size()
	if total == 0:
		return 0

	if not state.used_lore_entries.has(lore_key):
		state.used_lore_entries[lore_key] = []

	var used: Array = state.used_lore_entries[lore_key]
	var available: Array = []
	for i in range(total):
		if not used.has(i):
			available.append(i)

	var entry_index: int
	if available.is_empty():
		entry_index = rng.rand_int(0, total - 1)
		logs.append("You've read all these. This one seems familiar...")
	else:
		entry_index = rng.choice(available)
		(state.used_lore_entries[lore_key] as Array).append(entry_index)

	state.lore_item_assignments[item_key] = entry_index
	return entry_index


## Read a readable_lore item. Returns the display entry dict and whether it was
## newly added to the codex.  Mirrors Python read_lore_item.
func read_lore_item(item_name: String, idx: int) -> Dictionary:
	var base := item_name.split(" #")[0] if " #" in item_name else item_name
	var info := resolve_lore_type(base)
	if info.is_empty():
		logs.append("Cannot read %s." % item_name)
		return {"ok": false, "reason": "not_readable_lore"}

	var lore_type: String = info[0]
	var lore_key: String = info[1]
	var item_key := "%s_%d" % [base, idx]
	var standard_title: String = TITLE_MAP.get(lore_type, base)

	var is_new := not state.lore_item_assignments.has(item_key)
	var entry_index: int

	if is_new:
		entry_index = _get_lore_entry_index(lore_key, item_key)
		var entries: Array = lore_db.get(lore_key, [])
		if entry_index >= entries.size():
			return {"ok": false, "reason": "entry_out_of_range"}
		var entry: Dictionary = entries[entry_index]

		var subtitle := _build_subtitle(lore_type, entry)
		var unique_id := _next_unique_id(lore_type)

		state.lore_codex.append({
			"type": lore_type,
			"title": standard_title,
			"subtitle": subtitle,
			"content": _entry_text(entry),
			"floor_found": state.floor,
			"unique_id": unique_id,
			"item_key": item_key,
		})
		logs.append("New lore discovered: %s #%d!" % [standard_title, unique_id])
	else:
		entry_index = int(state.lore_item_assignments.get(item_key, 0))

	var entries: Array = lore_db.get(lore_key, [])
	if entry_index >= entries.size():
		return {"ok": false, "reason": "entry_out_of_range"}
	var entry: Dictionary = entries[entry_index]

	var subtitle := _build_subtitle(lore_type, entry)
	var display_entry := {
		"type": lore_type,
		"title": standard_title,
		"subtitle": subtitle,
		"content": _entry_text(entry),
		"floor_found": state.floor,
	}

	return {"ok": true, "entry": display_entry, "is_new": is_new}


func get_codex() -> Array:
	return state.lore_codex


func get_codex_categories() -> Array:
	var cats: Array[String] = []
	for e in state.lore_codex:
		var t: String = e.get("type", "")
		if not t.is_empty() and not cats.has(t):
			cats.append(t)
	return cats


func _build_subtitle(lore_type: String, entry: Dictionary) -> String:
	match lore_type:
		"guards_journal":
			return entry.get("date", "")
		"quest_notice":
			var reward = entry.get("reward", "Unknown")
			return "Reward: %s" % str(reward)
		"training_manual":
			return entry.get("title", "")
	return ""


func _entry_text(entry: Dictionary) -> String:
	if entry.has("text"):
		return str(entry["text"])
	return str(entry.get("content", ""))


func _next_unique_id(lore_type: String) -> int:
	var count := 0
	for e in state.lore_codex:
		if e.get("type", "") == lore_type:
			count += 1
	return count + 1
