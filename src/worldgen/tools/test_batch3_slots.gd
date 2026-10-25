extends SceneTree

# Batch 3 (Kathleen's R1 sounds, data/sound/batch3_slots.json) loads into SlotSounds: every slot has files that exist and import, and the
# shore net's server lines map to their cues.
#   godot --headless --path . --script res://src/worldgen/tools/test_batch3_slots.gd

const SlotSoundsScript := preload("res://src/client/slot_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var slots = SlotSoundsScript.new()
	slots.setup(null)

	for name in ["bed_lie", "bed_rise", "net_cast", "net_haul", "thatch_pick", "twine_lash"]:
		check(slots.has_slot(name), "slot %s loads" % name)
		var files: Array = (slots._slots.get(name, {}) as Dictionary).get("files", [])
		check(files.size() >= 3, "%s has its clips" % name)

		for path in files:
			check(ResourceLoader.exists(str(path)), "%s imports (open the project once in the editor if this fails)" % path)

	var fishing: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fishing.json"))
	var net: Dictionary = fishing["net"]
	check(SlotSoundsScript.net_cue(str(net["say_start"])) == "net_cast", "the net's start line is the cast cue")
	check(SlotSoundsScript.net_cue(str(net["say_nothing"])) == "net_haul", "an empty haul is the haul cue")
	check(SlotSoundsScript.net_cue("You haul in trout, perch.") == "net_haul", "a haul line is the haul cue")
	check(SlotSoundsScript.net_cue(str(net["say_cancel"])) == "", "a cancel line makes no cue")
	check(SlotSoundsScript.net_cue("You land a trout.") == "", "a rod catch makes no net cue")
	print("batch 3 slot tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
