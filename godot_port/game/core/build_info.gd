class_name BuildInfo
extends RefCounted
## Reads build metadata from res://build_info.json (written by CI).
## Falls back to "dev" when running from the editor or a local build.

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open("res://build_info.json", FileAccess.READ)
	if f == null:
		_cache = {"git_sha": "dev", "build_time_utc": "", "ref": ""}
		return _cache
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		_cache = json.data
	else:
		_cache = {"git_sha": "dev", "build_time_utc": "", "ref": ""}
	f.close()
	return _cache


static func git_sha() -> String:
	var sha := str(_load().get("git_sha", "dev"))
	if sha.is_empty():
		return "dev"
	return sha


static func build_time_utc() -> String:
	return str(_load().get("build_time_utc", ""))


static func ref_name() -> String:
	return str(_load().get("ref", ""))


static func version_label() -> String:
	var sha := git_sha()
	if sha == "dev":
		return "dev"
	var short := sha.substr(0, 7) if sha.length() > 7 else sha
	var btime := build_time_utc()
	if not btime.is_empty() and btime.length() >= 10:
		return "%s (%s)" % [short, btime.substr(0, 10)]
	return short
