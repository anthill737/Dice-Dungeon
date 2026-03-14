extends Node
## Persistent music manager for the Godot port.
##
## Features:
## - Crossfades between contexts across scene changes
## - Separate Music audio bus and persisted music settings
## - Per-room override lookup via room data, room id/name, tags, and difficulty
## - Safe no-op behavior when no tracks are assigned yet

const MANIFEST_PATH := "res://assets/audio/music_manifest.json"
const MUSIC_BUS_NAME := "Music"
const DEFAULT_FADE_SEC := 0.75
const SILENT_DB := -60.0

var _rng := RandomNumberGenerator.new()
var _context_defs: Dictionary = {}
var _cue_defs: Dictionary = {}
var _stream_cache: Dictionary = {}
var _last_variant_index: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _active_player_index: int = 0
var _active_cue_id: String = ""
var _active_context_key: String = ""
var _active_track_path: String = ""
var _transition_tween: Tween

var _active_playlist: Dictionary = {}
var _playlist_queue: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_music_bus()
	_create_players()
	reload_manifest()
	_connect_settings()
	_apply_settings()


func reload_manifest() -> void:
	_context_defs.clear()
	_cue_defs.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("MusicService: manifest missing at %s" % MANIFEST_PATH)
		return

	var raw_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_warning("MusicService: invalid manifest JSON at %s" % MANIFEST_PATH)
		return

	_context_defs = Dictionary(parsed.get("contexts", {}))
	_cue_defs = Dictionary(parsed.get("cues", {}))


func has_context(context_key: String) -> bool:
	return _context_defs.has(context_key)


func has_cue(cue_id: String) -> bool:
	var cue: Dictionary = _cue_defs.get(cue_id, {})
	return not Array(cue.get("paths", [])).is_empty()


func is_playlist_cue(cue_id: String) -> bool:
	var cue: Dictionary = _cue_defs.get(cue_id, {})
	return bool(cue.get("playlist", false))


func get_context_cue(context_key: String) -> String:
	var context_def: Dictionary = _context_defs.get(context_key, {})
	return str(context_def.get("cue", "")).strip_edges()


func get_variant_paths(cue_id: String) -> PackedStringArray:
	var cue: Dictionary = _cue_defs.get(cue_id, {})
	return PackedStringArray(Array(cue.get("paths", [])))


func get_active_context() -> String:
	return _active_context_key


func get_active_cue() -> String:
	return _active_cue_id


func get_active_track_path() -> String:
	return _active_track_path


func is_playing() -> bool:
	if _players.is_empty():
		return false
	return _players[_active_player_index].playing


func set_rng_seed(seed: int) -> void:
	_rng.seed = seed


func set_context(context_key: String, options: Dictionary = {}) -> void:
	var resolved := _resolve_context_request(context_key, options, [])
	_play_resolved(resolved, bool(options.get("immediate", false)))


func set_room_context(room: Variant, phase: String = "exploration", fallback_context: String = "", options: Dictionary = {}) -> void:
	var resolved := _resolve_room_request(room, phase, fallback_context, options)
	_play_resolved(resolved, bool(options.get("immediate", false)))


func set_overlay_context(
	context_key: String,
	room: Variant,
	phase: String = "exploration",
	fallback_context: String = "",
	options: Dictionary = {}
) -> void:
	var overlay_options := options.duplicate()
	if not fallback_context.strip_edges().is_empty():
		# Explorer overlays should preserve the active room/combat music unless they
		# have their own explicit cue. This lets menu overlays still fall back to the
		# menu theme while in-game overlays keep the adventure playlist intact.
		overlay_options["fallback_context"] = fallback_context
	var resolved := _resolve_context_request(context_key, overlay_options, [])
	if resolved.is_empty():
		set_room_context(room, phase, fallback_context, options)
		return
	_play_resolved(resolved, bool(overlay_options.get("immediate", false)))


func stop_music(fade_sec: float = DEFAULT_FADE_SEC) -> void:
	_active_cue_id = ""
	_active_context_key = ""
	_active_track_path = ""
	_active_playlist = {}
	_playlist_queue.clear()

	if _players.is_empty():
		return

	var active_player := _players[_active_player_index]
	if not active_player.playing:
		return

	if _transition_tween != null and is_instance_valid(_transition_tween):
		_transition_tween.kill()

	if fade_sec <= 0.01 or not is_inside_tree():
		active_player.stop()
		active_player.stream = null
		active_player.volume_db = SILENT_DB
		return

	_transition_tween = create_tween()
	_transition_tween.tween_property(active_player, "volume_db", SILENT_DB, fade_sec)
	_transition_tween.tween_callback(func():
		if is_instance_valid(active_player):
			active_player.stop()
			active_player.stream = null
			active_player.volume_db = SILENT_DB
	)


func _resolve_room_request(room: Variant, phase: String, fallback_context: String, options: Dictionary) -> Dictionary:
	var candidates := room_music_candidates_for(room, phase)
	for candidate in candidates:
		var resolved := _resolve_named_candidate(candidate, options, [])
		if not resolved.is_empty():
			return resolved

	var default_context := resolve_room_context_key(room, phase, fallback_context)
	return _resolve_context_request(default_context, options, [])


func _resolve_named_candidate(name: String, options: Dictionary, seen: Array[String]) -> Dictionary:
	var candidate := name.strip_edges()
	if candidate.is_empty():
		return {}
	if _context_defs.has(candidate):
		return _resolve_context_request(candidate, options, seen)
	if has_cue(candidate):
		return _resolve_cue_request(candidate, options, candidate)
	return {}


func _resolve_context_request(context_key: String, options: Dictionary, seen: Array[String]) -> Dictionary:
	var key := context_key.strip_edges()
	if key.is_empty():
		return {}
	if seen.has(key):
		return {}

	var context_def: Dictionary = _context_defs.get(key, {})
	var cue_id := str(options.get("cue", context_def.get("cue", ""))).strip_edges()
	if not cue_id.is_empty():
		var cue_result := _resolve_cue_request(cue_id, options, key)
		if not cue_result.is_empty():
			cue_result["context_key"] = key
			return cue_result

	var next_seen := seen.duplicate()
	next_seen.append(key)
	var fallback_context := str(options.get("fallback_context", context_def.get("fallback_context", ""))).strip_edges()
	if not fallback_context.is_empty():
		return _resolve_context_request(fallback_context, options, next_seen)
	return {}


func _resolve_cue_request(cue_id: String, options: Dictionary, context_key: String) -> Dictionary:
	var cue: Dictionary = _cue_defs.get(cue_id, {})
	var paths: Array = cue.get("paths", [])
	if paths.is_empty():
		return {}

	var resolved := {
		"context_key": context_key,
		"cue_id": cue_id,
		"paths": PackedStringArray(paths),
		"loop": bool(options.get("loop", cue.get("loop", true))),
		"volume_db": float(options.get("volume_db", cue.get("volume_db", 0.0))),
		"fade_sec": float(options.get("fade_sec", cue.get("fade_sec", DEFAULT_FADE_SEC))),
		"playlist": bool(options.get("playlist", cue.get("playlist", false))),
		"shuffle": bool(options.get("shuffle", cue.get("shuffle", false))),
		"loop_playlist": bool(options.get("loop_playlist", cue.get("loop_playlist", true))),
	}

	if bool(resolved["playlist"]):
		return resolved

	var path := pick_variant_path(cue_id)
	if path.is_empty():
		return {}
	resolved["path"] = path
	return resolved


func pick_variant_path(cue_id: String) -> String:
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


func _play_resolved(resolved: Dictionary, immediate: bool) -> void:
	if resolved.is_empty():
		stop_music()
		return

	var cue_id := str(resolved.get("cue_id", "")).strip_edges()
	var active_player: AudioStreamPlayer = _players[_active_player_index] if not _players.is_empty() else null
	if cue_id == _active_cue_id and not cue_id.is_empty() and active_player != null and active_player.playing:
		_active_context_key = str(resolved.get("context_key", "")).strip_edges()
		return

	if bool(resolved.get("playlist", false)):
		_start_playlist(resolved, immediate)
		return

	var path := str(resolved.get("path", "")).strip_edges()
	if _transition_to_path(
		path,
		bool(resolved.get("loop", true)),
		float(resolved.get("volume_db", 0.0)),
		float(resolved.get("fade_sec", DEFAULT_FADE_SEC)),
		immediate
	):
		_active_playlist = {}
		_playlist_queue.clear()
		_active_cue_id = cue_id
		_active_context_key = str(resolved.get("context_key", "")).strip_edges()
		_active_track_path = path


func _start_playlist(resolved: Dictionary, immediate: bool) -> void:
	var paths: Array[String] = []
	for raw_path in PackedStringArray(resolved.get("paths", PackedStringArray())):
		var path := str(raw_path).strip_edges()
		if path.is_empty():
			continue
		paths.append(path)
	if paths.is_empty():
		stop_music()
		return

	_active_playlist = {
		"cue_id": str(resolved.get("cue_id", "")).strip_edges(),
		"context_key": str(resolved.get("context_key", "")).strip_edges(),
		"paths": paths.duplicate(),
		"shuffle": bool(resolved.get("shuffle", true)),
		"loop_playlist": bool(resolved.get("loop_playlist", true)),
		"volume_db": float(resolved.get("volume_db", 0.0)),
		"fade_sec": float(resolved.get("fade_sec", DEFAULT_FADE_SEC)),
	}
	_playlist_queue = _make_playlist_queue(paths, _active_track_path)
	_active_cue_id = str(_active_playlist.get("cue_id", ""))
	_active_context_key = str(_active_playlist.get("context_key", ""))
	_play_next_playlist_track(immediate)


func _play_next_playlist_track(immediate: bool) -> void:
	if _active_playlist.is_empty():
		return

	var paths: Array[String] = []
	for raw_path in _active_playlist.get("paths", []):
		paths.append(str(raw_path))
	if paths.is_empty():
		stop_music()
		return

	if _playlist_queue.is_empty():
		if not bool(_active_playlist.get("loop_playlist", true)):
			stop_music(0.0)
			return
		_playlist_queue = _make_playlist_queue(paths, _active_track_path)
		if _playlist_queue.is_empty():
			stop_music()
			return

	var next_path: String = _playlist_queue.pop_front()
	var played := _transition_to_path(
		next_path,
		false,
		float(_active_playlist.get("volume_db", 0.0)),
		float(_active_playlist.get("fade_sec", DEFAULT_FADE_SEC)),
		immediate
	)
	if played:
		_active_track_path = next_path


func _make_playlist_queue(paths: Array[String], avoid_first_path: String) -> Array[String]:
	var queue := paths.duplicate()
	if queue.is_empty():
		return queue

	if bool(_active_playlist.get("shuffle", true)):
		for i in range(queue.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var temp: String = queue[i]
			queue[i] = queue[j]
			queue[j] = temp

	if queue.size() > 1 and not avoid_first_path.is_empty() and queue[0] == avoid_first_path:
		for i in range(1, queue.size()):
			if queue[i] == avoid_first_path:
				continue
			var swap_value: String = queue[0]
			queue[0] = queue[i]
			queue[i] = swap_value
			break

	return queue


func _transition_to_path(
	path: String,
	loop_enabled: bool,
	target_volume_db: float,
	fade_sec: float,
	immediate: bool
) -> bool:
	var stream = _load_stream(path, loop_enabled)
	if stream == null:
		return false

	if _players.size() < 2:
		_create_players()
	if _players.size() < 2:
		return false

	if _transition_tween != null and is_instance_valid(_transition_tween):
		_transition_tween.kill()

	var incoming_index: int = (_active_player_index + 1) % 2
	var incoming: AudioStreamPlayer = _players[incoming_index]
	var outgoing: AudioStreamPlayer = _players[_active_player_index]

	incoming.stop()
	incoming.stream = stream
	incoming.bus = MUSIC_BUS_NAME
	incoming.volume_db = target_volume_db if immediate or not outgoing.playing else SILENT_DB
	incoming.play()

	if immediate or not outgoing.playing or fade_sec <= 0.01 or not is_inside_tree():
		outgoing.stop()
		outgoing.stream = null
		outgoing.volume_db = SILENT_DB
	else:
		_transition_tween = create_tween()
		_transition_tween.tween_property(incoming, "volume_db", target_volume_db, fade_sec)
		_transition_tween.parallel().tween_property(outgoing, "volume_db", SILENT_DB, fade_sec)
		_transition_tween.tween_callback(func():
			if is_instance_valid(outgoing):
				outgoing.stop()
				outgoing.stream = null
				outgoing.volume_db = SILENT_DB
		)

	_active_player_index = incoming_index
	return true


func _load_stream(path: String, loop_enabled: bool):
	if path.is_empty():
		return null

	var base_stream = _stream_cache.get(path)
	if base_stream == null:
		base_stream = load(path)
		if base_stream == null:
			push_warning("MusicService: failed to load %s" % path)
			return null
		_stream_cache[path] = base_stream

	var stream = base_stream.duplicate()
	_apply_loop_setting(stream, loop_enabled)
	return stream


func _apply_loop_setting(stream, loop_enabled: bool) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop_enabled
	elif stream is AudioStreamMP3:
		stream.loop = loop_enabled


func _ensure_music_bus() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_index != -1:
		return
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, MUSIC_BUS_NAME)


func _create_players() -> void:
	if not _players.is_empty():
		return
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS_NAME
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_players.append(player)


func _on_player_finished(player: AudioStreamPlayer) -> void:
	if _active_playlist.is_empty():
		return
	if _players.is_empty():
		return
	if player != _players[_active_player_index]:
		return
	_play_next_playlist_track(true)


func _connect_settings() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		return
	if not sm.settings_changed.is_connected(_apply_settings):
		sm.settings_changed.connect(_apply_settings)


func _apply_settings() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_index == -1:
		return

	var enabled := true
	var volume := 0.65
	var sm = get_node_or_null("/root/SettingsManager")
	if sm != null:
		enabled = bool(sm.get("music_enabled"))
		volume = float(sm.get("music_volume"))

	AudioServer.set_bus_mute(bus_index, not enabled)
	AudioServer.set_bus_volume_db(bus_index, _linear_to_bus_db(volume))


static func room_music_candidates_for(room: Variant, phase: String = "exploration") -> PackedStringArray:
	var data := _room_data(room)
	var room_name := _room_name(room)
	var tags := _room_tags(room)
	var difficulty := _room_difficulty(room)
	var candidates: Array[String] = []
	var normalized_phase := _slugify(phase)

	var explicit_music = data.get("music", null)
	if explicit_music is String:
		_append_unique(candidates, str(explicit_music))
	elif explicit_music is Dictionary:
		var music_map: Dictionary = explicit_music
		var special_key := ""
		if _room_is_boss(room):
			special_key = "boss"
		elif _room_is_mini_boss(room):
			special_key = "elite"

		if not special_key.is_empty():
			_append_unique(candidates, str(music_map.get("%s_%s" % [special_key, normalized_phase], "")))
			_append_unique(candidates, str(music_map.get(special_key, "")))
		if not difficulty.is_empty():
			_append_unique(candidates, str(music_map.get("%s_%s" % [_slugify(difficulty), normalized_phase], "")))
		_append_unique(candidates, str(music_map.get(normalized_phase, "")))
		_append_unique(candidates, str(music_map.get("default", "")))

	var direct_cue := str(data.get("music_cue", "")).strip_edges()
	_append_unique(candidates, direct_cue)

	var room_id := int(data.get("id", -1))
	if room_id >= 0:
		_append_unique(candidates, "room_%d_%s" % [room_id, normalized_phase])
		_append_unique(candidates, "room_%d" % room_id)

	var room_slug := _slugify(room_name)
	if not room_slug.is_empty():
		_append_unique(candidates, "room_%s_%s" % [room_slug, normalized_phase])
		_append_unique(candidates, "room_%s" % room_slug)

	if _room_is_boss(room):
		_append_unique(candidates, "boss_%s" % normalized_phase)
		_append_unique(candidates, "boss")
	elif _room_is_mini_boss(room):
		_append_unique(candidates, "elite_%s" % normalized_phase)
		_append_unique(candidates, "elite")

	if not difficulty.is_empty():
		var difficulty_slug := _slugify(difficulty)
		_append_unique(candidates, "difficulty_%s_%s" % [difficulty_slug, normalized_phase])
		_append_unique(candidates, "difficulty_%s" % difficulty_slug)

	for raw_tag in tags:
		var tag_slug := _slugify(str(raw_tag))
		if tag_slug.is_empty():
			continue
		_append_unique(candidates, "tag_%s_%s" % [tag_slug, normalized_phase])
		_append_unique(candidates, "tag_%s" % tag_slug)

	return PackedStringArray(candidates)


static func resolve_room_context_key(room: Variant, phase: String = "exploration", fallback_context: String = "") -> String:
	var normalized_phase := _slugify(phase)
	if normalized_phase == "combat":
		if _room_is_boss(room):
			return "boss_combat"
		if _room_is_mini_boss(room):
			return "elite_combat"
		return "combat"

	if _room_is_boss(room):
		return "exploration_boss"
	if _room_is_mini_boss(room):
		return "exploration_elite"

	var difficulty := _slugify(_room_difficulty(room))
	if not difficulty.is_empty():
		return "exploration_%s" % difficulty

	return fallback_context if not fallback_context.strip_edges().is_empty() else "exploration"


static func _append_unique(target: Array[String], value: String) -> void:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return
	if target.has(trimmed):
		return
	target.append(trimmed)


static func _room_data(room: Variant) -> Dictionary:
	if room is RoomState:
		return room.data
	if room is Dictionary:
		return room
	return {}


static func _room_name(room: Variant) -> String:
	if room is RoomState:
		return room.room_name
	if room is Dictionary:
		return str(room.get("name", ""))
	return ""


static func _room_tags(room: Variant) -> Array:
	if room is RoomState:
		return room.tags
	if room is Dictionary:
		return Array(room.get("tags", []))
	return []


static func _room_difficulty(room: Variant) -> String:
	if room is RoomState:
		return room.room_type
	if room is Dictionary:
		return str(room.get("difficulty", ""))
	return ""


static func _room_is_boss(room: Variant) -> bool:
	if room is RoomState:
		return room.is_boss_room
	if room is Dictionary:
		return bool(room.get("is_boss_room", false))
	return false


static func _room_is_mini_boss(room: Variant) -> bool:
	if room is RoomState:
		return room.is_mini_boss_room
	if room is Dictionary:
		return bool(room.get("is_mini_boss_room", false))
	return false


static func _slugify(value: String) -> String:
	var lowered := value.to_lower().strip_edges()
	var result := ""
	var in_gap := false
	for i in lowered.length():
		var ch := lowered[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			if in_gap and not result.is_empty():
				result += "_"
			result += ch
			in_gap = false
		else:
			in_gap = true
	return result


static func _linear_to_bus_db(volume: float) -> float:
	var clamped := clampf(volume, 0.0, 1.0)
	if clamped <= 0.001:
		return SILENT_DB
	return linear_to_db(clamped)
