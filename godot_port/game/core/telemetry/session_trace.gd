class_name SessionTrace
extends RefCounted
## Append-only structured event logger for a single game run.
##
## Maintains run metadata and an ordered list of events.
## Each event carries a timestamp (ms since run start), a type string,
## the current floor/coord, and an arbitrary payload dictionary.
##
## Thread-safe by virtue of Godot's single-threaded script execution.

# ------------------------------------------------------------------
# Run metadata
# ------------------------------------------------------------------

var run_id: String = ""
var start_time_utc: String = ""
var seed_value: int = -1
var rng_type: String = "Unknown"
var rng_mode: String = "default"
var game_version: String = ""
var build_time_utc: String = ""
var difficulty: String = "Normal"

# ------------------------------------------------------------------
# Replay header (computed once at run start)
# ------------------------------------------------------------------

var build_version: String = ""
var content_version: String = ""
var settings_fingerprint: String = ""

# ------------------------------------------------------------------
# Events
# ------------------------------------------------------------------

var events: Array = []  ## Array[Dictionary]

var _adventure_log: RefCounted = null  ## AdventureLogService (optional)

var _start_ticks_ms: int = 0
var _current_floor: int = 1
var _current_coord: Vector2i = Vector2i.ZERO


func _init() -> void:
	reset()


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func reset(p_seed: int = -1, p_rng_type: String = "DefaultRNG", p_rng_mode: String = "") -> void:
	run_id = _generate_run_id()
	start_time_utc = Time.get_datetime_string_from_system(true)
	seed_value = p_seed
	rng_type = p_rng_type
	rng_mode = p_rng_mode if not p_rng_mode.is_empty() else ("deterministic" if p_rng_type == "DeterministicRNG" else "default")
	game_version = BuildInfo.git_sha()
	build_time_utc = BuildInfo.build_time_utc()
	build_version = BuildInfo.git_sha()
	content_version = _compute_content_version()
	settings_fingerprint = _compute_settings_fingerprint()
	_start_ticks_ms = Time.get_ticks_msec()
	_current_floor = 1
	_current_coord = Vector2i.ZERO
	events = []


func set_adventure_log(log_service: RefCounted) -> void:
	_adventure_log = log_service


# ------------------------------------------------------------------
# Floor / coord tracking
# ------------------------------------------------------------------

func set_floor(floor_num: int) -> void:
	_current_floor = floor_num


func set_coord(coord: Vector2i) -> void:
	_current_coord = coord


# ------------------------------------------------------------------
# Event recording
# ------------------------------------------------------------------

func record(event_type: String, payload: Dictionary = {}) -> void:
	events.append({
		"t_ms": Time.get_ticks_msec() - _start_ticks_ms,
		"type": event_type,
		"floor": _current_floor,
		"coord": [_current_coord.x, _current_coord.y],
		"payload": payload,
	})


func record_rng_roll(context: String, value: int, details: Dictionary = {}) -> void:
	var payload := {"context": context, "value": value}
	if not details.is_empty():
		payload["details"] = details
	record("rng_roll", payload)


# ------------------------------------------------------------------
# Milestone snapshots
# ------------------------------------------------------------------

const MILESTONE_EVENTS := [
	"run_started", "floor_started", "room_entered",
	"combat_started", "combat_ended",
	"saved", "loaded",
]

func record_milestone(event_type: String, payload: Dictionary, snapshot: Dictionary) -> void:
	var ev := {
		"t_ms": Time.get_ticks_msec() - _start_ticks_ms,
		"type": event_type,
		"floor": _current_floor,
		"coord": [_current_coord.x, _current_coord.y],
		"payload": payload,
		"snapshot": snapshot,
	}
	events.append(ev)


static func make_snapshot(gs, fs = null, room_name: String = "") -> Dictionary:
	if gs == null:
		return {}
	var snap := {
		"floor": int(gs.floor) if gs.get("floor") != null else 1,
		"hp": int(gs.health) if gs.get("health") != null else 0,
		"max_hp": int(gs.max_health) if gs.get("max_health") != null else 0,
		"gold": int(gs.gold) if gs.get("gold") != null else 0,
		"inventory_count": gs.inventory.size() if gs.get("inventory") != null else 0,
	}
	if fs != null:
		snap["coord"] = [fs.current_pos.x, fs.current_pos.y] if fs.get("current_pos") != null else [0, 0]
	if not room_name.is_empty():
		snap["room_name"] = room_name
	var equipped: PackedStringArray = []
	if gs.get("equipment") != null and gs.equipment is Dictionary:
		for slot in gs.equipment:
			var item_name = gs.equipment[slot]
			if item_name is String and not item_name.is_empty():
				equipped.append("%s:%s" % [slot, item_name])
	snap["equipped_summary"] = ", ".join(equipped) if not equipped.is_empty() else "none"
	return snap


# ------------------------------------------------------------------
# Export — JSON
# ------------------------------------------------------------------

func export_json() -> String:
	var log_entries: Array = []
	if _adventure_log != null and _adventure_log.has_method("get_entries"):
		log_entries = _adventure_log.get_entries()

	var export_log: Array = []
	for i in log_entries.size():
		var entry = log_entries[i]
		if entry is Dictionary:
			var out := {"index": i, "text": str(entry.get("text", ""))}
			if entry.has("tag"):
				out["event_type"] = str(entry["tag"])
			if entry.has("category"):
				out["category"] = str(entry["category"])
			if entry.has("source"):
				out["source"] = str(entry["source"])
			if entry.has("action_id"):
				out["action_id"] = int(entry["action_id"])
			export_log.append(out)
		else:
			export_log.append({"index": i, "text": str(entry)})

	var data := {
		"run_id": run_id,
		"start_time_utc": start_time_utc,
		"seed": seed_value,
		"run_seed": seed_value,
		"rng_mode": rng_mode,
		"rng_type": rng_type,
		"game_version": game_version,
		"build_time_utc": build_time_utc,
		"build_version": build_version,
		"content_version": content_version,
		"settings_fingerprint": settings_fingerprint,
		"difficulty": difficulty,
		"event_count": events.size(),
		"events": events,
		"adventure_log": export_log,
		"adventure_log_count": log_entries.size(),
	}
	return JSON.stringify(data, "  ")


func export_json_to_file() -> String:
	var path := "user://session_trace_%s.json" % run_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SessionTrace: cannot write %s" % path)
		return ""
	f.store_string(export_json())
	f.close()
	return path


# ------------------------------------------------------------------
# Export — human-readable text
# ------------------------------------------------------------------

func export_text() -> String:
	var lines: PackedStringArray = []
	lines.append("=== SESSION TRACE ===")
	lines.append("Run ID      : %s" % run_id)
	lines.append("Started     : %s" % start_time_utc)
	lines.append("Seed        : %d" % seed_value)
	lines.append("RNG Mode    : %s" % rng_mode)
	lines.append("RNG Type    : %s" % rng_type)
	lines.append("Version     : %s" % game_version)
	lines.append("Build Ver   : %s" % build_version)
	lines.append("Content Ver : %s" % content_version)
	lines.append("Settings FP : %s" % settings_fingerprint)
	lines.append("Build Time  : %s" % build_time_utc)
	lines.append("Difficulty  : %s" % difficulty)
	lines.append("Total Events: %d" % events.size())
	lines.append("=====================")
	lines.append("")

	for ev in events:
		var t_ms: int = int(ev.get("t_ms", 0))
		var etype: String = str(ev.get("type", ""))
		var fl: int = int(ev.get("floor", 1))
		var coord = ev.get("coord", [0, 0])
		var payload = ev.get("payload", {})

		var secs := "%.3f" % (float(t_ms) / 1000.0)
		var coord_str := "(%s,%s)" % [str(coord[0]), str(coord[1])]
		var header := "[%ss] F%d %s  %s" % [secs, fl, coord_str, etype]
		lines.append(header)

		if payload is Dictionary and not payload.is_empty():
			for key in payload:
				lines.append("    %s: %s" % [str(key), str(payload[key])])
		if ev.has("snapshot"):
			lines.append("    [snapshot] %s" % str(ev["snapshot"]))
		lines.append("")

	var log_entries: Array = []
	if _adventure_log != null and _adventure_log.has_method("get_entries"):
		log_entries = _adventure_log.get_entries()

	if not log_entries.is_empty():
		lines.append("=== ADVENTURE LOG (%d entries) ===" % log_entries.size())
		for i in log_entries.size():
			var entry = log_entries[i]
			if entry is Dictionary:
				var text: String = str(entry.get("text", ""))
				var tag: String = str(entry.get("tag", ""))
				var cat: String = str(entry.get("category", ""))
				var src: String = str(entry.get("source", ""))
				var aid: int = int(entry.get("action_id", -1))
				var meta := "[%s/%s src=%s #%d]" % [tag, cat, src, aid]
				lines.append("[%d] %s %s" % [i, meta, text])
			else:
				lines.append("[%d] %s" % [i, str(entry)])
		lines.append("")

	return "\n".join(lines)


func export_text_to_file() -> String:
	var path := "user://session_trace_%s.txt" % run_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SessionTrace: cannot write %s" % path)
		return ""
	f.store_string(export_text())
	f.close()
	return path


# ------------------------------------------------------------------
# Convenience: export both files, return paths
# ------------------------------------------------------------------

func export_all() -> Dictionary:
	var json_path := export_json_to_file()
	var txt_path := export_text_to_file()
	return {"json": json_path, "txt": txt_path}


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

static func _generate_run_id() -> String:
	var dt := Time.get_datetime_dict_from_system(true)
	var ts := "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"],
	]
	var rand_suffix := randi() % 10000
	return "%s_%04d" % [ts, rand_suffix]


static func _compute_content_version() -> String:
	var hash_val: int = 0
	for path in ["res://data/rooms_v2.json", "res://data/items.json", "res://data/enemy_types.json"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			hash_val = hash_val ^ f.get_as_text().hash()
			f.close()
	return "%x" % hash_val if hash_val != 0 else "unknown"


static func _compute_settings_fingerprint() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var sm = tree.root.get_node_or_null("SettingsManager")
		if sm != null and sm.has_method("settings_fingerprint"):
			return sm.settings_fingerprint()
	return "unknown"
