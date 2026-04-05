extends Control

signal completed

var commands: Array[String] = ["route"]

const COLS = 6
const ROWS = 6
const POINT_COLS = 7
const POINT_ROWS = 7
const ROUNDS_TO_WIN = 3

var current_round: int = 0
var start_node: Vector2i
var end_node: Vector2i
var current_path: Array[Vector2i] = []
var walls: Array = []

const WALL_PRESETS = [
	# preset 0: manual
	[
		{"from": Vector2i(3,1), "to": Vector2i(4,1)},
		{"from": Vector2i(4,1), "to": Vector2i(5,1)},
		{"from": Vector2i(1,3), "to": Vector2i(1,4)},
		{"from": Vector2i(1,4), "to": Vector2i(1,5)},
		{"from": Vector2i(1,5), "to": Vector2i(1,6)},
		{"from": Vector2i(3,7), "to": Vector2i(4,7)},
		{"from": Vector2i(5,7), "to": Vector2i(6,7)},
		{"from": Vector2i(7,2), "to": Vector2i(7,3)},
		{"from": Vector2i(7,3), "to": Vector2i(7,4)},
		{"from": Vector2i(2,5), "to": Vector2i(2,6)},
		{"from": Vector2i(2,5), "to": Vector2i(3,5)},
		{"from": Vector2i(3,5), "to": Vector2i(4,5)},
		{"from": Vector2i(5,5), "to": Vector2i(5,6)},
		{"from": Vector2i(6,4), "to": Vector2i(6,5)},
		{"from": Vector2i(3,4), "to": Vector2i(4,4)},
		{"from": Vector2i(4,3), "to": Vector2i(4,4)},
		{"from": Vector2i(5,2), "to": Vector2i(5,3)},
		{"from": Vector2i(5,3), "to": Vector2i(6,3)},
		{"from": Vector2i(2,2), "to": Vector2i(3,2)},
		{"from": Vector2i(3,2), "to": Vector2i(3,3)},
		{"from": Vector2i(2,3), "to": Vector2i(3,3)},
		{"from": Vector2i(2,2), "to": Vector2i(2,3)},
	],
]

var node_positions: Dictionary = {}

@onready var draw_layer = $DrawLayer

func _ready() -> void:
	_pick_nodes()   # pick nodes immediately so get_tutorial has valid values
	_pick_walls()
	await get_tree().process_frame
	await get_tree().process_frame
	_cache_node_positions()
	# now redraw with correct positions
	draw_layer.queue_redraw()

func _start_round() -> String:
	current_path.clear()
	_pick_nodes()
	_pick_walls()
	draw_layer.queue_redraw()
	return "circuit %d of %d.  start: %dx%d  end: %dx%d" % [current_round + 1, ROUNDS_TO_WIN, start_node.x, start_node.y, end_node.x, end_node.y]

func _cache_node_positions() -> void:
	var vbox = $MarginContainer/VBoxContainer
	var hboxes: Array = []
	for child in vbox.get_children():
		if child is HBoxContainer:
			hboxes.append(child)

	var origin = global_position

	for row_idx in range(hboxes.size()):
		var hbox = hboxes[row_idx]
		var panels: Array = []
		for child in hbox.get_children():
			if child is Panel:
				panels.append(child)

		for col_idx in range(panels.size()):
			var panel = panels[col_idx]
			var r = panel.get_global_rect()
			var tl = r.position - origin
			var tr = Vector2(r.end.x, r.position.y) - origin
			var bl = Vector2(r.position.x, r.end.y) - origin
			var br = r.end - origin

			node_positions[Vector2i(col_idx + 1, row_idx + 1)] = tl
			node_positions[Vector2i(col_idx + 2, row_idx + 1)] = tr
			node_positions[Vector2i(col_idx + 1, row_idx + 2)] = bl
			node_positions[Vector2i(col_idx + 2, row_idx + 2)] = br

func _get_node_position(coord: Vector2i) -> Vector2:
	return node_positions.get(coord, Vector2.ZERO)
	
func _draw_star(canvas: Control, center: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	var num_points = 5
	for i in range(num_points * 2):
		var angle = (PI / num_points) * i - PI / 2
		var r = radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	canvas.draw_polygon(points, PackedColorArray([color]))
func _is_wall_node(coord: Vector2i) -> bool:
	var connected: Array = []
	for wall in walls:
		if wall["from"] == coord:
			connected.append(wall["to"])
		elif wall["to"] == coord:
			connected.append(wall["from"])
	
	if connected.size() < 2:
		return false
	
	# check each pair of connected points
	for i in range(connected.size()):
		for j in range(i + 1, connected.size()):
			var a = connected[i]
			var b = connected[j]
			# both horizontal (same y as each other and as coord)
			var both_horizontal = (a.y == coord.y and b.y == coord.y)
			# both vertical (same x as each other and as coord)
			var both_vertical = (a.x == coord.x and b.x == coord.x)
			if both_horizontal or both_vertical:
				return true
	
	return false

func _draw_overlay(canvas: Control) -> void:
	for wall in walls:
		_draw_wall(canvas, wall["from"], wall["to"])
	for coord in node_positions:
		if not _is_wall_node(coord):
			canvas.draw_circle(node_positions[coord], 8.0, Color("ffffffff"))
	for i in range(current_path.size() - 1):
		_draw_path_segment(canvas, current_path[i], current_path[i + 1])
	_draw_star(canvas, _get_node_position(start_node), 25.0, Color("00cfff"))
	_draw_star(canvas, _get_node_position(end_node), 25.0, Color("ff6600"))
	if current_path.size() > 0 and current_path[-1] != start_node:
		_draw_star(canvas, _get_node_position(current_path[-1]), 16.0, Color("ffff00"))
	# draw white dot on every grid point

func _draw_wall(canvas: Control, from: Vector2i, to: Vector2i) -> void:
	var thickness = 12.0
	var overlap = 6.0  # extends beyond endpoints to close corner gaps
	var color = Color("0055ffcc")
	var a = _get_node_position(from)
	var b = _get_node_position(to)
	if from.y == to.y:
		canvas.draw_rect(Rect2(min(a.x, b.x) - overlap, a.y - thickness * 0.5, abs(b.x - a.x) + overlap * 2, thickness), color)
	else:
		canvas.draw_rect(Rect2(a.x - thickness * 0.5, min(a.y, b.y) - overlap, thickness, abs(b.y - a.y) + overlap * 2), color)
		
func _draw_path_segment(canvas: Control, from: Vector2i, to: Vector2i) -> void:
	var thickness = 4.0
	var color = Color("ffff00cc")
	var a = _get_node_position(from)
	var b = _get_node_position(to)
	if from.x == to.x:
		canvas.draw_rect(Rect2(a.x - thickness * 0.5, min(a.y, b.y), thickness, abs(b.y - a.y)), color)
	else:
		canvas.draw_rect(Rect2(min(a.x, b.x), a.y - thickness * 0.5, abs(b.x - a.x), thickness), color)

func _pick_nodes() -> void:
	var all_points: Array[Vector2i] = []
	for col in range(1, POINT_COLS + 1):
		for row in range(1, POINT_ROWS + 1):
			all_points.append(Vector2i(col, row))
	all_points.shuffle()
	start_node = all_points[0]
	for candidate in all_points.slice(1):
		var dist = abs(candidate.x - start_node.x) + abs(candidate.y - start_node.y)
		if dist > 1:
			end_node = candidate
			return

func _pick_walls() -> void:
	var preset = WALL_PRESETS[randi_range(0, WALL_PRESETS.size() - 1)].duplicate(true)
	var rotation_steps = randi_range(0, 3)
	for _i in rotation_steps:
		preset = _rotate_walls_90(preset)
	walls = preset

func _rotate_walls_90(preset: Array) -> Array:
	var result = []
	for wall in preset:
		result.append({
			"from": Vector2i(POINT_ROWS + 1 - wall["from"].y, wall["from"].x),
			"to": Vector2i(POINT_ROWS + 1 - wall["to"].y, wall["to"].x)
		})
	return result

func handle_command(cmd: String, args: Array) -> String:
	match cmd:
		"route":
			return await _handle_route(args)
	return ""

func _handle_route(args: Array) -> String:
	if args.is_empty():
		return "usage: route <col> <row> | route clear"

	if args[0] == "clear":
		current_path.clear()
		draw_layer.queue_redraw()
		return "route cleared."

	if args.size() < 2 or not args[0].is_valid_int() or not args[1].is_valid_int():
		return "route: invalid coordinate. use format <col> <row> e.g. route 3 4"

	var col = args[0].to_int()
	var row = args[1].to_int()

	if col < 1 or col > POINT_COLS or row < 1 or row > POINT_ROWS:
		return "route: coordinate out of bounds. grid is %dx%d" % [POINT_COLS, POINT_ROWS]

	var target = Vector2i(col, row)

	if _is_wall_node(target):
		return "route: node %d %d is blocked by walls." % [col, row]

	if current_path.is_empty():
		current_path.append(start_node)

	var head = current_path[-1]

	if target.x != head.x and target.y != head.y:
		return "route: must route in a straight line (same row or column)"

	var wall_hit = _check_walls(head, target)
	if wall_hit != "":
		return wall_hit

	var segment_cells = _get_segment_steps(head, target)
	for cell in segment_cells:
		if cell in current_path and cell != head:
			return "route: path cannot cross itself"

	current_path.append(target)
	draw_layer.queue_redraw()

	if target == end_node:
		current_round += 1
		if current_round >= ROUNDS_TO_WIN:
			draw_layer.queue_redraw()
			await get_tree().create_timer(0.5).timeout
			completed.emit()
			return "connection established. install complete."
		else:
			var msg = _start_round()
			return "connection established. " + msg

	return "waypoint set at %d %d" % [col, row]

func _check_walls(from: Vector2i, to: Vector2i) -> String:
	var steps = _get_segment_steps(from, to)
	for i in range(steps.size() - 1):
		var a = steps[i]
		var b = steps[i + 1]
		for wall in walls:
			if (wall["from"] == a and wall["to"] == b) or (wall["from"] == b and wall["to"] == a):
				return "route: wall blocks path between %dx%d and %dx%d" % [a.x, a.y, b.x, b.y]
	return ""

func _get_segment_steps(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var steps: Array[Vector2i] = []
	var dx = sign(to.x - from.x)
	var dy = sign(to.y - from.y)
	var cur = from
	while cur != to:
		steps.append(cur)
		cur += Vector2i(dx, dy)
	steps.append(to)
	return steps

func get_tutorial() -> Array[String]:
	return [
		"power routing minigame.",
		"connect the start node to the end node.",
		"type 'route [col] [row]' to set waypoints.",
		"type 'route clear' to reset your path.",
		"complete 3 connections to finish.",
		"start: %dx%d  end: %dx%d" % [start_node.x, start_node.y, end_node.x, end_node.y],
	]
