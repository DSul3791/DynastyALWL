extends SceneTree

# The building and station looks build inside their footprints (one test for what were eight, testing slim-down round 2, 22 Nov 2026: the
# buildables plan batches B1a to B6 and the item system C2 to C4 each had its own file with the same helpers). Each section below keeps its
# own checks, tables and history; a failing line names its section.
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks.gd

const LookTable := preload("res://src/client/look_table.gd")
const PieceLook := preload("res://src/client/piece_look.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const BasicLook := preload("res://src/client/basic_look.gd")

var failures: int = 0
var section: String = ""


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + section + ": " + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	section = "buildable_looks_b1a"
	await _b1a_run()
	section = "buildable_looks_b1bc"
	await _b1bc_run()
	section = "buildable_looks_b2"
	await _b2_run()
	section = "buildable_looks_b3"
	await _b3_run()
	section = "buildable_looks_b4"
	await _b4_run()
	section = "buildable_looks_b5_b6"
	await _b56_run()
	section = "station_looks_c2"
	await _c2_run()
	section = "structure_looks_c3c4"
	await _c34_run()
	print("test_buildable_looks: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# Helpers the sections share.
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

func _mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false

	return box

func _triangles(node: Node) -> int:
	var total: int = 0

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += floori(float((node as MeshInstance3D).mesh.get_faces().size()) / 3.0)

	for child in node.get_children():
		total += _triangles(child)

	return total


# ---- buildable_looks_b1a (was test_buildable_looks_b1a.gd)
# Buildables plan B0 and B1a (10 Nov 2026): the new foundation, doorway and window looks and the forged hammer heads build, sit on the grid of the
# pieces they match, and leave their openings walkable. Bounds only (no pictures): every look's meshes in its box, the solids where they should be.

const B1A_FOUNDATIONS := ["log_foundation", "brick_foundation"]
const B1A_DOORWAYS := ["log_doorway", "stone_doorway", "brick_doorway"]
const B1A_WINDOWS := ["thatch_window", "log_window", "stone_window", "brick_window"]


# The box round every mesh under `node`, in the look's own space.
func _b1a_mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false

	return box


# Whether any solid box under `node` holds `point` (look space).
func _b1a_near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


func _b1a_run() -> void:
	await process_frame

	for look in B1A_FOUNDATIONS:
		var node: Node3D = _build(look)
		var box: AABB = _b1a_mesh_box(node)
		check(_b1a_near(box.size.x, 4.0, 0.1) and _b1a_near(box.size.z, 4.0, 0.1) and _b1a_near(box.end.y, 0.3, 0.03) and _b1a_near(box.position.y, -1.7, 0.05),
			"%s: 4 m square, top 0.3 m up, 2 m deep like the stone foundation (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.25, 0.0)) and _solid_at(node, Vector3(1.9, -1.6, 1.9)) and not _solid_at(node, Vector3(0.0, 0.35, 0.0)), "%s: solid from the top down, nothing above it" % look)

	# The doorways (BUGLIST-002): an empty frame, the wall solid either side of and over the gap, nothing in the 0.9 m by 1.9 m clear opening and no open twin look.
	for look in B1A_DOORWAYS:
		var node: Node3D = _build(look)
		var box: AABB = _b1a_mesh_box(node)
		check(box.position.x >= -1.04 and box.end.x <= 1.04 and box.position.y >= -0.01 and box.end.y <= 2.56 and box.end.y >= 2.3, "%s: in the 2 m by 2.4 m wall piece (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.75, 1.0, 0.0)) and _solid_at(node, Vector3(-0.75, 1.0, 0.0)) and _solid_at(node, Vector3(0.0, 2.25, 0.0)), "%s: the wall either side of and over the gap is solid" % look)
		check(box.position.z >= -0.2 and box.end.z <= 0.2, "%s: as thick as a wall (%.2f to %.2f)" % [look, box.position.z, box.end.z])
		var blocked: Array = []

		for x in [-0.45, -0.2, 0.0, 0.2, 0.45]:
			for y in [0.1, 1.0, 1.9]:
				for z in [-0.1, 0.0, 0.1]:
					if _solid_at(node, Vector3(x, y, z)):
						blocked.append(Vector3(x, y, z))

		check(blocked.is_empty(), "%s: nothing solid in the opening (%s)" % [look, str(blocked)])
		check(not LookTable.has_look(look + "_open"), "%s: no open twin look (the door is a separate piece)" % look)

	# The Crude doorway (BUG-010): a framed passage with no door at all. The wall is solid either side of and over the gap and nothing stands in it, at any
	# height a person passes, over the whole clear width; no mesh stands in the gap either.
	var crude: Node3D = _build("thatch_doorway")
	var crude_box: AABB = _b1a_mesh_box(crude)
	check(crude_box.position.x >= -1.04 and crude_box.end.x <= 1.04 and crude_box.position.y >= -0.01 and crude_box.end.y <= 2.56 and crude_box.end.y >= 2.3 and crude_box.position.z >= -0.2 and crude_box.end.z <= 0.2,
		"thatch_doorway: in the 2 m by 2.4 m wall piece, as thick as a wall (%s)" % crude_box)
	check(_solid_at(crude, Vector3(0.75, 1.0, 0.0)) and _solid_at(crude, Vector3(-0.75, 1.0, 0.0)) and _solid_at(crude, Vector3(0.0, 2.25, 0.0)), "thatch_doorway: the wall either side of and over the gap is solid")
	var blocked_at: Array = []

	for x in [-0.45, -0.3, 0.0, 0.3, 0.45]:
		for y in [0.1, 0.5, 1.0, 1.5, 1.9]:
			for z in [-0.1, 0.0, 0.1]:
				if _solid_at(crude, Vector3(x, y, z)):
					blocked_at.append(Vector3(x, y, z))

	check(blocked_at.is_empty(), "thatch_doorway: nothing solid in the 0.9 m by 1.9 m opening (%s)" % str(blocked_at))
	var leaf_in_gap: bool = false

	for child in crude.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (crude.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		leaf_in_gap = leaf_in_gap or (b.position.x > -0.44 and b.end.x < 0.44 and b.position.y < 1.9 and b.end.y > 0.1)   # a mesh wholly inside the opening: a door leaf

	check(not leaf_in_gap, "thatch_doorway: no door leaf hangs in the opening")
	check(not LookTable.has_look("thatch_doorway_open"), "thatch_doorway: the open twin look is retired")

	for look in B1A_WINDOWS:
		var node: Node3D = _build(look)
		var box: AABB = _b1a_mesh_box(node)
		check(box.position.x >= -1.04 and box.end.x <= 1.04 and box.position.y >= -0.01 and box.end.y <= 2.56 and box.end.y >= 2.3 and box.position.z >= -0.2 and box.end.z <= 0.2, "%s: in the 2 m by 2.4 m wall piece (%s)" % [look, box])
		check(not _solid_at(node, Vector3(0.0, 1.3, 0.0)) and _solid_at(node, Vector3(0.0, 0.5, 0.0)) and _solid_at(node, Vector3(0.0, 2.1, 0.0)) and _solid_at(node, Vector3(0.75, 1.3, 0.0)), "%s: open at 1.3 m, solid under, over and beside the gap" % look)

	for item in ["bronze_hammer", "iron_hammer", "steel_hammer"]:
		var mesh: Mesh = BasicLook.mesh_for(item)
		check(mesh != null and mesh.get_surface_count() >= 2, "%s: a hammer with a metal surface" % item)

		if mesh != null:
			var box: AABB = mesh.get_aabb()
			var stone: AABB = BasicLook.mesh_for("stone_hammer").get_aabb()
			# The same haft as the stone hammer (its grip end and a hammer's length); the forged head across it is longer than the stone lump, so only its
			# own span is checked (a cross-peen head about 15 cm, not a block).
			check(_b1a_near(box.position.x, stone.position.x, 0.02) and box.size.x > 0.4 and box.size.x < 0.5 and box.size.z > 0.12 and box.size.z < 0.2,
				"%s: the stone hammer's haft, a forged head across it (%s)" % [item, box])


# ---- buildable_looks_b1bc (was test_buildable_looks_b1bc.gd)
# Buildables plan B1b and B1c (10 Nov 2026): stairs, railings, the double doorway, pillars and roof corners build, sit in the boxes of
# the pieces they match, and are solid where a player stands or is stopped. Bounds only (no pictures).

func _b1bc_inside(box: AABB, low: Vector3, high: Vector3) -> bool:
	return box.position.x >= low.x and box.position.y >= low.y and box.position.z >= low.z and box.end.x <= high.x and box.end.y <= high.y and box.end.z <= high.z


func _b1bc_run() -> void:
	await process_frame

	for look in ["log_stairs", "stone_stairs", "brick_stairs"]:
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_b1bc_inside(box, Vector3(-0.55, -0.15, -1.3), Vector3(0.55, 2.45, 1.3)) and box.end.y > 2.35, "%s: 1 m wide, 2.4 m long and 2.4 m up like the wooden stairs (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.2, 1.08)) and _solid_at(node, Vector3(0.0, 2.35, -1.08)) and not _solid_at(node, Vector3(0.0, 0.5, 1.08)), "%s: a step at the foot, one at the top, open over the first step" % look)

	for look in ["wooden_railing", "iron_railing"]:
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_b1bc_inside(box, Vector3(-1.01, -0.01, -0.08), Vector3(1.01, 1.07, 0.08)), "%s: 2 m long, 1 m high, thin (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.9, 0.0)) and not _solid_at(node, Vector3(0.0, 0.5, 0.2)), "%s: stops a fall, nothing beside it" % look)

	for look in ["double_doorway"]:   # Iron and Steel doorways retired 13 Nov 2026
		var half: float = 2.0
		var gap: float = 1.0
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_b1bc_inside(box, Vector3(-half - 0.03, -0.01, -0.2), Vector3(half + 0.03, 2.45, 0.2)) and box.end.y >= 2.3, "%s: in its %d m wall piece (%s)" % [look, int(half * 2.0), box])
		check(_solid_at(node, Vector3(gap + 0.2, 1.0, 0.0)) and _solid_at(node, Vector3(-gap - 0.2, 1.0, 0.0)) and _solid_at(node, Vector3(0.0, 2.25, 0.0)), "%s: solid beside and over the gap" % look)
		check(not _solid_at(node, Vector3(0.0, 1.0, 0.0)) and not _solid_at(node, Vector3(gap - 0.1, 0.3, 0.0)), "%s: an empty frame, the gap is walkable (BUGLIST-002)" % look)
		check(not LookTable.has_look(look + "_open"), "%s: no open twin look" % look)

	for kind in ["thatch", "wooden", "log", "stone", "brick"]:
		var look: String = kind + "_pillar"
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		var half: float = 0.26 if kind in ["stone", "brick"] else 0.21
		check(_b1bc_inside(box, Vector3(-half, -0.01, -half), Vector3(half, 2.62, half)) and box.end.y > 2.55, "%s: in its footprint, 2.6 m high (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.1, 0.0)) and _solid_at(node, Vector3(0.0, 2.5, 0.0)), "%s: solid top to bottom" % look)

	# The roof corners are hips over the 2 m corner square since GOALS-REPAIR A-37, no posts: checked with their 65 shapes in test_roof_panels.


# ---- buildable_looks_b2 (was test_buildable_looks_b2.gd)
# Buildables plan B2 (10 Nov 2026): every fence section and gate builds in its 2 m section box, has its posts at the two ends (x = -1 and +1, where the next
# section shares them: placement_rules.gd fence_ends), is solid between them, and a gate opens to leave the gap walkable. Bounds only (no pictures).

const B2_KINDS := {"thatch": "thatch", "wood": "wood", "log": "log", "log_palisade": "palisade", "stone": "stone", "brick": "brick", "iron": "iron"}


func _b2_run() -> void:
	await process_frame

	for name_part in B2_KINDS:
		var kind: String = B2_KINDS[name_part]
		var fence_look: String = name_part if name_part == "log_palisade" else name_part + "_fence"
		var gate_look: String = name_part + "_gate"

		for look in [fence_look, gate_look, gate_look + "_open"]:
			var is_gate: bool = look != fence_look
			var spec: Array = PieceLook.FENCE_SPEC.get(kind + "_gate", PieceLook.FENCE_SPEC[kind]) if is_gate else PieceLook.FENCE_SPEC[kind]
			var height: float = spec[0]
			var radius: float = spec[1]
			var half_depth: float = maxf(float(spec[2]) * 0.5, radius + 0.03) + 0.02
			var open: bool = look.ends_with("_open")
			var node: Node3D = _build(look)
			var box: AABB = _mesh_box(node)
			var reach_x: float = 1.0 + radius + 0.05
			check(box.position.x >= -reach_x and box.end.x <= reach_x and box.position.y >= -0.01 and box.end.y <= height + 0.06 and box.end.y >= height - 0.1
				and box.position.z >= -half_depth and box.end.z <= (2.0 if open else half_depth), "%s: in its 2 m section, %.1f m high (%s)" % [look, height, box])
			check(_solid_at(node, Vector3(-1.0, 0.3, 0.0)) and _solid_at(node, Vector3(1.0, 0.3, 0.0)), "%s: a post at each end, where the next section shares it" % look)

			if open:
				var w: float = 2.0 - 2.0 * radius - 0.04
				check(not _solid_at(node, Vector3(0.0, 0.5, 0.0)) and _solid_at(node, Vector3(-w * 0.5, 0.5, w * 0.5)), "%s: the gap is walkable, the leaf stands swung out" % look)
			else:
				check(_solid_at(node, Vector3(0.0, 0.5, 0.0)) and _solid_at(node, Vector3(0.5, minf(0.9, height - 0.1), 0.0)), "%s: solid between the posts" % look)


# ---- buildable_looks_b3 (was test_buildable_looks_b3.gd)
# Buildables plan B3 (10 Nov 2026): the furniture tiers, the stone work bench and the storage pieces build inside their footprints (the plan's w x d x h,
# centred, standing on y = 0) and are solid. Bounds only (no pictures).

const B3_SIZES := {
	"log_bench": Vector3(1.2, 0.45, 0.45), "log_double_bench": Vector3(2.2, 0.45, 0.45), "log_backed_bench": Vector3(1.5, 0.9, 0.6), "stone_bench": Vector3(2.0, 0.45, 0.4), "iron_bench": Vector3(2.0, 0.45, 0.4),
	"log_table": Vector3(1.4, 0.8, 0.7), "stone_table": Vector3(1.4, 0.85, 0.8), "iron_table": Vector3(1.4, 0.8, 0.7),
	"iron_chair": Vector3(0.6, 0.9, 0.6), "stone_workbench": Vector3(2.0, 1.1, 1.0),
	"wooden_shelf": Vector3(1.2, 1.2, 0.3), "wooden_cupboard": Vector3(1.0, 1.8, 0.5), "wooden_barrel": Vector3(0.7, 0.9, 0.7),
}


func _b3_run() -> void:
	await process_frame

	for look in B3_SIZES:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var size: Vector3 = B3_SIZES[look]
		var box: AABB = _mesh_box(node)
		var slack: float = 0.04
		check(box.position.x >= -size.x * 0.5 - slack and box.end.x <= size.x * 0.5 + slack and box.position.z >= -size.z * 0.5 - slack and box.end.z <= size.z * 0.5 + slack
			and box.position.y >= -0.01 and box.end.y <= size.y + slack and box.end.y >= size.y - 0.15, "%s: in its %s footprint (%s)" % [look, size, box])
		check(not node.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s: solid" % look)


# ---- buildable_looks_b4 (was test_buildable_looks_b4.gd)
# Buildables plan B4 (10 Nov 2026): every placed light builds inside its footprint (the plan's w x d x h, standing on y = 0; the wall lantern reaching out from
# its wall at z = 0), its lit flames sit where it holds its fire (each flame spot inside the look's box, near the top of a post), and the carried lanterns,
# horn pane and lamp oil have art. Bounds only (no pictures).

const B4_SIZES := {
	"wooden_hanging_lantern": Vector3(0.3, 0.4, 0.3), "iron_hanging_lantern": Vector3(0.3, 0.4, 0.3), "iron_wall_lantern": Vector3(0.3, 0.5, 0.6),
	"wooden_torch_post": Vector3(0.3, 2.2, 0.3), "stone_torch_pillar": Vector3(0.5, 2.0, 0.5), "iron_torch_stand": Vector3(0.3, 1.8, 0.3),
	"wooden_lamp_post": Vector3(0.3, 3.0, 1.0), "iron_lamp_post": Vector3(0.3, 3.4, 1.0), "stone_lamp_post": Vector3(0.5, 3.0, 1.2),
	"stone_brazier": Vector3(0.8, 0.7, 0.8), "iron_brazier": Vector3(0.7, 0.8, 0.7),
}


func _b4_run() -> void:
	await process_frame

	for look in B4_SIZES:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var size: Vector3 = B4_SIZES[look]
		var box: AABB = _mesh_box(node)
		var slack: float = 0.04
		check(box.position.x >= -size.x * 0.5 - slack and box.end.x <= size.x * 0.5 + slack and box.position.z >= -size.z * 0.5 - slack and box.end.z <= size.z * 0.5 + slack
			and box.position.y >= -0.01 and box.end.y <= size.y + slack, "%s: in its %s footprint (%s)" % [look, size, box])
		check(PieceLook.LIGHT_SPOTS.has(look), "%s: has flame spots for lit_fixture" % look)

		if PieceLook.LIGHT_SPOTS.has(look):
			var spots: Array = PieceLook.LIGHT_SPOTS[look]["spots"]
			var inside: bool = true

			for spot in spots:
				var at: Vector3 = spot[0]
				inside = inside and absf(at.x) <= size.x * 0.5 and absf(at.z) <= size.z * 0.5 + 0.01 and at.y > box.end.y - 0.6 - (0.3 if size.y < 0.6 else 0.0) and at.y < box.end.y + 0.4

			check(inside, "%s: its flames are where it holds its fire" % look)
			var fixture: Node3D = BuildingLook.lit_fixture(look)
			check(fixture.get_node_or_null("Light") != null and fixture.get_child_count() > spots.size(), "%s: lit, it draws its flames and a light" % look)
			fixture.free()

	for item in ["wooden_lantern", "iron_lantern", "horn_pane", "lamp_oil"]:
		var mesh: Mesh = BasicLook.mesh_for(item)
		check(mesh != null and mesh.get_aabb().size.length() > 0.05, "%s: has art" % item)


# ---- buildable_looks_b5_b6 (was test_buildable_looks_b5_b6.gd)
# Buildables plan B5 and B6 (10 Nov 2026): the garden and water pieces build inside their footprints (the plan's w x d x h, centred, standing on y = 0; a
# scarecrow's arms and a pump's handle reach a little past the footprint, which is their solid) and every conduit reaches its ports: a straight piece
# x = -1 and +1, a corner -X and +Z, a tee -X, +X and +Z (the rows' "water" ports). Bounds only (no pictures). Pipes are laid from the hand at any length
# since 19 Nov 2026 (PLUMBING_DESIGN s9) and the iron pipe, elbow and tap were retired: test_pipe_runs.gd checks the pipe, tap and drip head looks.

const B56_SIZES := {
	"small_garden_plot": Vector3(1.0, 0.4, 1.0), "wooden_garden_plot": Vector3(2.0, 0.4, 2.0), "large_garden_plot": Vector3(3.0, 0.4, 3.0),
	"wooden_planter_box": Vector3(0.8, 0.3, 0.3), "stone_planter": Vector3(0.8, 0.6, 0.8), "wooden_trellis": Vector3(1.6, 2.0, 0.1), "wooden_compost_bin": Vector3(1.0, 0.8, 1.0),
	"thatch_scarecrow": Vector3(1.1, 2.0, 0.6), "wooden_cold_frame": Vector3(1.0, 0.5, 1.0),
	"stone_well": Vector3(1.6, 1.1, 1.6), "wooden_hand_pump": Vector3(0.5, 1.1, 0.5), "iron_hand_pump": Vector3(0.5, 1.1, 0.5),
	"log_trough": Vector3(1.6, 0.5, 0.5), "wooden_trough": Vector3(2.0, 0.5, 0.6), "stone_trough": Vector3(2.0, 0.6, 0.7), "wooden_sluice": Vector3(2.0, 0.6, 0.4),
	"iron_deep_well_pump": Vector3(0.8, 1.6, 0.8), "stone_cistern": Vector3(2.0, 1.0, 2.0), "raised_cistern": Vector3(2.0, 3.0, 2.0),
}

const B56_CONDUITS := {
	"wooden_channel": ["straight", 0.4, 0.3], "wooden_channel_corner": ["corner", 0.4, 0.3], "wooden_channel_tee": ["tee", 0.4, 0.3],
	"stone_channel": ["straight", 0.5, 0.3], "stone_channel_corner": ["corner", 0.5, 0.3], "stone_channel_tee": ["tee", 0.5, 0.3],
}


func _b56_run() -> void:
	await process_frame

	for look in B56_SIZES:
		var node: Node3D = _build(look)
		var size: Vector3 = B56_SIZES[look]
		var box: AABB = _mesh_box(node)
		check(box.position.x >= -size.x * 0.5 - 0.04 and box.end.x <= size.x * 0.5 + 0.04 and box.position.z >= -size.z * 0.5 - 0.04 and box.end.z <= size.z * 0.5 + 0.04
			and box.position.y >= -0.01 and box.end.y <= size.y + 0.06 and box.end.y >= size.y - 0.2, "%s: in its %s footprint (%s)" % [look, size, box])

	for look in B56_CONDUITS:
		var row: Array = B56_CONDUITS[look]
		var shape: String = row[0]
		var half_w: float = float(row[1]) * 0.5
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		var to_plus_x: bool = shape != "corner"
		var to_plus_z: bool = shape != "straight"
		check(box.position.x <= -0.97 and box.position.x >= -1.04 and (box.end.x >= 0.97 if to_plus_x else box.end.x <= half_w + 0.06) and box.end.x <= 1.04
			and box.position.z >= -half_w - 0.04 and (box.end.z >= 0.97 if to_plus_z else box.end.z <= half_w + 0.04) and box.end.z <= 1.04
			and box.position.y >= -0.01 and box.end.y <= float(row[2]) + 0.04, "%s: a %s piece reaching its ports (%s)" % [look, shape, box])
		var high: float = float(row[2]) * 0.5
		check(_solid_at(node, Vector3(-0.9, high, 0.0)) and _solid_at(node, Vector3(0.9, high, 0.0)) == to_plus_x and _solid_at(node, Vector3(0.0, high, 0.9)) == to_plus_z,
			"%s: solid along its runs and nowhere else" % look)


# ---- station_looks_c2 (was test_station_looks_c2.gd)
# Item system C2 stations (item_system.md draft 7, Jamie's #934, 10 Nov 2026): the Kiln, Tanning rack, Drying rack, Smoker, Oil press and (15 Nov 2026) Wood carving station looks build inside
# their structures.json footprints (w x d, centred, standing on y = 0, under the height given here), are solid over the footprint, and stay under the
# look table's triangle cap. Bounds only (no pictures).
# "kiln" is the brick kiln the Improved and Advanced kilns draw; the Primitive kiln has its own model (test_forge_models.gd).

# look: footprint_x, height, footprint_z
const C2_SIZES := {
	"kiln": Vector3(1.6, 1.7, 1.6), "tanning_rack": Vector3(2.0, 1.8, 0.6), "drying_rack": Vector3(1.6, 1.4, 0.6), "smoker": Vector3(1.2, 1.7, 1.2),
	"oil_press": Vector3(1.2, 1.1, 1.2), "carving_station": Vector3(1.9, 0.65, 1.1),   # the Wood carving station of the 15 Nov 2026 wood redesign (W-6): a bench beside a chopping block, shavings round them
}


func _c2_run() -> void:
	await process_frame

	for look in C2_SIZES:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var size: Vector3 = C2_SIZES[look]
		var box: AABB = _mesh_box(node)
		check(box.position.x >= -size.x * 0.5 - 0.04 and box.end.x <= size.x * 0.5 + 0.04 and box.position.z >= -size.z * 0.5 - 0.04 and box.end.z <= size.z * 0.5 + 0.04
			and box.position.y >= -0.01 and box.end.y <= size.y and box.end.y >= 0.6, "%s: in its %s footprint (%s)" % [look, size, box])
		check(_solid_at(node, Vector3(0.0, 0.3, 0.0)), "%s: solid where it stands" % look)
		var tris: int = _triangles(node)
		check(tris <= 300, "%s: under the 300 triangle cap (%d)" % [look, tris])


# ---- structure_looks_c3c4 (was test_structure_looks_c3c4.gd)
# Item system C3 and C4 (item_system.md draft 7, Jamie's #936 and #938, 10 Nov 2026): the Storage jar, Hide - Sack, Basket, Weapon rack,
# Armour stand, Sign, Tusk mount, Clay bloomery and Stonecutter's bench looks build inside their structures.json footprints (w x d, centred, standing
# on y = 0, under the height given here), are solid where they stand (not the Tusk mount: it hangs on a wall like the Antler mount, so it is given
# 0.3 m of depth out from the wall), and stay under the look table's triangle cap. Bounds only (no pictures). The set Fish trap and Bird trap (#941,
# fish_trap_set and bird_trap_set) are checked here too; they are not solid. The Iron - Anvil (#950)
# is checked too, and is solid, and so are the Preserving jar and Root cellar (#955) and the B3b Log - Shelf, Iron - Chest and Wooden - Crate.
# The seven-tier ladder's free-standing concrete pieces (10 Nov 2026) are checked too: the Engineered and Fortified pillars, the Fortified gate and wall
# top, and the Mixer.
# The C7 future placeholders (chicken coop, fodder trough, tub, sap tap, cheese press, spinning wheel, loom) have looks before their rows; their
# sizes here are first guesses. The Carpenter's bench (the level-2 workbench rename) is 2.0 x 1.0 like the bench it replaces. The sap tap hangs on a tree (its back at Z = 0, given 0.3 m out from the bark) and is not solid.

# look: footprint_x, height, footprint_z
const C34_SIZES := {
	"storage_jar": Vector3(0.5, 0.8, 0.5), "hide_sack": Vector3(0.5, 0.65, 0.4), "wicker_basket": Vector3(0.6, 0.55, 0.6),
	"weapon_rack": Vector3(1.2, 1.6, 0.3), "armour_stand": Vector3(0.6, 1.8, 0.6), "sign": Vector3(0.6, 1.35, 0.1),
	"tusk_mount": Vector3(0.44, 2.15, 0.3), "clay_bloomery": Vector3(1.2, 1.45, 1.2), "stonecutters_bench": Vector3(2.0, 1.15, 1.0),
	"fish_trap_set": Vector3(0.8, 0.45, 0.5), "bird_trap_set": Vector3(0.6, 0.4, 0.6),
	"iron_anvil": Vector3(0.6, 0.85, 0.4), "preserving_jar": Vector3(0.5, 0.6, 0.5), "root_cellar": Vector3(2.0, 0.7, 2.0),
	"log_shelf": Vector3(1.2, 1.25, 0.3), "iron_chest": Vector3(1.0, 0.65, 0.6), "wooden_crate": Vector3(0.8, 0.85, 0.8),
	"engineered_pillar": Vector3(0.5, 2.6, 0.5), "fortified_pillar": Vector3(0.6, 2.6, 0.6), "fortified_gate": Vector3(2.0, 2.75, 0.3),
	"fortified_wall_top": Vector3(2.0, 0.85, 0.4), "mixer": Vector3(1.2, 1.1, 0.8),
	"chicken_coop": Vector3(1.6, 1.5, 1.2), "fodder_trough": Vector3(1.6, 0.6, 0.5), "tub": Vector3(1.4, 0.6, 0.8), "sap_tap": Vector3(0.3, 1.2, 0.6),
	"cheese_press": Vector3(0.8, 1.4, 0.6), "spinning_wheel": Vector3(1.0, 1.1, 0.5), "loom": Vector3(1.6, 1.85, 0.8),
	"carpenters_bench": Vector3(2.0, 1.1, 1.0),
}
const C34_NOT_SOLID := ["tusk_mount", "fish_trap_set", "bird_trap_set", "sap_tap"]   # hung on a wall, or a trap you can walk over (no blocks_walk)
const C34_LOW := {"fish_trap_set": 0.3, "bird_trap_set": 0.3}   # pieces lower than the usual 0.4 m: the traps lie on the ground


func _c34_mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):   # the mesh's own corners, not its turned AABB, which grows on a tipped part
		var mi: MeshInstance3D = child

		if mi.mesh == null:
			continue

		var to_node: Transform3D = node.global_transform.affine_inverse() * mi.global_transform

		for v in mi.mesh.get_faces():
			var p: Vector3 = to_node * v

			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)

	return box


func _c34_run() -> void:
	await process_frame

	for look in C34_SIZES:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var size: Vector3 = C34_SIZES[look]
		var box: AABB = _c34_mesh_box(node)
		check(box.position.x >= -size.x * 0.5 - 0.04 and box.end.x <= size.x * 0.5 + 0.04 and box.position.z >= -size.z * 0.5 - 0.04 and box.end.z <= size.z * 0.5 + 0.04
			and box.position.y >= -0.01 and box.end.y <= size.y and box.end.y >= float(C34_LOW.get(look, 0.4)), "%s: in its %s footprint (%s)" % [look, size, box])

		if look not in C34_NOT_SOLID:
			check(_solid_at(node, Vector3(0.0, 0.2, 0.0)), "%s: solid where it stands" % look)

		var tris: int = _triangles(node)
		check(tris <= 300, "%s: under the 300 triangle cap (%d)" % [look, tris])
