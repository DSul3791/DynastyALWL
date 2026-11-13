extends SceneTree

# BUGLIST-002 (13 Nov 2026): the looks of the 28 empty doorway frames and the 28 separately made doors (7 tiers x single, double, single arched, double arched), shut and open.
# Bounds and solids only (no pictures), checked against the opening geometry written out here from the contract (docs/ai-team/missions/BUGLIST-002/CONTRACT.md), not read back from
# piece_look.gd: single 1.0 x 2.0 m clear in a 2 m piece; double 2.0 x 2.0 m in a 4 m piece; arched openings keep that envelope with a rounded top springing at 1.5 m with the
# crown at 2.0 m (single: a semicircle of radius 0.5 m; double: one segmental arch of radius 1.25 m over the 2 m span).
#   godot --headless --path . --script res://src/worldgen/tools/test_door_looks.gd

const LookTable := preload("res://src/client/look_table.gd")
const PieceLook := preload("res://src/client/piece_look.gd")

const OPENINGS := ["single", "double", "single_arched", "double_arched"]
const TIERS := ["crude", "rustic", "refined", "sturdy", "superior", "engineered", "fortified"]
const FRAMES := {
	"crude": ["thatch_doorway", "thatch_double_doorway", "thatch_arched_doorway", "thatch_double_arched_doorway"],
	"rustic": ["log_doorway", "log_double_doorway", "log_arched_doorway", "log_double_arched_doorway"],
	"refined": ["doorway_section", "double_doorway", "wood_arched_doorway", "wood_double_arched_doorway"],
	"sturdy": ["stone_doorway", "stone_double_doorway", "stone_arched_doorway", "stone_double_arched_doorway"],
	"superior": ["brick_doorway", "brick_double_doorway", "brick_arched_doorway", "brick_double_arched_doorway"],
	"engineered": ["engineered_doorway", "engineered_double_doorway", "engineered_arched_doorway", "engineered_double_arched_doorway"],
	"fortified": ["fortified_doorway", "fortified_double_doorway", "fortified_arched_doorway", "fortified_double_arched_doorway"],
}
const DOORS := {"single": "door", "double": "double_door", "single_arched": "arched_door", "double_arched": "double_arched_door"}
const MARGIN := 0.09           # the solids follow an arch in steps of about 8 cm, so a point this far inside the curve is covered and one this far above it is solid

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	_run()


func _gap(opening: String) -> float:
	return 2.0 if opening.begins_with("double") else 1.0


func _arched(opening: String) -> bool:
	return opening.ends_with("arched")


# Half the clear width of an opening at height y, from the contract's geometry.
func _clear_half(opening: String, y: float) -> float:
	var half: float = _gap(opening) * 0.5

	if y >= 2.0:
		return 0.0

	if not _arched(opening) or y <= 1.5:
		return half

	if opening == "single_arched":
		return sqrt(maxf(0.25 - (y - 1.5) * (y - 1.5), 0.0))

	return sqrt(maxf(1.5625 - (y - 0.75) * (y - 0.75), 0.0))


# The height of the arch's underside at x.
func _arch_top(opening: String, x: float) -> float:
	if opening == "single_arched":
		return 1.5 + sqrt(maxf(0.25 - x * x, 0.0))

	return 0.75 + sqrt(maxf(1.5625 - x * x, 0.0))


func _mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false

	return box


func _solid_at(node: Node3D, point: Vector3) -> bool:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = child
		var shape: BoxShape3D = cs.shape as BoxShape3D

		if shape == null:
			continue

		var local: Vector3 = (node.global_transform.affine_inverse() * cs.global_transform).affine_inverse() * point

		if absf(local.x) <= shape.size.x * 0.5 and absf(local.y) <= shape.size.y * 0.5 and absf(local.z) <= shape.size.z * 0.5:
			return true

	return false


func _build(look: String) -> Node3D:
	check(LookTable.has_look(look), "%s is in the look table" % look)
	var node: Node3D = LookTable.build(look)
	get_root().add_child(node)
	return node


# The points of the clear opening (a grid of 5 cm at three depths), `inset` m inside the curve above the springing.
func _opening_points(opening: String, inset: float, depths: Array) -> Array:
	var points: Array = []
	var half: float = _gap(opening) * 0.5

	for iy in range(1, 40):
		var y: float = 0.05 * float(iy)
		var w: float = (_clear_half(opening, y + inset) if _arched(opening) and y > 1.5 else half) - 0.01
		var ix: int = 0

		while -w + 0.05 * float(ix) <= w:
			for z in depths:
				points.append(Vector3(-w + 0.05 * float(ix), y, float(z)))

			ix += 1

	return points


func _frame_checks(opening: String, look: String) -> void:
	var node: Node3D = _build(look)
	var gap: float = _gap(opening)
	var box: AABB = _mesh_box(node)
	check(box.position.x >= -gap - 0.05 and box.end.x <= gap + 0.05 and box.position.y >= -0.01 and box.end.y <= 2.46 and box.end.y >= 2.3 and box.position.z >= -0.2 and box.end.z <= 0.2,
		"%s: in its %d m wall piece, as thick as a wall (%s)" % [look, int(gap * 2.0), box])
	check(_solid_at(node, Vector3(gap * 0.75, 1.0, 0.0)) and _solid_at(node, Vector3(-gap * 0.75, 1.0, 0.0)) and _solid_at(node, Vector3(0.0, 2.2, 0.0)),
		"%s: solid at both sides and over the opening" % look)
	var blocked: Array = []

	for point in _opening_points(opening, 0.0, [-0.1, 0.0, 0.1]):
		if _solid_at(node, point):
			blocked.append(point)

	check(blocked.is_empty(), "%s: nothing solid in the clear opening (%s)" % [look, str(blocked.slice(0, 3))])

	if _arched(opening):
		var thin: Array = []
		var x: float = -gap * 0.5 + 0.03

		while x < gap * 0.5 - 0.029:
			if not _solid_at(node, Vector3(x, _arch_top(opening, x) + MARGIN + 0.005, 0.0)):
				thin.append(x)

			x += 0.05

		check(thin.is_empty(), "%s: the wall just above the curve is solid (%s)" % [look, str(thin.slice(0, 3))])
	else:
		var leaf: bool = false

		for child in node.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = child
			var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			leaf = leaf or (b.position.x > -gap * 0.5 + 0.06 and b.end.x < gap * 0.5 - 0.06 and b.position.y < 1.9 and b.end.y > 0.1)    # a mesh wholly inside the opening: a door leaf

		check(not leaf, "%s: no door leaf hangs in the opening" % look)

	check(not LookTable.has_look(look + "_open"), "%s: no open twin look (a doorway has no door)" % look)
	node.free()


# The z extent of the leaf's boards: the meshes in a door wood (Hardwood, Plank) at least 4.5 cm deep; returns [thickness, number of different layers].
func _boards(node: Node3D) -> Array:
	var woods: Array = [PieceLook._wood_mat("hard"), PieceLook._wood_mat("rich"), PieceLook._wood_mat("rough"), PieceLook._wood_mat("heavy"), PieceLook._wood_mat("eng")]
	var low: float = INF
	var high: float = -INF
	var layers: Array = []

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var box: BoxMesh = mi.mesh as BoxMesh

		if box == null or not woods.has(mi.material_override) or box.size.z < 0.045:
			continue

		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		low = minf(low, b.position.z)
		high = maxf(high, b.end.z)
		var layer: float = snappedf(b.position.z + b.size.z * 0.5, 0.01)

		if not layers.has(layer):
			layers.append(layer)

	return [high - low, layers.size()]


# Metal on a door: the volume of its boxes whose surface has no wood picture (iron, steel, brass, rivets).
func _metal(node: Node3D) -> float:
	var total: float = 0.0

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var box: BoxMesh = mi.mesh as BoxMesh
		var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D

		if box != null and mat != null and mat.albedo_texture == null:
			total += box.size.x * box.size.y * box.size.z

	return total


func _wood_meshes(node: Node3D) -> int:
	var count: int = 0

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D

		if mat != null and mat.albedo_texture != null:
			count += 1

	return count


func _door_checks(tier: String, opening: String) -> void:
	var look: String = "%s_%s" % [tier, DOORS[opening]]
	var gap: float = _gap(opening)
	var half: float = gap * 0.5
	var leaves: int = 2 if opening.begins_with("double") else 1
	var shut: Node3D = _build(look)
	var box: AABB = _mesh_box(shut)
	check(box.position.x >= -half - 0.15 and box.end.x <= half + 0.15 and box.position.y >= -0.06 and box.end.y <= 2.12 and box.position.z >= -0.2 and box.end.z <= 0.2,
		"%s: in its opening and the frame's plane (%s)" % [look, box])
	var uncovered: Array = []

	for point in _opening_points(opening, MARGIN, [0.0]):
		if not _solid_at(shut, point):
			uncovered.append(point)

	check(uncovered.is_empty(), "%s: the shut door's solids cover the opening (%s)" % [look, str(uncovered.slice(0, 3))])
	var outside: Array = []

	for z in [-0.05, 0.0, 0.05]:
		for iy in range(1, 50):
			var y: float = 0.05 * float(iy)
			var ix: int = 0

			while -half - 0.4 + 0.05 * float(ix) <= half + 0.4:
				var x: float = -half - 0.4 + 0.05 * float(ix)
				ix += 1

				if absf(x) <= _clear_half(opening, y) + 0.001 and y <= 2.0 + 0.001:   # 0.05 * 40 is a hair over 2.0
					continue

				if _solid_at(shut, Vector3(x, y, z)):
					outside.append(Vector3(x, y, z))

	check(outside.is_empty(), "%s: no solid outside the opening (%s)" % [look, str(outside.slice(0, 3))])
	var leaf_nodes: int = 0

	for child in shut.get_children():
		if not child is StaticBody3D:
			leaf_nodes += 1

	check(leaf_nodes == leaves, "%s: %d leaves (found %d)" % [look, leaves, leaf_nodes])

	if _arched(opening):
		check(_solid_at(shut, Vector3(0.0, 1.6, 0.0)) and not _solid_at(shut, Vector3(0.0, 2.05, 0.0)), "%s: the solids follow the arch, none above it" % look)

	var open: Node3D = _build(look + "_open")
	var open_box: AABB = _mesh_box(open)
	var thick: float = PieceLook._door_thick(tier)
	var snagged: Array = []

	for iy in range(1, 40):
		var y: float = 0.05 * float(iy)
		var w: float = _clear_half(opening, y) - thick - 0.03
		var ix: int = 0

		while -w + 0.05 * float(ix) <= w:
			for z in [-0.1, 0.0, 0.1]:
				if _solid_at(open, Vector3(-w + 0.05 * float(ix), y, z)):
					snagged.append(Vector3(-w + 0.05 * float(ix), y, z))

			ix += 1

	check(snagged.is_empty(), "%s_open: the opening is clear (%s)" % [look, str(snagged.slice(0, 3))])
	check(open_box.position.x >= -half - 0.2 and open_box.end.x <= half + 0.2 and open_box.end.z <= 1.15 and open_box.position.z >= -0.2 and open_box.end.z >= 0.8,
		"%s_open: each leaf swung out against its jamb (%s)" % [look, open_box])
	var swung: int = open.find_children("*", "StaticBody3D", true, false).size()
	check(swung == leaves, "%s_open: a small solid for each of %d leaves (found %d)" % [look, leaves, swung])
	var shut_metal: float = _metal(shut)

	match tier:
		"rustic":
			check(shut_metal == 0.0, "%s: rough Planks and wooden hinges, no metal" % look)
		"fortified":
			check(_wood_meshes(shut) == 0 and _wood_meshes(open) == 0, "%s: all metal, no wood" % look)
		"refined", "sturdy", "superior", "engineered":
			check(shut_metal > 0.0, "%s: metal hinges and nails" % look)

	shut.free()
	open.free()


func _run() -> void:
	await process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var rows: Dictionary = parsed.get("structures", parsed)
	var frames: int = 0
	var doors: int = 0

	for tier in TIERS:
		for k in 4:
			var opening: String = OPENINGS[k]
			var frame: String = FRAMES[tier][k]
			var door: String = "%s_%s" % [tier, DOORS[opening]]
			_frame_checks(opening, frame)
			_door_checks(tier, opening)
			frames += 1
			doors += 1
			# the data and the looks agree: each frame and door row draws its own look and names its opening
			check(rows.has(frame) and str(rows[frame].get("look", "")) == frame and str(rows[frame].get("opening", "")) == opening, "%s: structures.json draws look %s for a %s frame" % [frame, frame, opening])
			check(rows.has(door) and str(rows[door].get("look", "")) == door and str(rows[door].get("opening", "")) == opening and str(rows[door].get("piece_kind", "")) == "door",
				"%s: structures.json draws look %s for a %s door" % [door, door, opening])
			check(rows.has(door + "_open") and str(rows[door + "_open"].get("look", "")) == door + "_open", "%s_open: structures.json draws its open look" % door)

	# Thickness (master catalog 3.0, 3.2): Plank 4 in = 0.10 m, Hardwood board 2 in = 0.05 m; Superior is two layers of Hardwood board, about 4 in; Sturdy is thicker than Refined.
	var refined: Array = _boards(_build("refined_door"))
	var rustic: Array = _boards(_build("rustic_door"))
	var sturdy: Array = _boards(_build("sturdy_door"))
	var superior: Array = _boards(_build("superior_door"))
	var engineered: Array = _boards(_build("engineered_door"))
	check(absf(float(refined[0]) - 0.05) < 0.005 and int(refined[1]) == 1, "refined_door: one layer of 2 in Hardwood boards (%s)" % str(refined))
	check(absf(float(rustic[0]) - 0.1) < 0.005 and absf(float(sturdy[0]) - 0.1) < 0.005, "rustic and sturdy doors: 4 in Planks (%s, %s)" % [str(rustic), str(sturdy)])
	check(float(refined[0]) < float(rustic[0]) and float(refined[0]) < float(sturdy[0]), "the Refined leaf is thinner than the Rustic and Sturdy leaves")
	check(float(superior[0]) > 0.09 and float(superior[0]) < 0.11 and int(superior[1]) == 2, "superior_door: two layers of Hardwood board, about 4 in thick (%s)" % str(superior))
	check(float(engineered[0]) > 0.09, "engineered_door: thick fitted wood (%s)" % str(engineered))
	check(_metal(_build("engineered_door")) > 2.0 * _metal(_build("superior_door")), "the Engineered door carries clearly more metal than the Superior door")
	check(_metal(_build("superior_door")) > _metal(_build("refined_door")), "the Superior door has finer metalwork than the Refined door")
	print("door looks: %d frames, %d doors (shut and open), %d failures" % [frames, doors, failures])
	print("test_door_looks: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
