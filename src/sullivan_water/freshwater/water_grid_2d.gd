extends RefCounted

# Sullivan water, milestone M1: one closed region of freshwater columns (Sonny, 7 Nov 2026).
# Foundation: docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md, sections 3.1 to 3.9, 19, 25.2 and 26.3.
#
# The model (guide 3.1, the virtual-pipe / cell volume model):
# - The ground plane (X/Z, metres) is cut into square columns of `cell_m`. Each column stores its bed height `bed` (m) and the water it holds,
#   `volume` (m^3, float64). Depth = volume / area, surface = bed + depth. Volume is the truth; depth and surface are derived from it.
# - Each shared face is stored once: the east face of (i, j) joins it to (i + 1, j), the south face joins it to (i, j + 1). West and north faces
#   are the neighbour's east and south faces. A face has a built crest (a dam, a levee, a wall); its sill is max(bed a, bed b, crest).
# - Water moves toward the lower SURFACE, not the lower ground (guide 3.9): a high pond spills over a hump; a ditch lower than the river stays
#   dry while a ridge blocks it.
#
# One tick (guide 3.2 and 19, in this order; nothing else changes the grid during a tick):
#   0. Springs and sinks, each written in the ledger (a sink takes only what is there).
#   1. Snapshot the surfaces.
#   2. Every face once: a signed candidate transfer from the snapshot, transfer = Q * dt (m^3), with Q from the face law (below).
#   3. Each cell sums what it would send.
#   4. A cell that would send more than it holds scales ALL its outgoing transfers by the same share.
#   5. Each face applies its equal and opposite change once.
#   6. Check for negative volume (only float rounding may leave a trace; it is counted, never hidden).
#   7. Keep each face's transfer for currents.
#   8. Ledger totals.
#
# The face law (decision record in src/sullivan_water/README.md, decision 1). The transaction above is the same for both laws.
# - LAW_PIPE (default), the virtual pipe of Mei, Decaudin and Hu 2007, the model the guide names in 3.1: each face keeps its discharge from the
#   last tick and gravity accelerates it, Q' = (Q + dt g A_face head / cell_m) / (1 + dt damping), with A_face = cell_m * (eta_up - sill),
#   the wetted area over the sill. The damping is linear friction. Steady flow through deep water needs almost no slope, so a reservoir
#   stays level and a river keeps its water moving. The speed through a face is capped at MAX_COURANT * cell_m / dt.
# - LAW_ORIFICE, the guide's baseline exactly as Dave's companion file has it (docs/water/edition3_code/implementation/WaterGrid2D.gd):
#   Q = C * face_width * max(0, eta_up - sill) * sqrt(2 g |head|) * sign(head) with C = 0.18, no memory, heads under 1e-6 m ignored, and
#   each face's transfer at most the donor's volume. Kept for comparison. Measured on Dave's PC (#498): a law without memory needs a
#   slope to carry any flow, so a reservoir fed by a spring tilts; the pipe law keeps it level.
#
# Edges are sealed (guide 3.5: the starter is a closed region; open boundaries, chunks and reservoirs come in M4). Caves and stacked water
# are not this model (guide 3.10): one water surface per column only.
#
# Units: metres, seconds, cubic metres. Indices: k = j * w + i, i along X (east), j along Z (south).

const GRAVITY := 9.81
const DEFAULT_DT := 0.1            # s: 10 ticks a second (guide 3.4 test value)
const DEFAULT_CELL_M := 2.0        # m (guide 3.4 test value)
const DEFAULT_C := 0.18            # LAW_ORIFICE discharge coefficient, Dave's file's value ("intentional game-tuning parameter")
const ORIFICE_MIN_HEAD := 0.000001 # LAW_ORIFICE: heads smaller than this move nothing (Dave's file)
const LAW_PIPE := 0
const LAW_ORIFICE := 1
const DEFAULT_DAMPING_PER_S := 0.5 # LAW_PIPE linear friction, 1/s: a moving face loses this share of its discharge each second when nothing drives it
const MAX_COURANT := 0.5           # LAW_PIPE: water crosses at most half a cell per tick (10 m/s at 2 m and 0.1 s)
const MAX_CATCH_UP_STEPS := 4      # advance() runs at most this many ticks a call (Dave's freshwater_runner.gd), so a pause is never one giant step
const BACKLOG_WARN_S := 1.0        # ... and the time it could not run yet is KEPT, never thrown away; over this much, it warns (same file)
const OPEN := -INF                 # a face with no built crest
const WALL := INF                  # a face nothing passes

var w: int
var h: int
var cell_m: float
var area_m2: float
var dt: float = DEFAULT_DT
var coefficient: float = DEFAULT_C
var law: int = LAW_PIPE
var damping_per_s: float = DEFAULT_DAMPING_PER_S

var bed: PackedFloat64Array        # m, per cell
var volume: PackedFloat64Array     # m^3, per cell
var crest_e: PackedFloat64Array    # m, built crest of each cell's east face (OPEN = none)
var crest_s: PackedFloat64Array    # m, built crest of each cell's south face
var flow_e: PackedFloat64Array     # m^3 moved east through each east face in the last tick (negative = west)
var flow_s: PackedFloat64Array     # m^3 moved south through each south face in the last tick (negative = north)
var pipe_e: PackedFloat64Array     # LAW_PIPE: each east face's discharge kept from the last tick (m^3/s, after scaling)
var pipe_s: PackedFloat64Array     # LAW_PIPE: each south face's discharge kept from the last tick

var springs: Dictionary = {}       # cell index -> {"id": String, "m3_per_s": float}
var sinks: Dictionary = {}         # cell index -> {"id": String, "m3_per_s": float} (the most it asks for)
var fixed: Dictionary = {}         # cell index -> surface level held there: a fixed-stage reservoir boundary (guide 3.5), e.g. the river
                                   # where it enters and leaves a window. What it adds or takes each tick is booked as boundary_in/out.

# Ledger (guide 26.3): expected = start + added + springs - removed - sinks - rounding. Interior faces cancel and never appear here.
var start_m3: float = 0.0
var added_m3: float = 0.0          # add_water calls
var removed_m3: float = 0.0        # remove_water calls (what was actually granted)
var spring_m3: float = 0.0
var sink_m3: float = 0.0           # what sinks were actually granted
var boundary_in_m3: float = 0.0   # fixed-level cells topped up (water coming in from outside the region)
var boundary_out_m3: float = 0.0  # fixed-level cells drained (water leaving the region)
var rounding_m3: float = 0.0       # float traces under zero set back to zero (step 6); reported, so a real leak cannot hide here
var by_id: Dictionary = {}         # source or sink id -> signed m^3 (positive = into the water)

var ticks: int = 0
var max_negative_m3: float = 0.0   # the most negative volume ever seen before step 6 (0 = never)
var last_scaled_cells: int = 0     # cells whose outflow was scaled down in the last tick (step 4)
var _accum: float = 0.0
var behind: bool = false           # the backlog passed BACKLOG_WARN_S (warned once until it catches up)
var _out: PackedFloat64Array       # scratch: candidate outflow per cell
var _scale: PackedFloat64Array     # scratch: share of its outflow each cell may send
var _eta: PackedFloat64Array       # scratch: the snapshot surfaces


func _init(width: int, height: int, p_cell_m: float = DEFAULT_CELL_M, bed_heights = null) -> void:
	assert(width >= 1 and height >= 1 and p_cell_m > 0.0)
	w = width
	h = height
	cell_m = p_cell_m
	area_m2 = p_cell_m * p_cell_m
	var n: int = w * h
	bed.resize(n)
	bed.fill(0.0)
	volume.resize(n)
	volume.fill(0.0)
	crest_e.resize(n)
	crest_e.fill(OPEN)
	crest_s.resize(n)
	crest_s.fill(OPEN)
	flow_e.resize(n)
	flow_e.fill(0.0)
	flow_s.resize(n)
	flow_s.fill(0.0)
	pipe_e.resize(n)
	pipe_e.fill(0.0)
	pipe_s.resize(n)
	pipe_s.fill(0.0)
	_out.resize(n)
	_scale.resize(n)
	_eta.resize(n)

	if bed_heights is PackedFloat64Array and bed_heights.size() == n:
		bed = bed_heights.duplicate()


func index(i: int, j: int) -> int:
	return j * w + i


func inside(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < w and j < h


# --- Geometry --------------------------------------------------------------------------------------------------------------------------

# Raising or lowering ground keeps the water's volume: the surface moves with the bed and the flow spreads it out over the next ticks
# (guide 25.2: "Raising land does not destroy water"). Never clamp the old surface and delete what no longer fits.
func set_bed(i: int, j: int, y: float) -> void:
	bed[index(i, j)] = y


# A built crest on the face east of (i, j), between it and (i + 1, j). OPEN removes it, WALL closes the face.
func set_crest_east(i: int, j: int, y: float) -> void:
	assert(i < w - 1, "the east edge is sealed: no face there")
	crest_e[index(i, j)] = y


# A built crest on the face south of (i, j), between it and (i, j + 1).
func set_crest_south(i: int, j: int, y: float) -> void:
	assert(j < h - 1, "the south edge is sealed: no face there")
	crest_s[index(i, j)] = y


# --- Water in and out (every external change goes through the ledger) ------------------------------------------------------------------

func add_water(i: int, j: int, m3: float, id: String = "add") -> void:
	assert(m3 >= 0.0)
	volume[index(i, j)] += m3
	added_m3 += m3
	_book(id, m3)


# Takes at most what the cell holds and returns what it really took (guide 19: a caller gets the granted volume, never its request).
func remove_water(i: int, j: int, m3: float, id: String = "remove") -> float:
	assert(m3 >= 0.0)
	var k: int = index(i, j)
	var granted: float = minf(m3, volume[k])
	volume[k] -= granted
	removed_m3 += granted
	_book(id, -granted)
	return granted


# Fills every cell up to the surface `level` (cells whose bed is above stay dry). The water starts the ledger, as if it had always been there.
func fill_to_level(level: float) -> void:
	for k in range(w * h):
		volume[k] = maxf(0.0, level - bed[k]) * area_m2

	start_m3 = total_volume() - (expected_volume() - start_m3)


func add_spring(i: int, j: int, m3_per_s: float, id: String) -> void:
	assert(m3_per_s >= 0.0)
	springs[index(i, j)] = {"id": id, "m3_per_s": m3_per_s}


func add_sink(i: int, j: int, m3_per_s: float, id: String) -> void:
	assert(m3_per_s >= 0.0)
	sinks[index(i, j)] = {"id": id, "m3_per_s": m3_per_s}


# --- Time ------------------------------------------------------------------------------------------------------------------------------

# Runs as many fixed ticks as `elapsed_s` holds, at most MAX_CATCH_UP_STEPS; the rest waits for the next call, never discarded (Dave's
# runner: "do not silently discard remaining simulation time"; if it keeps falling behind, report it, lower resolution or activate fewer cells). Render frames call this; the result does not
# depend on the frame rate, only on the number of fixed ticks (test F09).
func advance(elapsed_s: float) -> int:
	_accum += maxf(0.0, elapsed_s)
	var ran: int = 0

	while _accum >= dt and ran < MAX_CATCH_UP_STEPS:
		step()
		_accum -= dt
		ran += 1

	if _accum > BACKLOG_WARN_S and not behind:
		behind = true
		push_warning("Sullivan water: simulation backlog over %.1f s" % BACKLOG_WARN_S)
	elif _accum <= dt:
		behind = false
	return ran


# Simulation time waiting to run (s).
func backlog_s() -> float:
	return _accum


func step() -> void:
	var n: int = w * h

	# 0. Springs and sinks.
	for k in springs:
		var add: float = float(springs[k]["m3_per_s"]) * dt
		volume[k] += add
		spring_m3 += add
		_book(String(springs[k]["id"]), add)

	for k in sinks:
		var want: float = float(sinks[k]["m3_per_s"]) * dt
		var got: float = minf(want, volume[k])
		volume[k] -= got
		sink_m3 += got
		_book(String(sinks[k]["id"]), -got)

	# 0b. Fixed-stage boundaries: each held cell is set back to its level, and the difference is booked as water in or out.
	for k in fixed:
		var want_m3: float = maxf(0.0, float(fixed[k]) - bed[k]) * area_m2
		var delta: float = want_m3 - volume[k]

		if delta > 0.0:
			boundary_in_m3 += delta
		else:
			boundary_out_m3 -= delta

		volume[k] = want_m3

	# 1. Snapshot.
	for k in range(n):
		_eta[k] = bed[k] + volume[k] / area_m2
		_out[k] = 0.0

	# 2. Candidate transfers, each face once, all from the snapshot.
	for j in range(h):
		for i in range(w):
			var k: int = j * w + i

			if i < w - 1:
				var t: float = _candidate(k, k + 1, crest_e[k], pipe_e[k])
				flow_e[k] = t
				_out[k if t > 0.0 else k + 1] += absf(t)
			else:
				flow_e[k] = 0.0

			if j < h - 1:
				var t: float = _candidate(k, k + w, crest_s[k], pipe_s[k])
				flow_s[k] = t
				_out[k if t > 0.0 else k + w] += absf(t)
			else:
				flow_s[k] = 0.0

	# 3 and 4. Each cell's share: all its outgoing transfers scaled together, never one by one.
	last_scaled_cells = 0

	for k in range(n):
		if _out[k] > volume[k]:
			_scale[k] = volume[k] / _out[k] if _out[k] > 0.0 else 0.0
			last_scaled_cells += 1
		else:
			_scale[k] = 1.0

	# 5. Apply each face once, equal and opposite.
	for j in range(h):
		for i in range(w):
			var k: int = j * w + i

			if i < w - 1:
				var t: float = flow_e[k] * _scale[k if flow_e[k] > 0.0 else k + 1]
				flow_e[k] = t
				pipe_e[k] = t / dt   # the pipe keeps only what really moved
				volume[k] -= t
				volume[k + 1] += t

			if j < h - 1:
				var t: float = flow_s[k] * _scale[k if flow_s[k] > 0.0 else k + w]
				flow_s[k] = t
				pipe_s[k] = t / dt
				volume[k] -= t
				volume[k + w] += t

	# 6. Negative check. Scaling keeps every donor at or above zero up to float rounding; the trace is counted.
	for k in range(n):
		if volume[k] < 0.0:
			max_negative_m3 = minf(max_negative_m3, volume[k])
			rounding_m3 += volume[k]   # negative: water the rounding "made"; removing the trace brings it back to zero
			volume[k] = 0.0

	ticks += 1


# Signed m^3 from a to b this tick (negative = b to a), from the snapshot. `kept` is the face's discharge from the last tick (LAW_PIPE).
# Zero when the side the water would leave is dry or sits at or below the sill.
func _candidate(a: int, b: int, crest: float, kept: float) -> float:
	var sill: float = maxf(maxf(bed[a], bed[b]), crest)
	var head: float = _eta[a] - _eta[b]
	var over: float = maxf(_eta[a], _eta[b]) - sill   # water standing over the sill on the higher side

	if over <= 0.0:
		return 0.0

	var q: float

	if law == LAW_ORIFICE:
		if absf(head) < ORIFICE_MIN_HEAD:
			return 0.0

		var up: int = a if head > 0.0 else b
		var proposed: float = coefficient * cell_m * over * sqrt(2.0 * GRAVITY * absf(head)) * dt
		q = minf(proposed, volume[up]) / dt
		q = q if head > 0.0 else -q
	else:
		var wet_area: float = cell_m * over
		q = (kept + dt * GRAVITY * wet_area * head / cell_m) / (1.0 + dt * damping_per_s)
		var most: float = wet_area * MAX_COURANT * cell_m / dt
		q = clampf(q, -most, most)

	var donor: int = a if q > 0.0 else b

	# A dry cell cannot send water, and neither can a side whose surface is at or under the sill (the pipe's kept discharge cannot pull
	# water up over a crest).
	if q == 0.0 or volume[donor] <= 0.0 or _eta[donor] <= sill:
		return 0.0

	return q * dt


func _book(id: String, m3: float) -> void:
	by_id[id] = float(by_id.get(id, 0.0)) + m3


# --- Queries (read-only; renderers, swimmers and farms never write volume) ------------------------------------------------------------

func depth(i: int, j: int) -> float:
	return volume[index(i, j)] / area_m2


func surface(i: int, j: int) -> float:
	var k: int = index(i, j)
	return bed[k] + volume[k] / area_m2


func total_volume() -> float:
	var sum: float = 0.0

	for k in range(w * h):
		sum += volume[k]
	return sum


func expected_volume() -> float:
	return start_m3 + added_m3 + spring_m3 + boundary_in_m3 - removed_m3 - sink_m3 - boundary_out_m3 - rounding_m3


# actual - expected, m^3 (guide 26.3). Zero up to float rounding when no water is made or lost.
func ledger_residual() -> float:
	return total_volume() - expected_volume()


# The smallest volume in any cell now (m^3); never below zero after a tick.
func min_volume() -> float:
	var low: float = INF

	for k in range(w * h):
		low = minf(low, volume[k])
	return low


# Mean water speed through the cell (m/s, X east, Y = Z south), from the last tick's face transfers: the average of its west/east and
# north/south discharges over the wetted face area. An approximate current for drift and foam (guide 19: not a measured drag force).
func velocity(i: int, j: int) -> Vector2:
	var k: int = index(i, j)
	var d: float = depth(i, j)

	if d <= 1.0e-6:
		return Vector2.ZERO

	var qx: float = flow_e[k] if i < w - 1 else 0.0
	var qz: float = flow_s[k] if j < h - 1 else 0.0
	var faces_x: int = 1 if i < w - 1 else 0
	var faces_z: int = 1 if j < h - 1 else 0

	if i > 0:
		qx += flow_e[k - 1]
		faces_x += 1

	if j > 0:
		qz += flow_s[k - w]
		faces_z += 1

	var wet: float = cell_m * d * dt   # m^2 * s: converts m^3 per tick to m/s
	return Vector2(qx / maxi(faces_x, 1) / wet, qz / maxi(faces_z, 1) / wet)


# The same current as a world vector (x east, y 0, z south), the shape the water query hands out (core/water_sample.gd).
func current_mps(i: int, j: int) -> Vector3:
	var v: Vector2 = velocity(i, j)
	return Vector3(v.x, 0.0, v.y)


# The largest surface difference across any face where at least `min_over_m` of water stands over the sill (m): how far the water is from
# at rest. A settled pond reads near zero. The threshold leaves out the last films draining off high ground, which never quite reach zero.
func max_wet_head(min_over_m: float = 0.001) -> float:
	var most: float = 0.0

	for j in range(h):
		for i in range(w):
			var k: int = j * w + i

			if i < w - 1:
				most = maxf(most, _face_head(k, k + 1, crest_e[k], min_over_m))

			if j < h - 1:
				most = maxf(most, _face_head(k, k + w, crest_s[k], min_over_m))
	return most


func _face_head(a: int, b: int, crest: float, min_over_m: float) -> float:
	var eta_a: float = bed[a] + volume[a] / area_m2
	var eta_b: float = bed[b] + volume[b] / area_m2
	var sill: float = maxf(maxf(bed[a], bed[b]), crest)
	return absf(eta_a - eta_b) if maxf(eta_a, eta_b) - sill > min_over_m else 0.0
