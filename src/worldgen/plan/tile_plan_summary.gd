class_name TilePlanSummary
extends RefCounted

# Plain-text report on a tile plan built from the sketch.

const CLASS_ORDER := ["islet", "small", "medium", "large", "great", "colossal"]
const TIER_ORDER := ["easy", "moderate", "medium", "hard", "deadly"]


static func build(settings, plan, matrix) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var cells: Array = matrix.get_sorted_cells()
	var by_kind: Dictionary = {}
	var land_by_zone: Dictionary = {}
	var land_by_tier: Dictionary = {}
	var tiles_by_tier: Dictionary = {}
	var total_land: float = 0.0
	var geology: Dictionary = {}
	var file_tiles: int = 0

	for cell in cells:
		var kind: String = str(cell["kind"])
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var land: float = float(cell["land_km2"])
		total_land += land
		land_by_zone[cell["zone"]] = float(land_by_zone.get(cell["zone"], 0.0)) + land
		land_by_tier[cell["danger_tier"]] = float(land_by_tier.get(cell["danger_tier"], 0.0)) + land
		tiles_by_tier[cell["danger_tier"]] = int(tiles_by_tier.get(cell["danger_tier"], 0)) + 1

		if str(cell["status"]) == "planned":
			file_tiles += 1

		for hint in cell["geology_hints"]:
			geology[hint] = int(geology.get(hint, 0)) + 1

	var by_class: Dictionary = {}

	for island in plan.islands:
		by_class[island["size_class"]] = int(by_class.get(island["size_class"], 0)) + 1

	lines.append("TILE PLAN SUMMARY (built from the world sketch)")
	lines.append("World: %s   seed phrase: %s" % [settings.world_name, settings.seed_text])
	lines.append("Tiles: %d   tiles needing a tile file: %d   land: %.0f km2" % [
		cells.size(), file_tiles, total_land
	])
	lines.append("Tile kinds: %s" % _counts(by_kind))
	lines.append("Islands: %d   %s" % [plan.islands.size(), _ordered(by_class, CLASS_ORDER)])
	lines.append("Tiles by geology hint: %s" % _counts(geology))
	lines.append("")
	lines.append("LAND BY CLIMATE ZONE")

	for zone in settings.zones:
		lines.append("  %-18s %8.0f km2" % [zone["id"], float(land_by_zone.get(zone["id"], 0.0))])

	lines.append("")
	lines.append("BY DANGER TIER (tiles, land km2)")

	for tier in TIER_ORDER:
		lines.append("  %-9s %4d tiles  %8.0f km2" % [
			tier, int(tiles_by_tier.get(tier, 0)), float(land_by_tier.get(tier, 0.0))
		])

	lines.append("")
	lines.append("STARTER TILES")

	for cell in cells:
		if str(cell["starter_set"]) != "":
			lines.append("  %-6s (%3d,%3d)  land %6.1f km2  islands %s  danger %.2f" % [
				cell["starter_set"], cell["x"], cell["z"], cell["land_km2"],
				str(cell["island_ids"]), cell["danger"]
			])

	lines.append("")
	lines.append("TILES WITH THE MOST LAND")
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["land_km2"]) > float(b["land_km2"])
	)

	for index in range(mini(12, sorted.size())):
		var cell: Dictionary = sorted[index]
		lines.append("  (%3d,%3d) %7.1f km2  %-9s  %s" % [
			cell["x"], cell["z"], cell["land_km2"], cell["danger_tier"],
			", ".join(PackedStringArray(cell["features"]))
		])

	return "\n".join(lines) + "\n"


static func _counts(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()

	for key in keys:
		parts.append("%s %d" % [key, int(counts[key])])

	return ", ".join(parts)


static func _ordered(counts: Dictionary, order: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for key in order:
		parts.append("%s %d" % [key, int(counts.get(key, 0))])

	return ", ".join(parts)
