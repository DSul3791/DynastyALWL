extends SceneTree

# Headless check (Sonny, 30 Oct 2026): the arm stays sane over the whole range of the Arms, Hands, Muscle, Build and Shoulders sliders: segment lengths follow the Arms slider, the arm is
# nearly straight at rest, the wrist is a real wrist (not pinched), the forearm runs into the hand (no gap, so no butt joint), the hand is not far out from the ribs, and the joints
# move smoothly from one slider step to the next; both arms mirror each other.
#   godot --headless --path . --script res://tools/check_arm_sanity.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	for slider in ["arms", "hands", "muscle", "build", "shoulders", "height"]:
		var last_wrist: Array = []

		for value in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var g: Dictionary = Generator.make_genome("average")
			g[slider] = value
			var wrists: Array = _check_one(g, "%s %.1f" % [slider, value])

			if not last_wrist.is_empty():
				for side in range(2):
					var step: float = (wrists[side] as Vector3).distance_to(last_wrist[side])
					_ok(step < 0.12, "%s %.1f: the wrist moves smoothly from the last step (%.3f m)" % [slider, value, step])

			last_wrist = wrists

	# A rough corner of the space: everything extreme at once, and the broad and lean presets.
	for preset in ["broad", "lean", "stocky"]:
		_check_one(Generator.make_genome(preset), preset)

	var corner: Dictionary = Generator.make_genome("average")

	for key in ["arms", "hands", "muscle", "build", "shoulders"]:
		corner[key] = 1.0

	_check_one(corner, "everything +1")

	for key in ["arms", "hands", "muscle", "build", "shoulders"]:
		corner[key] = -1.0

	_check_one(corner, "everything -1")
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


# Returns the two wrist positions.
func _check_one(g: Dictionary, tag: String) -> Array:
	var rg: Dictionary = Generator.rig(g)
	var p: Array = rg["global"]
	var arm: float = float(rg["dims"]["arm"])
	var prims: Array = Generator.primitives(g, rg, false)
	var wrists: Array = []

	for side in [-1.0, 1.0]:
		var o: int = 5 if side < 0.0 else 9
		var shoulder: Vector3 = p[o + 1]
		var elbow: Vector3 = p[o + 2]
		var wrist: Vector3 = p[o + 3]
		wrists.append(wrist)
		_ok(absf(shoulder.distance_to(elbow) - 0.29 * arm) < 0.001 and absf(elbow.distance_to(wrist) - 0.26 * arm) < 0.001, "%s: segment lengths follow the Arms slider (%.3f, %.3f for arm %.3f)" % [tag, shoulder.distance_to(elbow), elbow.distance_to(wrist), arm])
		var upper: Vector3 = (elbow - shoulder).normalized()
		var fore: Vector3 = (wrist - elbow).normalized()
		_ok(rad_to_deg(upper.angle_to(fore)) < 15.0, "%s: the arm is nearly straight at rest (%.1f degrees at the elbow)" % [tag, rad_to_deg(upper.angle_to(fore))])
		_ok(wrist.y < elbow.y and elbow.y < shoulder.y, "%s: the arm hangs down" % tag)
		var chest_half: float = float(Generator.measures(g)["chest_half_width"])
		_ok(absf(wrist.x) - chest_half < 0.14 and absf(wrist.x) > 0.1, "%s: the hand hangs %.3f m outside the chest edge, not far out" % [tag, absf(wrist.x) - chest_half])
		var fore_cone: Dictionary = {}
		var hand: Dictionary = {}

		for q in prims:
			if int(q["bone"]) == o + 2 and q["t"] == "cone":
				fore_cone = q

			if int(q["bone"]) == o + 3 and q["t"] == "ell":
				hand = q

		_ok(not fore_cone.is_empty() and not hand.is_empty(), "%s: the forearm and the hand exist" % tag)

		if fore_cone.is_empty() or hand.is_empty():
			continue

		var wrist_r: float = float(fore_cone["rb"])
		var start_r: float = float(fore_cone["ra"])
		_ok(wrist_r >= 0.6 * start_r and wrist_r > 0.027, "%s: a real wrist (%.3f m radius against %.3f at the elbow)" % [tag, wrist_r, start_r])
		_ok(Generator.prim_sdf(hand, fore_cone["b"]) < 0.0, "%s: the forearm runs into the hand (no gap): its end is inside the palm" % tag)
		var palm_half: float = (hand["r"] as Vector3).x
		_ok(palm_half / wrist_r < 1.7 and palm_half / wrist_r > 0.8, "%s: the palm is %.2f times the wrist radius, not a ball on a pin" % [tag, palm_half / wrist_r])

	_ok(absf((wrists[0] as Vector3).x + (wrists[1] as Vector3).x) < 0.001 and absf((wrists[0] as Vector3).y - (wrists[1] as Vector3).y) < 0.001, "%s: both arms mirror each other" % tag)
	return wrists
