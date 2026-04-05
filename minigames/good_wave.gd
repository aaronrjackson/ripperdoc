extends Control

enum WaveType { ALPHA, BETA, THETA, DELTA, GAMMA }
@export var wave_type: WaveType = WaveType.THETA
@export var is_flat := false

var time := 0.0

func _ready():
	if Engine.is_editor_hint():
		return
	randomize()
	GameManager.good_wave_amp = randi_range(30, 100)
	GameManager.good_wave_speed = randi_range(5, 50)

func _physics_process(delta):
	time += delta
	queue_redraw()

func _draw():
	if Engine.is_editor_hint():
		return
	var w = size.x
	var h = size.y
	var p_count = 300
	var speed = GameManager.good_wave_speed
	var points := []
	for i in range(p_count):
		var t = time * speed + i * (TAU / p_count) * 3.0
		var y = _get_wave_y(t, h) if not is_flat else randf_range(-0.5, 0.5)
		var x = (float(i) / float(p_count - 1)) * w
		points.append(Vector2(x, h / 2.0 + y))
	if points.size() > 1:
		draw_polyline(points, _get_wave_color(), max(1.0, h * 0.01))

func _get_wave_y(t: float, h: float) -> float:
	var amp = (GameManager.good_wave_amp / 100.0) * h * 0.4
	match wave_type:
		WaveType.ALPHA:
			return sin(t) * amp * 0.6 + cos(t * 1.3) * amp * 0.25 + sin(t * 0.7) * amp * 0.15
		WaveType.BETA:
			return sin(t * 2.2) * amp * 0.4 + cos(t * 3.1) * amp * 0.3 + sin(t * 1.7) * amp * 0.2 + cos(t * 4.3) * amp * 0.1
		WaveType.THETA:
			return sin(t * 0.6) * amp * 0.7 + cos(t * 0.9) * amp * 0.2 + sin(t * 1.1) * amp * 0.1
		WaveType.DELTA:
			return sin(t * 0.2) * amp * 0.85 + cos(t * 0.35) * amp * 0.15
		WaveType.GAMMA:
			return sin(t * 4.5) * amp * 0.35 + cos(t * 6.2) * amp * 0.25 + sin(t * 3.8) * amp * 0.2 + cos(t * 7.1) * amp * 0.1 + sin(t * 5.3) * amp * 0.1
	return 0.0

func _get_wave_color() -> Color:
	match wave_type:
		WaveType.ALPHA: return Color(0.22, 0.61, 0.87)
		WaveType.BETA:  return Color(0.11, 0.62, 0.46)
		WaveType.THETA: return Color(0.50, 0.47, 0.87)
		WaveType.DELTA: return Color(0.85, 0.35, 0.19)
		WaveType.GAMMA: return Color(0.73, 0.46, 0.09)
	return Color.WHITE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
