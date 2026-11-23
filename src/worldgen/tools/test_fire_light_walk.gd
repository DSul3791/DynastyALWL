extends SceneTree

# Fire and light walk (coordinator rulings for Dave, 23 Nov 2026), through the real ServerItems:
#   1. wolves take a player for a torch bearer only while a torch or lantern burns in hand (the walking rule and the keep-off ring, 9 m),
#      not for a torch that is out or only on the hotbar;
#   2. a lit Fireplace warms like the medium campfire and dries wet clothes, a brazier like the small fire; unlit, neither;
#   3. a lit Standing torch keeps wolves 8 m off; the Stone torch pillar goes out in open rain like the other posts; a brazier burns on in
#      heavy rain, faster;
#   4. over a restart the lit Fireplace is still lit and still warms.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_light_walk.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_fire_light_walk"
const HOME := Vector3(100.0, 5.0, 100.0)

var failures: int = 0
var rain: float = 0.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func make():
	var f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(_p, _t): pass
	f.setup(ItemTableScript.load_default(), DIR)
	f.ground_height = func(_x, _z): return HOME.y
	f.weather_at = func(_pos): return {"rain": rain, "snow": 0.0, "wind": 0.0, "temp_c": 0.0}
	f.weather_now = func(): return {"rain": rain, "snow": 0.0, "wind": 0.0, "temp_c": 0.0}
	f.rain_now = func(): return rain
	f.cover_at = func(_p): return 0.0
	f.peer_connected_hello(1, "firelight001")
	f._characters[f._peer_key[1]]["grace_s"] = 0.0
	f.report_position(1, HOME)
	return f


func info_of(f, peer: int) -> Dictionary:
	for row in f.wolf_info():
		if int(row["peer"]) == peer:
			return row

	return {}


func place(f, id: int, kind: String, at: Vector3, lit: bool) -> void:
	var def: Dictionary = f._structures[kind]
	var st: Dictionary = {"kind": kind, "yaw": 0.0}

	if lit:
		st["lit"] = true
		st["fuel_left"] = f.light_burn_s(def)

	f._items[id] = {"number": f.table.number_of(str(def.get("item", kind))), "count": 1, "pos": at, "left": 1.0e9, "struct": st}
	f._lit_valid = false


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var f = make()
	var inv = f.inventory_of(1)

	# 1. Torches and wolves.
	var torch: int = f.table.number_of("torch")
	f.action(1, Net.ACT_ADMIN_GIVE, torch, 0, 1, Vector3.ZERO)
	var slot: int = inv.numbers.find(torch)
	check(slot >= 0 and inv.on_hotbar(slot), "a torch on the hotbar")
	check(not bool(info_of(f, 1).get("torch", true)), "a torch carried but not burning keeps no wolf away")
	f.action(1, Net.ACT_TORCH_BURN, slot, 0, 0, Vector3.ZERO)
	check(bool(info_of(f, 1).get("torch", false)), "burning in hand: the wolves' walking rule counts it")
	var ring: float = -1.0

	for spot in f.fire_spots():
		if (spot[0] as Vector3).is_equal_approx(HOME):
			ring = float(spot[1])

	var animals_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	var walk_m: float = float(animals_cfg.get("wolves", {}).get("torch_light_m", -1.0))
	check(is_equal_approx(ring, 9.0) and is_equal_approx(walk_m, ring), "and the keep-off ring is the walking rule's 9 m (ring %.1f, walking %.1f)" % [ring, walk_m])
	inv.inst_of(slot)["out"] = true
	f._torch_seen.erase(1)
	f.action(1, Net.ACT_TORCH_BURN, slot, 0, 0, Vector3.ZERO)
	check(not bool(info_of(f, 1).get("torch", true)), "a torch that went out counts for nothing")
	inv.clear_slot(slot)

	# 2. Warmth by a Fireplace and a brazier.
	var cold: float = f.warmth_target(1)
	place(f, 901, "fireplace", HOME + Vector3(2.0, 0.0, 0.0), false)
	check(is_equal_approx(f.warmth_target(1), cold), "an unlit Fireplace warms nobody")
	f._items[901]["struct"]["lit"] = true
	f._items[901]["struct"]["fuel_left"] = 3000.0
	f._lit_valid = false
	var by_fireplace: float = f.warmth_target(1)
	check(by_fireplace > cold, "a lit Fireplace 2 m off warms (%.1f, cold %.1f)" % [by_fireplace, cold])
	var rows: Array = f._heat_rows()
	check(rows.size() == 1 and is_equal_approx(float(rows[0][1].get("heat_c", 0.0)), 20.0) and is_equal_approx(float(rows[0][1].get("heat_radius_m", 0.0)), 4.0), "as the medium campfire: 20 C within 4 m")
	f._soak[1] = 0.8
	f._update_soak(1, 3600.0)
	check(float(f._soak.get(1, 1.0)) < 0.8, "wet clothes dry by the Fireplace (%.2f)" % float(f._soak.get(1, 1.0)))
	f._soak[1] = 0.0   # dry again: the cold was read dry
	f._items[901]["pos"] = HOME + Vector3(10.0, 0.0, 0.0)
	f._lit_valid = false
	check(is_equal_approx(f.warmth_target(1), cold), "10 m off it warms nothing")
	place(f, 902, "stone_brazier", HOME + Vector3(0.0, 0.0, 2.0), true)
	var brazier_row: Dictionary = {}

	for row in f._heat_rows():
		if (row[0] as Vector3).is_equal_approx(HOME + Vector3(0.0, 0.0, 2.0)):
			brazier_row = row[1]

	check(is_equal_approx(float(brazier_row.get("heat_c", 0.0)), 10.0) and f.warmth_target(1) > cold, "a lit brazier warms as the small fire (10 C within 2.5 m)")

	# 3. Standing lights in the rain and wolves.
	place(f, 903, "standing_torch", HOME + Vector3(-30.0, 0.0, 0.0), true)
	var torch_ring: float = -1.0

	for spot in f.fire_spots():
		if (spot[0] as Vector3).is_equal_approx(HOME + Vector3(-30.0, 0.0, 0.0)):
			torch_ring = float(spot[1])

	check(is_equal_approx(torch_ring, 8.0), "a lit Standing torch keeps wolves 8 m off (%.1f)" % torch_ring)
	f._items.erase(903)
	place(f, 904, "stone_torch_pillar", HOME + Vector3(-40.0, 0.0, 0.0), true)
	var dry_left: float = float(f._items[902]["struct"]["fuel_left"])
	f._lights_tick(10.0)
	var dry_burn: float = dry_left - float(f._items[902]["struct"]["fuel_left"])
	rain = 0.9
	dry_left = float(f._items[902]["struct"]["fuel_left"])
	f._lights_tick(10.0)
	var wet_burn: float = dry_left - float(f._items[902]["struct"]["fuel_left"])
	check(not bool(f._items[904]["struct"].get("lit", false)), "the Stone torch pillar goes out in open rain like the other posts")
	check(bool(f._items[902]["struct"].get("lit", false)) and is_equal_approx(wet_burn, dry_burn * 1.25), "a brazier burns on in heavy rain, 1.25 times as fast (%.1f s against %.1f s)" % [wet_burn, dry_burn])
	f._items.erase(904)
	f._items.erase(902)
	rain = 0.0

	# 4. A restart with the Fireplace lit beside the player.
	f._items[901]["pos"] = HOME + Vector3(2.0, 0.0, 0.0)
	f._dirty = true
	f.save()
	f._finish_writer()
	f = make()
	var still: bool = false

	for id in f._items:
		var it: Dictionary = f._items[id]

		if it.has("struct") and str(it["struct"].get("kind", "")) == "fireplace":
			still = bool(it["struct"].get("lit", false))

	check(still, "after a restart the Fireplace is still lit")
	check(f.warmth_target(1) > cold, "and still warms (%.1f)" % f.warmth_target(1))

	print("test_fire_light_walk: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
