extends Node

signal character_loaded(character: Character)
signal character_dismissed
signal character_died # when load or pressure == 1.0
signal driver_installed(driver_name: String)
signal virus_uploaded(virus: Virus)
signal vitals_changed(load: float, pressure: float)
signal vfib_started
signal vfib_resolved

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
var neural_pressure: float = 0.0
var pressure_rate: float
var in_vfib: bool = false
var vfib_mistakes: int = 0
var vfib_correct_pid: int = -1
var vfib_processes: Array = [] # list of dicts with pid, name, descriptor
var vfib_timer: float = 0.0
var vfib_time_limit: float = 35.0

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

func _ready() -> void:
	roster = load("res://data/character_roster.tres")
	_load_names()
	# wait two frames so all scene nodes are ready before emitting character_loaded
	await get_tree().process_frame
	await get_tree().process_frame

func start() -> void:
	next_character()

func _process(delta: float) -> void:
	if current_character == null or is_dead:
		return
	neural_pressure += pressure_rate * delta
	neural_pressure = clamp(neural_pressure, 0.0, 1.0) # snsure always within bounds
	vitals_changed.emit(system_load, neural_pressure) # update vitals
	if neural_pressure >= 1.0 or system_load >= 1.0: # kill if too high
		_kill_character()
	
	# handle vfib countdown
	if in_vfib:
		vfib_timer -= delta
		if vfib_timer <= 0.0:
			_kill_character()


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

func next_character() -> void:
	if roster == null:
		return
	load_character(_generate_character())

func load_character(character: Character) -> void:
	current_character = character
	installed_drivers.clear()
	reset_vitals()
	character_loaded.emit(character)
	_maybe_upload_viruses(character) # starts random virus upload timer
	_maybe_trigger_vfib() # starts random vfib start timer
	
func _generate_character() -> Character:
	var c = Character.new()
	
	# pick random name
	c.character_name = roster.names.pick_random()
	
	# pick random cyberware (no duplicates)
	var cyberware_pool = roster.cyberware_pool.duplicate()
	cyberware_pool.shuffle()
	var ware_count = randi_range(1, 3) # choose 1-3 random cyberware

	var cyberware: Array[Cyberware] = []
	for i in ware_count:
		var ware = cyberware_pool[i].duplicate()
		ware.drivers = _pick_drivers(ware)
		cyberware.append(ware)
	c.cyberware = cyberware
	
	# pick random virus
	var all_types = Virus.Type.values()
	all_types.shuffle()
	var virus_roll = randf()
	if virus_roll < 0.01: # 1% chance of three viruses
		c.virus_types.append(all_types[0])
		c.virus_types.append(all_types[1])
		c.virus_types.append(all_types[2])
	elif virus_roll < 0.26: # 25% chance of two viruses
		c.virus_types.append(all_types[0])
		c.virus_types.append(all_types[1])
	elif virus_roll < .96: # 70% chance of one virus
		c.virus_types.append(all_types[0])
	elif virus_roll < 1.0: # 4% chance of no virus
		pass
	
	print("viruses:")
	for v in c.virus_types:
		match v:
			Virus.Type.SLOW: print("SLOW")
			Virus.Type.CORRUPT: print("CORRUPT")
			Virus.Type.AMNESIA: print("AMNESIA")
	return c

func dismiss_character() -> void:
	current_character = null
	installed_drivers.clear()
	character_dismissed.emit()

func _kill_character() -> void:
	if is_dead:
		return
	is_dead = true
	character_died.emit()
	dismiss_character()  # clears state
	# next_character() called by terminal after death sequence plays out
	
func _pick_drivers(ware: Cyberware) -> Array[Driver]:
	var pool = ware.drivers.duplicate()
	pool.shuffle()
	var count = randi_range(1, 3)
	count = min(count, pool.size())
	var result: Array[Driver] = []
	for i in count:
		result.append(pool[i])
		driver_to_install.append(pool[i])
	return result

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

func all_drivers_installed() -> bool:
	if current_character == null:
		return false
	for cyberware in current_character.cyberware:
		for driver in cyberware.drivers:
			if driver.driver_name not in installed_drivers:
				return false
	return true

#endregion

#region VIRUS

func _maybe_upload_viruses(character: Character) -> void:
	for virus_type in character.virus_types:
		var delay = randf_range(10.0, 30.0)  # upload on a random timer mid-session
		await get_tree().create_timer(delay).timeout
		if current_character != character:
			return  # character was dismissed before virus fired
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
		return false  # no slots
	for v in active_viruses:
		if v.pid == pid:
			v.quarantined = true
			return true
	print("ERROR: you shouldn't ever see this error message. call aaron!")
	return false

func purge_quarantined() -> void:
	active_viruses = active_viruses.filter(func(v): return not v.quarantined)
	# TODO: spike vitals stub here

func has_virus(type: Virus.Type) -> bool:
	for v in active_viruses:
		if v.type == type and not v.quarantined:
			return true
	return false

#endregion

#region VITALS

func add_load(amount: float) -> void:
	if is_dead:
		return
	system_load = clamp(system_load + amount, 0.0, 1.0) # add
	vitals_changed.emit(system_load, neural_pressure)
	if system_load >= 1.0:
		_kill_character()

func allocate(amount: float) -> void:
	# allocating too much kills character
	if amount > neural_pressure + 0.3:
		_kill_character()
		return
	neural_pressure = clamp(neural_pressure - amount, 0.0, 1.0)
	add_load(amount * 0.6)  # allocating costs system load

func reset_vitals() -> void:
	
	is_dead = false
	system_load = 0.0
	neural_pressure = 0.0
	# randomize pressure rate per character
	pressure_rate = randf_range(0.005, 0.025)
	# occasionally spike mid-session
	_schedule_pressure_spike()
	
	# reset vfib
	in_vfib = false
	vfib_mistakes = 0
	vfib_correct_pid = -1
	vfib_processes.clear()

func spike_pressure_rate(spiked_rate: float, duration: float) -> void:
	var og_pressure_rate = pressure_rate # save the original pressure rate
	pressure_rate = spiked_rate
	await get_tree().create_timer(duration).timeout
	pressure_rate = og_pressure_rate  # back to base

func _schedule_pressure_spike() -> void:
	await get_tree().create_timer(randf_range(5.0, 20.0)).timeout # random time until spike
	if current_character == null:
		return
	spike_pressure_rate(randf_range(0.04, 0.06), randf_range(1.5, 4.0))

func _maybe_trigger_vfib() -> void:
	# called only from load_character, fires randomly mid session
	await get_tree().create_timer(randf_range(30.0, 90.0)).timeout
	if current_character == null or is_dead:
		return
	if randf() < 0.2: # 20% chance after the delay - overall rare
		_start_vfib()

func _start_vfib() -> void:
	in_vfib = true
	vfib_mistakes = 0
	vfib_timer = vfib_time_limit
	
	# pick random processes
	vfib_processes.clear()
	var innocents = INNOCENT_PROCESSES.duplicate()
	innocents.shuffle()
	var guilty = GUILTY_PROCESSES.pick_random().duplicate()
	guilty["pid"] = randi_range(1000, 99999)
	vfib_correct_pid = guilty["pid"]
	
	vfib_processes.append(guilty)
	for i in 2: # 2 innocent processes
		var p = innocents[i].duplicate()
		p["pid"] = randi_range(1000, 99999)
		vfib_processes.append(p)
	vfib_processes.shuffle() # TODO: actually sort by pid in increasing order
	
	# TODO: possible for two or mmore processes (or viruses) to have the same pid needs fix
	
	vfib_started.emit()

# returns true if correct
func vfib_kill(pid: int) -> bool:
	if pid == vfib_correct_pid:
		# success
		in_vfib = false
		vfib_processes.clear()
		vfib_resolved.emit()
		return true
	else:
		# failure
		vfib_mistakes += 1
		if vfib_mistakes >= 2:
			_kill_character()
		else:
			vfib_timer = max(vfib_timer - 5.0, 5.0)  # lose 5 seconds, min 5 left
		return false

#endregion
