class_name InventoryEngine
extends RefCounted
## Headless inventory, equipment, item usage, and store engine.
##
## Faithful port of Python:
##   explorer/inventory_equipment.py
##   explorer/inventory_usage.py
##   explorer/inventory_pickup.py
##   explorer/store.py
##
## NO UI. All operations mutate GameState and return result dicts.

var rng: RNG
var state: GameState
var items_db: Dictionary = {}
var logs: Array[String] = []


func _init(p_rng: RNG, p_state: GameState, p_items_db: Dictionary = {}) -> void:
	rng = p_rng if p_rng != null else DefaultRNG.new()
	state = p_state
	items_db = p_items_db


# ------------------------------------------------------------------
# Inventory helpers
# ------------------------------------------------------------------

func get_item_def(item_name: String) -> Dictionary:
	var base := item_name.split(" #")[0] if " #" in item_name else item_name
	return items_db.get(base, {})


func can_add_item() -> bool:
	return state.inventory.size() < state.max_inventory


func add_item_to_inventory(item_name: String, source: String = "found") -> bool:
	if not can_add_item():
		logs.append("Inventory full! Cannot add %s." % item_name)
		return false
	state.inventory.append(item_name)
	_track_item_acquisition(item_name, source)
	var item_def := get_item_def(item_name)
	if item_def.get("type", "") == "equipment":
		state.equipment_floor_level[item_name] = state.floor
	return true


func _track_item_acquisition(item_name: String, source: String) -> void:
	if source in ["found", "reward", "chest", "ground"]:
		state.stats["items_found"] = int(state.stats.get("items_found", 0)) + 1


func remove_item_at(idx: int) -> String:
	if idx < 0 or idx >= state.inventory.size():
		return ""
	return state.inventory.pop_at(idx)


# ------------------------------------------------------------------
# Equipment — mirrors Python inventory_equipment.py
# ------------------------------------------------------------------

func equip_item(item_name: String, slot: String) -> Dictionary:
	if not state.inventory.has(item_name):
		logs.append("Item %s not in inventory." % item_name)
		return {"ok": false, "reason": "not_in_inventory"}

	if not state.equipped_items.has(slot):
		logs.append("Invalid slot: %s" % slot)
		return {"ok": false, "reason": "invalid_slot"}

	var item_def := get_item_def(item_name)
	var item_slot: String = item_def.get("slot", "")
	if item_slot != slot:
		logs.append("%s cannot go in %s slot." % [item_name, slot])
		return {"ok": false, "reason": "wrong_slot"}

	for existing_slot in state.equipped_items:
		if state.equipped_items[existing_slot] == item_name:
			logs.append("%s is already equipped in %s." % [item_name, existing_slot])
			return {"ok": false, "reason": "already_equipped"}

	var old_item: String = state.equipped_items[slot]
	if not old_item.is_empty():
		_remove_equipment_bonuses(old_item)
		logs.append("Unequipped %s" % old_item)

	state.equipped_items[slot] = item_name

	if not state.equipment_durability.has(item_name):
		var max_dur: int = int(item_def.get("max_durability", 100))
		state.equipment_durability[item_name] = max_dur

	_apply_equipment_bonuses(item_name)
	logs.append("Equipped %s to %s slot." % [item_name, slot])
	return {"ok": true, "unequipped": old_item}


func unequip_item(slot: String) -> Dictionary:
	if not state.equipped_items.has(slot):
		logs.append("Invalid slot: %s" % slot)
		return {"ok": false, "reason": "invalid_slot"}

	var item_name: String = state.equipped_items[slot]
	if item_name.is_empty():
		logs.append("No item in %s slot." % slot)
		return {"ok": false, "reason": "empty_slot"}

	if not state.inventory.has(item_name):
		state.equipped_items[slot] = ""
		return {"ok": false, "reason": "not_in_inventory"}

	_remove_equipment_bonuses(item_name)
	state.equipped_items[slot] = ""
	logs.append("Unequipped %s from %s." % [item_name, slot])
	return {"ok": true}


func _apply_equipment_bonuses(item_name: String, skip_hp: bool = false) -> void:
	var item_def := get_item_def(item_name)
	if item_def.is_empty():
		return

	var floor_level: int = int(state.equipment_floor_level.get(item_name, state.floor))
	var floor_bonus: int = maxi(0, floor_level - 1)

	if item_def.has("damage_bonus"):
		var base_dmg: int = int(item_def["damage_bonus"])
		var scaled_dmg: int = base_dmg + floor_bonus
		state.damage_bonus += scaled_dmg

	if item_def.has("crit_bonus"):
		state.crit_chance += float(item_def["crit_bonus"])

	if item_def.has("reroll_bonus") and not item_def.has("combat_ability"):
		state.reroll_bonus += int(item_def["reroll_bonus"])

	if item_def.has("max_hp_bonus") and not skip_hp:
		var base_hp: int = int(item_def["max_hp_bonus"])
		var scaled_hp: int = base_hp + (floor_bonus * 3)
		state.max_health += scaled_hp
		state.health += scaled_hp

	if item_def.has("armor_bonus"):
		state.armor += int(item_def["armor_bonus"])

	if item_def.has("inventory_bonus"):
		state.max_inventory += int(item_def["inventory_bonus"])

	if not state.equipment_durability.has(item_name):
		var max_dur: int = int(item_def.get("max_durability", 100))
		state.equipment_durability[item_name] = max_dur


func _remove_equipment_bonuses(item_name: String) -> void:
	var item_def := get_item_def(item_name)
	if item_def.is_empty():
		return

	var floor_level: int = int(state.equipment_floor_level.get(item_name, state.floor))
	var floor_bonus: int = maxi(0, floor_level - 1)

	if item_def.has("damage_bonus"):
		var base_dmg: int = int(item_def["damage_bonus"])
		var scaled_dmg: int = base_dmg + floor_bonus
		state.damage_bonus -= scaled_dmg

	if item_def.has("crit_bonus"):
		state.crit_chance -= float(item_def["crit_bonus"])

	if item_def.has("reroll_bonus") and not item_def.has("combat_ability"):
		state.reroll_bonus -= int(item_def["reroll_bonus"])

	if item_def.has("max_hp_bonus"):
		var base_hp: int = int(item_def["max_hp_bonus"])
		var scaled_hp: int = base_hp + (floor_bonus * 3)
		state.max_health -= scaled_hp
		state.health = maxi(1, state.health - scaled_hp)
		state.health = mini(state.health, state.max_health)

	if item_def.has("armor_bonus"):
		state.armor -= int(item_def["armor_bonus"])

	if item_def.has("inventory_bonus"):
		state.max_inventory -= int(item_def["inventory_bonus"])


## Degrade durability for a specific equipped item.
## Returns the new durability value. If reaches 0, item breaks.
func degrade_durability(item_name: String, amount: int = 1) -> Dictionary:
	if not state.equipment_durability.has(item_name):
		return {"durability": -1, "broken": false}

	state.equipment_durability[item_name] = maxi(0, int(state.equipment_durability[item_name]) - amount)
	var current: int = int(state.equipment_durability[item_name])

	if current <= 0:
		return _break_equipment(item_name)

	return {"durability": current, "broken": false}


func _break_equipment(item_name: String) -> Dictionary:
	var slot_found := ""
	for slot in state.equipped_items:
		if state.equipped_items[slot] == item_name:
			slot_found = slot
			break

	if not slot_found.is_empty():
		_remove_equipment_bonuses(item_name)
		state.equipped_items[slot_found] = ""

	var idx := state.inventory.find(item_name)
	if idx >= 0:
		state.inventory[idx] = "Broken " + item_name

	state.equipment_durability.erase(item_name)

	var item_def := get_item_def(item_name)
	var broken_name := "Broken " + item_name
	if not items_db.has(broken_name):
		items_db[broken_name] = {
			"type": "broken_equipment",
			"original_item": item_name,
			"slot": item_def.get("slot", "weapon"),
			"sell_value": maxi(1, int(item_def.get("sell_value", 5)) / 2),
			"desc": "A broken %s. Can be repaired or sold for scrap." % item_name,
		}

	logs.append("%s has broken!" % item_name)
	return {"durability": 0, "broken": true, "broken_name": broken_name}


func get_durability_percent(item_name: String) -> int:
	if not state.equipment_durability.has(item_name):
		return 100
	var item_def := get_item_def(item_name)
	var max_dur: int = int(item_def.get("max_durability", 100))
	if max_dur <= 0:
		return 100
	return int((float(state.equipment_durability[item_name]) / float(max_dur)) * 100.0)


## Check if an equipped item is broken (0% durability). Python treats broken
## items as providing NO bonuses — they are auto-unequipped on break.
func is_equipment_broken(item_name: String) -> bool:
	return state.equipment_durability.has(item_name) and int(state.equipment_durability[item_name]) <= 0


# ------------------------------------------------------------------
# Repair — mirrors Python inventory_usage.py repair logic
# ------------------------------------------------------------------

func repair_item(repair_kit_name: String, repair_kit_idx: int, target_name: String) -> Dictionary:
	var kit_def := get_item_def(repair_kit_name)
	if kit_def.get("type", "") != "repair":
		return {"ok": false, "reason": "not_repair_kit"}

	var repair_type: String = kit_def.get("repair_type", "any")
	var repair_percent: float = float(kit_def.get("repair_percent", 0.40))

	if target_name.begins_with("Broken "):
		return _repair_broken(repair_kit_idx, target_name, repair_type, repair_percent)
	else:
		return _repair_durability(repair_kit_idx, target_name, repair_type, repair_percent)


func _repair_broken(kit_idx: int, broken_name: String, repair_type: String, repair_pct: float) -> Dictionary:
	var broken_def: Dictionary = items_db.get(broken_name, {})
	if broken_def.get("type", "") != "broken_equipment":
		return {"ok": false, "reason": "not_broken_equipment"}

	var original: String = broken_def.get("original_item", "")
	var slot: String = broken_def.get("slot", "")

	if repair_type != "any" and repair_type != slot:
		return {"ok": false, "reason": "wrong_repair_type"}

	var original_def := get_item_def(original)
	var max_dur: int = int(original_def.get("max_durability", 100))
	var restored_dur: int = int(max_dur * repair_pct)

	var broken_idx := state.inventory.find(broken_name)
	if broken_idx < 0:
		return {"ok": false, "reason": "item_not_found"}

	state.inventory[broken_idx] = original
	state.equipment_durability[original] = restored_dur
	state.equipment_floor_level[original] = state.floor

	remove_item_at(kit_idx if kit_idx < broken_idx else kit_idx)
	if kit_idx > broken_idx:
		pass  # broken_idx still valid
	else:
		pass  # kit was before broken item, broken_idx shifted

	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Repaired %s! Restored to %s (%d durability)" % [broken_name, original, restored_dur])
	return {"ok": true, "restored_item": original, "durability": restored_dur}


func _repair_durability(kit_idx: int, item_name: String, repair_type: String, repair_pct: float) -> Dictionary:
	var item_def := get_item_def(item_name)
	var item_slot: String = item_def.get("slot", "")
	if repair_type != "any" and repair_type != item_slot:
		return {"ok": false, "reason": "wrong_repair_type"}

	if not state.equipment_durability.has(item_name):
		return {"ok": false, "reason": "no_durability_tracked"}

	var max_dur: int = int(item_def.get("max_durability", 100))
	var current_dur: int = int(state.equipment_durability[item_name])
	if current_dur >= max_dur:
		return {"ok": false, "reason": "already_full"}

	var repair_amount: int = int(max_dur * repair_pct)
	var new_dur: int = mini(current_dur + repair_amount, max_dur)
	var actual_repair: int = new_dur - current_dur

	state.equipment_durability[item_name] = new_dur
	remove_item_at(kit_idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Repaired %s: %d → %d (+%d)" % [item_name, current_dur, new_dur, actual_repair])
	return {"ok": true, "old_dur": current_dur, "new_dur": new_dur, "repaired": actual_repair}


# ------------------------------------------------------------------
# Item usage — mirrors Python inventory_usage.py
# ------------------------------------------------------------------

func use_item(idx: int) -> Dictionary:
	if idx < 0 or idx >= state.inventory.size():
		return {"ok": false, "reason": "invalid_index"}

	var item_name: String = state.inventory[idx]
	var item_def := get_item_def(item_name)
	var item_type: String = item_def.get("type", "unknown")

	match item_type:
		"heal":
			return _use_heal(idx, item_name, item_def)
		"buff":
			return _use_buff(idx, item_name, item_def)
		"shield":
			return _use_shield(idx, item_name, item_def)
		"cleanse":
			return _use_cleanse(idx, item_name, item_def)
		"combat_consumable":
			return _use_combat_consumable(idx, item_name, item_def)
		"quest_item":
			logs.append("%s can be turned in at a store." % item_name)
			return {"ok": false, "reason": "quest_item_sell_only"}
		"consumable":
			return _use_consumable(idx, item_name, item_def)
		"consumable_blessing":
			return _use_blessing(idx, item_name, item_def)
		"token":
			return _use_token(idx, item_name, item_def)
		"tool":
			return _use_tool(idx, item_name, item_def)
		"repair":
			logs.append("%s requires a target. Use repair_item() instead." % item_name)
			return {"ok": false, "reason": "needs_target"}
		"upgrade":
			return _use_upgrade(idx, item_name, item_def)
		"throwable":
			return _use_throwable(idx, item_name, item_def)
		"broken_equipment":
			logs.append("%s is broken. Use a Repair Kit." % item_name)
			return {"ok": false, "reason": "broken"}
		"equipment":
			logs.append("%s is equipment. Equip it instead." % item_name)
			return {"ok": false, "reason": "equipment"}
		_:
			logs.append("Cannot use %s." % item_name)
			return {"ok": false, "reason": "unusable"}


func _use_heal(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	var heal_amount: int = int(item_def.get("heal", 0))
	var old_hp: int = state.health
	state.health = mini(state.health + heal_amount, state.max_health)
	var actual_heal: int = state.health - old_hp
	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	state.stats["potions_used"] = int(state.stats.get("potions_used", 0)) + 1
	logs.append("Used %s! Restored %d health." % [item_name, actual_heal])
	return {"ok": true, "type": "heal", "healed": actual_heal, "hp": state.health}


func _use_buff(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	if not state.in_combat:
		logs.append("Can only use %s during combat!" % item_name)
		return {"ok": false, "reason": "not_in_combat"}

	var result := {"ok": true, "type": "buff"}
	if item_def.has("damage_bonus"):
		var bonus: int = int(item_def["damage_bonus"])
		state.damage_bonus += bonus
		state.temp_combat_damage += bonus
		result["damage_bonus"] = bonus
	if item_def.has("crit_bonus"):
		var bonus: float = float(item_def["crit_bonus"])
		state.crit_chance += bonus
		state.temp_combat_crit += bonus
		result["crit_bonus"] = bonus
	if item_def.has("extra_rolls"):
		var bonus: int = int(item_def["extra_rolls"])
		state.reroll_bonus += bonus
		state.temp_combat_rerolls += bonus
		result["extra_rolls"] = bonus

	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Used %s!" % item_name)
	return result


func _use_shield(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	if not state.in_combat:
		logs.append("Can only use %s during combat!" % item_name)
		return {"ok": false, "reason": "not_in_combat"}

	var shield_amount: int = int(item_def.get("shield", 0))
	state.temp_shield += shield_amount
	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Used %s! Gained %d shield." % [item_name, shield_amount])
	return {"ok": true, "type": "shield", "shield": shield_amount}


func _use_cleanse(idx: int, item_name: String, _item_def: Dictionary) -> Dictionary:
	var statuses: Array = state.flags.get("statuses", [])
	if statuses.is_empty():
		logs.append("No negative effects to cleanse!")
		return {"ok": false, "reason": "no_statuses"}

	state.flags["statuses"] = []
	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Used %s! All negative effects removed." % item_name)
	return {"ok": true, "type": "cleanse"}


func _use_combat_consumable(idx: int, item_name: String, _item_def: Dictionary) -> Dictionary:
	if not state.in_combat:
		logs.append("Can only use %s during combat!" % item_name)
		return {"ok": false, "reason": "not_in_combat"}

	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Used combat consumable %s!" % item_name)
	return {"ok": true, "type": "combat_consumable", "item": item_name}


func _use_consumable(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	var effect_type: String = item_def.get("effect_type", "unknown")
	if effect_type == "heal":
		var heal_amount: int = int(item_def.get("effect_value", 20))
		var old_hp: int = state.health
		state.health = mini(state.health + heal_amount, state.max_health)
		var actual_heal: int = state.health - old_hp
		state.inventory.pop_at(idx)
		state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
		logs.append("Used %s! Restored %d health." % [item_name, actual_heal])
		return {"ok": true, "type": "consumable_heal", "healed": actual_heal}
	elif effect_type == "light":
		state.flags["has_light"] = true
		state.flags["light_duration"] = int(state.flags.get("light_duration", 0)) + 3
		state.inventory.pop_at(idx)
		state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
		logs.append("Used %s! Light for 3 rooms." % item_name)
		return {"ok": true, "type": "consumable_light"}
	else:
		logs.append("Unknown consumable effect for %s." % item_name)
		return {"ok": false, "reason": "unknown_effect"}


func _use_blessing(idx: int, item_name: String, _item_def: Dictionary) -> Dictionary:
	var blessing_type: String = rng.choice(["heal", "crit", "gold"])
	var result := {"ok": true, "type": "blessing", "blessing": blessing_type}

	if blessing_type == "heal":
		var heal_amount := 15
		var old_hp: int = state.health
		state.health = mini(state.health + heal_amount, state.max_health)
		result["healed"] = state.health - old_hp
	elif blessing_type == "crit":
		state.flags["prayer_blessing_combats"] = int(state.flags.get("prayer_blessing_combats", 0)) + 3
		state.crit_chance += 0.05
		result["crit_bonus"] = 0.05
	else:
		var gold_amount: int = rng.rand_int(5, 10)
		state.gold += gold_amount
		state.stats["gold_found"] = int(state.stats.get("gold_found", 0)) + gold_amount
		result["gold"] = gold_amount

	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Used %s! Blessing: %s" % [item_name, blessing_type])
	return result


func _use_token(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	if item_def.get("escape_token", false):
		state.flags["escape_token"] = int(state.flags.get("escape_token", 0)) + 1
		state.inventory.pop_at(idx)
		state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
		logs.append("Activated %s! Escape token gained." % item_name)
		return {"ok": true, "type": "escape_token"}
	elif item_def.get("disarm_token", false):
		state.flags["disarm_token"] = int(state.flags.get("disarm_token", 0)) + 1
		state.inventory.pop_at(idx)
		state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
		logs.append("Activated %s! Disarm token gained." % item_name)
		return {"ok": true, "type": "disarm_token"}
	return {"ok": false, "reason": "unknown_token"}


func _use_tool(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	if item_def.get("disarm_token", false):
		state.flags["disarm_token"] = int(state.flags.get("disarm_token", 0)) + 1
		state.inventory.pop_at(idx)
		state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
		logs.append("Used %s! Disarm token gained." % item_name)
		return {"ok": true, "type": "tool_disarm"}
	logs.append("%s is a narrative tool." % item_name)
	return {"ok": false, "reason": "narrative_tool"}


func _use_upgrade(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	var applied := false
	var result := {"ok": true, "type": "upgrade"}

	if item_def.has("max_hp_bonus"):
		var bonus: int = int(item_def["max_hp_bonus"])
		state.max_health += bonus
		state.health += bonus
		result["max_hp_bonus"] = bonus
		applied = true

	if item_def.has("damage_bonus"):
		var bonus: int = int(item_def["damage_bonus"])
		state.damage_bonus += bonus
		result["damage_bonus"] = bonus
		applied = true

	if item_def.has("reroll_bonus"):
		var bonus: int = int(item_def["reroll_bonus"])
		state.reroll_bonus += bonus
		result["reroll_bonus"] = bonus
		applied = true

	if item_def.has("crit_bonus"):
		var bonus: float = float(item_def["crit_bonus"])
		state.crit_chance += bonus
		result["crit_bonus"] = bonus
		applied = true

	if applied:
		state.inventory.pop_at(idx)
		state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
		logs.append("Used %s! Permanent upgrade applied." % item_name)
	else:
		result = {"ok": false, "reason": "unknown_upgrade"}

	return result


func _use_throwable(idx: int, item_name: String, item_def: Dictionary) -> Dictionary:
	if not state.in_combat:
		logs.append("Can only use %s during combat!" % item_name)
		return {"ok": false, "reason": "not_in_combat"}

	var damage: int = int(item_def.get("damage", 5))
	state.inventory.pop_at(idx)
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Threw %s for %d damage!" % [item_name, damage])
	return {"ok": true, "type": "throwable", "damage": damage}


# ------------------------------------------------------------------
# Lockpick — mirrors Python inventory_pickup.py
# ------------------------------------------------------------------

func use_lockpick_on_container(room: RoomState) -> Dictionary:
	if not state.inventory.has("Lockpick Kit"):
		logs.append("No Lockpick Kit!")
		return {"ok": false, "reason": "no_lockpick"}

	state.inventory.erase("Lockpick Kit")
	room.container_locked = false
	state.stats["items_used"] = int(state.stats.get("items_used", 0)) + 1
	logs.append("Used Lockpick Kit! Container unlocked.")
	return {"ok": true}


# ------------------------------------------------------------------
# Effective stats — base + equipment + active statuses
# ------------------------------------------------------------------

func get_effective_stats() -> Dictionary:
	return {
		"health": state.health,
		"max_health": state.max_health,
		"damage_bonus": state.damage_bonus,
		"crit_chance": state.crit_chance,
		"reroll_bonus": state.reroll_bonus,
		"armor": state.armor,
		"temp_shield": state.temp_shield,
		"max_inventory": state.max_inventory,
		"gold": state.gold,
		"statuses": (state.flags.get("statuses", []) as Array).duplicate(),
	}


## Clear combat-only temp buffs (mirrors Python end-of-combat cleanup).
func clear_combat_temps() -> void:
	state.damage_bonus -= state.temp_combat_damage
	state.crit_chance -= state.temp_combat_crit
	state.reroll_bonus -= state.temp_combat_rerolls
	state.temp_combat_damage = 0
	state.temp_combat_crit = 0.0
	state.temp_combat_rerolls = 0
	state.temp_shield = 0
	state.in_combat = false
