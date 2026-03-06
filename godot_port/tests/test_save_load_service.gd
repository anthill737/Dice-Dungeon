extends GutTest
## Tests for SaveLoadService — save/load coordination wrapper.

var _svc: SaveLoadService
var _tmp_dir: String


func before_each():
	_tmp_dir = "user://test_saves_%d" % randi()
	_svc = SaveLoadService.new(_tmp_dir)


func after_each():
	for i in range(1, SaveEngine.MAX_SLOTS + 1):
		SaveEngine.delete_slot(_tmp_dir, i)
	if DirAccess.dir_exists_absolute(_tmp_dir):
		DirAccess.remove_absolute(_tmp_dir)


func _make_state() -> Array:
	var gs := GameState.new()
	gs.reset()
	gs.gold = 42
	gs.health = 30
	gs.floor = 2
	var fs := FloorState.new()
	fs.floor_index = 2
	fs.current_pos = Vector2i(1, 1)
	return [gs, fs]


func test_saves_dir_created():
	assert_true(DirAccess.dir_exists_absolute(_tmp_dir), "saves dir should be created")


func test_save_and_load_roundtrip():
	var pair := _make_state()
	var gs: GameState = pair[0]
	var fs: FloorState = pair[1]
	assert_true(_svc.save_to_slot(gs, fs, 1, "Test Save"), "save should succeed")

	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	assert_true(_svc.load_from_slot(1, gs2, fs2), "load should succeed")
	assert_eq(gs2.gold, 42, "gold should be restored")
	assert_eq(gs2.health, 30, "health should be restored")
	assert_eq(fs2.floor_index, 2, "floor should be restored")


func test_list_slots():
	var pair := _make_state()
	_svc.save_to_slot(pair[0], pair[1], 3, "Slot Three")
	var slots := _svc.list_slots()
	assert_eq(slots.size(), SaveEngine.MAX_SLOTS, "should list all slots")
	var slot3 = slots[2]
	assert_eq(slot3.get("save_name", ""), "Slot Three")


func test_delete_slot():
	var pair := _make_state()
	_svc.save_to_slot(pair[0], pair[1], 2, "To Delete")
	assert_true(_svc.delete_slot(2), "delete should succeed")
	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	assert_false(_svc.load_from_slot(2, gs2, fs2), "load after delete should fail")


func test_rename_slot():
	var pair := _make_state()
	_svc.save_to_slot(pair[0], pair[1], 1, "Original")
	assert_true(_svc.rename_slot(1, "Renamed"), "rename should succeed")
	var slots := _svc.list_slots()
	var s1 = slots[0]
	assert_eq(s1.get("save_name", ""), "Renamed")


func test_signal_saved():
	var pair := _make_state()
	watch_signals(_svc)
	_svc.save_to_slot(pair[0], pair[1], 1, "Sig Test")
	assert_signal_emitted(_svc, "saved")


func test_signal_loaded():
	var pair := _make_state()
	_svc.save_to_slot(pair[0], pair[1], 1, "Sig Load")
	watch_signals(_svc)
	var gs2 := GameState.new()
	var fs2 := FloorState.new()
	_svc.load_from_slot(1, gs2, fs2)
	assert_signal_emitted(_svc, "loaded")


func test_signal_deleted():
	var pair := _make_state()
	_svc.save_to_slot(pair[0], pair[1], 1, "Sig Del")
	watch_signals(_svc)
	_svc.delete_slot(1)
	assert_signal_emitted(_svc, "deleted")


func test_signal_renamed():
	var pair := _make_state()
	_svc.save_to_slot(pair[0], pair[1], 1, "Sig Ren")
	watch_signals(_svc)
	_svc.rename_slot(1, "New Name")
	assert_signal_emitted(_svc, "renamed")
