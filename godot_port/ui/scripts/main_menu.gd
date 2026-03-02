extends Control
## Main Menu — entry point for the game.
## Buttons: Start Adventure, Load Game, Settings (stub), Quit.

@onready var _btn_start: Button = $VBox/BtnStart
@onready var _btn_load: Button = $VBox/BtnLoad
@onready var _btn_settings: Button = $VBox/BtnSettings
@onready var _btn_quit: Button = $VBox/BtnQuit


func _ready() -> void:
	_btn_start.pressed.connect(_on_start)
	_btn_load.pressed.connect(_on_load)
	_btn_settings.pressed.connect(_on_settings)
	_btn_quit.pressed.connect(_on_quit)


func _on_start() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file("res://ui/scenes/Explorer.tscn")


func _on_load() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file("res://ui/scenes/Explorer.tscn")
	# The Explorer scene will show the SaveLoad panel automatically
	GameSession.log_message.emit("Load panel opened — select a slot.")


func _on_settings() -> void:
	pass  # stub


func _on_quit() -> void:
	get_tree().quit()
