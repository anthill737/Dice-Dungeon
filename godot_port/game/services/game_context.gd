class_name GameContext
extends RefCounted
## Scene-scoped service registry.
##
## Instantiated by the Explorer root (and MainMenu when needed).
## Holds typed references to the small set of coordination services so
## UI panels never need to traverse the scene tree for deep game state.
##
## Usage:
##   var ctx := GameContext.new()           # creates all owned services
##   ctx.set_menus(overlay_manager)         # set after OverlayManager is ready
##   some_panel.context = ctx               # inject into UI

var content: ContentManager
var save_load: SaveLoadService
var session: SessionService
var log: AdventureLogService

var menus  # MenuOverlayManager — set by caller after overlay setup
var settings: Node  # SettingsManager autoload reference (may be null in tests)


func _init() -> void:
	content = ContentManager.new()
	content.load_all()

	save_load = SaveLoadService.new()
	log = AdventureLogService.new()

	var gs = _resolve_game_session()
	if gs:
		session = SessionService.new(gs)
		settings = _resolve_settings_manager()
	else:
		session = null


func set_menus(overlay_manager) -> void:
	menus = overlay_manager


func _resolve_game_session():
	if Engine.has_singleton("GameSession"):
		return Engine.get_singleton("GameSession")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("GameSession")
	return null


func _resolve_settings_manager():
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("SettingsManager")
	return null
