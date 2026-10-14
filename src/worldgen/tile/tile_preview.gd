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


const ROCK_COLORS := {
	"sediment": Color(0.80, 0.72, 0.55), "shale": Color(0.42, 0.45, 0.50), "limestone": Color(0.82, 0.82, 0.76),
	"coal": Color(0.12, 0.12, 0.12), "granite": Color(0.86, 0.58, 0.58), "slate": Color(0.32, 0.36, 0.46),
	"basalt": Color(0.22, 0.20, 0.22), "sandstone": Color(0.86, 0.66, 0.40), "marble": Color(0.98, 0.98, 1.0), "chalk": Color(0.95, 0.95, 0.85),
}

const RESOURCE_COLORS := {
	"gold": Color(1.0, 0.85, 0.0), "silver": Color(0.85, 0.9, 1.0), "tin": Color(0.6, 1.0, 0.9),
	"copper": Color(1.0, 0.45, 0.1), "iron": Color(0.75, 0.1, 0.05), "zinc": Color(0.5, 0.6, 1.0),
	"lead": Color(0.55, 0.45, 0.75), "sulfur": Color(0.95, 1.0, 0.3),
	"diamond": Color(0.9, 1.0, 1.0), "ruby": Color(0.9, 0.0, 0.2), "sapphire": Color(0.1, 0.2, 0.95),
	"emerald": Color(0.0, 0.8, 0.3), "topaz": Color(1.0, 0.7, 0.3), "aquamarine": Color(0.4, 0.9, 0.9),
	"amethyst": Color(0.6, 0.3, 0.9), "agate": Color(0.8, 0.5, 0.4), "garnet": Color(0.6, 0.05, 0.1), "opal": Color(0.95, 0.85, 0.95), "flint": Color(0.3, 0.3, 0.35), "bitumen": Color(0.05, 0.03, 0.02), "graphite": Color(0.4, 0.4, 0.45), "alum": Color(0.85, 0.95, 0.85),
	"salt": Color(1.0, 1.0, 1.0), "gypsum": Color(0.95, 0.9, 0.85), "coal": Color(0.0, 0.0, 0.0),
}


# Bedrock map under hill shading: rock at the bedrock surface, province
# borders, fault traces and ore bodies (a ring marks ore that reaches the
# surface). Sea floor is drawn darker.
static func render_geology(height, geology, tables) -> Image:
	var samples: int = height.samples
	var spacing: float = height.spacing_m
	var image: Image = Image.create(samples, samples, false, Image.FORMAT_RGB8)
	var light: Vector3 = Vector3(-1.0, 1.3, -1.0).normalized()
	var colors: Dictionary = {}

	for entry in tables.get_entries("rocks"):
		colors[int(entry["id"])] = ROCK_COLORS.get(str(entry["name"]), Color(1, 0, 1))

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
			var color: Color = colors[geology.surface_rock[index]] * (0.55 + 0.6 * shade)

			if h <= 0.0:
				color = color.lerp(Color(0.05, 0.12, 0.28), 0.6)

			var p: int = geology.province[index]

			if (i + 1 < samples and geology.province[index + 1] != p) or (j + 1 < samples and geology.province[index + samples] != p):
				color = Color(0.05, 0.05, 0.05)

			color.a = 1.0
			image.set_pixel(i, j, color)

	var x0: float = float(geology.tile_origin.x)
	var z0: float = float(geology.tile_origin.y)

	for feature in geology.features:
		if str(feature["type"]) == "fault":
			var a: Vector2 = (Vector2(float(feature["points"][0][0]), float(feature["points"][0][1])) - Vector2(x0, z0)) / spacing
			var b: Vector2 = (Vector2(float(feature["points"][1][0]), float(feature["points"][1][1])) - Vector2(x0, z0)) / spacing
			_line(image, a, b, Color(0.9, 0.1, 0.1), 1)

	for ore in geology.ore_bodies:
		var color: Color = RESOURCE_COLORS.get(str(ore["resource"]), Color(1, 0, 1))
		var shape: String = str(ore["shape"])

		if shape == "layer" or shape == "scatter":
			continue

		if ore.has("points"):
			for k in range(ore["points"].size() - 1):
				var a: Vector2 = (Vector2(float(ore["points"][k][0]), float(ore["points"][k][1])) - Vector2(x0, z0)) / spacing
				var b: Vector2 = (Vector2(float(ore["points"][k + 1][0]), float(ore["points"][k + 1][1])) - Vector2(x0, z0)) / spacing
				_line(image, a, b, color, 3 if shape == "placer" else 2)
			continue

		var center: Vector2 = (Vector2(float(ore["center"][0]), float(ore["center"][ore["center"].size() - 1])) - Vector2(x0, z0)) / spacing
		var radius: float = maxf(float(ore.get("radius_m", ore.get("radius_a_m", 20.0))) / spacing, 5.0)
		_disc(image, center, minf(radius, 9.0), color)
		_ring(image, center, radius, color)

	return image


static func _line(image: Image, a: Vector2, b: Vector2, color: Color, thickness: int) -> void:
	var steps: int = int(a.distance_to(b)) + 1

	for k in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(k) / float(steps))

		for dy in range(-thickness / 2, thickness / 2 + 1):
			for dx in range(-thickness / 2, thickness / 2 + 1):
				var x: int = int(p.x) + dx
				var y: int = int(p.y) + dy

				if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
					image.set_pixel(x, y, color)


static func _disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for dy in range(-int(radius), int(radius) + 1):
		for dx in range(-int(radius), int(radius) + 1):
			if dx * dx + dy * dy <= radius * radius:
				var x: int = int(center.x) + dx
				var y: int = int(center.y) + dy

				if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
					image.set_pixel(x, y, color)


static func _ring(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var steps: int = maxi(int(radius * 6.0), 16)

	for k in range(steps):
		var angle: float = float(k) * TAU / float(steps)
		var x: int = int(center.x + cos(angle) * radius)
		var y: int = int(center.y + sin(angle) * radius)

		if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
			image.set_pixel(x, y, color)


const SEGMENT_COLORS := {
	"squeeze": Color(1.0, 0.9, 0.1), "shaft": Color(1.0, 0.2, 0.9), "water": Color(0.2, 0.6, 1.0),
	"ledge": Color(1.0, 0.5, 0.1),
}


# Caves and other sites over a grey relief. Passages shade from pale (just
# under the ground) to deep violet (100 m or more below it); squeezes are
# yellow, drops magenta, flooded passages blue, ledges orange. Chambers are
# cyan rings (red if they have a chasm and rock bridge), entrances green,
# dens red, lair sites white rings, the spawn a white cross and the town
# block a white square.
static func render_sites(height, sites) -> Image:
	var samples: int = height.samples
	var spacing: float = height.spacing_m
	var image: Image = Image.create(samples, samples, false, Image.FORMAT_RGB8)
	var light: Vector3 = Vector3(-1.0, 1.3, -1.0).normalized()

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
			var grey: float = 0.25 + 0.4 * shade if h > 0.0 else 0.10
			image.set_pixel(i, j, Color(grey, grey, grey * (1.0 if h > 0.0 else 2.2)))

	var origin: Vector2 = Vector2(float(sites._x0), float(sites._z0))

	for cave in sites.caves:
		var nodes: Array = cave["nodes"]

		for segment in cave["segments"]:
			var a: Array = nodes[int(segment[0])]
			var b: Array = nodes[int(segment[1])]
			var pa: Vector2 = (Vector2(float(a[0]), float(a[2])) - origin) / spacing
			var pb: Vector2 = (Vector2(float(b[0]), float(b[2])) - origin) / spacing
			var color: Color = SEGMENT_COLORS.get(str(segment[2]), Color(0, 0, 0))

			if str(segment[2]) == "passage":
				var index: int = clampi(int(pb.y), 0, samples - 1) * samples + clampi(int(pb.x), 0, samples - 1)
				var depth: float = clampf((height.heights[index] - float(b[1])) / 100.0, 0.0, 1.0)
				color = Color(0.95, 0.9, 1.0).lerp(Color(0.45, 0.1, 0.75), depth)

			_line(image, pa, pb, color, 3 if float(b[3]) >= 5.0 else 1)

		for chamber in cave["chambers"]:
			var node: Array = nodes[int(chamber["node"])]
			var center: Vector2 = (Vector2(float(node[0]), float(node[2])) - origin) / spacing
			var color: Color = Color(1.0, 0.3, 0.3) if chamber["features"].has("chasm") else Color(0.2, 1.0, 1.0)
			_ring(image, center, maxf(float(chamber["radius_m"]) / spacing, 2.0), color)

		for entrance in cave["entrances"]:
			var node: Array = nodes[int(entrance)]
			_disc(image, (Vector2(float(node[0]), float(node[2])) - origin) / spacing, 4.0, Color(0.2, 1.0, 0.2))

		for den in cave["dens"]:
			var node: Array = nodes[int(den["node"])]
			_disc(image, (Vector2(float(node[0]), float(node[2])) - origin) / spacing, 2.0 + float(den["tier"]), Color(1.0, 0.1, 0.1))

	for lair in sites.lairs:
		for cave in sites.caves:
			if cave["id"] == lair["cave"]:
				var node: Array = cave["nodes"][int(lair["node"])]
				_ring(image, (Vector2(float(node[0]), float(node[2])) - origin) / spacing, 14.0, Color(1, 1, 1))

	if not sites.harbor.is_empty():
		var center: Vector2 = (Vector2(float(sites.harbor["center"][0]), float(sites.harbor["center"][1])) - origin) / spacing
		_ring(image, center, float(sites.harbor["radius_m"]) / spacing, Color(0.6, 0.8, 1.0))

	if sites.starter.has("spawn_point"):
		var spawn: Vector2 = (Vector2(float(sites.starter["spawn_point"][0]), float(sites.starter["spawn_point"][2])) - origin) / spacing
		_line(image, spawn - Vector2(12, 12), spawn + Vector2(12, 12), Color(1, 1, 1), 3)
		_line(image, spawn - Vector2(12, -12), spawn + Vector2(12, -12), Color(1, 1, 1), 3)

	if sites.starter.has("town_block"):
		var block: Vector2 = (Vector2(float(sites.starter["town_block"][0]), float(sites.starter["town_block"][2])) - origin) / spacing
		var corners: Array = [Vector2(-14, -14), Vector2(14, -14), Vector2(14, 14), Vector2(-14, 14)]

		for k in range(4):
			_line(image, block + corners[k], block + corners[(k + 1) % 4], Color(1, 1, 1), 3)

	return image
