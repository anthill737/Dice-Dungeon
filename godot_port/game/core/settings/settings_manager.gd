extends Node
## Autoload singleton managing persistent settings.
##
## Stores difficulty, color scheme, text speed, and keybindings
## in user://settings.cfg via Godot ConfigFile.
## Exposes difficulty multipliers matching the Python implementation.

signal settings_changed()

const CONFIG_PATH := "user://settings.cfg"

# Difficulty names matching Python (Brutal displayed as Nightmare)
const DIFFICULTY_OPTIONS := ["Easy", "Normal", "Hard", "Nightmare"]

const COLOR_SCHEME_OPTIONS := ["Classic", "Dark", "Light"]

const TEXT_SPEED_OPTIONS := ["Slow", "Medium", "Fast", "Instant"]
const TEXT_SPEED_DELAYS := {"Slow": 15, "Medium": 13, "Fast": 7, "Instant": 0}

const BINDABLE_ACTIONS := [
	"move_north", "move_south", "move_east", "move_west",
	"open_inventory", "open_menu", "rest", "character_status", "ui_cancel",
]

const ACTION_DISPLAY_NAMES := {
	"move_north": "Move North",
	"move_south": "Move South",
	"move_east": "Move East",
	"move_west": "Move West",
	"open_inventory": "Inventory",
	"open_menu": "Menu / Save-Load",
	"rest": "Rest",
	"character_status": "Character Status",
	"ui_cancel": "Escape / Close",
}

const DEFAULT_KEYBINDINGS := {
	"move_north": KEY_W,
	"move_south": KEY_S,
	"move_east": KEY_D,
	"move_west": KEY_A,
	"open_inventory": KEY_I,
	"open_menu": KEY_ESCAPE,
	"rest": KEY_R,
	"character_status": KEY_G,
	"ui_cancel": KEY_Q,
}

## Matches Python dice_dungeon_explorer.py difficulty_multipliers.
## Python uses "Brutal" — we display "Nightmare" but keep identical values.
const DIFFICULTY_MULTIPLIERS := {
	"Easy": {
		"player_damage_mult": 1.5,
		"player_damage_taken_mult": 0.7,
		"enemy_health_mult": 0.7,
		"enemy_damage_mult": 1.0,
		"loot_chance_mult": 1.3,
		"heal_mult": 1.2,
	},
	"Normal": {
		"player_damage_mult": 1.0,
		"player_damage_taken_mult": 1.0,
		"enemy_health_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"loot_chance_mult": 1.0,
		"heal_mult": 1.0,
	},
	"Hard": {
		"player_damage_mult": 0.8,
		"player_damage_taken_mult": 1.3,
		"enemy_health_mult": 1.3,
		"enemy_damage_mult": 1.3,
		"loot_chance_mult": 0.8,
		"heal_mult": 0.8,
	},
	"Nightmare": {
		"player_damage_mult": 0.6,
		"player_damage_taken_mult": 1.6,
		"enemy_health_mult": 1.8,
		"enemy_damage_mult": 1.6,
		"loot_chance_mult": 0.6,
		"heal_mult": 0.6,
	},
}

var difficulty: String = "Normal"
var color_scheme: String = "Classic"
var text_speed: String = "Medium"
var keybindings: Dictionary = {}  # action_name -> Key enum int


func _ready() -> void:
	_init_default_keybindings()
	load_settings()
	_apply_keybindings()


func _init_default_keybindings() -> void:
	keybindings = DEFAULT_KEYBINDINGS.duplicate()


func get_difficulty_multipliers() -> Dictionary:
	return DIFFICULTY_MULTIPLIERS.get(difficulty, DIFFICULTY_MULTIPLIERS["Normal"]).duplicate()


func get_text_speed_delay() -> int:
	return TEXT_SPEED_DELAYS.get(text_speed, 13)


# ------------------------------------------------------------------
# Persistence
# ------------------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "difficulty", difficulty)
	cfg.set_value("general", "color_scheme", color_scheme)
	cfg.set_value("general", "text_speed", text_speed)
	for action in keybindings:
		cfg.set_value("keybindings", action, keybindings[action])
	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	difficulty = cfg.get_value("general", "difficulty", "Normal")
	color_scheme = cfg.get_value("general", "color_scheme", "Classic")
	text_speed = cfg.get_value("general", "text_speed", "Medium")
	if cfg.has_section("keybindings"):
		for action in cfg.get_section_keys("keybindings"):
			keybindings[action] = int(cfg.get_value("keybindings", action, 0))


func reset_keybindings_to_defaults() -> void:
	_init_default_keybindings()
	_apply_keybindings()
	save_settings()
	settings_changed.emit()


func set_keybinding(action: String, keycode: int) -> void:
	keybindings[action] = keycode
	_apply_single_keybinding(action, keycode)
	save_settings()
	settings_changed.emit()


func set_difficulty(value: String) -> void:
	difficulty = value
	save_settings()
	settings_changed.emit()


func set_color_scheme(value: String) -> void:
	color_scheme = value
	save_settings()
	settings_changed.emit()


func set_text_speed(value: String) -> void:
	text_speed = value
	save_settings()
	settings_changed.emit()


# ------------------------------------------------------------------
# InputMap management
# ------------------------------------------------------------------

func _apply_keybindings() -> void:
	for action in keybindings:
		_apply_single_keybinding(action, keybindings[action])


func _apply_single_keybinding(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	InputMap.action_add_event(action, ev)


## Utility: return the Key enum int currently bound to an action.
func get_key_for_action(action: String) -> int:
	return keybindings.get(action, 0)


## Utility: human-readable key name.
static func key_name(keycode: int) -> String:
	if keycode == 0:
		return "None"
	return OS.get_keycode_string(keycode as Key)
