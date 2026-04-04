# virus.gd
class_name Virus
extends Resource

enum Type { SLOW, CORRUPT, AMNESIA }

var pid: int
var type: Type
var quarantined: bool = false

static func create(t: Type) -> Virus:
	var v = Virus.new()
	v.pid = randi_range(10000, 99999)
	v.type = t
	v.quarantined = false
	return v

func type_name() -> String:
	match type:
		Type.SLOW: return "SLOW"
		Type.CORRUPT: return "CORRUPT"
		Type.AMNESIA: return "AMNESIA"
	return "UNKNOWN"
