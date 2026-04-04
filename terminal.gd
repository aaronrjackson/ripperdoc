extends Control
@onready var output_box = $MarginContainer/TextBox

var output: Array[String] = []  # source of truth for all committed output
var command_history: Array[String] = []
var history_index: int = -1
var history_draft: String = ""
var current_input: String = ""

const PROMPT: String = "$ "

func _ready() -> void:
	GameManager.customer_loaded.connect(_on_customer_loaded)
	
	output.append("RipperOS v2.77 -- Morro Rock")
	output.append("(C) 2068 Synthcast Corp. All Rights Reserved.")
	_redraw()

func _on_customer_loaded(customer: Customer) -> void:
	print("new customer detected!")
	output.append(customer.flavor_text)
	output.append("new patient seated. run 'scan' to assess.")
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
		_handle_command(trimmed)
		#var result = _handle_command(trimmed)
		#if result != "":
			#output.append(result)
	
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

func _handle_command(raw: String) -> void:
	var parts = raw.split(" ", false)
	var cmd = parts[0]
	var args = parts.slice(1)
	match cmd:
		"help":
			output.append("Available commands:\n- help\n- echo\n- clear\n- scan\n- install\n")
			return
		"echo":
			output.append(" ".join(args))
			return
		"clear":
			output.clear()
			return
		"scan":
			if GameManager.current_customer == null:
				output.append("no patient in chair.")
				return
			
			output.append("PATIENT: " + GameManager.current_customer.customer_name)
			for cyberware in GameManager.current_customer.cyberware:
				output.append("[" + cyberware.manufacturer + "] " + cyberware.device_name)
				for driver in cyberware.drivers:
					var status: String = "MISSING"
					if driver.driver_name in GameManager.installed_drivers:
						status = "installed"
					output.append("- " + driver.driver_name + " [" + status + "]")
			return
		"install":
			if GameManager.current_customer == null:
				output.append("no patient in chair.")
				return
			if args.is_empty():
				output.append("usage: install <driver>")
				return
			var target = args[0]
			for ware in GameManager.current_customer.cyberware:
				for drv in ware.drivers:
					if drv.driver_name == target:
						if not GameManager.install_driver(target):
							output.append(target + ": already installed.")
							return
						# launch minigame here
						output.append("loading " + target + "...")
						return
			output.append("install: " + target + ": driver not found")
		_:
			output.append("ripperscript: '" + cmd + "' not found")
	
