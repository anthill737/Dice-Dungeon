extends Control
## Main Menu — entry point for the game.
## Buttons: Start Adventure, Load Game, Settings, Quit.

@onready var _btn_start: Button = $VBox/BtnStart
@onready var _btn_load: Button = $VBox/BtnLoad
@onready var _btn_settings: Button = $VBox/BtnSettings
@onready var _btn_quit: Button = $VBox/BtnQuit

var _settings_panel: Control
var _settings_scene := preload("res://ui/scenes/SettingsPanel.tscn")


func _ready() -> void:
	_btn_start.pressed.connect(_on_start)
	_btn_load.pressed.connect(_on_load)
	_btn_settings.pressed.connect(_on_settings)
	_btn_quit.pressed.connect(_on_quit)

	_settings_panel = _settings_scene.instantiate()
	_settings_panel.visible = false
	add_child(_settings_panel)
	if _settings_panel.has_signal("close_requested"):
		_settings_panel.close_requested.connect(func(): _settings_panel.visible = false)


func _on_start() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file("res://ui/scenes/Explorer.tscn")


func _on_load() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file("res://ui/scenes/Explorer.tscn")
	GameSession.log_message.emit("Load panel opened — select a slot.")


func _on_settings() -> void:
	_settings_panel.visible = true
	if _settings_panel.has_method("refresh"):
		_settings_panel.refresh()


func _on_quit() -> void:
	get_tree().quit()
