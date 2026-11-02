extends Node3D

# Visible ambient life (client only, no server state, no collision; flora session 2026-10-31): butterflies and bees over flowering meadows by day,
# dragonflies at water, birds in the tree canopy, fireflies at warm dusk and night. Placeholder look: small camera-facing quads, one MultiMesh
# per kind (5 draws in all); Kathleen can swap the meshes later. Density comes from the zone weights AmbientLife already measures (forest, meadow,
# water, highland), the season, the hour and the weather: density() is a pure function (tested headless). Each critter has a fixed anchor and
# phase around the player and moves on a small loop; anchors that fall out of reach wrap round, so nothing is placed or freed per frame.
#
#   update(delta, player_pos, weights, season, hour, rain)   called every frame by the client; costs a few microseconds per critter.

const KINDS := ["butterfly", "bee", "dragonfly", "bird", "firefly"]
const MAX_COUNT := {"butterfly": 14, "bee": 10, "dragonfly": 6, "bird": 6, "firefly": 16}
const REACH_M := 26.0                   # critters live inside this radius of the player
const MIN_M := 2.5
const SIZE_M := {"butterfly": 0.14, "bee": 0.05, "dragonfly": 0.16, "bird": 0.22, "firefly": 0.05}
const SPEED := {"butterfly": 1.1, "bee": 2.2, "dragonfly": 2.6, "bird": 0.5, "firefly": 0.5}
const COLOR := {
	"butterfly": [Color(0.95, 0.82, 0.2), Color(0.95, 0.95, 0.9), Color(0.9, 0.45, 0.15), Color(0.45, 0.6, 0.95)],
	"bee": [Color(0.9, 0.7, 0.1)],
	"dragonfly": [Color(0.2, 0.6, 0.85), Color(0.15, 0.7, 0.55)],
	"bird": [Color(0.25, 0.2, 0.17), Color(0.4, 0.3, 0.2)],
	"firefly": [Color(0.8, 1.0, 0.35)],
}
const SEASON_SHARE := {
	"butterfly": {"spring": 0.6, "summer": 1.0, "autumn": 0.15, "winter": 0.0},
	"bee": {"spring": 0.7, "summer": 1.0, "autumn": 0.2, "winter": 0.0},
	"dragonfly": {"spring": 0.2, "summer": 1.0, "autumn": 0.4, "winter": 0.0},
	"bird": {"spring": 1.0, "summer": 1.0, "autumn": 0.8, "winter": 0.4},
	"firefly": {"spring": 0.0, "summer": 1.0, "autumn": 0.0, "winter": 0.0},
}

var counts: Dictionary = {}             # kind -> critters shown now
var enabled: bool = true
var quality: float = 1.0                # 0 to 1: the quality tier's share of the counts
var _meshes: Dictionary = {}            # kind -> MultiMeshInstance3D
var _anchors: Dictionary = {}           # kind -> Array of [Vector2 offset, phase, height, colour index]
var _time: float = 0.0
var _since: float = 0.0                # seconds since the transforms were last moved (they move at 30 Hz)


# How many of each kind should be out: 0 to MAX_COUNT, from the zone weights (forest, meadow, water, highland: 0..1 each), season, hour and rain (0..1).
static func density(weights: Dictionary, season: String, hour: float, rain: float) -> Dictionary:
	var day: float = clampf((hour - 7.5) / 1.5, 0.0, 1.0) * clampf((19.0 - hour) / 1.5, 0.0, 1.0)
	var night: float = 0.0

	if hour >= 19.5 or hour < 4.5:
		night = 1.0
	elif hour >= 18.5:
		night = clampf(hour - 18.5, 0.0, 1.0)

	var wet: float = clampf(1.0 - rain * 3.0, 0.0, 1.0)
	var meadow: float = float(weights.get("meadow", 0.0))
	var forest: float = float(weights.get("forest", 0.0))
	var water: float = float(weights.get("water", 0.0))
	var amounts: Dictionary = {
		"butterfly": day * wet * clampf(meadow + 0.25 * forest, 0.0, 1.0),
		"bee": day * wet * meadow,
		"dragonfly": day * wet * water,
		"bird": clampf(day * 0.8 + 0.1, 0.0, 1.0) * wet * forest,
		"firefly": night * wet * clampf(meadow * 0.8 + water * 0.8 + forest * 0.2, 0.0, 1.0),
	}
	var result: Dictionary = {}

	for kind in KINDS:
		var share: float = float((SEASON_SHARE[kind] as Dictionary).get(season, 0.0))
		result[kind] = int(round(float(MAX_COUNT[kind]) * clampf(float(amounts[kind]) * share, 0.0, 1.0)))

	return result


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242

	for kind in KINDS:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(float(SIZE_M[kind]), float(SIZE_M[kind]))
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED

		if kind == "firefly":
			material.emission_enabled = true
			material.emission = Color(0.8, 1.0, 0.35)
			material.emission_energy_multiplier = 2.0

		quad.material = material
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = quad
		multi.instance_count = int(MAX_COUNT[kind])
		multi.visible_instance_count = 0
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = kind
		node.multimesh = multi
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-100.0, -50.0, -100.0), Vector3(200.0, 100.0, 200.0))
		add_child(node)
		_meshes[kind] = node
		var list: Array = []

		for n in range(int(MAX_COUNT[kind])):
			var angle: float = rng.randf() * TAU
			var dist: float = lerpf(MIN_M, REACH_M, sqrt(rng.randf()))
			var height: float = rng.randf_range(0.4, 1.8)

			if kind == "bird":
				height = rng.randf_range(4.0, 11.0)
			elif kind == "firefly":
				height = rng.randf_range(0.5, 2.2)

			var colour_index: int = rng.randi() % (COLOR[kind] as Array).size()
			list.append([Vector2(cos(angle), sin(angle)) * dist, rng.randf() * TAU, height, colour_index])
			multi.set_instance_color(n, (COLOR[kind] as Array)[colour_index])

		_anchors[kind] = list


func update(delta: float, player_pos: Vector3, weights: Dictionary, season: String, hour: float, rain: float) -> void:
	if not enabled:
		visible = false
		return

	visible = true
	_time += delta
	_since += delta

	if _since < 1.0 / 30.0 and not counts.is_empty():
		return

	_since = 0.0
	var want: Dictionary = density(weights, season, hour, rain)

	for kind in KINDS:
		var node: MultiMeshInstance3D = _meshes.get(kind)

		if node == null:
			continue

		var multi: MultiMesh = node.multimesh
		var shown: int = int(round(float(want[kind]) * quality))
		counts[kind] = shown
		multi.visible_instance_count = shown
		var list: Array = _anchors[kind]
		var speed: float = float(SPEED[kind])

		for n in range(shown):
			var a: Array = list[n]
			var anchor: Vector2 = a[0]
			# The anchor is fixed relative to the world origin of the player's cell: wrap it round the player so it stays within reach as they walk.
			var rel: Vector2 = Vector2(anchor.x - player_pos.x, anchor.y - player_pos.z)
			rel = Vector2(fposmod(rel.x + REACH_M, 2.0 * REACH_M) - REACH_M, fposmod(rel.y + REACH_M, 2.0 * REACH_M) - REACH_M)
			var phase: float = float(a[1]) + _time * speed
			var wobble: Vector3 = Vector3(sin(phase * 1.3) * 1.2, sin(phase * 2.1) * 0.35, cos(phase * 0.9) * 1.2)

			if kind == "bird":
				wobble = Vector3(sin(phase) * 2.0, sin(phase * 3.0) * 0.2, cos(phase * 0.8) * 2.0)

			var at: Vector3 = Vector3(player_pos.x + rel.x, player_pos.y - 1.7 + float(a[2]), player_pos.z + rel.y) + wobble
			multi.set_instance_transform(n, Transform3D(Basis(), at))   # the node sits at the world origin (the client adds it to the root)
