class_name DurabilitySystem
extends RefCounted
## Pure-logic durability module. No UI, no Nodes.
##
## Python parity: explorer/combat.py, dice_dungeon_explorer.py
## - Weapon degrades by 3 on each player attack
## - Armor degrades by 5 on each hit taken
## - Items break at durability <= 0
## - Low durability warning at <= 20

const WEAPON_DEGRADE_AMOUNT := 3
const ARMOR_DEGRADE_AMOUNT := 5
const LOW_DURABILITY_THRESHOLD := 20
const DEFAULT_MAX_DURABILITY := 100


## Degrade the equipped weapon after the player attacks.
## Returns {degraded, broken, item_name, durability, warning}.
static func degrade_weapon(inv_engine: InventoryEngine, game_state: GameState) -> Dictionary:
	var weapon_name: String = game_state.equipped_items.get("weapon", "")
	if weapon_name.is_empty():
		return {"degraded": false}
	return _degrade_slot(inv_engine, game_state, weapon_name, WEAPON_DEGRADE_AMOUNT)


## Degrade the equipped armor after the player takes damage.
## Returns {degraded, broken, item_name, durability, warning}.
static func degrade_armor(inv_engine: InventoryEngine, game_state: GameState) -> Dictionary:
	var armor_name: String = game_state.equipped_items.get("armor", "")
	if armor_name.is_empty():
		return {"degraded": false}
	return _degrade_slot(inv_engine, game_state, armor_name, ARMOR_DEGRADE_AMOUNT)


static func _degrade_slot(inv_engine: InventoryEngine, game_state: GameState,
		item_name: String, amount: int) -> Dictionary:
	if not game_state.equipment_durability.has(item_name):
		return {"degraded": false}

	var result := inv_engine.degrade_durability(item_name, amount)
	var dur: int = int(result.get("durability", -1))
	var broken: bool = result.get("broken", false)
	var warning: bool = not broken and dur > 0 and dur <= LOW_DURABILITY_THRESHOLD

	return {
		"degraded": true,
		"broken": broken,
		"item_name": item_name,
		"durability": dur,
		"warning": warning,
		"broken_name": result.get("broken_name", ""),
	}
