extends Node

# Water you can hear (client only; queue job "water sounds"). Four kinds, each a
# seamless loop: brook (narrow, babbling), river (wide, a deeper burble and trickle, no rumble), pond
# (a lake or pond shore, slow lapping) and waterfall (a steep drop, a heavy roar).
#
# Every SCAN_SEC seconds the water squares (8 m grid, the same lookups the water
# drawing and the footsteps use) around the player are read into a small grid.
# A wet square is sorted by how much water lies around it and how steeply the
# surface drops: a drop of FALL_DROP_M or more between neighbours is rapids (louder), real waterfalls come from the water chunk fall list,
# 16 or more wet squares in the 5 x 5 around it a pond, 8 or more a river, else a
# brook. The nearest square of each kind becomes a source, with a second one of
# the same kind at least SEPARATION_M further along when there is room, and the
# best MAX_SOURCES sources are played from 3D positions. Sources glide to new
# positions and fade in and out, so nothing pops while the player walks. Steep
# brooks babble louder. Cost: 289 squares read every 1.5 s, three rows a frame, and at most
# MAX_SOURCES looping voices.
#
# The sea (waves) is not here yet: it needs the distance to the shore.
# Sounds: generated placeholders in assets/audio/water/ (make_water.py);
# recordings in assets/audio/recorded/water/ with the same names win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/water/"
const RECORDED_DIR := "res://assets/audio/recorded/water/"

const SCAN_SEC := 2.5
const SPACING_M := 8.0
const HALF := 8                         # squares each way: 8 x 8 m = 64 m reach
const MAX_SOURCES := 4
const MAX_DEPTH_M := 12.0
const SPEED_REF := 0.5                  # m/s with no loudness change (the current simulated rivers run 0.1 to 1 m/s)
const SPEED_FLOOR := 0.15
const SPEED_DB_PER_OCTAVE := 5.0        # per doubling of the current speed
const ROWS_PER_FRAME := 2               # of the 17 scan rows
const SEPARATION_M := 36.0
const FALL_MERGE_M := 100.0              # falls farther than this and within FALL_CLUSTER_M of each other share one voice
const FALL_CLUSTER_M := 120.0

# The base of a fall (job 55): a close hiss and splash under the roar, only within BASE_REACH_M of the landing
# point. Level from the fall: +3 dB per doubling of width (4 m reference) and +2 dB per doubling of the drop (4 m),
# the flow through the width. One loop at most, a few dB softer with distance by its own attenuation.
const BASE_REACH_M := 60.0
const BASE_DB := -12.0
const BASE_FILE := "water_fall_base"
const FALL_DROP_M := 1.0                # surface drop between neighbouring squares
const POND_AROUND := 16
const RIVER_AROUND := 8

# kind: loop name, loudness at the source (dB), how far it carries (m) for choosing sources
# A fall carries far: its player hears out to FALL_MAX_M, a bigger unit size keeps it audible, and the
# distance low-pass (the player's own attenuation filter) takes the top off with range.
const FALL_MAX_M := 300.0
const FALL_UNIT := 26.0
const FALL_FILTER_HZ := 2200.0

const KINDS := {
	"brook": {"file": "water_brook", "db": -15.0, "reach": 45.0},
	"river": {"file": "water_river", "db": -22.0, "reach": 50.0},
	"pond": {"file": "water_pond", "db": -17.0, "reach": 35.0},
	"fall": {"file": "water_fall", "db": -14.0, "reach": 260.0},
}

var sources: Array = []                 # what is playing now: [{kind, distance}] for the HUD
var summary: String = ""
var merged_falls: int = 0               # falls folded into another's voice at the last choice (HUD, check)

var _flora
var _base: AudioStreamPlayer3D          # the fall-base hiss and splash, one loop at the nearest fall within BASE_REACH_M
var _base_target: Vector3 = Vector3.ZERO
var _base_db: float = -80.0
var base_fall_drop: float = 0.0         # HUD: drop height of the fall the base sound sits at, 0 when none
var _slots: Array = []                  # {player, kind, target, fade}
var _streams: Dictionary = {}
var _scan_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _row: int = -1                      # next scan row to read, -1 between scans
var _level: PackedFloat32Array = PackedFloat32Array()
var _speed: PackedFloat32Array = PackedFloat32Array()   # current at each square, m/s, -1 unknown
var _tool: VoxelTool
var _origin: Vector3 = Vector3.ZERO
var _cx: float = 0.0
var _cz: float = 0.0
var _candidates: Array = []


func setup(flora, terrain: VoxelLodTerrain = null) -> void:
	_flora = flora

	if terrain != null:
		_tool = terrain.get_voxel_tool()
		_tool.channel = VoxelBuffer.CHANNEL_SDF
	_rng.randomize()

	for n in range(MAX_SOURCES):
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.bus = "Nature"
		player.volume_db = -80.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 10.0
		player.max_distance = 140.0
		player.attenuation_filter_cutoff_hz = 9000.0
		add_child(player)
		player.add_to_group("world_sounds")
		_slots.append({"player": player, "kind": "", "target": Vector3.ZERO, "fade": -80.0})

	# The base of the nearest fall, heard close (job 55): spray and churn under the roar.
	_base = AudioStreamPlayer3D.new()
	_base.bus = "Nature"
	_base.volume_db = -80.0
	_base.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_base.unit_size = 6.0
	_base.max_distance = BASE_REACH_M * 1.5
	_base.attenuation_filter_cutoff_hz = 12000.0
	add_child(_base)
	_base.add_to_group("world_sounds")

	# Loads the loops now, so the first river met doesn't stall a frame reading a file.
	for kind in KINDS:
		_variants(str(KINDS[kind]["file"]))

	_variants(BASE_FILE)


func voices_playing() -> int:
	var count: int = 1 if _base.playing else 0

	for slot in _slots:
		if slot["player"].playing:
			count += 1

	return count


func update(delta: float, body: CharacterBody3D, underwater: bool) -> void:
	_scan_left -= delta

	if _row < 0 and _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_start_scan(body.global_position)

	# Steps through the scan a few rows a frame: first reading the water, then sorting it.
	if _row >= 0:
		var count: int = HALF * 2 + 1

		if _row < count:
			_read_rows(ROWS_PER_FRAME)
		elif _row < count * 2:
			for r in range(ROWS_PER_FRAME):
				if _row < count * 2:
					_classify_row(_row - count)
					_row += 1
		else:
			_row = -1
			_choose()

	_update_base(delta)

	for slot in _slots:
		var player: AudioStreamPlayer3D = slot["player"]

		if slot["kind"] == "":
			continue

		player.global_position = player.global_position.lerp(slot["target"], clampf(delta * 3.0, 0.0, 1.0))
		var db: float = float(slot["fade"])
		player.volume_db = lerpf(player.volume_db, db, clampf(delta * 2.0, 0.0, 1.0))
		player.pitch_scale = lerpf(player.pitch_scale, float(slot.get("pitch", 1.0)), clampf(delta * 1.5, 0.0, 1.0))

		if db <= -60.0 and player.volume_db < -55.0:
			player.stop()
			slot["kind"] = ""


func _update_base(delta: float) -> void:
	if _base_db <= -60.0 and _base.volume_db < -55.0:
		if _base.playing:
			_base.stop()

		return

	if not _base.playing:
		var list: Array = _variants(BASE_FILE)

		if list.is_empty():
			return

		_base.stream = list[0]
		_base.global_position = _base_target
		_base.volume_db = -80.0
		_base.play(_rng.randf() * 8.0)

	_base.global_position = _base.global_position.lerp(_base_target, clampf(delta * 3.0, 0.0, 1.0))
	_base.volume_db = lerpf(_base.volume_db, _base_db, clampf(delta * 2.0, 0.0, 1.0))


# A scan reads the squares a few rows per frame (no frame pays for all of it),
# then sorts the wet ones and gives each source slot its job.
func _start_scan(origin: Vector3) -> void:
	var count: int = HALF * 2 + 1
	_origin = origin
	_cx = floorf(origin.x / SPACING_M) * SPACING_M + SPACING_M * 0.5
	_cz = floorf(origin.z / SPACING_M) * SPACING_M + SPACING_M * 0.5
	_level.resize(count * count)
	_speed.resize(count * count)
	_row = 0


func _read_rows(rows: int) -> void:
	var count: int = HALF * 2 + 1

	for r in range(rows):
		if _row >= count:
			return

		var j: int = _row

		for i in range(count):
			var x: float = _cx + float(i - HALF) * SPACING_M
			var z: float = _cz + float(j - HALF) * SPACING_M
			_level[j * count + i] = _flora.water_surface_at(x, z)
			_speed[j * count + i] = _flora.water_speed_at(x, z) if not is_nan(_level[j * count + i]) else -1.0

		_row += 1


func _classify_row(j: int) -> void:
	var count: int = HALF * 2 + 1
	var level: PackedFloat32Array = _level
	var origin: Vector3 = _origin
	var cx: float = _cx
	var cz: float = _cz

	if j == 0:
		_candidates.clear()

	for i in range(count):
		var here: float = level[j * count + i]

		if is_nan(here):
			continue

		var around: int = 0

		for dj in range(-2, 3):
			for di in range(-2, 3):
				var ni: int = i + di
				var nj: int = j + dj

				if ni >= 0 and nj >= 0 and ni < count and nj < count and not is_nan(level[nj * count + ni]):
					around += 1

		var drop: float = 0.0

		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = i + step.x
			var nj: int = j + step.y

			if ni >= 0 and nj >= 0 and ni < count and nj < count and not is_nan(level[nj * count + ni]):
				drop = maxf(drop, absf(here - level[nj * count + ni]))

		var kind: String = "brook"

		# Waterfalls come from the water chunk's fall columns (_fall_candidates); a steep reach on the grid is rapids.
		if around >= POND_AROUND:
			kind = "pond"
		elif around >= RIVER_AROUND:
			kind = "river"

		var at: Vector3 = Vector3(cx + float(i - HALF) * SPACING_M, here, cz + float(j - HALF) * SPACING_M)
		var distance: float = Vector2(at.x - origin.x, at.z - origin.z).length()

		if distance <= float(KINDS[kind]["reach"]):
			_candidates.append({"kind": kind, "at": at, "distance": distance, "drop": drop, "speed": _speed[j * count + i], "score": distance / float(KINDS[kind]["reach"])})



func _choose() -> void:
	var candidates: Array = _candidates
	candidates.append_array(_fall_candidates(_origin))
	candidates.sort_custom(func(a, b): return a["score"] < b["score"])
	var chosen: Array = []

	for candidate in candidates:
		if chosen.size() >= MAX_SOURCES:
			break

		var apart: bool = true

		for other in chosen:
			if other["kind"] == candidate["kind"] and Vector2(other["at"].x - candidate["at"].x, other["at"].z - candidate["at"].z).length() < SEPARATION_M:
				apart = false
				break

		if apart:
			chosen.append(candidate)

	_pick_base(candidates)

	for candidate in chosen:
		candidate["depth"] = _depth_at(candidate["at"]) if candidate["kind"] != "fall" else -1.0

	_assign(chosen, _origin)


# The waterfalls the water chunks carry (flora.fall_list(): top, base, pool, flow, width in world coordinates):
# the roar sits at the landing point, louder with the width and the height of the drop.
func _fall_candidates(origin: Vector3) -> Array:
	var found: Array = []

	if _flora == null or not _flora.has_method("fall_list"):
		return found

	for fall in _flora.fall_list():
		var base: Vector3 = fall["base"]
		var at: Vector3 = Vector3(base.x, maxf(float(fall["pool"]), base.y), base.z)
		var distance: float = Vector2(at.x - origin.x, at.z - origin.z).length()

		if distance <= float(KINDS["fall"]["reach"]):
			found.append({"kind": "fall", "at": at, "distance": distance, "drop": float(fall["top"].y) - base.y, "speed": -1.0,
				"width": float(fall["width"]), "score": distance / float(KINDS["fall"]["reach"])})

	return _merge_far_falls(found, origin)


# Falls beyond FALL_MERGE_M that lie within FALL_CLUSTER_M of each other are one distant roar (job 53): one voice at
# their width-weighted centre, as wide as all of them together (a few dB louder), so a valley of falls takes one of the
# MAX_SOURCES slots, not all of them. Near falls stay single.
func _merge_far_falls(found: Array, origin: Vector3) -> Array:
	merged_falls = 0
	var near: Array = []
	var far: Array = []

	for fall in found:
		if float(fall["distance"]) > FALL_MERGE_M:
			far.append(fall)
		else:
			near.append(fall)

	far.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var clusters: Array = []

	for fall in far:
		var joined: bool = false

		for cluster in clusters:
			if Vector2(cluster["seed"].x - fall["at"].x, cluster["seed"].z - fall["at"].z).length() <= FALL_CLUSTER_M:
				cluster["members"].append(fall)
				joined = true
				break

		if not joined:
			clusters.append({"seed": fall["at"], "members": [fall]})

	for cluster in clusters:
		var members: Array = cluster["members"]

		if members.size() == 1:
			near.append(members[0])
			continue

		var total: float = 0.0
		var centre: Vector3 = Vector3.ZERO
		var drop: float = 0.0

		for fall in members:
			var w: float = maxf(float(fall["width"]), 0.5)
			total += w
			centre += fall["at"] * w
			drop = maxf(drop, float(fall["drop"]))

		centre /= total
		var distance: float = Vector2(centre.x - origin.x, centre.z - origin.z).length()
		near.append({"kind": "fall", "at": centre, "distance": distance, "drop": drop, "speed": -1.0, "width": total,
			"score": distance / float(KINDS["fall"]["reach"]), "merged": members.size()})
		merged_falls += members.size() - 1

	return near


func _assign(chosen: Array, origin: Vector3) -> void:
	var used: Array = []
	var pending: Array = []

	# Keep a slot on a source of the same kind that is still close to it, so it glides, not jumps.
	for candidate in chosen:
		var best: int = -1
		var best_distance: float = SEPARATION_M * 0.9

		for n in range(_slots.size()):
			var slot: Dictionary = _slots[n]

			if n in used or slot["kind"] != candidate["kind"]:
				continue

			var d: float = Vector2(slot["target"].x - candidate["at"].x, slot["target"].z - candidate["at"].z).length()

			if d < best_distance:
				best_distance = d
				best = n

		if best >= 0:
			used.append(best)
			_aim(_slots[best], candidate, origin)
		else:
			pending.append(candidate)

	for candidate in pending:
		var free: int = -1

		for n in range(_slots.size()):
			if n not in used and _slots[n]["kind"] == "":
				free = n
				break

		if free < 0:
			for n in range(_slots.size()):
				if n not in used:
					free = n
					break

		if free < 0:
			break

		used.append(free)
		var slot: Dictionary = _slots[free]
		var list: Array = _variants(str(KINDS[candidate["kind"]]["file"]))

		if list.is_empty():
			continue

		var player: AudioStreamPlayer3D = slot["player"]
		player.stream = list[0]
		var far: bool = candidate["kind"] == "fall"
		player.max_distance = FALL_MAX_M if far else 140.0
		player.unit_size = FALL_UNIT if far else 10.0
		player.attenuation_filter_cutoff_hz = FALL_FILTER_HZ if far else 9000.0
		player.global_position = candidate["at"]
		player.volume_db = -80.0
		slot["kind"] = candidate["kind"]
		_aim(slot, candidate, origin)
		player.play(_rng.randf() * 8.0)

	for n in range(_slots.size()):
		if n not in used and _slots[n]["kind"] != "":
			_slots[n]["fade"] = -80.0

	sources.clear()
	var parts: PackedStringArray = PackedStringArray()

	for slot in _slots:
		if slot["kind"] != "" and slot["fade"] > -60.0:
			var d: float = Vector2(slot["target"].x - origin.x, slot["target"].z - origin.z).length()
			sources.append({"kind": slot["kind"], "distance": d})
			parts.append("%s %.0f m %s" % [slot["kind"], d, slot.get("tuned", "")])

	summary = ", ".join(parts) if not parts.is_empty() else "none"


# The nearest single fall within BASE_REACH_M gets the close hiss and splash.
func _pick_base(candidates: Array) -> void:
	var best: Dictionary = {}

	for candidate in candidates:
		if candidate["kind"] != "fall" or candidate.has("merged") or float(candidate["distance"]) > BASE_REACH_M:
			continue

		if best.is_empty() or float(candidate["distance"]) < float(best["distance"]):
			best = candidate

	if best.is_empty():
		_base_db = -80.0
		base_fall_drop = 0.0
		return

	_base_target = best["at"]
	base_fall_drop = float(best["drop"])
	_base_db = BASE_DB + clampf(3.0 * log(maxf(float(best.get("width", 4.0)), 0.5) / 4.0) / log(2.0), -5.0, 4.0) \
		+ clampf(2.0 * log(maxf(base_fall_drop, 1.0) / 4.0) / log(2.0), -4.0, 5.0)


# How deep the water is under a surface point (m): a voxel ray down to the bed, -1 when unknown.
func _depth_at(at: Vector3) -> float:
	if _tool == null:
		return -1.0

	var hit = _tool.raycast(at + Vector3(0.0, 0.5, 0.0), Vector3.DOWN, MAX_DEPTH_M)
	return maxf(float(hit.distance) - 0.5, 0.0) if hit != null else -1.0


# The source's loudness and pitch follow the real current and depth (build 101 carries the
# current in the water chunk): faster water is louder, brighter and a touch higher, deep
# water is a touch lower and softer. Ponds, falls and unknown currents keep their set level.
func _aim(slot: Dictionary, candidate: Dictionary, origin: Vector3) -> void:
	slot["target"] = candidate["at"]
	var db: float = float(KINDS[candidate["kind"]]["db"])
	var pitch: float = 1.0

	if candidate["kind"] == "brook":
		db += clampf(float(candidate["drop"]) / 0.5, 0.0, 1.0) * 4.0     # steeper babbles louder
	elif candidate["kind"] == "river":
		db += clampf((float(candidate["drop"]) - 0.1) / 0.5, 0.0, 1.0) * 5.0    # a steep reach (rapids) is louder; a calm one stays quiet

	if candidate["kind"] == "fall":
		db += clampf(3.0 * log(maxf(float(candidate.get("width", 4.0)), 0.5) / 4.0) / log(2.0), -5.0, 4.0)    # wider falls roar louder
		db += clampf((float(candidate["drop"]) - 3.0) / 10.0, 0.0, 1.0) * 3.0                                # and taller ones

	var speed: float = float(candidate.get("speed", -1.0))

	if speed >= 0.0 and candidate["kind"] in ["brook", "river"]:
		var octaves: float = log(maxf(speed, SPEED_FLOOR) / SPEED_REF) / log(2.0)
		# Owner 2026-10-20: rivers sounded like ocean surf. Only fast water gets louder (up to +3 dB, and
		# only rapids add the slope boost below); calm reaches get quieter and keep their pitch.
		db += clampf(SPEED_DB_PER_OCTAVE * octaves, -6.0, 3.0)
		pitch += 0.04 * clampf(octaves, -1.5, 2.0)

	var depth: float = float(candidate.get("depth", -1.0))

	if depth >= 0.0 and candidate["kind"] in ["brook", "river", "pond"]:
		var deep: float = clampf(depth / 3.0, 0.0, 1.0)
		db -= 3.0 * deep
		pitch -= 0.07 * deep

	slot["pitch"] = clampf(pitch, 0.85, 1.15)
	slot["tuned"] = "v%.1f d%.1f" % [speed, depth]

	slot["fade"] = db


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	for stream in list:
		if stream is AudioStreamOggVorbis:
			stream.loop = true

	_streams[name] = list
	return list


func _exit_tree() -> void:
	for slot in _slots:
		slot["player"].stop()
		slot["player"].stream = null

	_streams.clear()
