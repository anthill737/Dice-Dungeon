class_name MechanicsEngine
extends RefCounted
## Room-effects engine — direct port of Python mechanics_engine.py.
##
## Processes the "mechanics" field from rooms_v2.json entries.
## Each room can define effects for three phases:
##   on_enter  — applied when the player enters the room
##   on_clear  — applied when the player clears combat in the room
##   on_fail   — applied when the player fails/flees combat
##
## Supported effect keys (all optional):
##   heal           int    restore HP (capped at max_health)
##   gold_flat      int    grant gold
##   cleanse        bool   clear all status effects
##   disarm_token   bool   grant +1 disarm token
##   escape_token   bool   grant +1 escape token
##   item           String add item to ground_items
##   status         String apply a status effect
##   shield         int    grant temporary shield HP
##   extra_rolls    int    temp bonus rerolls
##   crit_bonus     float  temp crit chance bonus
##   damage_bonus   int    temp damage bonus
##   gold_mult      float  temp gold multiplier
##   shop_discount  float  temp shop discount
##   duration       String "combat" (default) or "floor"


## Log callback type: receives a single String message.
## If null, messages are silently discarded.
var _log_fn: Callable


func _init(log_fn: Callable = Callable()) -> void:
	_log_fn = log_fn


func _log(msg: String) -> void:
	if _log_fn.is_valid():
		_log_fn.call(msg)


# ------------------------------------------------------------------
# Public API — mirrors Python exactly
# ------------------------------------------------------------------

func apply_on_enter(state: GameState, room: Dictionary) -> void:
	var eff = _get_phase(room, "on_enter")
	_apply_bundle(state, eff)


func apply_on_clear(state: GameState, room: Dictionary) -> void:
	var eff = _get_phase(room, "on_clear")
	_apply_bundle(state, eff)


func apply_on_fail(state: GameState, room: Dictionary) -> void:
	var eff = _get_phase(room, "on_fail")
	_apply_bundle(state, eff)


func settle_temp_effects(state: GameState, phase: String) -> void:
	## Remove temp effects whose duration has expired.
	## phase: "after_combat" or "floor_transition"
	var to_delete: Array[String] = []
	for key in state.temp_effects:
		var data: Dictionary = state.temp_effects[key]
		var dur: String = data.get("duration", "combat")
		var expire := false
		if phase == "after_combat" and dur == "combat":
			expire = true
		elif phase == "floor_transition" and (dur == "combat" or dur == "floor"):
			expire = true
		if expire:
			to_delete.append(key)

	for k in to_delete:
		state.temp_effects.erase(k)

	if phase == "floor_transition":
		state.temp_shield = 0
		state.shop_discount = 0.0


func get_effective_stats(state: GameState) -> Dictionary:
	## Return a snapshot of all temporary modifiers currently active.
	var te := state.temp_effects
	return {
		"crit_bonus": float(_get_delta(te, "crit_bonus")),
		"damage_bonus": int(_get_delta(te, "damage_bonus")),
		"gold_mult": float(_get_delta(te, "gold_mult")),
		"extra_rolls": int(_get_delta(te, "extra_rolls")),
		"shop_discount": float(_get_delta(te, "shop_discount")),
		"temp_shield": state.temp_shield,
		"statuses": state.flags.get("statuses", []).duplicate(),
		"has_disarm": int(state.flags.get("disarm_token", 0)) > 0,
		"has_escape": int(state.flags.get("escape_token", 0)) > 0,
	}


func apply_effective_modifiers(state: GameState) -> Dictionary:
	## Compute and return final effective stats (base + temp).
	var eff := get_effective_stats(state)
	return {
		"crit": state.crit_chance + float(eff["crit_bonus"]),
		"damage_bonus": state.damage_bonus + int(eff["damage_bonus"]),
		"gold_mult": state.multiplier * (1.0 + float(eff["gold_mult"])),
		"temp_shield": eff["temp_shield"],
		"shop_discount": eff["shop_discount"],
		"has_disarm": eff["has_disarm"],
		"has_escape": eff["has_escape"],
		"statuses": eff["statuses"],
	}


# ------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------

static func _get_phase(room: Dictionary, phase: String) -> Dictionary:
	var mech = room.get("mechanics")
	if mech == null or not mech is Dictionary:
		return {}
	var eff = mech.get(phase)
	if eff == null or not eff is Dictionary:
		return {}
	return eff


func _apply_bundle(state: GameState, eff: Dictionary) -> void:
	if eff.is_empty():
		return

	var dur: String = eff.get("duration", "combat")

	# Heal (Python removed from apply, but data still has it — keep parity)
	# Note: Python commented this out. We also skip it for exact parity.
	# var heal_val := int(eff.get("heal", 0))
	# ...

	# Cleanse
	if eff.get("cleanse", false):
		state.flags["statuses"] = []
		_log("Cleansed all negative statuses")

	# Tokens
	if eff.get("disarm_token", false):
		state.flags["disarm_token"] = int(state.flags.get("disarm_token", 0)) + 1
		_log("Gained a disarm token")

	if eff.get("escape_token", false):
		state.flags["escape_token"] = int(state.flags.get("escape_token", 0)) + 1
		_log("Gained an escape token")

	# Item — add to ground_items (mirrors Python)
	var item_name = eff.get("item")
	if item_name != null and item_name is String and item_name.length() > 0:
		state.ground_items.append(item_name)
		_log("Found item: %s (on ground)" % item_name)

	# Status effect
	var status_name = eff.get("status")
	if status_name != null and status_name is String and status_name.length() > 0:
		var statuses: Array = state.flags.get("statuses", [])
		if not statuses.has(status_name):
			statuses.append(status_name)
			state.flags["statuses"] = statuses
			_log("Status applied: %s" % status_name)

	# Shield
	var shield_val := int(eff.get("shield", 0))
	if shield_val > 0:
		state.temp_shield += shield_val
		_log("+%d Shield" % shield_val)

	# Temp effects
	_add_temp(state, "extra_rolls", int(eff.get("extra_rolls", 0)), dur)
	_add_temp(state, "crit_bonus", float(eff.get("crit_bonus", 0.0)), dur)
	_add_temp(state, "damage_bonus", int(eff.get("damage_bonus", 0)), dur)
	_add_temp(state, "gold_mult", float(eff.get("gold_mult", 0.0)), dur)
	_add_temp(state, "shop_discount", float(eff.get("shop_discount", 0.0)), dur)


static func _add_temp(state: GameState, key: String, delta, duration: String) -> void:
	if delta == 0 or delta == 0.0:
		return
	var existing: Dictionary = state.temp_effects.get(key, {"delta": 0, "duration": duration})
	if existing["delta"] is float or delta is float:
		existing["delta"] = float(existing["delta"]) + float(delta)
	else:
		existing["delta"] = int(existing["delta"]) + int(delta)
	existing["duration"] = duration
	state.temp_effects[key] = existing


static func _get_delta(te: Dictionary, key: String):
	var entry = te.get(key)
	if entry == null or not entry is Dictionary:
		return 0
	return entry.get("delta", 0)
