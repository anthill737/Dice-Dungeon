extends CanvasLayer
## Centralized modal popup manager. Single authority for popup sizing,
## registration, stacking (LIFO), and close-gating.
##
## Size profiles mirror Python get_responsive_dialog_size():
##   size = max(base, min(base * 1.5, viewport * pct))
##
## Usage:
##   manager.register_menu("inventory", "🎒 INVENTORY", panel, "inventory")
##   manager.open_menu("inventory")

signal menu_opened(menu_key: String)
signal menu_closed(menu_key: String)

var PopupFrameScript := preload("res://ui/scripts/popup_frame.gd")
const _SfxService := preload("res://game/services/sfx_service.gd")
const MENU_SFX_KEYS := {
	"inventory": true,
	"settings": true,
	"save_load": true,
	"character_status": true,
	"lore_codex": true,
	"pause": true,
	"tutorial": true,
	"start_adventure": true,
}

var _popup_root: Control
var _popups: Dictionary = {}
var _contents: Dictionary = {}
var _stack: Array[String] = []
var _can_close_overrides: Dictionary = {}
var _active_tweens: Array[Tween] = []

const FADE_DURATION := 0.12

## Canonical size profiles — base_w, base_h, width_pct, height_pct
## Mirrors Python get_responsive_dialog_size(base_w, base_h, w_pct, h_pct)
const SIZE_PROFILES := {
	"pause":     {"base_w": 350, "base_h": 300, "width_pct": 0.35, "height_pct": 0.45},
	"inventory": {"base_w": 450, "base_h": 500, "width_pct": 0.45, "height_pct": 0.75},
	"settings":  {"base_w": 500, "base_h": 500, "width_pct": 0.45, "height_pct": 0.70},
	"store":     {"base_w": 500, "base_h": 500, "width_pct": 0.50, "height_pct": 0.75},
	"combat":    {"base_w": 700, "base_h": 600, "width_pct": 0.65, "height_pct": 0.85},
	"status":    {"base_w": 650, "base_h": 600, "width_pct": 0.65, "height_pct": 0.85},
	"lore":      {"base_w": 650, "base_h": 600, "width_pct": 0.65, "height_pct": 0.85},
	"save_load": {"base_w": 700, "base_h": 550, "width_pct": 0.70, "height_pct": 0.80},
	"start_adventure": {"base_w": 380, "base_h": 350, "width_pct": 0.35, "height_pct": 0.50},
	"dev_menu": {"base_w": 400, "base_h": 450, "width_pct": 0.35, "height_pct": 0.60},
	"tutorial": {"base_w": 800, "base_h": 700, "width_pct": 0.80, "height_pct": 0.90},
}


func _ready() -> void:
	layer = 100
	_popup_root = Control.new()
	_popup_root.name = "PopupRoot"
	_popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_root.set_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup_root)


func _exit_tree() -> void:
	for tw in _active_tweens:
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
	_active_tweens.clear()
	_stack.clear()
	_popups.clear()
	_contents.clear()
	_can_close_overrides.clear()


func register_menu(menu_key: String, title: String, content: Control,
		size_profile: String = "inventory",
		can_close_fn: Callable = Callable()) -> void:
	var profile: Dictionary = SIZE_PROFILES.get(size_profile, SIZE_PROFILES["inventory"])
	var frame = PopupFrameScript.new()
	frame.title_text = title
	frame.size_config = profile.duplicate()
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

	if frame.has_method("_apply_sizing"):
		frame._apply_sizing()

	if is_inside_tree():
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_property(frame, "modulate:a", 1.0, FADE_DURATION)
	else:
		frame.modulate.a = 1.0
	_stack.erase(menu_key)
	_stack.push_back(menu_key)

	frame.closable = can_close(menu_key)

	var content = _contents.get(menu_key)
	if content != null and content.has_method("refresh"):
		content.refresh()

	if MENU_SFX_KEYS.has(menu_key):
		_SfxService.play_for(self, "menu_open")
	menu_opened.emit(menu_key)


func close_menu(menu_key: String) -> void:
	if not _popups.has(menu_key):
		return
	var frame = _popups[menu_key]
	if not frame.visible:
		return
	_stack.erase(menu_key)
	if is_inside_tree():
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_property(frame, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(func():
			if is_instance_valid(frame):
				frame.visible = false)
	else:
		frame.visible = false
	if MENU_SFX_KEYS.has(menu_key):
		_SfxService.play_for(self, "menu_close")
	menu_closed.emit(menu_key)


func close_top_menu() -> bool:
	while not _stack.is_empty():
		var key: String = _stack.pop_back()
		var frame = _popups.get(key)
		if frame == null or not frame.visible:
			continue
		if not can_close(key):
			_stack.push_back(key)
			return true
		close_menu(key)
		return true
	return false


func close_all_menus() -> void:
	for key in _popups:
		if can_close(key):
			var frame = _popups[key]
			if is_instance_valid(frame) and frame.visible:
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
		var frame = _popups[key]
		if is_instance_valid(frame) and frame.visible:
			return true
	return false


func is_menu_open(menu_key: String) -> bool:
	if not _popups.has(menu_key):
		return false
	var frame = _popups[menu_key]
	return is_instance_valid(frame) and frame.visible


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


func _track_tween(tw: Tween) -> void:
	_active_tweens.append(tw)
	tw.finished.connect(func(): _active_tweens.erase(tw))
