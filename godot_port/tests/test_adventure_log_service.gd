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
	assert_eq(svc.get_entries()[0], "You enter the dungeon.")


func test_append_multiple():
	var svc := AdventureLogService.new()
	svc.append("First")
	svc.append("Second")
	svc.append("Third")
	assert_eq(svc.size(), 3)
	assert_eq(svc.get_entries()[1], "Second")


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
