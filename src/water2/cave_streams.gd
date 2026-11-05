extends Node3D

# Spring cave streams (Sonny, 3 Nov 2026; Dave: a brook on a hillside comes out of a cave about 100 m deep, "then put the spring way at the back
# of the cave"). The live water is a heightfield over the ground, so it cannot run inside a tunnel: this draws the stream on each spring cave's floor
# from the server's list (protocol 87, TileTerrainData.cave_streams), a ribbon from the spring down to the mouth with ripples running towards the
# mouth, and a still pool in each spring chamber with rings spreading from the spring. One mesh per tile, built once when the list arrives.

const RIBBON_LIFT_M := 0.45     # the water stands at least this deep over the passage floor on the centre line ...
const DEPTH_SHARE := 0.05       # ... and deeper in wider passages (Dave 5 Nov: the stream grows on its way out of the cave), up to DEPTH_MAX_M
const DEPTH_MAX_M := 1.5
const RIBBON_SHARE := 0.3       # at most this share of the passage width either side of the centre line
# The carved floor is the bottom of an ellipse, so it rises off the centre line: a flat ribbon 0.3 of the width out sat up to 1.2 m under the rock in the
# wide river-sized mouths (Dave 5 Nov 2026, x 54162 z 69741: "there is no water actually running in the cave"). The ribbon now spans only the trough the
# water fills, where an ellipse as tall as half the passage width (taller than any passage: mouths are 0.25, passages about 0.43) is still under the water.
const FLOOR_RISE_SHARE := 0.5
const POOL_SIDES := 20
const UNDER_REACH := 2.5        # under the surface the pool's water reaches this many rim radii out (spring_basin's lobes: 2.43), plus 1 m as the server
const CAVE_POOL_SHALLOW_M := 0.4   # an old server's pool (no depth sent)

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform vec4 water_colour : source_color = vec4(0.05, 0.13, 0.15, 0.82);
uniform vec3 foam_colour : source_color = vec3(0.62, 0.74, 0.78);
uniform float speed = 0.9;     // m/s along the stream

void fragment() {
	// COLOR.r: 0 stream (UV.x across, -1..1; UV.y metres from the spring), 1 pool (UV.x 0 centre .. 1 edge)
	float pool = COLOR.r;
	float v = UV.y - TIME * speed;
	float stream_wave = sin(v * 5.0 + 1.6 * sin(UV.x * 3.1 + v * 1.3)) * 0.5 + 0.5;
	float pool_wave = sin(UV.x * 14.0 - TIME * 1.4) * 0.5 + 0.5;
	float wave = mix(stream_wave, pool_wave, pool);
	float tilt = mix(cos(v * 5.0 + UV.x * 2.0), cos(UV.x * 14.0 - TIME * 1.4), pool);
	NORMAL_MAP = vec3(0.5 + 0.12 * tilt, 0.5 + 0.12 * (wave - 0.5), 1.0);
	ALBEDO = mix(water_colour.rgb, foam_colour, wave * mix(0.18, 0.08, pool));
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	float edge = mix(1.0 - smoothstep(0.7, 1.0, abs(UV.x)), 1.0 - smoothstep(0.85, 1.0, UV.x), pool);
	ALPHA = water_colour.a * edge;
}
"""

var _material: ShaderMaterial = null
var _tiles: Dictionary = {}   # tile -> MeshInstance3D
var _pools: Dictionary = {}   # tile -> Array of [centre (surface) Vector3, open radius, depth below the surface] (BUG-008: 20 m deep pools you swim in)


func show_tile(tile: Vector2i, streams: PackedFloat32Array) -> void:
	drop_tile(tile)
	_pools[tile] = pools_of(streams)

	if streams.size() < 7:
		return

	if _material == null:
		_material = ShaderMaterial.new()
		var shader: Shader = Shader.new()
		shader.code = SHADER
		_material.shader = shader

	var mesh: ArrayMesh = build_mesh(streams)

	if mesh == null:
		return

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "CaveStreams_%d_%d" % [tile.x, tile.y]
	instance.mesh = mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_tiles[tile] = instance


func drop_tile(tile: Vector2i) -> void:
	_pools.erase(tile)

	if _tiles.has(tile):
		_tiles[tile].queue_free()
		_tiles.erase(tile)


func clear() -> void:
	for tile in _tiles.keys():
		drop_tile(tile)


# The pools in a list: [centre on the surface, radius at the surface, depth below it] (depth 0 from a server without BUG-008: a 0.4 m pool).
static func pools_of(streams: PackedFloat32Array) -> Array:
	var out: Array = []

	@warning_ignore("integer_division")
	for n in range(streams.size() / 7):
		var o: int = n * 7

		if streams[o + 6] < 0.0:
			out.append([Vector3(streams[o], streams[o + 1], streams[o + 2]), -streams[o + 6], maxf(streams[o + 3], CAVE_POOL_SHALLOW_M)])

	return out


# The surface height of the cave pool a point is in (or just above), else NAN. Under the surface the basin swells wider than its rim (spring_basin:
# the main bowl to 1.74 times the rim, and its two side lobes reach up to 2.43 times out), so a swimmer below keeps the water there. At 1.75 a swimmer
# who went down into a lobe left the water on this side while the server (the carved shapes) still ran the breath down (Dave 5 Nov 2026: "i fell because
# apparently water in caves doesnt exist and I cant swim but it does say my oxygen is dropping"). Under the rim nothing but the basin is open, so the
# wider test only takes in its water.
func pool_surface_at(p: Vector3) -> float:
	for tile in _pools:
		for pool in _pools[tile]:
			var centre: Vector3 = pool[0]
			var flat: float = Vector2(p.x - centre.x, p.z - centre.z).length()

			if p.y > centre.y + 2.0 or p.y < centre.y - float(pool[2]) - 1.0:
				continue

			if flat <= float(pool[1]) * (1.0 if p.y >= centre.y else UNDER_REACH) + (1.0 if p.y < centre.y else 0.0):
				return centre.y

	return NAN


# Pieces of 7 floats: upper end x, y, z, lower end x, y, z, passage width; a negative width is a pool: centre x, y, z, depth below the surface, -radius.
# The stream's UV.y counts metres from the upper end of its piece plus the piece's height (pieces of one passage then roughly line up).
# The water's depth on the centre line, and half its width across a passage `width` wide: where an elliptic floor as tall as FLOOR_RISE_SHARE of the
# width stays under that depth. Wider passages near the mouth carry a wider, deeper stream.
static func ribbon_depth(width: float) -> float:
	return clampf(DEPTH_SHARE * width, RIBBON_LIFT_M, DEPTH_MAX_M)


static func ribbon_half_width(width: float) -> float:
	var rw: float = 0.5 * width
	var depth: float = ribbon_depth(width)
	var rh: float = maxf(FLOOR_RISE_SHARE * width, depth)
	var t: float = 1.0 - depth / rh
	return minf(rw * sqrt(maxf(1.0 - t * t, 0.0)), RIBBON_SHARE * width)


static func build_mesh(streams: PackedFloat32Array) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colours: PackedColorArray = PackedColorArray()
	var normals: PackedVector3Array = PackedVector3Array()

	@warning_ignore("integer_division")
	for n in range(streams.size() / 7):
		var o: int = n * 7
		var a: Vector3 = Vector3(streams[o], streams[o + 1], streams[o + 2])
		var width: float = streams[o + 6]

		if width < 0.0:
			_add_pool(verts, uvs, colours, normals, a, -width)
			continue

		var b: Vector3 = Vector3(streams[o + 3], streams[o + 4], streams[o + 5])
		var along: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)

		if along.length() < 0.01:
			continue

		var dir: Vector3 = along.normalized()
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x) * ribbon_half_width(width)
		var lift: Vector3 = Vector3(0.0, ribbon_depth(width), 0.0)
		# Each piece runs a little past both its ends so the bends have no gaps.
		var reach: Vector3 = dir * ribbon_half_width(width)
		var top: Vector3 = a - reach + lift
		var low: Vector3 = b + reach + lift
		var v0: float = -a.y * 20.0   # spring passages rise 3 to 7 percent: about 20 m along per metre of height, so a passage's pieces line up
		var v1: float = v0 + top.distance_to(low)
		var quad: Array = [[top - side, Vector2(-1.0, v0)], [top + side, Vector2(1.0, v0)], [low + side, Vector2(1.0, v1)],
			[top - side, Vector2(-1.0, v0)], [low + side, Vector2(1.0, v1)], [low - side, Vector2(-1.0, v1)]]

		for corner in quad:
			verts.append(corner[0])
			uvs.append(corner[1])
			colours.append(Color(0.0, 0.0, 0.0))
			normals.append(Vector3.UP)

	if verts.is_empty():
		return null

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_pool(verts: PackedVector3Array, uvs: PackedVector2Array, colours: PackedColorArray, normals: PackedVector3Array, centre: Vector3, radius: float) -> void:
	for k in range(POOL_SIDES):
		var t0: float = TAU * float(k) / float(POOL_SIDES)
		var t1: float = TAU * float(k + 1) / float(POOL_SIDES)

		for corner in [[centre, 0.0], [centre + Vector3(cos(t0), 0.0, sin(t0)) * radius, 1.0], [centre + Vector3(cos(t1), 0.0, sin(t1)) * radius, 1.0]]:
			verts.append(corner[0])
			uvs.append(Vector2(float(corner[1]), 0.0))
			colours.append(Color(1.0, 0.0, 0.0))
			normals.append(Vector3.UP)
