class_name EnemySpawnResolver
extends RefCounted
## Pure deterministic spawn/split resolution — no UI, no Nodes.
##
## Mirrors Python's check_spawn_conditions, check_split_conditions,
## split_enemy behavior exactly.

# ------------------------------------------------------------------
# Types
# ------------------------------------------------------------------

class SpawnEvent extends RefCounted:
	var spawner_name: String = ""
	var spawn_type: String = ""
	var hp: int = 0
	var dice: int = 0
	var logs: Array = []


class SplitEvent extends RefCounted:
	var original_name: String = ""
	var split_type: String = ""
	var count: int = 0
	var hp: int = 0
	var dice: int = 0
	var logs: Array = []


# ------------------------------------------------------------------
# Config-based spawning (check_spawn_conditions in Python)
# ------------------------------------------------------------------

## Check all enemies for config-based spawn conditions.
## Returns Array[SpawnEvent].
static func check_spawn_conditions(enemies: Array, combat_turn_count: int,
		difficulty_hp_mult: float = 1.0) -> Array:
	var events: Array = []

	for enemy in enemies:
		if not _is_alive_obj(enemy):
			continue

		var config: Dictionary = {}
		if enemy is CombatEngine.Enemy:
			config = enemy.type_data
		elif enemy is Dictionary:
			config = enemy.get("config", {})

		if not config.get("can_spawn", false):
			continue

		var max_spawns: int = int(config.get("max_spawns", 0))
		var spawns_used: int = _get_spawns_used(enemy)
		if spawns_used >= max_spawns:
			continue

		var spawn_trigger: String = config.get("spawn_trigger", "")
		var spawner_name: String = _get_name(enemy)

		match spawn_trigger:
			"hp_threshold":
				var hp_pct: float = _hp_fraction(enemy)
				var threshold: float = float(config.get("spawn_hp_threshold", 0.5))
				if hp_pct <= threshold and spawns_used == 0:
					var spawn_count: int = int(config.get("spawn_count", 1))
					for _i in spawn_count:
						if _get_spawns_used(enemy) < max_spawns:
							var ev := _make_spawn_event(enemy, config, spawner_name, difficulty_hp_mult)
							events.append(ev)
							_increment_spawns(enemy)

			"hp_thresholds":
				var hp_pct: float = _hp_fraction(enemy)
				var thresholds: Array = config.get("spawn_hp_thresholds", [])
				for idx in thresholds.size():
					if idx >= spawns_used and hp_pct <= float(thresholds[idx]):
						if _get_spawns_used(enemy) < max_spawns:
							var spawn_count: int = int(config.get("spawn_count", 1))
							for _j in spawn_count:
								var ev := _make_spawn_event(enemy, config, spawner_name, difficulty_hp_mult)
								events.append(ev)
								_increment_spawns(enemy)
						break

			"turn_count":
				var interval: int = int(config.get("spawn_turn_interval", 3))
				var turn_spawned: int = _get_turn_spawned(enemy)
				var turns_since: int = combat_turn_count - turn_spawned
				if turns_since > 0 and turns_since % interval == 0:
					var spawn_count: int = int(config.get("spawn_count", 1))
					for _i in spawn_count:
						if _get_spawns_used(enemy) < max_spawns:
							var ev := _make_spawn_event(enemy, config, spawner_name, difficulty_hp_mult)
							events.append(ev)
							_increment_spawns(enemy)

	return events


# ------------------------------------------------------------------
# Split checks
# ------------------------------------------------------------------

## Check if enemy should split on HP threshold (alive, not yet split).
## Returns null or SplitEvent.
static func check_split_on_hp(enemy) -> SplitEvent:
	var config: Dictionary = _get_config(enemy)
	if _get_has_split(enemy):
		return null
	if not config.get("splits_on_hp", false):
		return null
	var hp_pct: float = _hp_fraction(enemy)
	var threshold: float = float(config.get("split_hp_threshold", 0.3))
	if hp_pct > threshold:
		return null
	return _make_split_event(enemy, config)


## Check if enemy should split on death.
## Returns null or SplitEvent.
static func check_split_on_death(enemy) -> SplitEvent:
	var config: Dictionary = _get_config(enemy)
	if not config.get("splits_on_death", false):
		return null
	if _get_has_split(enemy):
		return null
	return _make_split_event(enemy, config)


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

static func _make_spawn_event(enemy, config: Dictionary,
		spawner_name: String, difficulty_hp_mult: float) -> SpawnEvent:
	var ev := SpawnEvent.new()
	ev.spawner_name = spawner_name
	ev.spawn_type = config.get("spawn_type", "Skeleton")
	var hp_mult: float = float(config.get("spawn_hp_mult", 0.3))
	var max_hp: int = _get_max_hp(enemy)
	ev.hp = maxi(10, int(float(max_hp) * hp_mult))
	ev.hp = int(float(ev.hp) * difficulty_hp_mult)
	ev.dice = maxi(1, int(config.get("spawn_dice", 2)))
	ev.logs.append(CombatLogFormatter.enemy_spawned(spawner_name, ev.spawn_type))
	ev.logs.append(CombatLogFormatter.spawned_stats(ev.spawn_type, ev.hp, ev.dice))
	return ev


static func _make_split_event(enemy, config: Dictionary) -> SplitEvent:
	var ev := SplitEvent.new()
	ev.original_name = _get_name(enemy)
	ev.split_type = config.get("split_into_type", "Shard")
	ev.count = int(config.get("split_count", 2))
	var hp_pct: float = float(config.get("split_hp_percent", 0.5))
	ev.hp = maxi(10, int(float(_get_max_hp(enemy)) * hp_pct))
	var dice_delta: int = int(config.get("split_dice", -1))
	ev.dice = maxi(1, _get_num_dice(enemy) + dice_delta)
	ev.logs.append(CombatLogFormatter.enemy_split(ev.original_name, ev.count, ev.split_type))
	for _i in ev.count:
		ev.logs.append(CombatLogFormatter.split_stats(ev.split_type, ev.hp, ev.dice))
	return ev


static func _is_alive_obj(e) -> bool:
	if e is CombatEngine.Enemy:
		return e.is_alive()
	elif e is Dictionary:
		return int(e.get("health", 0)) > 0
	return false

static func _hp_fraction(e) -> float:
	if e is CombatEngine.Enemy:
		return e.hp_fraction()
	elif e is Dictionary:
		var mhp: int = int(e.get("max_health", 1))
		if mhp <= 0:
			return 0.0
		return float(e.get("health", 0)) / float(mhp)
	return 0.0

static func _get_name(e) -> String:
	if e is CombatEngine.Enemy:
		return e.name
	elif e is Dictionary:
		return e.get("name", "")
	return ""

static func _get_max_hp(e) -> int:
	if e is CombatEngine.Enemy:
		return e.max_health
	elif e is Dictionary:
		return int(e.get("max_health", 0))
	return 0

static func _get_num_dice(e) -> int:
	if e is CombatEngine.Enemy:
		return e.num_dice
	elif e is Dictionary:
		return int(e.get("num_dice", 2))
	return 2

static func _get_config(e) -> Dictionary:
	if e is CombatEngine.Enemy:
		return e.type_data
	elif e is Dictionary:
		return e.get("config", {})
	return {}

static func _get_spawns_used(e) -> int:
	if e is CombatEngine.Enemy:
		return e.spawns_done
	elif e is Dictionary:
		return int(e.get("spawns_used", 0))
	return 0

static func _increment_spawns(e) -> void:
	if e is CombatEngine.Enemy:
		e.spawns_done += 1
	elif e is Dictionary:
		e["spawns_used"] = int(e.get("spawns_used", 0)) + 1

static func _get_turn_spawned(e) -> int:
	if e is CombatEngine.Enemy:
		return e.turn_spawned
	elif e is Dictionary:
		return int(e.get("turn_spawned", 0))
	return 0

static func _get_has_split(e) -> bool:
	if e is CombatEngine.Enemy:
		return e.type_data.get("_has_split", false)
	elif e is Dictionary:
		return e.get("has_split", false)
	return false
