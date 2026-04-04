@tool
extends Control
class_name HeartbeatUI

@export var speed := 20.0

# Wave height as a percentage of the control height (0.0 - 0.5 is safe)
@export var amp := 0.2

@export var point_count := 100

var time := 0.0

func _process(delta):
	time += delta
	queue_redraw()


func _draw():
	var points := []

	for i in range(point_count):

		# Properly spaced X (0 → width)
		var x = (float(i) / (point_count - 1)) * size.x

		# Time-based animation
		var t = time * speed

		# Smooth wave (keep it stable first)
		var wave = sin(t + i * 0.2)

		# Scale vertically (THIS is the only place amp is used)
		var y = size.y * 0.5 + wave * (size.y * amp)

		points.append(Vector2(x, y))

	if points.size() > 1:
		draw_polyline(points, Color.GREEN, 3.0)
