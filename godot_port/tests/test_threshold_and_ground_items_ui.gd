extends GutTest

var _ground_items_scene := preload("res://ui/scenes/GroundItemsPanel.tscn")
var _threshold_scene := preload("res://ui/scenes/ThresholdArea.tscn")


func before_each() -> void:
	GameSession._load_data()
	if GameSession.assets == null:
		GameSession.assets = AssetResolver.new()


func test_container_item_row_uses_texture_icon_when_available() -> void:
	var panel := _ground_items_scene.instantiate()
	add_child(panel)
	await get_tree().process_frame

	var room := RoomState.new()
	var parent := VBoxContainer.new()
	panel.add_child(parent)

	panel._add_container_item_row(parent, room, "Honey Jar")

	var icon_nodes := parent.find_children("*", "TextureRect", true, false)
	assert_gt(icon_nodes.size(), 0, "Container item row should render a TextureRect icon")

	var labels := parent.find_children("*", "Label", true, false)
	var found := false
	for lbl in labels:
		if lbl.text == "Honey Jar":
			found = true
			break
	assert_true(found, "Container item row should show the plain item name")

	panel.queue_free()
	await get_tree().process_frame


func test_sign_popup_uses_rich_text_label_for_wrapped_body() -> void:
	var scene := _threshold_scene.instantiate()
	add_child(scene)
	await get_tree().process_frame

	var sign_data := {
		"title": "Ancient Advice - Pace Yourself",
		"text": "An old message, carved deep into stone:\n\n'...whatever you're here for, pace yourself...'"
	}
	scene._on_sign_pressed(sign_data)
	await get_tree().process_frame

	assert_not_null(scene._sign_popup, "Sign popup should be created")
	var rich_nodes := scene._sign_popup.find_children("*", "RichTextLabel", true, false)
	assert_eq(rich_nodes.size(), 1, "Sign popup should use a RichTextLabel body")
	assert_eq(rich_nodes[0].text, sign_data["text"], "Sign popup body text should match the sign content")

	scene.queue_free()
	await get_tree().process_frame
