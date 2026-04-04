@tool
extends Control
class_name HeartbeatUI

@export var spacing := 10.0
@export var speed := 20.0
@export var amp := 50.0
@export var point_count := 50

# NEW: toggle between flat line and heartbeat
@export var is_flat := false

var time := 0.0

func _physics_process(delta):
	time += delta
	queue_redraw()


func _draw():
	var points := []

	for i in range(point_count):

		var sin_time = time * speed + i

		var y = 0.0

		if not is_flat:
			# Normal heartbeat waveform
			y = sin(sin_time) * amp / 2 + cos(sin_time / 2) * amp
		else:
			# Flat line (slight noise optional if you want realism)
			y = randf_range(-0.5, 0.5)

		var x = i * spacing

		# Edge smoothing (still applies)
		if i == point_count - 1:
			sin_time -= 1
			if not is_flat:
				y = sin(sin_time) * amp / 2 + cos(sin_time / 2) * amp
			x = (i - 0.999) * spacing

		if i == 0:
			sin_time += 1
			if not is_flat:
				y = sin(sin_time) * amp / 2 + cos(sin_time / 2 + 1) * amp
			x = 0.999 * spacing

		points.append(Vector2(x, size.y / 2 + y))

	if points.size() > 1:
		draw_polyline(points, Color.GREEN, 5.0)


func set_params(new_spacing := spacing, new_speed := speed, new_amp := amp):
	spacing = new_spacing
	speed = new_speed
	amp = new_amp
