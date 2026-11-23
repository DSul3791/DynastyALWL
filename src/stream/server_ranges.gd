extends RefCounted

# Animal places and the game trails between them (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md; data/animals/ranges.json).
# A place is worked out from position (a hash of its square and the world seed), never saved, so it is the same on every visit:
# a rabbit warren with its runs out to grazing, a deer range with its bed and feeding ground. The route between a place's spots is
# the trail the animals walk at the hours of their clock (server_animals.gd routine_trip) and the client draws as matted grass.
# Blocks are the trail blocks (256 m); a block is worked out when a player comes near, a little each tick, and dropped later.

const Codec := preload("res://src/shared/trail_codec.gd")

var cfg: Dictionary = {}
const DEST_OUT_M := 90.0           # how far past its block's side a trail may end (a warren's grazing ground or neighbour, a deer's water)
const REACH_OUT_M := 150.0         # how far a block's trails may run past its side: DEST_OUT_M and a water detour (60 m) or drift (30 m).
# Kept under 256 - 80 m: the client lays the trails round the player (grass_view 80 m, trail_signs 70 m) from the 3 x 3 blocks the server
# sends, so a trail from a block farther off never reaches into what the player sees.

var world_seed: int = 0
var ground_height: Callable        # (x, z) -> height, NAN where the ground is not known yet
var blocked: Callable              # (x, z) -> bool: deep water
var biome_weight: Callable         # (species, x, z) -> 0..1, how well the species lives there
var ground_ready: Callable         # (x, z) -> bool, the ground tile there is loaded (asks for it when not); unset means always
var no_spawn: Callable             # (x, z) -> bool: settled ground (no_spawn_m round anything put down); its places are left
var blocks: Dictionary = {}        # Vector2i -> {"places": Array, "jobs": Array, "retry_ms": int, "seen_ms": int, "ver": int}
var _wire: Dictionary = {}         # Vector2i -> [msec built, bytes]
var hold_until_ms: int = 0         # no work before this (msec): set when a player joins (hold_for_join), so a cold join's own ground comes first
var _held_at_ms: int = -1000000000
# A job past the tick's budget stops at its next ground read and runs again next tick; the reads it made are kept with its block
# (rec "memo"), so each run gets further and the place comes out as if worked in one go (the generated ground never changes; deep water
# is live, so a job spread over seconds may see a pool's edge move, as one started a moment later would).
var fresh_reads_min: int = 4       # new ground reads a job may always make in a tick, so it never stalls (cfg fresh_reads_min)
var _memo: Dictionary = {}         # [what, x, z] -> value: the block's reads for the job being worked (rec "memo" while tick() runs it)
var _deadline_us: int = 0          # 0 outside tick(): reads never stop and are not kept
var _fresh: int = 0
var _out_of_time: bool = false


func setup() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/ranges.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	fresh_reads_min = maxi(int(cfg.get("fresh_reads_min", 4)), 1)


# A player has joined: hold the work for hold_after_join_s, at most once in three times that (so joins in a row cannot hold it for good).
func hold_for_join(now_ms: int) -> void:
	var hold_ms: int = int(float(cfg.get("hold_after_join_s", 0.0)) * 1000.0)

	if hold_ms > 0 and now_ms - _held_at_ms >= hold_ms * 3:
		_held_at_ms = now_ms
		hold_until_ms = now_ms + hold_ms


func on() -> bool:
	return bool(cfg.get("on", false))


func block_of(x: float, z: float) -> Vector2i:
	var size: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
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

	if now_ms < hold_until_ms:
		return   # a player has just joined: its ground first (this work's own tile loads and reads would share the CPU with the join)

	var started: int = Time.get_ticks_usec()
	var budget: int = int(float(cfg.get("budget_ms", 0.6)) * 1000.0)
	var out_of_time: bool = false
	var ran: bool = false

	for key in blocks.keys():
		if out_of_time:
			break

		var rec: Dictionary = blocks[key]

		if now_ms - int(rec["seen_ms"]) > int(float(cfg.get("forget_s", 600.0)) * 1000.0):
			blocks.erase(key)
			_wire.erase(key)
			continue

		if not (rec["jobs"] as Array).is_empty() and now_ms >= int(rec["retry_ms"]) and not _ground_loaded(key):
			rec["retry_ms"] = now_ms + 5000   # a ground tile it reaches is still loading: never read a cold tile on the server tick
			_note_wait(key, rec, "ground tiles loading")
			continue

		var had_jobs: bool = not (rec["jobs"] as Array).is_empty()

		while not (rec["jobs"] as Array).is_empty() and now_ms >= int(rec["retry_ms"]) and (not ran or Time.get_ticks_usec() - started < budget):
			ran = true   # one job a tick at least, so a slow machine still gets on
			var job: Array = rec["jobs"][0]
			var job_us: int = Time.get_ticks_usec()
			var place: Variant = null

			if rec.get("memo_job", []) != job:
				rec["memo"] = {}
				rec["memo_job"] = job

			_memo = rec["memo"]
			_deadline_us = started + budget
			_fresh = 0
			_out_of_time = false

			match str(job[0]):
				"w":
					place = _warren(job[1], job[2])
				"f":
					place = _fox_earth(key, rec, int(job[1]))
				_:
					place = _deer_range(key, str(job[1]) if job.size() > 1 else "deer")

			_deadline_us = 0
			_memo = {}   # the reads stay with the block (rec "memo") until its job is done
			var spent: int = Time.get_ticks_usec() - job_us
			rec["job_us"] = int(rec.get("job_us", 0)) + spent
			rec["job_max_us"] = maxi(int(rec.get("job_max_us", 0)), spent)   # the longest single run (one tick's share of a job)

			if _out_of_time:
				out_of_time = true
				break   # the budget ran out inside the job: it goes on next tick from the reads it made

			rec.erase("memo")
			rec.erase("memo_job")
			_memo = {}

			if place == null:
				rec["retry_ms"] = now_ms + 5000   # the ground there is not known yet: try again shortly
				_note_wait(key, rec, "ground height unknown at a %s job" % str(job[0]))
				break

			rec["jobs"].pop_front()

			if not (place as Dictionary).is_empty():
				rec["places"].append(place)
				rec["ver"] = int(rec["ver"]) + 1

		if had_jobs and (rec["jobs"] as Array).is_empty():
			_log_ready(key, rec)


# Counts a block's waits and logs the first and every 12th (about a minute), so a block that never gets worked out shows in the log.
func _note_wait(key: Vector2i, rec: Dictionary, why: String) -> void:
	rec["waits"] = int(rec.get("waits", 0)) + 1

	if int(rec["waits"]) == 1 or int(rec["waits"]) % 12 == 0:
		print("ranges: block %d,%d waiting (%s), %d waits, %d jobs left" % [key.x, key.y, why, int(rec["waits"]), (rec["jobs"] as Array).size()])


# One log line when a block is worked out (so a lane can see trails exist and where): its places, routes and each place's home spot.
func _log_ready(key: Vector2i, rec: Dictionary) -> void:
	var homes: PackedStringArray = PackedStringArray()
	var routes: int = 0

	for place in rec["places"]:
		routes += trails_of(place).size()
		homes.append("%s %s %.0f,%.0f%s" % [str(place["id"]), str(place["sp"]), place["home"].x, place["home"].y, " settled" if settled(place) else ""])

	print("ranges: block %d,%d worked out (%d ground waits, jobs %.1f ms, slowest %.1f ms): %d places, %d routes: %s" % [key.x, key.y, int(rec.get("waits", 0)),
		float(rec.get("job_us", 0)) / 1000.0, float(rec.get("job_max_us", 0)) / 1000.0, (rec["places"] as Array).size(), routes, ", ".join(homes)])


# Whether the ground under a block and the margin its routes may reach (runs, drift, the water detour) is loaded.
func _ground_loaded(key: Vector2i) -> bool:
	if not ground_ready.is_valid():
		return true

	var m: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
	var pad: float = REACH_OUT_M + 16.0
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
	var per: int = maxi(int(round(float(cfg.get("block_m", Codec.ROUTE_BLOCK_M)) / float(wc.get("cell_m", 64.0)))), 1)

	if not wc.is_empty():
		for sz in per:
			for sx in per:
				jobs.append(["w", key.x * per + sx, key.y * per + sz])

	for name in cfg.get("ranges", ["deer"]):
		if cfg.has(str(name)):
			jobs.append(["d", str(name)])   # a bed and feeding ground of each kind of deer (deer, moose, elk) that lives in the block

	if cfg.has("fox"):
		for n in maxi(int((cfg["fox"] as Dictionary).get("rounds", 3)), 1):
			jobs.append(["f", n])   # last: a fox earth goes by the block's warrens, worked out by then; one round a job (each lays several legs)

	return jobs


# Whether a job may make a new read now; false once the tick's budget is spent (after fresh_reads_min), which stops the job.
func _may_read() -> bool:
	if _out_of_time:
		return false

	if _deadline_us > 0 and _fresh >= fresh_reads_min and Time.get_ticks_usec() > _deadline_us:
		_out_of_time = true
		return false

	_fresh += 1
	return true


func _h(x: float, z: float) -> float:
	var k: Array = [0, x, z]

	if _memo.has(k):
		return float(_memo[k])

	if not _may_read():
		return NAN   # stops the job (tick() runs it again next tick)

	var v: float = float(ground_height.call(x, z))

	if not is_nan(v) and _deadline_us > 0:
		_memo[k] = v

	return v


func _wet(x: float, z: float) -> bool:
	if not blocked.is_valid():
		return false

	var k: Array = [1, x, z]

	if _memo.has(k):
		return bool(_memo[k])

	if not _may_read():
		return true   # any answer: the job's result is thrown away and it runs again

	var v: bool = bool(blocked.call(x, z))

	if _deadline_us > 0:
		_memo[k] = v

	return v


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
	if not biome_weight.is_valid():
		return 1.0

	var k: Array = [sp, x, z]

	if _memo.has(k):
		return float(_memo[k])

	if not _may_read():
		return 0.0   # as _wet

	var v: float = float(biome_weight.call(sp, x, z))

	if _deadline_us > 0:
		_memo[k] = v

	return v


# A warren in square (sx, sz), {} for none, null when the ground is not known yet. Its trails have no set length (Dave 23 Nov 2026,
# "they should just exist wherever they exist"): they run to real places within forage_m, as long as the walk there happens to be.
# Runs out to its grazing grounds: the best grassland spots of the squares round it (the most rabbit-friendly ground, flat and dry, a
# spot in each square, never its own square, which the warren grazes short), graze_apart_deg apart so they fan out. And runs to the
# neighbouring warrens it joins (a pair joins in join_share, the same roll from either end; the one whose block may hold it lays it).
# Rabbits graze up to about 200 m from the warren (Agriculture Victoria; NSW DPI). Walked: the grazing runs (routes); drawn only: the joins.
func _warren(sx: int, sz: int) -> Variant:
	var wc: Dictionary = cfg["warren"]
	var cell: float = float(wc.get("cell_m", 64.0))
	var sp: String = str(wc.get("species", "rabbit"))
	var at: Vector2 = _warren_spot(sx, sz)

	if h01(sx, sz, 3) >= float(wc.get("chance", 0.45)) * _weight(sp, at.x, at.y):
		return {}

	var slope: float = slope_at(at.x, at.y)

	if is_nan(slope):
		return null

	if slope > float(wc.get("slope_max", 0.35)) or _wet(at.x, at.y) or _h(at.x, at.y) <= 0.0:
		return {}

	var forage: float = float(wc.get("forage_m", 200.0))
	var box: Rect2 = _dest_box(at)
	var span: int = int(ceil(forage / cell))
	var cands: Array = []   # [weight, tie, spot]

	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if dx == 0 and dz == 0:
				continue

			var gx: int = sx + dx
			var gz: int = sz + dz
			var spot: Vector2 = Vector2((float(gx) + 0.5 + 0.8 * (h01(gx, gz, 6) - 0.5)) * cell, (float(gz) + 0.5 + 0.8 * (h01(gx, gz, 7) - 0.5)) * cell)

			if spot.distance_to(at) > forage or not box.has_point(spot):
				continue

			var w: float = _weight(sp, spot.x, spot.y)

			if w <= 0.0 or _wet(spot.x, spot.y) or _h(spot.x, spot.y) <= 0.0:
				continue

			cands.append([w, h01(gx, gz, 8), spot])

	if _out_of_time:
		return null

	cands.sort_custom(func(l, r): return l[0] > r[0] or (l[0] == r[0] and l[1] > r[1]))   # the best grassland first, then by the spot's own roll
	var gspan: Array = wc.get("graze_runs", [2, 3])
	var want: int = int(gspan[0]) + int(floor(h01(sx, sz, 4) * float(int(gspan[1]) - int(gspan[0]) + 1)))
	var apart: float = deg_to_rad(float(wc.get("graze_apart_deg", 70.0)))
	var outs: Array = []
	var routes: Array = []
	var links: Array = []
	var n: int = 0

	for c in cands:
		if outs.size() >= want:
			break

		var spot: Vector2 = c[2]
		var ang: float = (spot - at).angle()
		var clear: bool = true

		for o in outs:
			clear = clear and absf(angle_difference(ang, ((o as Vector2) - at).angle())) >= apart

		if not clear:
			continue

		var gs: float = slope_at(spot.x, spot.y)

		if is_nan(gs):
			return null

		if gs > float(wc.get("graze_slope_max", 0.25)):
			continue   # rabbits graze open, gentle ground

		var route: Variant = lay_route(at, spot, sx * 31 + sz * 17 + n)
		n += 1

		if route == null:
			return null

		if (route as PackedVector2Array).is_empty():
			continue

		outs.append(spot)
		routes.append(route)

	# Joins to neighbouring warrens.
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var nx: int = sx + dx
			var nz: int = sz + dz

			if (dx == 0 and dz == 0) or _pair_roll(sx, sz, nx, nz) >= float(wc.get("join_share", 0.15)):
				continue

			var other: Vector2 = _warren_spot(nx, nz)

			if other.distance_to(at) > forage or not _lays_join(sx, sz, at, nx, nz, other):
				continue

			var there: Variant = _warren_at(nx, nz)

			if there == null:
				return null

			if not bool(there):
				continue

			var link: Variant = lay_route(at, other, sx * 37 + sz * 23 + nx * 5 + nz * 3)

			if link == null:
				return null

			if not (link as PackedVector2Array).is_empty():
				links.append(link)

	if _out_of_time:
		return null

	if routes.is_empty():
		return {}

	return {"id": "w:%d,%d" % [sx, sz], "sp": sp, "kind": int(wc.get("kind", 0)), "home": at, "outs": outs, "routes": routes, "links": links}


# Where square (sx, sz)'s warren would be (worked out from the square alone).
func _warren_spot(sx: int, sz: int) -> Vector2:
	var cell: float = float((cfg["warren"] as Dictionary).get("cell_m", 64.0))
	return Vector2((float(sx) + 0.125 + 0.75 * h01(sx, sz, 1)) * cell, (float(sz) + 0.125 + 0.75 * h01(sx, sz, 2)) * cell)


# Whether square (sx, sz) has a warren (its spot's roll and ground), null when the ground is not known yet.
func _warren_at(sx: int, sz: int) -> Variant:
	var wc: Dictionary = cfg["warren"]
	var at: Vector2 = _warren_spot(sx, sz)

	if h01(sx, sz, 3) >= float(wc.get("chance", 0.45)) * _weight(str(wc.get("species", "rabbit")), at.x, at.y):
		return false

	var slope: float = slope_at(at.x, at.y)

	if is_nan(slope):
		return null

	return not (slope > float(wc.get("slope_max", 0.35)) or _wet(at.x, at.y) or _h(at.x, at.y) <= 0.0)


# The same roll for a pair of squares from either end.
func _pair_roll(ax: int, az: int, bx: int, bz: int) -> float:
	var first: bool = ax < bx or (ax == bx and az < bz)
	return h01((ax if first else bx) * 7919 + (az if first else bz), (bx if first else ax) * 7919 + (bz if first else az), 9)


# Which end lays a join between two warrens (so it is never laid twice): the lower square when the other lies within its block's reach
# (DEST_OUT_M), else the higher one when the lower lies within its own. A pair lying too far either side of a block side for either is
# left unjoined (the spill bound, REACH_OUT_M, comes first): a few joins fewer, accepted.
func _lays_join(sx: int, sz: int, at: Vector2, nx: int, nz: int, other: Vector2) -> bool:
	var lower: bool = sx < nx or (sx == nx and sz < nz)
	var mine: bool = _dest_box(at).has_point(other)
	var theirs: bool = _dest_box(other).has_point(at)
	return mine if lower else (theirs == false and mine)


# Where a trail from a spot may end: its trail block grown by DEST_OUT_M.
func _dest_box(at: Vector2) -> Rect2:
	var size: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
	var key: Vector2i = block_of(at.x, at.y)
	return Rect2(Vector2(key) * size, Vector2(size, size)).grow(DEST_OUT_M)


# The deer range of a trail block: a bed on sheltered side ground and a feeding ground on flat open ground apart_m from it.
func _deer_range(key: Vector2i, name: String = "deer") -> Variant:
	var dc: Dictionary = cfg[name]
	var size: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
	var inset: float = float(dc.get("inset_m", 24.0))
	var sp: String = str(dc.get("species", name))
	var salt: int = int(dc.get("salt", 100))   # each kind its own spots (deer 100 and 200, as in stage 1)
	var spots: Array = []

	for k in int(dc.get("tries", 8)):
		var at: Vector2 = Vector2((float(key.x) * size) + inset + (size - 2.0 * inset) * h01(key.x, key.y, salt + k), (float(key.y) * size) + inset + (size - 2.0 * inset) * h01(key.x, key.y, salt + 100 + k))
		var slope: float = slope_at(at.x, at.y)

		if is_nan(slope):
			return null

		var weight: float = _weight(sp, at.x, at.y)

		if _wet(at.x, at.y) or _h(at.x, at.y) <= 0.0 or weight <= 0.0:
			continue

		if bool(dc.get("weight_roll", false)) and h01(key.x, key.y, salt + 200 + k) >= weight:
			continue   # moose and elk: a spot in a biome they like less (weight under 1) is taken less often, as the old random spawn rolled

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
	var patch: float = float(dc.get("patch_m", 40.0))
	var feed: Vector2 = Vector2.INF
	var flattest: float = float(dc.get("feed_slope_max", 0.15))
	var wet_m: float = float(dc.get("feed_wet_m", 0.0))
	var by_water: bool = false

	for i in spots.size():   # no set distance (Dave 23 Nov 2026): the best feeding ground of the block, wherever it lies, not the bed's own patch
		var d: float = (spots[i][0] as Vector2).distance_to(bed)

		if i == best_bed or d < patch or float(spots[i][1]) > float(dc.get("feed_slope_max", 0.15)):
			continue

		var wet: bool = wet_m > 0.0 and _water_near(spots[i][0], wet_m)

		if (wet and not by_water) or (wet == by_water and float(spots[i][1]) <= flattest):   # moose: a spot by water first, then the flattest
			by_water = wet
			flattest = float(spots[i][1])
			feed = spots[i][0]

	if feed == Vector2.INF:
		return {}

	var route: Variant = lay_route(bed, feed, key.x * 977 + key.y * 131 + salt - 100)

	if route == null:
		return null

	if (route as PackedVector2Array).is_empty():
		return {}

	# And on from the feeding ground to the nearest fresh water within water_m, where deer go to drink at dawn and dusk (drawn only:
	# the drink itself is server_animals' drink trip).
	var links: Array = []
	var water: Variant = _water_edge(feed, float(dc.get("water_m", 0.0)))

	if water == null:
		return null

	if water is Vector2 and (water as Vector2).distance_to(feed) > float(dc.get("near_water_m", 10.0)):
		var leg: Variant = lay_route(feed, water, key.x * 571 + key.y * 293 + salt)

		if leg == null:
			return null

		if not (leg as PackedVector2Array).is_empty():
			links.append(leg)

	if _out_of_time:
		return null

	return {"id": "%s:%d,%d" % [str(dc.get("tag", "d")), key.x, key.y], "sp": sp, "kind": int(dc.get("kind", 1)), "home": bed, "outs": [feed], "routes": [route], "links": links}


# The dry edge of the nearest fresh water within m of a spot (deep water over ground above the sea), in sixteen directions every
# 20 m out, false for none (or m 0), null when the ground is not known yet. Kept within the spot's block reach (DEST_OUT_M).
func _water_edge(from: Vector2, m: float) -> Variant:
	if m <= 0.0:
		return false

	var box: Rect2 = _dest_box(from)
	var r: float = 20.0

	while r <= m:
		for k in 16:
			var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 16.0)
			var p: Vector2 = from + dir * r

			if not box.has_point(p) or not _wet(p.x, p.y):
				continue

			var floor_h: float = _h(p.x, p.y)

			if is_nan(floor_h):
				return null

			if floor_h <= 0.0:
				continue   # the sea: not a drink

			var edge: Vector2 = p

			for b in 6:   # back to dry ground, a few metres at a time
				edge -= dir * 4.0

				if not _wet(edge.x, edge.y):
					return edge

		r += 20.0

	return false


# The fox earth of a trail block (stage 2b, TR-9): {} for none, null when the ground is not known yet. A fox dens in a bank where there
# is one (the spot nearest earth_best slope), within reach_m of at least visits[0] of the block's warrens; it keeps no trail of its own. Its routes are its rounds:
# from the earth by way of 2 to 4 of those warrens, nearest first, so it hunts along the rabbits' ground. It walks a different round each
# night (server_animals routine_trip), as a real fox's route is only loosely tied to the night before (Oxford radio-tracking). Rounds
# are never drawn as trails nor count as runs for snares ("drawn": false). This finds the earth (job "f" 0); _fox_earth lays the rounds.
func _fox_spot(key: Vector2i, places: Array) -> Variant:
	var fc: Dictionary = cfg["fox"]
	var size: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
	var inset: float = float(fc.get("inset_m", 24.0))
	var sp: String = str(fc.get("species", "fox"))
	var salt: int = int(fc.get("salt", 900))
	var warrens: Array = []

	for place in places:
		if str(place["sp"]) == str((cfg.get("warren", {}) as Dictionary).get("species", "rabbit")):
			warrens.append(place["home"])

	var span: Array = fc.get("visits", [2, 4])

	if warrens.size() < int(span[0]):
		return {}

	var middle: Vector2 = (Vector2(key) + Vector2(0.5, 0.5)) * size

	if h01(key.x, key.y, salt + 200) >= float(fc.get("chance", 0.5)) * _weight(sp, middle.x, middle.y):
		return {}   # an earth in about chance of the blocks where foxes live (a fox's nightly range is about 18 ha, a block 6.5 ha)

	var reach: float = float(fc.get("reach_m", 200.0))
	var best: Vector2 = Vector2.INF
	var best_score: float = INF
	var best_near: Array = []

	for k in int(fc.get("tries", 8)):
		var at: Vector2 = Vector2((float(key.x) * size) + inset + (size - 2.0 * inset) * h01(key.x, key.y, salt + k), (float(key.y) * size) + inset + (size - 2.0 * inset) * h01(key.x, key.y, salt + 100 + k))
		var slope: float = slope_at(at.x, at.y)

		if is_nan(slope):
			return null

		if slope > float(fc.get("earth_slope_max", 0.6)) or _wet(at.x, at.y) or _h(at.x, at.y) <= 0.0 or _weight(sp, at.x, at.y) <= 0.0:
			continue

		var near: Array = []

		for w in warrens:
			if (w as Vector2).distance_to(at) <= reach:
				near.append(w)

		var score: float = absf(slope - float(fc.get("earth_best", 0.25)))   # dug into a bank where there is one, else where it can

		if near.size() >= int(span[0]) and score < best_score:
			best = at
			best_score = score
			best_near = near

	if best == Vector2.INF:
		return {}

	return {"home": best, "near": best_near, "routes": [], "outs": []}


# One round of a block's fox earth (job "f" n): job 0 finds the earth first. The place goes in with the last round; null while the ground is not known.
func _fox_earth(key: Vector2i, rec: Dictionary, n: int) -> Variant:
	var fc: Dictionary = cfg["fox"]
	var salt: int = int(fc.get("salt", 900))
	var span: Array = fc.get("visits", [2, 4])

	if n == 0:
		var spot: Variant = _fox_spot(key, rec["places"])

		if spot == null or _out_of_time:
			return null   # not known yet, or stopped for the tick: nothing kept

		rec["fox"] = spot

	var earth: Dictionary = rec.get("fox", {})

	if earth.is_empty():
		return {}

	var best: Vector2 = earth["home"]
	var best_near: Array = earth["near"]
	var rounds: Array = earth["routes"]
	var ends: Array = earth["outs"]

	var want: int = mini(int(span[0]) + int(floor(h01(key.x, key.y, salt + 300 + n) * float(int(span[1]) - int(span[0]) + 1))), best_near.size())
	var pool: Array = best_near.duplicate()
	var start: int = int(floor(h01(key.x, key.y, salt + 400 + n) * float(pool.size())))
	var stops: Array = [pool[start]]
	pool.remove_at(start)

	while stops.size() < want:   # on to the nearest warren not yet visited
		var last: Vector2 = stops[stops.size() - 1]
		var pick: int = 0

		for i in pool.size():
			if last.distance_squared_to(pool[i]) < last.distance_squared_to(pool[pick]):
				pick = i

		stops.append(pool[pick])
		pool.remove_at(pick)

	var trip: PackedVector2Array = PackedVector2Array([best])
	var leg_from: Vector2 = best

	for i in stops.size():
		var leg: Variant = lay_route(leg_from, stops[i], key.x * 613 + key.y * 389 + salt + n * 7 + i)

		if leg == null:
			return null

		var pts: PackedVector2Array = leg

		if pts.is_empty():
			continue   # no way round water to that warren: the round skips it

		trip.append_array(pts.slice(1))
		leg_from = stops[i]

	if _out_of_time:
		return null   # stopped for the tick: the round is laid again from the kept reads next tick, so nothing is added twice

	if trip.size() > 1:
		rounds.append(trip)
		ends.append(trip[trip.size() - 1])

	if n < maxi(int(fc.get("rounds", 3)), 1) - 1:
		return {}   # more rounds to come

	rec.erase("fox")

	if rounds.is_empty():
		return {}   # no round could be laid

	return {"id": "%s:%d,%d" % [str(fc.get("tag", "f")), key.x, key.y], "sp": str(fc.get("species", "fox")), "kind": -1, "drawn": false, "home": best, "outs": ends, "routes": rounds}


# Deep water within m of a spot, in eight directions at half and full distance (a moose feeds at the water's edge).
func _water_near(at: Vector2, m: float) -> bool:
	for k in 8:
		var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 8.0)

		if _wet(at.x + dir.x * m * 0.5, at.y + dir.y * m * 0.5) or _wet(at.x + dir.x * m, at.y + dir.y * m):
			return true

	return false


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
	var size: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
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
		if settled(place) or not bool(place.get("drawn", true)):
			continue   # settled ground, or a fox's rounds (no trail of its own)

		for route in trails_of(place):
			routes.append([int(place["kind"]), route])

	var bytes: PackedByteArray = Codec.encode_routes(routes, key, float(cfg.get("block_m", Codec.ROUTE_BLOCK_M)))
	_wire[key] = [now_ms, bytes, routes.size()]
	return bytes


# How many routes the block's last wire() held (0 before it was built).
func wire_count(key: Vector2i) -> int:
	var rec: Array = _wire.get(key, [])
	return int(rec[2]) if rec.size() > 2 else 0


# The distance from a point to the nearest trail of a kind (-1 any) that is not on settled ground, `reach` when no trail is nearer. A trail
# found in the blocks worked out is a true answer even while a neighbour is not (a nearer one could only make it closer): a snare set on a
# trail the player was sent always reads it (only the 3 x 3 round a player is worked out, so a trail in the ring round them would otherwise
# read INF; the robots, 23 Nov 2026). INF only when no trail is found and a block whose trails could come this near (the one round the
# point too) is not worked out. Each route keeps a bounding box, so only the routes that pass near are measured.
func route_distance(x: float, z: float, kind: int = -1, reach: float = 10.0) -> float:
	var p: Vector2 = Vector2(x, z)
	var centre: Vector2i = block_of(x, z)
	var best: float = reach
	var unknown: bool = false

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key: Vector2i = centre + Vector2i(dx, dz)

			if not is_ready(key):
				var m: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))

				if Rect2(Vector2(key) * m, Vector2(m, m)).grow(reach + REACH_OUT_M).has_point(p):
					unknown = true   # a block whose runs could pass this near is not worked out yet

				continue

			for place in blocks[key]["places"]:
				if (kind >= 0 and int(place["kind"]) != kind) or not bool(place.get("drawn", true)):
					continue   # another kind, or a fox's rounds (not a worn trail)

				var boxes: Array = _boxes(place)
				var near: Array = []

				for n in boxes.size():
					if (boxes[n] as Rect2).grow(best).has_point(p):
						near.append(n)

				if near.is_empty() or settled(place):
					continue

				for n in near:
					var pts: PackedVector2Array = trails_of(place)[n]

					for i in range(1, pts.size()):
						best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])))

	return INF if unknown and best >= reach else best   # none found and some not worked out: not known, rather than off a run


# Whether a fox earth lies within m of a point, in worked-out blocks (a snare there may take a fox while nobody is near, TR-10).
func fox_near(x: float, z: float, m: float) -> bool:
	var size: float = float(cfg.get("block_m", Codec.ROUTE_BLOCK_M))
	var span: int = int(ceil(m / size))
	var centre: Vector2i = block_of(x, z)
	var sp: String = str((cfg.get("fox", {}) as Dictionary).get("species", "fox"))

	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var key: Vector2i = centre + Vector2i(dx, dz)

			if not is_ready(key):
				continue

			for place in blocks[key]["places"]:
				if str(place["sp"]) == sp and (place["home"] as Vector2).distance_to(Vector2(x, z)) <= m and not settled(place):
					return true

	return false


# The bounding box of each of a place's routes, worked out once and kept on the place.
func _boxes(place: Dictionary) -> Array:
	if not place.has("boxes"):
		var boxes: Array = []

		for route in trails_of(place):
			var pts: PackedVector2Array = route
			var box: Rect2 = Rect2(pts[0], Vector2.ZERO) if not pts.is_empty() else Rect2()

			for q in pts:
				box = box.expand(q)

			boxes.append(box)

		place["boxes"] = boxes

	return place["boxes"]


# A place's drawn trails: the routes its animals walk (each from its home), then the joins and water legs they do not (links).
func trails_of(place: Dictionary) -> Array:
	if not place.has("trails"):
		place["trails"] = (place["routes"] as Array) + (place.get("links", []) as Array)   # kept on the place (asked per route in route_distance)

	return place["trails"]
