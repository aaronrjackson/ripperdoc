extends Control

@export var speed := 6
@export var amp_scale := -1.4
@export var cycles_visible := 2 # how many heartbeat cycles fit on screen at once
@export var is_flat := false
@export var is_vfib := false
const POINT_COUNT := 500  # more points = smoother curve (ish)

var time := 0.0

func _ready():
	GameManager.vfib_started.connect(func(): is_vfib = true; is_flat = false)
	GameManager.vfib_resolved.connect(func(): is_vfib = false; is_flat = false)
	GameManager.character_loaded.connect(func(_c): is_vfib = false; is_flat = false)
	GameManager.character_died.connect(func(): is_vfib = false; is_flat = true)

func _physics_process(delta):
	time += delta
	queue_redraw()

func _draw():
	var w = size.x
	var h = size.y
	var amp = h * 0.3 * amp_scale
	var spacing = w / float(POINT_COUNT - 1) # fills full width
	
	var points := []
	for i in range(POINT_COUNT):
		var t = time * speed + i * (TAU * cycles_visible / POINT_COUNT)
		var y: float
		if is_flat:
			y = randf_range(-0.5, 0.5)
		elif is_vfib:
			y = _vfib(t, amp)
		else:
			y = _ecg(t, amp)
		var v_offset = h * 0.15 # shift down, adjust to taste
		points.append(Vector2(i * spacing, h / 2 + y + v_offset))
	
	if points.size() > 1:
		var line_width = max(1.0, h * 0.03) # line width scales too
		draw_polyline(points, Color.GREEN, line_width)

func _ecg(t: float, amp: float) -> float:
	var cycle = fmod(t, TAU) # 0 to 2pi per beat
	
	if cycle < 0.3:
		# small P wave bump
		return sin(cycle * (PI / 0.3)) * amp * 0.2
	elif cycle < 1.2:
		# flat section
		return 0.0
	elif cycle < 1.35:
		# sharp Q dip
		return -amp * 0.3 * ((cycle - 1.2) / 0.15)
	elif cycle < 1.5:
		# sharp R spike up
		return amp * ((cycle - 1.35) / 0.15)
	elif cycle < 1.65:
		# sharp S dip back down
		return amp - (amp * 1.3) * ((cycle - 1.5) / 0.15)
	elif cycle < 1.9:
		# return to baseline
		return lerp(-amp * 0.3, 0.0, (cycle - 1.65) / 0.25)
	elif cycle < 2.5:
		# T wave - gentle bump
		return sin((cycle - 1.9) * (PI / 0.6)) * amp * 0.25
	else:
		# flat until next beat
		return 0.0
	
func _vfib(t: float, amp: float) -> float:
	var mult = 0.3
	return (
		sin(t * 3.7) * amp * mult * 0.6 +
		sin(t * 7.3 + 1.2) * amp * mult * 0.4 +
		sin(t * 2.1 + 0.5) * amp * mult * 0.3 +
		cos(t * 5.9) * amp * mult * 0.5 +
		randf_range(-amp * mult * 0.05, amp * mult * 0.05)  # slight noise
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_params(new_speed := speed, new_is_flat := is_flat) -> void:
	speed = new_speed
	is_flat = new_is_flat
