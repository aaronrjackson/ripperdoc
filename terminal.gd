extends Control
@onready var output_box = $MarginContainer/TextBox

var output: Array[String] = []  # source of truth for all committed output
var command_history: Array[String] = []
var history_index: int = -1
var history_draft: String = ""
var current_input: String = ""

const PROMPT: String = "$ "

func _ready() -> void:
	output.append("RipperOS v2.77 -- Morro Rock")
	output.append("(C) 2068 Synthcast Corp. All Rights Reserved.")
	_redraw()

func _redraw() -> void:
	output_box.clear()
	for line in output:
		output_box.append_text(line + "\n")
	output_box.append_text(PROMPT + current_input + "█")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	get_viewport().set_input_as_handled()
	
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_submit()
		KEY_BACKSPACE:
			if current_input.length() > 0:
				current_input = current_input.left(current_input.length() - 1)
				_redraw()
		KEY_UP:
			_navigate_history(1)
		KEY_DOWN:
			_navigate_history(-1)
		_:
			if event.unicode > 0:
				current_input += char(event.unicode)
				_redraw()

func _submit() -> void:
	var trimmed = current_input.strip_edges()
	current_input = ""
	
	output.append(PROMPT + trimmed)
	
	if trimmed != "":
		command_history.append(trimmed)
		history_index = -1
		history_draft = ""
		var result = _handle_command(trimmed)
		if result != "":
			output.append(result)
	
	_redraw()
	
	await get_tree().process_frame
	var scrollbar = output_box.get_v_scroll_bar()
	scrollbar.value = scrollbar.max_value

func _navigate_history(direction: int) -> void:
	# direction 1 -> up key
	# direction -1 -> down key
	
	if command_history.is_empty():
		return
	
	# pressing down on draft input shouldn't do anything
	if history_index == -1 and direction == 1:
		history_draft = current_input
	
	# clamp
	history_index = clamp(history_index + direction, -1, command_history.size() - 1)
	
	if history_index == -1:
		# restore draft input
		current_input = history_draft
	else:
		# continue scrubbing through history
		current_input = command_history[command_history.size() - 1 - history_index]
	current_input = history_draft if history_index == -1 else command_history[command_history.size() - 1 - history_index]
	_redraw()

func _handle_command(raw: String) -> String:
	var parts = raw.split(" ", false)
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)
	match cmd:
		"help":
			return "Available commands: help, echo, clear"
		"echo":
			return " ".join(args)
		"clear":
			output.clear()
			return ""
		_:
			return "ripperscript: '" + cmd + "' not found"
