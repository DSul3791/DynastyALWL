extends RefCounted

# Single birds in flight, step 1 (docs/design/bird_flight_server_design.md; MikeW's client flight layer, BIRD_FLIGHT.md and FLIGHT_RIGS.md).
# A species row with a "flight" block flies instead of running when it bolts:
#   flush (pheasant, grouse, guineafowl): sits tight to flush_m, bursts straight up climb_m, flies away (bending to cover), glides the last
#     glide_share down, lands and runs run_m into cover;
#   perch (crow): flies to a spot under tree crowns fly_m off and sits perch_up_m up; comes down after perch_s once nobody is near.
# Flight is a list of straight segments followed by elapsed time, so a far bird ticked at 0.5 Hz is where it would be at 10 Hz. Every
# segment is kept clear_m over the ground (sampled every 5 m) except where it lands. Wire: 15 flying (flapping), 17 gliding, 0 on the
# ground or perched (the position carries the height).


const FLY := 15
const GLIDE := 17
const SAMPLE_M := 5.0
const LIFT_MARGIN_M := 0.5

var host                            # ServerAnimals


func _row(a: Dictionary) -> Dictionary:
	return host.species_def(a["sp"]).get("flight", {})


func handles(a: Dictionary) -> bool:
	return a.has("fly") or bool(a.get("perched", false))


func _ground(x: float, z: float) -> float:
	return float(host.ground_height.call(x, z)) if host.ground_height.is_valid() else 0.0


func _clear_m() -> float:
	return float(host.cfg.get("flight", {}).get("clear_m", 3.0))


func _stormy() -> bool:
	return float(host._wx.get("rain", 0.0)) > 0.6 or float(host._wx.get("storm", 0.0)) >= 0.5


# The way it flies from a threat: straight away, bent toward tree cover within 45 degrees when there is some at `reach`; with the wind
# behind it in a gale.
func _away(a: Dictionary, from: Vector3, reach: float) -> Vector2:
	var away: Vector2 = Vector2(a["pos"].x - from.x, a["pos"].z - from.z) if from.is_finite() else Vector2.ZERO   # an alarm with no player in sight
	away = away.normalized() if away.length() > 0.01 else Vector2.from_angle(float(a["heading"]))

	if float(host._wx.get("wind", 0.0)) >= 0.6:
		away = (away + host._wind_dir).normalized() if (away + host._wind_dir).length() > 0.01 else away

	if host.canopy.is_valid():
		for deg in [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0]:
			var d: Vector2 = away.rotated(deg_to_rad(deg))
			var end: Vector3 = Vector3(a["pos"].x + d.x * reach, 0.0, a["pos"].z + d.y * reach)
			end.y = _ground(end.x, end.z)

			if bool(host.canopy.call(end)):
				return d

	return away


# Segments [from, to, seconds, wire state] for a flight from `from` to `to`: the straight line, lifted where it would come within clear_m of
# the ground (every SAMPLE_M, with LIFT_MARGIN_M so the line between samples clears a rounded hill too), except over its last land_m metres
# where the clearance ramps down to the touch-down point. A lifted stretch that climbs is flown flapping (15) even in a glide.
func _path(from: Vector3, to: Vector3, speed: float, state: int, land_m: float = 0.0) -> Array:
	var horiz: float = Vector2(to.x - from.x, to.z - from.z).length()
	var n: int = maxi(int(ceil(horiz / SAMPLE_M)), 1)
	var pts: Array = [from]

	for k in range(1, n + 1):
		var f: float = float(k) / float(n)
		var p: Vector3 = from.lerp(to, f)
		var to_end: float = horiz * (1.0 - f)
		var lift: float = _clear_m() + LIFT_MARGIN_M

		if land_m > 0.0 and to_end < land_m:
			lift *= to_end / land_m   # coming in to land: the clearance ramps down to the touch-down point

		p.y = maxf(p.y, _ground(p.x, p.z) + lift)

		pts.append(p)

	var segs: Array = []

	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		segs.append([a, b, maxf(a.distance_to(b) / maxf(speed, 0.1), 0.01), FLY if b.y > a.y + 0.5 else state])

	return segs


# Take off from a threat at `from` (called by ServerAnimals._bolt for a species with a flight row).
func take_off(a: Dictionary, from: Vector3) -> void:
	var row: Dictionary = _row(a)
	var kind: String = str(row.get("kind", "flush"))
	var climb: Array = row.get("climb_m", [10.0, 15.0])
	var fly: Array = row.get("fly_m", [120.0, 300.0])
	var speed: float = float(row.get("fly_mps", 18.0))
	var glide: float = clampf(float(row.get("glide_share", 0.3)), 0.0, 0.9)
	var dist: float = host.rng.randf_range(float(fly[0]), float(fly[1])) * (0.6 if float(host._wx.get("wind", 0.0)) >= 0.6 else 1.0)   # luck-exempt: how far a flushed bird flies
	var up: float = host.rng.randf_range(float(climb[0]), float(climb[1]))   # luck-exempt: how high it climbs
	var dir: Vector2 = _away(a, from, dist)
	var p0: Vector3 = a["pos"]
	var p1: Vector3 = p0 + Vector3(dir.x * 2.0, up, dir.y * 2.0)
	var segs: Array = [[p0, p1, float(row.get("burst_s", 1.5)), FLY]]   # the burst: straight up, the one part allowed near the ground
	var end: Vector3 = p0 + Vector3(dir.x, 0.0, dir.y) * dist
	end.y = _ground(end.x, end.z)

	if kind == "perch" and host.canopy.is_valid() and bool(host.canopy.call(end)):
		var perch: Vector3 = Vector3(end.x, end.y + float(row.get("perch_up_m", 8.0)), end.z)
		var cruise: Vector3 = p1.lerp(perch, 1.0 - glide)
		cruise.y = maxf(p1.y, perch.y + 2.0)
		segs.append_array(_path(p1, cruise, speed, FLY))
		segs.append_array(_path(segs.back()[1], perch, speed * 0.8, GLIDE, 0.01))
		a["fly"] = {"segs": segs, "k": 0, "t": 0.0, "perch": true}
	else:
		var glide_from: Vector3 = p0 + Vector3(dir.x, 0.0, dir.y) * dist * (1.0 - glide)
		glide_from.y = _ground(glide_from.x, glide_from.z) + up
		segs.append_array(_path(p1, glide_from, speed, FLY))
		segs.append_array(_path(segs.back()[1], end, speed * 0.8, GLIDE, 10.0))
		a["fly"] = {"segs": segs, "k": 0, "t": 0.0, "perch": false}

	a.erase("perched")
	a["state"] = FLY
	a["heading"] = atan2(dir.y, dir.x)
	a["alarm"] = -1.0


# One step of a bird in the air or on a perch. `seen_d` and `seen_p` are the nearest player as the bird senses them.
func step(a: Dictionary, dt: float, seen_d: float, seen_p: Vector3) -> void:
	if a.has("fly"):
		_fly(a, dt)
		return

	# Perched: it sits until perch_s has run out and nobody is within safe_m (and not in a storm), then glides down to feed; a player within
	# spook_m sends it off again.
	var def: Dictionary = host.species_def(a["sp"])
	var row: Dictionary = _row(a)

	if seen_d <= host._spook_m(a, def):
		take_off(a, seen_p)
		return

	a["timer"] = float(a["timer"]) - dt
	a["state"] = 0

	if float(a["timer"]) > 0.0 or seen_d <= float(def.get("safe_m", 35.0)) or _stormy() or host.fog_grounded(a["pos"]):   # sits out thick fog (animals_in_fog_server.md 4.4)
		return

	var angle: float = host.rng.randf() * TAU   # luck-exempt: where a crow comes down
	var down: Vector3 = a["pos"] + Vector3(cos(angle), 0.0, sin(angle)) * host.rng.randf_range(10.0, 30.0)   # luck-exempt: as above
	down.y = _ground(down.x, down.z)
	a["fly"] = {"segs": _path(a["pos"], down, float(row.get("fly_mps", 12.0)) * 0.6, GLIDE, 10.0), "k": 0, "t": 0.0, "perch": false}
	a.erase("perched")
	a["state"] = GLIDE


func _fly(a: Dictionary, dt: float) -> void:
	var f: Dictionary = a["fly"]
	f["t"] = float(f["t"]) + dt

	while int(f["k"]) < (f["segs"] as Array).size() and float(f["t"]) >= float(f["segs"][int(f["k"])][2]):
		f["t"] = float(f["t"]) - float(f["segs"][int(f["k"])][2])
		f["k"] = int(f["k"]) + 1

	var segs: Array = f["segs"]

	if int(f["k"]) >= segs.size():
		_land(a, segs.back()[1], bool(f["perch"]))
		return

	var s: Array = segs[int(f["k"])]
	var from: Vector3 = s[0]
	var to: Vector3 = s[1]
	a["pos"] = from.lerp(to, clampf(float(f["t"]) / float(s[2]), 0.0, 1.0))
	a["state"] = int(s[3])

	if Vector2(to.x - from.x, to.z - from.z).length() > 0.5:
		a["heading"] = atan2(to.z - from.z, to.x - from.x)


func _land(a: Dictionary, at: Vector3, perch: bool) -> void:
	var def: Dictionary = host.species_def(a["sp"])
	var row: Dictionary = _row(a)
	a.erase("fly")
	a["pos"] = at

	if perch:
		a["perched"] = true
		a["state"] = 0
		var span: Array = row.get("perch_s", [30.0, 90.0])
		a["timer"] = host.rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how long a crow sits
		return

	a["pos"] = Vector3(at.x, _ground(at.x, at.z), at.z)
	a["home"] = a["pos"]
	var run: float = float(row.get("run_m", 0.0))

	if run > 0.0:
		var ahead: Vector2 = Vector2.from_angle(float(a["heading"]))
		a["target"] = a["pos"] + Vector3(ahead.x, 0.0, ahead.y) * run
		a["home"] = a["target"]
		a["state"] = host.HOP
		return

	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(def)
