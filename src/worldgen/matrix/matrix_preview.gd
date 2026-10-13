class_name MatrixPreview
extends RefCounted

# Draws the whole-world plan as one image: climate-tinted sea, every
# island at its planned position and size, and markers for starter
# tiles, island chains and the tiles added near starters.
#
# North is up. The strip on the left shows each row's climate zone.
#
# Marker key
#   yellow border   inner starter tile        orange border  outer starter tile
#   red square      volcanic arc tile         white square   island chain tile
#   cyan square     tile added near a starter for medium islands

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const STRIP_WIDTH := 28

const ZONE_COLORS := {
	"desert": Color(0.90, 0.78, 0.45),
	"transition_desert": Color(0.74, 0.74, 0.38),
	"temperate": Color(0.42, 0.67, 0.35),
	"transition_arctic": Color(0.66, 0.78, 0.78),
	"arctic": Color(0.96, 0.96, 0.98),
}

const CHARACTER_COLORS := {
	"flat": Color(0.78, 0.72, 0.42),
	"rolling": Color(0.34, 0.62, 0.30),
	"mountainous": Color(0.46, 0.46, 0.48),
	"volcanic": Color(0.55, 0.22, 0.16),
	"archipelago": Color(0.28, 0.60, 0.46),
}

const BEACH_COLOR := Color(0.86, 0.80, 0.58)
const ICE_COLOR := Color(0.95, 0.97, 1.0)


# Returns an RGB8 image.
static func render(settings, matrix, pixels_per_tile: int = 96) -> Image:
	var tiles_x: int = settings.tiles_x
	var tiles_z: int = settings.tiles_z
	var width: int = STRIP_WIDTH + tiles_x * pixels_per_tile
	var height: int = tiles_z * pixels_per_tile
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))

	var meters_per_pixel: float = float(settings.tile_size_m) / float(pixels_per_tile)

	for tile_z in range(settings.min_tile, settings.get_max_tile_z() + 1):
		var row: int = tile_z - settings.min_tile
		var zone_id: String = settings.get_zone_id_for_row(tile_z)
		var sea_color: Color = _sea_color(settings.temperature_for_row_c(tile_z))

		image.fill_rect(
			Rect2i(0, row * pixels_per_tile, STRIP_WIDTH - 4, pixels_per_tile),
			ZONE_COLORS[zone_id]
		)

		for tile_x in range(settings.min_tile, settings.get_max_tile_x() + 1):
			var column: int = tile_x - settings.min_tile
			var origin: Vector2i = Vector2i(
				STRIP_WIDTH + column * pixels_per_tile, row * pixels_per_tile
			)
			image.fill_rect(
				Rect2i(origin.x, origin.y, pixels_per_tile, pixels_per_tile), sea_color
			)

			# Tile grid line (west and north edge).
			var grid_color: Color = sea_color.darkened(0.18)
			image.fill_rect(Rect2i(origin.x, origin.y, pixels_per_tile, 1), grid_color)
			image.fill_rect(Rect2i(origin.x, origin.y, 1, pixels_per_tile), grid_color)

			var cell: Dictionary = matrix.get_cell(tile_x, tile_z)

			if cell.is_empty():
				continue

			var center: Vector2 = Vector2(
				float(origin.x) + float(pixels_per_tile) * 0.5,
				float(origin.y) + float(pixels_per_tile) * 0.5
			)

			for island in cell["islands"]:
				_draw_island(image, island, center, meters_per_pixel)

			_draw_markers(image, cell, origin, pixels_per_tile)

	return image


static func _sea_color(temperature_c: float) -> Color:
	var warm: Color = Color(0.10, 0.56, 0.62)
	var mild: Color = Color(0.08, 0.38, 0.62)
	var cold: Color = Color(0.26, 0.50, 0.72)
	var ice: Color = Color(0.72, 0.84, 0.92)

	if temperature_c >= 25.0:
		return warm

	if temperature_c >= 12.0:
		return mild.lerp(warm, (temperature_c - 12.0) / 13.0)

	if temperature_c >= 0.0:
		return cold.lerp(mild, temperature_c / 12.0)

	return ice.lerp(cold, clampf((temperature_c + 12.0) / 12.0, 0.0, 1.0))


static func _draw_island(
	image: Image, island: Dictionary, center: Vector2, meters_per_pixel: float
) -> void:
	var a: float = float(island["semi_axis_a_m"])
	var b: float = float(island["semi_axis_b_m"])
	var rot: float = deg_to_rad(float(island["rotation_deg"]))
	var cos_r: float = cos(rot)
	var sin_r: float = sin(rot)
	var center_x: float = float(island["center_x"])
	var center_z: float = float(island["center_z"])
	var shape: String = str(island["shape"])
	var glaciated: bool = bool(island["glaciated"])
	var base_color: Color = CHARACTER_COLORS.get(
		str(island["character"]), CHARACTER_COLORS["rolling"]
	)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(island["seed"])
	noise.frequency = 0.0007
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var reach: float = a * 1.25
	var first_x: int = int(floor(center.x + (center_x - reach) / meters_per_pixel))
	var last_x: int = int(ceil(center.x + (center_x + reach) / meters_per_pixel))
	var first_y: int = int(floor(center.y + (center_z - reach) / meters_per_pixel))
	var last_y: int = int(ceil(center.y + (center_z + reach) / meters_per_pixel))

	for pixel_y in range(first_y, last_y + 1):
		for pixel_x in range(first_x, last_x + 1):
			if pixel_x < 0 or pixel_y < 0:
				continue

			if pixel_x >= image.get_width() or pixel_y >= image.get_height():
				continue

			var world_x: float = (float(pixel_x) + 0.5 - center.x) * meters_per_pixel
			var world_z: float = (float(pixel_y) + 0.5 - center.y) * meters_per_pixel
			var dx: float = world_x - center_x
			var dz: float = world_z - center_z
			var local_x: float = dx * cos_r + dz * sin_r
			var local_z: float = -dx * sin_r + dz * cos_r
			var rho: float = sqrt(
				(local_x * local_x) / (a * a) + (local_z * local_z) / (b * b)
			)

			if rho > 1.3:
				continue

			var ragged: float = noise.get_noise_2d(world_x, world_z)
			var limit: float = 0.95 + 0.22 * ragged

			if shape == "crescent":
				var bite_x: float = local_x
				var bite_z: float = local_z - 0.62 * b
				var bite_radius: float = 0.85 * b

				if bite_x * bite_x + bite_z * bite_z < bite_radius * bite_radius:
					continue

			if rho > limit:
				continue

			var color: Color = base_color
			var inland: float = clampf(1.0 - rho / limit, 0.0, 1.0)

			if inland < 0.12:
				color = BEACH_COLOR
			else:
				color = base_color.lightened(0.18 * inland).darkened(0.10 * (1.0 - inland))

			if glaciated and inland >= 0.12:
				color = color.lerp(ICE_COLOR, 0.65)

			image.set_pixel(pixel_x, pixel_y, color)


static func _draw_markers(
	image: Image, cell: Dictionary, origin: Vector2i, size: int
) -> void:
	var starter_set: String = str(cell["starter_set"])

	if starter_set != "":
		var border: Color = (
			Color(1.0, 0.86, 0.0) if starter_set == "inner" else Color(1.0, 0.55, 0.0)
		)
		var thickness: int = 3
		image.fill_rect(Rect2i(origin.x, origin.y, size, thickness), border)
		image.fill_rect(Rect2i(origin.x, origin.y + size - thickness, size, thickness), border)
		image.fill_rect(Rect2i(origin.x, origin.y, thickness, size), border)
		image.fill_rect(Rect2i(origin.x + size - thickness, origin.y, thickness, size), border)

	var pattern: String = str(cell["pattern"])
	var marker_size: int = maxi(size / 12, 4)

	if pattern.begins_with("chain"):
		var color: Color = (
			Color(0.80, 0.10, 0.10) if pattern.ends_with("volcanic_arc")
			else Color(1.0, 1.0, 1.0)
		)
		image.fill_rect(
			Rect2i(origin.x + 3, origin.y + 3, marker_size, marker_size), color
		)
	elif pattern == "starter_neighbor":
		image.fill_rect(
			Rect2i(
				origin.x + size - marker_size - 3, origin.y + 3, marker_size, marker_size
			),
			Color(0.0, 0.9, 0.9)
		)
