extends Node3D

# Fresh tracks (hunting thread, 23 Nov 2026; Dave: "making game trails actually visible with signs of game ... extrapolate from them and see
# what would make for a fun hunting game"): a live animal walking near the player leaves marks where its feet land, fading over life_s,
# so a hunter can follow the animal itself, not only its trail. Client only: each print comes from animal_view's `stepped` signal (a
# footfall of a drawn animal, read only; the animals thread's hook), so there is no message, no server work and no protocol change. Every
# client near the animal draws the same animal's steps. A higher Tracking keeps them in sight longer (life_s x up to life_mult at 100).
# One MultiMesh per print shape (hoof, paw, hop), at most max_prints in all, rebuilt at most twice a second and only while marks change.

const CONFIG := "res://data/look/fresh_tracks.json"
const TrailSigns := preload("res://src/client/trail_signs.gd")   # compass words
const PRINT_COLOR := Color(0.17, 0.13, 0.09)

var cfg: Dictionary = {}
var shape_of: Dictionary = {}      # animal kind -> "hoof", "paw" or "hop" (data/look/fresh_tracks.json kinds)
var marks: Array = []             # [Vector3 at, yaw, born msec, shape, kind], oldest first
var tracking: int = 0              # the player's Tracking (terrain_client sets it each frame with the trail signs)
var player_at: Callable            # () -> the player's position: marks farther than draw_m are not laid
var _recent: Array = []            # [kind, Vector3, msec, index of its print, followed] of the footfalls of the last 2 s, for the heading of the next
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
		return

	_recent = _recent.filter(func(r): return now - int(r[2]) < 2000)
	var yaw: float = NAN   # unknown until a second footfall of the same walk says which way it goes (never guessed: the reading would lie)
	var stride: float = float(cfg.get("stride_m", 1.6))
	var newest: Array = []  # the same kind's last footfall
	var ends: Array = []    # the same kind's footfalls of the last 2 s within two strides that no later step has followed: the walks it may go on

	for r in _recent:
		if str(r[0]) != kind:
			continue

		newest = r

		if not bool(r[4]) and Vector2(at.x - (r[1] as Vector3).x, at.z - (r[1] as Vector3).z).length() <= stride * 2.0:
			ends.append(r)

	if not newest.is_empty() and Vector2(at.x - (newest[1] as Vector3).x, at.z - (newest[1] as Vector3).z).length() < float(cfg.get("min_gap_m", 0.6)):
		return   # a gait count that barely moved (turning, a shuffle): no new print, so the list holds a walk of minutes, not seconds

	# The heading only when one walk can be going on here: exactly one unfollowed footfall of the kind within two strides, and it within one.
	# Two (animals grazing close, a herd pressed together) could be either: no heading rather than a wrong one (review 23 Nov). The signal
	# carries no animal, so two of a kind closer than a stride are still told apart only by this.
	if ends.size() == 1 and Vector2(at.x - (ends[0][1] as Vector3).x, at.z - (ends[0][1] as Vector3).z).length() <= stride:
		var last: Array = ends[0]
		last[4] = true
		yaw = Vector2(at.x - (last[1] as Vector3).x, at.z - (last[1] as Vector3).z).angle()

		if int(last[3]) >= 0 and int(last[3]) < marks.size() and is_nan(float(marks[int(last[3])][1])):
			marks[int(last[3])][1] = yaw   # the first print of the walk learns its heading from the second

	var side_yaw: float = 0.0 if is_nan(yaw) else yaw
	var side: Vector2 = Vector2(cos(side_yaw), sin(side_yaw)).orthogonal() * float(cfg.get("side_m", 0.07)) * (1.0 if marks.size() % 2 == 0 else -1.0)
	marks.append([Vector3(at.x + side.x, at.y, at.z + side.y), yaw, now, shape, kind])
	_recent.append([kind, at, now, marks.size() - 1, false])

	if marks.size() > int(cfg.get("max_prints", 480)):
		_cut_front(marks.size() - int(cfg.get("max_prints", 480)))

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
	var gone: int = 0   # marks are oldest first, so the expired ones are at the front

	while gone < marks.size() and float(now - int(marks[gone][2])) >= life:
		gone += 1

	_dirty = _dirty or not marks.is_empty()   # marks fade as they age
	_cut_front(gone)

	if not _dirty:
		return

	_dirty = false
	var rows: Dictionary = {"hoof": [], "paw": [], "hop": []}

	for p in marks:
		var age: float = float(now - int(p[2])) / life
		(rows[str(p[3])] as Array).append([p[0], 0.0 if is_nan(float(p[1])) else float(p[1]), clampf(1.0 - age * age, 0.0, 1.0)])   # strong while fresh, fading out at the end

	for shape in rows:
		_fill(shape, rows[shape])


# Reading a fresh print (hunting thread, 23 Nov 2026): the newest print of each animal kind within read_m, as [index, point] for the aim.
func readable(player: Vector3, now_msec: int = -1) -> Array:
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var out: Array = []
	var seen: Dictionary = {}
	var life: float = life_s(tracking, cfg) * 1000.0

	if marks.is_empty():
		return out

	for n in range(marks.size() - 1, -1, -1):
		var m: Array = marks[n]

		if float(now - int(m[2])) >= life * 0.9 or Vector2((m[0] as Vector3).x - player.x, (m[0] as Vector3).z - player.z).length() > float(cfg.get("read_m", 3.0)):
			continue   # flat, as the trail signs; not the last tenth of its life, when it has faded out of sight

		var tag: String = "%s %d %d" % [str(m[4]), roundi((m[0] as Vector3).x), roundi((m[0] as Vector3).z)]

		if not seen.has(tag):
			seen[tag] = true
			out.append([n, (m[0] as Vector3) + Vector3(0.0, 0.03, 0.0)])

	return out


# What a fresh print says (data/look/fresh_tracks.json "read"): whose it is and how old for anyone, a warning for a predator's; from
# read_way_level which way it was heading.
static func read_text(mark: Array, level: int, now_msec: int, c: Dictionary) -> String:
	var lines: Dictionary = c.get("read", {})
	var kind: String = str(mark[4])
	var who: String = str((lines.get("names", {}) as Dictionary).get(kind, kind.replace("_", " ")))
	var age_s: float = float(now_msec - int(mark[2])) / 1000.0
	var ages: Dictionary = lines.get("ages", {})
	var age: String = str(ages.get("now", "made just now")) if age_s < 60.0 else (str(ages.get("minutes", "made minutes ago")) if age_s < 300.0 else str(ages.get("older", "made a while ago")))
	var text: String = str(lines.get("what", "%s prints, %s.")) % [who.substr(0, 1).to_upper() + who.substr(1), age]

	if (lines.get("predators", []) as Array).has(kind):
		text += " " + str(lines.get("warning", "Something dangerous is about."))

	if level >= int(c.get("read_way_level", 10)) and not is_nan(float(mark[1])):   # a heading only when its steps told it
		var yaw: float = float(mark[1])
		text += " " + str(lines.get("way", "It was heading %s.")) % TrailSigns.compass(Vector2(cos(yaw), sin(yaw)))

	return text


# Drops the n oldest marks; the recent footfalls' print indexes move with them (an index under 0 is a print gone).
func _cut_front(n: int) -> void:
	if n <= 0:
		return

	marks = marks.slice(n)

	for r in _recent:
		r[3] = int(r[3]) - n


func mark_at(index: int) -> Array:
	return marks[index] if index >= 0 and index < marks.size() else []


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
