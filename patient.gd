extends Control

@onready var base = $Layers/Base
@onready var death_sound = $DeathPlayer
@onready var flatline_sound = $FlatlinePlayer

var flatline_tween: Tween = null
var death_tween: Tween = null

func _ready() -> void:
	GameManager.character_died.connect(_on_character_died)
	GameManager.character_loaded.connect(_on_character_loaded)

func _on_character_died() -> void:
	death_sound.play()
	flatline_sound.play()
	flatline_sound.volume_db = -32.0
	# start fade after a delay
	flatline_tween = create_tween()
	flatline_tween.tween_interval(4.0)  # play at full volume for 5 seconds
	flatline_tween.tween_method(
		func(v): flatline_sound.volume_db = v, -32.0, -80.0, 4.0)  # fade over 4 seconds
	flatline_tween.tween_callback(func(): flatline_sound.stop())
	
	var mat = base.material as ShaderMaterial
	if mat == null:
		return
	death_tween = create_tween()
	death_tween.tween_method(
		func(v): mat.set_shader_parameter("glitch_intensity", v), 0.0, 1.8, 3.5)
	death_tween.tween_interval(4.0) # wait 2 seconds before fading
	death_tween.tween_property(base, "modulate:a", 0.0, 6)

func _on_character_loaded(character: Character) -> void:
	flatline_sound.stop()
	# kill any running death tween before resetting
	if death_tween != null and death_tween.is_running():
		death_tween.kill()
	var mat = base.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glitch_intensity", 0.0)
	base.modulate.a = 1.0
