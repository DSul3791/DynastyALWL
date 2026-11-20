extends RefCounted

# Boot tracks leading from a road to a bandit camp's cold fire pit (docs/design/BANDIT_CAMPS.md stage 3, the signs): one dark, flat print
# per [dx, dy, dz, yaw degrees] of the mark's world row at the road (server_items.lay_bandit_camp), drawn as one MultiMesh under the mark's
# node, so a client that joins near the road sees them with the mark and they go with it.

const PRINT_SIZE := Vector3(0.11, 0.015, 0.28)   # a boot sole pressed into the ground
const PRINT_COLOR := Color(0.22, 0.17, 0.12)
const LIFT_M := 0.01                              # just over the ground so the prints do not flicker in it


static func make(tracks: Array) -> Node3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = PRINT_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = PRINT_COLOR
	material.roughness = 1.0
	box.material = material
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	var prints: Array = tracks.filter(func(row): return row is Array and (row as Array).size() == 4)
	multi.instance_count = prints.size()

	for n in prints.size():
		var row: Array = prints[n]
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(row[3])))
		multi.set_instance_transform(n, Transform3D(basis, Vector3(float(row[0]), float(row[1]) + LIFT_M, float(row[2]))))

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "Tracks"
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
