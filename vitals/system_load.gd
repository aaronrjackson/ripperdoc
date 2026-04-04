extends Panel

@export var radius := 100
@export var fill := 0.3 # 0.0 - 1.0
@export var epsilon = 0.05 # overlap to close gap

func _draw():
	var center = size / 2
	var r = min(size.x, size.y) * 0.5
	var sweep = fill * ((4 * PI) / 3)
	var arc_width = r * 1.0  # scales with radius
	
	# outline
	draw_circle(center, r, Color("fd0156ff"))
	# inside background
	draw_circle(center, r - (r * 0.04), Color("121016ff"))
	# fill meter
	draw_arc(center, r * 0.46, ((5 * PI) / 6) - epsilon, ((5 * PI) / 6) + sweep + epsilon, 100, Color("ed4800ff"), arc_width)
	# bottom thick
	draw_arc(center, r * 0.50, ((5 * PI) / 6), (PI / 6), 100, Color("fd0156ff"), arc_width)
	# middle inner tiny circle
	draw_circle(center, r * 0.36, Color("fd0156ff"))

func _ready() -> void:
	queue_redraw()

func set_fill(value: float) -> void:
	fill = clamp(value, 0.0, 1.0)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
