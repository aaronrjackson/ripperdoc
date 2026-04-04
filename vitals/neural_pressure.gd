extends Panel

@export var radius := 100
@export var fill := 0.3 # 0.0 - 1.0

func _draw():
	var center = size / 2
	var sweep = fill * ((4 * PI) / 3)  # map 0.0-1.0 to full arc range
	
	draw_circle(center, radius, Color("fd0156ff"))
	draw_circle(center, radius - 8, Color("121016ff"))
	draw_arc(center, 42, ((5 * PI) / 6), ((5 * PI) / 6) + sweep, 100, Color(0.012, 0.533, 1.0, 1.0), 100)  # fill
	draw_arc(center, 50, ((5 * PI) / 6), (PI / 6), 100, Color("fd0156ff"), 100)  # bottom
	draw_circle(center, 36, Color("fd0156ff"))

func _ready() -> void:
	queue_redraw()

func set_fill(value: float) -> void:
	fill = clamp(value, 0.0, 1.0)
	queue_redraw()
