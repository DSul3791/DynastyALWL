extends RefCounted

# The player's characters, kept on this computer only (Sonny, 30 Oct 2026): one file per character in user://characters/ holding the text form of a character record
# (name and body share code; the rest of the record is left blank until the rules of CHARACTER_DESIGN_VISION.md Part 9 are decided), plus the "active" character the game
# wears. Nothing here touches accounts or the server. Saving the same text form later on a server is the intended next step.

const Record := preload("res://src/client/character/character_record.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

static var dir: String = "user://characters"       # tests point this somewhere else
static var _counter: int = 0


static func name_ok(name: String) -> bool:
	return name == name.strip_edges() and not name.is_empty() and name.length() <= Record.NAME_MAX and not name.contains("\n") and not name.contains("\t")


# Every readable character, oldest first: [{id, name, code, genome}]. Files that are not a character (or whose code no longer decodes) are skipped.
static func list() -> Array:
	var out: Array = []

	if not DirAccess.dir_exists_absolute(dir):
		return out

	var ids: PackedStringArray = PackedStringArray()

	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			ids.append(file.trim_suffix(".json"))

	var sorted_ids: Array = Array(ids)
	sorted_ids.sort_custom(func(a: String, b: String) -> bool: return a.length() < b.length() or (a.length() == b.length() and a < b))

	for id in sorted_ids:
		var one: Dictionary = get_character(id)

		if not one.is_empty():
			out.append(one)

	return out


static func get_character(id: String) -> Dictionary:
	var path: String = "%s/%s.json" % [dir, id]

	if id.is_empty() or not FileAccess.file_exists(path):
		return {}

	var rec: Dictionary = Record.from_text(FileAccess.get_file_as_string(path))
	var code: String = str(rec.get("genome_code", ""))
	var genome: Dictionary = Generator.decode(code) if code != "" else {}

	if rec.is_empty() or genome.is_empty() or not name_ok(str(rec.get("name", ""))):
		return {}

	return {"id": id, "name": str(rec["name"]), "code": code, "genome": genome, "gender": str(rec.get("gender", Record.DEFAULT_GENDER)),
		"pronouns": str(rec.get("pronouns", Record.DEFAULT_PRONOUNS)), "frame": str(rec.get("frame", Record.DEFAULT_FRAME))}


static func count() -> int:
	return list().size()


# Saves a new character and returns its id, or "" when the name is not acceptable or the code does not decode.
static func add(name: String, code: String, gender: String = Record.DEFAULT_GENDER, pronouns: String = "", frame: String = "") -> String:
	if not name_ok(name) or Generator.decode(code).is_empty() or not Record.GENDERS.has(gender):
		return ""

	pronouns = pronouns if pronouns != "" else Record.default_pronouns(gender)
	frame = frame if frame != "" else Record.default_frame(gender)

	if not Record.PRONOUNS.has(pronouns) or not Record.FRAMES.has(frame):
		return ""

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("user://") else dir)
	_counter += 1
	var id: String = "%d%03d" % [int(Time.get_unix_time_from_system() * 1000.0), _counter % 1000]
	var rec: Dictionary = Record.blank()
	rec["name"] = name
	rec["genome_code"] = code
	rec["gender"] = gender
	rec["pronouns"] = pronouns
	rec["frame"] = frame
	return id if _write(id, rec) else ""


static func rename(id: String, name: String) -> bool:
	var one: Dictionary = get_character(id)

	if one.is_empty() or not name_ok(name):
		return false

	return _write(id, _record_of(one, name, str(one["pronouns"])))


# Changes the pronouns of a saved character (a player may change them any time). False for an unknown character or pronouns.
static func set_pronouns(id: String, pronouns: String) -> bool:
	var one: Dictionary = get_character(id)

	if one.is_empty() or not Record.PRONOUNS.has(pronouns):
		return false

	return _write(id, _record_of(one, str(one["name"]), pronouns))


static func _record_of(one: Dictionary, name: String, pronouns: String) -> Dictionary:
	var rec: Dictionary = Record.blank()
	rec["name"] = name
	rec["genome_code"] = one["code"]
	rec["gender"] = one["gender"]
	rec["pronouns"] = pronouns
	rec["frame"] = one["frame"]
	return rec


static func delete(id: String) -> bool:
	var path: String = "%s/%s.json" % [dir, id]

	if id.is_empty() or not FileAccess.file_exists(path):
		return false

	DirAccess.remove_absolute(path)

	if active_id() == id:
		_clear_active()

	return true


# The character the game wears: the one set with set_active, else the newest, else {} when there are none.
static func active() -> Dictionary:
	var one: Dictionary = get_character(active_id())

	if not one.is_empty():
		return one

	var all: Array = list()
	return all[all.size() - 1] if not all.is_empty() else {}


static func active_id() -> String:
	var path: String = dir + "/active.txt"
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""


static func set_active(id: String) -> bool:
	if get_character(id).is_empty():
		return false

	var file := FileAccess.open(dir + "/active.txt", FileAccess.WRITE)

	if file == null:
		return false

	file.store_string(id)
	return true


static func _clear_active() -> void:
	var path: String = dir + "/active.txt"

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _write(id: String, rec: Dictionary) -> bool:
	var file := FileAccess.open("%s/%s.json" % [dir, id], FileAccess.WRITE)

	if file == null:
		return false

	file.store_string(Record.to_text(rec))
	return true
