extends GutTest


func test_arithmetic():
	assert_eq(1 + 1, 2, "basic addition")


func test_string_format():
	var name := "Dice Dungeon"
	assert_eq(name.length(), 12, "game title length")


func test_array_operations():
	var dice := [1, 2, 3, 4, 5, 6]
	assert_eq(dice.size(), 6, "six dice faces")
	assert_true(dice.has(6), "contains max face")
	assert_false(dice.has(7), "no face value 7")


func test_dictionary():
	var player := {"hp": 50, "gold": 0, "floor": 1}
	assert_eq(player["hp"], 50, "starting hp")
	assert_eq(player.get("gold"), 0, "starting gold")
