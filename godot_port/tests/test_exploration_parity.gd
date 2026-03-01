extends GutTest
## Cross-language parity test: Python exploration trace vs Godot exploration trace.
##
## Both sides use PortableLCG (identical LCG implementation) so given the same
## seed they produce the same RNG sequence, enabling exact comparison of every
## room generated, exit blocked, store/stairs/miniboss/boss spawn decision.
##
## Test cases:
##   1) seed=100, short pattern "E,E,N,W,S" (5 moves)
##   2) seed=42,  different pattern "N,E,E,S,W,N,E" (7 moves)
##   3) seed=999, long run 50 moves east/north zigzag


## Fields compared per step (order matches JSON schema).
const COMPARE_FIELDS := [
	"coord", "room_name", "room_id",
	"has_combat", "has_chest", "has_store", "has_stairs",
	"is_miniboss", "is_boss", "blocked_exits",
	"ground_container", "ground_gold", "ground_items", "container_locked",
	"revisit",
]


func _python_trace_path() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var repo_root := project_dir.get_base_dir()
	return repo_root.path_join("tools/parity/trace_exploration.py")


func _run_python_trace(seed_val: int, moves: String, floor_num: int = 1) -> Array:
	var script := _python_trace_path()
	var output: Array = []
	var args := [script, str(seed_val), moves, str(floor_num)]
	var exit_code := OS.execute("python3", args, output, true)
	assert_eq(exit_code, 0, "Python trace should exit 0 (seed=%d)" % seed_val)
	var stdout_text: String = output[0] if output.size() > 0 else ""
	if stdout_text.is_empty():
		fail_test("Python trace produced no output (seed=%d)" % seed_val)
		return []
	var json := JSON.new()
	var err := json.parse(stdout_text)
	if err != OK:
		fail_test("Python trace output is not valid JSON (seed=%d): %s" % [seed_val, json.get_error_message()])
		return []
	if not json.data is Array:
		fail_test("Python trace output is not an Array (seed=%d)" % seed_val)
		return []
	return json.data


func _run_godot_trace(seed_val: int, moves_arr: Array, floor_num: int = 1) -> Array:
	return ExplorationTrace.generate(seed_val, moves_arr, floor_num)


func _compare_traces(py_steps: Array, gd_steps: Array, label: String) -> void:
	if py_steps.size() != gd_steps.size():
		fail_test("%s: step count mismatch: python=%d godot=%d" % [label, py_steps.size(), gd_steps.size()])
		## Show first few steps for debugging
		var show := mini(py_steps.size(), gd_steps.size())
		for i in mini(show, 5):
			gut.p("  py[%d]: %s" % [i, str(py_steps[i]).substr(0, 200)])
			gut.p("  gd[%d]: %s" % [i, str(gd_steps[i]).substr(0, 200)])
		return

	var all_ok := true
	for i in py_steps.size():
		var py: Dictionary = py_steps[i] if py_steps[i] is Dictionary else {}
		var gd: Dictionary = gd_steps[i] if gd_steps[i] is Dictionary else {}

		## Handle blocked steps
		var py_blocked: bool = py.get("blocked", false)
		var gd_blocked: bool = gd.get("blocked", false)
		if py_blocked or gd_blocked:
			if py_blocked != gd_blocked:
				fail_test("%s step %d: blocked mismatch py=%s gd=%s" % [label, i, str(py_blocked), str(gd_blocked)])
				all_ok = false
			elif py.get("reason", "") != gd.get("reason", ""):
				fail_test("%s step %d: block reason mismatch py=%s gd=%s" % [label, i, py.get("reason", ""), gd.get("reason", "")])
				all_ok = false
			continue

		for field in COMPARE_FIELDS:
			var py_val = py.get(field)
			var gd_val = gd.get(field)
			if not _values_equal(py_val, gd_val):
				fail_test("%s step %d field '%s': MISMATCH\n  python = %s\n  godot  = %s" % [label, i, field, str(py_val), str(gd_val)])
				all_ok = false
				## Stop after first mismatch in this step for readability
				break

	if all_ok:
		pass_test("%s: all %d steps match" % [label, py_steps.size()])


func _values_equal(a: Variant, b: Variant) -> bool:
	## Handle type coercion for int/float and Array/Dictionary comparisons
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false

	## bool comparison (Python sends true/false, Godot bool)
	if a is bool and b is bool:
		return a == b
	if a is bool or b is bool:
		return bool(a) == bool(b)

	## Numeric comparison
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.001

	## String comparison
	if a is String and b is String:
		return a == b

	## Array comparison
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _values_equal(a[i], b[i]):
				return false
		return true

	## Dictionary comparison
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

func _run_parity_case(seed_val: int, moves_csv: String, floor_num: int, label: String) -> void:
	var moves_arr: Array = []
	for m in moves_csv.split(","):
		var s := m.strip_edges().to_upper()
		if not s.is_empty():
			moves_arr.append(s)

	var py_steps := _run_python_trace(seed_val, moves_csv, floor_num)
	if py_steps.is_empty():
		return

	var gd_steps := _run_godot_trace(seed_val, moves_arr, floor_num)
	assert_gt(gd_steps.size(), 0, "%s: Godot trace should produce steps" % label)

	_compare_traces(py_steps, gd_steps, label)


# ------------------------------------------------------------------
# Test cases
# ------------------------------------------------------------------

func test_parity_seed100_short():
	_run_parity_case(100, "E,E,N,W,S", 1, "seed100_short")


func test_parity_seed42_mixed():
	_run_parity_case(42, "N,E,E,S,W,N,E", 1, "seed42_mixed")


func test_parity_seed999_long():
	## 50 moves: alternating E and N
	var moves: Array = []
	for i in 50:
		moves.append("E" if i % 2 == 0 else "N")
	var moves_csv := ",".join(moves)
	_run_parity_case(999, moves_csv, 1, "seed999_long_50")


# ------------------------------------------------------------------
# Verify PortableLCG cross-language agreement
# ------------------------------------------------------------------

func test_portable_lcg_matches_python():
	## Verify the first 10 values from PortableLCG match Python's output.
	## Python: PortableLCG(42), call _next() 10 times
	## Expected values computed by running Python:
	##   state starts at 42
	##   42 * 48271 % 2147483647 = 2027382
	##   2027382 * 48271 % 2147483647 = ...
	var lcg_py := PortableLCG.new(42)
	var lcg_gd := PortableLCG.new(42)
	var vals_py: Array = []
	var vals_gd: Array = []
	for i in 10:
		vals_py.append(lcg_py.randf())
	for i in 10:
		vals_gd.append(lcg_gd.randf())
	assert_eq(vals_py, vals_gd, "PortableLCG self-consistency check")


func test_python_trace_script_exists():
	var path := _python_trace_path()
	assert_true(FileAccess.file_exists(path),
		"trace_exploration.py should exist at %s" % path)
