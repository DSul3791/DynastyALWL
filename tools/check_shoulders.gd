extends SceneTree

# Headless check (Sonny, 30 Oct 2026): the Shoulders slider moves the shoulder joints, the upper arms and the cloth over them (a lot) and the chest only a little; the frames'
# shoulder values show in the joints; the neutral body is unchanged.
#   godot --headless --path . --script res://tools/check_shoulders.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	var rows: Dictionary = {}

	for s in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		rows[s] = _measure(s)

	print("shoulders -1 / 0 / +1: joint %.3f / %.3f / %.3f, mesh width at the shoulders %.3f / %.3f / %.3f, tunic %.3f / %.3f / %.3f, chest width %.3f / %.3f / %.3f" % [
		rows[-1.0]["joint"], rows[0.0]["joint"], rows[1.0]["joint"], rows[-1.0]["mesh"], rows[0.0]["mesh"], rows[1.0]["mesh"],
		rows[-1.0]["tunic"], rows[0.0]["tunic"], rows[1.0]["tunic"], rows[-1.0]["chest"], rows[0.0]["chest"], rows[1.0]["chest"]])
	var keys: Array = [-1.0, -0.5, 0.0, 0.5, 1.0]

	for what in ["joint", "mesh", "tunic"]:
		var rising: bool = true

		for i in range(1, keys.size()):
			rising = rising and float(rows[keys[i]][what]) > float(rows[keys[i - 1]][what]) + 0.005

		_ok(rising, "%s grows with every step of the slider" % what)

	_ok(float(rows[1.0]["joint"]) - float(rows[-1.0]["joint"]) > 0.1, "the shoulder joints move more than 10 cm each side over the whole slider (%.3f)" % (float(rows[1.0]["joint"]) - float(rows[-1.0]["joint"])))
	_ok(float(rows[1.0]["mesh"]) - float(rows[-1.0]["mesh"]) > 0.1, "and so does the mesh at shoulder height (%.3f)" % (float(rows[1.0]["mesh"]) - float(rows[-1.0]["mesh"])))
	_ok(float(rows[1.0]["tunic"]) - float(rows[-1.0]["tunic"]) > 0.1, "and the tunic over the shoulders (%.3f)" % (float(rows[1.0]["tunic"]) - float(rows[-1.0]["tunic"])))
	var chest_change: float = float(rows[1.0]["chest"]) - float(rows[-1.0]["chest"])
	var joint_change: float = float(rows[1.0]["joint"]) - float(rows[-1.0]["joint"])
	_ok(chest_change > 0.0 and chest_change < joint_change * 0.5, "the chest follows only a little (%.3f against the joints' %.3f)" % [chest_change, joint_change])
	# The neutral body is what it was: joint at 0.23 with a neutral build.
	_ok(absf(float(rows[0.0]["joint"]) - 0.23) < 0.001, "at 0 the joint is where it always was (%.3f)" % float(rows[0.0]["joint"]))

	# Frames: feminine < neutral < masculine in the joints.
	var joints: Array = []

	for frame in ["feminine", "neutral", "masculine"]:
		var g: Dictionary = Generator.make_genome("average")
		g["shoulders"] = float(Generator.FRAMES[frame]["shoulders"])
		joints.append(absf((Generator.rig(g)["global"][6] as Vector3).x))

	_ok(float(joints[0]) < float(joints[1]) and float(joints[1]) < float(joints[2]), "the frames' shoulder values show in the joints (%s)" % str(joints))
	# The arm and hand follow the joint.
	var narrow: Dictionary = Generator.make_genome("average")
	narrow["shoulders"] = -1.0
	var broad: Dictionary = Generator.make_genome("average")
	broad["shoulders"] = 1.0
	var rn: Array = Generator.rig(narrow)["global"]
	var rb: Array = Generator.rig(broad)["global"]
	_ok(absf((rb[8] as Vector3).x) > absf((rn[8] as Vector3).x) + 0.02 and absf((rb[12] as Vector3).x) > absf((rn[12] as Vector3).x) + 0.02, "the hands hang further out from broad shoulders (the arms angle in, so by less than the joints)")
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _measure(s: float) -> Dictionary:
	var g: Dictionary = Generator.make_genome("average")
	g["shoulders"] = s
	var built: Dictionary = Generator.build(g, 0.03, false)
	var rg: Dictionary = built["rig"]
	var verts: PackedVector3Array = built["arrays"][Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = built["arrays"][Mesh.ARRAY_COLOR]
	var joint: Vector3 = rg["global"][6]
	var mesh: float = 0.0
	var tunic: float = 0.0
	var chest: float = 0.0

	for i in range(verts.size()):
		var v: Vector3 = verts[i]

		if absf(v.y - joint.y) < 0.05:
			mesh = maxf(mesh, absf(v.x))

			if int(floor(colors[i].a * 8.0)) == 3:
				tunic = maxf(tunic, absf(v.x))

	chest = float(Generator.measures(g)["chest_half_width"])

	return {"joint": absf(joint.x), "mesh": mesh, "tunic": tunic, "chest": chest}


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)
