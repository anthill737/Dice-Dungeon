extends GutTest
## Tests for minimap icon sizing and label truncation (Issue H).

var _panel_script := preload("res://ui/scripts/minimap_panel.gd")


func test_boss_icon_larger_than_regular() -> void:
	var half := 10.0
	var regular := _panel_script.compute_icon_size(half)
	var boss := _panel_script.compute_boss_icon_size(half)
	assert_gt(boss, regular, "Boss icon size > regular icon size at half=10")


func test_boss_icon_larger_at_small_zoom() -> void:
	var half := 5.0
	var regular := _panel_script.compute_icon_size(half)
	var boss := _panel_script.compute_boss_icon_size(half)
	assert_gte(boss, regular, "Boss icon >= regular at small zoom")


func test_icon_clamp_prevents_overflow() -> void:
	var half := 20.0
	var boss := _panel_script.compute_boss_icon_size(half)
	assert_lte(boss, half, "Boss icon does not exceed half-cell")


func test_icon_size_minimum() -> void:
	var half := 2.0
	var icon := _panel_script.compute_icon_size(half)
	assert_gte(icon, _panel_script.MIN_ICON_SIZE, "Icon >= MIN_ICON_SIZE")


func test_boss_icon_minimum() -> void:
	var half := 2.0
	var icon := _panel_script.compute_boss_icon_size(half)
	assert_gte(icon, _panel_script.MIN_ICON_SIZE, "Boss icon >= MIN_ICON_SIZE")


func test_label_truncation_short() -> void:
	var result := _panel_script.truncate_label("Short", 28)
	assert_eq(result, "Short", "Short label not truncated")


func test_label_truncation_long() -> void:
	var long_text := "This Is A Very Long Room Name That Exceeds Limit"
	var result := _panel_script.truncate_label(long_text, 28)
	assert_eq(result.length(), 28, "Truncated label has correct length")
	assert_true(result.ends_with("..."), "Truncated label ends with ...")


func test_label_truncation_exact() -> void:
	var exact := "ExactlyTwentyEightCharsHere!"
	var result := _panel_script.truncate_label(exact, 28)
	assert_eq(result, exact, "Exactly-at-limit label not truncated")


func test_label_truncation_produces_nonempty() -> void:
	var text := "A"
	var result := _panel_script.truncate_label(text, 5)
	assert_gt(result.length(), 0, "Truncation always produces non-empty string")
