extends RefCounted

# Dynasty water, stage a: the core heightfield sim (Sonny, 31 Oct 2026; design in docs/DYNASTY_WATER_DESIGN.md).
# One liquid on a regular grid. State: bed height `bed`, water depth `depth` per cell, discharge per unit width `qx` (between cell i and i+1) and `qy` (between j and j+1), in m^2/s.
# The flow law is the local inertial shallow water scheme (Bates, Horritt, Fewtrell 2010, LISFLOOD-FP): q' = (q_mix - g h dt dS/dx) / (1 + dt (g n^2 |q| / h^(7/3) + viscosity)).
# Friction (Manning n and the viscosity trait) keeps fast flow smooth, so a river runs without sloshing; the cell outflow limiter keeps depths from going negative.
# Cells are grouped into 16 x 16 blocks; blocks with nothing moving sleep and cost nothing; a block wakes when water or flux reaches it.
# Springs add m^3/s to a cell, sinks remove at most m^3/s, fixed cells hold a water level (the sea). Edges are closed walls unless `open_edges` drains them.

const Traits := preload("res://src/water2/water_traits.gd")

const GRAVITY := 9.81
const BLOCK := 16
const CFL := 0.7
const MAX_DT := 1.0
const THETA := 0.85
const WAKE_STEPS := 24
const SLEEP_CHANGE := 2.0e-6
const SLEEP_Q := 2.0e-5
const DRY := 1.0e-5

var w: int
var h: int
var cell_m: float
var bed: PackedFloat32Array
var depth: PackedFloat32Array
var qx: PackedFloat32Array
var qy: PackedFloat32Array
var traits
var springs: Dictionary = {}    # cell index -> m^3/s
var sinks: Dictionary = {}      # cell index -> m^3/s (most it takes out)
var fixed: Dictionary = {}      # cell index -> water level held there
var open_edges: bool = false    # edge cells lose their water to the outside (a river leaving the field)
var time_s: float = 0.0
var cells_stepped: int = 0      # cells visited by the last step() (the cost measure)
var substeps: int = 0

var _bw: int
var _bh: int
var _awake: PackedInt32Array
var _keep: PackedFloat32Array
var _hmax: float = 0.1
var _g: float
var _n2: float


func _init(width: int, height: int, cell: float, bed_heights: PackedFloat32Array, p_traits = null) -> void:
	w = width
	h = height
	cell_m = cell
	bed = bed_heights
	depth = PackedFloat32Array()
	depth.resize(w * h)
	qx = PackedFloat32Array()
	qx.resize(w * h)
	qy = PackedFloat32Array()
	qy.resize(w * h)
	_keep = PackedFloat32Array()
	_keep.resize(w * h)
	_keep.fill(1.0)
	_bw = (w + BLOCK - 1) / BLOCK
	_bh = (h + BLOCK - 1) / BLOCK
	_awake = PackedInt32Array()
	_awake.resize(_bw * _bh)
	set_traits(p_traits if p_traits != null else Traits.of("fresh"))


func set_traits(p_traits) -> void:
	traits = p_traits
	_g = GRAVITY * traits.flow_rate
	_n2 = traits.roughness * traits.roughness


func index_of(i: int, j: int) -> int:
	return j * w + i


func wake_all() -> void:
	_awake.fill(WAKE_STEPS)


func wake_cell(i: int, j: int) -> void:
	_awake[(j / BLOCK) * _bw + i / BLOCK] = WAKE_STEPS


func add_water(i: int, j: int, meters: float) -> void:
	depth[j * w + i] += meters
	wake_cell(i, j)


# Fills every cell up to a level (a lake set down in one go); cells already higher are left.
func fill_to_level(level: float) -> void:
	for k in range(w * h):
		depth[k] = maxf(depth[k], level - bed[k])

	wake_all()


func add_spring(i: int, j: int, m3_per_s: float) -> void:
	springs[j * w + i] = m3_per_s
	wake_cell(i, j)


func add_sink(i: int, j: int, m3_per_s: float) -> void:
	sinks[j * w + i] = m3_per_s
	wake_cell(i, j)


func fix_level(i: int, j: int, level: float) -> void:
	fixed[j * w + i] = level
	depth[j * w + i] = maxf(0.0, level - bed[j * w + i])
	wake_cell(i, j)


func surface(k: int) -> float:
	return bed[k] + depth[k]


func volume_m3() -> float:
	var total: float = 0.0

	for k in range(w * h):
		total += depth[k]

	return total * cell_m * cell_m


func awake_blocks() -> int:
	var n: int = 0

	for b in range(_awake.size()):
		if _awake[b] > 0:
			n += 1

	return n


# Speed of the water at a cell, from the discharges on its four faces (m/s); (vx, vz) with x east and z south.
func velocity(i: int, j: int) -> Vector2:
	var k: int = j * w + i
	var d: float = depth[k]

	if d < DRY:
		return Vector2.ZERO

	var east: float = qx[k] if i < w - 1 else 0.0
	var west: float = qx[k - 1] if i > 0 else 0.0
	var south: float = qy[k] if j < h - 1 else 0.0
	var north: float = qy[k - w] if j > 0 else 0.0
	return Vector2(0.5 * (east + west), 0.5 * (south + north)) / d


# Advances the sim by dt_total seconds in stable substeps.
func step(dt_total: float) -> void:
	cells_stepped = 0
	substeps = 0
	var remaining: float = dt_total

	while remaining > 1.0e-6:
		var dt: float = minf(remaining, minf(MAX_DT, CFL * cell_m / sqrt(_g * maxf(_hmax, 0.05))))
		_substep(dt)
		remaining -= dt
		substeps += 1

	time_s += dt_total


func _blocks_to_run() -> PackedInt32Array:
	var run: PackedInt32Array = PackedInt32Array()

	for by in range(_bh):
		for bx in range(_bw):
			var on: bool = false

			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx: int = bx + dx
					var ny: int = by + dy

					if nx >= 0 and ny >= 0 and nx < _bw and ny < _bh and _awake[ny * _bw + nx] > 0:
						on = true

			if on:
				run.append(by * _bw + bx)

	return run


func _flux(a: int, b: int, q: float, qa: float, qb: float, dt: float) -> float:
	var sa: float = bed[a] + depth[a]
	var sb: float = bed[b] + depth[b]
	var hf: float = maxf(sa, sb) - maxf(bed[a], bed[b])

	if hf <= traits.film_m:
		return 0.0

	var mixed: float = THETA * q + (1.0 - THETA) * 0.5 * (qa + qb)
	var num: float = mixed - _g * hf * dt * (sb - sa) / cell_m
	var den: float = 1.0 + dt * (_g * _n2 * absf(q) / (hf * hf * pow(hf, 1.0 / 3.0)) + traits.viscosity)
	return num / den


func _substep(dt: float) -> void:
	for k in springs:
		depth[k] += float(springs[k]) * dt / (cell_m * cell_m)
		_awake[((k / w) / BLOCK) * _bw + (k % w) / BLOCK] = WAKE_STEPS

	var run: PackedInt32Array = _blocks_to_run()
	var hmax: float = 0.0
	var block_q: Dictionary = {}
	var block_change: Dictionary = {}

	# 1. discharge on the east and south face of every cell of the running blocks
	for b in run:
		var i0: int = (b % _bw) * BLOCK
		var j0: int = (b / _bw) * BLOCK
		var i1: int = mini(i0 + BLOCK, w)
		var j1: int = mini(j0 + BLOCK, h)
		var maxq: float = 0.0

		for j in range(j0, j1):
			for i in range(i0, i1):
				var a: int = j * w + i

				if i < w - 1:
					var q0: float = qx[a]
					var left: float = qx[a - 1] if i > 0 else 0.0
					var right: float = qx[a + 1] if i < w - 2 else 0.0
					var q1: float = _flux(a, a + 1, q0, left, right, dt)
					qx[a] = q1
					maxq = maxf(maxq, absf(q1))

				if j < h - 1:
					var r0: float = qy[a]
					var up: float = qy[a - w] if j > 0 else 0.0
					var down: float = qy[a + w] if j < h - 2 else 0.0
					var r1: float = _flux(a, a + w, r0, up, down, dt)
					qy[a] = r1
					maxq = maxf(maxq, absf(r1))

		block_q[b] = maxq
		cells_stepped += (i1 - i0) * (j1 - j0)

	# 2. no cell gives away more than it holds: scale the discharges that leave it
	for b in run:
		var i0: int = (b % _bw) * BLOCK
		var j0: int = (b / _bw) * BLOCK

		for j in range(j0, mini(j0 + BLOCK, h)):
			for i in range(i0, mini(i0 + BLOCK, w)):
				var a: int = j * w + i
				var out: float = 0.0

				if i < w - 1:
					out += maxf(qx[a], 0.0)

				if i > 0:
					out += maxf(-qx[a - 1], 0.0)

				if j < h - 1:
					out += maxf(qy[a], 0.0)

				if j > 0:
					out += maxf(-qy[a - w], 0.0)

				var room: float = depth[a] * cell_m
				_keep[a] = 1.0 if out * dt <= room else room / (out * dt)

	for b in run:
		var i0: int = (b % _bw) * BLOCK
		var j0: int = (b / _bw) * BLOCK

		for j in range(j0, mini(j0 + BLOCK, h)):
			for i in range(i0, mini(i0 + BLOCK, w)):
				var a: int = j * w + i

				if i < w - 1:
					qx[a] *= _keep[a] if qx[a] > 0.0 else _keep[a + 1]

				if j < h - 1:
					qy[a] *= _keep[a] if qy[a] > 0.0 else _keep[a + w]

	# 3. depths from the discharges, sinks, open edges and held levels
	for b in run:
		var i0: int = (b % _bw) * BLOCK
		var j0: int = (b / _bw) * BLOCK
		var change: float = 0.0

		for j in range(j0, mini(j0 + BLOCK, h)):
			for i in range(i0, mini(i0 + BLOCK, w)):
				var a: int = j * w + i
				var net: float = 0.0

				if i > 0:
					net += qx[a - 1]

				if i < w - 1:
					net -= qx[a]

				if j > 0:
					net += qy[a - w]

				if j < h - 1:
					net -= qy[a]

				var before: float = depth[a]
				var after: float = before + dt * net / cell_m

				if open_edges and (i == 0 or j == 0 or i == w - 1 or j == h - 1):
					after = 0.0

				after = maxf(after, 0.0)
				depth[a] = 0.0 if after < DRY else after
				hmax = maxf(hmax, depth[a])
				change = maxf(change, absf(depth[a] - before))

		block_change[b] = change

	for k in sinks:
		depth[k] = maxf(0.0, depth[k] - float(sinks[k]) * dt / (cell_m * cell_m))

	for k in fixed:
		depth[k] = maxf(0.0, float(fixed[k]) - bed[k])
		hmax = maxf(hmax, depth[k])

	for b in run:
		if float(block_change[b]) > SLEEP_CHANGE or float(block_q[b]) > SLEEP_Q:
			_awake[b] = WAKE_STEPS
		elif _awake[b] > 0:
			_awake[b] -= 1

	_hmax = maxf(hmax, 0.05)
