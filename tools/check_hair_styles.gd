extends SceneTree

# Headless check (Sonny, 30 Oct 2026): every hair style covers the scalp (no bald patch) at every Hair Length value on all four body types, has no hair on the face, draws with the hair
# colour, and the share code carries the style (older codes load with the first). Bald has no hair. The length slider changes the styles that use it and leaves the others alone.
#   godot --headless --path . --script res://tools/check_hair_styles.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")

const USES_LENGTH := ["long_loose", "side_part", "ponytail", "bun", "braid", "curly"]

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	for style in range(Generator.HAIR_STYLES.size()):
		var name: String = Generator.HAIR_STYLES[style]
		var counts: Array = []

		for preset in ["average", "broad", "lean", "stocky"]:
			for length in [-1.0, 0.0, 1.0]:
				var g: Dictionary = Generator.make_genome(preset, Color(0.82, 0.62, 0.48), Color(0.7, 0.3, 0.1))
				g["hair_style"] = style
				g["hair_length"] = length
				var r: Dictionary = _measure(g)
				var tag: String = "%s %s hair %.1f" % [name, preset, length]

				if name == "bald":
					_ok(int(r["hair"]) == 0, "%s: no hair at all (%d vertices)" % [tag, int(r["hair"])])
					_ok(int(r["top_total"]) > 0, "%s: the crown is skin" % tag)
				else:
					_ok(int(r["top_total"]) > 0 and int(r["top_bare"]) == 0, "%s: no bare scalp on the crown (%d of %d)" % [tag, int(r["top_bare"]), int(r["top_total"])])
					_ok(int(r["side_total"]) > 0 and int(r["side_bare"]) == 0, "%s: the sides above the ears are covered (%d of %d bare)" % [tag, int(r["side_bare"]), int(r["side_total"])])

				_ok(int(r["face_hair"]) == 0, "%s: no hair on the face (%d)" % [tag, int(r["face_hair"])])

				if preset == "average" and length == 0.0:
					counts.append(int(r["hair"]))

		# Draws with the hair colour: the material parameter is the genome's hair colour and the mesh has hair weights.
		var g2: Dictionary = Generator.make_genome("average", Color(0.82, 0.62, 0.48), Color(0.7, 0.3, 0.1))
		g2["hair_style"] = style
		var body: Node3D = GeneratedBody.new(g2, 0.05, false)
		var material: ShaderMaterial = body.body_mesh.material_override as ShaderMaterial
		_ok((material.get_shader_parameter("hair_color") as Color).is_equal_approx(Color(0.7, 0.3, 0.1)), "%s: draws in the hair colour" % name)
		body.free()
		# The share code carries the style.
		var back: Dictionary = Generator.decode(Generator.encode(g2))
		_ok(not back.is_empty() and int(back["hair_style"]) == style, "%s: the share code keeps the style" % name)

		# The length slider.
		var short: Dictionary = g2.duplicate(true)
		var long: Dictionary = g2.duplicate(true)
		short["hair_length"] = -1.0
		long["hair_length"] = 1.0
		var different: bool = Generator.primitives(short, Generator.rig(short), false) != Generator.primitives(long, Generator.rig(long), false)
		_ok(different == (name in USES_LENGTH), "%s: the Hair Length slider %s" % [name, "changes it" if name in USES_LENGTH else "does not change it"])

	# The styles are all different (hair vertex counts on the average body at length 0).
	var seen: Dictionary = {}

	for style in range(Generator.HAIR_STYLES.size()):
		var g3: Dictionary = Generator.make_genome("average")
		g3["hair_style"] = style
		var key: int = int(_measure(g3)["hair"])
		var prims: int = Generator.primitives(g3, Generator.rig(g3), false).size()
		var sig: String = "%d/%d" % [key, prims]
		print("  %s: %d hair vertices, %d primitives" % [Generator.HAIR_STYLES[style], key, prims])
		_ok(not seen.has(sig), "%s: different from the other styles (%s)" % [Generator.HAIR_STYLES[style], sig])
		seen[sig] = true

	# Older codes: version 3 has no style byte and loads with the first.
	var v3: PackedByteArray = PackedByteArray()
	v3.append(3)

	for i in range(20):
		v3.append(128)

	for i in range(15):
		v3.append(100)

	v3.append(Generator._crc8(v3))
	var old: Dictionary = Generator.decode(Marshalls.raw_to_base64(v3))
	_ok(not old.is_empty() and int(old["hair_style"]) == 0 and Generator.HAIR_STYLES[0] == "long_loose", "a version 3 code loads with the first style (long and loose, the old look)")
	_ok(Generator.CODE_VERSION == 4 and Generator.HAIR_STYLES.size() == 10, "version 4 and ten styles")
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _measure(g: Dictionary) -> Dictionary:
	var built: Dictionary = Generator.build(g, 0.03, false)
	var verts: PackedVector3Array = built["arrays"][Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = built["arrays"][Mesh.ARRAY_COLOR]
	var head: Vector3 = (built["rig"]["global"] as Array)[4]
	var hs: float = Generator.m(float(g["head"]), 0.85, 1.4)
	var r: Dictionary = {"hair": 0, "top_bare": 0, "top_total": 0, "side_bare": 0, "side_total": 0, "face_hair": 0}

	for i in range(verts.size()):
		var p: Vector3 = verts[i] - head
		var hair: bool = colors[i].r > 0.5

		if hair:
			r["hair"] += 1

		if p.y > 0.23 * hs and p.y < 0.34 * hs and Vector2(p.x, p.z).length() < 0.06:
			r["top_total"] += 1
			r["top_bare"] += 0 if hair else 1

		if absf(p.x) > 0.07 * hs and p.y > 0.22 * hs and p.y < 0.24 * hs and p.z > -0.04 * hs:
			r["side_total"] += 1
			r["side_bare"] += 0 if hair else 1

		if p.z < -0.07 * hs and p.y < 0.17 * hs and p.y > 0.03 * hs and hair:
			r["face_hair"] += 1

	return r
