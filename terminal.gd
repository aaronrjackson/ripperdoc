extends Control

@onready var output_box = $MarginContainer/TextBox
@onready var patient = get_tree().root.get_node("main/Panel/HBoxContainer/Patient/Layers") # spaghetti
@onready var patient_node = get_tree().root.get_node("main/Panel/HBoxContainer/Patient")

var output: Array[String] = [] # source of truth for all committed output
var command_history: Array[String] = []
var history_index: int = -1
var history_draft: String = ""
var current_input: String = ""
var cursor_pos: int = 0
var input_locked: bool = false
var in_minigame: bool = false
var current_minigame: Node = null
var minigame_commands: Array[String] = ["wave"]
var saved_output: Array[String] = []
var current_minigame_driver: String = ""

const PROMPT: String = "$ "

# slow virus input throttle
var slow_ready: bool = true

func _ready() -> void:
	GameManager.character_loaded.connect(_on_character_loaded)
	GameManager.character_died.connect(_on_character_died)
	GameManager.vfib_started.connect(_on_vfib_started)
	GameManager.vfib_resolved.connect(_on_vfib_resolved)
	GameManager.day_advanced.connect(_on_day_advanced)
	GameManager.game_over.connect(_on_game_over)
	GameManager.next_patient_incoming.connect(_on_next_patient_incoming)

	_print_boot()
	await get_tree().process_frame
	await get_tree().process_frame
	_redraw()

func _print_boot() -> void:
	output.append("RipperOS v2.77 -- Morro Rock")
	output.append("(C) 2068 Synthcast Corp. All Rights Reserved.")
	output.append("")
	_print_day_header(GameManager.current_day)
	output.append("")

func _on_character_loaded(character: Character) -> void:
	print("new character " + character.character_name + " detected!")
	# always unlock input when a new patient arrives, even after a death
	input_locked = false
	output.append("A new patient has been seated. Run 'scan' to assess.")
	_redraw()

func _on_character_died() -> void:
	var char_name = GameManager.current_character.character_name if GameManager.current_character else "patient"

	if in_minigame:
		in_minigame = false
		minigame_commands.clear()
		output = saved_output.duplicate()

	var afib = get_tree().root.get_node_or_null("main/Panel/HBoxContainer/VBoxContainer/Vitals/AfibPlayer")
	if afib:
		afib.stop()

	output.append(char_name + " has perished...")
	output.append("")
	_redraw()

func _on_vfib_started() -> void:
	var afib = get_tree().root.get_node_or_null("main/Panel/HBoxContainer/VBoxContainer/Vitals/AfibPlayer")
	if afib:
		afib.finished.connect(func():
			if GameManager.in_vfib:
				afib.play()
		)
		afib.play()

func _on_vfib_resolved() -> void:
	var afib = get_tree().root.get_node_or_null("main/Panel/HBoxContainer/VBoxContainer/Vitals/AfibPlayer")
	if afib:
		afib.stop()

func _print_day_header(day: int) -> void:
	output.append("================================")
	output.append("       DAY " + str(day) + " SHIFT STARTING")
	output.append("================================")

func _on_day_advanced(new_day: int) -> void:
	output.append("No more patients for today.")
	output.append("Type 'shop' to browse upgrades or 'clockin' to start the next shift.")
	_redraw()

func _on_game_over() -> void:
	var afib = get_tree().root.get_node_or_null("main/Vitals/AfibPlayer")
	if afib:
		afib.stop()
	input_locked = true
	output.append("")
	output.append("================================")
	output.append("           GAME OVER")
	output.append("================================")
	output.append("")
	output.append("day reached:       " + str(GameManager.current_day))
	output.append("patients helped:   " + str(GameManager.patients_helped))
	output.append("patients lost:     " + str(GameManager.patients_killed))
	output.append("final balance:     " + str(GameManager.currency) + "$")
	output.append("")
	output.append("System shutting down...")
	_redraw()

func _on_next_patient_incoming() -> void:
	output.append("Next patient incoming...")
	_redraw()


#region PATIENT VISUALS

func _flash_bodypart(part_name: String) -> void:
	var layer = patient.get_node_or_null(part_name)
	if layer == null:
		return
	layer.visible = true
	_play_scan_sound()
	var tween = create_tween()
	tween.tween_property(layer, "modulate:a", 0.0, 0.9)
	tween.tween_callback(func():
		layer.visible = false
		layer.modulate.a = 1.0 # reset for next time
	)

func _set_bodypart_visible(part_name: String, visible: bool) -> void:
	var layer = patient.get_node_or_null(part_name)
	if layer == null:
		return
	if visible:
		_play_scan_sound()
	layer.modulate.a = 1.0
	layer.visible = visible

func _fade_bodypart(part_name: String) -> void:
	var layer = patient.get_node_or_null(part_name)
	if layer == null:
		return
	var tween = create_tween()
	tween.tween_property(layer, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		layer.visible = false
		layer.modulate.a = 1.0
	)

func _play_scan_sound() -> void:
	var sound = patient_node.get_node_or_null("ScanPlayer")
	if sound == null:
		print("ERROR: ScanPlayer not found in Patient!!!")
		return
	sound.play()

#endregion


#region RENDERING

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

#endregion


#region INPUT

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if input_locked:
		return

	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
			GameManager.add_load(GameManager.keypress_load_cost)

	# slow virus: ignore inputs while throttled
	if GameManager.has_virus(Virus.Type.SLOW) and not slow_ready:
		return

	get_viewport().set_input_as_handled()

	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_submit()
		KEY_C:
			if event.ctrl_pressed and in_minigame:
				in_minigame = false
				GameManager.uninstall_driver(current_minigame_driver)
				_redraw()
				return
			if event.unicode > 0:
				_insert_char(char(event.unicode))
		KEY_BACKSPACE:
			if cursor_pos > 0:
				current_input = current_input.left(cursor_pos - 1) + current_input.substr(cursor_pos)
				cursor_pos -= 1
				_redraw()
			GameManager.add_load(GameManager.backspace_load_cost)
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
				_insert_char(char(event.unicode))

	# slow virus: throttle after handling input
	if GameManager.has_virus(Virus.Type.SLOW):
		slow_ready = false
		await get_tree().create_timer(randf_range(0.05, 0.1)).timeout
		slow_ready = true

func _insert_char(ch: String) -> void:
	# corrupt virus: randomly duplicate or swap on 10% chance
	if GameManager.has_virus(Virus.Type.CORRUPT) and randf() < 0.10:
		if randf() < 0.05 and current_input.length() > 0:
			# swap with previous character
			var prev = current_input[cursor_pos - 1]
			current_input = current_input.left(cursor_pos - 1) + ch + prev + current_input.substr(cursor_pos)
			cursor_pos += 1
		else:
			# duplicate the keypress
			current_input = current_input.left(cursor_pos) + ch + ch + current_input.substr(cursor_pos)
			cursor_pos += 2
	else:
		current_input = current_input.left(cursor_pos) + ch + current_input.substr(cursor_pos)
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

func _navigate_history(direction: int) -> void:
	# direction 1 -> up, direction -1 -> down
	if command_history.is_empty():
		return

	# amnesia virus: return fake history
	if GameManager.has_virus(Virus.Type.AMNESIA):
		current_input = ["scan", "install", "help", "dismiss --force"].pick_random()
		cursor_pos = current_input.length()
		_redraw()
		return

	if history_index == -1 and direction == 1:
		history_draft = current_input

	history_index = clamp(history_index + direction, -1, command_history.size() - 1)

	if history_index == -1:
		current_input = history_draft
	else:
		current_input = command_history[command_history.size() - 1 - history_index]
		cursor_pos = current_input.length()
	_redraw()

#endregion


#region COMMANDS

func _handle_command(raw: String) -> void:
	var parts = raw.split(" ", false)
	var cmd = parts[0]
	var args = parts.slice(1)

	if in_minigame:
		if cmd in minigame_commands:
			var result = current_minigame.handle_command(cmd, args)
			if result != "":
				output.append(result)
			_redraw()
			return
		elif cmd not in ["clear", "help", "echo"]:
			output.append(cmd + ": not available during install process.")
			return

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
			output.append("- allocate [percentage]")
			output.append("- diagnose [cardiac]")
			output.append("- kill [pid]")
			output.append("- shop [item_id]")
			output.append("- clockin")
			output.append("- exit")

		"echo":
			output.append(" ".join(args))

		"clear":
			if not args.is_empty():
				output.append("usage: clear")
				return
			output.clear()

		"scan", "status":
			if not args.is_empty():
				output.append("usage: scan")
				return
			if GameManager.current_character == null:
				output.append("no patient in chair.")
				return
			output.append("PATIENT: " + GameManager.current_character.character_name)
			for cyberware in GameManager.current_character.cyberware:
				if cyberware.drivers.is_empty():
					continue
				output.append("[" + cyberware.manufacturer + "] " + cyberware.device_name)
				for driver in cyberware.drivers:
					var status = "installed" if driver.driver_name in GameManager.installed_drivers else "MISSING"
					output.append("- " + driver.driver_name + " [" + status + "]")
			output.append("")
			var seen_parts: Array[String] = []
			for cyberware in GameManager.current_character.cyberware:
				if cyberware.bodypart != "" and cyberware.bodypart not in seen_parts:
					seen_parts.append(cyberware.bodypart)
					_flash_bodypart(cyberware.bodypart)

		"install":
			if GameManager.current_character == null:
				output.append("no patient in chair.")
				return
			if args.is_empty():
				output.append("usage: install [driver]")
				return
			await _cmd_install(args[0])

		"dismiss":
			if GameManager.current_character == null:
				output.append("No patient in chair.")
				return
			var force = not args.is_empty() and args[0] == "--force"
			if not GameManager.all_drivers_installed():
				if not force:
					output.append("Patient still has missing drivers! Run 'scan' to check.")
					output.append("Otherwise, run with '--force' to forcibly remove patient (NOT RECOMMENDED).")
					return
			var earned = GameManager.earn_dismiss_currency(force)
			if earned > 0:
				output.append("Patient discharged. +" + str(earned) + "$")
				output.append("")
			else:
				output.append("Patient forcibly discharged. No payment received.")
				output.append("")
			GameManager.dismiss_character()

		"virus":
			if args.is_empty():
				output.append("usage: virus [scan|quarantine|purge]")
				return
			await _cmd_virus(args)

		"allocate":
			if args.is_empty():
				output.append("usage: allocate [percentage]")
				return
			var amount = args[0].to_float()
			if amount <= 0.0 or amount > 1.0:
				output.append("allocate: value must be between 0.0 and 1.0")
				GameManager.add_load(0.05)
				return
			GameManager.allocate(amount)
			output.append("allocated " + args[0] + " neural resources.")

		"diagnose":
			if args.is_empty() or args[0] != "cardiac":
				output.append("usage: diagnose cardiac")
				return
			if not GameManager.in_vfib:
				output.append("diagnose: no cardiac anomaly detected.")
				return
			output.append("DIAGNOSIS: ventricular fibrillation detected due to conflicting processes.")
			output.append("conflicting processes:")
			for p in GameManager.vfib_processes:
				output.append("  PID %d  %-30s [%s]" % [p["pid"], p["name"], p["desc"]])
			output.append("Run 'kill [pid]' to terminate the offending process.")

		"kill":
			if args.is_empty():
				output.append("usage: kill [pid]")
				return
			if not GameManager.in_vfib:
				output.append("kill: no active cardiac event.")
				return
			var pid = args[0].to_int()
			var valid = GameManager.vfib_processes.any(func(p): return p["pid"] == pid)
			if not valid:
				output.append("kill: pid " + args[0] + " not found.")
				return
			if GameManager.vfib_kill(pid):
				output.append("process terminated. cardiac rhythm stabilizing...")
			else:
				if GameManager.is_dead:
					return
				output.append("WARNING: wrong process. cardiac stability worsening.")
		
		"shop":
			if not GameManager.is_between_days:
				output.append("shop: only accessible between days.")
				return
			if args.is_empty():
				_cmd_shop_list()
			elif args[0] == "buy":
				if args.size() < 2:
					output.append("usage: shop buy [item_id]")
					return
				_cmd_shop_buy(args[1])
			else:
				output.append("usage: shop | shop buy [item_id]")
		
		"clockin":
			if not GameManager.is_between_days:
				output.append("clockin: no shift change pending.")
				return
			GameManager.is_between_days = false
			output.clear()
			_print_boot()
			output.append("clocking in. next patient incoming...")
			output.append("")
			_redraw()
			GameManager.next_character()
		
		"exit", "quit":
			if not args.is_empty():
				output.append("usage: exit")
				return
			get_tree().quit()
		_:
			output.append("ripSH: '" + cmd + "' not found")
			GameManager.add_load(0.03)

func _cmd_install(target: String) -> void:
	for cyberware in GameManager.current_character.cyberware:
		for driver in cyberware.drivers:
			if driver.driver_name != target:
				continue
			if GameManager.installed_drivers.has(target):
				output.append(target + ": already installed.")
				return

			output.append("installing " + target + "...")
			var bodypart = cyberware.bodypart
			_set_bodypart_visible(bodypart, true)
			input_locked = true
			_redraw()
			await get_tree().create_timer(randf_range(0.5, 1.0)).timeout
			input_locked = false

			if driver.minigame_scene == null:
				GameManager.install_driver(driver.driver_name)
				output.append(target + ": installed successfully.")
				output.append("")
				_fade_bodypart(bodypart)
				_redraw()
				return

			# launch minigame
			var minigame_panel = get_tree().root.get_node("main/Panel/HBoxContainer/VBoxContainer/Minigame/Panel/MarginContainer/Panel/MarginContainer/GamePanel")
			var minigame: Node = driver.minigame_scene.instantiate()
			GameManager.reset_minigame_state()
			minigame_panel.add_child(minigame)
			current_minigame = minigame

			# connect completion signal
			minigame.completed.connect(func():
				GameManager.install_driver(current_minigame_driver)
				in_minigame = false
			)

			saved_output = output.duplicate()
			output.clear()
			var header = "############ " + driver.display_name.to_upper() + " INSTALLATION WIZARD ############"
			output.append(header)
			output.append("")
			if minigame.has_method("get_tutorial"):
				for line in minigame.get_tutorial():
					output.append(line)
			output.append("CTRL+C to abort.")
			output.append("")
			output.append("#".repeat(header.length()))
			output.append("")
			minigame_commands = minigame.commands.duplicate()
			current_minigame_driver = target
			in_minigame = true
			_redraw()

			while in_minigame:
				await get_tree().process_frame

			minigame_commands.clear()
			current_minigame = null
			_fade_bodypart(bodypart)

			if GameManager.is_dead:
				# _on_character_died already restored saved_output and appended the death message
				# do NOT overwrite output here
				minigame.queue_free()
				_redraw()
				return

			output = saved_output.duplicate()

			if GameManager.installed_drivers.has(current_minigame_driver):
				output.append(target + ": installed successfully.")
				output.append("")
			else:
				output.append("^C")
				output.append("install aborted.")
			minigame.queue_free()
			_redraw()
			return

	output.append("install: " + target + ": driver not found")

func _cmd_virus(args: Array) -> void:
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
				output.append("usage: virus quarantine [pid]")
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
				output.append("process " + args[1] + " successfully isolated!")
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
			GameManager.add_load(0.10)
		_:
			output.append("virus: unknown subcommand '" + args[0] + "'")

func _cmd_shop_list() -> void:
	output.append("NIGHT MARKET -- balance: " + str(GameManager.currency) + "$")
	output.append("")
	for item in GameManager.get_shop_items():
		var price = GameManager.get_item_price(item.id)
		var times = GameManager.shop_purchases.get(item.id, 0)
		var bought_str = " (x" + str(times) + " owned)" if times > 0 else ""
		output.append(item.name + bought_str + "  --  " + str(price) + "$")
		output.append("  id: " + item.id)
		output.append("  " + item.desc)
		output.append("")
	output.append("use 'shop buy [item_id]' to purchase.")

func _cmd_shop_buy(item_id: String) -> void:
	var valid = GameManager.get_shop_items().any(func(i): return i.id == item_id)
	if not valid:
		output.append("shop: unknown item '" + item_id + "'")
		return
	var price = GameManager.get_item_price(item_id)
	if not GameManager.purchase_item(item_id):
		output.append("insufficient funds. need " + str(price) + "$, have " + str(GameManager.currency) + "$")
		return
	output.append("purchased! balance: " + str(GameManager.currency) + "$")

#endregion
