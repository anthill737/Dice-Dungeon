class_name AssetResolver
extends RefCounted
## Resolves enemy sprite and item icon paths using the exact same rules
## as the Python implementation (see docs/python_asset_loading_rules.md).
##
## Enemy sprites: assets/sprites/enemies/<folder>/rotations/south.png
## Item icons:    assets/icons/items/<slug>.png
##
## The resolver loads images at runtime from the filesystem (no Godot import
## required) and caches them as ImageTexture.

## Cache: enemy_name -> ImageTexture (or null if tried and missing)
var _enemy_cache: Dictionary = {}

## Cache: (slug, size) -> ImageTexture
var _item_cache: Dictionary = {}

## Base path to the assets directory (repo root level).
var _assets_dir: String = ""

## Placeholder textures
var _unknown_item_tex: Variant = null  # ImageTexture or null
var _unknown_loaded: bool = false


func _init() -> void:
	_assets_dir = _find_assets_dir()


# ------------------------------------------------------------------
# Assets directory resolution
# ------------------------------------------------------------------

static func _find_assets_dir() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var parent := project_dir.get_base_dir()
	var candidate := parent.path_join("assets")
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	if DirAccess.dir_exists_absolute(project_dir.path_join("assets")):
		return project_dir.path_join("assets")
	return ""


# ------------------------------------------------------------------
# Item icon slugify — exact Python parity (explorer/item_icons.py)
# ------------------------------------------------------------------

## Convert an item name to a filesystem-safe slug.
## Matches Python: lowercase, strip smart quotes, replace non-alnum with _.
static func slugify(item_name: String) -> String:
	var s := item_name.to_lower().strip_edges()
	# Remove typographic apostrophes and single-quotes
	s = s.replace("'", "").replace("\u2018", "").replace("\u2019", "")
	# Replace all non-alphanumeric sequences with _
	var result := ""
	var in_gap := false
	for i in s.length():
		var c := s[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			if in_gap and not result.is_empty():
				result += "_"
			result += c
			in_gap = false
		else:
			in_gap = true
	return result


# ------------------------------------------------------------------
# Enemy name ↔ folder conversion — exact Python parity
# ------------------------------------------------------------------

## Convert an enemy folder name to display name (Python load_enemy_sprites).
static func folder_to_enemy_name(folder_name: String) -> String:
	var parts := folder_name.split("_")
	var words: PackedStringArray = []
	for part in parts:
		if part.is_empty():
			continue
		words.append(part[0].to_upper() + part.substr(1))
	var name := " ".join(words)
	# Python: re.sub(r'\bCharmers\b', "Charmer's", name)
	name = name.replace("Charmers", "Charmer's")
	# Python: re.sub(r'\bOf\b', 'of', name)
	name = name.replace(" Of ", " of ")
	if name.begins_with("Of "):
		name = "of " + name.substr(3)
	return name


## Convert an enemy display name to the folder slug used on disk.
static func enemy_name_to_folder(enemy_name: String) -> String:
	return slugify(enemy_name)


# ------------------------------------------------------------------
# Enemy sprite resolution
# ------------------------------------------------------------------

## Get an ImageTexture for the given enemy name, or null if not available.
## Results are cached.
func get_enemy_sprite(enemy_name: String) -> Variant:
	if _enemy_cache.has(enemy_name):
		return _enemy_cache[enemy_name]

	var tex = _load_enemy_sprite(enemy_name)
	_enemy_cache[enemy_name] = tex
	return tex


func _load_enemy_sprite(enemy_name: String) -> Variant:
	if _assets_dir.is_empty():
		return null

	var folder := enemy_name_to_folder(enemy_name)
	var sprites_base := _assets_dir.path_join("sprites/enemies").path_join(folder)

	if not DirAccess.dir_exists_absolute(sprites_base):
		return null

	var rotations_dir := sprites_base.path_join("rotations")
	# Python priority: south, west, east, north
	for direction in ["south", "west", "east", "north"]:
		var path := rotations_dir.path_join(direction + ".png")
		var tex: Variant = _load_image_texture(path)
		if tex != null:
			return tex

	return null


# ------------------------------------------------------------------
# Item icon resolution
# ------------------------------------------------------------------

## Get an ImageTexture for the given item name, or null if not available.
## Results are cached per (slug, size) pair.
func get_item_icon(item_name: String, icon_size: int = 0) -> Variant:
	var slug := slugify(item_name)
	var key := slug + ":" + str(icon_size)
	if _item_cache.has(key):
		return _item_cache[key]

	var tex = _load_item_icon(slug, icon_size)
	_item_cache[key] = tex
	return tex


## Get the resolved filesystem path for an item icon (for testing).
func get_item_icon_path(item_name: String) -> String:
	if _assets_dir.is_empty():
		return ""
	var slug := slugify(item_name)
	var specific := _assets_dir.path_join("icons/items").path_join(slug + ".png")
	if FileAccess.file_exists(specific):
		return specific
	var fallback := _assets_dir.path_join("icons/items/unknown.png")
	return fallback


## Get the resolved filesystem path for an enemy sprite (for testing).
func get_enemy_sprite_path(enemy_name: String) -> String:
	if _assets_dir.is_empty():
		return ""
	var folder := enemy_name_to_folder(enemy_name)
	var rotations_dir := _assets_dir.path_join("sprites/enemies").path_join(folder).path_join("rotations")
	for direction in ["south", "west", "east", "north"]:
		var path := rotations_dir.path_join(direction + ".png")
		if FileAccess.file_exists(path):
			return path
	return ""


func _load_item_icon(slug: String, icon_size: int) -> Variant:
	if _assets_dir.is_empty():
		return null

	var icons_dir := _assets_dir.path_join("icons/items")
	var specific := icons_dir.path_join(slug + ".png")

	if FileAccess.file_exists(specific):
		return _load_image_texture(specific, icon_size)

	# Fallback to unknown.png (Python parity)
	if not _unknown_loaded:
		_unknown_loaded = true
		var fallback_path := icons_dir.path_join("unknown.png")
		_unknown_item_tex = _load_image_texture(fallback_path)

	if _unknown_item_tex != null and icon_size > 0:
		return _load_image_texture(icons_dir.path_join("unknown.png"), icon_size)
	return _unknown_item_tex


# ------------------------------------------------------------------
# Image loading helper
# ------------------------------------------------------------------

static func _load_image_texture(path: String, resize_to: int = 0) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		return null
	if resize_to > 0 and (img.get_width() != resize_to or img.get_height() != resize_to):
		img.resize(resize_to, resize_to, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------
# Cache management
# ------------------------------------------------------------------

func clear_cache() -> void:
	_enemy_cache.clear()
	_item_cache.clear()
	_unknown_item_tex = null
	_unknown_loaded = false


func has_assets() -> bool:
	return not _assets_dir.is_empty()
