extends GutTest
## Tests for AdventureLogService.


func test_starts_empty():
	var svc := AdventureLogService.new()
	assert_eq(svc.size(), 0, "log should start empty")
	assert_true(svc.get_entries().is_empty(), "entries should be empty")


func test_append_adds_entry():
	var svc := AdventureLogService.new()
	svc.append("You enter the dungeon.")
	assert_eq(svc.size(), 1)
	var entry: Dictionary = svc.get_entries()[0]
	assert_eq(entry["text"], "You enter the dungeon.")
	assert_eq(entry["tag"], "system")


func test_append_multiple():
	var svc := AdventureLogService.new()
	svc.append("First")
	svc.append("Second")
	svc.append("Third")
	assert_eq(svc.size(), 3)
	assert_eq(svc.get_entries()[1]["text"], "Second")


func test_clear():
	var svc := AdventureLogService.new()
	svc.append("Entry")
	svc.clear()
	assert_eq(svc.size(), 0, "log should be empty after clear")


func test_get_entries_returns_copy():
	var svc := AdventureLogService.new()
	svc.append("Original")
	var entries := svc.get_entries()
	entries.append("Injected")
	assert_eq(svc.size(), 1, "internal list should not be affected by external mutation")


func test_signal_entry_added():
	var svc := AdventureLogService.new()
	watch_signals(svc)
	svc.append("Signal test")
	assert_signal_emitted(svc, "entry_added")


func test_append_with_tag():
	var svc := AdventureLogService.new()
	svc.append("Found gold!", "loot")
	var entry: Dictionary = svc.get_entries()[0]
	assert_eq(entry["text"], "Found gold!")
	assert_eq(entry["tag"], "loot")


func test_append_with_category():
	var svc := AdventureLogService.new()
	svc.append("Boss fight!", "enemy", "combat")
	var entry: Dictionary = svc.get_entries()[0]
	assert_eq(entry["text"], "Boss fight!")
	assert_eq(entry["tag"], "enemy")
	assert_eq(entry["category"], "combat")


func test_get_text_entries():
	var svc := AdventureLogService.new()
	svc.append("First", "system")
	svc.append("Second", "loot")
	svc.append("Third", "enemy")
	var texts := svc.get_text_entries()
	assert_eq(texts.size(), 3)
	assert_eq(texts[0], "First")
	assert_eq(texts[1], "Second")
	assert_eq(texts[2], "Third")
