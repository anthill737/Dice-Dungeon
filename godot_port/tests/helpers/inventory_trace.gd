class_name InventoryTrace
extends RefCounted
## Generates inventory trace arrays for parity testing.
##
## Uses PortableLCG (cross-language deterministic RNG) and the real
## InventoryEngine/StoreEngine to produce snapshot records in the same
## JSON schema as the Python trace_inventory.py script.


static func generate(seed_val: int, actions: Array, floor_num: int = 1) -> Array:
	var items_data := ItemsData.new()
	if not items_data.load():
		push_error("InventoryTrace: failed to load items DB")
		return []

	var items_db: Dictionary = items_data.items.duplicate(true)
	if items_db.has("_meta"):
		items_db.erase("_meta")

	var rng := PortableLCG.new(seed_val)
	var state := GameState.new()
	state.floor = floor_num
	var inv_engine := InventoryEngine.new(rng, state, items_db)
	var store_engine := StoreEngine.new(state, items_db)

	var snapshots: Array = []

	for action_str in actions:
		var parts: Array = (action_str as String).split(":")
		var cmd: String = parts[0]

		if cmd == "pickup":
			var item: String = parts[1] if parts.size() > 1 else "Health Potion"
			inv_engine.add_item_to_inventory(item)

		elif cmd == "equip":
			var item: String = parts[1] if parts.size() > 1 else ""
			var slot: String = parts[2] if parts.size() > 2 else ""
			inv_engine.equip_item(item, slot)

		elif cmd == "unequip":
			var slot: String = parts[1] if parts.size() > 1 else ""
			inv_engine.unequip_item(slot)

		elif cmd == "use":
			var idx: int = int(parts[1]) if parts.size() > 1 else 0
			inv_engine.use_item(idx)

		elif cmd == "degrade":
			var item: String = parts[1] if parts.size() > 1 else ""
			var amt: int = int(parts[2]) if parts.size() > 2 else 1
			inv_engine.degrade_durability(item, amt)

		elif cmd == "repair":
			var kit: String = parts[1] if parts.size() > 1 else ""
			var target: String = parts[2] if parts.size() > 2 else ""
			var kit_idx: int = state.inventory.find(kit)
			if kit_idx >= 0:
				inv_engine.repair_item(kit, kit_idx, target)

		elif cmd == "buy":
			var item: String = parts[1] if parts.size() > 1 else ""
			var price: int = _get_store_price(store_engine, item)
			store_engine.buy_item(item, price)

		elif cmd == "sell":
			var item: String = parts[1] if parts.size() > 1 else ""
			var price: int = store_engine.calculate_sell_price(item)
			store_engine.sell_item(item, price)

		elif cmd == "upgrade":
			var item: String = parts[1] if parts.size() > 1 else ""
			var price: int = _get_store_price(store_engine, item)
			store_engine.buy_item(item, price)

		elif cmd == "set_gold":
			var amount: int = int(parts[1]) if parts.size() > 1 else 0
			state.gold = amount

		elif cmd == "set_combat":
			state.in_combat = (parts[1] == "1") if parts.size() > 1 else false

		elif cmd == "add_status":
			var status_name: String = parts[1] if parts.size() > 1 else ""
			if not status_name.is_empty():
				var statuses: Array = state.flags.get("statuses", [])
				if not statuses.has(status_name):
					statuses.append(status_name)
					state.flags["statuses"] = statuses

		elif cmd == "snapshot":
			snapshots.append(_make_snapshot(state))

	snapshots.append(_make_snapshot(state))
	return snapshots


static func _get_store_price(store: StoreEngine, item_name: String) -> int:
	var inv := store.generate_store_inventory()
	for entry in inv:
		if entry[0] == item_name:
			return int(entry[1])
	return 0


static func _make_snapshot(state: GameState) -> Dictionary:
	var equipped := {}
	for slot in state.equipped_items:
		equipped[slot] = state.equipped_items[slot] if not (state.equipped_items[slot] as String).is_empty() else ""

	var durability := {}
	for item in state.equipment_durability:
		durability[item] = int(state.equipment_durability[item])

	return {
		"inventory": state.inventory.duplicate(),
		"equipped": equipped,
		"durability": durability,
		"gold": state.gold,
		"health": state.health,
		"max_health": state.max_health,
		"damage_bonus": state.damage_bonus,
		"crit_chance": snapped(state.crit_chance, 0.0001),
		"reroll_bonus": state.reroll_bonus,
		"armor": state.armor,
		"temp_shield": state.temp_shield,
		"max_inventory": state.max_inventory,
		"statuses": (state.flags.get("statuses", []) as Array).duplicate(),
		"num_dice": state.num_dice,
		"stats": state.stats.duplicate(),
	}
