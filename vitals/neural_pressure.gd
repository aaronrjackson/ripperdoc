extends Panel

@export var radius := 100
@export var fill := 0.0
@export var epsilon = 0.05

var time: float

func _ready() -> void:
	GameManager.vitals_changed.connect(_on_vitals_changed)
	GameManager.character_loaded.connect(_on_character_loaded)
	queue_redraw()

func _on_character_loaded(character: Character) -> void:
	fill = 0.0
	queue_redraw()

func _on_vitals_changed(load: float, pressure: float) -> void:
	fill = pressure
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw():
	var center = size / 2
	var r = min(size.x, size.y) * 0.5
	
	var noise = (
		sin(time * 3.7) * 0.006 +
		sin(time * 11.3) * 0.004 +
		sin(time * 23.7) * 0.0025 +
		sin(time * 47.1) * 0.002 +
		sin(time * 97.3 + 1.4) * 0.0015 +
		randf_range(-0.0015, 0.0015)
	)
	var display_fill = clamp(fill + noise, 0.0, 1.0)
	
	var sweep = display_fill * ((4 * PI) / 3)
	var arc_width = r * 1.0
	
	draw_circle(center, r, Color("fd0156ff"))
	draw_circle(center, r - (r * 0.04), Color("121016ff"))
	draw_arc(center, r * 0.46, ((5 * PI) / 6) - epsilon, ((5 * PI) / 6) + sweep + epsilon, 100, Color("008df1ff"), arc_width)
	draw_arc(center, r * 0.50, ((5 * PI) / 6), (PI / 6), 100, Color("fd0156ff"), arc_width)
	draw_circle(center, r * 0.36, Color("fd0156ff"))

func set_fill(value: float) -> void:
	fill = clamp(value, 0.0, 1.0)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
