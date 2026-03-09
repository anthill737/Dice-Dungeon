class_name SfxService
extends Node

const MANIFEST_PATH := "res://assets/audio/sfx_manifest.json"
const AUDIO_DIR := "res://assets/audio/sfx"

const CUE_OVERRIDES := {
	"button_click": {"volume_db": -8.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"menu_open": {"volume_db": -7.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"menu_close": {"volume_db": -8.0, "pitch_min": 0.97, "pitch_max": 1.01},
	"dice_roll": {"volume_db": -5.0, "pitch_min": 0.97, "pitch_max": 1.03},
	"dice_lock": {"volume_db": -6.0, "pitch_min": 0.98, "pitch_max": 1.04},
	"attack": {"volume_db": -5.0, "pitch_min": 0.97, "pitch_max": 1.02},
	"crit": {"volume_db": -4.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"legendary_hit": {"volume_db": -3.0, "pitch_min": 0.97, "pitch_max": 1.01},
	"shield_block": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"armor_break": {"volume_db": -4.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"move_room": {"volume_db": -9.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"discover_room": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"stairs_down": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"chest_open": {"volume_db": -4.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"barrel_open": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03},
	"lockbox_open": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"item_pickup": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.04},
	"gold_pickup": {"volume_db": -6.0, "pitch_min": 0.97, "pitch_max": 1.05},
	"purchase": {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.04},
	"sell": {"volume_db": -6.0, "pitch_min": 0.97, "pitch_max": 1.03},
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
	"flee_success": {"volume_db": -6.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"flee_fail": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"door_locked_rattle": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"rest_recover": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"read_lore": {"volume_db": -8.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"equip_weapon": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"equip_armor": {"volume_db": -5.0, "pitch_min": 0.99, "pitch_max": 1.01},
	"equip_accessory": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"unequip_item": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"drop_item": {"volume_db": -8.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"use_token": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"use_tool": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"repair_kit": {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"buff_tonic": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.02},
	"cleanse_tonic": {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.02},
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
	var service := _get_service(node)
	if service != null:
		service.play(cue_id, overrides)


static func play_enemy_event_for(
	node: Node,
	enemy_name: String,
	event_name: String,
	overrides: Dictionary = {}
) -> void:
	var service := _get_service(node)
	if service != null:
		service.play_enemy_event(enemy_name, event_name, overrides)


static func play_item_use_for(
	node: Node,
	item_name: String,
	effect_type: String,
	overrides: Dictionary = {}
) -> void:
	var service := _get_service(node)
	if service != null:
		service.play_item_use(item_name, effect_type, overrides)


static func play_equipment_action_for(
	node: Node,
	slot: String,
	action_name: String,
	overrides: Dictionary = {}
) -> void:
	var cue_id := equipment_action_cue_for(slot, action_name)
	play_for(node, cue_id, overrides)


static func play_container_for(node: Node, container_name: String) -> void:
	play_for(node, container_cue_for(container_name))


static func container_cue_for(container_name: String) -> String:
	var lowered := container_name.to_lower()
	if lowered.contains("barrel"):
		return "barrel_open"
	if lowered.contains("lockbox") or lowered.contains("strongbox"):
		return "lockbox_open"
	return "chest_open"


static func equipment_action_cue_for(slot: String, action_name: String = "equip") -> String:
	if action_name == "unequip":
		return "unequip_item"
	match slot.strip_edges().to_lower():
		"weapon":
			return "equip_weapon"
		"armor":
			return "equip_armor"
		"accessory":
			return "equip_accessory"
	return "item_pickup"


static func item_use_cue_for(item_name: String, effect_type: String) -> String:
	var lowered_name := item_name.to_lower()
	var lowered_type := effect_type.to_lower()

	if lowered_type in ["heal", "consumable_heal"]:
		if _contains_any(lowered_name, ["bandage", "salve", "poultice", "cloth"]):
			return "heal_bandage"
		if _contains_any(lowered_name, ["herb", "leaf", "reed", "bundle", "mushroom", "incense"]):
			return "heal_herb"
		if _contains_any(lowered_name, ["bread", "ration", "meat", "honey", "ale", "waterskin", "jar"]):
			return "heal_food"
		return "drink_potion"

	if lowered_type == "shield":
		return "shield_gain"
	if lowered_type in ["buff", "consumable_light", "blessing"]:
		return "buff_tonic"
	if lowered_type == "cleanse":
		return "cleanse_tonic"
	if lowered_type in ["escape_token", "disarm_token", "token"]:
		return "use_token"
	if lowered_type == "repair":
		return "repair_kit"
	if lowered_type in ["tool_disarm", "tool", "upgrade"]:
		return "use_tool"
	return "item_pickup"


static func enemy_family_for(enemy_name: String) -> String:
	var lowered := enemy_name.to_lower()
	if _contains_any(lowered, ["slime", "ooze", "blob", "gelatinous"]):
		return "ooze"
	if _contains_any(lowered, ["skeleton", "zombie", "lich", "ghost", "wraith", "specter", "phantom", "shade", "corpse"]):
		return "undead"
	if _contains_any(lowered, ["spider", "bee", "beetle", "grub", "leech", "worm"]):
		return "insect"
	if _contains_any(lowered, ["wolf", "bear", "boar", "serpent", "rat", "bat", "hydra", "hound", "beast", "salamander"]):
		return "beast"
	if _contains_any(lowered, ["wisp", "spirit", "elemental", "angel", "demon", "imp", "sprite", "phoenix"]):
		return "spirit"
	if _contains_any(lowered, ["goblin", "orc", "bandit", "knight", "guard", "warrior", "jailer", "butcher", "cultist"]):
		return "humanoid"
	return ""


func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func has_cue(cue_id: String) -> bool:
	_ensure_cues_loaded()
	if not _cue_defs.has(cue_id):
		return false
	return not Array(_cue_defs[cue_id].get("paths", [])).is_empty()


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


func play_first_available(cue_ids: Array, overrides: Dictionary = {}) -> void:
	for raw_cue_id in cue_ids:
		var cue_id := str(raw_cue_id).strip_edges()
		if cue_id.is_empty() or not has_cue(cue_id):
			continue
		play(cue_id, overrides)
		return


func play_enemy_event(enemy_name: String, event_name: String, overrides: Dictionary = {}) -> void:
	var candidates: Array = []
	var family := enemy_family_for(enemy_name)
	if not family.is_empty():
		candidates.append("enemy_%s_%s" % [event_name, family])
	candidates.append("enemy_%s" % event_name)
	play_first_available(candidates, overrides)


func play_item_use(item_name: String, effect_type: String, overrides: Dictionary = {}) -> void:
	play_first_available([item_use_cue_for(item_name, effect_type), "item_pickup"], overrides)


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
	var sound_paths_by_id: Dictionary = {}
	for raw_sound in sounds:
		if not (raw_sound is Dictionary):
			continue
		var cue_id := str(raw_sound.get("id", "")).strip_edges()
		var file_stem := str(raw_sound.get("file_stem", "")).strip_edges()
		if cue_id.is_empty() or file_stem.is_empty():
			continue
		var stream_path := _resolve_stream_path(file_stem)
		sound_paths_by_id[cue_id] = stream_path
		_cue_defs[cue_id] = {
			"paths": [stream_path],
			"volume_db": 0.0,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
		}

	var cue_groups = parsed.get("cue_groups", {})
	if cue_groups is Dictionary:
		for raw_group_id in cue_groups.keys():
			var group_id := str(raw_group_id).strip_edges()
			if group_id.is_empty():
				continue
			var members = cue_groups[raw_group_id]
			if not (members is Array):
				continue
			var variant_paths: Array = []
			for raw_member in members:
				var member_id := str(raw_member).strip_edges()
				if member_id.is_empty():
					continue
				if sound_paths_by_id.has(member_id):
					var member_path = sound_paths_by_id[member_id]
					if member_path not in variant_paths:
						variant_paths.append(member_path)
				elif _cue_defs.has(member_id):
					for path in _cue_defs[member_id].get("paths", []):
						if path not in variant_paths:
							variant_paths.append(path)
			if variant_paths.is_empty():
				continue
			var cue: Dictionary = _cue_defs.get(group_id, {
				"paths": [],
				"volume_db": 0.0,
				"pitch_min": 1.0,
				"pitch_max": 1.0,
			})
			cue["paths"] = variant_paths
			_cue_defs[group_id] = cue

	for cue_id_variant in _cue_defs.keys():
		var cue_id := str(cue_id_variant)
		var cue: Dictionary = _cue_defs[cue_id]
		cue = _merge_profile(cue, _default_profile_for_cue(cue_id))
		cue = _merge_profile(cue, CUE_OVERRIDES.get(cue_id, {}))
		_cue_defs[cue_id] = cue


func _merge_profile(cue: Dictionary, profile: Dictionary) -> Dictionary:
	if profile.is_empty():
		return cue
	for key in ["volume_db", "pitch_min", "pitch_max"]:
		if profile.has(key):
			cue[key] = profile[key]
	return cue


func _default_profile_for_cue(cue_id: String) -> Dictionary:
	if cue_id.begins_with("enemy_hit"):
		return {"volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.03}
	if cue_id.begins_with("enemy_die"):
		return {"volume_db": -4.0, "pitch_min": 0.98, "pitch_max": 1.02}
	if cue_id.begins_with("enemy_dice_roll"):
		return {"volume_db": -7.0, "pitch_min": 0.97, "pitch_max": 1.03}
	if cue_id.begins_with("gold_pickup") or cue_id.begins_with("purchase") or cue_id.begins_with("sell"):
		return {"volume_db": -6.0, "pitch_min": 0.97, "pitch_max": 1.05}
	if cue_id.begins_with("drink_potion"):
		return {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.03}
	if cue_id.begins_with("heal_") or cue_id == "heal":
		return {"volume_db": -6.0, "pitch_min": 0.99, "pitch_max": 1.03}
	if cue_id.begins_with("item_pickup"):
		return {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.04}
	if cue_id in ["buff_tonic", "cleanse_tonic", "use_token", "use_tool", "repair_kit"]:
		return {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02}
	if cue_id.begins_with("equip_") or cue_id in ["unequip_item", "drop_item", "read_lore"]:
		return {"volume_db": -7.0, "pitch_min": 0.99, "pitch_max": 1.02}
	return {}


func _resolve_stream_path(file_stem: String) -> String:
	var wav_path := "%s/%s.wav" % [AUDIO_DIR, file_stem]
	if FileAccess.file_exists(wav_path):
		return wav_path
	var mp3_path := "%s/%s.mp3" % [AUDIO_DIR, file_stem]
	if FileAccess.file_exists(mp3_path):
		return mp3_path
	return wav_path


static func _get_service(node: Node) -> SfxService:
	if node == null:
		return null
	var tree := node.get_tree()
	if tree == null:
		return null
	var service = tree.get_first_node_in_group("sfx_service")
	if service is SfxService:
		return service
	return null


static func _contains_any(haystack: String, needles: Array) -> bool:
	for raw_needle in needles:
		var needle := str(raw_needle)
		if not needle.is_empty() and haystack.contains(needle):
			return true
	return false
