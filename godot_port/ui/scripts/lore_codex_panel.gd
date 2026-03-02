extends PanelContainer
## Lore Codex Panel — browse discovered lore entries.
## Left pane: list of entries (title / date / category) with filter + search.
## Right pane: full lore text for the selected entry.

signal close_requested()

var _entry_list: ItemList
var _detail_title: Label
var _detail_subtitle: Label
var _detail_floor: Label
var _detail_text: RichTextLabel
var _filter_option: OptionButton
var _search_edit: LineEdit
var _btn_close: Button
var _no_entries_label: Label

var _filtered_entries: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(func(): if visible: refresh())


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.12, 0.97)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := Label.new()
	title.text = "=== LORE CODEX ==="
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	header.add_child(Control.new())  # spacer

	_filter_option = OptionButton.new()
	_filter_option.add_item("All Categories", 0)
	_filter_option.item_selected.connect(_on_filter_changed)
	_filter_option.custom_minimum_size = Vector2(180, 0)
	header.add_child(_filter_option)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search..."
	_search_edit.custom_minimum_size = Vector2(160, 0)
	_search_edit.text_changed.connect(_on_search_changed)
	header.add_child(_search_edit)

	_btn_close = Button.new()
	_btn_close.text = "Close"
	_btn_close.pressed.connect(func(): close_requested.emit(); visible = false)
	header.add_child(_btn_close)

	# Content split
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 320
	root.add_child(split)

	# Left pane — entry list
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(280, 0)
	split.add_child(left_box)

	var list_label := Label.new()
	list_label.text = "Discovered Entries"
	left_box.add_child(list_label)

	_entry_list = ItemList.new()
	_entry_list.name = "CodexEntryList"
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_list.item_selected.connect(_on_entry_selected)
	left_box.add_child(_entry_list)

	_no_entries_label = Label.new()
	_no_entries_label.text = "No lore entries discovered yet.\nRead items marked 'readable_lore' to fill the codex."
	_no_entries_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_no_entries_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_box.add_child(_no_entries_label)

	# Right pane — detail view
	var right_box := VBoxContainer.new()
	right_box.name = "CodexDetailPane"
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 4)
	split.add_child(right_box)

	_detail_title = Label.new()
	_detail_title.name = "DetailTitle"
	_detail_title.text = ""
	_detail_title.add_theme_font_size_override("font_size", 18)
	_detail_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	right_box.add_child(_detail_title)

	_detail_subtitle = Label.new()
	_detail_subtitle.name = "DetailSubtitle"
	_detail_subtitle.text = ""
	_detail_subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	right_box.add_child(_detail_subtitle)

	_detail_floor = Label.new()
	_detail_floor.name = "DetailFloor"
	_detail_floor.text = ""
	_detail_floor.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	right_box.add_child(_detail_floor)

	var sep := HSeparator.new()
	right_box.add_child(sep)

	_detail_text = RichTextLabel.new()
	_detail_text.name = "DetailText"
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_text.bbcode_enabled = true
	_detail_text.scroll_following = false
	right_box.add_child(_detail_text)


func refresh() -> void:
	_rebuild_filter_options()
	_apply_filter_and_search()
	_populate_list()
	_clear_detail()


func _rebuild_filter_options() -> void:
	var current := _filter_option.selected
	_filter_option.clear()
	_filter_option.add_item("All Categories", 0)

	if GameSession.lore_engine == null:
		return

	var cats := GameSession.lore_engine.get_codex_categories()
	for i in range(cats.size()):
		var display: String = LoreEngine.CATEGORY_DISPLAY.get(cats[i], cats[i])
		_filter_option.add_item(display, i + 1)

	if current >= 0 and current < _filter_option.item_count:
		_filter_option.select(current)


func _apply_filter_and_search() -> void:
	_filtered_entries = []
	if GameSession.lore_engine == null:
		return

	var codex := GameSession.lore_engine.get_codex()
	var filter_idx := _filter_option.selected
	var filter_cat := ""
	if filter_idx > 0 and GameSession.lore_engine != null:
		var cats := GameSession.lore_engine.get_codex_categories()
		if filter_idx - 1 < cats.size():
			filter_cat = cats[filter_idx - 1]

	var search_term := _search_edit.text.strip_edges().to_lower()

	for entry in codex:
		if not filter_cat.is_empty() and entry.get("type", "") != filter_cat:
			continue
		if not search_term.is_empty():
			var haystack := (str(entry.get("title", "")) + " " + str(entry.get("content", "")) + " " + str(entry.get("subtitle", ""))).to_lower()
			if haystack.find(search_term) < 0:
				continue
		_filtered_entries.append(entry)


func _populate_list() -> void:
	_entry_list.clear()
	_no_entries_label.visible = _filtered_entries.is_empty()
	_entry_list.visible = not _filtered_entries.is_empty()

	for entry in _filtered_entries:
		var cat_display: String = LoreEngine.CATEGORY_DISPLAY.get(entry.get("type", ""), "")
		var uid = entry.get("unique_id", "")
		var line := "%s #%s" % [entry.get("title", "Unknown"), str(uid)]
		if not cat_display.is_empty():
			line += "  [%s]" % cat_display
		_entry_list.add_item(line)


func _on_entry_selected(idx: int) -> void:
	if idx < 0 or idx >= _filtered_entries.size():
		return
	var entry: Dictionary = _filtered_entries[idx]
	_detail_title.text = "%s #%s" % [entry.get("title", ""), str(entry.get("unique_id", ""))]
	_detail_subtitle.text = entry.get("subtitle", "")
	_detail_floor.text = "Discovered on Floor %s" % str(entry.get("floor_found", "?"))
	_detail_text.text = str(entry.get("content", ""))


func _clear_detail() -> void:
	_detail_title.text = "Select an entry"
	_detail_subtitle.text = ""
	_detail_floor.text = ""
	_detail_text.text = ""


func _on_filter_changed(_idx: int) -> void:
	_apply_filter_and_search()
	_populate_list()
	_clear_detail()


func _on_search_changed(_text: String) -> void:
	_apply_filter_and_search()
	_populate_list()
	_clear_detail()
