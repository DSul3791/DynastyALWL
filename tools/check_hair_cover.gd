extends SceneTree

# Headless check (Sonny, 30 Oct 2026): the hair covers the top and the sides of the head at every hair length and body type (no bare scalp), nothing but skin shows on the face
# below the hairline, and the boots cover the toes. Material weights come from the vertex colours (COLOR.r hair, UV = trousers, boots).
#   godot --headless --path . --script res://tools/check_hair_cover.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	for preset in ["average", "broad", "lean", "stocky"]:
		for length in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var g: Dictionary = Generator.make_genome(preset)
			g["hair_length"] = length
			var built: Dictionary = Generator.build(g, 0.03, false)
			var arrays: Array = built["arrays"]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var head: Vector3 = (built["rig"]["global"] as Array)[4]
			var hs: float = Generator.m(float(g["head"]), 0.85, 1.4)
			var top_bare: int = 0
			var top_total: int = 0
			var side_bare: int = 0
			var side_total: int = 0
			var face_hair: int = 0
			var toe_skin: int = 0

			for i in range(verts.size()):
				var p: Vector3 = verts[i] - head
				var hair: bool = colors[i].r > 0.5

				# The crown: above 0.23 head heights and within 6 cm of the axis.
				if p.y > 0.23 * hs and p.y < 0.28 * hs and Vector2(p.x, p.z).length() < 0.06:
					top_total += 1
					top_bare += 0 if hair else 1

				# The sides above the ears: x beyond 7 cm, y between 0.22 and 0.24 head heights (above the largest ears), in front of the ear line and behind the brow.
				if absf(p.x) > 0.07 * hs and p.y > 0.22 * hs and p.y < 0.24 * hs and p.z > -0.04 * hs:
					side_total += 1
					side_bare += 0 if hair else 1

				# The face below the hairline: in front (z < -0.07), below the brows.
				if p.z < -0.07 * hs and p.y < 0.17 * hs and p.y > 0.03 * hs and hair:
					face_hair += 1

			_ok(top_total > 0 and top_bare == 0, "%s hair %.1f: no bare scalp on the crown (%d of %d)" % [preset, length, top_bare, top_total])
			_ok(side_total > 0 and side_bare == 0, "%s hair %.1f: the sides above the ears are covered (%d of %d bare)" % [preset, length, side_bare, side_total])
			_ok(face_hair == 0, "%s hair %.1f: no hair on the face below the brows (%d)" % [preset, length, face_hair])

			if length == 0.0:
				# Toes: every vertex in front of the foot's toe line and below the ankle should be boot (UV.y), not skin.
				var feet_y: float = 0.09
				var rig_global: Array = built["rig"]["global"]
				var toe_l: Vector3 = rig_global[16]
				var toe_r: Vector3 = rig_global[20]

				for i in range(verts.size()):
					var v: Vector3 = verts[i]

					for toe in [toe_l, toe_r]:
						if v.distance_to(toe) < 0.04 and v.y < feet_y and uvs[i].y < 0.5:
							toe_skin += 1

				_ok(toe_skin == 0, "%s: no skin vertex around the toes (%d)" % [preset, toe_skin])

	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)
