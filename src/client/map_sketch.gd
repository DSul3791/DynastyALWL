extends RefCounted

# The charcoal sketch of the Map (docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md s1.2-1.3): turns this character's surveyed cells
# (map_knowledge.gd) into charcoal marks on transparent pixels, which the Map page lays over its paper. Unsurveyed ground stays bare
# paper. Each cell is drawn with its own q (the Mapping skill it was surveyed at): low q gives wobblier, lighter, smudgier lines and
# coarser contours (the server already rounded its heights to a coarse step), high q steadier and darker ones. Everything is a function
# of world pixel coordinates and the cells around them, so neighbouring blocks meet without a seam: render_block() is render_rect() over
# one block, with a one-cell border read from the neighbours.

const INK := Color(0.12, 0.11, 0.10)
const CONTOUR_M := 10.0   # one contour line every 10 m of height
const PX := 4             # sketch pixels per map cell (16 m cells: 4 m a pixel)
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# One block's sketch: an Image of block_cells * px square, transparent where nothing is known.
static func render_block(knowledge, block: Vector2i, px: int = PX) -> Image:
	var size: int = knowledge.block_cells * px
	return render_rect(knowledge, Vector2i(block.x * size, block.y * size), Vector2i(size, size), px)


# Any rectangle of world sketch pixels (origin in world pixels: world metres / cell_m * px).
static func render_rect(knowledge, origin: Vector2i, extent: Vector2i, px: int = PX) -> Image:
	var image: Image = Image.create(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# The cells under the rectangle plus a two-cell border (bilinear corners and the contour neighbours).
	var c0: Vector2i = Vector2i(int(floor(float(origin.x) / px)) - 2, int(floor(float(origin.y) / px)) - 2)
	var cw: int = int(ceil(float(extent.x) / px)) + 5
	var ch: int = int(ceil(float(extent.y) / px)) + 5
	var known: PackedByteArray = PackedByteArray()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var water: PackedByteArray = PackedByteArray()
	var quality: PackedByteArray = PackedByteArray()
	var trees: PackedByteArray = PackedByteArray()
	known.resize(cw * ch)
	heights.resize(cw * ch)
	water.resize(cw * ch)
	quality.resize(cw * ch)
	trees.resize(cw * ch)
	var any: bool = false

	for j in ch:
		for i in cw:
			var cell: Array = knowledge.cell_at(Vector2i(c0.x + i, c0.y + j))
			var n: int = j * cw + i

			if cell.is_empty():
				continue

			any = true
			known[n] = 1
			quality[n] = int(cell[0])
			heights[n] = float(cell[1])
			water[n] = int(cell[2])
			trees[n] = int(cell[3])

	if not any:
		return image

	# Unknown cells borrow a known neighbour's height, so a slope does not plunge to 0 at the edge of the known ground.
	for j in ch:
		for i in cw:
			var n: int = j * cw + i

			if known[n] == 1:
				continue

			for d in SIDES:
				var a: int = i + d.x
				var b: int = j + d.y

				if a >= 0 and b >= 0 and a < cw and b < ch and known[b * cw + a] == 1:
					heights[n] = heights[b * cw + a]
					break

	# The height under every pixel (one pixel of margin for the contour test), from the four cell centres around it, wobbled by q.
	var fw: int = extent.x + 1
	var fh: int = extent.y + 1
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(fw * fh)
	var inv: float = 1.0 / float(px)

	for y in fh:
		for x in fw:
			var wx: int = origin.x + x
			var wy: int = origin.y + y
			var ci: int = int(floor(float(wx) * inv)) - c0.x
			var cj: int = int(floor(float(wy) * inv)) - c0.y
			var wob: float = _wobble(quality[cj * cw + ci], wx, wy)
			var u: float = (float(wx) + 0.5) * inv - 0.5 - float(c0.x) + wob
			var v: float = (float(wy) + 0.5) * inv - 0.5 - float(c0.y) + _wobble(quality[cj * cw + ci], wy + 7919, wx)
			field[y * fw + x] = _bilinear(heights, cw, ch, u, v)

	for y in extent.y:
		for x in extent.x:
			var wx: int = origin.x + x
			var wy: int = origin.y + y
			var ci: int = int(floor(float(wx) * inv)) - c0.x
			var cj: int = int(floor(float(wy) * inv)) - c0.y
			var n: int = cj * cw + ci

			if known[n] == 0:
				continue

			var q: float = float(quality[n]) / 100.0
			var clarity: float = lerpf(0.55, 1.0, q)
			var h: float = field[y * fw + x]
			var hx: float = field[y * fw + x + 1]
			var hy: float = field[(y + 1) * fw + x]
			var ink: float = 0.07   # the light wash that says "surveyed"
			var wet: int = water[n]

			if wet != 0:
				ink += 0.12

				if wy % 5 == 0 and sin(float(wx) * 0.55 + float(wy)) > -0.2:
					ink += 0.25 * clarity   # ripple strokes on water

				for d in SIDES:
					var m: int = (cj + d.y) * cw + ci + d.x

					if known[m] == 1 and water[m] != wet and _near_edge(wx, wy, px, d):
						ink += 0.55 * clarity   # the shore line
						break
			else:
				# Hill hatching: light from the north-west; the steeper the shadowed side, the closer the strokes.
				var shade: float = clampf(((hx - h) + (hy - h)) * 0.35, 0.0, 1.0)

				if shade > 0.12:
					var spacing: int = maxi(6 - int(shade * 4.0), 2)

					if posmod(wx + wy, spacing) == 0:
						ink += 0.35 * clarity

				if floor(h / CONTOUR_M) != floor(hx / CONTOUR_M) or floor(h / CONTOUR_M) != floor(hy / CONTOUR_M):
					ink += 0.4 * clarity

				var t: int = trees[n]

				if t > 0 and _tree_mark(ci + c0.x, cj + c0.y, t, wx, wy, px, q):
					ink += 0.55 * clarity

			# The edge of the known ground fades out over the outer half of an edge cell instead of a hard line.
			var fade: float = _fade(known, cw, ch, ci, cj, wx, wy, px)
			var grain: float = 0.85 + 0.3 * _hash01(wx, wy)
			var alpha: float = clampf(ink * grain, 0.0, 1.0) * fade

			if alpha > 0.004:
				image.set_pixel(x, y, Color(INK.r, INK.g, INK.b, alpha))

	return image


# A smooth sideways wobble in cells: about 0.45 of a cell at Mapping 1, nothing at 100 (a steady hand draws where things are).
static func _wobble(q: int, a: int, b: int) -> float:
	var amp: float = 0.45 * (1.0 - clampf(float(q) / 100.0, 0.0, 1.0))
	return amp * sin(float(b) * 0.21 + float(a) * 0.05) * cos(float(a) * 0.033)


static func _bilinear(heights: PackedFloat32Array, cw: int, ch: int, u: float, v: float) -> float:
	var i: int = clampi(int(floor(u)), 0, cw - 2)
	var j: int = clampi(int(floor(v)), 0, ch - 2)
	var fu: float = clampf(u - float(i), 0.0, 1.0)
	var fv: float = clampf(v - float(j), 0.0, 1.0)
	var top: float = lerpf(heights[j * cw + i], heights[j * cw + i + 1], fu)
	var bottom: float = lerpf(heights[(j + 1) * cw + i], heights[(j + 1) * cw + i + 1], fu)
	return lerpf(top, bottom, fv)


# Whether pixel (wx, wy) lies in the outer pixel of its cell on side d (the shore line is drawn on the water side of the edge).
static func _near_edge(wx: int, wy: int, px: int, d: Vector2i) -> bool:
	var lx: int = posmod(wx, px)
	var ly: int = posmod(wy, px)
	return (d.x == 1 and lx == px - 1) or (d.x == -1 and lx == 0) or (d.y == 1 and ly == px - 1) or (d.y == -1 and ly == 0)


static func _fade(known: PackedByteArray, cw: int, ch: int, ci: int, cj: int, wx: int, wy: int, px: int) -> float:
	var lx: float = (float(posmod(wx, px)) + 0.5) / float(px)
	var ly: float = (float(posmod(wy, px)) + 0.5) / float(px)
	var f: float = 1.0

	if ci + 1 < cw and known[cj * cw + ci + 1] == 0:
		f = minf(f, clampf((1.0 - lx) * 2.0, 0.0, 1.0))

	if ci > 0 and known[cj * cw + ci - 1] == 0:
		f = minf(f, clampf(lx * 2.0, 0.0, 1.0))

	if cj + 1 < ch and known[(cj + 1) * cw + ci] == 0:
		f = minf(f, clampf((1.0 - ly) * 2.0, 0.0, 1.0))

	if cj > 0 and known[(cj - 1) * cw + ci] == 0:
		f = minf(f, clampf(ly * 2.0, 0.0, 1.0))

	return lerpf(0.35, 1.0, f)


# A few small tree scribbles in a cell (t = 1..3 density): their places come from the cell, shaken more at low skill.
static func _tree_mark(cx: int, cz: int, t: int, wx: int, wy: int, px: int, q: float) -> bool:
	var base: Vector2 = Vector2(float(cx * px), float(cz * px))

	for k in t:
		var spot: Vector2 = base + Vector2(_hash01(cx * 31 + k, cz * 17), _hash01(cx * 13, cz * 29 + k)) * float(px)
		spot += Vector2(_hash01(cx + k * 7, cz), _hash01(cx, cz + k * 11)) * (1.0 - q) * 1.5

		if spot.distance_squared_to(Vector2(float(wx) + 0.5, float(wy) + 0.5)) <= 1.2:
			return true

	return false


static func _hash01(a: int, b: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 0xffff) / 65535.0
