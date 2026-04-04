@tool
extends Control

func _ready():
	randomize()
	
@export var spacing := 10.0
@export var speed := 20.0
@export var amp := 50.0
@export var point_count := 49

enum WaveType { ALPHA, BETA, THETA, DELTA, GAMMA }
@export var wave_type: WaveType = WaveType.ALPHA

@export var is_flat := false

var time := 0.0

func _physics_process(delta):
	time += delta
	queue_redraw()

func _draw():
	var points := []
	for i in range(point_count):
		var t = time * speed + i
		var y = 0.0

		if not is_flat:
			y = _get_wave_y(t)
		else:
			y = randf_range(-0.5, 0.5)

		var x = i * spacing

		# Edge smoothing
		if i == point_count - 1:
			t -= 1
			if not is_flat:
				y = _get_wave_y(t)
			x = (i - 0.999) * spacing
		elif i == 0:
			t += 1
			if not is_flat:
				y = _get_wave_y(t)
			x = 0.999 * spacing

		points.append(Vector2(x, size.y / 2.0 + y))

	if points.size() > 1:
		draw_polyline(points, _get_wave_color(), 3.0)

func _get_wave_y(t: float) -> float:
	match wave_type:
		WaveType.ALPHA:
			# Relaxed wakefulness — smooth, moderate rhythm (8–12 Hz feel)
			return sin(t) * amp * 0.6 + cos(t * 1.3) * amp * 0.25 + sin(t * 0.7) * amp * 0.15

		WaveType.BETA:
			# Active focus — faster, choppier (12–30 Hz feel)
			return sin(t * 2.2) * amp * 0.4 + cos(t * 3.1) * amp * 0.3 + sin(t * 1.7) * amp * 0.2 + cos(t * 4.3) * amp * 0.1

		WaveType.THETA:
			# Drowsy / meditative — slower, rounder (4–8 Hz feel)
			return sin(t * 0.6) * amp * 0.7 + cos(t * 0.9) * amp * 0.2 + sin(t * 1.1) * amp * 0.1

		WaveType.DELTA:
			# Deep sleep — very slow, large waves (0.5–4 Hz feel)
			return sin(t * 0.2) * amp * 0.85 + cos(t * 0.35) * amp * 0.15

		WaveType.GAMMA:
			# Peak cognition — rapid, dense (30–100 Hz feel)
			return sin(t * 4.5) * amp * 0.35 + cos(t * 6.2) * amp * 0.25 + sin(t * 3.8) * amp * 0.2 + cos(t * 7.1) * amp * 0.1 + sin(t * 5.3) * amp * 0.1

	return 0.0

func _get_wave_color() -> Color:
	match wave_type:
		WaveType.ALPHA:  return Color(0.22, 0.61, 0.87)  # blue
		WaveType.BETA:   return Color(0.11, 0.62, 0.46)  # teal
		WaveType.THETA:  return Color(0.50, 0.47, 0.87)  # purple
		WaveType.DELTA:  return Color(0.85, 0.35, 0.19)  # orange-red
		WaveType.GAMMA:  return Color(0.73, 0.46, 0.09)  # amber
	return Color.WHITE

func set_params(new_spacing := spacing, new_speed := speed, new_amp := amp):
	spacing = new_spacing
	speed = new_speed
	amp = new_amp
