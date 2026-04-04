extends Control

func _ready():
	if Engine.is_editor_hint():
		return
	randomize()
	GameManager.bad_wave_amp = randi_range(5, 100)
	GameManager.bad_wave_speed = randi_range(5, 50)
	
@export var spacing := 10
@export var point_count := 54
@export var x_offset := 50

enum WaveType { ALPHA, BETA, THETA, DELTA, GAMMA }
@export var wave_type: WaveType = WaveType.THETA

@export var is_flat := false

var time := 0.0

func _physics_process(delta):
	time += delta
	queue_redraw()

func _draw():
	var points := []
	if Engine.is_editor_hint():
		return
	var speed = GameManager.bad_wave_speed
	for i in range(point_count):
		var t = time * speed + i
		var y = 0.0

		if not is_flat:
			y = _get_wave_y(t)
		else:
			y = randf_range(-0.5, 0.5)

		var x = i * spacing + x_offset

		# Edge smoothing
		if i == point_count - 1:
			t -= 1
			if not is_flat:
				y = _get_wave_y(t)
			x = (i - 0.999) * spacing + x_offset
		elif i == 0:
			t += 1
			if not is_flat:
				y = _get_wave_y(t)
			x = 0.999 * spacing + x_offset

		points.append(Vector2(x, size.y / 2.0 + y))

	if points.size() > 1:
		draw_polyline(points, _get_wave_color(), 3.0)

func _get_wave_y(t: float) -> float:
	var amp = GameManager.bad_wave_amp
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
		WaveType.ALPHA:  return Color.RED  # blue
		WaveType.BETA:   return Color.RED  # teal
		WaveType.THETA:  return Color.RED  # purple
		WaveType.DELTA:  return Color.RED  # orange-red
		WaveType.GAMMA:  return Color.RED  # amber
	return Color.WHITE
