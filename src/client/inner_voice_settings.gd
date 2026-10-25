extends RefCounted

# Esc > Settings > Inner voice (Dave 24 Oct): hints on/off and inner dialogue on/off, saved per player on this PC. Both default on (also when the file is missing).
# The server still sends every line (protocol 38); the client drops the lines of a switched-off class before the subtitle and the sound (inventory_view._on_thought).
# The symptom message of a sickness is not a line of the voice and is never filtered. Which class a kind belongs to: data/items/inner_voice_classes.json.

const CONFIG := "user://inner_voice.cfg"
const CLASSES_PATH := "res://data/items/inner_voice_classes.json"

var hints: bool = true
var dialogue: bool = true

var _path: String = CONFIG
var _classes: Dictionary = {}


func _init(path: String = CONFIG, classes_path: String = CLASSES_PATH) -> void:
	_path = path
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(classes_path))
	_classes = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var file: ConfigFile = ConfigFile.new()

	if file.load(_path) == OK:
		hints = bool(file.get_value("inner_voice", "hints", true))
		dialogue = bool(file.get_value("inner_voice", "dialogue", true))


# "hint" or "dialogue" for a line kind.
func class_of(kind: String) -> String:
	if (_classes.get("hint", []) as Array).has(kind) or (kind.begins_with("hint_") and not (_classes.get("dialogue", []) as Array).has(kind)):
		return "hint"

	return "dialogue"


# False when the player has switched off the class this kind belongs to.
func allows(kind: String) -> bool:
	return hints if class_of(kind) == "hint" else dialogue


func set_hints(on: bool) -> void:
	hints = on
	_save()


func set_dialogue(on: bool) -> void:
	dialogue = on
	_save()


func _save() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("inner_voice", "hints", hints)
	file.set_value("inner_voice", "dialogue", dialogue)
	file.save(_path)
