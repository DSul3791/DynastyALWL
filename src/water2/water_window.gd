extends RefCounted

# A square window of a baked tile as a water field (Sonny, 31 Oct 2026, dynasty-water stage b). Read only: the tile is never changed.
# Reuses TileFile (header, height step, sections) and TileTerrainData (_load_sim_water, the settled water of the .water file); the 8 m grid of the heights is the sim grid, no resampling.

const Field := preload("res://src/water2/water_field.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TF := preload("res://src/worldgen/tile/tile_file.gd")


# The whole tile: {heights, levels (NaN where dry), samples, cell_m} or {} when the tile cannot be read.
static func read_tile(tile_path: String) -> Dictionary:
	var head: Dictionary = TF.read_header(tile_path)

	if not bool(head["ok"]):
		return {}

	var n: int = int(head["header"]["samples"])
	var data = TileTerrainData.new()
	data.samples = n
	data.heights = TF.decode_height(TF.read_section(tile_path, head["table"], "height")["raw"], TF.height_step_of(head["header"]))
	data._load_sim_water(tile_path)
	return {"heights": data.heights, "levels": data.sim_levels, "samples": n, "cell_m": 8.0}   # shortcut: 8 m assumed as in every baked tile; read it from the header if tiles ever change


# The size x size window starting at cell (i0, j0): bed from the heights, depth from the settled levels (0 where the file has no water).
static func window(tile: Dictionary, i0: int, j0: int, size: int, traits = null):
	var n: int = int(tile["samples"])
	var bed: PackedFloat32Array = PackedFloat32Array()
	bed.resize(size * size)

	for j in range(size):
		for i in range(size):
			bed[j * size + i] = tile["heights"][(j0 + j) * n + i0 + i]

	var f = Field.new(size, size, float(tile["cell_m"]), bed, traits)

	for j in range(size):
		for i in range(size):
			var level: float = tile["levels"][(j0 + j) * n + i0 + i]

			if not is_nan(level):
				f.depth[j * size + i] = maxf(0.0, level - bed[j * size + i])

	f.wake_all()
	return f


# The window of the given size holding the most wet cells, searched on a half-window stride: {i0, j0, wet}.
static func wettest(tile: Dictionary, size: int) -> Dictionary:
	var n: int = int(tile["samples"])
	var best: Dictionary = {"i0": 0, "j0": 0, "wet": -1}
	var step: int = size / 2

	for j0 in range(0, n - size, step):
		for i0 in range(0, n - size, step):
			var wet: int = 0

			for j in range(j0, j0 + size, 4):
				for i in range(i0, i0 + size, 4):
					if not is_nan(tile["levels"][j * n + i]):
						wet += 1

			if wet > int(best["wet"]):
				best = {"i0": i0, "j0": j0, "wet": wet}

	return best
