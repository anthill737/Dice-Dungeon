extends PanelContainer
## MinimapPanel — purely visual 2D grid representation of explored rooms.
## Reads from FloorState via GameSession. No gameplay logic; display only.
##
## Python-parity reference: docs/python_minimap_rules.md

const CELL_SIZE_DEFAULT := 18
const CELL_GAP := 2
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.25

## Python-matching room fill colours
const COLOR_CURRENT := Color("#ffd700")      # gold — player room
const COLOR_VISITED := Color("#4a4a4a")      # medium gray
const COLOR_UNVISITED := Color("#666666")    # lighter gray (rooms not yet visited but in dungeon)
const COLOR_ROOM_OUTLINE := Color("#ffffff") # white outline for every room

## Connection/blocked colours
const COLOR_EXIT_LINE := Color("#3a3a3a")    # dashed open-path line
const COLOR_BLOCKED := Color("#ff3333")      # red bars for blocked exits

## Icon colours
const COLOR_ICON_GREEN := Color("#00ff00")
const COLOR_ICON_LOCKED := Color("#ff3333")
const COLOR_ICON_ACTIVE := Color("#ff0000")

## Tooltip
const TOOLTIP_BG := Color(0.08, 0.06, 0.10, 0.92)
const TOOLTIP_TEXT := Color(0.9, 0.85, 0.7)

var _zoom: float = 1.0
var _pan_offset := Vector2.ZERO
var _dragging := false
var _drag_start := Vector2.ZERO
var _pan_start := Vector2.ZERO

var _canvas: Control
var _btn_zoom_in: Button
var _btn_zoom_out: Button
var _btn_center: Button
var _last_floor_index: int = -1
var _needs_center: bool = false  # deferred centering when canvas has no size yet
var _user_interacted: bool = false  # set true on first manual pan/zoom

## Tooltip state
var _tooltip_label: Label
var _hovered_room_pos: Variant = null  # Vector2i or null

## Expose model data for tests (MinimapModel concept)
var model_player_room: Variant = null          # Vector2i
var model_visible_rooms: Array[Vector2i] = []  # rooms that would be drawn
var model_blocked_edges: Array[Dictionary] = [] # [{pos, dir}]
var model_special_markers: Dictionary = {}      # Vector2i -> String marker type
var model_center_target: Variant = null         # Vector2i follow target


func _ready() -> void:
	_build_ui()
	GameSession.state_changed.connect(_on_state_changed)
	_update_model()
	_needs_center = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _needs_center:
		set_process(false)
		return
	if _canvas == null or _canvas.size.x <= 0 or _canvas.size.y <= 0:
		return
	var fs := GameSession.get_floor_state()
	if fs != null:
		_last_floor_index = fs.floor_index
	_center_on_player()
	set_process(false)


func _build_ui() -> void:
	custom_minimum_size = Vector2(200, 200)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.08, 0.9)
	style.set_corner_radius_all(4)
	style.border_color = DungeonTheme.BORDER.darkened(0.2)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var header := DungeonTheme.make_header(
		"Minimap", DungeonTheme.TEXT_GOLD, DungeonTheme.FONT_LABEL)
	vbox.add_child(header)

	_canvas = Control.new()
	_canvas.name = "MinimapCanvas"
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_minimap)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_exited.connect(_on_canvas_mouse_exited)
	_canvas.resized.connect(_on_canvas_resized)
	vbox.add_child(_canvas)

	_tooltip_label = Label.new()
	_tooltip_label.name = "MinimapTooltip"
	_tooltip_label.visible = false
	_tooltip_label.add_theme_font_size_override("font_size", 11)
	_tooltip_label.add_theme_color_override("font_color", TOOLTIP_TEXT)
	_tooltip_label.z_index = 10
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = TOOLTIP_BG
	tip_style.set_corner_radius_all(3)
	tip_style.set_content_margin_all(4)
	_tooltip_label.add_theme_stylebox_override("normal", tip_style)
	_canvas.add_child(_tooltip_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_btn_zoom_out = DungeonTheme.make_styled_btn("−", DungeonTheme.TEXT_SECONDARY, 28)
	_btn_zoom_out.custom_minimum_size = Vector2(28, 24)
	_btn_zoom_out.pressed.connect(_zoom_out)
	btn_row.add_child(_btn_zoom_out)

	_btn_center = DungeonTheme.make_styled_btn("◎", DungeonTheme.TEXT_GOLD, 28)
	_btn_center.custom_minimum_size = Vector2(28, 24)
	_btn_center.pressed.connect(_center_on_player)
	btn_row.add_child(_btn_center)

	_btn_zoom_in = DungeonTheme.make_styled_btn("+", DungeonTheme.TEXT_SECONDARY, 28)
	_btn_zoom_in.custom_minimum_size = Vector2(28, 24)
	_btn_zoom_in.pressed.connect(_zoom_in)
	btn_row.add_child(_btn_zoom_in)


func _on_state_changed() -> void:
	var fs := GameSession.get_floor_state()
	if fs != null and fs.floor_index != _last_floor_index:
		_last_floor_index = fs.floor_index
		_needs_center = true
		_user_interacted = false
	_update_model()
	if _canvas != null:
		_canvas.queue_redraw()


func rebuild_from_state() -> void:
	_update_model()
	_center_on_player()
	if _canvas != null:
		_canvas.queue_redraw()


func get_explored_room_count() -> int:
	var fs := GameSession.get_floor_state()
	if fs == null:
		return 0
	var count := 0
	for pos in fs.rooms:
		var room: RoomState = fs.rooms[pos]
		if room.visited:
			count += 1
	return count


func get_current_room_pos() -> Vector2i:
	var fs := GameSession.get_floor_state()
	if fs == null:
		return Vector2i.ZERO
	return fs.current_pos


# ------------------------------------------------------------------
# Model — testable pure-data representation of what the minimap shows
# ------------------------------------------------------------------

func _update_model() -> void:
	var fs := GameSession.get_floor_state()
	model_visible_rooms.clear()
	model_blocked_edges.clear()
	model_special_markers.clear()
	model_player_room = null
	model_center_target = null

	if fs == null:
		return

	model_player_room = fs.current_pos
	model_center_target = fs.current_pos

	for pos_key in fs.rooms:
		var pos: Vector2i = pos_key
		var room: RoomState = fs.rooms[pos_key]
		model_visible_rooms.append(pos)

		# Blocked edges
		for dir in room.blocked_exits:
			model_blocked_edges.append({"pos": pos, "dir": dir})

		# Special markers
		var marker := _classify_room_marker(room, pos, fs)
		if not marker.is_empty():
			model_special_markers[pos] = marker


## Classify what marker icon a room should display (pure data, no drawing).
func _classify_room_marker(room: RoomState, pos: Vector2i, fs: FloorState) -> String:
	# Locked boss/miniboss (in special_rooms but not unlocked, possibly not visited)
	if fs.special_rooms.has(pos) and not fs.unlocked_rooms.has(pos):
		var stype: String = fs.special_rooms[pos]
		if stype == "boss" or stype == "mini_boss":
			return "locked"

	if room.is_boss_room:
		if room.enemies_defeated:
			return "defeated"
		return "boss_active"

	if room.is_mini_boss_room:
		if room.enemies_defeated:
			return "defeated"
		return "miniboss_active"

	if room.has_stairs:
		return "stairs"

	if room.has_store:
		return "store"

	if room.has_chest and not room.chest_looted:
		return "chest"

	if room.combat_escaped:
		return "escaped"

	return ""


# ------------------------------------------------------------------
# Zoom / Pan
# ------------------------------------------------------------------

func _zoom_in() -> void:
	_user_interacted = true
	_zoom = minf(_zoom + ZOOM_STEP, MAX_ZOOM)
	_canvas.queue_redraw()


func _zoom_out() -> void:
	_user_interacted = true
	_zoom = maxf(_zoom - ZOOM_STEP, MIN_ZOOM)
	_canvas.queue_redraw()


func _center_on_player() -> void:
	var fs := GameSession.get_floor_state()
	if fs == null:
		_pan_offset = Vector2.ZERO
		return
	if _canvas.size.x <= 0 or _canvas.size.y <= 0:
		_needs_center = true
		_canvas.call_deferred("queue_redraw")
		return
	var cell := CELL_SIZE_DEFAULT * _zoom
	var center := _canvas.size / 2.0
	_pan_offset = center - Vector2(fs.current_pos.x, -fs.current_pos.y) * (cell + CELL_GAP)
	_needs_center = false
	_canvas.queue_redraw()


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start = mb.position
				_pan_start = _pan_offset
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_in()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_out()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging:
			_user_interacted = true
			_pan_offset = _pan_start + (mm.position - _drag_start)
			_canvas.queue_redraw()
		else:
			_update_hover(mm.position)


func _on_canvas_resized() -> void:
	if _canvas.size.x > 0 and _canvas.size.y > 0:
		if _needs_center or not _user_interacted:
			_center_on_player()


func _on_canvas_mouse_exited() -> void:
	_hovered_room_pos = null
	if _tooltip_label != null:
		_tooltip_label.visible = false


func _update_hover(mouse_pos: Vector2) -> void:
	var fs := GameSession.get_floor_state()
	if fs == null:
		return
	var cell := CELL_SIZE_DEFAULT * _zoom
	var half := cell / 2.0
	var stride := cell + CELL_GAP * _zoom

	var best_pos: Variant = null
	var best_dist := INF
	for pos_key in fs.rooms:
		var pos: Vector2i = pos_key
		var sx: float = pos.x * stride + _pan_offset.x
		var sy: float = -pos.y * stride + _pan_offset.y
		var rect := Rect2(sx - half, sy - half, cell, cell)
		if rect.has_point(mouse_pos):
			var dist := mouse_pos.distance_squared_to(Vector2(sx, sy))
			if dist < best_dist:
				best_dist = dist
				best_pos = pos

	if best_pos != _hovered_room_pos:
		_hovered_room_pos = best_pos
		_show_tooltip(mouse_pos)


func _show_tooltip(mouse_pos: Vector2) -> void:
	if _tooltip_label == null:
		return
	if _hovered_room_pos == null:
		_tooltip_label.visible = false
		return
	var fs := GameSession.get_floor_state()
	if fs == null or not fs.rooms.has(_hovered_room_pos):
		_tooltip_label.visible = false
		return
	var room: RoomState = fs.rooms[_hovered_room_pos]
	var text := room.room_name
	var marker := _classify_room_marker(room, _hovered_room_pos, fs)
	if not marker.is_empty():
		match marker:
			"stairs": text += " [Stairs]"
			"store": text += " [Store]"
			"boss_active": text += " [Boss]"
			"miniboss_active": text += " [Mini-Boss]"
			"locked": text += " [Locked]"
			"defeated": text += " [Cleared]"
			"chest": text += " [Chest]"
			"escaped": text += " [Fled]"
	_tooltip_label.text = text
	_tooltip_label.visible = true
	# Position tooltip near cursor, clamped to canvas
	var tip_size := _tooltip_label.size
	var tx := mouse_pos.x + 12
	var ty := mouse_pos.y - tip_size.y - 4
	if tx + tip_size.x > _canvas.size.x:
		tx = mouse_pos.x - tip_size.x - 4
	if ty < 0:
		ty = mouse_pos.y + 16
	_tooltip_label.position = Vector2(tx, ty)


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw_minimap() -> void:
	var fs := GameSession.get_floor_state()
	if fs == null:
		return

	var cell := CELL_SIZE_DEFAULT * _zoom
	var half := cell / 2.0
	var gap := CELL_GAP * _zoom
	var stride := cell + gap

	# Defer centering until canvas has a valid size (first frame after layout)
	if _needs_center or _pan_offset == Vector2.ZERO:
		if _canvas.size.x > 0 and _canvas.size.y > 0:
			var center := _canvas.size / 2.0
			_pan_offset = center - Vector2(fs.current_pos.x, -fs.current_pos.y) * stride
			_needs_center = false
		else:
			# Canvas not laid out yet — schedule a retry next frame
			_canvas.call_deferred("queue_redraw")
			return

	for pos_key in fs.rooms:
		var pos: Vector2i = pos_key
		var room: RoomState = fs.rooms[pos_key]

		var screen_x: float = pos.x * stride + _pan_offset.x - half
		var screen_y: float = -pos.y * stride + _pan_offset.y - half
		var rect := Rect2(screen_x, screen_y, cell, cell)

		# Room fill — Python-parity: gold for current, gray for visited/unvisited
		var color := _room_color(pos, room, fs)
		_canvas.draw_rect(rect, color)

		# White outline on every room (Python: outline='#ffffff', width=1)
		_canvas.draw_rect(rect, COLOR_ROOM_OUTLINE, false, 1.0)

		# Current room gets an extra bright border (Godot enhancement for clarity)
		if pos == fs.current_pos:
			_canvas.draw_rect(rect.grow(1.0), COLOR_CURRENT, false, 2.0 * _zoom)

		# Open-path connection lines (drawn from this room towards neighbours)
		_draw_exits(room, pos, screen_x, screen_y, cell, stride, fs)

		# Blocked-exit red bars (Python parity)
		_draw_blocked_bars(room, screen_x + half, screen_y + half, half)

		# Special room icons (zoom >= 0.5 to match Python)
		if _zoom >= 0.5:
			_draw_room_icon(room, pos, Vector2(screen_x + half, screen_y + half), half, fs)


func _room_color(pos: Vector2i, room: RoomState, fs: FloorState) -> Color:
	if pos == fs.current_pos:
		return COLOR_CURRENT
	if room.visited:
		return COLOR_VISITED
	return COLOR_UNVISITED


func _draw_exits(room: RoomState, pos: Vector2i, sx: float, sy: float,
		cell: float, stride: float, fs: FloorState) -> void:
	var half := cell / 2.0
	var cx := sx + half
	var cy := sy + half
	var line_len := stride - cell
	if line_len <= 0:
		return
	for dir in ["N", "S", "E", "W"]:
		if not room.exits.get(dir, false):
			continue
		if dir in room.blocked_exits:
			continue
		var delta := RoomState.dir_delta(dir)
		var neighbor_pos := pos + delta
		if not fs.has_room_at(neighbor_pos):
			continue
		var dx: float = 0
		var dy: float = 0
		match dir:
			"N": dy = -half
			"S": dy = half
			"E": dx = half
			"W": dx = -half
		# Python uses dashed line (#3a3a3a). Godot doesn't support dash natively,
		# so we approximate with a thin semi-transparent line.
		_canvas.draw_line(
			Vector2(cx + dx, cy + dy),
			Vector2(cx + dx + delta.x * line_len, cy + dy - delta.y * line_len),
			COLOR_EXIT_LINE, maxf(1.0, _zoom))


func _draw_blocked_bars(room: RoomState, cx: float, cy: float, half: float) -> void:
	var bar_length := half * 1.5
	var bar_width := maxf(2.0, 3.0 * _zoom)
	for dir in room.blocked_exits:
		match dir:
			"N":
				_canvas.draw_line(
					Vector2(cx - bar_length, cy - half),
					Vector2(cx + bar_length, cy - half),
					COLOR_BLOCKED, bar_width)
			"S":
				_canvas.draw_line(
					Vector2(cx - bar_length, cy + half),
					Vector2(cx + bar_length, cy + half),
					COLOR_BLOCKED, bar_width)
			"E":
				_canvas.draw_line(
					Vector2(cx + half, cy - bar_length),
					Vector2(cx + half, cy + bar_length),
					COLOR_BLOCKED, bar_width)
			"W":
				_canvas.draw_line(
					Vector2(cx - half, cy - bar_length),
					Vector2(cx - half, cy + bar_length),
					COLOR_BLOCKED, bar_width)


func _draw_room_icon(room: RoomState, pos: Vector2i, center: Vector2,
		half: float, fs: FloorState) -> void:
	var icon_size := half * 0.6
	var marker := _classify_room_marker(room, pos, fs)
	match marker:
		"locked":
			_draw_skull(center, icon_size, COLOR_ICON_LOCKED)
		"boss_active":
			_draw_skull(center, icon_size, COLOR_ICON_ACTIVE)
		"miniboss_active":
			_draw_skull(center, icon_size, COLOR_ICON_ACTIVE)
		"defeated":
			_draw_checkmark(center, icon_size)
		"stairs":
			_draw_stairs_icon(center, icon_size)
		"store":
			_draw_store_icon(center, icon_size)
		"chest":
			_draw_chest_icon(center, icon_size)
		"escaped":
			_draw_cross(center, icon_size)


# ------------------------------------------------------------------
# Icon drawing helpers
# ------------------------------------------------------------------

func _draw_skull(center: Vector2, s: float, tint: Color) -> void:
	_canvas.draw_circle(center - Vector2(0, s * 0.15), s * 0.5, tint)
	_canvas.draw_rect(Rect2(center.x - s * 0.35, center.y + s * 0.15,
		s * 0.7, s * 0.35), tint)
	_canvas.draw_circle(center + Vector2(-s * 0.18, -s * 0.15), s * 0.12, Color.BLACK)
	_canvas.draw_circle(center + Vector2(s * 0.18, -s * 0.15), s * 0.12, Color.BLACK)


func _draw_checkmark(center: Vector2, s: float) -> void:
	var lw := maxf(1.5, s * 0.25)
	_canvas.draw_line(
		center + Vector2(-s * 0.4, 0),
		center + Vector2(-s * 0.1, s * 0.35),
		COLOR_ICON_GREEN, lw)
	_canvas.draw_line(
		center + Vector2(-s * 0.1, s * 0.35),
		center + Vector2(s * 0.4, -s * 0.35),
		COLOR_ICON_GREEN, lw)


func _draw_stairs_icon(center: Vector2, s: float) -> void:
	var step_h := s * 0.5
	var step_w := s * 0.5
	for i in 3:
		var x := center.x - s + i * step_w
		var y := center.y + s * 0.5 - i * step_h
		_canvas.draw_rect(Rect2(x, y, step_w, step_h), COLOR_ICON_GREEN)


func _draw_store_icon(center: Vector2, s: float) -> void:
	# Dollar sign approximation — matches Python "$" glyph
	_canvas.draw_circle(center, s * 0.5, COLOR_ICON_GREEN)
	_canvas.draw_circle(center, s * 0.3, Color(0.0, 0.6, 0.0))


func _draw_chest_icon(center: Vector2, s: float) -> void:
	_canvas.draw_rect(Rect2(center.x - s * 0.5, center.y - s * 0.3,
		s, s * 0.6), Color(0.85, 0.75, 0.2))
	_canvas.draw_rect(Rect2(center.x - s * 0.1, center.y - s * 0.1,
		s * 0.2, s * 0.2), Color(0.6, 0.5, 0.1))


func _draw_cross(center: Vector2, s: float) -> void:
	var lw := maxf(1.0, s * 0.2)
	_canvas.draw_line(center + Vector2(-s, -s) * 0.5, center + Vector2(s, s) * 0.5,
		Color(0.7, 0.3, 0.3), lw)
	_canvas.draw_line(center + Vector2(s, -s) * 0.5, center + Vector2(-s, s) * 0.5,
		Color(0.7, 0.3, 0.3), lw)
