class_name CombatEngine
extends RefCounted
## Headless combat loop — no UI, fully deterministic with DeterministicRNG.
##
## Manages: player dice, multi-enemy targeting, enemy attacks, status ticks,
## splitting/spawning behaviors, crit/fumble, flee.
##
## Delegates to modular sub-systems:
##   AbilitySystem  — ability trigger evaluation + event generation
##   EffectSystem   — curse/status/burn tick logic
##   RewardResolver — gold/item/score calculation
##   EnemySpawnResolver — config-based spawn/split checks
##   CombatLogFormatter — all log text (Python-parity)

# ------------------------------------------------------------------
# Types
# ------------------------------------------------------------------

## One enemy in the encounter.
class Enemy extends RefCounted:
	var name: String
	var health: int
	var max_health: int
	var num_dice: int
	var type_data: Dictionary  ## from enemy_types.json (may be empty)
	var turn_spawned: int = 0  ## combat turn on which this enemy appeared
	var spawns_done: int = 0   ## how many times periodic spawn has fired
	var damage_reduction: int = 0  ## flat damage reduction from abilities
	var is_boss: bool = false
	var is_mini_boss: bool = false

	func _init(p_name: String, p_hp: int, p_dice: int, p_type: Dictionary = {}) -> void:
		name = p_name
		health = p_hp
		max_health = p_hp
		num_dice = p_dice
		type_data = p_type

	func is_alive() -> bool:
		return health > 0

	func hp_fraction() -> float:
		if max_health <= 0:
			return 0.0
		return float(health) / float(max_health)


## Snapshot of a single turn's result.
class TurnResult extends RefCounted:
	var player_dice: Array = []
	var player_damage: int = 0
	var was_crit: bool = false
	var was_fumble: bool = false
	var target_name: String = ""
	var target_killed: bool = false
	var enemy_rolls: Array = []    ## [{name, dice, damage}]
	var status_tick_damage: int = 0
	var spawned: Array = []        ## names of newly spawned enemies
	var split_into: Array = []     ## names of enemies created from splitting
	var player_hp_after: int = 0
	var logs: Array = []
	var trace_events: Array = []   ## structured trace events


## Full combat outcome.
class CombatResult extends RefCounted:
	var victory: bool = false
	var fled: bool = false
	var player_died: bool = false
	var turns: Array = []        ## Array[TurnResult]
	var gold_reward: int = 0
	var total_damage_dealt: int = 0
	var total_damage_taken: int = 0


# ------------------------------------------------------------------
# State
# ------------------------------------------------------------------

var rng: RNG
var state: GameState
var enemies: Array = []      ## Array[Enemy]
var dice: DiceRoller
var turn_count: int = 0
var enemy_types_db: Dictionary = {}  ## full enemy_types.json
var statuses_db: Dictionary = {}     ## full statuses_catalog.json

var active_curses: Array = []        ## Array[Dictionary]
var boss_ability_cooldowns: Dictionary = {}
var dice_obscured: bool = false
var dice_restricted_values: Array = []
var forced_dice_locks: Array = []    ## indices that are force-locked
var enemy_burn_status: Dictionary = {}  ## int(index) -> {initial_damage, turns_remaining}

var _logs: Array = []
var _trace: SessionTrace


func _init(p_rng: RNG, p_state: GameState, p_num_dice: int = 3,
		   p_enemy_types: Dictionary = {}, p_statuses: Dictionary = {}) -> void:
	rng = p_rng
	state = p_state
	dice = DiceRoller.new(rng, p_num_dice)
	enemy_types_db = p_enemy_types
	statuses_db = p_statuses


func set_trace(trace: SessionTrace) -> void:
	_trace = trace


# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

func add_enemy(enemy_name: String, hp: int, num_dice: int) -> Enemy:
	var type_data: Dictionary = enemy_types_db.get(enemy_name, {})
	var enemy := Enemy.new(enemy_name, hp, num_dice, type_data)
	enemy.turn_spawned = turn_count
	enemies.append(enemy)
	return enemy


func get_alive_enemies() -> Array:
	var alive: Array = []
	for e in enemies:
		if e.is_alive():
			alive.append(e)
	return alive


## Trigger combat_start abilities for all enemies.
func trigger_combat_start_abilities() -> Array:
	var all_logs: Array = []
	for enemy in enemies:
		var events := _evaluate_abilities(enemy, "combat_start")
		for ev in events:
			var logs := _apply_ability_event(ev, enemy)
			all_logs.append_array(logs)
	return all_logs


# ------------------------------------------------------------------
# Player turn
# ------------------------------------------------------------------

func player_roll() -> bool:
	if not dice_restricted_values.is_empty():
		return _roll_restricted()
	return dice.roll()


func _roll_restricted() -> bool:
	if dice.rolls_left <= 0:
		return false
	var rolled_any := false
	for i in dice.num_dice:
		if not dice.locked[i]:
			dice.values[i] = rng.choice(dice_restricted_values)
			rolled_any = true
	if rolled_any:
		dice.rolls_left -= 1
	return rolled_any


func player_lock(index: int) -> void:
	dice.lock(index)


func player_attack(target_index: int = 0) -> TurnResult:
	var result := TurnResult.new()
	result.player_dice = dice.values.duplicate()
	turn_count += 1

	# --- Process boss curses at start of turn ---
	var curse_result := EffectSystem.tick_curses(active_curses, enemies, state.health)
	if curse_result.curse_damage_total > 0:
		state.health -= curse_result.curse_damage_total
	for heal_info in curse_result.heals:
		_apply_heal_to_enemy(heal_info["enemy_name"], heal_info["amount"])
	_remove_curse_indices(curse_result.removed_indices)
	_process_curse_expiry_side_effects(curse_result.expired)
	result.logs.append_array(curse_result.logs)
	if state.health <= 0:
		result.player_hp_after = state.health
		_logs.append_array(result.logs)
		return result

	# --- Reroll curse check ---
	var has_reroll_curse := false
	for c in active_curses:
		if c.get("type") == "curse_reroll":
			has_reroll_curse = true
			break

	# --- Fumble check ---
	var fumble_chance := _get_status_modifier("skip_chance")
	if fumble_chance > 0.0:
		var fumble_roll := rng.randf()
		if _trace: _trace.record_rng_roll("fumble_check", int(fumble_roll * 1000), {"threshold": fumble_chance})
		if fumble_roll < fumble_chance:
			result.was_fumble = true
		result.player_damage = 0
		result.logs.append("Fumbled! Attack missed.")
	else:
		# --- Crit check ---
		var crit_chance: float = state.crit_chance + _get_temp_float("crit_bonus") + _get_status_modifier("crit_bonus")
		crit_chance = maxf(crit_chance, 0.0)
		var crit_roll := rng.randf()
		if _trace: _trace.record_rng_roll("crit_check", int(crit_roll * 1000), {"threshold": crit_chance})
		result.was_crit = crit_roll < crit_chance

		# --- Damage ---
		var dmg_bonus: int = state.damage_bonus + _get_temp_int("damage_bonus") + int(_get_status_modifier("damage_bonus"))
		var damage := dice.calc_total_damage(state.multiplier, dmg_bonus)
		damage = int(float(damage) * state.difficulty_mults.get("player_damage_mult", 1.0))
		if result.was_crit:
			damage = int(float(damage) * 1.5)

		# --- Damage reduction from boss abilities ---
		var alive := get_alive_enemies()
		if target_index >= 0 and target_index < alive.size():
			var target: Enemy = alive[target_index]
			if target.damage_reduction > 0:
				var original_damage := damage
				damage = maxi(1, damage - target.damage_reduction)
				if damage < original_damage:
					result.logs.append(CombatLogFormatter.damage_reduction_applied(
						target.damage_reduction, original_damage, damage))

		result.player_damage = damage

		# --- Apply to target ---
		if target_index >= 0 and target_index < alive.size():
			var target: Enemy = alive[target_index]
			target.health -= damage
			result.target_name = target.name
			result.target_killed = not target.is_alive()
			result.logs.append(CombatLogFormatter.player_hit(target.name, damage, result.was_crit))

			# --- HP threshold abilities AFTER damage ---
			var hp_events := _evaluate_abilities(target, "hp_threshold")
			for ev in hp_events:
				var logs := _apply_ability_event(ev, target)
				result.logs.append_array(logs)
				for sp in ev.spawns:
					result.spawned.append(sp["type"])

			# --- Splitting on death ---
			if result.target_killed:
				var split := EnemySpawnResolver.check_split_on_death(target)
				if split != null:
					_apply_split(target, split, result)
				else:
					# on_death abilities (spawn_on_death, transform_on_death)
					var death_events := _evaluate_abilities(target, "on_death")
					for ev in death_events:
						var logs := _apply_ability_event(ev, target)
						result.logs.append_array(logs)
						for sp in ev.spawns:
							result.spawned.append(sp["type"])

			# --- Split on HP threshold (alive) ---
			if not result.target_killed and target.is_alive():
				var split := EnemySpawnResolver.check_split_on_hp(target)
				if split != null:
					_apply_split(target, split, result)

			# --- Config-based HP spawns ---
			var spawn_events := EnemySpawnResolver.check_spawn_conditions(
				enemies, turn_count, state.difficulty_mults.get("enemy_health_mult", 1.0))
			for sev in spawn_events:
				var child := add_enemy(sev.spawn_type, sev.hp, sev.dice)
				child.turn_spawned = turn_count
				result.spawned.append(sev.spawn_type)
				result.logs.append_array(sev.logs)

	# --- Status tick damage ---
	# If statuses_db has entries, use the catalog-based system (Godot-specific).
	# Otherwise, use Python-style name-based matching (5 dmg per DoT).
	if not statuses_db.is_empty():
		result.status_tick_damage = _tick_statuses()
		state.health -= result.status_tick_damage
		if result.status_tick_damage > 0:
			result.logs.append("Status effects deal %d damage" % result.status_tick_damage)
	else:
		var py_statuses: Array = state.flags.get("statuses", [])
		if not py_statuses.is_empty():
			var py_result := EffectSystem.tick_statuses(py_statuses)
			if py_result.damage > 0:
				state.health -= py_result.damage
				result.status_tick_damage += py_result.damage
				result.logs.append_array(py_result.logs)

	# --- Enemy burn ticks ---
	if not enemy_burn_status.is_empty():
		var burn_result := EffectSystem.tick_enemy_burns(enemy_burn_status, enemies)
		for tick_info in burn_result.ticks:
			var idx: int = tick_info["enemy_index"]
			if idx < enemies.size():
				enemies[idx].health -= tick_info["damage"]
		result.logs.append_array(burn_result.logs)

	# --- Enemy attacks ---
	var alive_after := get_alive_enemies()
	for enemy in alive_after:
		if enemy.turn_spawned == turn_count:
			result.logs.append(CombatLogFormatter.enemy_just_spawned(enemy.name))
			continue
		var enemy_dice: Array[int] = []
		for _d in enemy.num_dice:
			var die_val := rng.rand_int(1, 6)
			enemy_dice.append(die_val)
		if _trace: _trace.record_rng_roll("enemy_dice", 0, {"enemy": enemy.name, "dice": enemy_dice.duplicate()})
		var enemy_dmg: int = 0
		for d in enemy_dice:
			enemy_dmg += d

		var enemy_mult := _get_status_modifier("enemy_damage_mult")
		if enemy_mult > 0.0:
			enemy_dmg = int(float(enemy_dmg) * enemy_mult)

		enemy_dmg = int(float(enemy_dmg) * state.difficulty_mults.get("enemy_damage_mult", 1.0))

		if state.temp_shield > 0:
			var absorbed := mini(state.temp_shield, enemy_dmg)
			state.temp_shield -= absorbed
			enemy_dmg -= absorbed

		state.health -= enemy_dmg
		result.enemy_rolls.append({"name": enemy.name, "dice": enemy_dice, "damage": enemy_dmg})
		result.logs.append("%s rolls %s for %d damage" % [enemy.name, str(enemy_dice), enemy_dmg])

	# --- Periodic spawns (ability-driven) ---
	_handle_periodic_spawns(result)

	# --- Inflict-status abilities (enemy_turn trigger) ---
	_handle_inflict_status(result)

	result.player_hp_after = state.health

	# Reset dice for next turn
	var extra_rolls: int = state.reroll_bonus + _get_temp_int("extra_rolls") + int(_get_status_modifier("extra_rolls"))
	if has_reroll_curse:
		dice.rolls_left = 1
	else:
		dice.reset_turn(extra_rolls)

	# Preserve forced dice locks across turns
	for idx in forced_dice_locks:
		if idx < dice.num_dice:
			dice.locked[idx] = true

	_logs.append_array(result.logs)
	return result


# ------------------------------------------------------------------
# Flee
# ------------------------------------------------------------------

func attempt_flee() -> bool:
	var roll := rng.randf()
	if _trace: _trace.record_rng_roll("flee_attempt", int(roll * 1000), {"threshold": 0.5})
	return roll < 0.5


# ------------------------------------------------------------------
# Full combat run (convenience for testing)
# ------------------------------------------------------------------

func run_auto_combat(lock_strategy: Callable = Callable()) -> CombatResult:
	var result := CombatResult.new()

	while state.health > 0 and not get_alive_enemies().is_empty():
		dice.reset_turn(state.reroll_bonus + _get_temp_int("extra_rolls"))
		dice.roll()

		if lock_strategy.is_valid():
			lock_strategy.call(dice)

		while dice.rolls_left > 0:
			var unlocked := false
			for i in dice.num_dice:
				if not dice.locked[i]:
					unlocked = true
					break
			if not unlocked:
				break
			dice.roll()
			if lock_strategy.is_valid():
				lock_strategy.call(dice)

		var turn = player_attack(0)
		if turn == null:
			break
		result.turns.append(turn)
		result.total_damage_dealt += turn.player_damage
		for er in turn.enemy_rolls:
			result.total_damage_taken += int(er["damage"])

	result.victory = get_alive_enemies().is_empty() and state.health > 0
	result.player_died = state.health <= 0

	if result.victory:
		result.gold_reward = rng.rand_int(10, 30)

	return result


# ------------------------------------------------------------------
# Ability system integration
# ------------------------------------------------------------------

func _evaluate_abilities(enemy: Enemy, trigger: String) -> Array:
	var cs := _build_combat_state(enemy)
	return AbilitySystem.evaluate_abilities(enemy.name, enemy.type_data, trigger, cs, rng)


func _build_combat_state(enemy: Enemy) -> Dictionary:
	return {
		"combat_turn_count": turn_count,
		"boss_ability_cooldowns": boss_ability_cooldowns,
		"enemy_hp_fraction": enemy.hp_fraction(),
		"enemy_max_health": enemy.max_health,
		"enemy_health_mult": state.difficulty_mults.get("enemy_health_mult", 1.0),
		"floor": state.floor,
		"num_dice": dice.num_dice,
		"dice_locked": dice.locked.duplicate(),
		"statuses": state.flags.get("statuses", []).duplicate(),
	}


func _apply_ability_event(ev: AbilitySystem.AbilityEvent, source_enemy: Enemy) -> Array:
	var logs: Array = []

	if not ev.message.is_empty():
		logs.append(CombatLogFormatter.ability_triggered(ev.message))

	if not ev.curse.is_empty():
		if ev.curse.has("target_enemy_name"):
			ev.curse["_source_enemy"] = source_enemy
		active_curses.append(ev.curse)

	if ev.obscure_dice:
		dice_obscured = true

	if not ev.restrict_values.is_empty():
		dice_restricted_values = ev.restrict_values

	if not ev.dice_locks.is_empty():
		forced_dice_locks = ev.dice_locks
		for idx in ev.dice_locks:
			if idx < dice.num_dice:
				dice.locked[idx] = true
		for idx in ev.dice_values:
			if idx < dice.num_dice:
				dice.values[idx] = ev.dice_values[idx]

	if ev.rolls_override >= 0:
		dice.rolls_left = mini(dice.rolls_left, ev.rolls_override)

	if not ev.status_inflicted.is_empty():
		var statuses: Array = state.flags.get("statuses", [])
		if not statuses.has(ev.status_inflicted):
			statuses.append(ev.status_inflicted)
			state.flags["statuses"] = statuses

	for sp in ev.spawns:
		var child := add_enemy(sp["type"], sp["hp"], sp["dice"])
		child.turn_spawned = turn_count
		logs.append(CombatLogFormatter.enemy_spawned(ev.enemy_name, sp["type"]))
		logs.append(CombatLogFormatter.spawned_stats(sp["type"], sp["hp"], sp["dice"]))

	if not ev.transform.is_empty():
		var into: String = ev.transform["into"]
		var t_hp: int = ev.transform["hp"]
		var t_dice: int = ev.transform["dice"]
		var new_enemy := Enemy.new(into, t_hp, t_dice, enemy_types_db.get(into, {}))
		new_enemy.turn_spawned = turn_count
		new_enemy.is_boss = source_enemy.is_boss
		new_enemy.is_mini_boss = source_enemy.is_mini_boss
		var idx := enemies.find(source_enemy)
		if idx >= 0:
			enemies[idx] = new_enemy
		else:
			enemies.append(new_enemy)
		logs.append(CombatLogFormatter.transformed_stats(into, t_hp, t_dice))
		# Trigger combat_start for new form
		var start_events := _evaluate_abilities(new_enemy, "combat_start")
		for sev in start_events:
			logs.append_array(_apply_ability_event(sev, new_enemy))

	if source_enemy != null and ev.ability_type == "damage_reduction":
		source_enemy.damage_reduction = int(ev.curse.get("reduction_amount", 0))

	return logs


# ------------------------------------------------------------------
# Splitting / Spawning (legacy compat + new modular)
# ------------------------------------------------------------------

func _apply_split(dead_enemy: Enemy, split: EnemySpawnResolver.SplitEvent, result: TurnResult) -> void:
	var idx := enemies.find(dead_enemy)
	result.logs.append_array(split.logs)
	for i in split.count:
		var child := Enemy.new(split.split_type, split.hp, split.dice, enemy_types_db.get(split.split_type, {}))
		child.turn_spawned = turn_count
		if idx >= 0:
			enemies.insert(idx + 1 + i, child)
		else:
			enemies.append(child)
		result.split_into.append(split.split_type)


func _handle_hp_spawns(result: TurnResult) -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		for ability in enemy.type_data.get("boss_abilities", []):
			if ability.get("type") != "spawn_minions":
				continue
			if ability.get("trigger") != "hp_threshold":
				continue
			var threshold: float = float(ability.get("hp_threshold", 0.5))
			if enemy.hp_fraction() > threshold:
				continue
			if enemy.spawns_done > 0:
				continue
			enemy.spawns_done += 1

			var spawn_type: String = ability.get("spawn_type", "Minion")
			var spawn_count: int = int(ability.get("spawn_count", 1))
			var hp_mult: float = float(ability.get("spawn_hp_mult", 0.3))
			var spawn_dice: int = int(ability.get("spawn_dice", 2))
			var child_hp := maxi(1, int(float(enemy.max_health) * hp_mult))

			for _i in spawn_count:
				var child := add_enemy(spawn_type, child_hp, spawn_dice)
				child.turn_spawned = turn_count
				result.spawned.append(spawn_type)
				result.logs.append("%s spawns %s (%d HP)" % [enemy.name, spawn_type, child_hp])


func _handle_periodic_spawns(result: TurnResult) -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		for ability in enemy.type_data.get("boss_abilities", []):
			if ability.get("type") != "spawn_minions_periodic":
				continue
			var interval: int = int(ability.get("interval_turns", 3))
			var max_spawns: int = int(ability.get("max_spawns", 4))
			if enemy.spawns_done >= max_spawns:
				continue
			if turn_count % interval != 0:
				continue

			var spawn_type: String = ability.get("spawn_type", "Minion")
			var spawn_count: int = int(ability.get("spawn_count", 1))
			var hp_mult: float = float(ability.get("spawn_hp_mult", 0.25))
			var spawn_dice: int = int(ability.get("spawn_dice", 2))
			var child_hp := maxi(1, int(float(enemy.max_health) * hp_mult))

			for _i in spawn_count:
				enemy.spawns_done += 1
				var child := add_enemy(spawn_type, child_hp, spawn_dice)
				child.turn_spawned = turn_count
				result.spawned.append(spawn_type)
				result.logs.append("%s summons %s (%d HP)" % [enemy.name, spawn_type, child_hp])


func _handle_inflict_status(result: TurnResult) -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		for ability in enemy.type_data.get("boss_abilities", []):
			if ability.get("type") != "inflict_status":
				continue
			var interval: int = int(ability.get("interval_turns", 3))
			if interval > 0 and turn_count % interval != 0:
				continue
			var status_name: String = ability.get("status_name", "")
			if status_name.is_empty():
				continue
			var statuses: Array = state.flags.get("statuses", [])
			if not statuses.has(status_name):
				statuses.append(status_name)
				state.flags["statuses"] = statuses
				result.logs.append("%s inflicts %s!" % [enemy.name, status_name])


# ------------------------------------------------------------------
# Curse helpers
# ------------------------------------------------------------------

func _apply_heal_to_enemy(enemy_name: String, amount: int) -> void:
	for e in enemies:
		if e.name == enemy_name and e.is_alive():
			e.health = mini(e.health + amount, e.max_health)
			break


func _remove_curse_indices(indices: Array) -> void:
	for i in indices:
		if i < active_curses.size():
			active_curses.remove_at(i)


func _process_curse_expiry_side_effects(expired: Array) -> void:
	for info in expired:
		var ctype: String = info.get("type", "")
		match ctype:
			"dice_obscure":
				dice_obscured = false
			"dice_restrict":
				dice_restricted_values = []
			"dice_lock_random":
				for idx in forced_dice_locks:
					if idx < dice.num_dice:
						dice.locked[idx] = false
				forced_dice_locks = []
			"damage_reduction":
				for e in enemies:
					e.damage_reduction = 0


# ------------------------------------------------------------------
# Status effects
# ------------------------------------------------------------------

func _tick_statuses() -> int:
	var total_damage := 0
	var statuses: Array = state.flags.get("statuses", [])
	var to_remove: Array = []

	for status_name in statuses:
		var sdata: Dictionary = statuses_db.get(status_name, {})
		var tick_dmg: int = int(sdata.get("tick_damage", 0))

		if tick_dmg > 0 and sdata.get("poison_null", false):
			tick_dmg = 0

		total_damage += tick_dmg

		var turns: int = int(sdata.get("turns", 1))
		if turns <= 1:
			to_remove.append(status_name)
		else:
			sdata["turns"] = turns - 1
			statuses_db[status_name] = sdata

	for s in to_remove:
		statuses.erase(s)
	state.flags["statuses"] = statuses

	return total_damage


func _get_status_modifier(key: String) -> float:
	var total := 0.0
	var statuses: Array = state.flags.get("statuses", [])
	for status_name in statuses:
		var sdata: Dictionary = statuses_db.get(status_name, {})
		total += float(sdata.get(key, 0.0))
	return total


func _get_temp_int(key: String) -> int:
	var entry = state.temp_effects.get(key)
	if entry == null or not entry is Dictionary:
		return 0
	return int(entry.get("delta", 0))


func _get_temp_float(key: String) -> float:
	var entry = state.temp_effects.get(key)
	if entry == null or not entry is Dictionary:
		return 0.0
	return float(entry.get("delta", 0.0))
