extends SceneTree

# Sickle and scythe swings on the server (Dave 18 Nov 2026, BugsList_Current.md entry 7; drops.json "swath"): one swing with the tool in hand reaps
# every ripe grain crop within 1.5 m (sickle) or 3 m (scythe) of the player at the full yield; unripe grain and other crops stay; the swing is
# refused without the tool in hand and between swings; it wears the tool; grasses cut by a swing give more than by hand, by the tool's tier; and a
# bush or grass a swing cannot take says nothing. The plant search and the bush cut sit in terrain_server.gd (_on_cut_swath_requested), which a
# headless test cannot build; the client half is harvest.gd swath.
#   godot --headless --path . --script res://src/worldgen/tools/test_swath.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var notes: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


# A tilled bed at (x, z) holding `crop`, ripe or a seedling.
func bed(id: int, x: float, z: float, crop: String, ripe: bool) -> void:
	var pos: Vector3 = Vector3(x, 10.0, z)
	items._items[id] = {"number": items.table.number_of("tilled_bed"), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": "tilled_bed", "yaw": 0.0}}
	var grow: int = int(items._crop_table()[crop]["grow_days"])
	items._crops[items._bed_key(pos)] = {"crop": crop, "sown": 0, "age": float(grow) if ripe else 0.0, "wet": grow, "day": items._game_day(), "compost": false, "rained": -1, "poured": -1}


func has_crop(x: float, z: float) -> bool:
	return items._crops.has(items._bed_key(Vector3(x, 10.0, z)))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_swath")
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notes.append(t)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return 1000.0
	items.season_now = func(): return "summer"
	items.rain_now = func(): return 0.0
	items.setup(ItemTableScript.load_default(), "user://test_swath")
	items.peer_connected_hello(1, "abcdef123456")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var cfg: Dictionary = items._drops.get("swath", {})
	check(float(cfg["sickle"]["radius_m"]) == 1.5 and float(cfg["scythe"]["radius_m"]) == 3.0, "the sickle reaches 1.5 m and the scythe 3 m round the player (Dave: radius)")

	bed(930001, 1.0, 0.0, "wheat", true)     # inside the sickle's circle
	bed(930002, 0.0, 2.5, "wheat", true)     # outside it, inside the scythe's
	bed(930003, -0.5, 0.0, "barley", false)  # unripe grain
	bed(930004, 0.0, -1.0, "carrot", true)   # not a grain

	# No tool in hand: refused, and told.
	check(items.swath_swing(1, 0).is_empty() and has_crop(1.0, 0.0), "no sickle in hand: the swing is refused and nothing is reaped")
	check(notes.size() > 0 and str(notes[-1]).contains("sickle"), "and the player is told (%s)" % (str(notes[-1]) if notes.size() > 0 else "nothing"))

	give("bronze_sickle", 1)
	var sickle: int = HeldTool.slot_of(items, "sickle")
	var wheat_yield: int = int(items._crop_table()["wheat"]["yields"][0][1])
	var wear_before: int = items.inventory_of(1).wear[sickle]
	notes.clear()
	var swing: Dictionary = items.swath_swing(1, sickle)
	check(not swing.is_empty() and int(swing["crops"]) == 1 and str(swing["tool"]) == "sickle", "a sickle swing reaps the one ripe grain crop in its circle (%s)" % str(swing))
	check(count("wheat") == wheat_yield, "at the full yield (%d of %d)" % [count("wheat"), wheat_yield])
	check(not has_crop(1.0, 0.0) and has_crop(0.0, 2.5), "the wheat 1 m away is cut, the wheat 2.5 m away is not")
	check(has_crop(-0.5, 0.0) and has_crop(0.0, -1.0), "unripe barley and a ripe carrot are left standing")
	check(items.inventory_of(1).wear[sickle] > wear_before, "the swing wears the sickle")
	check(is_equal_approx(float(swing["mult"]), float(cfg["yield"]["bronze"])) and (swing["grasses"] as Array).has("tall_grass"), "a bronze sickle cuts grass at the bronze yield (%s)" % str(swing["mult"]))
	check(notes.is_empty(), "a swing says nothing about the plants it leaves (%s)" % str(notes))
	check(items.swath_swing(1, sickle).is_empty(), "a second swing at once is refused (the swing pace)")

	# The scythe: 3 m, the same grain.
	give("bronze_scythe", 1)
	var scythe: int = HeldTool.slot_of(items, "scythe")
	items._swath_ms.clear()
	var before: int = count("wheat")
	swing = items.swath_swing(1, scythe)
	check(not swing.is_empty() and str(swing["tool"]) == "scythe" and not has_crop(0.0, 2.5) and count("wheat") - before == wheat_yield, "a scythe swing reaps the ripe wheat 2.5 m away at the full yield")

	# Every tier has a yield factor, the new copper ones too.
	for material in ["copper", "bronze", "iron", "steel"]:
		check(float((cfg["yield"] as Dictionary).get(material, 0.0)) > 1.0, "%s gathers more than the hand" % material)

	for id in ["copper_sickle", "copper_scythe", "iron_scythe"]:
		if items.table.has_id(id):
			give(id, 1)
			var slot: int = items.inventory_of(1).numbers.find(items.table.number_of(id))
			items._swath_ms.clear()
			swing = items.swath_swing(1, slot)
			check(not swing.is_empty() and float(swing["mult"]) > 1.0, "%s swings (yield x%s)" % [id, str(swing.get("mult", 0))])

	# Grass: a swing's gather gives more than a hand's pick of the same plant.
	items.gather_pace_ms = 0
	var thatch: int = count("thatch")
	items.gather(1, "tall_grass", "plant", "0,0,601", 601, Vector3(0.5, 10.0, 0.0))
	var by_hand: int = count("thatch") - thatch
	thatch = count("thatch")
	items.swath_mult = float(cfg["yield"]["bronze"])
	items.gather(1, "tall_grass", "plant", "0,0,602", 601, Vector3(0.5, 10.0, 0.0))
	items.swath_mult = 0.0
	var by_swing: int = count("thatch") - thatch
	check(by_hand > 0 and by_swing >= by_hand * 2 - 1, "tall grass by a bronze swing gives about twice the thatch of a hand (%d against %d)" % [by_swing, by_hand])

	print("test_swath: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
