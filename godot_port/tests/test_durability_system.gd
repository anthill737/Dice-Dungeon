extends GutTest
## Tests for DurabilitySystem (Issue C) — Python parity for durability.

var _state: GameState
var _rng: RNG
var _inv: InventoryEngine
var _items_db: Dictionary


func before_each() -> void:
	_items_db = {
		"Iron Sword": {
			"type": "equipment",
			"slot": "weapon",
			"damage_bonus": 3,
			"max_durability": 100,
			"sell_value": 20,
		},
		"Iron Shield": {
			"type": "equipment",
			"slot": "armor",
			"armor_bonus": 2,
			"max_durability": 100,
			"sell_value": 15,
		},
	}
	_state = GameState.new()
	_state.reset()
	_rng = DeterministicRNG.new(42)
	_inv = InventoryEngine.new(_rng, _state, _items_db)


func test_weapon_degrades_by_3() -> void:
	_inv.add_item_to_inventory("Iron Sword", "found")
	_inv.equip_item("Iron Sword", "weapon")
	assert_eq(int(_state.equipment_durability["Iron Sword"]), 100)

	var result := DurabilitySystem.degrade_weapon(_inv, _state)
	assert_true(result.get("degraded", false), "Weapon degraded")
	assert_eq(int(_state.equipment_durability["Iron Sword"]), 97, "Reduced by 3")


func test_armor_degrades_by_5() -> void:
	_inv.add_item_to_inventory("Iron Shield", "found")
	_inv.equip_item("Iron Shield", "armor")
	assert_eq(int(_state.equipment_durability["Iron Shield"]), 100)

	var result := DurabilitySystem.degrade_armor(_inv, _state)
	assert_true(result.get("degraded", false), "Armor degraded")
	assert_eq(int(_state.equipment_durability["Iron Shield"]), 95, "Reduced by 5")


func test_weapon_break_at_zero() -> void:
	_inv.add_item_to_inventory("Iron Sword", "found")
	_inv.equip_item("Iron Sword", "weapon")
	_state.equipment_durability["Iron Sword"] = 2

	var result := DurabilitySystem.degrade_weapon(_inv, _state)
	assert_true(result.get("broken", false), "Weapon broke at 0")
	assert_eq(_state.equipped_items["weapon"], "", "Weapon slot cleared")
	assert_true(_state.inventory.has("Broken Iron Sword"), "Broken item in inventory")


func test_low_durability_warning() -> void:
	_inv.add_item_to_inventory("Iron Sword", "found")
	_inv.equip_item("Iron Sword", "weapon")
	_state.equipment_durability["Iron Sword"] = 22

	var result := DurabilitySystem.degrade_weapon(_inv, _state)
	assert_true(result.get("warning", false), "Warning at durability 19")
	assert_eq(int(_state.equipment_durability["Iron Sword"]), 19)


func test_no_degrade_without_equipped() -> void:
	var result := DurabilitySystem.degrade_weapon(_inv, _state)
	assert_false(result.get("degraded", false), "No weapon equipped = no degrade")


func test_constants_match_python() -> void:
	assert_eq(DurabilitySystem.WEAPON_DEGRADE_AMOUNT, 3)
	assert_eq(DurabilitySystem.ARMOR_DEGRADE_AMOUNT, 5)
	assert_eq(DurabilitySystem.LOW_DURABILITY_THRESHOLD, 20)
	assert_eq(DurabilitySystem.DEFAULT_MAX_DURABILITY, 100)
