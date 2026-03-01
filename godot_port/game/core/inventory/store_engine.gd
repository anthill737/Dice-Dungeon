class_name StoreEngine
extends RefCounted
## Headless store transaction engine — no UI.
##
## Faithful port of Python explorer/store.py.
## Handles buy, sell, permanent upgrades, and once-per-floor rules.

var state: GameState
var items_db: Dictionary = {}
var logs: Array[String] = []


func _init(p_state: GameState, p_items_db: Dictionary = {}) -> void:
	state = p_state
	items_db = p_items_db


# ------------------------------------------------------------------
# Store inventory generation — mirrors Python _generate_store_inventory()
# ------------------------------------------------------------------

func generate_store_inventory() -> Array:
	var store_items: Array = []
	var effective_floor: int = maxi(1, state.floor)

	store_items.append(["Health Potion", 30 + (effective_floor * 5)])

	store_items.append(["Weapon Repair Kit", 60 + (effective_floor * 15)])
	store_items.append(["Armor Repair Kit", 60 + (effective_floor * 15)])

	if effective_floor >= 5:
		store_items.append(["Master Repair Kit", 120 + (effective_floor * 30)])

	var upgrades: Array = [
		["Max HP Upgrade", 400 + (effective_floor * 100)],
		["Damage Upgrade", 500 + (effective_floor * 120)],
		["Fortune Upgrade", 450 + (effective_floor * 110)],
	]
	if effective_floor >= 2:
		upgrades.append(["Critical Upgrade", 200 + (effective_floor * 50)])

	for u in upgrades:
		if not state.purchased_upgrades_this_floor.has(u[0]):
			store_items.append(u)

	if effective_floor >= 1:
		store_items.append(["Lucky Chip", 70 + (effective_floor * 15)])
		store_items.append(["Honey Jar", 20 + (effective_floor * 4)])
		store_items.append(["Healing Poultice", 50 + (effective_floor * 10)])

	if effective_floor >= 2:
		store_items.append(["Weighted Die", 60 + (effective_floor * 15)])
		store_items.append(["Lockpick Kit", 50 + (effective_floor * 10)])
		store_items.append(["Conductor Rod", 70 + (effective_floor * 15)])

	if effective_floor >= 3:
		store_items.append(["Hourglass Shard", 80 + (effective_floor * 20)])
		store_items.append(["Tuner's Hammer", 85 + (effective_floor * 22)])
		store_items.append(["Antivenom Leaf", 40 + (effective_floor * 10)])

	if effective_floor >= 4:
		store_items.append(["Cooled Ember", 90 + (effective_floor * 23)])
		store_items.append(["Smoke Pot", 55 + (effective_floor * 12)])
		store_items.append(["Black Candle", 65 + (effective_floor * 15)])

	if effective_floor >= 1:
		store_items.append(["Iron Sword", 120 + (effective_floor * 30)])
		store_items.append(["Steel Dagger", 100 + (effective_floor * 25)])

	if effective_floor >= 2:
		store_items.append(["War Axe", 220 + (effective_floor * 50)])
		store_items.append(["Rapier", 160 + (effective_floor * 35)])

	if effective_floor >= 4:
		store_items.append(["Greatsword", 280 + (effective_floor * 60)])
		store_items.append(["Assassin's Blade", 260 + (effective_floor * 55)])

	if effective_floor >= 1:
		store_items.append(["Leather Armor", 110 + (effective_floor * 28)])
		store_items.append(["Chain Vest", 130 + (effective_floor * 32)])

	if effective_floor >= 3:
		store_items.append(["Plate Armor", 220 + (effective_floor * 50)])
		store_items.append(["Dragon Scale", 300 + (effective_floor * 65)])

	if effective_floor >= 1:
		store_items.append(["Traveler's Pack", 100 + (effective_floor * 25)])

	if effective_floor >= 2:
		store_items.append(["Lucky Coin", 140 + (effective_floor * 35)])
		store_items.append(["Mystic Ring", 150 + (effective_floor * 38)])
		store_items.append(["Merchant's Satchel", 180 + (effective_floor * 40)])
		store_items.append(["Extra Die", 500 + (effective_floor * 50)])

	if effective_floor >= 4:
		store_items.append(["Crown of Fortune", 250 + (effective_floor * 55)])
		store_items.append(["Timekeeper's Watch", 270 + (effective_floor * 58)])

	if effective_floor >= 3:
		store_items.append(["Blue Quartz", 90 + (effective_floor * 20)])
		store_items.append(["Silk Bundle", 120 + (effective_floor * 30)])

	return store_items


# ------------------------------------------------------------------
# Buy — mirrors Python _buy_item()
# ------------------------------------------------------------------

func buy_item(item_name: String, price: int, quantity: int = 1) -> Dictionary:
	var total_cost: int = price * quantity

	if state.gold < total_cost:
		logs.append("Not enough gold!")
		return {"ok": false, "reason": "insufficient_gold"}

	var item_def: Dictionary = items_db.get(item_name, {})
	var item_type: String = item_def.get("type", "")

	if item_name == "Extra Die":
		return _buy_extra_die(price)

	if item_type == "upgrade":
		return _buy_upgrade(item_name, price, item_def)

	if item_type == "equipment":
		return _buy_equipment(item_name, price, item_def)

	return _buy_consumable(item_name, price, quantity, item_def)


func _buy_extra_die(price: int) -> Dictionary:
	if state.num_dice >= state.max_dice:
		logs.append("Already at max dice!")
		return {"ok": false, "reason": "max_dice"}

	state.num_dice += 1
	state.purchased_upgrades_this_floor["Extra Die"] = true
	state.gold -= price
	state.stats["gold_spent"] = int(state.stats.get("gold_spent", 0)) + price
	state.stats["items_purchased"] = int(state.stats.get("items_purchased", 0)) + 1
	logs.append("Purchased Extra Die! Now have %d dice." % state.num_dice)
	return {"ok": true, "type": "extra_die", "num_dice": state.num_dice}


func _buy_upgrade(item_name: String, price: int, item_def: Dictionary) -> Dictionary:
	var result := {"ok": true, "type": "upgrade"}

	if item_def.has("max_hp_bonus"):
		var bonus: int = int(item_def["max_hp_bonus"])
		state.max_health += bonus
		state.health += bonus
		result["max_hp_bonus"] = bonus

	if item_def.has("damage_bonus"):
		var bonus: int = int(item_def["damage_bonus"])
		state.damage_bonus += bonus
		result["damage_bonus"] = bonus

	if item_def.has("reroll_bonus"):
		var bonus: int = int(item_def["reroll_bonus"])
		state.reroll_bonus += bonus
		result["reroll_bonus"] = bonus

	if item_def.has("crit_bonus"):
		var bonus: float = float(item_def["crit_bonus"])
		state.crit_chance += bonus
		result["crit_bonus"] = bonus

	state.purchased_upgrades_this_floor[item_name] = true
	state.gold -= price
	state.stats["gold_spent"] = int(state.stats.get("gold_spent", 0)) + price
	state.stats["items_purchased"] = int(state.stats.get("items_purchased", 0)) + 1
	logs.append("Purchased upgrade: %s" % item_name)
	return result


func _buy_equipment(item_name: String, price: int, item_def: Dictionary) -> Dictionary:
	if state.inventory.size() >= state.max_inventory:
		logs.append("Inventory full!")
		return {"ok": false, "reason": "inventory_full"}

	state.inventory.append(item_name)
	var max_dur: int = int(item_def.get("max_durability", 100))
	state.equipment_durability[item_name] = max_dur
	state.equipment_floor_level[item_name] = state.floor

	state.gold -= price
	state.stats["gold_spent"] = int(state.stats.get("gold_spent", 0)) + price
	state.stats["items_purchased"] = int(state.stats.get("items_purchased", 0)) + 1
	logs.append("Purchased %s!" % item_name)
	return {"ok": true, "type": "equipment"}


func _buy_consumable(item_name: String, price: int, quantity: int, _item_def: Dictionary) -> Dictionary:
	var total_cost: int = price * quantity
	var space: int = state.max_inventory - state.inventory.size()
	if quantity > space:
		logs.append("Not enough inventory space!")
		return {"ok": false, "reason": "inventory_full"}

	for i in quantity:
		state.inventory.append(item_name)
		state.stats["items_found"] = int(state.stats.get("items_found", 0)) + 1

	state.gold -= total_cost
	state.stats["gold_spent"] = int(state.stats.get("gold_spent", 0)) + total_cost
	state.stats["items_purchased"] = int(state.stats.get("items_purchased", 0)) + quantity
	logs.append("Purchased %dx %s!" % [quantity, item_name])
	return {"ok": true, "type": "consumable", "quantity": quantity}


# ------------------------------------------------------------------
# Sell — mirrors Python _sell_item() + _calculate_sell_price()
# ------------------------------------------------------------------

func calculate_sell_price(item_name: String) -> int:
	var buy_price: int = 0
	var floor_val: int = state.floor

	match item_name:
		"Health Potion": buy_price = 30 + (floor_val * 5)
		"Extra Die": buy_price = 100 + (floor_val * 20)
		"Lucky Chip": buy_price = 70 + (floor_val * 15)
		"Honey Jar": buy_price = 20 + (floor_val * 4)
		"Healing Poultice": buy_price = 50 + (floor_val * 10)
		"Weighted Die": buy_price = 60 + (floor_val * 15)
		"Lockpick Kit": buy_price = 50 + (floor_val * 10)
		"Conductor Rod": buy_price = 70 + (floor_val * 15)
		"Hourglass Shard": buy_price = 80 + (floor_val * 20)
		"Tuner's Hammer": buy_price = 85 + (floor_val * 22)
		"Cooled Ember": buy_price = 90 + (floor_val * 23)
		"Blue Quartz": buy_price = 90 + (floor_val * 20)
		"Silk Bundle": buy_price = 120 + (floor_val * 30)
		"Disarm Token": buy_price = 150
		"Antivenom Leaf": buy_price = 40 + (floor_val * 10)
		"Smoke Pot": buy_price = 55 + (floor_val * 12)
		"Black Candle": buy_price = 65 + (floor_val * 15)
		"Iron Sword": buy_price = 120 + (floor_val * 30)
		"Steel Dagger": buy_price = 100 + (floor_val * 25)
		"Hand Axe": buy_price = 120 + (floor_val * 30)
		"War Axe": buy_price = 180 + (floor_val * 40)
		"Rapier": buy_price = 160 + (floor_val * 35)
		"Greatsword": buy_price = 280 + (floor_val * 60)
		"Assassin's Blade": buy_price = 260 + (floor_val * 55)
		"Leather Armor": buy_price = 110 + (floor_val * 28)
		"Chain Vest": buy_price = 130 + (floor_val * 32)
		"Plate Armor": buy_price = 220 + (floor_val * 50)
		"Dragon Scale": buy_price = 300 + (floor_val * 65)
		"Traveler's Pack": buy_price = 100 + (floor_val * 25)
		"Merchant's Satchel": buy_price = 180 + (floor_val * 40)
		"Lucky Coin": buy_price = 140 + (floor_val * 35)
		"Mystic Ring": buy_price = 150 + (floor_val * 38)
		"Crown of Fortune": buy_price = 250 + (floor_val * 55)
		"Timekeeper's Watch": buy_price = 270 + (floor_val * 58)
		_:
			if items_db.has(item_name):
				var item_data: Dictionary = items_db[item_name]
				if item_data.has("sell_value"):
					return int(item_data["sell_value"])
				var rarity: String = str(item_data.get("rarity", "common")).to_lower()
				var base_prices := {"common": 30, "uncommon": 60, "rare": 120, "epic": 250, "legendary": 500}
				buy_price = int(base_prices.get(rarity, 30))
			else:
				buy_price = 20

	return maxi(5, buy_price / 2)


func sell_item(item_name: String, price: int, quantity: int = 1) -> Dictionary:
	var count: int = state.inventory.count(item_name)
	if count == 0:
		return {"ok": false, "reason": "not_in_inventory"}

	var is_equipped: bool = item_name in state.equipped_items.values()
	if is_equipped and count <= quantity:
		logs.append("Cannot sell equipped item! Unequip first.")
		return {"ok": false, "reason": "equipped"}

	var item_def: Dictionary = items_db.get(item_name, {})
	var item_type: String = item_def.get("type", "")

	if item_type == "quest_item":
		return _sell_quest_item(item_name, item_def, quantity)

	var total_price: int = price * quantity
	for i in quantity:
		state.inventory.erase(item_name)

	state.gold += total_price
	state.total_gold_earned += total_price
	state.stats["items_sold"] = int(state.stats.get("items_sold", 0)) + quantity
	logs.append("Sold %dx %s for %d gold." % [quantity, item_name, total_price])
	return {"ok": true, "gold_gained": total_price}


func _sell_quest_item(item_name: String, item_def: Dictionary, quantity: int) -> Dictionary:
	var quest_reward: int = int(item_def.get("gold_reward", 0))
	var total_reward: int = quest_reward * quantity

	for i in quantity:
		state.inventory.erase(item_name)

	state.gold += total_reward
	state.total_gold_earned += total_reward
	logs.append("Turned in %dx %s! Claimed %d gold reward." % [quantity, item_name, total_reward])
	return {"ok": true, "gold_gained": total_reward, "quest_reward": true}
