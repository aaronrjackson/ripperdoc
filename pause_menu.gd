extends Control

@onready var resume_button = $VBoxContainer/ResumeButton
@onready var restart_button = $VBoxContainer/RestartButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func open() -> void:
	visible = true
	get_tree().paused = true
	
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_resume_pressed() -> void:
	close()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
