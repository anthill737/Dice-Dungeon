extends PanelContainer
## MinimapPanel — purely visual 2D grid representation of explored rooms.
## Reads from FloorState via GameSession. No gameplay logic; display only.

const CELL_SIZE_DEFAULT := 18
const CELL_GAP := 2
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.25

## Room-type colours
const COLOR_NORMAL := Color(0.35, 0.55, 0.35)
const COLOR_COMBAT := Color(0.75, 0.20, 0.20)
const COLOR_CHEST := Color(0.85, 0.75, 0.20)
const COLOR_STORE := Color(0.25, 0.55, 0.85)
const COLOR_STAIRS := Color(0.55, 0.85, 0.55)
const COLOR_MINIBOSS := Color(0.80, 0.45, 0.15)
const COLOR_BOSS := Color(0.85, 0.15, 0.60)
const COLOR_ESCAPED := Color(0.45, 0.40, 0.40)
const COLOR_CURRENT_BORDER := Color(1.0, 1.0, 1.0)
const COLOR_CLEARED := Color(0.30, 0.50, 0.30)
const COLOR_EXIT_LINE := Color(0.6, 0.6, 0.6, 0.5)

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


func _ready() -> void:
	_build_ui()
	GameSession.state_changed.connect(_on_state_changed)


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
	vbox.add_child(_canvas)

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
		_pan_offset = Vector2.ZERO
	if _canvas != null:
		_canvas.queue_redraw()


func rebuild_from_state() -> void:
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


func _zoom_in() -> void:
	_zoom = minf(_zoom + ZOOM_STEP, MAX_ZOOM)
	_canvas.queue_redraw()


func _zoom_out() -> void:
	_zoom = maxf(_zoom - ZOOM_STEP, MIN_ZOOM)
	_canvas.queue_redraw()


func _center_on_player() -> void:
	var fs := GameSession.get_floor_state()
	if fs == null:
		_pan_offset = Vector2.ZERO
		return
	var cell := CELL_SIZE_DEFAULT * _zoom
	var center := _canvas.size / 2.0
	_pan_offset = center - Vector2(fs.current_pos.x, -fs.current_pos.y) * (cell + CELL_GAP)
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
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_pan_offset = _pan_start + (mm.position - _drag_start)
		_canvas.queue_redraw()


func _draw_minimap() -> void:
	var fs := GameSession.get_floor_state()
	if fs == null:
		return

	var cell := CELL_SIZE_DEFAULT * _zoom
	var half := cell / 2.0
	var gap := CELL_GAP * _zoom
	var stride := cell + gap

	if _pan_offset == Vector2.ZERO:
		var center := _canvas.size / 2.0
		_pan_offset = center - Vector2(fs.current_pos.x, -fs.current_pos.y) * stride

	for pos_key in fs.rooms:
		var pos: Vector2i = pos_key
		var room: RoomState = fs.rooms[pos_key]
		if not room.visited:
			continue

		var screen_x: float = pos.x * stride + _pan_offset.x - half
		var screen_y: float = -pos.y * stride + _pan_offset.y - half
		var rect := Rect2(screen_x, screen_y, cell, cell)

		var color := _room_color(room, pos, fs)
		_canvas.draw_rect(rect, color)

		_draw_room_icon(room, Vector2(screen_x + half, screen_y + half), half)

		if pos == fs.current_pos:
			_canvas.draw_rect(rect, COLOR_CURRENT_BORDER, false, 2.0 * _zoom)

		_draw_exits(room, pos, screen_x, screen_y, cell, stride, fs)


func _room_color(room: RoomState, pos: Vector2i, fs: FloorState) -> Color:
	if room.combat_escaped:
		return COLOR_ESCAPED
	if room.is_boss_room:
		return COLOR_BOSS if not room.enemies_defeated else COLOR_CLEARED
	if room.is_mini_boss_room:
		return COLOR_MINIBOSS if not room.enemies_defeated else COLOR_CLEARED
	if room.has_stairs:
		return COLOR_STAIRS
	if room.has_store:
		return COLOR_STORE
	if room.has_chest and not room.chest_looted:
		return COLOR_CHEST
	if room.has_combat and not room.enemies_defeated and not room.combat_escaped:
		return COLOR_COMBAT
	return COLOR_NORMAL


func _draw_room_icon(room: RoomState, center: Vector2, half: float) -> void:
	var icon_size := half * 0.6
	if room.is_boss_room and not room.enemies_defeated:
		_draw_skull(center, icon_size)
	elif room.is_mini_boss_room and not room.enemies_defeated:
		_draw_diamond(center, icon_size)
	elif room.has_stairs:
		_draw_stairs_icon(center, icon_size)
	elif room.has_store:
		_draw_coin_icon(center, icon_size)
	elif room.has_chest and not room.chest_looted:
		_draw_chest_icon(center, icon_size)
	elif room.combat_escaped:
		_draw_cross(center, icon_size)


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
		var nr: RoomState = fs.rooms[neighbor_pos]
		if not nr.visited:
			continue
		var dx: float = 0
		var dy: float = 0
		match dir:
			"N": dy = -half
			"S": dy = half
			"E": dx = half
			"W": dx = -half
		_canvas.draw_line(
			Vector2(cx + dx, cy + dy),
			Vector2(cx + dx + delta.x * line_len, cy + dy - delta.y * line_len),
			COLOR_EXIT_LINE, 1.0 * _zoom)


func _draw_skull(center: Vector2, s: float) -> void:
	_canvas.draw_circle(center - Vector2(0, s * 0.15), s * 0.5, Color.WHITE)
	_canvas.draw_rect(Rect2(center.x - s * 0.35, center.y + s * 0.15,
		s * 0.7, s * 0.35), Color.WHITE)
	_canvas.draw_circle(center + Vector2(-s * 0.18, -s * 0.15), s * 0.12, Color.BLACK)
	_canvas.draw_circle(center + Vector2(s * 0.18, -s * 0.15), s * 0.12, Color.BLACK)


func _draw_diamond(center: Vector2, s: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -s),
		center + Vector2(s, 0),
		center + Vector2(0, s),
		center + Vector2(-s, 0),
	])
	_canvas.draw_colored_polygon(pts, Color.WHITE)


func _draw_stairs_icon(center: Vector2, s: float) -> void:
	var step_h := s * 0.5
	var step_w := s * 0.5
	for i in 3:
		var x := center.x - s + i * step_w
		var y := center.y + s * 0.5 - i * step_h
		_canvas.draw_rect(Rect2(x, y, step_w, step_h), Color.WHITE)


func _draw_coin_icon(center: Vector2, s: float) -> void:
	_canvas.draw_circle(center, s * 0.5, Color(1, 0.85, 0.3))
	_canvas.draw_circle(center, s * 0.3, Color(0.9, 0.7, 0.1))


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
