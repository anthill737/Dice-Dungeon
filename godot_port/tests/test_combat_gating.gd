extends GutTest
## Tests for CombatGatingPolicy (Issue D) — save/flee gating during combat.

var _state: GameState
var _rng: RNG


func before_each() -> void:
	_state = GameState.new()
	_state.reset()
	_rng = DeterministicRNG.new(42)


func test_can_save_outside_combat() -> void:
	_state.in_combat = false
	assert_true(CombatGatingPolicy.can_save(_state, null), "Can save outside combat")


func test_cannot_save_during_combat() -> void:
	_state.in_combat = true
	assert_false(CombatGatingPolicy.can_save(_state, null), "Cannot save during combat")


func test_cannot_save_with_combat_engine() -> void:
	var enemy_db := {}
	var combat := CombatEngine.new(_rng, _state, 3, enemy_db)
	assert_false(CombatGatingPolicy.can_save(_state, combat), "Cannot save with active combat")


func test_can_flee_from_normal_enemy() -> void:
	var enemy_db := {}
	var combat := CombatEngine.new(_rng, _state, 3, enemy_db)
	combat.add_enemy("Skeleton", 20, 2)
	var result := CombatGatingPolicy.can_flee(combat)
	assert_true(result.get("allowed", false), "Can flee from normal enemy")


func test_cannot_flee_from_boss() -> void:
	var enemy_db := {}
	var combat := CombatEngine.new(_rng, _state, 3, enemy_db)
	var boss := combat.add_enemy("Dragon", 100, 4)
	boss.is_boss = true
	var result := CombatGatingPolicy.can_flee(combat)
	assert_false(result.get("allowed", false), "Cannot flee from boss")
	assert_eq(result.get("reason", ""), "boss_fight")


func test_cannot_flee_from_miniboss() -> void:
	var enemy_db := {}
	var combat := CombatEngine.new(_rng, _state, 3, enemy_db)
	var miniboss := combat.add_enemy("Shadow Knight", 50, 3)
	miniboss.is_mini_boss = true
	var result := CombatGatingPolicy.can_flee(combat)
	assert_false(result.get("allowed", false), "Cannot flee from miniboss")


func test_save_blocked_message() -> void:
	var msg := CombatGatingPolicy.save_blocked_message()
	assert_true(msg.length() > 0, "Save blocked message not empty")
	assert_true("combat" in msg.to_lower(), "Message mentions combat")


func test_flee_blocked_message() -> void:
	var msg := CombatGatingPolicy.flee_blocked_message()
	assert_true(msg.length() > 0, "Flee blocked message not empty")
	assert_true("boss" in msg.to_lower(), "Message mentions boss")


func test_null_state_cannot_save() -> void:
	assert_false(CombatGatingPolicy.can_save(null, null), "Null state = cannot save")
