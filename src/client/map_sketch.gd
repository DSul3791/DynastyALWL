extends RefCounted

# The inked sketch of the Map (docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md s1.2-1.3; Dave 23 Nov 2026 play test: "too digital and fake ...
# too much detail and ... straight lines"; keep it black and white, show water's edges, the ocean, rivers, roads and paths). It turns this
# character's surveyed cells (map_knowledge.gd) into pen strokes the Map page draws over its paper, the way a person inks a map: a wavering
# shore line with two broken lines of water inside it, a river as one line through the cells it runs in, a few faint hill lines, small tree
# marks for woods, reed tufts on wet ground, a dashed line for a path and a firmer one for a road. Unsurveyed ground stays bare paper, and
# the surveyed ground has a faint wash that fades out at its edge. Each cell keeps its own q (the Mapping skill it was surveyed at): low
# q gives shakier, lighter strokes, high q steadier and darker ones.
#
# Everything is worked out on a lattice in world sketch pixels (two samples a cell) and the wobble comes from the world position, so the
# strokes of neighbouring blocks meet without a seam: a block only draws the lattice squares and cells inside it, and a line's ends on the
# block's edge are never moved. render_block() is render_rect() over one block, with a two-cell border read from the neighbours.
# Strokes are in world sketch pixels: [PackedVector2Array points, screen width px, ink alpha, dashed]; the page draws them scaled by its zoom.

const INK := Color(0.12, 0.11, 0.10)
const CONTOUR_M := 20.0   # one faint hill line every 20 m of height (it was 10 m and every slope hatched: "too much detail")
const PX := 4             # sketch pixels per map cell (16 m cells: 4 m a pixel)
const SAMPLES := 2        # lattice samples a cell side
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const AROUND := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const WATER_INLAND := 1
const WATER_SEA := 2
const WATER_RIVER := 3
const WATER_MARSH := 4


# One block's sketch: {"strokes": [...], "batches": [...], "wash": Image of block_cells square (one pixel a cell), "origin", "extent"}.
static func render_block(knowledge, block: Vector2i, px: int = PX) -> Dictionary:
	var size: int = knowledge.block_cells * px
	return render_rect(knowledge, Vector2i(block.x * size, block.y * size), Vector2i(size, size), px)


# Any rectangle of world sketch pixels (origin in world pixels: world metres / cell_m * px), a whole number of cells.
static func render_rect(knowledge, origin: Vector2i, extent: Vector2i, px: int = PX) -> Dictionary:
	return paint(gather(knowledge, origin, extent, px))


# The cells a rectangle's sketch reads, copied out of the store (main thread, cheap), so paint() can run on a worker thread while new blocks
# keep arriving: {"origin", "extent", "px", "c0", "cw", "ch", "known", "heights", "water", "quality", "trees", "paths", "any"}.
static func gather(knowledge, origin: Vector2i, extent: Vector2i, px: int = PX) -> Dictionary:
	var c0: Vector2i = Vector2i(int(floor(float(origin.x) / px)) - 2, int(floor(float(origin.y) / px)) - 2)
	var cw: int = int(ceil(float(extent.x) / px)) + 5
	var ch: int = int(ceil(float(extent.y) / px)) + 5
	var known: PackedByteArray = PackedByteArray()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var water: PackedByteArray = PackedByteArray()
	var quality: PackedByteArray = PackedByteArray()
	var trees: PackedByteArray = PackedByteArray()
	var paths: PackedByteArray = PackedByteArray()
	known.resize(cw * ch)
	heights.resize(cw * ch)
	water.resize(cw * ch)
	quality.resize(cw * ch)
	trees.resize(cw * ch)
	paths.resize(cw * ch)
	var any: bool = false
	var has_paths: bool = knowledge.has_method("path_at")

	for j in ch:
		for i in cw:
			var at: Vector2i = Vector2i(c0.x + i, c0.y + j)
			var cell: Array = knowledge.cell_at(at)
			var n: int = j * cw + i

			if cell.is_empty():
				continue

			any = true
			known[n] = 1
			quality[n] = int(cell[0])
			heights[n] = float(cell[1])
			water[n] = int(cell[2])
			trees[n] = int(cell[3])
			paths[n] = knowledge.path_at(at) if has_paths else 0

	return {"origin": origin, "extent": extent, "px": px, "c0": c0, "cw": cw, "ch": ch, "known": known, "heights": heights, "water": water,
		"quality": quality, "trees": trees, "paths": paths, "any": any}


# The strokes and wash for gathered cells: touches nothing but its argument, so it may run on any thread.
static func paint(grid: Dictionary) -> Dictionary:
	var origin: Vector2i = grid["origin"]
	var extent: Vector2i = grid["extent"]
	var px: int = int(grid["px"])
	var c0: Vector2i = grid["c0"]
	var cw: int = int(grid["cw"])
	var ch: int = int(grid["ch"])
	var known: PackedByteArray = grid["known"]
	var water: PackedByteArray = grid["water"]
	var quality: PackedByteArray = grid["quality"]
	var out: Dictionary = {"origin": origin, "extent": extent, "strokes": [], "wash": null, "batches": []}
	var cells_x: int = int(ceil(float(extent.x) / px))
	var cells_y: int = int(ceil(float(extent.y) / px))
	var wash: Image = Image.create(maxi(cells_x, 1), maxi(cells_y, 1), false, Image.FORMAT_RGBA8)
	wash.fill(Color(INK, 0.0))
	out["wash"] = wash

	if not bool(grid["any"]):
		return out

	var first: Vector2i = Vector2i(int(floor(float(origin.x) / px)), int(floor(float(origin.y) / px))) - c0   # the rect's first cell in the grid

	for j in cells_y:
		for i in cells_x:
			if known[(first.y + j) * cw + first.x + i] == 1:
				wash.set_pixel(i, j, Color(INK, 0.07))

	# Cell fields: open water (sea, lake, and a river wide enough to be water rather than a line) and the heights (unknown cells borrow a
	# known neighbour's, so a slope does not plunge at the edge of the known ground).
	var heights: PackedFloat32Array = grid["heights"]
	var wet: PackedFloat32Array = PackedFloat32Array()
	wet.resize(cw * ch)

	for j in ch:
		for i in cw:
			var n: int = j * cw + i

			if known[n] == 0:
				for d in SIDES:
					var a: int = i + d.x
					var b: int = j + d.y

					if a >= 0 and b >= 0 and a < cw and b < ch and known[b * cw + a] == 1:
						heights[n] = heights[b * cw + a]
						wet[n] = 1.0 if _open_water(water, known, cw, ch, a, b) else 0.0
						break
			else:
				wet[n] = 1.0 if _open_water(water, known, cw, ch, i, j) else 0.0

	# The ripple field: the open water blurred over its neighbours, so its levels run alongside the shore inside the water.
	var calm: PackedFloat32Array = PackedFloat32Array()
	calm.resize(cw * ch)

	for j in ch:
		for i in cw:
			var sum: float = 0.0
			var count: float = 0.0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var a: int = clampi(i + di, 0, cw - 1)
					var b: int = clampi(j + dj, 0, ch - 1)
					sum += wet[b * cw + a]
					count += 1.0

			calm[j * cw + i] = sum / count

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 4471
	noise.frequency = 0.09
	var strokes: Array = out["strokes"]
	var step: float = float(px) / float(SAMPLES)
	var lat0: Vector2i = Vector2i(int(floor(float(origin.x) / step)), int(floor(float(origin.y) / step)))
	var lw: int = int(ceil(float(extent.x) / step)) + 1
	var lh: int = int(ceil(float(extent.y) / step)) + 1
	var f_wet: PackedFloat32Array = _lattice(wet, grid, noise, lat0, lw, lh, step, 0.18)
	var f_calm: PackedFloat32Array = _lattice(calm, grid, noise, lat0, lw, lh, step, 0.10)
	var f_h: PackedFloat32Array = _lattice(heights, grid, noise, lat0, lw, lh, step, 0.0)
	var f_known: PackedByteArray = PackedByteArray()
	var f_q: PackedByteArray = PackedByteArray()
	f_known.resize(lw * lh)
	f_q.resize(lw * lh)

	for y in lh:
		for x in lw:
			var ci: int = int(floor(float(lat0.x + x) * step / px)) - c0.x
			var cj: int = int(floor(float(lat0.y + y) * step / px)) - c0.y
			f_known[y * lw + x] = known[cj * cw + ci]
			f_q[y * lw + x] = quality[cj * cw + ci]

	# The shore: a firm wavering line where the open water meets the land; inside it two broken lines run along it.
	for line in _contours(f_wet, f_known, lw, lh, 0.5, PackedFloat32Array()):
		_add(strokes, line, lat0, step, f_q, lw, noise, 1.7, 0.9, false)

	for level in [0.78, 0.93]:
		for line in _contours(f_calm, f_known, lw, lh, level, f_wet):
			_add(strokes, line, lat0, step, f_q, lw, noise, 0.9, 0.38, true)

	# Hill lines: faint, broken, on dry ground only.
	var hmin: float = INF
	var hmax: float = -INF

	for v in f_h:
		hmin = minf(hmin, v)
		hmax = maxf(hmax, v)

	if hmax - hmin >= CONTOUR_M * 0.5:
		var level: float = ceil(hmin / CONTOUR_M) * CONTOUR_M
		var dry: PackedFloat32Array = f_wet

		while level <= hmax:
			for line in _contours(f_h, f_known, lw, lh, level, dry, true):
				_add(strokes, line, lat0, step, f_q, lw, noise, 0.8, 0.26, true)

			level += CONTOUR_M

	_cell_lines(grid, first, cells_x, cells_y, strokes, noise)
	_cell_marks(grid, first, cells_x, cells_y, strokes)
	out["batches"] = batches(strokes)
	return out


# The strokes as a few batches the page draws in one call each: [[PackedVector2Array of segment pairs, width, alpha], ...], by width and
# ink (to 0.05), so a block of woods is a handful of draw calls, not a thousand.
static func batches(strokes: Array) -> Array:
	var by: Dictionary = {}   # key -> [Array of Vector2, width, alpha] (a plain Array grows in place; a packed one in an Array would copy)

	for s in strokes:
		var pts: PackedVector2Array = s[0]
		var key: String = "%.2f|%.2f" % [float(s[1]), snappedf(float(s[2]), 0.05)]

		if not by.has(key):
			by[key] = [[], float(s[1]), snappedf(float(s[2]), 0.05)]

		var pairs: Array = by[key][0]

		for i in range(pts.size() - 1):
			pairs.append(pts[i])
			pairs.append(pts[i + 1])

	var out: Array = []

	for key in by:
		out.append([PackedVector2Array(by[key][0]), by[key][1], by[key][2]])

	return out


# A cell of open water: sea or lake, or a river cell that is wide (water on most sides), which is drawn as water with a shore, not a line.
static func _open_water(water: PackedByteArray, known: PackedByteArray, cw: int, ch: int, i: int, j: int) -> bool:
	var w: int = water[j * cw + i]

	if w == WATER_INLAND or w == WATER_SEA:
		return true

	if w != WATER_RIVER:
		return false

	var wide: int = 0

	for d in AROUND:
		var a: int = i + d.x
		var b: int = j + d.y

		if a >= 0 and b >= 0 and a < cw and b < ch and known[b * cw + a] == 1 and water[b * cw + a] in [WATER_INLAND, WATER_SEA, WATER_RIVER]:
			wide += 1

	return wide >= 6


# A cell field read at every lattice point (smoothstepped between cell centres), shaken by the world-position noise times `shake` (less at high q).
static func _lattice(field: PackedFloat32Array, grid: Dictionary, noise: FastNoiseLite, lat0: Vector2i, lw: int, lh: int, step: float, shake: float) -> PackedFloat32Array:
	var px: float = float(grid["px"])
	var c0: Vector2i = grid["c0"]
	var cw: int = int(grid["cw"])
	var ch: int = int(grid["ch"])
	var quality: PackedByteArray = grid["quality"]
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(lw * lh)

	for y in lh:
		for x in lw:
			var wx: float = float(lat0.x + x) * step
			var wy: float = float(lat0.y + y) * step
			var u: float = wx / px - 0.5 - float(c0.x)
			var v: float = wy / px - 0.5 - float(c0.y)
			var i: int = clampi(int(floor(u)), 0, cw - 2)
			var j: int = clampi(int(floor(v)), 0, ch - 2)
			var fu: float = clampf(u - float(i), 0.0, 1.0)
			var fv: float = clampf(v - float(j), 0.0, 1.0)
			fu = fu * fu * (3.0 - 2.0 * fu)   # smoothstep: a shore rounds the cell corners instead of running in straight diagonals
			fv = fv * fv * (3.0 - 2.0 * fv)
			var top: float = lerpf(field[j * cw + i], field[j * cw + i + 1], fu)
			var bottom: float = lerpf(field[(j + 1) * cw + i], field[(j + 1) * cw + i + 1], fu)
			var value: float = lerpf(top, bottom, fv)

			if shake > 0.0:
				var q: float = float(quality[clampi(int(round(v)), 0, ch - 1) * cw + clampi(int(round(u)), 0, cw - 1)]) / 100.0
				value += shake * lerpf(1.4, 0.7, q) * noise.get_noise_2d(wx, wy)

			out[y * lw + x] = value

	return out


# Marching squares on the lattice: the polylines (lattice coordinates) where `field` crosses `level`, chained end to end. A square is drawn
# only where all four corners are surveyed; with `mask` (the open water field), only where every corner is water (mask_dry false: the
# ripples) or every corner is land (mask_dry true: the hill lines).
static func _contours(field: PackedFloat32Array, known: PackedByteArray, lw: int, lh: int, level: float, mask: PackedFloat32Array, mask_dry: bool = false) -> Array:
	var segs: Array = []   # [edge key a, point a, edge key b, point b]

	for y in lh - 1:
		for x in lw - 1:
			var n: int = y * lw + x

			if known[n] == 0 or known[n + 1] == 0 or known[n + lw] == 0 or known[n + lw + 1] == 0:
				continue

			if not mask.is_empty():
				var ok: bool = true

				for m in [n, n + 1, n + lw, n + lw + 1]:
					ok = ok and ((mask[m] < 0.45) if mask_dry else (mask[m] > 0.5))

				if not ok:
					continue

			var a: float = field[n]               # top left
			var b: float = field[n + 1]           # top right
			var c: float = field[n + lw + 1]      # bottom right
			var d: float = field[n + lw]          # bottom left
			var code: int = (1 if a > level else 0) | (2 if b > level else 0) | (4 if c > level else 0) | (8 if d > level else 0)

			if code == 0 or code == 15:
				continue

			# Edges: 0 top (a-b), 1 right (b-c), 2 bottom (d-c), 3 left (a-d); keyed by the lattice edge so squares chain.
			var pts: Array = [
				[_ekey(x, y, 0), Vector2(x + _t(a, b, level), y)],
				[_ekey(x + 1, y, 1), Vector2(x + 1, y + _t(b, c, level))],
				[_ekey(x, y + 1, 0), Vector2(x + _t(d, c, level), y + 1)],
				[_ekey(x, y, 1), Vector2(x, y + _t(a, d, level))]]
			var pairs: Array = []

			match code:
				1, 14: pairs = [[0, 3]]
				2, 13: pairs = [[0, 1]]
				3, 12: pairs = [[1, 3]]
				4, 11: pairs = [[1, 2]]
				6, 9: pairs = [[0, 2]]
				7, 8: pairs = [[2, 3]]
				5: pairs = [[0, 1], [2, 3]] if (a + b + c + d) * 0.25 > level else [[0, 3], [1, 2]]
				10: pairs = [[0, 3], [1, 2]] if (a + b + c + d) * 0.25 > level else [[0, 1], [2, 3]]

			for p in pairs:
				segs.append([pts[p[0]][0], pts[p[0]][1], pts[p[1]][0], pts[p[1]][1]])

	return _chain(segs)


static func _ekey(x: int, y: int, dir: int) -> int:
	return ((y + 4096) * 16384 + (x + 4096)) * 2 + dir


static func _t(a: float, b: float, level: float) -> float:
	return clampf((level - a) / (b - a), 0.0, 1.0) if absf(b - a) > 0.00001 else 0.5


# Segments sharing an edge key joined into polylines.
static func _chain(segs: Array) -> Array:
	var at: Dictionary = {}   # edge key -> [segment indices]

	for k in segs.size():
		for e in [segs[k][0], segs[k][2]]:
			if not at.has(e):
				at[e] = []

			at[e].append(k)

	var used: PackedByteArray = PackedByteArray()
	used.resize(segs.size())
	var lines: Array = []

	for k in segs.size():
		if used[k] == 1:
			continue

		used[k] = 1
		var line: Array = [segs[k][1], segs[k][3]]
		var keys: Array = [segs[k][0], segs[k][2]]

		for end in [1, 0]:   # grow from the tail, then from the head
			var key: int = keys[end]

			while true:
				var next: int = -1

				for other in at.get(key, []):
					if used[other] == 0:
						next = other
						break

				if next < 0:
					break

				used[next] = 1
				var s: Array = segs[next]
				var far_key: int = s[2] if s[0] == key else s[0]
				var far_pt: Vector2 = s[3] if s[0] == key else s[1]

				if end == 1:
					line.append(far_pt)
				else:
					line.push_front(far_pt)

				key = far_key

		lines.append(line)

	return lines


# A lattice polyline turned into a stroke: into world sketch pixels, rounded twice (Chaikin, its ends kept so a line crossing a block edge
# meets its neighbour's), each inner point shaken a little by the hand, then added (dashed lines broken into dashes by position).
static func _add(strokes: Array, line: Array, lat0: Vector2i, step: float, f_q: PackedByteArray, lw: int, noise: FastNoiseLite, width: float, alpha: float, dashed: bool) -> void:
	if line.size() < 2:
		return

	var pts: Array = []

	for p in line:
		pts.append((Vector2(lat0) + p) * step)

	var mid: Vector2 = line[line.size() / 2]
	var q: float = float(f_q[clampi(int(mid.y), 0, f_q.size() / lw - 1) * lw + clampi(int(mid.x), 0, lw - 1)]) / 100.0
	_ink(strokes, pts, q, noise, width, alpha, dashed)


# World sketch pixel points inked: rounded twice (Chaikin, ends kept), the inner points shaken by the hand, dashed lines broken by position.
static func _ink(strokes: Array, pts: Array, q: float, noise: FastNoiseLite, width: float, alpha: float, dashed: bool) -> void:
	for _round in 2:
		if pts.size() < 3:
			break

		var smooth: Array = [pts[0]]

		for i in range(pts.size() - 1):
			smooth.append(pts[i].lerp(pts[i + 1], 0.25))
			smooth.append(pts[i].lerp(pts[i + 1], 0.75))

		smooth.append(pts[pts.size() - 1])
		pts = smooth

	var hand: float = lerpf(0.55, 0.15, q)
	var packed: PackedVector2Array = PackedVector2Array()

	for i in pts.size():
		var p: Vector2 = pts[i]

		if i > 0 and i < pts.size() - 1:
			p += Vector2(noise.get_noise_2d(p.x * 3.1, p.y * 3.1 + 500.0), noise.get_noise_2d(p.x * 3.1 + 900.0, p.y * 3.1)) * hand

		packed.append(p)

	var ink: float = alpha * lerpf(0.6, 1.0, q)

	if not dashed:
		strokes.append([packed, width, ink, false])
		return

	# Broken: runs of a few points with gaps, where the gaps fall by position (not by order) so a neighbouring block agrees.
	var run: PackedVector2Array = PackedVector2Array()

	for p in packed:
		if _hash01(int(floor(p.x * 0.7)), int(floor(p.y * 0.7))) < 0.28:
			if run.size() >= 2:
				strokes.append([run, width, ink, false])

			run = PackedVector2Array()
		else:
			run.append(p)

	if run.size() >= 2:
		strokes.append([run, width, ink, false])


# Rivers and paths: one line through the centres of the cells they run in, rounded like a pen line (a cell links to its neighbours east,
# south-east, south and south-west, so each link belongs to the cell it starts from and is drawn by that cell's block; a diagonal only
# where no square link makes the corner). Links are chained into lines first, so a river bends instead of stepping from cell to cell.
# A river runs on into open water it meets.
static func _cell_lines(grid: Dictionary, first: Vector2i, cells_x: int, cells_y: int, strokes: Array, noise: FastNoiseLite) -> void:
	var px: float = float(grid["px"])
	var c0: Vector2i = grid["c0"]
	var cw: int = int(grid["cw"])
	var ch: int = int(grid["ch"])
	var known: PackedByteArray = grid["known"]
	var water: PackedByteArray = grid["water"]
	var paths: PackedByteArray = grid["paths"]
	var quality: PackedByteArray = grid["quality"]
	var links: Dictionary = {"river": [], "road": [], "path": []}   # kind -> [[cell a, cell b], ...] in grid cell coordinates

	for j in range(first.y, first.y + cells_y):
		for i in range(first.x, first.x + cells_x):
			var n: int = j * cw + i

			if known[n] == 0:
				continue

			var river: bool = water[n] == WATER_RIVER and not _open_water(water, known, cw, ch, i, j)
			var path: int = paths[n]

			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var m: int = (j + d.y) * cw + i + d.x

				if known[m] == 0:
					continue

				var diagonal: bool = d.x != 0 and d.y != 0
				var corner_a: int = j * cw + i + d.x
				var corner_b: int = (j + d.y) * cw + i

				if river and water[m] in [WATER_RIVER, WATER_INLAND, WATER_SEA]:
					if not diagonal or not (water[corner_a] == WATER_RIVER or water[corner_b] == WATER_RIVER):
						links["river"].append([Vector2i(i, j), Vector2i(i, j) + d])

				if path > 0 and paths[m] > 0:
					if not diagonal or not (paths[corner_a] > 0 or paths[corner_b] > 0):
						links["road" if path == 2 and paths[m] == 2 else "path"].append([Vector2i(i, j), Vector2i(i, j) + d])

	var style: Dictionary = {"river": [1.6, 0.8, false], "road": [1.5, 0.8, false], "path": [1.1, 0.7, true]}

	for kind in links:
		for chain in _chain_cells(links[kind]):
			var pts: Array = []

			for cell in chain:
				pts.append((Vector2(c0) + Vector2(cell) + Vector2(0.5, 0.5)) * px)

			var at: Vector2i = chain[chain.size() / 2]
			var q: float = float(quality[clampi(at.y, 0, ch - 1) * cw + clampi(at.x, 0, cw - 1)]) / 100.0
			_ink(strokes, pts, q, noise, float(style[kind][0]), float(style[kind][1]), bool(style[kind][2]))


# Cell links joined into runs of cells: a run goes on through a cell with exactly two links and stops at an end or a fork.
static func _chain_cells(links: Array) -> Array:
	var at: Dictionary = {}   # cell -> [link indices]

	for k in links.size():
		for c in links[k]:
			if not at.has(c):
				at[c] = []

			at[c].append(k)

	var used: PackedByteArray = PackedByteArray()
	used.resize(links.size())
	var runs: Array = []

	for k in links.size():
		if used[k] == 1:
			continue

		used[k] = 1
		var run: Array = [links[k][0], links[k][1]]

		for end in [1, 0]:
			var cell: Vector2i = run[run.size() - 1] if end == 1 else run[0]

			while (at[cell] as Array).size() == 2:
				var next: int = -1

				for other in at[cell]:
					if used[other] == 0:
						next = other

				if next < 0:
					break

				used[next] = 1
				var far: Vector2i = links[next][1] if links[next][0] == cell else links[next][0]

				if end == 1:
					run.append(far)
				else:
					run.push_front(far)

				cell = far

		runs.append(run)

	return runs


# Woods and wet ground: a small tree mark in some cells where trees grow (more where they are thick), and reed tufts on marsh.
static func _cell_marks(grid: Dictionary, first: Vector2i, cells_x: int, cells_y: int, strokes: Array) -> void:
	var px: float = float(grid["px"])
	var c0: Vector2i = grid["c0"]
	var cw: int = int(grid["cw"])
	var known: PackedByteArray = grid["known"]
	var water: PackedByteArray = grid["water"]
	var trees: PackedByteArray = grid["trees"]
	var quality: PackedByteArray = grid["quality"]

	for j in range(first.y, first.y + cells_y):
		for i in range(first.x, first.x + cells_x):
			var n: int = j * cw + i

			if known[n] == 0:
				continue

			var cx: int = c0.x + i
			var cz: int = c0.y + j
			var q: float = float(quality[n]) / 100.0
			var ink: float = lerpf(0.5, 0.85, q)
			var spot: Vector2 = (Vector2(cx, cz) + Vector2(0.2 + 0.6 * _hash01(cx * 31, cz * 17), 0.2 + 0.6 * _hash01(cx * 13, cz * 29))) * px

			if water[n] == WATER_MARSH:
				if _hash01(cx * 7, cz * 5) < 0.55:
					strokes.append([PackedVector2Array([spot + Vector2(-1.3, 0.6), spot + Vector2(1.3, 0.6)]), 0.9, ink * 0.8, false])

					for k in [-1.0, 0.0, 1.0]:
						strokes.append([PackedVector2Array([spot + Vector2(k * 0.4, 0.5), spot + Vector2(k * 0.9, -1.0 + absf(k) * 0.3)]), 0.8, ink * 0.8, false])

				continue

			var t: int = trees[n]

			if t <= 0 or water[n] != 0:
				continue

			# Thin woods: a tree mark in about one cell in seven; thick woods in about half (Dave: "too much detail").
			var share: float = [0.0, 0.15, 0.35, 0.55][t]

			if _hash01(cx * 3 + 1, cz * 11 + 7) >= share:
				continue

			var crown: PackedVector2Array = PackedVector2Array()
			var r: float = 1.25 + 0.35 * _hash01(cx, cz * 3)

			for k in 8:
				var ang: float = PI + TAU * float(k) / 7.0
				var wob: float = 1.0 + 0.18 * sin(float(k) * 2.3 + float(cx))
				crown.append(spot + Vector2(cos(ang), sin(ang) * 0.9) * r * wob + Vector2(0.0, -0.8))

			strokes.append([crown, 0.9, ink, false])
			strokes.append([PackedVector2Array([spot + Vector2(0.0, 0.4), spot + Vector2(0.05, 1.5)]), 0.9, ink, false])


static func _hash01(a: int, b: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 0xffff) / 65535.0
