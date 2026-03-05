class_name EffectSystem
extends RefCounted
## Pure deterministic effect resolution — no UI, no Nodes.
##
## Handles: boss curse ticking, player status ticks, enemy burn ticks.
## Mirrors Python's _process_boss_curses, process_status_effects,
## _apply_burn_damage exactly.

# ------------------------------------------------------------------
# Types
# ------------------------------------------------------------------

class CurseTickResult extends RefCounted:
	var curse_damage_total: int = 0
	var heals: Array = []             ## [{enemy_name, amount}]
	var expired: Array = []           ## [{type, message}]  expiry events
	var removed_indices: Array = []   ## curse indices to remove (reverse order)
	var player_died: bool = false
	var logs: Array = []


class StatusTickResult extends RefCounted:
	var damage: int = 0
	var logs: Array = []
	var player_died: bool = false


class BurnTickResult extends RefCounted:
	var ticks: Array = []       ## [{enemy_index, enemy_name, damage, turns_remaining}]
	var deaths: Array = []      ## [enemy_index]
	var expired: Array = []     ## [enemy_index]
	var logs: Array = []


# ------------------------------------------------------------------
# Boss curse processing — called at start of player turn
# ------------------------------------------------------------------

## Process all active curses. Returns CurseTickResult.
## `curses` is Array[Dictionary], `enemies` is Array of enemy objects/dicts.
static func tick_curses(curses: Array, enemies: Array, player_health: int) -> CurseTickResult:
	var result := CurseTickResult.new()
	var to_remove: Array = []

	for i in curses.size():
		var curse: Dictionary = curses[i]
		var ctype: String = curse.get("type", "")

		var target_name: String = curse.get("target_enemy_name", "")
		if not target_name.is_empty():
			var found := false
			for e in enemies:
				var ename: String = ""
				if e is CombatEngine.Enemy:
					ename = e.name
				elif e is Dictionary:
					ename = e.get("name", "")
				if ename == target_name and _is_alive(e):
					found = true
					break
			if not found:
				to_remove.append(i)
				continue

		match ctype:
			"curse_damage":
				var dmg: int = int(curse.get("damage", 3))
				result.curse_damage_total += dmg
				player_health -= dmg
				var msg: String = curse.get("message", "")
				result.logs.append("☠ Curse damage! You lose %d HP. (%s)" % [dmg, msg])
				if player_health <= 0:
					result.player_died = true

			"heal_over_time":
				var heal_amount: int = int(curse.get("heal_amount", 8))
				for e in enemies:
					var ename: String = ""
					if e is CombatEngine.Enemy:
						ename = e.name
					elif e is Dictionary:
						ename = e.get("name", "")
					if ename == target_name and _is_alive(e):
						var old_hp: int = _get_hp(e)
						var max_hp: int = _get_max_hp(e)
						var new_hp: int = mini(old_hp + heal_amount, max_hp)
						var actual: int = new_hp - old_hp
						if actual > 0:
							result.heals.append({"enemy_name": ename, "amount": actual})
							result.logs.append("💚 %s regenerates %d HP!" % [ename, actual])
						break

		curse["turns_left"] = int(curse.get("turns_left", 1)) - 1
		if curse["turns_left"] <= 0:
			to_remove.append(i)
			var expiry_msg := _curse_expiry_message(ctype)
			if not expiry_msg.is_empty():
				result.expired.append({"type": ctype, "message": expiry_msg})
				result.logs.append(expiry_msg)

	to_remove.sort()
	to_remove.reverse()
	result.removed_indices = to_remove
	return result


## Process player status effects — called during enemy turn.
## `statuses` is Array[String].
static func tick_statuses(statuses: Array) -> StatusTickResult:
	var result := StatusTickResult.new()
	for status_name in statuses:
		var lower: String = status_name.to_lower()
		if "poison" in lower or "rot" in lower:
			result.damage += 5
			result.logs.append("☠ [%s] You take 5 damage!" % status_name)
		elif "bleed" in lower:
			result.damage += 5
			result.logs.append("▪ [%s] You take 5 bleed damage!" % status_name)
		elif "burn" in lower or "heat" in lower:
			result.damage += 5
			result.logs.append("✹ [%s] You take 5 fire damage!" % status_name)
		elif "choke" in lower or "soot" in lower:
			result.logs.append("≋ [%s] Your attacks are weakened!" % status_name)
		elif "hunger" in lower:
			result.logs.append("◆ [%s] You feel weakened from hunger..." % status_name)
	return result


## Process enemy burn damage — called during enemy turn.
## `burn_status` is Dictionary[int → {initial_damage, turns_remaining}].
## `enemies` is Array of enemy objects.
static func tick_enemy_burns(burn_status: Dictionary, enemies: Array) -> BurnTickResult:
	var result := BurnTickResult.new()
	var to_remove: Array = []

	for key in burn_status:
		var i: int = int(key)
		if i >= enemies.size():
			continue
		var enemy = enemies[i]
		var burn: Dictionary = burn_status[key]
		var turns_remaining: int = int(burn.get("turns_remaining", 0))

		var damage: int = 0
		match turns_remaining:
			3: damage = 8
			2: damage = 5
			1: damage = 2
			_: damage = 0

		var ename: String = ""
		if enemy is CombatEngine.Enemy:
			ename = enemy.name
		elif enemy is Dictionary:
			ename = enemy.get("name", "")

		result.ticks.append({
			"enemy_index": i,
			"enemy_name": ename,
			"damage": damage,
			"turns_remaining": turns_remaining,
		})
		result.logs.append("🔥 %s takes %d burn damage! (%d turns remaining)" % [ename, damage, turns_remaining])

		burn["turns_remaining"] = turns_remaining - 1
		if burn["turns_remaining"] <= 0:
			to_remove.append(i)
			result.expired.append(i)
			result.logs.append("🔥 %s's burn fades away." % ename)

		var hp: int = _get_hp(enemy) - damage
		if hp <= 0:
			result.deaths.append(i)
			result.logs.append("💀 %s burned to death!" % ename)

	for idx in to_remove:
		burn_status.erase(idx)

	return result


# ------------------------------------------------------------------
# Curse expiry messages — exact Python parity
# ------------------------------------------------------------------

static func _curse_expiry_message(ctype: String) -> String:
	match ctype:
		"dice_obscure":
			return "Your vision clears! Dice values are visible again."
		"dice_restrict":
			return "The curse fades! Your dice roll normally again."
		"dice_lock_random":
			return "The binding breaks! Your dice are unlocked."
		"curse_reroll":
			return "The curse fades! You can reroll normally again."
		"heal_over_time":
			return "The enemy's regeneration ends."
		"damage_reduction":
			return "The enemy's defenses fade!"
	return ""


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

static func _is_alive(e) -> bool:
	if e is CombatEngine.Enemy:
		return e.is_alive()
	elif e is Dictionary:
		return int(e.get("health", 0)) > 0
	return false


static func _get_hp(e) -> int:
	if e is CombatEngine.Enemy:
		return e.health
	elif e is Dictionary:
		return int(e.get("health", 0))
	return 0


static func _get_max_hp(e) -> int:
	if e is CombatEngine.Enemy:
		return e.max_health
	elif e is Dictionary:
		return int(e.get("max_health", 0))
	return 0
