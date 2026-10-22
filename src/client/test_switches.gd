extends RefCounted

# Experiment switches (Steve's bisect, Dave 2026-10-21): Esc > Advanced turns each suspect feature off on its own, so a crash or stall can be
# tried with one thing off at a time. Default on, remembered between runs in user://test_switches.cfg.

const PATH := "user://test_switches.cfg"
const KEYS := [
	["log_grass", "Felled-log grass strip"],
	["trails", "Grass trample and game trails"],
	["clearing", "Placed-item clearing circles"],
	["speech", "Voice and inner voice speech"],
	["ambient", "Ambient generated sounds"],
]

var _on: Dictionary = {}


func _init() -> void:
	var file: ConfigFile = ConfigFile.new()
	var loaded: bool = file.load(PATH) == OK

	for entry in KEYS:
		_on[entry[0]] = bool(file.get_value("switches", entry[0], true)) if loaded else true


func on(key: String) -> bool:
	return bool(_on.get(key, true))


func set_on(key: String, value: bool) -> void:
	_on[key] = value
	var file: ConfigFile = ConfigFile.new()

	for entry in KEYS:
		file.set_value("switches", entry[0], bool(_on.get(entry[0], true)))

	file.save(PATH)


func label(key: String) -> String:
	for entry in KEYS:
		if entry[0] == key:
			return "%s: %s" % [entry[1], "on" if on(key) else "OFF"]

	return key
