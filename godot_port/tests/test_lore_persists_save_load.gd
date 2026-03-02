extends "res://addons/gut/test.gd"
## Test that lore codex state persists through save/load cycle.

func before_each() -> void:
	GameSession._load_data()
	GameSession.start_new_game()


func test_codex_persists_save_load() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine
	var fs := GameSession.get_floor_state()

	gs.inventory.append("Guard Journal")
	gs.inventory.append("Prayer Strip")

	le.read_lore_item("Guard Journal", 0)
	le.read_lore_item("Prayer Strip", 1)
	assert_eq(gs.lore_codex.size(), 2, "Two entries before save")

	var saved_codex := gs.lore_codex.duplicate(true)
	var saved_assignments := gs.lore_item_assignments.duplicate(true)
	var saved_used := gs.used_lore_entries.duplicate(true)

	# Save to string
	var json_str := SaveEngine.save_to_string(gs, fs)
	assert_false(json_str.is_empty(), "Save string is non-empty")

	# Load into fresh state
	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	var ok := SaveEngine.load_from_string(json_str, gs2, fs2)
	assert_true(ok, "Load succeeded")

	assert_eq(gs2.lore_codex.size(), 2, "Codex restored with 2 entries")
	assert_eq(gs2.lore_item_assignments.size(), saved_assignments.size(),
		"Assignments count matches")
	assert_eq(gs2.used_lore_entries.size(), saved_used.size(),
		"Used entries count matches")

	# Verify content
	for i in range(gs2.lore_codex.size()):
		assert_eq(gs2.lore_codex[i].get("title", ""), saved_codex[i].get("title", ""),
			"Title %d matches after load" % i)
		assert_eq(gs2.lore_codex[i].get("content", ""), saved_codex[i].get("content", ""),
			"Content %d matches after load" % i)
		assert_eq(gs2.lore_codex[i].get("item_key", ""), saved_codex[i].get("item_key", ""),
			"Item key %d matches after load" % i)


func test_codex_deduplicates_on_load() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine
	var fs := GameSession.get_floor_state()

	gs.inventory.append("Guard Journal")
	le.read_lore_item("Guard Journal", 0)
	assert_eq(gs.lore_codex.size(), 1, "1 entry before save")

	# Manually duplicate the codex entry to simulate old-save bug
	gs.lore_codex.append(gs.lore_codex[0].duplicate(true))
	assert_eq(gs.lore_codex.size(), 2, "Duplicated entry pre-save")

	var json_str := SaveEngine.save_to_string(gs, fs)

	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	SaveEngine.load_from_string(json_str, gs2, fs2)

	assert_eq(gs2.lore_codex.size(), 1, "Deduplication removed duplicate on load")


func test_reread_after_load_no_new_entry() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine
	var fs := GameSession.get_floor_state()

	gs.inventory.append("Guard Journal")
	le.read_lore_item("Guard Journal", 0)
	assert_eq(gs.lore_codex.size(), 1, "1 entry before save")

	var json_str := SaveEngine.save_to_string(gs, fs)

	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	SaveEngine.load_from_string(json_str, gs2, fs2)

	# Create new lore engine with loaded state
	var le2 := LoreEngine.new(DefaultRNG.new(), gs2, GameSession.lore_db)

	var result := le2.read_lore_item("Guard Journal", 0)
	assert_true(result.get("ok", false), "Re-read after load ok")
	assert_false(result.get("is_new", false), "Re-read after load is NOT new")
	assert_eq(gs2.lore_codex.size(), 1, "Still 1 entry after re-read post-load")
