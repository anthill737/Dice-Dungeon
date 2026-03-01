class_name CombatEngine
extends RefCounted
## Headless combat loop — no UI, fully deterministic with DeterministicRNG.
##
## Manages: player dice, multi-enemy targeting, enemy attacks, status ticks,
## splitting/spawning behaviors, crit/fumble, flee.

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

var _logs: Array = []


func _init(p_rng: RNG, p_state: GameState, p_num_dice: int = 3,
		   p_enemy_types: Dictionary = {}, p_statuses: Dictionary = {}) -> void:
	rng = p_rng
	state = p_state
	dice = DiceRoller.new(rng, p_num_dice)
	enemy_types_db = p_enemy_types
	statuses_db = p_statuses


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


# ------------------------------------------------------------------
# Player turn
# ------------------------------------------------------------------

func player_roll() -> bool:
	return dice.roll()


func player_lock(index: int) -> void:
	dice.lock(index)


func player_attack(target_index: int = 0) -> TurnResult:
	## Execute a full turn: player attacks target, enemies retaliate, status ticks.
	var result := TurnResult.new()
	result.player_dice = dice.values.duplicate()
	turn_count += 1

	# --- Fumble check ---
	var fumble_chance := _get_status_modifier("skip_chance")
	if fumble_chance > 0.0 and rng.randf() < fumble_chance:
		result.was_fumble = true
		result.player_damage = 0
		result.logs.append("Fumbled! Attack missed.")
	else:
		# --- Crit check ---
		var crit_chance: float = state.crit_chance + _get_temp_float("crit_bonus") + _get_status_modifier("crit_bonus")
		crit_chance = maxf(crit_chance, 0.0)
		result.was_crit = rng.randf() < crit_chance

		# --- Damage ---
		var dmg_bonus: int = state.damage_bonus + _get_temp_int("damage_bonus") + int(_get_status_modifier("damage_bonus"))
		var damage := dice.calc_total_damage(state.multiplier, dmg_bonus)
		if result.was_crit:
			damage = int(float(damage) * 1.5)
		result.player_damage = damage

		# --- Apply to target ---
		var alive := get_alive_enemies()
		if target_index >= 0 and target_index < alive.size():
			var target: Enemy = alive[target_index]
			target.health -= damage
			result.target_name = target.name
			result.target_killed = not target.is_alive()
			result.logs.append("Hit %s for %d damage%s" % [target.name, damage, " (CRIT!)" if result.was_crit else ""])

			# --- Splitting on death ---
			if result.target_killed:
				_handle_split(target, result)

			# --- Spawn on HP threshold ---
			_handle_hp_spawns(result)

	# --- Status tick damage ---
	result.status_tick_damage = _tick_statuses()
	state.health -= result.status_tick_damage
	if result.status_tick_damage > 0:
		result.logs.append("Status effects deal %d damage" % result.status_tick_damage)

	# --- Enemy attacks ---
	var alive_after := get_alive_enemies()
	for enemy in alive_after:
		if enemy.turn_spawned == turn_count:
			continue  # just spawned, skip attack
		var enemy_dice: Array[int] = []
		for d in enemy.num_dice:
			enemy_dice.append(rng.rand_int(1, 6))
		var enemy_dmg: int = 0
		for d in enemy_dice:
			enemy_dmg += d

		# Enemy damage multiplier from status effects
		var enemy_mult := _get_status_modifier("enemy_damage_mult")
		if enemy_mult > 0.0:
			enemy_dmg = int(float(enemy_dmg) * enemy_mult)

		# Shield absorb
		if state.temp_shield > 0:
			var absorbed := mini(state.temp_shield, enemy_dmg)
			state.temp_shield -= absorbed
			enemy_dmg -= absorbed

		state.health -= enemy_dmg
		result.enemy_rolls.append({"name": enemy.name, "dice": enemy_dice, "damage": enemy_dmg})
		result.logs.append("%s rolls %s for %d damage" % [enemy.name, str(enemy_dice), enemy_dmg])

	# --- Periodic spawns ---
	_handle_periodic_spawns(result)

	# --- Inflict-status abilities ---
	_handle_inflict_status(result)

	result.player_hp_after = state.health

	# Reset dice for next turn
	var extra_rolls: int = state.reroll_bonus + _get_temp_int("extra_rolls") + int(_get_status_modifier("extra_rolls"))
	dice.reset_turn(extra_rolls)

	_logs.append_array(result.logs)
	return result


# ------------------------------------------------------------------
# Flee
# ------------------------------------------------------------------

func attempt_flee() -> bool:
	## 50% chance to flee. Returns true if successful.
	return rng.randf() < 0.5


# ------------------------------------------------------------------
# Full combat run (convenience for testing)
# ------------------------------------------------------------------

func run_auto_combat(lock_strategy: Callable = Callable()) -> CombatResult:
	## Run combat to completion. lock_strategy(dice: DiceRoller) is called
	## after each roll so the caller can lock dice.
	var result := CombatResult.new()

	while state.health > 0 and not get_alive_enemies().is_empty():
		dice.reset_turn(state.reroll_bonus + _get_temp_int("extra_rolls"))
		dice.roll()

		# Apply locking strategy
		if lock_strategy.is_valid():
			lock_strategy.call(dice)

		# Reroll unlocked dice
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
# Splitting / Spawning
# ------------------------------------------------------------------

func _handle_split(dead_enemy: Enemy, result: TurnResult) -> void:
	var td := dead_enemy.type_data
	if not td.get("splits_on_death", false):
		return
	var split_type: String = td.get("split_into_type", "")
	var split_count: int = int(td.get("split_count", 2))
	var hp_pct: float = float(td.get("split_hp_percent", 0.4))
	var dice_delta: int = int(td.get("split_dice", -1))
	if split_type.is_empty():
		return

	var child_hp := maxi(1, int(float(dead_enemy.max_health) * hp_pct))
	var child_dice := maxi(1, dead_enemy.num_dice + dice_delta)

	for i in split_count:
		var child := add_enemy(split_type, child_hp, child_dice)
		child.turn_spawned = turn_count
		result.split_into.append(split_type)
		result.logs.append("%s splits into %s (%d HP)" % [dead_enemy.name, split_type, child_hp])


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
				continue  # only once per threshold ability
			enemy.spawns_done += 1

			var spawn_type: String = ability.get("spawn_type", "Minion")
			var spawn_count: int = int(ability.get("spawn_count", 1))
			var hp_mult: float = float(ability.get("spawn_hp_mult", 0.3))
			var spawn_dice: int = int(ability.get("spawn_dice", 2))
			var child_hp := maxi(1, int(float(enemy.max_health) * hp_mult))

			for i in spawn_count:
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

			for i in spawn_count:
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
# Status effects
# ------------------------------------------------------------------

func _tick_statuses() -> int:
	## Process status ticks. Returns total tick damage dealt.
	var total_damage := 0
	var statuses: Array = state.flags.get("statuses", [])
	var to_remove: Array = []

	for status_name in statuses:
		var sdata: Dictionary = statuses_db.get(status_name, {})
		var tick_dmg: int = int(sdata.get("tick_damage", 0))

		# Poison null check
		if tick_dmg > 0 and sdata.get("poison_null", false):
			tick_dmg = 0

		total_damage += tick_dmg

		# Decrement turns
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
