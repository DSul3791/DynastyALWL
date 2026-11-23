extends SceneTree

# Fresh tracks (hunting thread, 23 Nov 2026): a drawn animal's footfalls near the player leave prints that fade over life_s (longer with
# Tracking); birds leave none; steps far off leave none; never more than max_prints.
#   godot --headless --path . --script res://src/worldgen/tools/test_fresh_tracks.gd

const TracksScript := preload("res://src/client/fresh_tracks.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var t = TracksScript.new()
	var c: Dictionary = t.cfg
	t.player_at = func() -> Vector3: return Vector3.ZERO
	check(t.shape_of.get("deer", "") == "hoof" and t.shape_of.get("wolf", "") == "paw" and t.shape_of.get("rabbit", "") == "hop", "deer hoof, wolf paw, rabbit hop")

	for n in 6:
		t.on_step("deer", Vector3(2.0 + float(n) * 0.8, 1.0, 3.0), 1000 + n * 300)

	check(t.shown() == 6, "a walking deer near the player leaves a print a step (%d)" % t.shown())
	check(absf(float(t.marks[5][1])) < 0.01, "heading east along its steps (yaw %.2f)" % float(t.marks[5][1]))
	check(absf(float(t.marks[0][1])) < 0.01, "the first print of the walk learns its heading from the second")
	var lone = TracksScript.new()
	lone.player_at = func() -> Vector3: return Vector3.ZERO
	lone.on_step("deer", Vector3(2.0, 0.0, 2.0), 1000)
	check(not TracksScript.read_text(lone.marks[0], 100, 1000, c).contains("heading"), "a single footfall gives no heading, even to a master tracker")
	lone.on_step("deer", Vector3(5.0, 0.0, 2.0), 1300)   # a herd neighbour 3 m off, not this deer's next step
	check(is_nan(float(lone.marks[1][1])) and is_nan(float(lone.marks[0][1])), "a step of another deer 3 m away gives no heading rather than a wrong one")
	lone.on_step("dog", Vector3(1.0, 0.0, 1.0), 1400)
	lone.on_step("dog", Vector3(1.8, 0.0, 1.0), 1700)
	check(lone.shown() == 2, "a dog at heel leaves no prints (it would crowd out the wild trail and the E key)")
	check(TracksScript.read_text(lone.marks[0], 1, 1000 + 20000, c).contains("just now") and TracksScript.read_text(lone.marks[0], 1, 1000 + 200000, c).contains("minutes"), "just now, then minutes ago")
	lone.free()
	t.on_step("deer", Vector3(6.2, 1.0, 3.1), 2900)
	check(t.shown() == 6, "a step 0.2 m from the last one (a shuffle) leaves no print")
	t.on_step("duck", Vector3(1.0, 1.0, 1.0), 3000)
	t.on_step("deer", Vector3(float(c["draw_m"]) + 5.0, 1.0, 0.0), 3100)
	check(t.shown() == 6, "a duck and a deer past draw_m leave nothing")
	var near: Array = t.readable(Vector3(5.0, 1.0, 3.0), 3000)
	check(not near.is_empty(), "a fresh print near the player can be read")
	var plain: String = TracksScript.read_text(t.mark_at(int(near[0][0])), 1, 3000, c)
	check(plain.begins_with("Deer prints") and plain.contains("just now") and not plain.contains("heading"), "untrained: whose and how fresh (%s)" % plain)
	check(TracksScript.read_text(t.mark_at(int(near[0][0])), int(c["read_way_level"]), 3000, c).contains("heading east"), "at read_way_level: which way it went")
	check(TracksScript.read_text([Vector3.ZERO, 0.0, 0, "paw", "wolf"], 1, 1000, c).contains(str(c["read"]["warning"])), "a wolf's prints warn")
	check(not TracksScript.read_text([Vector3.ZERO, 0.0, 0, "paw", "dog"], 1, 1000, c).contains(str(c["read"]["warning"])), "a dog's prints do not")
	check(TracksScript.read_text([Vector3.ZERO, 0.0, 0, "hoof", "deer"], 1, 600000, c).contains("a while ago"), "an old print says so")
	t.update(3200)
	check(t._nodes.has("hoof") and (t._nodes["hoof"] as MultiMeshInstance3D).multimesh.instance_count == 6, "the prints are drawn")
	var life0: float = TracksScript.life_s(0, c)
	check(TracksScript.life_s(100, c) > life0 and is_equal_approx(TracksScript.life_s(100, c), life0 * float(c["life_mult"])), "a tracker sees them longer")
	t.update(1000 + int(life0 * 1000.0) + 2000)
	check(t.shown() == 0 and (t._nodes["hoof"] as MultiMeshInstance3D).multimesh.instance_count == 0, "gone after life_s")

	for n in int(c["max_prints"]) + 50:
		t.on_step("rabbit", Vector3(float(n % 20) * 0.7, 0.0, 0.0), 100000 + n * 10)

	check(t.shown() == int(c["max_prints"]), "never more than max_prints (%d)" % t.shown())
	t.free()
	print("test_fresh_tracks: ", "PASS" if failures == 0 else "FAIL %d" % failures)
	quit(1 if failures > 0 else 0)
