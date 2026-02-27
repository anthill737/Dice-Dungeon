extends GutTest
## Python ↔ Godot parity tests.
##
## For each scenario: runs python_runner.py via OS.execute, runs the Godot
## ParityRunner, and diffs the final_state dictionaries for exact match.

const SCENARIOS := ["S1", "S2", "S3"]
const SEED_VAL := 42


func _python_runner_path() -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	project_dir = project_dir.rstrip("/")
	var repo_root := project_dir.get_base_dir()
	return repo_root.path_join("tools/parity/python_runner.py")


func _run_python(scenario_id: String, seed_val: int) -> Dictionary:
	var script_path := _python_runner_path()
	var output: Array = []
	var args := [script_path, scenario_id, str(seed_val)]
	var exit_code := OS.execute("python3", args, output, true)
	assert_eq(exit_code, 0, "python_runner.py should exit 0 for %s" % scenario_id)

	var stdout_text: String = output[0] if output.size() > 0 else ""
	if stdout_text.is_empty():
		fail_test("python_runner.py produced no output for %s" % scenario_id)
		return {}

	var json := JSON.new()
	var err := json.parse(stdout_text)
	if err != OK:
		fail_test("python_runner.py output is not valid JSON for %s: %s" % [scenario_id, json.get_error_message()])
		return {}

	return json.data


func _diff_dicts(path: String, expected: Variant, actual: Variant) -> Array[String]:
	## Recursively diff two values. Returns list of mismatch descriptions.
	var diffs: Array[String] = []

	if typeof(expected) != typeof(actual):
		# Allow int/float cross-comparison
		if (expected is int or expected is float) and (actual is int or actual is float):
			if absf(float(expected) - float(actual)) > 0.001:
				diffs.append("%s: type-coerced value mismatch: python=%s godot=%s" % [path, str(expected), str(actual)])
			return diffs
		diffs.append("%s: type mismatch: python=%s(%s) godot=%s(%s)" % [
			path, str(typeof(expected)), str(expected), str(typeof(actual)), str(actual)])
		return diffs

	if expected is Dictionary and actual is Dictionary:
		var all_keys := {}
		for k in expected:
			all_keys[k] = true
		for k in actual:
			all_keys[k] = true
		for k in all_keys:
			var sub_path := "%s.%s" % [path, k]
			if not expected.has(k):
				diffs.append("%s: missing in python output" % sub_path)
			elif not actual.has(k):
				diffs.append("%s: missing in godot output" % sub_path)
			else:
				diffs.append_array(_diff_dicts(sub_path, expected[k], actual[k]))
	elif expected is Array and actual is Array:
		if expected.size() != actual.size():
			diffs.append("%s: array length mismatch: python=%d godot=%d" % [path, expected.size(), actual.size()])
		else:
			for i in expected.size():
				diffs.append_array(_diff_dicts("%s[%d]" % [path, i], expected[i], actual[i]))
	else:
		if expected is float and actual is float:
			if absf(expected - actual) > 0.001:
				diffs.append("%s: value mismatch: python=%s godot=%s" % [path, str(expected), str(actual)])
		elif str(expected) != str(actual):
			diffs.append("%s: value mismatch: python=%s godot=%s" % [path, str(expected), str(actual)])

	return diffs


func _run_parity(scenario_id: String) -> void:
	# Python side
	var py_result := _run_python(scenario_id, SEED_VAL)
	if py_result.is_empty():
		return

	# Godot side
	var gd_result := ParityRunner.run_scenario(scenario_id, SEED_VAL)
	assert_false(gd_result.is_empty(), "Godot runner should produce output for %s" % scenario_id)

	# Diff final_state
	var py_final = py_result.get("final_state", {})
	var gd_final = gd_result.get("final_state", {})

	var diffs := _diff_dicts("final_state", py_final, gd_final)

	if diffs.size() > 0:
		var diff_text := "\n".join(diffs)
		fail_test("PARITY MISMATCH [%s]:\n%s" % [scenario_id, diff_text])
	else:
		pass_test("Parity OK for %s" % scenario_id)


# ------------------------------------------------------------------
# Test methods — one per scenario
# ------------------------------------------------------------------

func test_parity_s1_dice_damage():
	_run_parity("S1")


func test_parity_s2_mechanics():
	_run_parity("S2")


func test_parity_s3_combat():
	_run_parity("S3")


# ------------------------------------------------------------------
# Verify Python runner is reachable
# ------------------------------------------------------------------

func test_python_runner_exists():
	var path := _python_runner_path()
	assert_true(FileAccess.file_exists(path),
		"python_runner.py should exist at %s" % path)
