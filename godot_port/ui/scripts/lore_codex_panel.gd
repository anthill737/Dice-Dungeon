extends PanelContainer
## Lore Codex Panel — browse discovered lore entries.
## Left pane: list of entries with filter + search.
## Right pane: full lore text for the selected entry.
## Hosted inside PopupFrame (when standalone) or embedded in CharacterStatus tab.

signal close_requested()

var _entry_list: ItemList
var _detail_title: Label
var _detail_subtitle: Label
var _detail_floor: Label
var _detail_text: RichTextLabel
var _filter_option: OptionButton
var _search_edit: LineEdit
var _no_entries_label: Label

var _filtered_entries: Array = []
var _counts_label: Label
var _seen_entry_ids: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameSession.state_changed.connect(func(): if visible: refresh())


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Filter/search bar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	root.add_child(toolbar)

	_filter_option = OptionButton.new()
	_filter_option.add_item("All Categories", 0)
	_filter_option.item_selected.connect(_on_filter_changed)
	_filter_option.custom_minimum_size = Vector2(180, 0)
	toolbar.add_child(_filter_option)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search..."
	_search_edit.custom_minimum_size = Vector2(200, 0)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_edit)

	root.add_child(DungeonTheme.make_separator(DungeonTheme.BORDER))

	# Content split
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 320
	root.add_child(split)

	# Left pane — entry list
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(280, 0)
	left_box.add_theme_constant_override("separation", 4)
	split.add_child(left_box)

	var list_label := DungeonTheme.make_header(
		"Discovered Entries", DungeonTheme.TEXT_SECONDARY, DungeonTheme.FONT_LABEL)
	list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_box.add_child(list_label)

	_entry_list = DungeonTheme.make_item_list(200)
	_entry_list.name = "CodexEntryList"
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_list.item_selected.connect(_on_entry_selected)
	left_box.add_child(_entry_list)

	_no_entries_label = Label.new()
	_no_entries_label.text = "No lore entries discovered yet.\nRead items marked 'readable_lore' to fill the codex."
	_no_entries_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_no_entries_label.add_theme_color_override("font_color", DungeonTheme.TEXT_DIM)
	_no_entries_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)
	left_box.add_child(_no_entries_label)

	_counts_label = Label.new()
	_counts_label.text = ""
	_counts_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_SMALL)
	_counts_label.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	left_box.add_child(_counts_label)

	# Right pane — detail view
	var right_box := VBoxContainer.new()
	right_box.name = "CodexDetailPane"
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 4)
	split.add_child(right_box)

	_detail_title = Label.new()
	_detail_title.name = "DetailTitle"
	_detail_title.text = "Select an entry"
	_detail_title.add_theme_font_size_override("font_size", DungeonTheme.FONT_SUBHEADING)
	_detail_title.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	right_box.add_child(_detail_title)

	_detail_subtitle = Label.new()
	_detail_subtitle.name = "DetailSubtitle"
	_detail_subtitle.text = ""
	_detail_subtitle.add_theme_color_override("font_color", DungeonTheme.TEXT_SECONDARY)
	right_box.add_child(_detail_subtitle)

	_detail_floor = Label.new()
	_detail_floor.name = "DetailFloor"
	_detail_floor.text = ""
	_detail_floor.add_theme_color_override("font_color", DungeonTheme.TEXT_DIM)
	right_box.add_child(_detail_floor)

	right_box.add_child(DungeonTheme.make_separator())

	_detail_text = RichTextLabel.new()
	_detail_text.name = "DetailText"
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_text.bbcode_enabled = true
	_detail_text.scroll_following = false
	_detail_text.add_theme_font_size_override("normal_font_size", DungeonTheme.FONT_BODY)
	_detail_text.add_theme_color_override("default_color", DungeonTheme.TEXT_BONE)
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

	var total_discovered := 0
	if GameSession.lore_engine != null:
		total_discovered = GameSession.lore_engine.get_codex().size()
	_counts_label.text = "Discovered: %d | Showing: %d" % [total_discovered, _filtered_entries.size()]

	for entry in _filtered_entries:
		var cat_display: String = LoreEngine.CATEGORY_DISPLAY.get(entry.get("type", ""), "")
		var uid = entry.get("unique_id", "")
		var entry_key := str(entry.get("item_key", uid))
		var is_new := not _seen_entry_ids.has(entry_key)
		var prefix := "★ " if is_new else ""
		var line := "%s%s #%s" % [prefix, entry.get("title", "Unknown"), str(uid)]
		if not cat_display.is_empty():
			line += "  [%s]" % cat_display
		var idx := _entry_list.item_count
		_entry_list.add_item(line)
		if is_new:
			_entry_list.set_item_custom_fg_color(idx, DungeonTheme.TEXT_GOLD)


func _on_entry_selected(idx: int) -> void:
	if idx < 0 or idx >= _filtered_entries.size():
		return
	var entry: Dictionary = _filtered_entries[idx]
	var entry_key := str(entry.get("item_key", entry.get("unique_id", "")))
	if not _seen_entry_ids.has(entry_key):
		_seen_entry_ids[entry_key] = true
		_entry_list.set_item_custom_fg_color(idx, DungeonTheme.TEXT_BONE)
		var cur_text: String = _entry_list.get_item_text(idx)
		if cur_text.begins_with("★ "):
			_entry_list.set_item_text(idx, cur_text.substr(2))
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
