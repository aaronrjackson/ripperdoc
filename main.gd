extends Node

@onready var ambience = $AmbiencePlayer

func _ready() -> void:
	ambience.finished.connect(func(): ambience.play())
	ambience.play()
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.start()
