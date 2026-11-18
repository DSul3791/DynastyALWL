extends SceneTree

# The inner voice's voice set is compiled from the body model and traits (data/items/inner_voice_sets.json, src/shared/inner_voice_profile.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_inner_voice_profile.gd

const Profile := preload("res://src/shared/inner_voice_profile.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var bold: Dictionary = {"boldness": 0.9, "wisdom": 0.7}
	var shy: Dictionary = {"boldness": 0.1, "wisdom": 0.2}
	check(Profile.set_id("body_1", bold, "a").begins_with("masculine_steady_"), "a bold, wise character on Body 1 gets a steady voice of Body 1's timbre")
	check(Profile.set_id("body_1", shy, "b").begins_with("masculine_nervous_"), "a shy, unsure character gets a nervous voice")
	check(Profile.set_id("body_1", {}, "c").begins_with("masculine_steady_"), "no traits count as middling (steady)")
	check(Profile.set_id("body_1", bold, "same") == Profile.set_id("body_1", bold, "same"), "the same character always gets the same set")

	var seen: Dictionary = {}
	var families: Dictionary = {}

	for n in 200:
		var id: String = Profile.set_id("other", bold, "character %d" % n)
		seen[id] = true
		families[id.split("_")[0]] = true

	check(families.size() == 2, "a body model not in body_families takes either family, by character id")
	check(seen.size() >= 4, "different characters spread over the voices of a family")

	var all: PackedStringArray = Profile.all_set_ids()
	check(all.size() == 8, "eight voice sets are defined")

	for id in seen:
		check(all.has(id), "chosen set %s exists in the data" % id)

	quit(1 if failures > 0 else 0)
