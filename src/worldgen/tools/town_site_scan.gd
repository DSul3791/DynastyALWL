extends SceneTree

# Measures how buildable and natural the ground is in town-sized circles on one tile and lists the best
# candidate spots (nothing is written). Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/town_site_scan.gd -- --tile=3,4
#
# Options (after "--"):
#   --tile=X,Z     tile coordinate (default 3,4)
#   --radius=M     town circle radius in meters (default 300)
#   --step=M       distance between candidate centers (default 240)
#   --top=N        how many candidates to print (default 12)
#   --at=E,S       measure only this spot, meters east and north of the tile's south-west corner
#   --world=DIR    world folder (default res://worlds/base_world)
#
# Per circle: land share, lowest ground, average grade across the circle (the town may climb inland),
# the 90th percentile of the local slope, the share of ground at or under BUILDABLE_PCT, and the
# relief (height spread after the average grade is taken out) that makes it read as rolling and not flat.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")

const TILE_M := 15360.0
const SPACING := 8.0
const PLAIN_SAMPLES := 1921
const BUILDABLE_PCT := 8.0     # local slope (percent) still easy to build on
const MIN_HEIGHT_M := 1.0      # town ground stays at least this far above the sea
const STRIDE := 2              # sample every 2nd cell inside a circle (16 m)


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var radius: float = 300.0
	var step: float = 240.0
	var top: int = 12
	var world_dir: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(-1.0, -1.0)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--radius="):
			radius = float(argument.trim_prefix("--radius="))
		elif argument.begins_with("--step="):
			step = float(argument.trim_prefix("--step="))
		elif argument.begins_with("--top="):
			top = int(argument.trim_prefix("--top="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--at="):
			var parts: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(parts[0]), float(parts[1]))

	quit(_run(world_dir, tile, radius, step, top, at))


func _run(world_dir: String, tile: Vector2i, radius: float, step: float, top: int, at: Vector2) -> int:
	var baker = TileBakerScript.new()
	var problem: String = baker.setup(world_dir, 0.0)

	if problem != "":
		push_error(problem)
		return 1

	var result: Dictionary = baker.bake(tile)
	var grid: PackedFloat32Array = result["water"].heights
	var side: int = int(result["height"].samples)
	var margin: int = (side - PLAIN_SAMPLES) / 2
	print("Tile %s baked: %d samples a side, margin %d" % [str(tile), side, margin])
	_texture(grid, side)
	var slope: PackedFloat32Array = _slopes(grid, side)
	var found: Array = []

	if at.x >= 0.0:
		found.append(_measure(grid, slope, side, margin, at.x, at.y, radius))
	else:
		var low: float = radius + SPACING * 2.0
		var east: float = low

		while east <= TILE_M - low:
			var north: float = low

			while north <= TILE_M - low:
				var sample_index: int = (margin + int(round(north / SPACING))) * side + margin + int(round(east / SPACING))

				if grid[sample_index] >= MIN_HEIGHT_M:
					var entry: Dictionary = _measure(grid, slope, side, margin, east, north, radius)

					if entry["land"] >= 0.98:
						found.append(entry)

				north += step

			east += step

	found.sort_custom(func(a, b): return a["score"] > b["score"])
	print("east_m north_m | land low_m  avg_grade% (dir) | p90_slope% buildable% relief_m | score")

	for k in range(mini(top, found.size())):
		var e: Dictionary = found[k]
		print("%6d %6d | %.2f %5.1f %5.1f %s | %5.1f %5.0f %5.2f | %.2f" % [
			e["east"], e["north"], e["land"], e["low"], e["grade"], e["dir"],
			e["p90"], e["buildable"] * 100.0, e["relief"], e["score"]
		])

	print("%d candidate circles of radius %.0f m measured" % [found.size(), radius])
	return 0


# How bumpy the ground is at human scales, by height band: the mean height change over a distance
# (lag), as a percent grade, going east and going north. A number near 0 at a lag means the ground
# is flat at that scale; a big gap between east and north means the hills run one way only.
func _texture(grid: PackedFloat32Array, side: int) -> void:
	var bands: Array = [[1.0, 30.0], [30.0, 120.0], [120.0, 400.0], [400.0, 5000.0]]
	var lags: Array = [2, 4, 8, 16, 40]
	var reach: int = 40
	print("ground texture: mean grade %% over a lag, east / north   (lag m: %s)" % str(lags.map(func(l): return l * 8)))

	for band in bands:
		var sums: Array = []

		for _l in lags:
			sums.append([0.0, 0.0])

		var count: int = 0

		for row in range(reach, side - reach, 5):
			for col in range(reach, side - reach, 5):
				var h: float = grid[row * side + col]

				if h < float(band[0]) or h >= float(band[1]):
					continue

				count += 1

				for index in range(lags.size()):
					var lag: int = int(lags[index])
					sums[index][0] += absf(grid[row * side + col + lag] - h)
					sums[index][1] += absf(grid[(row + lag) * side + col] - h)

		if count == 0:
			continue

		var text: String = ""

		for index in range(lags.size()):
			var metres: float = float(lags[index]) * SPACING
			text += "  %4.1f / %4.1f" % [100.0 * sums[index][0] / float(count) / metres, 100.0 * sums[index][1] / float(count) / metres]

		print("  height %4.0f to %4.0f m (%6d pts):%s" % [band[0], band[1], count, text])


# Local slope in percent at every sample (central difference over 16 m).
func _slopes(grid: PackedFloat32Array, side: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(grid.size())

	for row in range(1, side - 1):
		var base: int = row * side

		for col in range(1, side - 1):
			var dx: float = grid[base + col + 1] - grid[base + col - 1]
			var dz: float = grid[base + col + side] - grid[base + col - side]
			out[base + col] = sqrt(dx * dx + dz * dz) / (2.0 * SPACING) * 100.0

	return out


func _measure(grid: PackedFloat32Array, slope: PackedFloat32Array, side: int, margin: int, east: float, north: float, radius: float) -> Dictionary:
	var cc: int = margin + int(round(east / SPACING))
	var cr: int = margin + int(round(north / SPACING))
	var reach: int = int(radius / SPACING)
	var count: int = 0
	var land: int = 0
	var sum_h: float = 0.0
	var sum_hh: float = 0.0
	var sum_dx_h: float = 0.0
	var sum_dz_h: float = 0.0
	var sum_dd: float = 0.0
	var low: float = INF
	var good: int = 0
	var slopes: Array = []

	for dr in range(-reach, reach + 1, STRIDE):
		for dc in range(-reach, reach + 1, STRIDE):
			if float(dr * dr + dc * dc) > float(reach * reach):
				continue

			var k: int = (cr + dr) * side + cc + dc
			var h: float = grid[k]
			count += 1
			sum_h += h
			sum_hh += h * h
			sum_dx_h += float(dc) * SPACING * h
			sum_dz_h += float(dr) * SPACING * h
			sum_dd += float(dc * dc) * SPACING * SPACING
			low = minf(low, h)

			if h >= MIN_HEIGHT_M:
				land += 1

			slopes.append(slope[k])

			if slope[k] <= BUILDABLE_PCT:
				good += 1

	var n: float = float(maxi(count, 1))
	var mean_h: float = sum_h / n
	var gx: float = sum_dx_h / maxf(sum_dd, 1.0)
	var gz: float = sum_dz_h / maxf(sum_dd, 1.0)
	var variance: float = sum_hh / n - mean_h * mean_h
	var residual: float = maxf(variance - (gx * gx + gz * gz) * sum_dd / n, 0.0)
	var grade: float = sqrt(gx * gx + gz * gz) * 100.0
	slopes.sort()
	var p90: float = float(slopes[int(float(slopes.size() - 1) * 0.9)]) if not slopes.is_empty() else 0.0
	var relief: float = sqrt(residual)
	var heading: float = rad_to_deg(atan2(gz, gx))
	var names: Array = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
	var buildable: float = float(good) / n
	# Prefer buildable ground that still has some relief and a mild grade (1 to 5 percent), fully on land.
	var score: float = buildable * 2.0 - p90 / 20.0 - absf(relief - 0.9) * 0.4 - maxf(grade - 5.0, 0.0) * 0.1 - maxf(1.0 - grade, 0.0) * 0.3

	return {
		"east": east, "north": north, "land": float(land) / n, "low": low, "grade": grade,
		"dir": names[int(round(fposmod(heading, 360.0) / 45.0)) % 8], "p90": p90,
		"buildable": buildable, "relief": relief, "score": score,
	}
