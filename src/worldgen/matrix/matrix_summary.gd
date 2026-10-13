class_name MatrixSummary
extends RefCounted

# Plain-text report on a tile matrix: how much land and ocean each climate
# zone has, island counts by size, geology coverage, starters, seas, chains.

const CLASS_ORDER := ["islet", "small", "medium", "large", "great", "colossal"]
const HINTS := ["granite", "basin", "fold_belt", "volcanic"]


static func build(settings, rules: Dictionary, matrix) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var cells: Array = matrix.get_sorted_cells()

	lines.append("TILE MATRIX SUMMARY")
	lines.append("World: %s   seed phrase: %s   master seed: %d" % [
		settings.world_name, settings.seed_text, settings.master_seed
	])
	lines.append("")

	# ---- Totals ----
	var by_layout: Dictionary = {}
	var total_land: float = 0.0
	var total_islands: int = 0
	var class_counts: Dictionary = {}
	var character_counts: Dictionary = {}

	for cell in cells:
		var layout: String = str(cell["layout"])
		by_layout[layout] = int(by_layout.get(layout, 0)) + 1

		for island in cell["islands"]:
			total_land += float(island["area_km2"])
			total_islands += 1
			var size_class: String = str(island["size_class"])
			class_counts[size_class] = int(class_counts.get(size_class, 0)) + 1
			var character: String = str(island["character"])
			character_counts[character] = int(character_counts.get(character, 0)) + 1

	var tile_km2: float = pow(float(settings.tile_size_m) / 1000.0, 2.0)
	var world_km2: float = tile_km2 * float(cells.size())

	lines.append("Tiles: %d   world area: %.0f km2   land: %.0f km2 (%.1f%%)" % [
		cells.size(), world_km2, total_land, total_land / world_km2 * 100.0
	])
	lines.append("Islands: %d" % total_islands)
	lines.append("Tile layouts: %s" % _format_counts(by_layout))
	lines.append("Island sizes: %s" % _format_ordered(class_counts, CLASS_ORDER))
	lines.append("Island characters: %s" % _format_counts(character_counts))
	lines.append("")

	# ---- Per zone ----
	lines.append("BY CLIMATE ZONE")
	lines.append("%-18s %5s %7s %8s %8s %9s  %s" % [
		"zone", "tiles", "ocean", "islands", "land km2", "km2/tile", "sizes (islet/small/medium/large/great/colossal)"
	])

	for zone in settings.zones:
		var zone_id: String = str(zone["id"])
		var tiles: int = 0
		var ocean: int = 0
		var islands: int = 0
		var land: float = 0.0
		var sizes: Dictionary = {}

		for cell in cells:
			if str(cell["zone"]) != zone_id:
				continue

			tiles += 1
			ocean += 1 if cell["kind"] == "ocean" else 0

			for island in cell["islands"]:
				islands += 1
				land += float(island["area_km2"])
				var size_class: String = str(island["size_class"])
				sizes[size_class] = int(sizes.get(size_class, 0)) + 1

		var size_text: PackedStringArray = PackedStringArray()

		for size_class in CLASS_ORDER:
			size_text.append(str(int(sizes.get(size_class, 0))))

		lines.append("%-18s %5d %6.0f%% %8d %8.0f %9.1f  %s" % [
			zone_id, tiles,
			float(ocean) / float(maxi(tiles, 1)) * 100.0,
			islands, land, land / float(maxi(tiles, 1)),
			"/".join(size_text)
		])

	lines.append("")

	# ---- Geology coverage ----
	lines.append("GEOLOGY: ISLANDS WITH EACH KIND, BY ZONE")
	lines.append("%-18s %9s %9s %9s %9s" % ["zone", "granite", "basin", "fold_belt", "volcanic"])

	for zone in settings.zones:
		var counts: Dictionary = {}

		for cell in cells:
			if str(cell["zone"]) != str(zone["id"]):
				continue

			for island in cell["islands"]:
				for hint in island["geology"]:
					counts[hint] = int(counts.get(hint, 0)) + 1

		lines.append("%-18s %9d %9d %9d %9d" % [
			zone["id"],
			int(counts.get("granite", 0)), int(counts.get("basin", 0)),
			int(counts.get("fold_belt", 0)), int(counts.get("volcanic", 0))
		])

	lines.append("")
	lines.append("Planned resources by geology (coarse planning guide):")

	for hint in HINTS:
		lines.append("  %-10s %s" % [hint, ", ".join(rules["hint_resources"][hint])])

	lines.append("")

	# ---- Starters ----
	lines.append("STARTER TILES")

	for set_name in ["inner", "outer"]:
		for tile in settings.starter_tiles.get(set_name, []):
			var cell: Dictionary = matrix.get_cell(tile.x, tile.y)
			var main_text: String = "no island"

			if not cell["islands"].is_empty():
				var main: Dictionary = cell["islands"][0]
				main_text = "%.1f km2 %s island, %d satellite(s)" % [
					float(main["area_km2"]), main["character"], cell["islands"].size() - 1
				]

			lines.append("  %-6s (%3d,%3d) %-18s %s   geology: %s" % [
				set_name, tile.x, tile.y, cell["zone"], main_text,
				", ".join(cell["geology_hints"])
			])

	lines.append("")

	# ---- Patterns ----
	var seas: Dictionary = {}
	var chains: Dictionary = {}
	var neighbors: int = 0

	for cell in cells:
		var pattern: String = str(cell["pattern"])

		if pattern.begins_with("open_sea"):
			seas[pattern] = int(seas.get(pattern, 0)) + 1
		elif pattern.begins_with("chain"):
			chains[pattern] = int(chains.get(pattern, 0)) + 1
		elif pattern == "starter_neighbor":
			neighbors += 1

	lines.append("WORLD-SCALE PATTERNS")
	lines.append("Open seas: %d  (%s tiles)" % [seas.size(), _format_counts(seas)])
	lines.append("Chains: %d  (%s tiles)" % [chains.size(), _format_counts(chains)])
	lines.append("Tiles added near starters for medium islands: %d" % neighbors)

	return "\n".join(lines) + "\n"


static func _format_counts(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()

	for key in keys:
		parts.append("%s %d" % [key, int(counts[key])])

	return ", ".join(parts)


static func _format_ordered(counts: Dictionary, order: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for key in order:
		parts.append("%s %d" % [key, int(counts.get(key, 0))])

	return ", ".join(parts)
