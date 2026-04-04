extends Panel

@export var radius := 100
@export var fill := 2.5

func _draw():
	# Center of the Panel
	var center = size / 2
	
	# Draw the circle
	draw_circle(center, radius, Color("fd0156ff"))
	draw_circle(center, radius - 8, Color("1C1829"))
	draw_arc(center, 42, (((5* PI) / 6) - .1), (((5* PI) / 6) + fill), 100, Color.CADET_BLUE, 100)
	draw_arc(center, 50, ((5* PI) / 6), ((PI) / 6), 100, Color("fd0156ff"), 100)
	draw_circle(center, 40, Color("fd0156ff"))

func _ready() -> void:
	queue_redraw()  # triggers _draw()
