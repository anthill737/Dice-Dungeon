extends CanvasLayer
## Centralized manager for modal popup menus in Explorer Mode.
## Maintains a LIFO stack of open menus. Provides:
##   - open_menu(menu_key) / close_top_menu()
##   - ESC routing: close topmost, or toggle pause if nothing open
##   - Modal input blocking via the PopupFrame dim background
##
## Menu keys: "combat", "inventory", "character_status", "save_load",
##            "lore_codex", "store", "settings", "pause"

signal menu_opened(menu_key: String)
signal menu_closed(menu_key: String)

var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")

var _popup_root: Control
var _popups: Dictionary = {}        # menu_key -> PopupFrame instance
var _contents: Dictionary = {}      # menu_key -> content Control
var _stack: Array[String] = []      # LIFO stack of open menu keys
var _can_close_overrides: Dictionary = {}  # menu_key -> Callable returning bool

const FADE_DURATION := 0.12


func _ready() -> void:
	layer = 100
	_popup_root = Control.new()
	_popup_root.name = "PopupRoot"
	_popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_root.set_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup_root)


func register_menu(menu_key: String, title: String, content: Control,
		can_close_fn: Callable = Callable()) -> void:
	var frame = PopupFrameScript.new()
	frame.title_text = title
	frame.visible = false
	frame.modulate.a = 0.0
	frame.set_content(content)
	frame.close_requested.connect(_on_popup_close_requested.bind(menu_key))
	_popup_root.add_child(frame)
	_popups[menu_key] = frame
	_contents[menu_key] = content
	if can_close_fn.is_valid():
		_can_close_overrides[menu_key] = can_close_fn


func open_menu(menu_key: String) -> void:
	if not _popups.has(menu_key):
		return
	var frame = _popups[menu_key]
	if frame.visible:
		return
	frame.visible = true
	frame.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(frame, "modulate:a", 1.0, FADE_DURATION)
	_stack.erase(menu_key)
	_stack.push_back(menu_key)

	# Update closable state
	frame.closable = can_close(menu_key)

	# Refresh content if it has a refresh method
	var content = _contents.get(menu_key)
	if content != null and content.has_method("refresh"):
		content.refresh()

	menu_opened.emit(menu_key)


func close_menu(menu_key: String) -> void:
	if not _popups.has(menu_key):
		return
	var frame = _popups[menu_key]
	if not frame.visible:
		return
	_stack.erase(menu_key)
	var tween: Tween = create_tween()
	tween.tween_property(frame, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): frame.visible = false)
	menu_closed.emit(menu_key)


func close_top_menu() -> bool:
	while not _stack.is_empty():
		var key: String = _stack.pop_back()
		var frame = _popups.get(key)
		if frame == null or not frame.visible:
			continue
		if not can_close(key):
			_stack.push_back(key)
			return true  # blocked — stop processing
		close_menu(key)
		return true
	return false


func close_all_menus() -> void:
	for key in _popups:
		if can_close(key):
			var frame = _popups[key]
			if frame.visible:
				frame.visible = false
				frame.modulate.a = 0.0
				_stack.erase(key)
				menu_closed.emit(key)


func can_close(menu_key: String) -> bool:
	if _can_close_overrides.has(menu_key):
		var fn: Callable = _can_close_overrides[menu_key]
		if fn.is_valid():
			return fn.call()
	return true


func is_any_open() -> bool:
	for key in _popups:
		if _popups[key].visible:
			return true
	return false


func is_menu_open(menu_key: String) -> bool:
	return _popups.has(menu_key) and _popups[menu_key].visible


func get_top_menu_key() -> String:
	for i in range(_stack.size() - 1, -1, -1):
		var key: String = _stack[i]
		if _popups.has(key) and _popups[key].visible:
			return key
	return ""


func get_frame(menu_key: String):
	return _popups.get(menu_key)


func get_content(menu_key: String) -> Control:
	return _contents.get(menu_key)


func get_stack() -> Array[String]:
	return _stack


func _on_popup_close_requested(menu_key: String) -> void:
	if can_close(menu_key):
		close_menu(menu_key)
