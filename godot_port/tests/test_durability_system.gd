extends GutTest
## Tests for DurabilitySystem (Issue C) — Python parity for durability.
## Includes standalone module tests and headless CombatEngine integration.

var _state: GameState
var _rng: RNG
var _inv: InventoryEngine
var _items_db: Dictionary


func _make_items_db() -> Dictionary:
	return {
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


func before_each() -> void:
	_items_db = _make_items_db()
	_state = GameState.new()
	_state.reset()
	_rng = DeterministicRNG.new(42)
	_inv = InventoryEngine.new(_rng, _state, _items_db)


# ------------------------------------------------------------------
# Standalone module tests
# ------------------------------------------------------------------

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


# ------------------------------------------------------------------
# Headless CombatEngine integration — durability in core without UI
# ------------------------------------------------------------------

func test_headless_weapon_degrades_on_player_attack() -> void:
	var rng := DeterministicRNG.new(500)
	var gs := GameState.new()
	gs.reset()
	var db := _make_items_db()
	var inv := InventoryEngine.new(rng, gs, db)
	inv.add_item_to_inventory("Iron Sword", "found")
	inv.equip_item("Iron Sword", "weapon")
	assert_eq(int(gs.equipment_durability["Iron Sword"]), 100)

	var combat := CombatEngine.new(rng, gs, 3, {"Goblin": {"health": 200, "num_dice": 1}})
	combat.set_inventory_engine(inv)
	combat.add_enemy("Goblin", 200, 1)

	combat.dice.roll()
	var turn := combat.player_attack(0)

	assert_lt(int(gs.equipment_durability["Iron Sword"]), 100,
		"Weapon durability decreased after headless attack")
	assert_eq(int(gs.equipment_durability["Iron Sword"]), 97,
		"Exactly 3 durability lost per Python parity")
	# Check durability_events in the TurnResult
	var weapon_events := []
	for ev in turn.durability_events:
		if ev.get("slot") == "weapon":
			weapon_events.append(ev)
	assert_eq(weapon_events.size(), 1, "One weapon durability event")
	assert_eq(int(weapon_events[0].get("durability", -1)), 97)


func test_headless_armor_degrades_on_enemy_hit() -> void:
	var rng := DeterministicRNG.new(600)
	var gs := GameState.new()
	gs.reset()
	gs.health = 200
	gs.max_health = 200
	var db := _make_items_db()
	var inv := InventoryEngine.new(rng, gs, db)
	inv.add_item_to_inventory("Iron Shield", "found")
	inv.equip_item("Iron Shield", "armor")
	assert_eq(int(gs.equipment_durability["Iron Shield"]), 100)

	var combat := CombatEngine.new(rng, gs, 3, {"Goblin": {"health": 200, "num_dice": 2}})
	combat.set_inventory_engine(inv)
	combat.add_enemy("Goblin", 200, 2)

	combat.dice.roll()
	var turn := combat.player_attack(0)

	# Enemy should have dealt some damage, triggering armor degradation
	var took_damage := false
	for er in turn.enemy_rolls:
		if int(er.get("damage", 0)) > 0:
			took_damage = true
	if took_damage:
		assert_eq(int(gs.equipment_durability["Iron Shield"]), 95,
			"Exactly 5 armor durability lost per Python parity")
		var armor_events := []
		for ev in turn.durability_events:
			if ev.get("slot") == "armor":
				armor_events.append(ev)
		assert_eq(armor_events.size(), 1, "One armor durability event")
	else:
		assert_eq(int(gs.equipment_durability["Iron Shield"]), 100,
			"No degradation when enemy dealt 0 damage")


func test_headless_no_durability_without_inv_engine() -> void:
	var rng := DeterministicRNG.new(700)
	var gs := GameState.new()
	gs.reset()

	var combat := CombatEngine.new(rng, gs, 3, {"Goblin": {"health": 200, "num_dice": 1}})
	# Deliberately NOT calling set_inventory_engine
	combat.add_enemy("Goblin", 200, 1)

	combat.dice.roll()
	var turn := combat.player_attack(0)

	assert_eq(turn.durability_events.size(), 0,
		"No durability events without inventory engine")


func test_headless_multiple_attacks_accumulate_durability_loss() -> void:
	var rng := DeterministicRNG.new(800)
	var gs := GameState.new()
	gs.reset()
	gs.health = 300
	gs.max_health = 300
	var db := _make_items_db()
	var inv := InventoryEngine.new(rng, gs, db)
	inv.add_item_to_inventory("Iron Sword", "found")
	inv.equip_item("Iron Sword", "weapon")

	var combat := CombatEngine.new(rng, gs, 3, {"Goblin": {"health": 500, "num_dice": 1}})
	combat.set_inventory_engine(inv)
	combat.add_enemy("Goblin", 500, 1)

	for i in 5:
		combat.dice.roll()
		combat.player_attack(0)

	# 5 attacks × 3 durability = 15 lost → 85 remaining
	assert_eq(int(gs.equipment_durability["Iron Sword"]), 85,
		"5 attacks lose 15 total durability")
