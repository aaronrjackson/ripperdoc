extends Control

@onready var restart_button = $VBoxContainer/RestartButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func open() -> void:
	visible = true

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
