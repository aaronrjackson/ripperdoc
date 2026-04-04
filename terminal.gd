extends Control
@onready var output_box = $MarginContainer/TextBox

var output: Array[String] = []  # source of truth for all committed output
var command_history: Array[String] = []
var history_index: int = -1
var history_draft: String = ""
var current_input: String = ""
var cursor_pos: int = 0

const PROMPT: String = "$ "

func _ready() -> void:
	GameManager.character_loaded.connect(_on_character_loaded)
	
	output.append("RipperOS v2.77 -- Morro Rock")
	output.append("(C) 2068 Synthcast Corp. All Rights Reserved.")
	output.append("")
	_redraw()

func _on_character_loaded(character: Character) -> void:
	print("new character detected!")
	output.append("new patient seated. run 'scan' to assess.")
	_redraw()

func _redraw() -> void:
	output_box.clear()
	for line in output:
		output_box.append_text(line + "\n")
	var before = current_input.left(cursor_pos)
	var after = current_input.substr(cursor_pos)
	output_box.append_text(PROMPT + before + "█" + after)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	get_viewport().set_input_as_handled()
	
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_submit()
		KEY_BACKSPACE:
			if cursor_pos > 0:
				current_input = current_input.left(cursor_pos - 1) + current_input.substr(cursor_pos)
				cursor_pos -= 1
				_redraw()
		KEY_UP:
			_navigate_history(1)
		KEY_DOWN:
			_navigate_history(-1)
		KEY_LEFT:
			cursor_pos = max(0, cursor_pos - 1)
			_redraw()
		KEY_RIGHT:
			cursor_pos = min(current_input.length(), cursor_pos + 1)
			_redraw()
		_:
			if event.unicode > 0:
				current_input = current_input.left(cursor_pos) + char(event.unicode) + current_input.substr(cursor_pos)
				cursor_pos += 1
				_redraw()

func _submit() -> void:
	var trimmed = current_input.strip_edges()
	current_input = ""
	cursor_pos = 0
	
	output.append(PROMPT + trimmed)
	
	if trimmed != "":
		command_history.append(trimmed)
		history_index = -1
		history_draft = ""
		_handle_command(trimmed)
	
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
		cursor_pos = current_input.length() 
	_redraw()

func _handle_command(raw: String) -> void:
	var parts = raw.split(" ", false)
	var cmd = parts[0]
	var args = parts.slice(1)
	match cmd:
		"help":
			if not args.is_empty():
				output.append("usage: help")
				return
			output.append("Available commands:\n- help\n- echo\n- clear\n- scan\n- install")
			return
		"echo":
			output.append(" ".join(args))
			return
		"clear":
			if not args.is_empty():
				output.append("usage: clear")
				return
			output.clear()
			return
		"scan":
			if not args.is_empty():
				output.append("usage: scan")
				return
			if GameManager.current_character == null:
				output.append("no patient in chair.")
				return
			
			output.append("PATIENT: " + GameManager.current_character.character_name)
			for cyberware in GameManager.current_character.cyberware:
				output.append("[" + cyberware.manufacturer + "] " + cyberware.device_name)
				for driver in cyberware.drivers:
					var status: String = "MISSING"
					if driver.driver_name in GameManager.installed_drivers:
						status = "installed"
					output.append("- " + driver.driver_name + " [" + status + "]")
			return
		"install":
			if GameManager.current_character == null:
				output.append("no patient in chair.")
				return
			if args.is_empty():
				output.append("usage: install <driver>")
				return
			var target = args[0]
			for cyberware in GameManager.current_character.cyberware:
				for driver in cyberware.drivers:
					if driver.driver_name == target:
						if not GameManager.install_driver(target):
							output.append(target + ": already installed.")
							return
						# launch minigame here
						output.append("loading " + target + "...")
						# TODO: LAUNCH MINIGAME HERE
						return
			output.append("install: " + target + ": driver not found")
			return
		"dismiss":
			if GameManager.current_character == null:
				output.append("no patient in chair.")
				return
			if not GameManager.all_drivers_installed():
				output.append("patient still has missing drivers. run 'scan' to check.")
				return
			GameManager.dismiss_character()
			GameManager.next_character()
			return
		_:
			output.append("ripperscript: '" + cmd + "' not found")
			return
