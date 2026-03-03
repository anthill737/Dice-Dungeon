extends "res://addons/gut/test.gd"
## Test that reading a readable_lore item adds an entry to the codex
## exactly once per unique item instance.

func before_each() -> void:
	GameSession._load_data()
	GameSession.start_new_game()


func test_read_adds_codex_entry() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine
	assert_not_null(le, "LoreEngine exists")
	assert_eq(gs.lore_codex.size(), 0, "Codex starts empty")

	gs.inventory.append("Guard Journal")
	var idx := gs.inventory.size() - 1

	var result := le.read_lore_item("Guard Journal", idx)
	assert_true(result.get("ok", false), "read_lore_item returns ok")
	assert_true(result.get("is_new", false), "First read is new")
	assert_eq(gs.lore_codex.size(), 1, "Codex has 1 entry after first read")

	var entry: Dictionary = result.get("entry", {})
	assert_eq(entry.get("title", ""), "Guard Journal", "Entry title matches")
	assert_false(entry.get("content", "").is_empty(), "Entry content is non-empty")


func test_reread_same_item_no_duplicate() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine

	gs.inventory.append("Guard Journal")
	var idx := gs.inventory.size() - 1

	le.read_lore_item("Guard Journal", idx)
	assert_eq(gs.lore_codex.size(), 1, "Codex has 1 entry after first read")

	var result2 := le.read_lore_item("Guard Journal", idx)
	assert_true(result2.get("ok", false), "Re-read returns ok")
	assert_false(result2.get("is_new", false), "Re-read is NOT new")
	assert_eq(gs.lore_codex.size(), 1, "Codex still has 1 entry after re-read")


func test_different_items_different_entries() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine

	gs.inventory.append("Guard Journal")
	gs.inventory.append("Guard Journal")
	var idx0 := 0
	var idx1 := 1

	le.read_lore_item("Guard Journal", idx0)
	le.read_lore_item("Guard Journal", idx1)
	assert_eq(gs.lore_codex.size(), 2, "Two different item instances produce two codex entries")


func test_entry_schema() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine

	gs.inventory.append("Quest Notice")
	var idx := gs.inventory.size() - 1

	var result := le.read_lore_item("Quest Notice", idx)
	assert_true(result.get("ok", false), "read ok")

	var codex_entry: Dictionary = gs.lore_codex[0]
	assert_has(codex_entry, "type", "Entry has 'type'")
	assert_has(codex_entry, "title", "Entry has 'title'")
	assert_has(codex_entry, "subtitle", "Entry has 'subtitle'")
	assert_has(codex_entry, "content", "Entry has 'content'")
	assert_has(codex_entry, "floor_found", "Entry has 'floor_found'")
	assert_has(codex_entry, "unique_id", "Entry has 'unique_id'")
	assert_has(codex_entry, "item_key", "Entry has 'item_key'")


func test_lore_type_not_readable() -> void:
	var gs := GameSession.game_state
	var le := GameSession.lore_engine

	var result := le.read_lore_item("Unknown Item", 0)
	assert_false(result.get("ok", false), "Unknown item returns not ok")
	assert_eq(gs.lore_codex.size(), 0, "Codex unchanged for unknown item")


func test_inventory_use_readable_lore() -> void:
	var gs := GameSession.game_state
	var ie := GameSession.inventory_engine

	gs.inventory.append("Guard Journal")
	var idx := gs.inventory.size() - 1

	var result := ie.use_item(idx)
	assert_true(result.get("ok", false), "use_item returns ok")
	assert_eq(result.get("type", ""), "readable_lore", "Type is readable_lore")

	var item_name: String = result.get("item_name", "")
	var item_idx: int = int(result.get("idx", 0))
	assert_eq(item_name, "Guard Journal", "item_name matches")
	assert_eq(item_idx, idx, "idx matches")


func test_inventory_use_lore_type() -> void:
	var gs := GameSession.game_state
	var ie := GameSession.inventory_engine

	var lore_items := GameSession.items_db.keys()
	var lore_item_name := ""
	for item_key in lore_items:
		var item_def: Dictionary = GameSession.items_db[item_key]
		if item_def.get("type", "") == "lore":
			lore_item_name = item_key
			break

	if lore_item_name.is_empty():
		pending("No lore-type items found in items_db")
		return

	gs.inventory.append(lore_item_name)
	var idx := gs.inventory.size() - 1

	var result := ie.use_item(idx)
	assert_true(result.get("ok", false), "use_item returns ok for lore type")
	assert_eq(result.get("type", ""), "lore", "Type is lore (not readable_lore)")
	assert_eq(gs.lore_codex.size(), 0, "Codex not affected by plain lore item")
