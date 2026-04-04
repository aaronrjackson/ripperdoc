extends Node

var roster: CharacterRoster
var current_character: Character = null
var installed_drivers: Array[String] = []
var bad_wave_speed: int = 0
var bad_wave_amp: int = 0
var good_wave_speed: int = 0
var good_wave_amp: int = 0
var amp_lock: bool = false
var speed_lock: bool = false


signal character_loaded(character: Character)
signal driver_installed(driver_name: String)
signal character_dismissed

func _ready() -> void:
	roster = load("res://data/character_roster.tres")
	_load_names()
	call_deferred("next_character")

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
	character_loaded.emit(character)
	
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
	
	return c

func _pick_drivers(ware: Cyberware) -> Array[Driver]:
	var pool = ware.drivers.duplicate()
	pool.shuffle()
	var count = randi_range(1, 3)
	count = min(count, pool.size())
	var result: Array[Driver] = []
	for i in count:
		result.append(pool[i])
	return result

func install_driver(driver_name: String) -> bool:
	if driver_name in installed_drivers:
		print("DRIVER ALREADY INSTALLED!")
		return false
	installed_drivers.append(driver_name)
	driver_installed.emit(driver_name)
	return true

func all_drivers_installed() -> bool:
	if current_character == null:
		return false
	for cyberware in current_character.cyberware:
		for driver in cyberware.drivers:
			if driver.driver_name not in installed_drivers:
				return false
	return true

func dismiss_character() -> void:
	current_character = null
	installed_drivers.clear()
	character_dismissed.emit()
