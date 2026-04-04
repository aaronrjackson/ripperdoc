extends Control

@onready var load_dial = $VBoxContainer/HBoxContainer/LoadDial
@onready var pressure_dial = $VBoxContainer/HBoxContainer/PressureDial

func _ready() -> void:
	GameManager.vitals_changed.connect(_on_vitals_changed)
	GameManager.patient_died.connect(_on_patient_died)
	GameManager.character_loaded.connect(_on_character_loaded)

func _on_vitals_changed(load: float, pressure: float) -> void:
	load_dial.fill = load
	load_dial.queue_redraw()
	pressure_dial.fill = pressure
	pressure_dial.queue_redraw()

func _on_patient_died() -> void:
	print("patient is dead!")
	pass
	# TODO: flatline animation, lock display, etc.

func _on_character_loaded(character: Character) -> void:
	load_dial.set_fill(0.0)
	load_dial.queue_redraw()
	pressure_dial.set_fill(0.0)
	pressure_dial.queue_redraw()
