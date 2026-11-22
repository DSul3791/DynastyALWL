extends SceneTree

# Bog iron patches as world rows for the client's look (Steve 10 Nov 2026, on Sonny's #996; fields and ground rust, Dave 21 Nov 2026): every patch
# within seen_m of a player is sent as
#   [id, 0, ore left, the patch centre on the generated ground, BOG_STATE 229, {"key", "total", "r"}]
# with "left" as it has grown back by now; a dig sends it again with less, the regrowth with more; walking away takes it off; no structure state
# may be 229. A stand-in field (bog_field) keeps the test off the baked tile.
#   godot --headless --path . --script res://src/worldgen/tools/test_bog_rows.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const NEAR_SPOT := Vector3(800.0, 10.0, 800.0)       # a patch on sample (100, 100), in field square (1, 1)
const WET_SPOT := Vector3(816.0, 10.0, 800.0)        # a second patch two samples east
const FAR_SPOT := Vector3(800.0, 10.0, 880.0)        # 80 m south: out of sight from the first spot

var failures: int = 0
var items
var sent: Array = []      # [added, removed] per send to peer 1
var clock_s: float = 1000.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# The rows for bog deposits in the last sends, by key, and every id taken off.
func _bog_added() -> Dictionary:
	var out: Dictionary = {}

	for send in sent:
		for row in send[0]:
			if int(row[4]) == items.BOG_STATE:
				out[str(row[5]["key"])] = row

	return out


func _removed() -> Array:
	var out: Array = []

	for send in sent:
		out.append_array(Array(send[1]))

	return out


func _sync() -> void:
	sent.clear()
	items._sync_world_items()


func _init() -> void:
	var dir: String = "user://test_bog_rows"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.send_world_items = func(p, added, removed) -> void:
		if p == 1:
			sent.append([added, removed])
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func() -> float: return clock_s
	items.bog_field = func(fx: int, fz: int, _cfg: Dictionary) -> Array:
		var patches: Array = []

		if fx == 1 and fz == 1:
			for spot in [NEAR_SPOT, WET_SPOT, FAR_SPOT]:
				patches.append({"key": "%d,%d" % [int(round(spot.x / 8.0)), int(round(spot.z / 8.0))], "x": spot.x, "z": spot.z, "size": 8, "r": 3.0})

		return patches
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "bogrows00001")
	items.vitals_of(1)["weight"] = 500.0
	var cfg: Dictionary = items._dig_cfg.get("bog_iron", {})
	check(not cfg.is_empty() and float(cfg.get("seen_m", 0.0)) == 50.0, "digging.json bog_iron sees 50 m (Dave 19 Nov 2026: easy to find)")

	# State 229 is the deposit's own: no structure may take it.
	var clash: Array = []

	for kind in items._structures:
		if int(items._structures[kind].get("state", -1)) == items.BOG_STATE:
			clash.append(kind)

	check(clash.is_empty(), "no structure uses state %d (%s)" % [items.BOG_STATE, str(clash)])

	# In sight: the two near deposits come as rows of the agreed shape, the far one does not.
	items.report_position(1, NEAR_SPOT + Vector3(3.0, 0.0, 3.0))
	_sync()
	var rows: Dictionary = _bog_added()
	var dry_key: String = "100,100"
	var east_key: String = "102,100"
	check(rows.size() == 2 and rows.has(dry_key) and rows.has(east_key), "the two patches within 50 m are sent, the one 80 m off is not (%s)" % str(rows.keys()))

	if not rows.has(dry_key) or not rows.has(east_key):
		quit(1)
		return

	var dry: Array = rows[dry_key]
	check(int(dry[0]) >= items.BOG_ID_BASE - 10 and int(dry[1]) == 0 and int(dry[2]) == 8 and (dry[3] as Vector3).distance_to(NEAR_SPOT) < 0.01, "a row is [id, 0, ore left 8, the sample on the ground] (%s)" % str(dry.slice(0, 4)))
	check(typeof(dry[5]) == TYPE_DICTIONARY and str(dry[5]["key"]) == dry_key and int(dry[5]["total"]) == 8 and is_equal_approx(float(dry[5]["r"]), 3.0) and not dry[5].has("wet"), "its extra is {key, total 8, r 3}")
	check(is_equal_approx((dry[3] as Vector3).y, 10.0), "its centre is on the generated ground (10 m)")
	check(int(rows[east_key][0]) != int(dry[0]), "each patch has its own id")
	# The slow-tick line times the bog rows apart from the scan and counts the field squares built on first sight (D-STALL-1, 22 Nov 2026).
	check(items._bog_built >= 1 and str(items._sync_detail).contains("bog ") and str(items._sync_detail).contains("built %d fields" % items._bog_built), "the first sync builds the field squares in sight and the sync line says so (%s)" % str(items._sync_detail))

	# Nothing changed: nothing sent again.
	_sync()
	check(_bog_added().is_empty(), "an unchanged deposit is not sent again")
	check(items._bog_built == 0 and str(items._sync_detail).contains("built 0 fields"), "the next sync builds none: they are kept (%s)" % str(items._sync_detail))

	# A dig takes ore: the row comes again with less left.
	items._dig_bog_iron(1, NEAR_SPOT, 1, 1)
	var after_dig: int = int(items._bog_left.get(dry_key, [8, 0.0])[0])
	_sync()
	rows = _bog_added()
	check(after_dig < 8 and rows.has(dry_key) and int(rows[dry_key][2]) == after_dig, "after a dig the row says %d left (sent %s)" % [after_dig, str(rows[dry_key][2]) if rows.has(dry_key) else "nothing"])

	# Regrowth: one ore back every regrow_game_days, sent without a dig.
	clock_s += float(cfg.get("regrow_game_days", 3.0)) * 86400.0 + 1.0
	_sync()
	rows = _bog_added()
	check(rows.has(dry_key) and int(rows[dry_key][2]) == mini(after_dig + 1, 8), "a regrow period later it says %d (%s)" % [mini(after_dig + 1, 8), str(rows[dry_key][2]) if rows.has(dry_key) else "nothing"])

	# Walking away: the rows are taken off, and the far deposit comes in.
	var dry_id: int = int(dry[0])
	items.report_position(1, FAR_SPOT + Vector3(2.0, 0.0, 0.0))
	_sync()
	rows = _bog_added()
	check(_removed().has(dry_id) and rows.has("100,110") and not rows.has(dry_key), "walking 80 m off takes the near deposits away and sends the far one")

	# Back again: the same id as before.
	items.report_position(1, NEAR_SPOT)
	_sync()
	rows = _bog_added()
	check(rows.has(dry_key) and int(rows[dry_key][0]) == dry_id, "coming back, the deposit keeps its id")

	print("test_bog_rows: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
