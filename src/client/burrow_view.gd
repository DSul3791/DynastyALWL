extends Node3D
# Rabbit burrow mounds (looks: Kathleen 3 Nov, data: MikeW #236). The server sends the ground positions of up to 40 burrows near the
# player, nearest first, whenever the set changes; every call redraws the whole set. Each burrow is a low heap of dug earth about
# 0.6 m across, lumpy and a little uneven, with a dark entrance hole sunk into one side and a fan of loose spoil in front of it, the way
# real rabbit warrens look (Art_Direction: believable, lived-in, rich warm earth rather than grey-brown). One mesh, one material, one
# MultiMesh, so 40 burrows are one draw call; the heading and size of each come from its position, so a burrow keeps its look.

const RADIUS := 0.32          # the heap's half width (about 0.6 m across)
const HEIGHT := 0.13          # the heap's height at its crown
const RINGS := 7
const SEGMENTS := 18
const HOLE_ANGLE := 0.0       # the entrance faces the mesh's +x (each burrow is turned by its own yaw)
const HOLE_R := 0.16          # how far out from the centre the entrance sits
const HOLE_SIZE := 0.085
const SINK := 0.02            # sunk a little into the ground so the edge never floats on a slope

var _multi: MultiMeshInstance3D = null
var ground_at: Callable = Callable()   # the ground height under a point (terrain_client._ground_below); with it the entrance faces downhill (MikeW's idea, 3 Nov)


func on_burrows(points: PackedVector3Array) -> void:
	if _multi == null:
		_multi = MultiMeshInstance3D.new()
		_multi.name = "BurrowMounds"
		_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = build_mesh()
		_multi.multimesh = multi
		add_child(_multi)

	var mm: MultiMesh = _multi.multimesh
	mm.instance_count = points.size()

	for i in points.size():
		var at: Vector3 = points[i]
		var seed_v: float = fposmod(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453, 1.0)
		var size: float = 0.85 + 0.3 * seed_v
		var basis: Basis = Basis(Vector3.UP, _yaw(at, seed_v)).scaled(Vector3(size, size * (0.9 + 0.2 * fposmod(seed_v * 7.0, 1.0)), size))
		mm.set_instance_transform(i, Transform3D(basis, at - Vector3(0.0, SINK, 0.0)))


# The heading: the entrance (mesh +x) faces down the steepest drop, from the ground 1 m to each side; on flat ground or without ground
# heights it falls back to a heading from the position. Rotating +x by yaw about Y gives (cos yaw, 0, -sin yaw).
func _yaw(at: Vector3, seed_v: float) -> float:
	if ground_at.is_valid():
		var east: float = float(ground_at.call(at + Vector3(1.0, 1.0, 0.0)))
		var west: float = float(ground_at.call(at + Vector3(-1.0, 1.0, 0.0)))
		var south: float = float(ground_at.call(at + Vector3(0.0, 1.0, 1.0)))
		var north: float = float(ground_at.call(at + Vector3(0.0, 1.0, -1.0)))
		if not (is_nan(east) or is_nan(west) or is_nan(south) or is_nan(north)):
			var down: Vector2 = Vector2(west - east, north - south)        # the downhill direction in x and z
			if down.length() > 0.05:                                     # more than about 1.5 degrees of slope
				return atan2(-down.y, down.x)
	return seed_v * TAU


# The heap: a polar grid lifted into a lumpy dome, pulled down and darkened into a hole on the +x side, with a spoil fan
# beyond the hole. Vertex colours carry the earth tones; normals are generated.
static func build_mesh() -> ArrayMesh:
	var earth: Color = Color(0.36, 0.25, 0.15)
	var dry: Color = Color(0.5, 0.38, 0.24)
	var hole_col: Color = Color(0.05, 0.035, 0.025)
	var hole_at: Vector2 = Vector2(cos(HOLE_ANGLE), sin(HOLE_ANGLE)) * HOLE_R
	var grid: Array = []                     # grid[ring][seg] = [Vector3, Color]

	for ring in RINGS + 1:
		var row: Array = []
		var r_share: float = float(ring) / float(RINGS)
		for seg in SEGMENTS:
			var a: float = TAU * float(seg) / float(SEGMENTS)
			var lump: float = 1.0 + 0.12 * sin(a * 3.0 + 0.7) + 0.08 * sin(a * 5.0 + 2.1)
			var spoil: float = maxf(cos(a - HOLE_ANGLE), 0.0)          # the heap runs out further on the hole side: dug earth thrown out of the entrance
			var r: float = RADIUS * r_share * lump * (1.0 + 0.35 * spoil * r_share)
			var p: Vector2 = Vector2(cos(a), sin(a)) * r
			var y: float = HEIGHT * pow(maxf(1.0 - r_share * r_share, 0.0), 1.3) * (1.0 + 0.15 * sin(a * 4.0 + float(ring)))
			var col: Color = earth.lerp(dry, 0.5 * (1.0 - r_share) * (0.6 + 0.4 * sin(a * 2.0 + float(ring) * 1.3)))
			var d: float = p.distance_to(hole_at) / HOLE_SIZE
			if d < 1.0:                                                    # the entrance: a pit sunk below the ground, fading to near black at its middle
				y = lerpf(-0.06, y, d * d)
				col = hole_col.lerp(earth.darkened(0.3), d * d)
			elif d < 1.6:                                                  # a raised, darker worn lip round the entrance
				y += 0.012 * (1.6 - d)
				col = col.darkened(0.12)
			if ring == RINGS:
				y = 0.0
			row.append([Vector3(p.x, y, p.y), col])
		grid.append(row)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown: Color = earth.lerp(dry, 0.5)

	for seg in SEGMENTS:                                                   # the crown fan
		var nxt: int = (seg + 1) % SEGMENTS
		_vert(st, [Vector3(0.0, HEIGHT, 0.0), crown])                    # clockwise seen from above: Godot's front face
		_vert(st, grid[1][seg])
		_vert(st, grid[1][nxt])

	for ring in range(1, RINGS):
		for seg in SEGMENTS:
			var nxt: int = (seg + 1) % SEGMENTS
			_vert(st, grid[ring][seg])
			_vert(st, grid[ring + 1][seg])
			_vert(st, grid[ring][nxt])
			_vert(st, grid[ring][nxt])
			_vert(st, grid[ring + 1][seg])
			_vert(st, grid[ring + 1][nxt])

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	return mesh


static func _vert(st: SurfaceTool, v: Array) -> void:
	st.set_color(v[1])
	st.add_vertex(v[0])
