extends Control

@onready var pause_menu = $PauseMenu
@onready var game_over_screen = $GameOverScreen
@onready var ambience = $AmbiencePlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambience.finished.connect(func(): ambience.play())
	ambience.play()
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.start()
	GameManager.game_over.connect(_on_game_over)  # ← was character_died

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if game_over_screen.visible:
			return
		if pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()

func _on_game_over() -> void:
	await get_tree().create_timer(4.0).timeout
	game_over_screen.open()
