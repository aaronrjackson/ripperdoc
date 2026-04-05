extends Node

signal character_loaded(character: Character)
signal character_dismissed
signal character_died
signal driver_installed(driver_name: String)
signal virus_uploaded(virus: Virus)
signal vitals_changed(load: float, pressure: float)
signal vfib_started
signal vfib_resolved
signal day_advanced(new_day: int)
signal game_over
signal next_patient_incoming

var roster: CharacterRoster
var current_character: Character = null
var installed_drivers: Array[String] = []
var driver_to_install: Array[Driver] = []
var is_dead: bool = false

var bad_wave_speed: int = 0
var bad_wave_amp: int = 0
var good_wave_speed: int = 0
var good_wave_amp: int = 0
var amp_lock: bool = false
var speed_lock: bool = false

var active_viruses: Array[Virus] = []
var quarantine_limit: int = 3

var system_load: float = 0.0
var keypress_load_cost: float = 0.001
var backspace_load_cost: float = 0.005
var neural_pressure: float = 0.0
var pressure_rate: float
var pressure_rate_multiplier: float = 1.0 # modified by pressure_dampener purchases
var in_vfib: bool = false
var vfib_mistakes: int = 0
var vfib_correct_pid: int = -1
var vfib_processes: Array = []
var vfib_timer: float = 0.0
var vfib_time_limit: float = 35.0

var current_day: int = 5
var patients_today: int = 0
var patients_per_day: int = 5

var currency: int = 0
var deaths_today: int = 0
var patients_helped: int = 0
var patients_killed: int = 0
var is_between_days: bool = false

var shop_purchases: Dictionary = {}

var nodes: Array = []

const INNOCENT_PROCESSES = [
	{"name": "cardiac_sync.exe", "desc": "stable, nominal load"},
	{"name": "pulse_monitor.exe", "desc": "stable, nominal load"},
	{"name": "rhythm_watchdog.exe", "desc": "stable, nominal load"},
	{"name": "cardio_logger.exe", "desc": "stable, read-only"},
	{"name": "bio_telemetry.exe", "desc": "stable, nominal load"},
]
const GUILTY_PROCESSES = [
	{"name": "ext_pulse_driver.exe", "desc": "elevated load, foreign signature"},
	{"name": "rhythm_override.exe", "desc": "elevated load, unverified origin"},
	{"name": "signal_inject.exe", "desc": "elevated load, unexpected activity"},
]

const DEATH_SEQUENCE_DURATION: float = 8.0

func _ready() -> void:
	roster = load("res://data/character_roster.tres")
	_load_names()
	character_dismissed.connect(_on_character_dismissed)
	await get_tree().process_frame
	await get_tree().process_frame

func start() -> void:
	next_character(0.0)

func _process(delta: float) -> void:
	if current_character == null or is_dead:
		return

	neural_pressure += pressure_rate * delta
	neural_pressure = clamp(neural_pressure, 0.0, 1.0)
	vitals_changed.emit(system_load, neural_pressure)

	if neural_pressure >= 1.0 or system_load >= 1.0:
		_kill_character()
		return

	if in_vfib:
		vfib_timer -= delta
		if vfib_timer <= 0.0:
			_kill_character()

func reset() -> void:
	current_character = null
	installed_drivers.clear()
	driver_to_install.clear()
	is_dead = false
	active_viruses.clear()
	system_load = 0.0
	neural_pressure = 0.0
	pressure_rate = 0.0
	pressure_rate_multiplier = 1.0
	in_vfib = false
	vfib_mistakes = 0
	vfib_correct_pid = -1
	vfib_processes.clear()
	vfib_timer = 0.0
	current_day = 1
	patients_today = 0
	deaths_today = 0
	currency = 0
	patients_helped = 0
	patients_killed = 0
	is_between_days = false
	shop_purchases.clear()
	nodes.clear()
	amp_lock = false
	speed_lock = false
	bad_wave_amp = 0
	bad_wave_speed = 0
	good_wave_amp = 0
	good_wave_speed = 0
	keypress_load_cost = 0.001
	backspace_load_cost = 0.005
	quarantine_limit = 3

#region CHARACTER

func _load_names() -> void:
	var file = FileAccess.open("res://data/names.txt", FileAccess.READ)
	if file == null:
		print("ERROR: could not open names.txt")
		return
	roster.names.clear()
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line != "":
			roster.names.append(line)
	file.close()
	print("loaded ", roster.names.size(), " names")

func next_character(delay: float = 8.0) -> void:
	if roster == null:
		return
	await get_tree().create_timer(delay).timeout
	load_character(_generate_character())

func load_character(character: Character) -> void:
	is_between_days = false
	current_character = character
	installed_drivers.clear()
	reset_vitals()
	character_loaded.emit(character)
	_maybe_upload_viruses(character)
	_maybe_trigger_vfib()

func _on_character_dismissed() -> void:
	patients_today += 1
	patients_helped += 1

	if patients_today >= _get_patients_per_day():
		patients_today = 0
		deaths_today = 0
		is_between_days = true
		current_day += 1
		day_advanced.emit(current_day)
	else:
		next_patient_incoming.emit()
		next_character()

func _generate_character() -> Character:
	driver_to_install.clear()
	var c = Character.new()

	c.character_name = roster.names.pick_random()

	var cyberware_pool = roster.cyberware_pool.duplicate()
	cyberware_pool.shuffle()
	var ware_count = randi_range(1, 3)
	var cyberware: Array[Cyberware] = []
	for i in ware_count:
		var ware = cyberware_pool[i].duplicate()
		# ware.drivers still has the full resource pool here; _assign_drivers reads it then replaces it
		cyberware.append(ware)
	c.cyberware = cyberware
	_assign_drivers(c.cyberware)
	c.cyberware = c.cyberware.filter(func(w): return not w.drivers.is_empty()) # remove redundant cyberware

	var all_types = Virus.Type.values()
	all_types.shuffle()
	var virus_count = _get_virus_count_for_day()
	virus_count = min(virus_count, all_types.size())
	for i in virus_count:
		c.virus_types.append(all_types[i])

	print("day: ", current_day, " | drivers: ", c.cyberware.reduce(func(acc, w): return acc + w.drivers.size(), 0), " | viruses: ", c.virus_types.map(func(v): return Virus.Type.keys()[v]))
	return c

func _get_patients_per_day() -> int:
	# day 1-2: 2 patients. increases by 1 every 2 days, hard cap at 6.
	if current_day <= 2:
		return 2
	return min(2 + (current_day - 2) / 2, 6)

func _assign_drivers(cyberware: Array[Cyberware]) -> void:
	var total_cap = _get_max_drivers_for_day()

	# build flat pool from the resource-defined drivers before clearing
	var pool: Array = []
	for ware in cyberware:
		for driver in ware.drivers:
			pool.append({"ware": ware, "driver": driver})
	pool.shuffle()

	# clear all, then assign up to cap
	for ware in cyberware:
		ware.drivers = []

	var assigned = 0
	for entry in pool:
		if assigned >= total_cap:
			break
		entry.ware.drivers.append(entry.driver)
		driver_to_install.append(entry.driver)
		assigned += 1

func dismiss_character(emit: bool = true) -> void:
	current_character = null
	installed_drivers.clear()
	system_load = 0.0
	neural_pressure = 0.0
	vitals_changed.emit(0.0, 0.0)
	if emit:
		character_dismissed.emit()

func earn_dismiss_currency(force: bool) -> int:
	var drivers_done = installed_drivers.size()
	var earned: int
	if force:
		# partial credit: 10¥ per completed driver
		earned = drivers_done * 10
	else:
		# full pay: 100¥ base + 50¥ per driver
		earned = 100 + drivers_done * 50
	currency += earned
	return earned

func _kill_character() -> void:
	if is_dead:
		return
	is_dead = true
	patients_killed += 1
	deaths_today += 1
	currency = max(0, currency - 200)
	character_died.emit()
	if deaths_today >= 2:
		game_over.emit()
		return
	dismiss_character(false)
	patients_today += 1
	if patients_today >= _get_patients_per_day():
		patients_today = 0
		deaths_today = 0
		is_between_days = true
		current_day += 1
		day_advanced.emit(current_day)
	else:
		next_patient_incoming.emit()
		next_character(DEATH_SEQUENCE_DURATION)

func _pick_drivers(ware: Cyberware) -> Array[Driver]:
	var pool = ware.drivers.duplicate()
	pool.shuffle()
	var max_drivers = _get_max_drivers_for_day()
	var count = min(randi_range(1, max_drivers), pool.size())
	var result: Array[Driver] = []
	for i in count:
		result.append(pool[i])
		driver_to_install.append(pool[i])
	return result

#endregion

#region SHOP

func get_shop_items() -> Array:
	return [
		{
			"id": "load_reducer",
			"name": "Load Reducer Patch",
			"desc": "reduces system load by 15% instantly and lowers per-keypress load cost.",
			"base_price": 150,
		},
		{
			"id": "pressure_dampener",
			"name": "Pressure Dampener",
			"desc": "permanently reduces neural pressure buildup rate by 20%.",
			"base_price": 200,
		},
		{
			"id": "quarantine_expansion",
			"name": "Quarantine Expansion",
			"desc": "adds one additional quarantine slot.",
			"base_price": 175,
		},
	]

func get_item_price(item_id: String) -> int:
	var base = 0
	for item in get_shop_items():
		if item.id == item_id:
			base = item.base_price
			break
	var times_bought = shop_purchases.get(item_id, 0)
	# each repeat purchase costs 50% more
	return int(base * pow(1.5, times_bought))

func purchase_item(item_id: String) -> bool:
	var price = get_item_price(item_id)
	if currency < price:
		return false
	currency -= price
	shop_purchases[item_id] = shop_purchases.get(item_id, 0) + 1
	_apply_item(item_id)
	return true

func _apply_item(item_id: String) -> void:
	match item_id:
		"load_reducer":
			system_load = max(0.0, system_load - 0.15)
			vitals_changed.emit(system_load, neural_pressure)
			keypress_load_cost = max(0.0, keypress_load_cost * 0.75)
			backspace_load_cost = max(0.0, backspace_load_cost * 0.75)
		"pressure_dampener":
			pressure_rate_multiplier *= 0.80
			pressure_rate *= 0.80 # apply immediately to current patient too
		"quarantine_expansion":
			quarantine_limit += 1

#endregion

#region DRIVERS

func install_driver(driver_name: String) -> bool:
	if driver_name in installed_drivers:
		print("DRIVER ALREADY INSTALLED!")
		return false
	installed_drivers.append(driver_name)
	driver_installed.emit(driver_name)
	return true

func uninstall_driver(driver_name: String) -> void:
	installed_drivers.erase(driver_name)
	reset_minigame_state()

func reset_minigame_state() -> void:
	amp_lock = false
	speed_lock = false
	bad_wave_amp = 0
	bad_wave_speed = 0

func all_drivers_installed() -> bool:
	if current_character == null:
		return false
	for cyberware in current_character.cyberware:
		for driver in cyberware.drivers:
			if driver.driver_name not in installed_drivers:
				return false
	return true

func _get_max_drivers_for_day() -> int:
	# Day 1: exactly 1 driver. Increases by 1 every 2 days after that, hard cap at 5.
	if current_day == 1:
		return 1
	return min(1 + (current_day - 1) / 2, 5)

#endregion


#region VIRUS

func _maybe_upload_viruses(character: Character) -> void:
	for virus_type in character.virus_types:
		var delay = randf_range(10.0, 30.0)
		await get_tree().create_timer(delay).timeout
		if current_character != character:
			return
		var v = Virus.create(virus_type)
		active_viruses.append(v)
		virus_uploaded.emit(v)
		print("virus " + v.type_name() + " uploaded!")

func valid_virus(pid: int) -> bool:
	for v in active_viruses:
		if v.pid == pid:
			return true
	return false

func quarantine_virus(pid: int) -> bool:
	if active_viruses.filter(func(v): return v.quarantined).size() >= quarantine_limit:
		return false
	for v in active_viruses:
		if v.pid == pid:
			v.quarantined = true
			return true
	print("ERROR: you shouldn't ever see this error message. call aaron!")
	return false

func purge_quarantined() -> void:
	active_viruses = active_viruses.filter(func(v): return not v.quarantined)

func has_virus(type: Virus.Type) -> bool:
	for v in active_viruses:
		if v.type == type and not v.quarantined:
			return true
	return false

func _get_virus_count_for_day() -> int:
	var roll = randf()
	match current_day:
		1:
			return 0
		2:
			if roll < 0.50:
				return 0
			else:
				return 1
		3, 4:
			if roll < 0.15:
				return 0
			elif roll < 0.85:
				return 1
			else:
				return 2
		_:
			var extra = min(current_day - 5, 5)
			var two_threshold = 0.40 + extra * 0.05
			var three_threshold = two_threshold + 0.10 + extra * 0.02
			if roll < 0.10:
				return 0
			elif roll < two_threshold:
				return 1
			elif roll < three_threshold:
				return 2
			else:
				return 3

#endregion


#region VITALS

func add_load(amount: float) -> void:
	if is_dead:
		return
	if is_between_days:
		return
	if current_character == null:
		return
	system_load = clamp(system_load + (amount * get_load_scale()) * 2.0, 0.0, 1.0)
	vitals_changed.emit(system_load, neural_pressure)
	if system_load >= 1.0:
		_kill_character()
		
func get_load_scale() -> float:
	return 1.0 / max(driver_to_install.size(), 1)

func allocate(amount: float) -> void:
	if amount > neural_pressure + 0.3:
		_kill_character()
		return
	neural_pressure = clamp(neural_pressure - amount, 0.0, 1.0)
	add_load(amount * 0.6)

func reset_vitals() -> void:
	is_dead = false
	system_load = 0.0
	neural_pressure = 0.0
	pressure_rate = randf_range(0.005, 0.025) * pressure_rate_multiplier # randomize pressure rate per character
	_schedule_pressure_spike()
	in_vfib = false
	vfib_mistakes = 0
	vfib_correct_pid = -1
	vfib_processes.clear()

func spike_pressure_rate(spiked_rate: float, duration: float) -> void:
	var og_pressure_rate = pressure_rate
	pressure_rate = spiked_rate
	await get_tree().create_timer(duration).timeout
	pressure_rate = og_pressure_rate

func _schedule_pressure_spike() -> void:
	await get_tree().create_timer(randf_range(5.0, 20.0)).timeout
	if current_character == null:
		return
	spike_pressure_rate(randf_range(0.04, 0.06), randf_range(1.5, 4.0))

func _maybe_trigger_vfib() -> void:
	await get_tree().create_timer(randf_range(45.0, 90.0)).timeout
	if current_character == null or is_dead:
		return
	if randf() < 0.15:
		_start_vfib()

func _start_vfib() -> void:
	in_vfib = true
	vfib_mistakes = 0
	vfib_timer = vfib_time_limit

	vfib_processes.clear()
	var innocents = INNOCENT_PROCESSES.duplicate()
	innocents.shuffle()
	var guilty = GUILTY_PROCESSES.pick_random().duplicate()
	guilty["pid"] = randi_range(1000, 99999)
	vfib_correct_pid = guilty["pid"]

	vfib_processes.append(guilty)
	for i in 2:
		var p = innocents[i].duplicate()
		p["pid"] = randi_range(1000, 99999)
		vfib_processes.append(p)
	vfib_processes.shuffle()

	vfib_started.emit()

func vfib_kill(pid: int) -> bool:
	if pid == vfib_correct_pid:
		in_vfib = false
		vfib_processes.clear()
		vfib_resolved.emit()
		return true
	vfib_mistakes += 1
	if vfib_mistakes >= 2:
		_kill_character()
	else:
		vfib_timer = max(vfib_timer - 5.0, 5.0)
	return false

#endregion


#region MINIGAMES

func handle_ping(address: String) -> String:
	for n in nodes:
		if n.address == address:
			if n.responsive:
				return address + ": reply received. node is live."
			else:
				return address + ": request timed out."
	return address + ": no route to host."

func handle_scp(id: String, address: String) -> bool:
	for n in nodes:
		if n.id == id and n.address == address and n.responsive:
			return true
	return false

#endregion
