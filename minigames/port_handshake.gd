extends Control

signal completed

var commands: Array[String] = ["ping", "scp"]

const NUMERIC_PREFIXES = [
	"192.168", "10.0", "172.16", "100.64", "198.18",
	"203.0", "169.254", "192.0", "198.51", "185.220",
	"45.33", "23.92", "104.21", "162.158", "141.101",
	"77.88", "31.13", "52.84", "13.107", "40.112",
	"8.8", "1.1", "9.9", "94.140", "176.103"
]
const NAMED_ADDRESSES = [
	"jotunheim.sys", "helheim.net", "bifrost.io", "yggdrasil.local",
	"synthcast.corp", "neurovault.net", "blacksite.io", "greybox.local",
	"deeplink.corp", "ironveil.net", "nullspace.io", "coldwire.local",
	"darknode.sys", "ghostframe.net", "voidpulse.io", "static.local",
	"deadchannel.sys", "lostpacket.net", "overflow.io", "kernel.local",
	"nowhere.sys", "silence.net", "redroom.io", "basement.local",
	"unmarked.sys", "forgotten.net", "buried.io", "offline.local"
]

@onready var lines = $Panel/MarginContainer/RichTextLabel

func _ready():
	GameManager.nodes = _generate_nodes()
	_display_nodes()

func get_tutorial() -> Array[String]:
	return [
		"establish a secure connection to retrieve the driver package.",
		"ping [address]  --  check if a node is live",
		"scp [id]@[address]  --  pull driver from a live node",
	]

func handle_command(cmd: String, args: Array) -> String:
	match cmd:
		"ping":
			if args.is_empty():
				return "usage: ping <address>"
			return GameManager.handle_ping(args[0])
		"scp":
			if args.is_empty():
				return "usage: scp <id>@<address>"
			var parts = args[0].split("@")
			if parts.size() != 2:
				return "scp: invalid format. use <id>@<address>"
			var id = parts[0]
			var address = parts[1]
			if GameManager.handle_scp(id, address):
				completed.emit()
				return "transfer complete."
			else:
				return "scp: connection refused or node not responsive."
	return ""

func _generate_nodes() -> Array:
	var result = []
	var used_addresses: Array = []
	while result.size() < 5:
		var address: String
		var attempts = 0
		while attempts < 20:
			if randf() < 0.5:
				address = "%s.%d.%d" % [NUMERIC_PREFIXES.pick_random(), randi_range(0, 255), randi_range(1, 254)]
			else:
				address = NAMED_ADDRESSES.pick_random()
			if address not in used_addresses:
				break
			attempts += 1
		used_addresses.append(address)
		var id = "%07d" % randi_range(1000000, 9999999)
		var days_ago = randi_range(0, 365)
		var unix = Time.get_unix_time_from_system() - (days_ago * 86400)
		var date = Time.get_date_dict_from_unix_time(unix)
		var date_str = "%02d/%02d/%04d" % [date.month, date.day, date.year]
		var response_chance = lerp(0.9, 0.05, days_ago / 365.0)
		var responsive = randf() < response_chance
		result.append({
			"id": id,
			"address": address,
			"last_accessed": date_str,
			"days_ago": days_ago,
			"responsive": responsive
		})
	return result

func _display_nodes() -> void:
	lines.clear()
	lines.append_text("ID        ADDRESS          LAST ACCESSED\n")
	lines.append_text("----------------------------------------\n")
	for n in GameManager.nodes:
		lines.append_text("%s  %-20s %s\n" % [n.id, n.address, n.last_accessed])
