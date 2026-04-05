extends Control

@onready var base = $Layers/Base

var death_tween: Tween = null

func _ready() -> void:
	GameManager.character_died.connect(_on_character_died)
	GameManager.character_loaded.connect(_on_character_loaded)

func _on_character_died() -> void:
	var mat = base.material as ShaderMaterial
	if mat == null:
		return
	death_tween = create_tween()
	death_tween.tween_method(
		func(v): mat.set_shader_parameter("glitch_intensity", v), 0.0, 1.5, 5)
	death_tween.tween_interval(4.0) # wait 2 seconds before fading
	death_tween.tween_property(base, "modulate:a", 0.0, 6)

func _on_character_loaded(character: Character) -> void:
	# kill any running death tween before resetting
	if death_tween != null and death_tween.is_running():
		death_tween.kill()
	var mat = base.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glitch_intensity", 0.0)
	base.modulate.a = 1.0
