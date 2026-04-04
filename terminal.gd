extends Control
@onready var output_box = $MarginContainer/TextBox

var output: Array[String] = []  # source of truth for all committed output
var command_history: Array[String] = []
var history_index: int = -1
var history_draft: String = ""
var current_input: String = ""
var cursor_pos: int = 0
var input_locked: bool = false

const PROMPT: String = "$ "

# virus stuff
var slow_ready: bool = true

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

func _get_max_lines() -> int:
	var font = output_box.get_theme_font("normal_font")
	var font_size = output_box.get_theme_font_size("normal_font_size")
	var line_height = font.get_height(font_size)
	return int(output_box.size.y / line_height)

func _redraw() -> void:
	var max_lines = _get_max_lines()
	
	# trim from front until rendered line count fits
	while true:
		output_box.clear()
		for line in output:
			output_box.append_text(line + "\n")
		if output_box.get_line_count() <= max_lines or output.is_empty():
			break
		output.pop_front()
	
	var before = current_input.left(cursor_pos)
	var after = current_input.substr(cursor_pos)
	output_box.append_text(PROMPT + before + "█" + after)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if input_locked:
		return
	
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		GameManager.add_load(0.001) # per keypress
	
	# SLOW VIRUS
	if GameManager.has_virus(Virus.Type.SLOW) and not slow_ready:
		# ignore inputs
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
			GameManager.add_load(0.005) 
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
				var ch = char(event.unicode)
				# CORRUPT VIRUS: randomly duplicate or swap on 10% chance
				if GameManager.has_virus(Virus.Type.CORRUPT) and randf() < 0.10:
					var roll = randf()
					if roll < 0.05 and current_input.length() > 0:
						# swap with previous character on 50% chance
						var prev = current_input[cursor_pos - 1]
						current_input = current_input.left(cursor_pos - 1) + ch + prev + current_input.substr(cursor_pos)
						cursor_pos += 1
					else:
						# otherwise duplicate a keypress
						ch = ch + ch
						current_input = current_input.left(cursor_pos) + ch + current_input.substr(cursor_pos)
						cursor_pos += 2
				else:
					current_input = current_input.left(cursor_pos) + ch + current_input.substr(cursor_pos)
					cursor_pos += 1
				_redraw()
	
	# SLOW VIRUS: make inputs slow to input
	if GameManager.has_virus(Virus.Type.SLOW):
		slow_ready = false
		await get_tree().create_timer(randf_range(0.05, 0.1)).timeout
		slow_ready = true

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
	

func _navigate_history(direction: int) -> void:
	# direction 1 -> up key
	# direction -1 -> down key
	
	if command_history.is_empty():
		return
	
	# AMNESIA VIRUS: return fake or empty history
	if GameManager.has_virus(Virus.Type.AMNESIA):
		current_input = ["scan", "install", "help", "dismiss --force"].pick_random()
		cursor_pos = current_input.length()
		_redraw()
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
			output.append("Available commands:")
			output.append("- help")
			output.append("- echo")
			output.append("- clear")
			output.append("- scan")
			output.append("- install [driver]")
			output.append("- dismiss [--force]")
			output.append("- virus [scan | quarantine | purge]")
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
						output.append("installing " + target + "...")
						input_locked = true
						_redraw()
						await get_tree().create_timer(randf_range(0.5, 1.0)).timeout
						input_locked = false
						# TODO: LAUNCH MINIGAME HERE
						return
			output.append("install: " + target + ": driver not found")
			return
		"dismiss":
			if GameManager.current_character == null:
				output.append("no patient in chair.")
				return
			if not args.is_empty():
				if args[0] == "--force":
					if GameManager.all_drivers_installed():
						GameManager.dismiss_character()
						GameManager.next_character()
						return
					else:
						print("FORCIBLY REMOVED PATIENT")
						output.append("you killed them...") #TODO: corny bruh delete this
						GameManager.dismiss_character()
						GameManager.next_character()
						return
			if not GameManager.all_drivers_installed():
				output.append("patient still has missing drivers. run 'scan' to check.")
				output.append("otherwise, run with --force to forcibly remove patient (NOT RECOMMENDED)")
				return
			GameManager.dismiss_character()
			GameManager.next_character()
			return
		"wave":
			if args.size() < 2:
				output.append("usage: bridge <amp/freq> <num>")
				return
			if args[0] == "amp":
				if GameManager.amp_lock:
					output.append("Amplitude Locked")
					return
				GameManager.bad_wave_amp += args[1].to_int()
			elif args[0] == "freq":
				if GameManager.speed_lock:
					output.append("Frequency Locked")
					return
				GameManager.bad_wave_speed += args[1].to_int()
			else:
				output.append("usage: bridge <amp/freq> <num>")
				
			if ((GameManager.good_wave_amp > GameManager.bad_wave_amp - 5) && (GameManager.good_wave_amp < GameManager.bad_wave_amp + 5)) && !GameManager.amp_lock:
				output.append("AMPLITUDE LOCK")
				GameManager.amp_lock = true
			if (GameManager.good_wave_speed == GameManager.bad_wave_speed)  && !GameManager.speed_lock:
				output.append("FREQUENCY LOCK")
				GameManager.speed_lock = true
			
			if GameManager.speed_lock && GameManager.amp_lock:
				output.append("Waves Synced")
			
		"virus":
			if args.is_empty():
				output.append("usage: virus <scan|quarantine|purge>")
				return
			match args[0]:
				"scan":
					output.append("scanning for active processes...")
					input_locked = true
					_redraw()
					await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
					input_locked = false
					if GameManager.active_viruses.is_empty():
						output.append("no hostile processes detected.")
					else:
						for v in GameManager.active_viruses:
							var status = "quarantined" if v.quarantined else "ACTIVE"
							output.append("pid %d [%s] -- %s" % [v.pid, v.type_name(), status])
					_redraw()
				"quarantine":
					if args.size() < 2:
						output.append("usage: virus quarantine <pid>")
						return
					var pid = args[1].to_int()
					if not GameManager.valid_virus(pid):
						output.append("error: no process with pid " + args[1])
						return
					output.append("isolating process " + args[1] + "...")
					_redraw()
					await get_tree().create_timer(randf_range(2.0, 3.0)).timeout
					if not GameManager.quarantine_virus(pid):
						output.append("error: quarantine slots full. purge existing processes first.")
					else:
						output.append("process " + args[1] + " isolated.")
					_redraw()
				"purge":
					if args.size() > 1:
						output.append("usage: virus purge")
						return
					var quarantined = GameManager.active_viruses.filter(func(v): return v.quarantined)
					if quarantined.is_empty():
						output.append("no processes in quarantine.")
						return
					GameManager.purge_quarantined()
					output.append("quarantined processes purged.")
					# TODO: spike vitals stub
				_:
					output.append("virus: unknown subcommand '" + args[0] + "'")
		"allocate":
			if args.is_empty():
				output.append("usage: allocate [amount]")
				return
			var amount = args[0].to_float()
			if amount <= 0.0 or amount > 1.0:
				output.append("allocate: value must be between 0.0 and 1.0")
				GameManager.add_load(0.05)
				return
			GameManager.allocate(amount)
			output.append("allocated " + args[0] + " neural resources.")
			return
		_:
			output.append("ripSH: '" + cmd + "' not found")
			GameManager.add_load(0.03)
			return
