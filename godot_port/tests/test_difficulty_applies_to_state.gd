extends GutTest
## Test that difficulty selection applies correct multipliers to GameState.

const CFG_PATH := "user://settings.cfg"


func before_each() -> void:
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func after_all() -> void:
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func test_easy_multipliers() -> void:
	_assert_difficulty("Easy", {
		"player_damage_mult": 1.5,
		"player_damage_taken_mult": 0.7,
		"enemy_health_mult": 0.7,
		"enemy_damage_mult": 1.0,
		"loot_chance_mult": 1.3,
		"heal_mult": 1.2,
	})


func test_normal_multipliers() -> void:
	_assert_difficulty("Normal", {
		"player_damage_mult": 1.0,
		"player_damage_taken_mult": 1.0,
		"enemy_health_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"loot_chance_mult": 1.0,
		"heal_mult": 1.0,
	})


func test_hard_multipliers() -> void:
	_assert_difficulty("Hard", {
		"player_damage_mult": 0.8,
		"player_damage_taken_mult": 1.3,
		"enemy_health_mult": 1.3,
		"enemy_damage_mult": 1.3,
		"loot_chance_mult": 0.8,
		"heal_mult": 0.8,
	})


func test_nightmare_multipliers() -> void:
	_assert_difficulty("Nightmare", {
		"player_damage_mult": 0.6,
		"player_damage_taken_mult": 1.6,
		"enemy_health_mult": 1.8,
		"enemy_damage_mult": 1.6,
		"loot_chance_mult": 0.6,
		"heal_mult": 0.6,
	})


func test_difficulty_name_stored_on_game_state() -> void:
	var sm := _make_manager()
	sm.set_difficulty("Hard")

	var gs := GameState.new()
	gs.reset()
	gs.difficulty = sm.difficulty
	gs.difficulty_mults = sm.get_difficulty_multipliers()

	assert_eq(gs.difficulty, "Hard", "difficulty name on GameState")
	sm.queue_free()


func test_start_new_game_applies_difficulty() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		pending("SettingsManager autoload not available in headless test context")
		return
	sm.set_difficulty("Nightmare")
	GameSession.start_new_game()
	assert_eq(GameSession.game_state.difficulty, "Nightmare", "difficulty applied after start_new_game")
	assert_eq(GameSession.game_state.difficulty_mults["player_damage_mult"], 0.6, "nightmare player_damage_mult")


func _assert_difficulty(diff_name: String, expected: Dictionary) -> void:
	var sm := _make_manager()
	sm.set_difficulty(diff_name)
	var mults: Dictionary = sm.get_difficulty_multipliers()

	for key in expected:
		assert_almost_eq(mults[key], expected[key], 0.001, "%s %s" % [diff_name, key])
	sm.queue_free()


func _make_manager() -> Node:
	var script := load("res://game/core/settings/settings_manager.gd")
	var sm := Node.new()
	sm.set_script(script)
	add_child(sm)
	return sm
