extends RefCounted

# STAND-IN for Cover.at (spec: tech/COVER_QUERY.md, built by the Water and terrain thread).
# Same idea and result (0.0 open, 1.0 covered): a point is covered when it lies under any tree's
# crown circle (crown_m / 2). Used by the campfire only. When src/shared/cover.gd lands, the
# two callers (terrain_server.gd, held_item.gd) switch to it and this file is deleted.

const FLORA_PATH := "res://data/tables/flora.json"

static var _crowns: Dictionary = {}    # species id -> crown radius in metres (trees only)


static func crown_radius(species_id: int) -> float:
	if _crowns.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLORA_PATH))

		for entry in parsed["entries"]:
			if str(entry["kind"]) == "tree":
				_crowns[int(entry["id"])] = float(entry["crown_m"]) * 0.5

	return float(_crowns.get(species_id, 0.0))


# `ids` and `positions` are a flora chunk's items (any kinds; only trees count).
static func at(point: Vector3, ids: PackedInt32Array, positions: PackedVector3Array) -> float:
	for n in range(ids.size()):
		var radius: float = crown_radius(ids[n] >> 16)

		if radius > 0.0 and Vector2(positions[n].x - point.x, positions[n].z - point.z).length() <= radius:
			return 1.0

	return 0.0
