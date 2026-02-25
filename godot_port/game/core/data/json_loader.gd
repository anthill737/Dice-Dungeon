class_name JsonLoader
extends RefCounted
## Low-level JSON file loader with validation.
##
## Resolves paths relative to the repository root so the Godot port reads
## the canonical JSON data from dice_dungeon_content/data/ without duplication.

const _DATA_REL_DIR := "dice_dungeon_content/data"


static func _repo_root() -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	# Strip trailing slash so get_base_dir() goes up one level
	project_dir = project_dir.rstrip("/")
	return project_dir.get_base_dir()


static func _data_dir() -> String:
	return _repo_root().path_join(_DATA_REL_DIR)


static func resolve_data_path(filename: String) -> String:
	return _data_dir().path_join(filename)


## Load a JSON file and return the parsed Variant.
## Returns null and pushes an error on failure.
static func load_json(filename: String) -> Variant:
	var path := resolve_data_path(filename)

	if not FileAccess.file_exists(path):
		push_error("JsonLoader: file not found: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JsonLoader: cannot open: %s (error %d)" % [path, FileAccess.get_open_error()])
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JsonLoader: parse error in %s line %d: %s" % [filename, json.get_error_line(), json.get_error_message()])
		return null

	return json.data


## Load JSON and assert it is an Array.
static func load_json_array(filename: String) -> Array:
	var data = load_json(filename)
	if data == null:
		return []
	if not data is Array:
		push_error("JsonLoader: expected Array in %s, got %s" % [filename, typeof(data)])
		return []
	return data as Array


## Load JSON and assert it is a Dictionary.
static func load_json_dict(filename: String) -> Dictionary:
	var data = load_json(filename)
	if data == null:
		return {}
	if not data is Dictionary:
		push_error("JsonLoader: expected Dictionary in %s, got %s" % [filename, typeof(data)])
		return {}
	return data as Dictionary
