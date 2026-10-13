class_name TilePreview
extends RefCounted

# Shaded relief of one tile's 8 m height map, lit from the northwest.
# Sea tinted by depth, land colored by height, 1 km grid lines.

const ReliefScript := preload("res://src/worldgen/sketch/relief_preview.gd")

const SAND := Color(0.84, 0.76, 0.52)
const GRASS := Color(0.42, 0.62, 0.30)
const FOREST := Color(0.22, 0.44, 0.22)
const ROCK := Color(0.47, 0.44, 0.41)


static func render(settings, height, tile: Vector2i, show_grid: bool = true) -> Image:
	var samples: int = height.samples
	var spacing: float = height.spacing_m
	var image: Image = Image.create(samples, samples, false, Image.FORMAT_RGB8)
	var light: Vector3 = Vector3(-1.0, 1.3, -1.0).normalized()
	var grid_every: int = int(round(1000.0 / spacing))

	for j in range(samples):
		for i in range(samples):
			var h: float = height.heights[j * samples + i]
			var east: float = height.heights[j * samples + mini(i + 1, samples - 1)]
			var west: float = height.heights[j * samples + maxi(i - 1, 0)]
			var south: float = height.heights[mini(j + 1, samples - 1) * samples + i]
			var north: float = height.heights[maxi(j - 1, 0) * samples + i]
			var exaggeration: float = 2.0 if h > 0.0 else 1.0
			var normal: Vector3 = Vector3(
				-(east - west) / (2.0 * spacing) * exaggeration, 1.0,
				-(south - north) / (2.0 * spacing) * exaggeration
			).normalized()
			var shade: float = maxf(normal.dot(light), 0.0)
			var color: Color

			if h > 0.0:
				color = _land_color(h)
				color = color * (0.45 + 0.75 * shade)
			else:
				color = ReliefScript._sea_color(-h) * (0.85 + 0.25 * shade)

			if show_grid and (i % grid_every == 0 or j % grid_every == 0):
				color = color.lerp(Color(1, 1, 1), 0.12)

			color.a = 1.0
			image.set_pixel(i, j, color)

	return image


static func _land_color(h: float) -> Color:
	if h < 2.5:
		return SAND

	var color: Color = GRASS.lerp(FOREST, clampf((h - 40.0) / 160.0, 0.0, 1.0))

	if h > 350.0:
		color = color.lerp(ROCK, clampf((h - 350.0) / 250.0, 0.0, 0.85))

	return color
