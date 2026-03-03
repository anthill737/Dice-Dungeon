class_name JsonLoader
extends RefCounted
## Low-level JSON file loader with validation.
##
## Data JSON files live inside the Godot project at res://data/ so they are
## included in exported builds.  The loader uses res:// paths, which work in
## both the editor and exports.

const _DATA_DIR := "res://data"


static func resolve_data_path(filename: String) -> String:
	return _DATA_DIR.path_join(filename)


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
