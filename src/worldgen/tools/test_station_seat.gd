extends SceneTree

# Stations and furniture on sloping ground (physical world audit, coordinator 23 Nov 2026): set at the lowest ground under the footprint so no corner
# hangs in the air, and a rise limit that grows with the piece's size (PlacementRules.seats_low, rise_limit, seated_ground).
#   godot --headless --path . --script res://src/worldgen/tools/test_station_seat.gd

const Rules := preload("res://src/shared/placement_rules.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _kit(cfg: Dictionary, structure: String) -> String:
	return str(cfg["structures"][structure].get("kit", structure + "_kit"))


func _init() -> void:
	var cfg: Dictionary = Rules.load_config()
	var crate: String = _kit(cfg, "wooden_crate")    # 0.8 x 0.8 m
	var bench: String = _kit(cfg, "workbench")       # 1.5 x 1.0 m
	var forge: String = _kit(cfg, "stone_forge")     # 3 m
	var base: String = _kit(cfg, "foundation_section")
	check(Rules.seats_low(cfg, crate) and Rules.seats_low(cfg, bench), "a crate and a workbench are set down by the station rule")
	check(not Rules.seats_low(cfg, base) and not Rules.seats_low(cfg, "campfire_kit"), "a foundation and the campfire keep their own rules")
	var pot: String = _kit(cfg, "campfire_pot")
	check(not Rules.seats_low(cfg, pot) and is_equal_approx(Rules.rise_limit(cfg, pot), float(cfg.get("max_rise_m", 1.0))), "a pot set on its fire (attach_to) keeps the file's limit: any fire's ground takes it")

	# The station rule's own drop counts in the wall-line check: a 2 m table sat at its lowest corner on a slope is still in a wall it stands in.
	var wall: Dictionary = cfg["structures"]["wall_section"]
	var table_def: Dictionary = cfg["structures"]["woodworking_table"]
	var wall_at: Vector3 = Vector3(200.0, 10.0, 200.0)
	check(Rules._stands_in(table_def, wall_at - Vector3(0.0, 0.65, 0.0), wall, wall_at, 0.0), "a 2 m table seated 0.65 m under a wall's foot is still standing in its line")
	check(absf(Rules.rise_limit(cfg, crate) - 0.28) < 0.001, "a 0.8 m crate may stand across 0.28 m of rise (%.2f), not 1.0 m" % Rules.rise_limit(cfg, crate))
	check(absf(Rules.rise_limit(cfg, bench) - 0.525) < 0.001, "a 1.5 m workbench across 0.525 m (%.3f)" % Rules.rise_limit(cfg, bench))
	check(is_equal_approx(Rules.rise_limit(cfg, forge), float(cfg.get("max_rise_m", 1.0))), "a 3 m forge keeps the file's 1.0 m at most")
	check(is_equal_approx(Rules.rise_limit(cfg, base), float(cfg["structures"]["foundation_section"]["max_rise_m"])), "a foundation keeps its own max_rise_m")
	check(is_equal_approx(Rules.rise_limit(cfg, "campfire_kit"), float(cfg.get("campfire", {}).get("max_rise_m", 0.6))), "the campfire keeps its ring's limit")

	# The 51 degree slope the old rule allowed a crate on is red now; a gentle one is fine.
	var spot: Vector3 = Vector3(100.0, 10.0, 100.0)
	check(Rules.steep(cfg, crate, spot, 0.0, func(x, _z): return 10.0 + 1.2 * (x - 100.0)) == "steep", "a crate on a 50 degree slope is too steep")
	check(Rules.steep(cfg, crate, spot, 0.0, func(x, _z): return 10.0 + 0.3 * (x - 100.0)) == "", "on a 17 degree slope it stands")

	# Seated at the lowest sample: on a slope rising 0.3 m per metre along x the workbench's low corners are 0.225 m under its middle.
	var slope := func(x: float, _z: float) -> float: return 10.0 + 0.3 * (x - 100.0)
	var seat: float = Rules.seated_ground(cfg, bench, spot, 0.0, slope, 10.0)
	check(absf(seat - (10.0 - 0.3 * 0.75)) < 0.001, "the workbench sits at its lowest corner's ground (%.3f), none in the air" % seat)
	check(is_equal_approx(Rules.seated_ground(cfg, base, spot, 0.0, slope, 10.0), 10.0), "a foundation keeps the ground under its middle (the wheel lifts it)")
	check(is_equal_approx(Rules.seated_ground(cfg, bench, spot, 0.0, func(_x, _z): return NAN, 10.0), 10.0), "unknown ground: the middle's height")
	var crest := func(x: float, z: float) -> float: return 10.0 - 0.3 * (absf(x - 100.0) + absf(z - 100.0))
	check(absf(Rules.seated_ground(cfg, crate, spot, 0.0, crest, 10.0) - (10.0 - 0.3 * 0.8)) < 0.001, "on a crest it comes down to its lowest corner too")

	# The server sets it there and the ghost shows it there.
	var server: String = FileAccess.get_file_as_string("res://src/stream/server_items.gd")
	check(server.contains("PlacementRules.seated_ground(_structures_cfg, kit_id, at,"), "the server places a station at its seat")
	check(FileAccess.get_file_as_string("res://src/client/held_item.gd").contains("PlacementRules.seated_ground(_placement, kit, _blueprint_at,"), "the ghost is drawn at its seat")
	print("station seat test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
