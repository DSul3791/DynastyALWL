extends SceneTree

# What the five parts of Dynasty_Base_Male_Parts_Split.glb are: size, centre, and the width of each part in ten slices along Y (Kathleen, 1 Nov 2026).

func _init() -> void:
	var inst: Node = (load("res://assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb") as PackedScene).instantiate()
	root.add_child(inst)

	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var m: ArrayMesh = mi.mesh as ArrayMesh
		var a: Array = m.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bb: AABB = m.get_aabb()
		var line: String = "PART %s node scale %s pos %s tris %d normals %s aabb pos %s size %s | widths along y:" % [mi.name, mi.scale, mi.position, (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, a[Mesh.ARRAY_NORMAL] != null, bb.position, bb.size]

		for s in range(10):
			var y0: float = bb.position.y + bb.size.y * float(s) / 10.0
			var y1: float = y0 + bb.size.y / 10.0
			var lo: float = 9.0
			var hi: float = -9.0
			var zlo: float = 9.0
			var zhi: float = -9.0

			for p in v:
				if p.y >= y0 and p.y < y1:
					lo = minf(lo, p.x)
					hi = maxf(hi, p.x)
					zlo = minf(zlo, p.z)
					zhi = maxf(zhi, p.z)

			line += " [%.0f-%.0f z%.0f..%.0f]" % [lo * 1000.0, hi * 1000.0, zlo * 1000.0, zhi * 1000.0]

		print(line)

	quit()
