class_name CombatGatingPolicy
extends RefCounted
## Centralized policy for what actions are blocked during combat.
##
## Python parity:
## - No saving during combat (dice_dungeon_explorer.py line 5167)
## - No fleeing from boss/mini-boss fights (combat.py line 285)
## - Flee during pending: 50% chance, no damage
## - Flee during combat: 50% chance, takes damage on success


## Whether the player can save the game right now.
static func can_save(game_state: GameState, combat: CombatEngine) -> bool:
	if game_state == null:
		return false
	if game_state.in_combat:
		return false
	if combat != null:
		return false
	return true


## Whether the player can flee from the current combat.
## Returns {allowed, reason}.
static func can_flee(combat: CombatEngine) -> Dictionary:
	if combat == null:
		return {"allowed": false, "reason": "no_combat"}
	for enemy in combat.get_alive_enemies():
		if enemy.is_boss or enemy.is_mini_boss:
			return {"allowed": false, "reason": "boss_fight"}
	return {"allowed": true, "reason": ""}


## Message to show when save is blocked.
static func save_blocked_message() -> String:
	return "Cannot save during combat!"


## Message to show when flee is blocked (boss fight).
static func flee_blocked_message() -> String:
	return "You cannot flee from a boss fight! Fight or die!"
