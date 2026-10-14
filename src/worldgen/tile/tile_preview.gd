class_name TilePreview
extends RefCounted

# Shaded relief of one tile's 8 m height map, lit from the northwest.
# Sea tinted by depth, land colored by height, 1 km grid lines.

const ReliefScript := preload("res://src/worldgen/sketch/relief_preview.gd")

const SAND := Color(0.84, 0.76, 0.52)
const GRASS := Color(0.42, 0.62, 0.30)
const FOREST := Color(0.22, 0.44, 0.22)
const ROCK := Color(0.47, 0.44, 0.41)


static func render(settings, height, tile: Vector2i, show_grid: bool = true, water = null) -> Image:
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

			var wet: int = 0

			if water != null:
				wet = water.water_class[j * samples + i]

			if wet == 3 or wet == 2:
				var river_color: Color = Color(0.20, 0.45, 0.85) if wet == 3 else Color(0.12, 0.35, 0.72)
				color = river_color * (0.8 + 0.3 * shade)
			elif h > 0.0:
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


const BIOME_COLORS := {
	"ocean": Color(0.10, 0.30, 0.55), "beach": Color(0.90, 0.84, 0.60), "hot_desert": Color(0.90, 0.72, 0.40),
	"dry_scrub": Color(0.72, 0.64, 0.38), "savanna": Color(0.74, 0.70, 0.32), "tropical_forest": Color(0.08, 0.42, 0.16),
	"mangrove": Color(0.20, 0.38, 0.28), "temperate_grassland": Color(0.55, 0.74, 0.32),
	"temperate_forest": Color(0.14, 0.45, 0.20), "mixed_forest": Color(0.28, 0.52, 0.26), "marsh": Color(0.32, 0.50, 0.42),
	"heath": Color(0.58, 0.42, 0.52), "boreal_forest": Color(0.12, 0.34, 0.30), "tundra": Color(0.62, 0.62, 0.52),
	"alpine_meadow": Color(0.52, 0.70, 0.52), "bare_rock": Color(0.48, 0.45, 0.43), "snowfield": Color(0.94, 0.95, 0.98),
	"glacier": Color(0.78, 0.90, 0.98), "volcanic_waste": Color(0.22, 0.18, 0.18),
}


# Biome map under hill shading. Water keeps its blue from the water map.
static func render_biomes(height, climate, tables, water = null) -> Image:
	var samples: int = height.samples
	var spacing: float = height.spacing_m
	var image: Image = Image.create(samples, samples, false, Image.FORMAT_RGB8)
	var light: Vector3 = Vector3(-1.0, 1.3, -1.0).normalized()
	var colors: Dictionary = {}

	for entry in tables.get_entries("biomes"):
		colors[int(entry["id"])] = BIOME_COLORS.get(str(entry["name"]), Color(1, 0, 1))

	for j in range(samples):
		for i in range(samples):
			var index: int = j * samples + i
			var h: float = height.heights[index]
			var east: float = height.heights[j * samples + mini(i + 1, samples - 1)]
			var west: float = height.heights[j * samples + maxi(i - 1, 0)]
			var south: float = height.heights[mini(j + 1, samples - 1) * samples + i]
			var north: float = height.heights[maxi(j - 1, 0) * samples + i]
			var normal: Vector3 = Vector3(
				-(east - west) / (2.0 * spacing) * 2.0, 1.0, -(south - north) / (2.0 * spacing) * 2.0
			).normalized()
			var shade: float = maxf(normal.dot(light), 0.0)
			var color: Color = colors[climate.biome[index]]
			var wet: int = 0 if water == null else water.water_class[index]

			if wet == 3 or wet == 2:
				color = Color(0.20, 0.45, 0.85)
			elif wet == 1 or h <= 0.0:
				color = ReliefScript._sea_color(-h) * (0.85 + 0.25 * shade)
				color.a = 1.0
				image.set_pixel(i, j, color)
				continue

			color = color * (0.55 + 0.6 * shade)
			color.a = 1.0
			image.set_pixel(i, j, color)

	return image
