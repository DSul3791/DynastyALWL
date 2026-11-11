extends SceneTree

# Bog iron deposits as world rows for the client's look (Steve 10 Nov 2026, on Sonny's #996): every deposit within seen_m of a player is sent as
#   [id, 0, ore left, the sample on the ground, BOG_STATE 229, {"key", "total", "wet"}]
# with "left" as it has grown back by now; a dig sends it again with less, the regrowth with more; walking away takes it off; "wet" only under
# standing water; no structure state may be 229. A stand-in deposit map (bog_deposit_at) keeps the test off the baked tile.
#   godot --headless --path . --script res://src/worldgen/tools/test_bog_rows.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const NEAR_SPOT := Vector3(800.0, 10.0, 800.0)       # a sample (100 x 8 m): a dry deposit
const WET_SPOT := Vector3(816.0, 10.0, 800.0)        # two samples east: under water
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
	items.water_depth_at = func(pos: Vector3) -> float: return 0.3 if pos.distance_to(WET_SPOT) < 1.0 else 0.0
	items.bog_deposit_at = func(x: float, z: float, _cfg: Dictionary) -> Dictionary:
		for spot in [NEAR_SPOT, WET_SPOT, FAR_SPOT]:
			if absf(x - spot.x) < 4.0 and absf(z - spot.z) < 4.0:
				return {"key": "%d,%d" % [int(round(spot.x / 8.0)), int(round(spot.z / 8.0))], "size": 8, "edge": false}

		return {}
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "bogrows00001")
	items.vitals_of(1)["weight"] = 500.0
	var cfg: Dictionary = items._dig_cfg.get("bog_iron", {})
	check(not cfg.is_empty() and float(cfg.get("seen_m", 0.0)) == 30.0, "digging.json bog_iron sees 30 m")

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
	var wet_key: String = "102,100"
	check(rows.size() == 2 and rows.has(dry_key) and rows.has(wet_key), "the two deposits within 30 m are sent, the one 80 m off is not (%s)" % str(rows.keys()))

	if not rows.has(dry_key) or not rows.has(wet_key):
		quit(1)
		return

	var dry: Array = rows[dry_key]
	check(int(dry[0]) >= items.BOG_ID_BASE - 10 and int(dry[1]) == 0 and int(dry[2]) == 8 and (dry[3] as Vector3).distance_to(NEAR_SPOT) < 0.01, "a row is [id, 0, ore left 8, the sample on the ground] (%s)" % str(dry.slice(0, 4)))
	check(typeof(dry[5]) == TYPE_DICTIONARY and str(dry[5]["key"]) == dry_key and int(dry[5]["total"]) == 8 and not bool(dry[5]["wet"]), "its extra is {key, total 8, wet false}")
	check(bool(rows[wet_key][5]["wet"]), "the deposit under standing water is wet")
	check(int(rows[wet_key][0]) != int(dry[0]), "each deposit has its own id")

	# Nothing changed: nothing sent again.
	_sync()
	check(_bog_added().is_empty(), "an unchanged deposit is not sent again")

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
