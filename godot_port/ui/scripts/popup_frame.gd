extends Control
## Shared modal popup wrapper. Provides dim background, centered panel with
## gold border, title bar with red ✕ close button, and a content slot.
##
## Sizing is controlled by `size_config` (set by MenuOverlayManager before
## this node enters the tree). The sizing formula lives in _apply_sizing().

signal close_requested()

var _title_label: Label
var _btn_close: Button
var _content_container: MarginContainer
var _popup_panel: Control
var _content: Control

## Sizing parameters — set by MenuOverlayManager.register_menu() from SIZE_PROFILES.
var size_config: Dictionary = {}

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
	if is_inside_tree():
		call_deferred("_apply_sizing")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_inside_tree():
			_apply_sizing()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_popup_panel = Control.new()
	_popup_panel.name = "PopupPanel"
	_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup_panel)

	var visual_bg := Panel.new()
	visual_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.07, 0.05, 0.98)
	panel_style.border_color = DungeonTheme.BORDER_GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	visual_bg.add_theme_stylebox_override("panel", panel_style)
	_popup_panel.add_child(visual_bg)

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 0)
	_popup_panel.add_child(inner)

	# Title bar
	var title_bar := PanelContainer.new()
	title_bar.name = "TitleBar"
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.12, 0.08, 0.06, 0.95)
	tb_style.set_content_margin_all(6)
	tb_style.content_margin_left = 14
	tb_style.content_margin_right = 8
	tb_style.corner_radius_top_left = 6
	tb_style.corner_radius_top_right = 6
	title_bar.add_theme_stylebox_override("panel", tb_style)
	inner.add_child(title_bar)

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
	_btn_close.text = "✕"
	_btn_close.custom_minimum_size = Vector2(28, 28)
	_btn_close.visible = closable
	_btn_close.add_theme_font_size_override("font_size", DungeonTheme.FONT_BODY)

	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = Color(0.65, 0.15, 0.15)
	close_normal.set_corner_radius_all(4)
	close_normal.set_content_margin_all(2)
	_btn_close.add_theme_stylebox_override("normal", close_normal)
	_btn_close.add_theme_color_override("font_color", Color.WHITE)

	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = Color(0.9, 0.2, 0.2)
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

	# Content area with padding
	_content_container = MarginContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("margin_left", 10)
	_content_container.add_theme_constant_override("margin_right", 10)
	_content_container.add_theme_constant_override("margin_top", 6)
	_content_container.add_theme_constant_override("margin_bottom", 10)
	inner.add_child(_content_container)


func _apply_sizing() -> void:
	if _popup_panel == null:
		return
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	# Mimic Python: max(base, min(base*1.5, int(window * percent)))
	var base_w: float = float(size_config.get("base_w", 450))
	var base_h: float = float(size_config.get("base_h", 500))
	var w_pct: float = float(size_config.get("width_pct", 0.45))
	var h_pct: float = float(size_config.get("height_pct", 0.75))

	var max_w: float = base_w * 1.5
	var max_h: float = base_h * 1.5
	var target_w: float = maxf(base_w, minf(max_w, vp_size.x * w_pct))
	var target_h: float = maxf(base_h, minf(max_h, vp_size.y * h_pct))

	# Clamp to viewport
	target_w = minf(target_w, vp_size.x * 0.95)
	target_h = minf(target_h, vp_size.y * 0.95)

	# Center
	var margin_x: float = (vp_size.x - target_w) / 2.0
	var margin_y: float = (vp_size.y - target_h) / 2.0

	_popup_panel.anchor_left = margin_x / vp_size.x
	_popup_panel.anchor_top = margin_y / vp_size.y
	_popup_panel.anchor_right = (margin_x + target_w) / vp_size.x
	_popup_panel.anchor_bottom = (margin_y + target_h) / vp_size.y
	_popup_panel.offset_left = 0
	_popup_panel.offset_top = 0
	_popup_panel.offset_right = 0
	_popup_panel.offset_bottom = 0


func set_content(panel: Control) -> void:
	_content = panel
	if _content_container == null:
		await ready
	for child in _content_container.get_children():
		_content_container.remove_child(child)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_child(panel)


func get_content() -> Control:
	return _content


func get_popup_panel() -> Control:
	return _popup_panel
