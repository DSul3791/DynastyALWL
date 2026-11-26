extends SceneTree

# The clip answers kept with the animal models (data/animals/clip_answers.json, made by tools/clip_answers.gd; Lane A r4 at Low, 26 Nov
# 2026: a kind's first body measured its clips and skins in the frame, 76-106 ms) are the answers the game would measure now, model by model:
# the same models, the same clip height shares, the same skin answers and the same models absent. Needs the model pack (Lane A); without
# it, it says NOT COMPARED.
#   godot --headless --path . --script res://src/worldgen/tools/test_clip_answers.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const ClipAnswersTool := preload("res://tools/clip_answers.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AnimalViewScript.CLIP_ANSWERS_PATH)) if FileAccess.file_exists(AnimalViewScript.CLIP_ANSWERS_PATH) else null
	check(parsed is Dictionary and (parsed as Dictionary).get("models", null) is Dictionary, "the kept answers are there")
	var kept: Dictionary = (parsed as Dictionary).get("models", {}) if parsed is Dictionary else {}
	var kept_absent: Array = (parsed as Dictionary).get("absent", []) if parsed is Dictionary else []
	var view = AnimalViewScript.new()
	var now: Dictionary = ClipAnswersTool.collect(view)
	view.free()
	var absent: Array = now["absent"]
	now.erase("absent")

	if now.is_empty():
		print("NOT COMPARED: no animal model is drawn here (the cloud, Lane B or LFS pointers): the kept answers were not checked")
		print("test_clip_answers: %d failures" % failures)
		quit(1 if failures > 0 else 0)
		return

	var keys_now: Array = now.keys()
	var keys_kept: Array = kept.keys()
	keys_now.sort()
	keys_kept.sort()
	check(keys_now == keys_kept, "the same models as measured now (%d kept, %d now): only kept %s, only now %s" % [keys_kept.size(), keys_now.size(), str(keys_kept.filter(func(k): return not now.has(k))), str(keys_now.filter(func(k): return not kept.has(k)))])
	absent.sort()
	kept_absent.sort()
	check(absent == kept_absent, "the same models absent (%s now, %s kept)" % [str(absent), str(kept_absent)])
	var off: PackedStringArray = PackedStringArray()

	for key in now:
		if not kept.has(key):
			continue

		var a: Dictionary = now[key]
		var b: Dictionary = kept[key]

		for part in ["shares", "skins"]:
			var x: Dictionary = a[part]
			var y: Dictionary = b.get(part, {})

			if x.keys().size() != y.keys().size():
				off.append("%s %s: %d now, %d kept" % [key, part, x.size(), y.size()])
				continue

			for name_text in x:
				if not y.has(name_text):
					off.append("%s %s %s: not kept" % [key, part, name_text])
				elif part == "shares" and absf(float(x[name_text]) - float(y[name_text])) > 0.000001:
					off.append("%s %s: %.6f now, %.6f kept" % [key, name_text, float(x[name_text]), float(y[name_text])])
				elif part == "skins" and bool(x[name_text]) != bool(y[name_text]):
					off.append("%s skin %s: %s now, %s kept" % [key, name_text, str(x[name_text]), str(y[name_text])])

	check(off.is_empty(), "every kept answer is the one measured now; run tools/clip_answers.gd for: %s" % "; ".join(off.slice(0, 12)))
	print("test_clip_answers: %d failures" % failures)
	quit(1 if failures > 0 else 0)
