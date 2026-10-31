extends Node3D

# Tide-line gather spots drawn on the beach (Kathleen, 2026-10-31): the nodes of data/items/shore_nodes.json (kelp, mussels, crabs, a nest) that ShoreRules.node_at says are in a cell today
# get a small prop in that cell, so a player can see where E will gather: a tangle of kelp, a cluster of mussels, a crab among pebbles, a nest of dry grass with eggs.
# Same cell, day, hour and season as the server's pick, so nothing is sent over the network; a cell this client already gathered today shows nothing. Cheap: a few small meshes per node,
# only the cells within RADIUS_M, rebuilt at most every 1.5 s.

const ShoreRules := preload("res://src/shared/shore_rules.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
const RADIUS_M := 26.0
const EVERY_MS := 1500

var _props: Dictionary = {}          # "cx,cz,day,kind" -> Node3D
var _meshes: Dictionary = {}         # shape -> ArrayMesh
var _material: StandardMaterial3D = null
var _last_ms: int = -10000
var _last_at: Vector3 = Vector3(1.0e9, 0.0, 0.0)


# `ground_fn(Vector3) -> float` is the ground height under a point (NAN when unknown); the sea lies below 0.
func update(player: Vector3, cfg: Dictionary, day: int, hour: float, season: String, used: Dictionary, ground_fn: Callable) -> void:
	var now: int = Time.get_ticks_msec()

	if cfg.is_empty() or cfg.has("none") or now - _last_ms < EVERY_MS:
		return

	if player.distance_to(_last_at) < 3.0 and now - _last_ms < 8000:
		return

	_last_ms = now
	_last_at = player
	var cell_m: float = float(cfg.get("cell_m", 8.0))
	var beach_max: float = float(cfg.get("beach_max_height_m", 4.0))
	var wanted: Dictionary = {}
	var reach_cells: int = int(ceil(RADIUS_M / cell_m))
	var here_cell: Vector2i = Vector2i(int(floor(player.x / cell_m)), int(floor(player.z / cell_m)))

	for dx in range(-reach_cells, reach_cells + 1):
		for dz in range(-reach_cells, reach_cells + 1):
			var cell: Vector2i = here_cell + Vector2i(dx, dz)
			var centre: Vector3 = Vector3((float(cell.x) + 0.5) * cell_m, 0.0, (float(cell.y) + 0.5) * cell_m)

			if Vector2(centre.x - player.x, centre.z - player.z).length() > RADIUS_M:
				continue

			var node: Dictionary = ShoreRules.node_at(cfg, centre, day, hour, season)

			if node.is_empty() or int(used.get(ShoreRules.cell_key(cfg, centre), -1)) == day:
				continue

			var key: String = "%d,%d,%d,%s" % [cell.x, cell.y, day, str(node.get("kind", ""))]
			wanted[key] = true

			if _props.has(key):
				continue

			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash(key)
			var spot: Vector3 = centre + Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
			var ground: float = float(ground_fn.call(spot))

			if is_nan(ground) or ground < 0.0 or ground > beach_max:
				continue

			var sea: bool = false

			for offset in [Vector2(6.0, 0.0), Vector2(-6.0, 0.0), Vector2(0.0, 6.0), Vector2(0.0, -6.0)]:
				var g: float = float(ground_fn.call(spot + Vector3(offset.x, 0.0, offset.y)))

				if not is_nan(g) and g < 0.0:
					sea = true
					break

			if not sea:
				continue

			spot.y = ground
			_props[key] = _make_prop(str(node.get("kind", "")), spot, rng)
			add_child(_props[key])

	for key in _props.keys():
		if not wanted.has(key):
			(_props[key] as Node3D).queue_free()
			_props.erase(key)


func _make_prop(kind: String, spot: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = spot
	root.rotation.y = rng.randf() * TAU

	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0

	for part in _parts_of(kind):
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = _mesh(str(part[0]))
		instance.material_override = _material
		instance.position = part[1] + Vector3(0.0, 0.055 * float(part[2]) + 0.005, 0.0)
		instance.scale = Vector3.ONE * float(part[2])
		instance.rotation.y = float(part[3])
		root.add_child(instance)

	return root


# [look shape key, offset, scale, yaw]: the item shapes of basic_look.gd, drawn larger than the item on the ground and grouped.
func _parts_of(kind: String) -> Array:
	match kind:
		"kelp":
			return [["weed", Vector3.ZERO, 3.2, 0.0], ["weed", Vector3(0.35, 0.0, 0.2), 2.4, 1.9]]
		"mussels":
			return [["mussel", Vector3.ZERO, 2.2, 0.0], ["mussel", Vector3(0.2, 0.0, 0.1), 1.9, 1.2], ["mussel", Vector3(-0.15, 0.0, 0.22), 2.0, 2.4], ["pebble", Vector3(0.0, 0.0, -0.3), 1.6, 0.5]]
		"crabs":
			return [["crab_live", Vector3.ZERO, 2.4, 0.0], ["pebble", Vector3(0.3, 0.0, 0.1), 1.4, 0.8], ["pebble", Vector3(-0.25, 0.0, 0.2), 1.1, 2.0]]
		"nest":
			return [["nest", Vector3.ZERO, 2.2, 0.0]]

	return [["pebble", Vector3.ZERO, 2.0, 0.0]]


func _mesh(shape: String) -> ArrayMesh:
	if not _meshes.has(shape):
		match shape:
			"weed":
				_meshes[shape] = BasicLook.mesh("weed", Color("#3c4a1c"))
			"mussel":
				_meshes[shape] = BasicLook.mesh("shellfish", Color("#2a3048"))
			"crab_live":
				_meshes[shape] = BasicLook.mesh("crab_live", Color("#7a4a2c"))
			"nest":
				_meshes[shape] = BasicLook.mesh("nest", Color("#a8905a"))
			_:
				_meshes[shape] = BasicLook.mesh("chunk", Color("#5a5854"), 0.5)

	return _meshes[shape]
