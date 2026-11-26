extends SceneTree

# Writes data/animals/clip_answers.json: for every animal model (each kind, look and young model of data/animals/models.json), the answers
# a kind's first body worked out in the frame (Lane A r4 at Low, 26 Nov 2026: 76-106 ms for the first body of a kind): each clip's height
# in its first frame as a share of the standing height (the clips that lay the body flat or throw it up are refused by it), and whether each
# skinned mesh's binds needed rebuilding. animal_view.gd takes the kept answers (_height_share, _fit_skin) and measures only what is missing.
# Run it again after changing a model file or its row (tools/check_clip_answers.py in the merge check and test_clip_answers say so):
#   godot --headless --path . --script res://tools/clip_answers.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const OUT_PATH := "res://data/animals/clip_answers.json"


func _init() -> void:
	var view = AnimalViewScript.new()
	var made: Dictionary = collect(view)
	var conflicts: PackedStringArray = view._conflicts
	view.free()

	if not conflicts.is_empty():
		print("clip_answers: one clip of one model measured two ways, nothing written: %s" % "; ".join(conflicts))
		quit(1)
		return

	var absent: Array = made["absent"]
	made.erase("absent")
	var out: Dictionary = {"about": "Each animal model's clip height shares and skin answers, measured by tools/clip_answers.gd. absent: kind|scene drawn with the code-built body (no file or no mesh here).", "models": made, "absent": absent}
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)

	if f == null:
		print("clip_answers: cannot write %s (%s)" % [OUT_PATH, error_string(FileAccess.get_open_error())])
		quit(1)
		return

	f.store_string(JSON.stringify(out, "\t", true, true) + "\n")
	f.close()
	var shares: int = 0

	for k in made:
		shares += ((made[k] as Dictionary)["shares"] as Dictionary).size()

	print("clip_answers: %d models, %d clip shares written to %s; %d absent" % [made.size(), shares, OUT_PATH, absent.size()])
	quit(0)


# Every model of every kind drawn once with nothing kept, its answers recorded: {"kind|scene": {"shares": {clip: share}, "skins": {mesh: rebuilt}}},
# and under "absent" the kind|scene keys with no model drawn (the row's scene after its look and young model are laid over it).
static func collect(view) -> Dictionary:
	view._measure_all = true
	view._recording = {}
	var absent: Array = []

	for kind in view._model_rows():
		var number: Variant = AnimalViewScript.KIND_OF_SPECIES.find_key(str(kind))

		if number == null:
			continue

		var row: Dictionary = view._model_rows()[kind]
		var looks: int = maxi(1, (row.get("variants", []) as Array).size())

		for look in looks:
			for young in [false, true]:
				if young and not row.get("young_model", null) is Dictionary:
					continue

				var body: Node3D = view._make_model(int(number), look, young, true)

				if body == null:
					var key: String = "%s|%s" % [str(kind), str(scene_of(row, look, young))]

					if not absent.has(key):
						absent.append(key)

					continue

				var drawn: Dictionary = body.get_meta("model_row", {})
				(view._recording as Dictionary).get_or_add("%s|%s" % [str(kind), str(drawn.get("scene", ""))], {"shares": {}, "skins": {}})   # a model with no clips is listed too
				body.free()

	var made: Dictionary = view._recording
	view._recording = null
	view._measure_all = false

	for key in made:
		absent.erase(key)      # a look drawn from another look's file

	absent.sort()
	made["absent"] = absent
	return made


# The scene a kind's look (and young model) is drawn from, as _make_model lays them over the row.
static func scene_of(row: Dictionary, look: int, young: bool) -> String:
	var merged: Dictionary = row.duplicate()
	var looks: Array = row.get("variants", [])

	if not looks.is_empty():
		merged.merge(looks[look % looks.size()], true)

	if young and merged.get("young_model", null) is Dictionary:
		merged.merge(merged["young_model"], true)

	return str(merged.get("scene", ""))
