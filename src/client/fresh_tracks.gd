extends Node3D

# Fresh tracks (hunting thread, 23 Nov 2026; Dave: "making game trails actually visible with signs of game ... extrapolate from them and see
# what would make for a fun hunting game"): a live animal walking near the player leaves marks where its feet land, fading over life_s,
# so a hunter can follow the animal itself, not only its trail. Client only: each print comes from animal_view's `stepped` signal (a
# footfall of a drawn animal, read only; the animals thread's hook), so there is no message, no server work and no protocol change. Every
# client near the animal draws the same animal's steps. A higher Tracking keeps them in sight longer (life_s x up to life_mult at 100).
# One MultiMesh per print shape (hoof, paw, hop), at most max_prints in all, rebuilt at most twice a second and only while marks change.

const CONFIG := "res://data/look/fresh_tracks.json"
const PRINT_COLOR := Color(0.17, 0.13, 0.09)

var cfg: Dictionary = {}
var shape_of: Dictionary = {}      # animal kind -> "hoof", "paw" or "hop" (data/look/fresh_tracks.json kinds)
var marks: Array = []             # [Vector3 at, yaw, born msec, shape], oldest first
var tracking: int = 0              # the player's Tracking (terrain_client sets it each frame with the trail signs)
var player_at: Callable            # () -> the player's position: marks farther than draw_m are not laid
var _last_step: Dictionary = {}    # kind -> [Vector3, msec] of its last footfall, for the heading of the next
var _nodes: Dictionary = {}        # shape -> MultiMeshInstance3D
var _dirty: bool = false
var _next_msec: int = 0


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	for shape in (cfg.get("kinds", {}) as Dictionary):
		for kind in cfg["kinds"][shape]:
			shape_of[str(kind)] = str(shape)


# How long a print stays at a Tracking level, in real seconds.
static func life_s(level: int, c: Dictionary) -> float:
	return float(c.get("life_s", 600.0)) * lerpf(1.0, float(c.get("life_mult", 2.0)), clampf(float(level) / 100.0, 0.0, 1.0))


# A footfall of a drawn animal (animal_view.stepped). Kinds with no print shape (birds, frogs) and steps far from the player leave nothing.
func on_step(kind: String, at: Vector3, now_msec: int = -1) -> void:
	var shape: String = str(shape_of.get(kind, ""))

	if shape == "":
		return

	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec

	if player_at.is_valid() and (player_at.call() as Vector3).distance_to(at) > float(cfg.get("draw_m", 30.0)):
		_last_step.erase(kind)
		return

	var yaw: float = 0.0
	var last: Array = _last_step.get(kind, [])

	# The heading from the same kind's last footfall when it was close and recent (several of a kind at once give a rough heading; a print is small).
	if not last.is_empty() and now - int(last[1]) < 2000 and Vector2(at.x - last[0].x, at.z - last[0].z).length() < 4.0 and Vector2(at.x - last[0].x, at.z - last[0].z).length() > 0.05:
		yaw = Vector2(at.x - last[0].x, at.z - last[0].z).angle()
	elif not last.is_empty():
		yaw = float(last[2]) if last.size() > 2 else 0.0

	if not last.is_empty() and Vector2(at.x - last[0].x, at.z - last[0].z).length() < float(cfg.get("min_gap_m", 0.6)) and now - int(last[1]) < 2000:
		return   # a gait count that barely moved (turning, a shuffle): no new print, so the list holds a walk of minutes, not seconds

	_last_step[kind] = [at, now, yaw]
	var side: Vector2 = Vector2(cos(yaw), sin(yaw)).orthogonal() * float(cfg.get("side_m", 0.07)) * (1.0 if marks.size() % 2 == 0 else -1.0)
	marks.append([Vector3(at.x + side.x, at.y, at.z + side.y), yaw, now, shape])

	if marks.size() > int(cfg.get("max_prints", 240)):
		marks = marks.slice(marks.size() - int(cfg.get("max_prints", 240)))

	_dirty = true


# Called each frame: drops marks past their life and redraws, at most twice a second, only when something changed or is fading.
func update(now_msec: int = -1) -> void:
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec

	if now < _next_msec:
		return

	_next_msec = now + 500

	if marks.is_empty() and not _dirty:
		return

	var life: float = life_s(tracking, cfg) * 1000.0
	var kept: Array = marks.filter(func(p): return float(now - int(p[2])) < life)
	_dirty = _dirty or kept.size() != marks.size() or not marks.is_empty()   # marks fade as they age
	marks = kept

	if not _dirty:
		return

	_dirty = false
	var rows: Dictionary = {"hoof": [], "paw": [], "hop": []}

	for p in marks:
		var age: float = float(now - int(p[2])) / life
		(rows[str(p[3])] as Array).append([p[0], float(p[1]), clampf(1.0 - age * age, 0.0, 1.0)])   # strong while fresh, fading out at the end

	for shape in rows:
		_fill(shape, rows[shape])


func shown() -> int:
	return marks.size()


func _fill(shape: String, rows: Array) -> void:
	if rows.is_empty() and not _nodes.has(shape):
		return

	if not _nodes.has(shape):
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = "FreshTracks_" + shape
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _mesh(shape)
		node.multimesh = multi
		add_child(node)
		_nodes[shape] = node

	var mm: MultiMesh = (_nodes[shape] as MultiMeshInstance3D).multimesh
	mm.instance_count = rows.size()

	for n in rows.size():
		var row: Array = rows[n]
		mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, PI * 0.5 - float(row[1])), row[0] + Vector3(0.0, 0.012, 0.0)))   # the long side (z) along the heading
		mm.set_instance_color(n, Color(PRINT_COLOR.r, PRINT_COLOR.g, PRINT_COLOR.b, float(cfg.get("alpha", 0.85)) * float(row[2])))


func _mesh(shape: String) -> Mesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box: BoxMesh = BoxMesh.new()
	var size: Array = (cfg.get("size_m", {}) as Dictionary).get(shape, [0.07, 0.09])
	box.size = Vector3(float(size[0]), 0.006, float(size[1]))
	box.material = material
	return box
