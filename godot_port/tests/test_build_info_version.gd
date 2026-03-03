extends GutTest
## Verifies that BuildInfo provides a non-empty game_version and that
## SessionTrace picks it up automatically on reset.


func test_build_info_git_sha_is_non_empty():
	var sha := BuildInfo.git_sha()
	assert_ne(sha, "", "BuildInfo.git_sha() must never be empty")
	assert_true(sha.length() > 0, "git_sha must have positive length")


func test_build_info_version_label_is_non_empty():
	var label := BuildInfo.version_label()
	assert_ne(label, "", "BuildInfo.version_label() must never be empty")


func test_session_trace_game_version_is_non_empty():
	var trace := SessionTrace.new()
	assert_ne(trace.game_version, "", "SessionTrace.game_version must be non-empty after init")
	assert_true(trace.game_version.length() > 0, "game_version must have positive length")


func test_session_trace_game_version_survives_reset():
	var trace := SessionTrace.new()
	trace.reset(42, "DeterministicRNG")
	assert_ne(trace.game_version, "", "game_version must be non-empty after reset")


func test_session_trace_json_contains_build_fields():
	var trace := SessionTrace.new()
	trace.reset(1, "DefaultRNG")
	trace.record("test", {})

	var json_str := trace.export_json()
	var json := JSON.new()
	var err := json.parse(json_str)
	assert_eq(err, OK, "exported JSON must parse")

	var data: Dictionary = json.data
	assert_true(data.has("game_version"), "JSON must contain game_version")
	assert_true(data.has("build_time_utc"), "JSON must contain build_time_utc")
	assert_ne(str(data["game_version"]), "", "game_version in JSON must be non-empty")
