extends Control

@onready var base = $Layers/Base
@onready var death_sound = $DeathPlayer
@onready var flatline_sound = $FlatlinePlayer

var flatline_tween: Tween = null
var death_tween: Tween = null
var dismiss_tween: Tween = null

func _ready() -> void:
	GameManager.character_died.connect(_on_character_died)
	GameManager.character_loaded.connect(_on_character_loaded)
	GameManager.character_dismissed.connect(_on_character_dismissed)

func _get_mat() -> ShaderMaterial:
	return base.material as ShaderMaterial

func _on_character_dismissed() -> void:
	var mat = _get_mat()
	if mat == null:
		return
	if dismiss_tween != null and dismiss_tween.is_running():
		dismiss_tween.kill()
	dismiss_tween = create_tween()
	dismiss_tween.tween_method(
		func(v): mat.set_shader_parameter("opacity", v), 1.0, 0.0, 2.0)

func _on_character_died() -> void:
	death_sound.play()
	flatline_sound.play()
	flatline_sound.volume_db = -32.0

	flatline_tween = create_tween()
	flatline_tween.tween_interval(4.0)
	flatline_tween.tween_method(
		func(v): flatline_sound.volume_db = v, -32.0, -80.0, 4.0)
	flatline_tween.tween_callback(func(): flatline_sound.stop())

	var mat = _get_mat()
	if mat == null:
		return
	death_tween = create_tween()
	death_tween.tween_method(
		func(v): mat.set_shader_parameter("glitch_intensity", v), 0.0, 1.8, 3.5)
	death_tween.tween_interval(4.0)
	death_tween.tween_method(
		func(v): mat.set_shader_parameter("opacity", v), 1.0, 0.0, 6.0)

func _on_character_loaded(character: Character) -> void:
	flatline_sound.stop()

	if death_tween != null and death_tween.is_running():
		death_tween.kill()
	if dismiss_tween != null and dismiss_tween.is_running():
		dismiss_tween.kill()

	var mat = _get_mat()
	if mat == null:
		return
	mat.set_shader_parameter("glitch_intensity", 0.0)
	mat.set_shader_parameter("opacity", 0.0)

	var fade_in = create_tween()
	fade_in.tween_method(
		func(v): mat.set_shader_parameter("opacity", v), 0.0, 1.0, 2.0)
