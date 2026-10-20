extends RefCounted

# The shared cover query (Technical direction spec COVER_QUERY.md, owner rules 2026-10-20):
# a spot is covered when it lies under any tree's canopy, a yes/no with one fixed mild value
# whatever the tree or the season. Rain soaks the ground everywhere except under canopies;
# cover is only mild shelter from sun and rain (not heat or cold). Roofs can add to `at` later.
#
# `Cover.at(pos, index)` returns 0.0 (open) or 1.0 (covered). Horizontal test only: (x, z)
# inside a crown circle (the table's crown_m / 2, grown with the tree's size) and pos.y no
# higher than the treetop. The index is a 16 m hash grid of crown circles that both the
# client (flora_view, from its chunk plans) and the server (server_flora, from the same
# placer list) fill from the flora they hold, so they agree. Felled trees leave the index.
# No save, no network traffic. Not thread safe by itself: the server wraps calls in a mutex.

const CELL_M := 16.0
const KIND_TREE := 0
const SIZE_MIN := 0.3                     # tree size scale limits, as the placer's spacing (young trees small)
const SIZE_MAX := 1.2


static func at(pos: Vector3, index) -> float:
	return 1.0 if index != null and index.covers(pos) else 0.0


# Fills an index chunk from an item list (FloraPlacer.chunk_items form: ids, positions,
# heights). `info` is a Callable(species_id) -> Array [kind, crown_m, reference_height_m]
# (empty for unknown species).
static func add_chunk(index, chunk: Vector2i, items: Dictionary, info: Callable) -> void:
	var ids: PackedInt32Array = items["ids"]
	var trees: Array = []

	for n in range(ids.size()):
		var row: Array = info.call(ids[n] >> 16)

		if row.is_empty() or int(row[0]) != KIND_TREE:
			continue

		var height: float = float(items["heights"][n])
		var scale: float = clampf(height / maxf(float(row[2]), 0.1), SIZE_MIN, SIZE_MAX)
		var p: Vector3 = items["positions"][n]
		trees.append([ids[n], p.x, p.z, float(row[1]) * 0.5 * scale, p.y + height])

	index.set_chunk(chunk, trees)


class Index:
	extends RefCounted

	# cell -> {"f": PackedFloat32Array of x, z, radius, top per tree, "k": PackedInt64Array of keys}
	var _cells: Dictionary = {}
	var _chunk_cells: Dictionary = {}     # chunk -> Array of cells it put trees in
	var trees: int = 0


	static func _chunk_key(chunk: Vector2i) -> int:
		return ((chunk.x & 0xFFFFF) << 20) | (chunk.y & 0xFFFFF)


	# Replaces a chunk's trees. `list` rows: [id, x, z, crown_radius, top_y].
	func set_chunk(chunk: Vector2i, list: Array) -> void:
		remove_chunk(chunk)

		if list.is_empty():
			return

		var base: int = _chunk_key(chunk) << 24
		var cells: Dictionary = {}

		for row in list:
			var radius: float = float(row[3])

			if radius <= 0.0:
				continue

			var x: float = float(row[1])
			var z: float = float(row[2])
			var cell: Vector2i = Vector2i(int(floor(x / CELL_M)), int(floor(z / CELL_M)))

			if not _cells.has(cell):
				_cells[cell] = {"f": PackedFloat32Array(), "k": PackedInt64Array()}

			var entry: Dictionary = _cells[cell]
			entry["f"].append_array(PackedFloat32Array([x, z, radius, float(row[4])]))
			entry["k"].append(base | (int(row[0]) & 0xFFFFFF))
			cells[cell] = true
			trees += 1

		_chunk_cells[chunk] = cells.keys()


	func remove_chunk(chunk: Vector2i) -> void:
		var cells: Array = _chunk_cells.get(chunk, [])
		var base: int = _chunk_key(chunk)

		for cell in cells:
			_filter(cell, func(key: int) -> bool: return (key >> 24) == base)

		_chunk_cells.erase(chunk)


	# Felling: the tree with this item id leaves the index, so the ground opens up.
	func remove_item(chunk: Vector2i, id: int) -> void:
		var want: int = (_chunk_key(chunk) << 24) | (id & 0xFFFFFF)

		for cell in _chunk_cells.get(chunk, []):
			_filter(cell, func(key: int) -> bool: return key == want)


	func _filter(cell: Vector2i, drop: Callable) -> void:
		var entry: Dictionary = _cells.get(cell, {})

		if entry.is_empty():
			return

		var f: PackedFloat32Array = PackedFloat32Array()
		var k: PackedInt64Array = PackedInt64Array()

		for n in range(entry["k"].size()):
			if drop.call(entry["k"][n]):
				trees -= 1
				continue

			f.append_array(entry["f"].slice(n * 4, n * 4 + 4))
			k.append(entry["k"][n])

		if k.is_empty():
			_cells.erase(cell)
		else:
			entry["f"] = f
			entry["k"] = k


	# The crown circles within `range_m` of (x, z), as [x, z, radius, top_y] rows, for drawing
	# maps (the ground wetness and rain streak mask) from the same index the query uses.
	func discs_near(x: float, z: float, range_m: float) -> Array:
		var found: Array = []
		var reach: int = int(ceil(range_m / CELL_M)) + 1
		var cx: int = int(floor(x / CELL_M))
		var cz: int = int(floor(z / CELL_M))

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var entry: Dictionary = _cells.get(Vector2i(cx + dx, cz + dz), {})

				if entry.is_empty():
					continue

				var f: PackedFloat32Array = entry["f"]

				for n in range(0, f.size(), 4):
					if absf(f[n] - x) <= range_m + f[n + 2] and absf(f[n + 1] - z) <= range_m + f[n + 2]:
						found.append([f[n], f[n + 1], f[n + 2], f[n + 3]])

		return found


	func chunk_count() -> int:
		return _chunk_cells.size()


	func covers(pos: Vector3) -> bool:
		var cx: int = int(floor(pos.x / CELL_M))
		var cz: int = int(floor(pos.z / CELL_M))

		# A crown (a few metres of radius) reaches at most one cell beyond its own.
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var entry: Dictionary = _cells.get(Vector2i(cx + dx, cz + dz), {})

				if entry.is_empty():
					continue

				var f: PackedFloat32Array = entry["f"]

				for n in range(0, f.size(), 4):
					var ox: float = pos.x - f[n]
					var oz: float = pos.z - f[n + 1]

					if ox * ox + oz * oz <= f[n + 2] * f[n + 2] and pos.y <= f[n + 3]:
						return true

		return false
