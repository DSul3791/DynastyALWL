extends RefCounted

# What this character knows when inspecting things (the / key). A placeholder
# until the skills and attributes system exists: the stats below stand in for
# the character sheet, and the notebook is saved as a small file per character.
#
# The first time the character looks at a kind of thing:
#   1. Memory check: the thing's base familiarity (0 to 100 percent, from its
#      table: high for everyday and for famous things, low for obscure ones)
#      plus 5 percent per point of memory. On success they remember it and it
#      is kept as known.
#   2. Otherwise a second check: d20 + skill + the better of wisdom and
#      intelligence against FIGURE_OUT_DC. On success they know they don't
#      know: "Unknown" (asked again after a while). On failure the game makes
#      up a wrong guess ("Might be Nightshade") that is kept, and shown every
#      time, until the character is corrected.
#
# Keys are strings like "f12" (flora species), "s3" soil, "r5" rock, "o1" ore.

const SAVE_PATH := "user://character_knowledge.json"
const FIGURE_OUT_DC := 10
const UNKNOWN_RETRY_MSEC := 60000

# Placeholder character sheet; skills belong to the coming skills system.
var stats: Dictionary = {"memory": 1, "wisdom": 1, "intelligence": 0, "horticulture": 0, "geology": 0}
var admin: bool = false          # admin look-around (flying): sees the truth, remembers nothing
var _notebook: Dictionary = {}   # key -> {"state": "known"} or {"state": "wrong", "guess": "Nightshade"}
var _unknown_until: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_load()


# The text to show for a thing: `true_label` when known, "Unknown", or a wrong
# guess. `familiarity` is the base percent chance of already knowing it (any
# inspectable thing: plant, animal, rock, ore, later items and places), `skill`
# names the stat that helps
# ("horticulture" or "geology"), `guesses` are display names to mistake it for.
func reveal(key: String, true_label: String, familiarity: int, skill: String, guesses: Array) -> String:
	if admin:
		return true_label

	var note: Dictionary = _notebook.get(key, {})

	if note.get("state", "") == "known":
		return true_label

	if note.get("state", "") == "wrong":
		return "Might be %s" % str(note["guess"])

	var now: int = Time.get_ticks_msec()

	if now < int(_unknown_until.get(key, 0)):
		return "Unknown"

	if _rng.randi_range(1, 100) <= familiarity + 5 * int(stats["memory"]):
		_notebook[key] = {"state": "known"}
		_save()
		return true_label

	var mind: int = maxi(int(stats["wisdom"]), int(stats["intelligence"]))

	if _rng.randi_range(1, 20) + int(stats.get(skill, 0)) + mind >= FIGURE_OUT_DC or guesses.is_empty():
		_unknown_until[key] = now + UNKNOWN_RETRY_MSEC
		return "Unknown"

	var guess: String = str(guesses[_rng.randi_range(0, guesses.size() - 1)])
	_notebook[key] = {"state": "wrong", "guess": guess}
	_save()
	return "Might be %s" % guess


# Does the character know this thing for certain (no roll, no change)? Used to gate using herbs.
func is_known(key: String) -> bool:
	return admin or _notebook.get(key, {}).get("state", "") == "known"


# Puts right a wrong belief (a teacher, a book, a reference): the thing is now known.
func correct(key: String) -> void:
	_notebook[key] = {"state": "known"}
	_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))

	if typeof(parsed) == TYPE_DICTIONARY:
		_notebook = parsed


func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(_notebook))
		file.close()
