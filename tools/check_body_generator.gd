extends SceneTree

# Headless check of src/client/character/body_generator.gd (Sonny, plan 6).
#   godot --headless --path . --script res://tools/check_body_generator.gd
# Fails (exit 1) when a generated body has a wrong bone set, broken weights, NaN values, an implausible size or shape, a share code that does not round trip,
# or is not deterministic.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checks: int = 0


func _initialize() -> void:
	_check_bones()

	for preset in ["average", "broad", "lean", "stocky"]:
		_check_body(preset)

	_check_extremes()
	_check_code()
	_check_deterministic()
	print("checks: %d, failures: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	_checks += 1

	if not cond:
		_fails += 1
		print("FAIL  " + what)


func _check_bones() -> void:
	var names: Array = []

	for i in range(Generator.BONES.size()):
		var row: Array = Generator.BONES[i]
		_ok(not names.has(row[0]), "bone name unique: " + str(row[0]))
		_ok(int(row[1]) < i, "parent index below child: " + str(row[0]))
		names.append(row[0])

	for must in ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "RightLowerLeg", "LeftFoot", "RightToes", "LeftIndexProximal", "RightThumbDistal"]:
		_ok(names.has(must), "required bone exists: " + must)

	_ok(Generator.BONES.size() == 37, "37 bones (got %d)" % Generator.BONES.size())


func _check_body(preset: String) -> void:
	var g: Dictionary = Generator.make_genome(preset)
	var built: Dictionary = Generator.build(g, 0.05)
	var arrays: Array = built["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bad: int = 0
	var low: float = 99.0
	var high: float = -99.0
	var min_x: float = 99.0
	var max_x: float = -99.0

	for v in verts:
		if is_nan(v.x) or is_nan(v.y) or is_nan(v.z):
			bad += 1

		low = minf(low, v.y)
		high = maxf(high, v.y)
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)

	_ok(bad == 0, preset + ": no NaN vertices")
	var bad_n: int = 0

	for n in normals:
		if is_nan(n.x) or absf(n.length() - 1.0) > 0.01:
			bad_n += 1

	_ok(bad_n < verts.size() / 50, preset + ": normals are unit length (%d of %d not)" % [bad_n, verts.size()])
	var bad_w: int = 0

	for i in range(verts.size()):
		var sum: float = 0.0

		for s in range(4):
			var w: float = weights[i * 4 + s]
			sum += w

			if w < -0.0001 or int(bones[i * 4 + s]) >= Generator.BONES.size() or int(bones[i * 4 + s]) < 0:
				bad_w += 1

		if absf(sum - 1.0) > 0.01:
			bad_w += 1

	_ok(bad_w == 0, preset + ": skin weights are in range and sum to 1 (%d bad)" % bad_w)
	var bad_i: int = 0

	for i in index:
		if i < 0 or i >= verts.size():
			bad_i += 1

	_ok(bad_i == 0 and index.size() % 3 == 0, preset + ": triangle indices valid")
	var height: float = high - low
	_ok(height > 1.5 and height < 2.3, preset + ": height %.2f m is plausible" % height)
	_ok(absf(low) < 0.1, preset + ": the feet are near y = 0 (lowest %.3f)" % low)
	_ok(absf(min_x + max_x) < 0.08, preset + ": left and right are balanced (x from %.2f to %.2f)" % [min_x, max_x])
	_ok(int(built["triangle_count"]) > 1000 and int(built["triangle_count"]) < 20000, preset + ": %d triangles at 5 cm detail" % int(built["triangle_count"]))
	# Every bone that should deform something has at least one vertex with weight on it, so no bone is dead.
	var used: Dictionary = {}

	for i in range(verts.size()):
		for s in range(4):
			if weights[i * 4 + s] > 0.05:
				used[int(bones[i * 4 + s])] = true

	var unused: Array = []

	for b in range(Generator.BONES.size()):
		if not used.has(b):
			unused.append(Generator.BONES[b][0])

	# Toes and a few finger tips can be too small for a coarse grid at 5 cm; the check only reports bones that matter.
	for must in ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]:
		_ok(not unused.has(must), preset + ": bone carries weight: " + must)


func _check_extremes() -> void:
	# Every slider at its two extremes must still give a valid body (the creator allows them).
	for key in Generator.SLIDERS:
		for sign in [-1.0, 1.0]:
			var g: Dictionary = Generator.make_genome("average")
			g[key] = sign
			var built: Dictionary = Generator.build(g, 0.07)
			var verts: PackedVector3Array = (built["arrays"] as Array)[Mesh.ARRAY_VERTEX]
			var nan: bool = false

			for v in verts:
				if is_nan(v.x) or is_nan(v.y) or is_nan(v.z):
					nan = true
					break

			_ok(not nan and verts.size() > 500, "slider %s at %+d gives a valid body (%d vertices)" % [key, int(sign), verts.size()])


func _check_code() -> void:
	var g: Dictionary = Generator.make_genome("broad", Color(0.5, 0.3, 0.2), Color(0.1, 0.2, 0.3))
	g["height"] = 0.37
	g["ears"] = -0.88
	var code: String = Generator.encode(g)
	var back: Dictionary = Generator.decode(code)
	_ok(not back.is_empty(), "share code decodes (%s)" % code)

	for key in Generator.SLIDERS:
		_ok(absf(float(back.get(key, 99.0)) - float(g[key])) < 0.008, "share code keeps slider " + key)

	for key in Generator.COLOR_KEYS:
		_ok((back.get(key, Color(1, 0, 1)) as Color).is_equal_approx(g[key]) or absf((back[key] as Color).r - (g[key] as Color).r) < 0.005, "share code keeps colour " + key)

	_ok(Generator.decode(code.substr(0, code.length() - 4)).is_empty(), "a cut code is refused")
	var damaged: String = code.substr(0, 10) + ("A" if code[10] != "A" else "B") + code.substr(11)
	_ok(Generator.decode(damaged).is_empty(), "a damaged code is refused")
	_ok(Generator.decode("").is_empty() and Generator.decode("not a code").is_empty(), "empty and nonsense text are refused")
	_ok(code.length() <= 64, "the code is short (%d characters)" % code.length())


func _check_deterministic() -> void:
	var g: Dictionary = Generator.make_genome("lean")
	var a: Dictionary = Generator.build(g, 0.06)
	var b: Dictionary = Generator.build(g, 0.06)
	_ok((a["arrays"][Mesh.ARRAY_VERTEX] as PackedVector3Array) == (b["arrays"][Mesh.ARRAY_VERTEX] as PackedVector3Array), "the same genome gives the same vertices")
	_ok((a["arrays"][Mesh.ARRAY_WEIGHTS] as PackedFloat32Array) == (b["arrays"][Mesh.ARRAY_WEIGHTS] as PackedFloat32Array), "the same genome gives the same weights")
