class_name AbilitySystem
extends RefCounted
## Pure deterministic ability evaluation — no UI, no Nodes.
##
## Given combat state + RNG + ability definition, returns structured events
## and state deltas.  The caller (CombatEngine / CombatService) applies
## the deltas and forwards events to the log formatter.
##
## Mirrors Python's _trigger_boss_abilities / _execute_boss_ability exactly.

# ------------------------------------------------------------------
# Types
# ------------------------------------------------------------------

## Result of evaluating one ability.
class AbilityEvent extends RefCounted:
	var ability_type: String = ""
	var enemy_name: String = ""
	var message: String = ""          ## ability's own message (logged as "⚠️ {message}")
	var curse: Dictionary = {}        ## curse to add to active_curses (empty = none)
	var status_inflicted: String = "" ## status name added to player (empty = none)
	var spawns: Array = []            ## [{type, hp, dice}] enemies to create
	var transform: Dictionary = {}    ## {into, hp, dice} replacement enemy (empty = none)
	var dice_locks: Array = []        ## indices force-locked
	var dice_values: Dictionary = {}  ## idx -> forced value
	var restrict_values: Array = []   ## dice restriction set (empty = clear)
	var obscure_dice: bool = false
	var rolls_override: int = -1      ## if >= 0, set rolls_left to this


# ------------------------------------------------------------------
# API
# ------------------------------------------------------------------

## Evaluate all abilities for one enemy at the given trigger phase.
## Returns Array[AbilityEvent].
static func evaluate_abilities(
		enemy_name: String,
		enemy_data: Dictionary,
		trigger: String,
		combat_state: Dictionary,
		rng: RNG) -> Array:

	var abilities: Array = enemy_data.get("boss_abilities", [])
	if abilities.is_empty():
		return []

	var events: Array = []
	for ability in abilities:
		if ability.get("trigger", "") != trigger:
			continue

		if not _should_trigger(ability, trigger, enemy_name, combat_state):
			continue

		_record_cooldown(ability, trigger, enemy_name, combat_state)

		var ev := _execute(ability, enemy_name, combat_state, rng)
		if ev != null:
			events.append(ev)

	return events


# ------------------------------------------------------------------
# Trigger gating
# ------------------------------------------------------------------

static func _should_trigger(ability: Dictionary, trigger: String,
		enemy_name: String, cs: Dictionary) -> bool:
	match trigger:
		"combat_start":
			return true
		"hp_threshold":
			var threshold: float = float(ability.get("hp_threshold", 0.5))
			var hp_frac: float = cs.get("enemy_hp_fraction", 1.0)
			var key := _cooldown_key_hp(enemy_name, ability, threshold)
			var cooldowns: Dictionary = cs.get("boss_ability_cooldowns", {})
			return hp_frac <= threshold and not cooldowns.has(key)
		"enemy_turn":
			var interval: int = int(ability.get("interval_turns", 1))
			var turn: int = cs.get("combat_turn_count", 0)
			var key := _cooldown_key_turn(enemy_name, ability)
			var cooldowns: Dictionary = cs.get("boss_ability_cooldowns", {})
			var last_trigger = cooldowns.get(key, -interval)
			if last_trigger is bool:
				last_trigger = -interval
			return (turn - int(last_trigger)) >= interval
		"on_death":
			return true
	return false


static func _record_cooldown(ability: Dictionary, trigger: String,
		enemy_name: String, cs: Dictionary) -> void:
	var cooldowns: Dictionary = cs.get("boss_ability_cooldowns", {})
	match trigger:
		"hp_threshold":
			var threshold: float = float(ability.get("hp_threshold", 0.5))
			cooldowns[_cooldown_key_hp(enemy_name, ability, threshold)] = true
		"enemy_turn":
			var turn: int = cs.get("combat_turn_count", 0)
			cooldowns[_cooldown_key_turn(enemy_name, ability)] = turn
	cs["boss_ability_cooldowns"] = cooldowns


static func _cooldown_key_hp(name: String, ability: Dictionary, threshold: float) -> String:
	return "%s_%s_hp_%s" % [name, ability.get("type", ""), str(threshold)]


static func _cooldown_key_turn(name: String, ability: Dictionary) -> String:
	return "%s_%s_turn" % [name, ability.get("type", "")]


# ------------------------------------------------------------------
# Execution — returns one AbilityEvent (or null)
# ------------------------------------------------------------------

static func _execute(ability: Dictionary, enemy_name: String,
		cs: Dictionary, rng: RNG) -> AbilityEvent:
	var ev := AbilityEvent.new()
	ev.ability_type = ability.get("type", "")
	ev.enemy_name = enemy_name
	ev.message = ability.get("message", "")

	match ev.ability_type:

		"dice_obscure":
			ev.obscure_dice = true
			ev.curse = {
				"type": "dice_obscure",
				"turns_left": int(ability.get("duration_turns", 2)),
				"message": "Your dice values are hidden!",
			}

		"dice_restrict":
			var rv: Array = ability.get("restricted_values", [1, 2, 3, 4, 5, 6])
			ev.restrict_values = rv
			ev.curse = {
				"type": "dice_restrict",
				"turns_left": int(ability.get("duration_turns", 2)),
				"restricted_values": rv,
				"message": "Your dice can only roll: %s!" % str(rv),
			}

		"dice_lock_random":
			var lock_count: int = int(ability.get("lock_count", 1))
			var num_dice: int = int(cs.get("num_dice", 3))
			var locked_flags: Array = cs.get("dice_locked", [])
			var unlocked: Array = []
			for i in num_dice:
				if i < locked_flags.size() and not locked_flags[i]:
					unlocked.append(i)
				elif i >= locked_flags.size():
					unlocked.append(i)
			if not unlocked.is_empty():
				var to_lock: Array = rng.sample(unlocked, mini(lock_count, unlocked.size()))
				var forced_vals: Dictionary = {}
				for idx in to_lock:
					forced_vals[idx] = rng.rand_int(1, 6)
				ev.dice_locks = to_lock
				ev.dice_values = forced_vals
				ev.curse = {
					"type": "dice_lock_random",
					"turns_left": int(ability.get("duration_turns", 1)),
					"locked_indices": to_lock,
					"message": "%d dice are force-locked!" % lock_count,
				}

		"curse_reroll":
			var duration: int = int(ability.get("duration_turns", 3))
			ev.rolls_override = 1
			ev.curse = {
				"type": "curse_reroll",
				"turns_left": duration,
				"message": "You can only reroll once per turn!",
			}

		"curse_damage":
			var damage: int = int(ability.get("damage_per_turn", 3))
			var duration: int = int(ability.get("duration_turns", 999))
			ev.curse = {
				"type": "curse_damage",
				"turns_left": duration,
				"damage": damage,
				"message": "You take %d damage per turn!" % damage,
			}

		"inflict_status":
			var status_name: String = ability.get("status_name", "Poison")
			var current: Array = cs.get("statuses", [])
			if not current.has(status_name):
				ev.status_inflicted = status_name

		"heal_over_time":
			var heal: int = int(ability.get("heal_per_turn", 8))
			var duration: int = int(ability.get("duration_turns", 5))
			ev.curse = {
				"type": "heal_over_time",
				"turns_left": duration,
				"heal_amount": heal,
				"target_enemy_name": enemy_name,
				"message": "Enemy regenerates %d HP per turn!" % heal,
			}

		"damage_reduction":
			var reduction: int = int(ability.get("reduction_amount", 5))
			var duration: int = int(ability.get("duration_turns", 999))
			ev.curse = {
				"type": "damage_reduction",
				"turns_left": duration,
				"reduction_amount": reduction,
				"target_enemy_name": enemy_name,
				"message": "Enemy has %d damage reduction!" % reduction,
			}

		"spawn_minions", "spawn_on_death":
			var spawn_type: String = ability.get("spawn_type", "Skeleton")
			var count: int = int(ability.get("spawn_count", 2))
			var hp_mult: float = float(ability.get("spawn_hp_mult", 0.3))
			var sdice: int = int(ability.get("spawn_dice", 2))
			var max_hp: int = int(cs.get("enemy_max_health", 100))
			var spawn_hp: int = maxi(10, int(float(max_hp) * hp_mult))
			var difficulty_hp_mult: float = float(cs.get("enemy_health_mult", 1.0))
			spawn_hp = int(float(spawn_hp) * difficulty_hp_mult)
			sdice = maxi(1, sdice)
			for i in count:
				ev.spawns.append({"type": spawn_type, "hp": spawn_hp, "dice": sdice})

		"spawn_minions_periodic":
			var spawn_type: String = ability.get("spawn_type", "Imp")
			var count: int = int(ability.get("spawn_count", 1))
			var hp_mult: float = float(ability.get("spawn_hp_mult", 0.25))
			var sdice: int = int(ability.get("spawn_dice", 2))
			var max_spawns_total: int = int(ability.get("max_spawns", 999))
			var max_hp: int = int(cs.get("enemy_max_health", 100))
			var spawn_hp: int = maxi(10, int(float(max_hp) * hp_mult))
			var difficulty_hp_mult: float = float(cs.get("enemy_health_mult", 1.0))
			spawn_hp = int(float(spawn_hp) * difficulty_hp_mult)
			sdice = maxi(1, sdice)
			var cooldowns: Dictionary = cs.get("boss_ability_cooldowns", {})
			var count_key := "%s_periodic_spawns_count" % enemy_name
			var current_spawns: int = int(cooldowns.get(count_key, 0))
			if current_spawns < max_spawns_total:
				for i in count:
					ev.spawns.append({"type": spawn_type, "hp": spawn_hp, "dice": sdice})
				cooldowns[count_key] = current_spawns + count
				cs["boss_ability_cooldowns"] = cooldowns

		"transform_on_death":
			var into: String = ability.get("transform_into", "")
			if into.is_empty():
				return null
			var hp_mult: float = float(ability.get("hp_mult", 0.6))
			var dice_count: int = int(ability.get("dice_count", 4))
			var floor_num: int = int(cs.get("floor", 1))
			var base_hp: int = 50 + (floor_num * 10)
			var t_hp: int = int(float(base_hp) * hp_mult * 1.5)
			var difficulty_hp_mult: float = float(cs.get("enemy_health_mult", 1.0))
			t_hp = int(float(t_hp) * difficulty_hp_mult)
			ev.transform = {"into": into, "hp": t_hp, "dice": dice_count}

		_:
			return null

	return ev
