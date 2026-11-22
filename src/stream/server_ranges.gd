extends RefCounted

# Animal places and the game trails between them (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md; data/animals/ranges.json).
# A place is worked out from position (a hash of its square and the world seed), never saved, so it is the same on every visit:
# a rabbit warren with its runs out to grazing, a deer range with its bed and feeding ground. The route between a place's spots is
# the trail the animals walk at the hours of their clock (server_animals.gd routine_trip) and the client draws as matted grass.
# Blocks are the trail blocks (256 m); a block is worked out when a player comes near, a little each tick, and dropped later.

const Codec := preload("res://src/shared/trail_codec.gd")

var cfg: Dictionary = {}
var world_seed: int = 0
var ground_height: Callable        # (x, z) -> height, NAN where the ground is not known yet
var blocked: Callable              # (x, z) -> bool: deep water
var biome_weight: Callable         # (species, x, z) -> 0..1, how well the species lives there
var ground_ready: Callable         # (x, z) -> bool, the ground tile there is loaded (asks for it when not); unset means always
var no_spawn: Callable             # (x, z) -> bool: settled ground (no_spawn_m round anything put down); its places are left
var blocks: Dictionary = {}        # Vector2i -> {"places": Array, "jobs": Array, "retry_ms": int, "seen_ms": int, "ver": int}
var _wire: Dictionary = {}         # Vector2i -> [msec built, bytes]


func setup() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/ranges.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func on() -> bool:
	return bool(cfg.get("on", false))


func block_of(x: float, z: float) -> Vector2i:
	var size: float = float(cfg.get("block_m", 256.0))
	return Vector2i(int(floor(x / size)), int(floor(z / size)))


# A fixed number 0..1 for a square and a salt: the same on every visit for one world seed.
func h01(a: int, b: int, salt: int) -> float:
	var x: int = (a * 73856093) ^ (b * 19349663) ^ (salt * 83492791) ^ (world_seed * 2654435761)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xFFFFFF) / 16777216.0


# Keeps the blocks round the players worked out: queues the 3 x 3 round each, works jobs within budget_ms, forgets the rest.
func tick(players: Array, now_ms: int) -> void:
	if not on() or not ground_height.is_valid():
		return

	for p in players:
		var centre: Vector2i = block_of(p.x, p.z)

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var key: Vector2i = centre + Vector2i(dx, dz)

				if not blocks.has(key):
					blocks[key] = {"places": [], "jobs": _jobs_for(key), "retry_ms": 0, "seen_ms": now_ms, "ver": 0}
				else:
					blocks[key]["seen_ms"] = now_ms

	var started: int = Time.get_ticks_usec()
	var budget: int = int(float(cfg.get("budget_ms", 0.6)) * 1000.0)

	for key in blocks.keys():
		var rec: Dictionary = blocks[key]

		if now_ms - int(rec["seen_ms"]) > int(float(cfg.get("forget_s", 600.0)) * 1000.0):
			blocks.erase(key)
			_wire.erase(key)
			continue

		if not (rec["jobs"] as Array).is_empty() and now_ms >= int(rec["retry_ms"]) and not _ground_loaded(key):
			rec["retry_ms"] = now_ms + 5000   # a ground tile it reaches is still loading: never read a cold tile on the server tick
			continue

		while not (rec["jobs"] as Array).is_empty() and now_ms >= int(rec["retry_ms"]) and Time.get_ticks_usec() - started < budget:
			var job: Array = rec["jobs"][0]
			var place: Variant = _warren(job[1], job[2]) if job[0] == "w" else _deer_range(key)

			if place == null:
				rec["retry_ms"] = now_ms + 5000   # the ground there is not known yet: try again shortly
				break

			rec["jobs"].pop_front()

			if not (place as Dictionary).is_empty():
				rec["places"].append(place)
				rec["ver"] = int(rec["ver"]) + 1


# Whether the ground under a block and the margin its routes may reach (runs, drift, the water detour) is loaded.
func _ground_loaded(key: Vector2i) -> bool:
	if not ground_ready.is_valid():
		return true

	var m: float = float(cfg.get("block_m", 256.0))
	var pad: float = 128.0
	var lo: Vector2 = Vector2(key) * m - Vector2(pad, pad)
	var hi: Vector2 = Vector2(key + Vector2i.ONE) * m + Vector2(pad, pad)
	var ok: bool = true

	for c in [lo, hi, Vector2(lo.x, hi.y), Vector2(hi.x, lo.y)]:
		ok = bool(ground_ready.call(c.x, c.y)) and ok   # every corner asked, so all the tiles start loading at once

	return ok


func is_ready(key: Vector2i) -> bool:
	return blocks.has(key) and (blocks[key]["jobs"] as Array).is_empty()


func _jobs_for(key: Vector2i) -> Array:
	var jobs: Array = []
	var wc: Dictionary = cfg.get("warren", {})
	var per: int = maxi(int(round(float(cfg.get("block_m", 256.0)) / float(wc.get("cell_m", 64.0)))), 1)

	if not wc.is_empty():
		for sz in per:
			for sx in per:
				jobs.append(["w", key.x * per + sx, key.y * per + sz])

	if cfg.has("deer"):
		jobs.append(["d"])

	return jobs


func _h(x: float, z: float) -> float:
	return float(ground_height.call(x, z))


func _wet(x: float, z: float) -> bool:
	return blocked.is_valid() and bool(blocked.call(x, z))


# The steepest rise over run_m across a spot (north-south or east-west), NAN where the ground is not known.
func slope_at(x: float, z: float) -> float:
	var r: float = float(cfg.get("slope_run_m", 3.0))
	var e: float = _h(x + r, z)
	var w: float = _h(x - r, z)
	var n: float = _h(x, z + r)
	var s: float = _h(x, z - r)

	if is_nan(e) or is_nan(w) or is_nan(n) or is_nan(s):
		return NAN

	return maxf(absf(e - w), absf(n - s)) / (2.0 * r)


func _weight(sp: String, x: float, z: float) -> float:
	return float(biome_weight.call(sp, x, z)) if biome_weight.is_valid() else 1.0


# A warren in square (sx, sz), {} for none, null when the ground is not known yet.
func _warren(sx: int, sz: int) -> Variant:
	var wc: Dictionary = cfg["warren"]
	var cell: float = float(wc.get("cell_m", 64.0))
	var sp: String = str(wc.get("species", "rabbit"))
	var at: Vector2 = Vector2((float(sx) + 0.125 + 0.75 * h01(sx, sz, 1)) * cell, (float(sz) + 0.125 + 0.75 * h01(sx, sz, 2)) * cell)

	if h01(sx, sz, 3) >= float(wc.get("chance", 0.45)) * _weight(sp, at.x, at.y):
		return {}

	var slope: float = slope_at(at.x, at.y)

	if is_nan(slope):
		return null

	if slope > float(wc.get("slope_max", 0.35)) or _wet(at.x, at.y) or _h(at.x, at.y) <= 0.0:
		return {}

	var span: Array = wc.get("runs", [2, 3])
	var count: int = int(span[0]) + int(floor(h01(sx, sz, 4) * float(int(span[1]) - int(span[0]) + 1)))
	var len_span: Array = wc.get("run_m", [15.0, 40.0])
	var outs: Array = []
	var routes: Array = []
	var turn: float = h01(sx, sz, 5) * TAU

	for i in count:
		var ang: float = turn + TAU * float(i) / float(count) + (h01(sx, sz, 10 + i) - 0.5) * 0.9
		var reach: float = lerpf(float(len_span[0]), float(len_span[1]), h01(sx, sz, 20 + i))
		var end: Vector2 = at + Vector2(cos(ang), sin(ang)) * reach
		var end_slope: float = slope_at(end.x, end.y)

		if is_nan(end_slope):
			return null

		if end_slope > float(wc.get("slope_max", 0.35)) or _wet(end.x, end.y) or _weight(sp, end.x, end.y) <= 0.0:
			continue   # that way leads onto ground rabbits do not graze: no run there

		var route: Variant = lay_route(at, end, sx * 31 + sz * 17 + i)

		if route == null:
			return null

		if (route as PackedVector2Array).is_empty():
			continue

		outs.append(end)
		routes.append(route)

	if routes.is_empty():
		return {}

	return {"id": "w:%d,%d" % [sx, sz], "sp": sp, "kind": int(wc.get("kind", 0)), "home": at, "outs": outs, "routes": routes}


# The deer range of a trail block: a bed on sheltered side ground and a feeding ground on flat open ground apart_m from it.
func _deer_range(key: Vector2i) -> Variant:
	var dc: Dictionary = cfg["deer"]
	var size: float = float(cfg.get("block_m", 256.0))
	var inset: float = float(dc.get("inset_m", 24.0))
	var sp: String = str(dc.get("species", "deer"))
	var spots: Array = []

	for k in int(dc.get("tries", 8)):
		var at: Vector2 = Vector2((float(key.x) * size) + inset + (size - 2.0 * inset) * h01(key.x, key.y, 100 + k), (float(key.y) * size) + inset + (size - 2.0 * inset) * h01(key.x, key.y, 200 + k))
		var slope: float = slope_at(at.x, at.y)

		if is_nan(slope):
			return null

		if _wet(at.x, at.y) or _h(at.x, at.y) <= 0.0 or _weight(sp, at.x, at.y) <= 0.0:
			continue

		spots.append([at, slope])

	var bed_span: Array = dc.get("bed_slope", [0.06, 0.45])
	var best_bed: int = -1
	var best_score: float = INF

	for i in spots.size():
		var s: float = float(spots[i][1])

		if s >= float(bed_span[0]) and s <= float(bed_span[1]) and absf(s - float(dc.get("bed_best", 0.2))) < best_score:
			best_score = absf(s - float(dc.get("bed_best", 0.2)))
			best_bed = i

	if best_bed < 0:
		return {}

	var bed: Vector2 = spots[best_bed][0]
	var apart: Array = dc.get("apart_m", [80.0, 200.0])
	var feed: Vector2 = Vector2.INF
	var flattest: float = float(dc.get("feed_slope_max", 0.15))

	for i in spots.size():
		var d: float = (spots[i][0] as Vector2).distance_to(bed)

		if i != best_bed and d >= float(apart[0]) and d <= float(apart[1]) and float(spots[i][1]) <= flattest:
			flattest = float(spots[i][1])
			feed = spots[i][0]

	if feed == Vector2.INF:
		return {}

	var route: Variant = lay_route(bed, feed, key.x * 977 + key.y * 131)

	if route == null:
		return null

	if (route as PackedVector2Array).is_empty():
		return {}

	return {"id": "d:%d,%d" % [key.x, key.y], "sp": sp, "kind": int(dc.get("kind", 1)), "home": bed, "outs": [feed], "routes": [route]}


# The trail from a to b (empty when no way round deep water was found, null when the ground is not known yet). Where deep water lies on
# the straight line, the trail goes by a dry point to one side of the middle (20, 40 or 60 m out), as game trails go round a pond.
func lay_route(a: Vector2, b: Vector2, salt: int) -> Variant:
	if not _line_wet(a, b):
		return _lay_leg(a, b, salt)

	var across: Vector2 = (b - a).normalized().orthogonal()
	var mid: Vector2 = (a + b) * 0.5

	for k in [20.0, -20.0, 40.0, -40.0, 60.0, -60.0]:
		var by: Vector2 = mid + across * k

		if _wet(by.x, by.y) or _line_wet(a, by) or _line_wet(by, b):
			continue

		var first: Variant = _lay_leg(a, by, salt)
		var second: Variant = _lay_leg(by, b, salt + 1)

		if first == null or second == null:
			return null

		if (first as PackedVector2Array).is_empty() or (second as PackedVector2Array).is_empty():
			continue

		var whole: PackedVector2Array = first
		whole.append_array((second as PackedVector2Array).slice(1))
		return whole

	return PackedVector2Array()


func _line_wet(a: Vector2, b: Vector2) -> bool:
	var n: int = maxi(int(a.distance_to(b) / 6.0), 1)

	for k in n + 1:
		var p: Vector2 = a.lerp(b, float(k) / float(n))

		if _wet(p.x, p.y):
			return true

	return false


# One leg of a trail: a point every step_m, each the gentlest climb of a few sideways moves from the last (so it can drift up to
# max_side_m off the straight line round a hill, and comes back by the end), never on deep water, then a small sideways wiggle.
func _lay_leg(a: Vector2, b: Vector2, salt: int) -> Variant:
	var rc: Dictionary = cfg.get("route", {})
	var dist: float = a.distance_to(b)
	var steps: int = maxi(int(round(dist / float(rc.get("step_m", 12.0)))), 1)
	var across: Vector2 = (b - a).normalized().orthogonal()
	var side: float = float(rc.get("side_m", 3.0))
	var max_side: float = float(rc.get("max_side_m", 30.0))
	var kept: PackedVector2Array = PackedVector2Array([a])
	var prev: Vector2 = a
	var prev_h: float = _h(a.x, a.y)
	var off: float = 0.0   # how far the trail has drifted to one side of the straight line (it must come back by the end)

	if is_nan(prev_h):
		return null

	for i in range(1, steps):
		var cap: float = minf(max_side, float(steps - i) * side * 2.0)
		var base: Vector2 = a.lerp(b, float(i) / float(steps))
		var best: Vector2 = Vector2.INF
		var best_cost: float = INF
		var best_h: float = 0.0
		var best_off: float = 0.0

		for o in [0, -1, 1, -2, 2, -4, 4]:
			var try_off: float = clampf(off + float(o) * side, -cap, cap)
			var at: Vector2 = base + across * try_off
			var hh: float = _h(at.x, at.y)

			if is_nan(hh):
				return null

			if _wet(at.x, at.y):
				continue

			var cost: float = absf(hh - prev_h) / maxf(at.distance_to(prev), 0.5) * float(rc.get("climb_w", 4.0)) + absf(try_off) * float(rc.get("side_w", 0.04))

			if cost < best_cost:
				best_cost = cost
				best = at
				best_h = hh
				best_off = try_off

		if best == Vector2.INF:
			return PackedVector2Array()   # deep water all the way across: no trail this way

		kept.append(best)
		prev = best
		prev_h = best_h
		off = best_off

	kept.append(b)
	return _wiggle(kept, salt, rc)


func _wiggle(pts: PackedVector2Array, salt: int, rc: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([pts[0]])
	var step: float = float(rc.get("wiggle_step_m", 4.0))
	var amp: float = float(rc.get("wiggle_m", 0.6))
	var phase: float = h01(salt, 7, 300) * TAU
	var along: float = 0.0

	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg: float = a.distance_to(b)
		var n: int = maxi(int(round(seg / step)), 1)
		var across: Vector2 = (b - a).normalized().orthogonal()

		for k in range(1, n + 1):
			var t: float = float(k) / float(n)
			along += seg / float(n)
			var p: Vector2 = a.lerp(b, t)

			if not (i == pts.size() - 1 and k == n):
				p += across * amp * sin(along * 0.35 + phase)   # the far end stays on its spot

			out.append(p)

	return out


# Places of a species within reach of a point, in ready blocks only (the nearest first), not on settled ground.
func places_near(sp: String, at: Vector3, reach: float) -> Array:
	var found: Array = []
	var size: float = float(cfg.get("block_m", 256.0))
	var span: int = int(ceil(reach / size))
	var centre: Vector2i = block_of(at.x, at.z)

	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var key: Vector2i = centre + Vector2i(dx, dz)

			if not is_ready(key):
				continue

			for place in blocks[key]["places"]:
				var d: float = (place["home"] as Vector2).distance_to(Vector2(at.x, at.z))

				if str(place["sp"]) == sp and d <= reach and not settled(place):
					found.append([d, place])

	found.sort_custom(func(l, r): return l[0] < r[0])
	return found.map(func(f): return f[1])


# Settled: a player has put something down within no_spawn_m of the place's home or any out spot; the animals leave it.
func settled(place: Dictionary) -> bool:
	if not no_spawn.is_valid():
		return false

	if bool(no_spawn.call(place["home"].x, place["home"].y)):
		return true

	for out in place["outs"]:
		if bool(no_spawn.call(out.x, out.y)):
			return true

	return false


# The routes of a block for the wire (trail_codec encode_routes), rebuilt at most every 10 s (settled ground changes rarely).
func wire(key: Vector2i, now_ms: int) -> PackedByteArray:
	if not is_ready(key):
		return PackedByteArray()

	var rec: Array = _wire.get(key, [])

	if not rec.is_empty() and now_ms - int(rec[0]) < 10000:
		return rec[1]

	var routes: Array = []

	for place in blocks[key]["places"]:
		if settled(place):
			continue

		for route in place["routes"]:
			routes.append([int(place["kind"]), route])

	var bytes: PackedByteArray = Codec.encode_routes(routes, key, float(cfg.get("block_m", 256.0)))
	_wire[key] = [now_ms, bytes]
	return bytes


# The distance from a point to the nearest trail of a kind (-1 any) that is not on settled ground: INF while the block round the point is
# not worked out, `reach` when no trail is nearer. Each route keeps a bounding box, so only the routes that pass near are measured.
func route_distance(x: float, z: float, kind: int = -1, reach: float = 10.0) -> float:
	var p: Vector2 = Vector2(x, z)
	var centre: Vector2i = block_of(x, z)

	if not is_ready(centre):
		return INF

	var best: float = reach

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key: Vector2i = centre + Vector2i(dx, dz)

			if not is_ready(key):
				continue

			for place in blocks[key]["places"]:
				if kind >= 0 and int(place["kind"]) != kind:
					continue

				var boxes: Array = _boxes(place)
				var near: Array = []

				for n in boxes.size():
					if (boxes[n] as Rect2).grow(best).has_point(p):
						near.append(n)

				if near.is_empty() or settled(place):
					continue

				for n in near:
					var pts: PackedVector2Array = place["routes"][n]

					for i in range(1, pts.size()):
						best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])))

	return best


# The bounding box of each of a place's routes, worked out once and kept on the place.
func _boxes(place: Dictionary) -> Array:
	if not place.has("boxes"):
		var boxes: Array = []

		for route in place["routes"]:
			var pts: PackedVector2Array = route
			var box: Rect2 = Rect2(pts[0], Vector2.ZERO) if not pts.is_empty() else Rect2()

			for q in pts:
				box = box.expand(q)

			boxes.append(box)

		place["boxes"] = boxes

	return place["boxes"]
