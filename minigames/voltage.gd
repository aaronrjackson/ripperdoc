extends Control

signal completed

var commands: Array[String] = ["volt"]

# voltage state
var current_voltage: float = 0.0
var target_min: float = 0.0
var target_max: float = 0.0
var drift_speed: float = 0.0
var drift_direction: float = 1.0
var drift_timer: float = 0.0
var drift_change_interval: float = 0.0

# success tracking
var in_range_timer: float = 0.0
const SUCCESS_DURATION: float = 5.0
const VOLTAGE_MIN: float = -100.0
const VOLTAGE_MAX: float = 100.0

var completed_flag: bool = false

# node refs — built in _ready, no scene file needed
var track_bg: ColorRect
var target_zone: ColorRect
var voltage_cursor: ColorRect
var hold_bar_bg: ColorRect
var hold_bar_fill: ColorRect
var label_voltage: Label
var label_target: Label
var label_status: Label

func _ready() -> void:
	current_voltage = randf_range(-40.0, 40.0)
	var target_center = randf_range(-30.0, 30.0)
	var target_half_width = randf_range(8.0, 16.0)
	target_min = target_center - target_half_width
	target_max = target_center + target_half_width

	drift_speed = randf_range(3.0, 7.0)
	drift_direction = 1.0 if randf() > 0.5 else -1.0
	drift_change_interval = randf_range(1.5, 3.5)
	drift_timer = drift_change_interval

	_build_ui()
	_update_display()

func get_tutorial() -> Array[String]:
	return [
		"calibrate voltage to match the target range.",
		"volt +[num]  --  increase voltage",
		"volt -[num]  --  decrease voltage",
		"hold voltage within range for " + str(SUCCESS_DURATION) + " seconds.",
	]

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var consola = load("res://resources/fonts/CONSOLA.TTF")

	# --- voltage track background ---
	track_bg = ColorRect.new()
	track_bg.color = Color(0.071, 0.063, 0.086, 1.0)
	track_bg.set_anchor(SIDE_LEFT, 0.05)
	track_bg.set_anchor(SIDE_RIGHT, 0.95)
	track_bg.set_anchor(SIDE_TOP, 0.25)
	track_bg.set_anchor(SIDE_BOTTOM, 0.45)
	track_bg.offset_left = 0; track_bg.offset_right = 0
	track_bg.offset_top = 0; track_bg.offset_bottom = 0
	add_child(track_bg)

	# --- target zone (green band) ---
	target_zone = ColorRect.new()
	target_zone.color = Color(0.192, 0.165, 0.278, 1.0)
	track_bg.add_child(target_zone)

	# --- voltage cursor ---
	voltage_cursor = ColorRect.new()
	voltage_cursor.color = Color(0.835, 0.914, 0.439, 1.0)
	track_bg.add_child(voltage_cursor)

	# --- hold progress bar background ---
	hold_bar_bg = ColorRect.new()
	hold_bar_bg.color = Color(0.071, 0.063, 0.086, 1.0)
	hold_bar_bg.set_anchor(SIDE_LEFT, 0.05)
	hold_bar_bg.set_anchor(SIDE_RIGHT, 0.95)
	hold_bar_bg.set_anchor(SIDE_TOP, 0.52)
	hold_bar_bg.set_anchor(SIDE_BOTTOM, 0.60)
	hold_bar_bg.offset_left = 0; hold_bar_bg.offset_right = 0
	hold_bar_bg.offset_top = 0; hold_bar_bg.offset_bottom = 0
	add_child(hold_bar_bg)

	hold_bar_fill = ColorRect.new()
	hold_bar_fill.color = Color(0.1, 0.7, 0.3)
	hold_bar_fill.set_anchor(SIDE_LEFT, 0.0)
	hold_bar_fill.set_anchor(SIDE_TOP, 0.0)
	hold_bar_fill.set_anchor(SIDE_BOTTOM, 1.0)
	hold_bar_fill.set_anchor(SIDE_RIGHT, 0.0)
	hold_bar_fill.offset_left = 0; hold_bar_fill.offset_right = 0
	hold_bar_fill.offset_top = 0; hold_bar_fill.offset_bottom = 0
	hold_bar_bg.add_child(hold_bar_fill)

	# --- labels ---
	label_voltage = Label.new()
	label_voltage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_voltage.set_anchor(SIDE_LEFT, 0.05)
	label_voltage.set_anchor(SIDE_RIGHT, 0.95)
	label_voltage.set_anchor(SIDE_TOP, 0.63)
	label_voltage.set_anchor(SIDE_BOTTOM, 0.74)
	label_voltage.offset_left = 0; label_voltage.offset_right = 0
	label_voltage.offset_top = 0; label_voltage.offset_bottom = 0
	label_voltage.add_theme_font_override("font", consola)
	label_voltage.add_theme_font_size_override("font_size", 24)
	add_child(label_voltage)

	label_target = Label.new()
	label_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_target.set_anchor(SIDE_LEFT, 0.05)
	label_target.set_anchor(SIDE_RIGHT, 0.95)
	label_target.set_anchor(SIDE_TOP, 0.74)
	label_target.set_anchor(SIDE_BOTTOM, 0.85)
	label_target.offset_left = 0; label_target.offset_right = 0
	label_target.offset_top = 0; label_target.offset_bottom = 0
	label_target.add_theme_font_override("font", consola)
	label_target.add_theme_font_size_override("font_size", 24)
	add_child(label_target)

	label_status = Label.new()
	label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_status.set_anchor(SIDE_LEFT, 0.05)
	label_status.set_anchor(SIDE_RIGHT, 0.95)
	label_status.set_anchor(SIDE_TOP, 0.85)
	label_status.set_anchor(SIDE_BOTTOM, 0.96)
	label_status.offset_left = 0; label_status.offset_right = 0
	label_status.offset_top = 0; label_status.offset_bottom = 0
	label_status.add_theme_font_override("font", consola)
	label_status.add_theme_font_size_override("font_size", 24)
	add_child(label_status)

func _process(delta: float) -> void:
	if completed_flag:
		return

	current_voltage += drift_direction * drift_speed * delta
	current_voltage = clamp(current_voltage, VOLTAGE_MIN, VOLTAGE_MAX)

	drift_timer -= delta
	if drift_timer <= 0.0:
		drift_direction = 1.0 if randf() > 0.5 else -1.0
		drift_speed = randf_range(3.0, 7.0)
		drift_change_interval = randf_range(1.5, 3.5)
		drift_timer = drift_change_interval

	var in_range = current_voltage >= target_min and current_voltage <= target_max
	if in_range:
		in_range_timer += delta
		if in_range_timer >= SUCCESS_DURATION:
			completed_flag = true
			completed.emit()
	else:
		in_range_timer = 0.0

	_update_display()

func handle_command(cmd: String, args: Array) -> String:
	if cmd != "volt":
		return ""
	if args.is_empty():
		return "usage: volt +[num] or volt -[num]"

	var raw = args[0]
	if not (raw.begins_with("+") or raw.begins_with("-")):
		return "volt: value must start with + or -  (e.g. volt +10)"

	var amount = raw.to_float()
	if amount == 0.0 and raw != "+0" and raw != "-0":
		return "volt: invalid value '" + raw + "'"

	current_voltage = clamp(current_voltage + amount, VOLTAGE_MIN, VOLTAGE_MAX)
	_update_display()
	return "voltage adjusted to %.1f" % current_voltage

func _update_display() -> void:
	if track_bg == null:
		return

	var voltage_range = VOLTAGE_MAX - VOLTAGE_MIN

	# position target zone within track_bg (0..1 along width)
	var t_min_norm = (target_min - VOLTAGE_MIN) / voltage_range
	var t_max_norm = (target_max - VOLTAGE_MIN) / voltage_range
	target_zone.set_anchor(SIDE_LEFT, t_min_norm)
	target_zone.set_anchor(SIDE_RIGHT, t_max_norm)
	target_zone.set_anchor(SIDE_TOP, 0.0)
	target_zone.set_anchor(SIDE_BOTTOM, 1.0)
	target_zone.offset_left = 0; target_zone.offset_right = 0
	target_zone.offset_top = 0; target_zone.offset_bottom = 0

	# position voltage cursor — thin vertical bar
	var v_norm = (current_voltage - VOLTAGE_MIN) / voltage_range
	var cursor_width_norm = 0.01
	voltage_cursor.set_anchor(SIDE_LEFT, clamp(v_norm - cursor_width_norm * 0.5, 0.0, 1.0))
	voltage_cursor.set_anchor(SIDE_RIGHT, clamp(v_norm + cursor_width_norm * 0.5, 0.0, 1.0))
	voltage_cursor.set_anchor(SIDE_TOP, 0.0)
	voltage_cursor.set_anchor(SIDE_BOTTOM, 1.0)
	voltage_cursor.offset_left = 0; voltage_cursor.offset_right = 0
	voltage_cursor.offset_top = 0; voltage_cursor.offset_bottom = 0

	var in_range = current_voltage >= target_min and current_voltage <= target_max

	# hold bar fill
	var hold_pct = clamp(in_range_timer / SUCCESS_DURATION, 0.0, 1.0)
	hold_bar_fill.set_anchor(SIDE_RIGHT, hold_pct)
	hold_bar_fill.offset_right = 0

	# labels
	label_voltage.text = "voltage:  %.1f" % current_voltage
	label_target.text  = "target:   %.1f  to  %.1f" % [target_min, target_max]
	if in_range:
		var pct = int(hold_pct * 100.0)
		label_status.text = "IN RANGE -- holding... %d%%" % pct
		label_status.add_theme_color_override("font_color", Color(0.1, 0.9, 0.3))
	else:
		label_status.text = "OUT OF RANGE"
		label_status.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
