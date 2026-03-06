extends GutTest
## Cross-language parity test: Python inventory trace vs Godot inventory trace.
##
## Both sides use PortableLCG so given the same seed they produce identical
## RNG sequences, enabling exact comparison of inventory state after each
## scripted action sequence.
##
## Test cases:
##   1) Simple pickup + equip
##   2) Equip + durability drop + repair
##   3) Store buy/sell + permanent upgrade + stat check

const COMPARE_FIELDS := [
	"inventory", "equipped", "durability",
	"gold", "health", "max_health",
	"damage_bonus", "crit_chance", "reroll_bonus",
	"armor", "temp_shield", "max_inventory",
	"statuses", "num_dice",
]


func _python_trace_path() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var repo_root := project_dir.get_base_dir()
	return repo_root.path_join("tools/parity/trace_inventory.py")


func _run_python_trace(seed_val: int, actions_csv: String, floor_num: int = 1) -> Array:
	var script := _python_trace_path()
	var output: Array = []
	var args := [script, str(seed_val), actions_csv, str(floor_num)]
	var exit_code := OS.execute("python3", args, output, true)
	assert_eq(exit_code, 0, "Python trace should exit 0 (seed=%d)" % seed_val)
	var stdout_text: String = output[0] if output.size() > 0 else ""
	if stdout_text.is_empty():
		fail_test("Python trace produced no output (seed=%d)" % seed_val)
		return []
	var json := JSON.new()
	var err := json.parse(stdout_text)
	if err != OK:
		fail_test("Python trace is not valid JSON (seed=%d): %s\nOutput: %s" % [seed_val, json.get_error_message(), stdout_text.substr(0, 500)])
		return []
	if not json.data is Array:
		fail_test("Python trace is not an Array (seed=%d)" % seed_val)
		return []
	return json.data


func _run_godot_trace(seed_val: int, actions_arr: Array, floor_num: int = 1) -> Array:
	return InventoryTrace.generate(seed_val, actions_arr, floor_num)


func _compare_traces(py_snapshots: Array, gd_snapshots: Array, label: String) -> void:
	if py_snapshots.size() != gd_snapshots.size():
		fail_test("%s: snapshot count mismatch: python=%d godot=%d" % [label, py_snapshots.size(), gd_snapshots.size()])
		return

	var all_ok := true
	for i in py_snapshots.size():
		var py: Dictionary = py_snapshots[i] if py_snapshots[i] is Dictionary else {}
		var gd: Dictionary = gd_snapshots[i] if gd_snapshots[i] is Dictionary else {}

		for field in COMPARE_FIELDS:
			var py_val = py.get(field)
			var gd_val = gd.get(field)
			if not _values_equal(py_val, gd_val):
				fail_test("%s snapshot %d field '%s': MISMATCH\n  python = %s\n  godot  = %s" % [label, i, field, str(py_val), str(gd_val)])
				all_ok = false
				break

	if all_ok:
		pass_test("%s: all %d snapshots match" % [label, py_snapshots.size()])


func _values_equal(a: Variant, b: Variant) -> bool:
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false

	if a is bool and b is bool:
		return a == b
	if a is bool or b is bool:
		return bool(a) == bool(b)

	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.01

	if a is String and b is String:
		return a == b

	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _values_equal(a[i], b[i]):
				return false
		return true

	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k):
				return false
			if not _values_equal(a[k], b[k]):
				return false
		return true

	return str(a) == str(b)


# ------------------------------------------------------------------
# Parity helper
# ------------------------------------------------------------------

func _run_parity_case(seed_val: int, actions_csv: String, floor_num: int, label: String) -> void:
	var actions_arr: Array = []
	for a in actions_csv.split(","):
		var s := a.strip_edges()
		if not s.is_empty():
			actions_arr.append(s)

	var py_snapshots := _run_python_trace(seed_val, actions_csv, floor_num)
	if py_snapshots.is_empty():
		return

	var gd_snapshots := _run_godot_trace(seed_val, actions_arr, floor_num)
	assert_gt(gd_snapshots.size(), 0, "%s: Godot trace should produce snapshots" % label)

	_compare_traces(py_snapshots, gd_snapshots, label)


# ------------------------------------------------------------------
# Test cases
# ------------------------------------------------------------------

func test_parity_simple_pickup_equip():
	## Scenario: Pick up Iron Sword and Leather Armor, equip both, check stats
	var actions := "pickup:Iron Sword,pickup:Leather Armor,equip:Iron Sword:weapon,equip:Leather Armor:armor,snapshot"
	_run_parity_case(100, actions, 1, "simple_pickup_equip")


func test_parity_durability_repair():
	## Scenario: Equip weapon, degrade durability to 0 (break), then repair
	var actions := "pickup:Iron Sword,equip:Iron Sword:weapon,degrade:Iron Sword:100,snapshot,pickup:Weapon Repair Kit,repair:Weapon Repair Kit:Broken Iron Sword,snapshot"
	_run_parity_case(200, actions, 1, "durability_repair")


func test_parity_store_buy_sell_upgrade():
	## Scenario: Set gold, buy from store, sell item, buy permanent upgrade, check stats
	var actions := "set_gold:5000,buy:Health Potion,buy:Iron Sword,sell:Health Potion,upgrade:Max HP Upgrade,snapshot"
	_run_parity_case(300, actions, 1, "store_buy_sell_upgrade")


func test_parity_heal_and_cleanse():
	## Scenario: Take damage, heal, add status, cleanse
	var actions := "pickup:Health Potion,pickup:Antivenom Leaf,use:0,add_status:poison,use:0,snapshot"
	_run_parity_case(400, actions, 1, "heal_and_cleanse")


func test_python_trace_script_exists():
	var path := _python_trace_path()
	assert_true(FileAccess.file_exists(path),
		"trace_inventory.py should exist at %s" % path)
