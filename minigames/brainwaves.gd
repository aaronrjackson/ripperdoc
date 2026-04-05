extends Control

signal completed

var commands: Array[String] = ["wave"]

func get_tutorial() -> Array[String]:
	return [
		"sync the incoming wave to the patient's neural frequency.",
		"wave amp [num]   --  adjust amplitude",
		"wave freq [num]  --  adjust frequency",
	]

func handle_command(cmd: String, args: Array) -> String:
	if cmd != "wave":
		return ""
	if args.size() < 2:
		return "usage: wave [amp|freq] [num]"

	match args[0]:
		"amp":
			if GameManager.amp_lock:
				return "amplitude already matches -- locked"
			GameManager.bad_wave_amp += args[1].to_int()
		"freq":
			if GameManager.speed_lock:
				return "frequency already matches -- locked"
			GameManager.bad_wave_speed += args[1].to_int()
		_:
			return "usage: wave [amp|freq] [num]"

	var result = ""
	if not GameManager.amp_lock and abs(GameManager.good_wave_amp - GameManager.bad_wave_amp) < 5:
		result += "AMPLITUDE MATCHES -- LOCKED\n"
		GameManager.amp_lock = true
	if not GameManager.speed_lock and GameManager.good_wave_speed == GameManager.bad_wave_speed:
		result += "FREQUENCY MATCHES -- LOCKED\n"
		GameManager.speed_lock = true

	if GameManager.speed_lock and GameManager.amp_lock:
		result += "waves successfully synced!"
		completed.emit()

	return result.strip_edges()
