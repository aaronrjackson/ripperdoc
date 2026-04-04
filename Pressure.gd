extends Panel

@export var radius := 80.0

func _draw():
	# Center of the Panel
	var center = size / 2
	
	# Draw the circle
	draw_circle(center, radius, Color.WHITE)


func _ready() -> void:
	queue_redraw()  # triggers _draw()
