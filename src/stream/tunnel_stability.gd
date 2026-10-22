extends RefCounted

# Which parts of a block's ground are excavations that need bracing (tech/EXCAVATION_BRACING_GROUND_DESIGN.md, section 1).
# Pure measurement, no timers: classify() looks at one LOD 0 block with every edit applied and returns the "working" cells, the
# roofed open spaces whose span is wider than the roof material can hold on its own. Runs on a worker thread.
#
# A cell is on a 2 m grid in x and z inside the block (every floor voxel in y). It counts when it is air with ground under it (a place you can stand), has a roof in
# the block or solid ground above it up to the surface (open pits and trenches never count), and its span is wider than the free
# span of the roof material. The span is the smaller of the open widths along x and z (a tunnel is narrow one way, a room both
# ways); a width that runs off the block edge is unknown and left out, so cells whose two widths are both unknown are skipped.
#   need = clamp((span x (1 + min(overburden, 20 m) / 20 m) - free_span) / (2 x free_span), 0, 1)
# The cells keep a position, span, overburden, free span and need; the caller joins them across blocks and runs the timers.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const BLOCK := 16
const CELL := 2
const MAX_HEADROOM_M := 8                # a roof higher than this above the floor is a cavern, not worked here
const MIN_COVER_M := 1.5                 # ground above the roof thinner than this is a skin, not an excavation roof
const OVERBURDEN_CAP_M := 20.0           # cover above this adds no more load (the span counts up to double)
const FREE_SPAN_SOIL_M := 2.0            # widest roof loose soil, sand and gravel hold on their own
const FREE_SPAN_ROCK_M := 6.0            # hard rock (the numbers move to data/tunnels.json with the timers)


# buffer: the block's voxels (Layout.make_buffer(16)) with all edits applied; origin: world corner of the block;
# surface_h: Callable (x, z) -> ground surface height there (the generated ground, a pit's air above it never counts).
static func classify(buffer: VoxelBuffer, origin: Vector3, surface_h: Callable) -> Array:
	var found: Array = []

	for cz in range(0, BLOCK, CELL):
		for cx in range(0, BLOCK, CELL):
			var surface: float = float(surface_h.call(origin.x + float(cx), origin.z + float(cz)))

			for cy in range(1, BLOCK):
				if not _air(buffer, cx, cy, cz) or _air(buffer, cx, cy - 1, cz) or surface < origin.y + float(cy) + 1.0:
					continue

				var roof: int = _roof(buffer, cx, cy, cz)
				var roof_y: float = origin.y + float(roof if roof >= 0 else BLOCK)
				var cover: float = surface - roof_y

				if cover < MIN_COVER_M or (roof >= 0 and roof - cy > MAX_HEADROOM_M):
					continue

				var span: float = _span(buffer, cx, cy, cz)

				if span <= 0.0:
					continue

				var soil: bool = roof >= 0 and buffer.get_voxel(cx, roof, cz, Layout.CHANNEL_SOIL) > 0
				var free: float = FREE_SPAN_SOIL_M if soil or roof < 0 else FREE_SPAN_ROCK_M
				var overburden: float = maxf(cover, 0.0)
				var need: float = clampf((span * (1.0 + minf(overburden, OVERBURDEN_CAP_M) / OVERBURDEN_CAP_M) - free) / (2.0 * free), 0.0, 1.0)
				found.append({"pos": origin + Vector3(float(cx), float(cy), float(cz)), "span": span, "overburden": overburden, "free": free, "need": need})

	return found


static func working(cells: Array) -> Array:
	return cells.filter(func(cell): return float(cell["need"]) > 0.0)


static func _air(buffer: VoxelBuffer, x: int, y: int, z: int) -> bool:
	return buffer.get_voxel_f(x, y, z, Layout.CHANNEL_SDF) > 0.0


# Lowest solid voxel above the cell's head inside the block, or -1.
static func _roof(buffer: VoxelBuffer, x: int, y: int, z: int) -> int:
	for roof_y in range(y + 1, BLOCK):
		if not _air(buffer, x, roof_y, z):
			return roof_y

	return -1


# The smaller known open width along x and z at head height (the cell's y + 1), 0 when neither is known.
static func _span(buffer: VoxelBuffer, x: int, y: int, z: int) -> float:
	var head: int = mini(y + 1, BLOCK - 1)
	var wx: float = _width(buffer, x, head, z, 1, 0)
	var wz: float = _width(buffer, x, head, z, 0, 1)

	if wx < 0.0 and wz < 0.0:
		return 0.0

	if wx < 0.0:
		return wz

	if wz < 0.0:
		return wx

	return minf(wx, wz)


# Open width through the cell along (dx, dz), or -1 when the air runs off the block on either side.
static func _width(buffer: VoxelBuffer, x: int, y: int, z: int, dx: int, dz: int) -> float:
	var total: int = 1

	for sign in [1, -1]:
		var n: int = 1

		while true:
			var px: int = x + sign * dx * n
			var pz: int = z + sign * dz * n

			if px < 0 or px >= BLOCK or pz < 0 or pz >= BLOCK:
				return -1.0

			if not _air(buffer, px, y, pz):
				break

			total += 1
			n += 1

	return float(total)
