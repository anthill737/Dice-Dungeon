extends PanelContainer
## Shared modal popup wrapper. Provides a title bar with a red X close button
## and a content slot where submenu panels are instanced.
##
## Usage:
##   var frame = PopupFrame.new()
##   frame.title_text = "INVENTORY"
##   frame.set_content(some_panel)
##   frame.closable = true  # false for combat when locked
##   frame.close_requested connects to MenuOverlayManager.close_top_menu()

signal close_requested()

var _title_label: Label
var _btn_close: Button
var _content_container: MarginContainer
var _content: Control

## If false, the X button is hidden and close_requested will not fire.
var closable: bool = true:
	set(value):
		closable = value
		if _btn_close != null:
			_btn_close.visible = value

var title_text: String = "":
	set(value):
		title_text = value
		if _title_label != null:
			_title_label.text = value


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Dim background behind the popup to create modal feel
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bg_style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", bg_style)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Centered popup panel
	var popup_panel := PanelContainer.new()
	popup_panel.name = "PopupPanel"
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.anchor_left = 0.05
	popup_panel.anchor_top = 0.03
	popup_panel.anchor_right = 0.95
	popup_panel.anchor_bottom = 0.97

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.05, 0.98)
	panel_style.border_color = DungeonTheme.BORDER_GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(0)
	popup_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(popup_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	popup_panel.add_child(root_vbox)

	# Title bar
	var title_bar := PanelContainer.new()
	title_bar.name = "TitleBar"
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.12, 0.08, 0.06, 0.95)
	tb_style.set_content_margin_all(6)
	tb_style.content_margin_left = 12
	tb_style.content_margin_right = 8
	tb_style.corner_radius_top_left = 8
	tb_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", tb_style)
	root_vbox.add_child(title_bar)

	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	title_bar.add_child(title_hbox)

	_title_label = Label.new()
	_title_label.text = title_text
	_title_label.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)
	_title_label.add_theme_color_override("font_color", DungeonTheme.TEXT_GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(_title_label)

	_btn_close = Button.new()
	_btn_close.name = "BtnPopupClose"
	_btn_close.text = "X"
	_btn_close.custom_minimum_size = Vector2(28, 28)
	_btn_close.visible = closable
	_btn_close.add_theme_font_size_override("font_size", DungeonTheme.FONT_LABEL)

	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = Color(0.6, 0.15, 0.15)
	close_normal.set_corner_radius_all(4)
	close_normal.set_content_margin_all(2)
	_btn_close.add_theme_stylebox_override("normal", close_normal)
	_btn_close.add_theme_color_override("font_color", Color.WHITE)

	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = Color(0.85, 0.2, 0.2)
	close_hover.set_corner_radius_all(4)
	close_hover.set_content_margin_all(2)
	_btn_close.add_theme_stylebox_override("hover", close_hover)
	_btn_close.add_theme_color_override("font_hover_color", Color.WHITE)

	var close_pressed := StyleBoxFlat.new()
	close_pressed.bg_color = Color(0.5, 0.1, 0.1)
	close_pressed.set_corner_radius_all(4)
	close_pressed.set_content_margin_all(2)
	_btn_close.add_theme_stylebox_override("pressed", close_pressed)

	_btn_close.pressed.connect(func(): close_requested.emit())
	title_hbox.add_child(_btn_close)

	# Content area
	_content_container = MarginContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_container)


func set_content(panel: Control) -> void:
	_content = panel
	if _content_container == null:
		await ready
	# Remove existing content
	for child in _content_container.get_children():
		_content_container.remove_child(child)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_child(panel)


func get_content() -> Control:
	return _content
