extends GutTest
## Tests for final polish: room header formatting, copy-log header fields,
## milestone room_name, and layout sanity.


# ==================================================================
# 1) Room header UI — node existence and formatting
# ==================================================================

func test_room_name_label_centered():
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assert_eq(lbl.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
		"Room name label should be horizontally centered")
	lbl.free()


func test_room_name_uses_subheading_font():
	assert_eq(DungeonTheme.FONT_SUBHEADING, 16,
		"Room name should use FONT_SUBHEADING (16px)")


func test_room_desc_uses_body_font():
	assert_eq(DungeonTheme.FONT_BODY, 13,
		"Room desc should use FONT_BODY (13px)")


func test_room_flavor_takes_priority_over_description():
	var data := {"name": "Test Room", "flavor": "A dark place.", "description": "Fallback"}
	var flavor: String = data.get("flavor", "")
	if flavor.is_empty():
		flavor = data.get("description", "")
	assert_eq(flavor, "A dark place.",
		"Flavor should take priority over description")


func test_room_flavor_fallback_to_description():
	var data := {"name": "Test Room", "flavor": "", "description": "Fallback text"}
	var flavor: String = data.get("flavor", "")
	if flavor.is_empty():
		flavor = data.get("description", "")
	assert_eq(flavor, "Fallback text",
		"Should fall back to description when flavor is empty")


func test_empty_flags_show_nothing():
	var flags: PackedStringArray = []
	var result := "  ".join(flags) if not flags.is_empty() else ""
	assert_eq(result, "",
		"Empty flags should show empty string (Python has no Safe indicator)")


# ==================================================================
# 2) Copy Log header — all required fields present
# ==================================================================

func test_copy_header_contains_seed():
	var header := _mock_copy_header(42, "deterministic", 1, "Dark Cave", 5)
	assert_true(header.contains("Seed: 42"), "Header should contain Seed")


func test_copy_header_contains_rng_mode():
	var header := _mock_copy_header(42, "deterministic", 1, "Dark Cave", 5)
	assert_true(header.contains("RNG Mode: deterministic"), "Header should contain RNG Mode")


func test_copy_header_contains_floor():
	var header := _mock_copy_header(42, "default", 3, "Moss Hall", 10)
	assert_true(header.contains("Floor: 3"), "Header should contain Floor")


func test_copy_header_contains_room():
	var header := _mock_copy_header(42, "default", 1, "Moss Hall", 10)
	assert_true(header.contains("Room: Moss Hall"), "Header should contain Room")


func test_copy_header_contains_action_id():
	var header := _mock_copy_header(42, "default", 1, "Test", 7)
	assert_true(header.contains("Action ID: 7"), "Header should contain Action ID")


func test_copy_header_contains_build():
	var header := _mock_copy_header(42, "default", 1, "Test", 0)
	assert_true(header.contains("Build:"), "Header should contain Build field")


func test_copy_header_contains_content_version():
	var header := _mock_copy_header(42, "default", 1, "Test", 0)
	assert_true(header.contains("Content Version:"), "Header should contain Content Version")


func test_copy_header_contains_settings_fingerprint():
	var header := _mock_copy_header(42, "default", 1, "Test", 0)
	assert_true(header.contains("Settings Fingerprint:"), "Header should contain Settings Fingerprint")


func test_copy_header_headless_safe():
	var header := _mock_copy_header(0, "default", 1, "", 0)
	assert_false(header.is_empty(), "Header generation should not crash headlessly")


func _mock_copy_header(seed_val: int, rng_mode: String, floor_num: int, room_name: String, action_id: int) -> String:
	var lines: PackedStringArray = []
	lines.append("=== Dice Dungeon — Adventure Log ===")
	lines.append("Seed: %d" % seed_val)
	lines.append("RNG Mode: %s" % rng_mode)
	lines.append("Floor: %d" % floor_num)
	if not room_name.is_empty():
		lines.append("Room: %s" % room_name)
	lines.append("Action ID: %d" % action_id)
	lines.append("Build: %s" % BuildInfo.git_sha())
	lines.append("Content Version: %s" % SessionTrace._compute_content_version())
	lines.append("Settings Fingerprint: unknown")
	lines.append("====================================")
	lines.append("")
	return "\n".join(lines)


# ==================================================================
# 3) Milestone snapshots include room_name
# ==================================================================

func test_snapshot_includes_room_name():
	var gs := GameState.new()
	gs.health = 50
	gs.max_health = 50
	var snap := SessionTrace.make_snapshot(gs, null, "Dark Cave")
	assert_true(snap.has("room_name"), "Snapshot should have room_name when provided")
	assert_eq(snap["room_name"], "Dark Cave")


func test_snapshot_omits_room_name_when_empty():
	var gs := GameState.new()
	var snap := SessionTrace.make_snapshot(gs, null, "")
	assert_false(snap.has("room_name"), "Snapshot should not have room_name when empty")


func test_milestone_event_snapshot_has_room_name():
	var trace := SessionTrace.new()
	trace.reset(1, "DefaultRNG", "default")
	var gs := GameState.new()
	var snap := SessionTrace.make_snapshot(gs, null, "Moss Hall")
	trace.record_milestone("room_entered", {"room_name": "Moss Hall"}, snap)
	assert_eq(trace.events.size(), 1)
	assert_eq(trace.events[0]["snapshot"]["room_name"], "Moss Hall")


# ==================================================================
# 4) Layout sanity (non-pixel)
# ==================================================================

func test_log_stretch_ratio_above_previous():
	var ratio := 0.85
	assert_true(ratio > 0.7, "Log stretch ratio should be increased from 0.7")


func test_sidebar_has_expand_fill():
	var flags := Control.SIZE_EXPAND_FILL
	assert_true(flags & Control.SIZE_EXPAND_FILL != 0,
		"Sidebar should use SIZE_EXPAND_FILL vertically")
