class_name ReliefPreview
extends RefCounted

# Draws the world elevation map as a shaded-relief map: hill shading lit
# from the northwest, land colored by climate and height, sea tinted by
# depth, polar pack ice, lava in the crater, a faint tile grid and the
# starter tiles outlined (yellow inner, orange outer). North is up.

const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")

const SAND := Color(0.84, 0.76, 0.52)
const SCRUB := Color(0.66, 0.62, 0.38)
const JUNGLE := Color(0.10, 0.40, 0.15)
const MEADOW := Color(0.42, 0.62, 0.30)
const FOREST := Color(0.25, 0.46, 0.24)
const TUNDRA := Color(0.50, 0.50, 0.40)
const SNOW := Color(0.94, 0.95, 0.97)
const ROCK := Color(0.47, 0.44, 0.41)
const LAVA := Color(0.95, 0.38, 0.06)


static func render(settings, elevation, show_grid: bool = true) -> Image:
	var width: int = elevation.size_x
	var height: int = elevation.size_z
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	var cell: float = elevation.cell_m
	var light: Vector3 = Vector3(-1.0, 1.3, -1.0).normalized()
	var center_owner: int = elevation.feature_ids.find("center_island")
	var tile_cells: int = int(round(float(settings.tile_size_m) / cell))

	for row in range(height):
		var z_m: float = elevation.origin_z + (float(row) + 0.5) * cell
		var sea_temperature: float = settings.temperature_c(z_m, 0.0)

		for column in range(width):
			var index: int = row * width + column
			var h: float = elevation.heights[index]
			var east: float = elevation.heights[elevation.index_of(column + 1, row)]
			var west: float = elevation.heights[elevation.index_of(column - 1, row)]
			var south: float = elevation.heights[elevation.index_of(column, row + 1)]
			var north: float = elevation.heights[elevation.index_of(column, row - 1)]
			var exaggeration: float = 3.0 if h > 0.0 else 1.2
			var normal: Vector3 = Vector3(
				-(east - west) / (2.0 * cell) * exaggeration,
				1.0,
				-(south - north) / (2.0 * cell) * exaggeration
			).normalized()
			var shade: float = maxf(normal.dot(light), 0.0)
			var color: Color

			if h > 0.0:
				color = _land_color(settings, elevation, index, z_m, h, center_owner)
				color = color * (0.45 + 0.75 * shade)
			else:
				color = _sea_color(-h)
				color = color * (0.80 + 0.30 * shade)

				# Pack ice with a ragged edge (the real ice is worked out at
				# runtime from the season; this shows the permanent pack).
				var ragged: float = sea_temperature + 3.5 * ElevationScript._value(elevation._detail, index)

				if ragged < -11.0:
					var ice: float = clampf((-11.0 - ragged) / 3.0, 0.0, 1.0)
					color = color.lerp(SNOW, 0.8 * ice)

			if show_grid and (column % tile_cells == 0 or row % tile_cells == 0):
				color = color.lerp(Color(1, 1, 1), 0.10)

			color.a = 1.0
			image.set_pixel(column, row, color)

	_outline_starters(image, settings, tile_cells)
	return image


static func _land_color(
	settings, elevation, index: int, z_m: float, h: float, center_owner: int
) -> Color:
	if elevation.special[index] == ElevationScript.SPECIAL_LAVA:
		return LAVA

	if h < 5.0:
		return SAND

	var temperature: float = settings.temperature_c(z_m, h)
	var moisture: float = 0.5 + 0.5 * ElevationScript._value(elevation._hills, index)
	var color: Color

	if elevation.owners[index] == center_owner and center_owner >= 0 and h < 900.0:
		color = JUNGLE
	elif temperature >= 24.0:
		color = SAND.lerp(SCRUB, moisture)
	elif temperature >= 15.0:
		color = SCRUB.lerp(MEADOW, clampf((24.0 - temperature) / 9.0, 0.0, 1.0))
	elif temperature >= 5.0:
		color = MEADOW.lerp(FOREST, clampf((15.0 - temperature) / 10.0, 0.0, 1.0))
	elif temperature >= -3.0:
		color = FOREST.lerp(TUNDRA, clampf((5.0 - temperature) / 8.0, 0.0, 1.0))
	else:
		color = TUNDRA.lerp(SNOW, clampf((-3.0 - temperature) / 5.0, 0.0, 1.0))

	if h > 600.0 and temperature > -3.0:
		color = color.lerp(ROCK, clampf((h - 600.0) / 700.0, 0.0, 0.85))

	return color


static func _sea_color(depth: float) -> Color:
	var stops: Array = [
		[0.0, Color(0.42, 0.80, 0.80)],
		[40.0, Color(0.22, 0.62, 0.74)],
		[200.0, Color(0.13, 0.42, 0.66)],
		[1200.0, Color(0.07, 0.24, 0.48)],
		[2100.0, Color(0.04, 0.14, 0.34)],
		[2800.0, Color(0.01, 0.04, 0.14)],
	]

	for index in range(1, stops.size()):
		if depth <= float(stops[index][0]):
			var low: float = float(stops[index - 1][0])
			var high: float = float(stops[index][0])
			var t: float = (depth - low) / maxf(high - low, 1.0)
			return (stops[index - 1][1] as Color).lerp(stops[index][1], t)

	return stops[stops.size() - 1][1]


static func _outline_starters(image: Image, settings, tile_cells: int) -> void:
	for set_name in settings.starter_tiles.keys():
		var color: Color = Color(1.0, 0.86, 0.0) if set_name == "inner" else Color(1.0, 0.55, 0.0)

		for tile in settings.starter_tiles[set_name]:
			var left: int = (tile.x - settings.min_tile) * tile_cells
			var top: int = (tile.y - settings.min_tile) * tile_cells
			var thickness: int = 3
			image.fill_rect(Rect2i(left, top, tile_cells, thickness), color)
			image.fill_rect(Rect2i(left, top + tile_cells - thickness, tile_cells, thickness), color)
			image.fill_rect(Rect2i(left, top, thickness, tile_cells), color)
			image.fill_rect(Rect2i(left + tile_cells - thickness, top, thickness, tile_cells), color)
