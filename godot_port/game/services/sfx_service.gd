class_name SfxService
extends Node

const MANIFEST_PATH := "res://assets/audio/sfx_manifest.json"
const AUDIO_DIR := "res://assets/audio/sfx"

const CUE_OVERRIDES := {
	"button_click": {"volume_db": -8.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"menu_open": {"volume_db": -7.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"menu_close": {"volume_db": -8.0, "pitch_min": 0.97, "pitch_max": 1.01},
	"dice_roll": {"volume_db": -5.0, "pitch_min": 0.97, "pitch_max": 1.04},
	"dice_lock": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.05},
	"attack": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"crit": {"volume_db": -4.0, "pitch_min": 0.99, "pitch_max": 1.03},
	"legendary_hit": {"volume_db": -3.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"enemy_hit": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"enemy_die": {"volume_db": -4.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"shield_block": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"armor_break": {"volume_db": -4.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"enemy_dice_roll": {"volume_db": -7.0, "pitch_min": 0.97, "pitch_max": 1.03},
	"move_room": {"volume_db": -9.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"discover_room": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"stairs_down": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"chest_open": {"volume_db": -4.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"barrel_open": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"lockbox_open": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"item_pickup": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.04},
	"gold_pickup": {
		"variants": ["gold_pickup", "purchase", "sell"],
		"volume_db": -6.0,
		"pitch_min": 0.97,
		"pitch_max": 1.05,
	},
	"purchase": {
		"variants": ["purchase", "gold_pickup", "sell"],
		"volume_db": -5.0,
		"pitch_min": 0.98,
		"pitch_max": 1.04,
	},
	"sell": {
		"variants": ["sell", "gold_pickup", "purchase"],
		"volume_db": -6.0,
		"pitch_min": 0.97,
		"pitch_max": 1.03,
	},
	"inventory_full": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"shop_enter": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"drink_potion": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.03},
	"heal": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.03},
	"shield_gain": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"puzzle_success": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"puzzle_fail": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"elite_unlock": {"volume_db": -4.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"boss_spawn": {"volume_db": -3.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"boss_defeat": {"volume_db": -3.0, "pitch_min": 0.99, "pitch_max": 1.01},
}

var _rng := RandomNumberGenerator.new()
var _cue_defs: Dictionary = {}
var _stream_cache: Dictionary = {}
var _last_variant_index: Dictionary = {}


func _init() -> void:
	_rng.randomize()


func _enter_tree() -> void:
	add_to_group("sfx_service")


static func ensure_for(node: Node) -> void:
	if node == null:
		return
	var tree := node.get_tree()
	if tree != null and tree.get_first_node_in_group("sfx_service") != null:
		return
	var service := SfxService.new()
	service.name = "SfxService"
	node.add_child(service)


static func play_for(node: Node, cue_id: String, overrides: Dictionary = {}) -> void:
	if node == null:
		return
	var tree := node.get_tree()
	if tree == null:
		return
	var service = tree.get_first_node_in_group("sfx_service")
	if service is SfxService:
		service.play(cue_id, overrides)


static func container_cue_for(container_name: String) -> String:
	var lowered := container_name.to_lower()
	if lowered.contains("barrel"):
		return "barrel_open"
	if lowered.contains("lockbox") or lowered.contains("strongbox"):
		return "lockbox_open"
	return "chest_open"


static func play_container_for(node: Node, container_name: String) -> void:
	play_for(node, container_cue_for(container_name))


func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func has_cue(cue_id: String) -> bool:
	_ensure_cues_loaded()
	return _cue_defs.has(cue_id)


func get_variant_paths(cue_id: String) -> PackedStringArray:
	_ensure_cues_loaded()
	var cue: Dictionary = _cue_defs.get(cue_id, {})
	var paths: Array = cue.get("paths", [])
	return PackedStringArray(paths)


func pick_variant_path(cue_id: String) -> String:
	_ensure_cues_loaded()
	var cue: Dictionary = _cue_defs.get(cue_id, {})
	var paths: Array = cue.get("paths", [])
	if paths.is_empty():
		return ""
	if paths.size() == 1:
		_last_variant_index[cue_id] = 0
		return str(paths[0])

	var last_index: int = int(_last_variant_index.get(cue_id, -1))
	var next_index := _rng.randi_range(0, paths.size() - 1)
	if next_index == last_index:
		next_index = (last_index + 1 + _rng.randi_range(0, paths.size() - 2)) % paths.size()
	_last_variant_index[cue_id] = next_index
	return str(paths[next_index])


func play(cue_id: String, overrides: Dictionary = {}) -> void:
	var path := pick_variant_path(cue_id)
	if path.is_empty():
		return

	var stream = _stream_cache.get(path)
	if stream == null:
		stream = load(path)
		if stream == null:
			push_warning("SfxService: failed to load " + path)
			return
		_stream_cache[path] = stream

	var cue: Dictionary = _cue_defs.get(cue_id, {})
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	player.volume_db = float(overrides.get("volume_db", cue.get("volume_db", 0.0)))
	var pitch_min: float = float(overrides.get("pitch_min", cue.get("pitch_min", 1.0)))
	var pitch_max: float = float(overrides.get("pitch_max", cue.get("pitch_max", 1.0)))
	if pitch_max < pitch_min:
		var swap := pitch_min
		pitch_min = pitch_max
		pitch_max = swap
	player.pitch_scale = _rng.randf_range(pitch_min, pitch_max)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _ensure_cues_loaded() -> void:
	if not _cue_defs.is_empty():
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("SfxService: missing manifest at " + MANIFEST_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("SfxService: invalid manifest JSON")
		return

	var sounds: Array = parsed.get("sounds", [])
	for raw_sound in sounds:
		if not (raw_sound is Dictionary):
			continue
		var cue_id := str(raw_sound.get("id", "")).strip_edges()
		var file_stem := str(raw_sound.get("file_stem", "")).strip_edges()
		if cue_id.is_empty() or file_stem.is_empty():
			continue
		var stream_path := _resolve_stream_path(file_stem)
		_cue_defs[cue_id] = {
			"paths": [stream_path],
			"volume_db": 0.0,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
		}

	for cue_id in CUE_OVERRIDES.keys():
		var override: Dictionary = CUE_OVERRIDES[cue_id]
		var cue: Dictionary = _cue_defs.get(cue_id, {
			"paths": [],
			"volume_db": 0.0,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
		})
		if override.has("variants"):
			var variant_paths: Array = []
			for variant_id in override["variants"]:
				if _cue_defs.has(variant_id):
					for path in _cue_defs[variant_id].get("paths", []):
						if path not in variant_paths:
							variant_paths.append(path)
			if not variant_paths.is_empty():
				cue["paths"] = variant_paths
		for key in ["volume_db", "pitch_min", "pitch_max"]:
			if override.has(key):
				cue[key] = override[key]
		_cue_defs[cue_id] = cue


func _resolve_stream_path(file_stem: String) -> String:
	var wav_path := "%s/%s.wav" % [AUDIO_DIR, file_stem]
	if FileAccess.file_exists(wav_path):
		return wav_path
	var mp3_path := "%s/%s.mp3" % [AUDIO_DIR, file_stem]
	if FileAccess.file_exists(mp3_path):
		return mp3_path
	return wav_path
