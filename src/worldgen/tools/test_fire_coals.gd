extends SceneTree

# After the flames (docs/design/fire_coals_design.md, step 1; coordinator decision 8 Nov 2026, Dave may revert): a fire that burned 10 minutes
# burns out to coals (76), then after coals_s to warm ash (77), then after ash_s to cold ash (8), then is gone; a 2-minute stick fire goes straight
# to cold ash; firewood laid on coals catches in 45 s with no E; tinder and wood light warm ash in light rain every time, where a cold fire and warm
# ash without tinder sometimes fail the damp roll; rain on uncovered coals turns them to ash and then the ash goes cold, covered coals stay; coals
# warm within 1.5 m and not at 3 m; wolves are not held off by coals; a save and load keeps 76 and 77 with their time left.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_coals.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_fire_coals"
const AT := Vector3(2.0, 10.0, 0.0)

var failures: int = 0
var rain: float = 0.0
var roof: float = 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(key: String):
	var f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(_p, _t): pass
	f.setup(ItemTableScript.load_default(), DIR)
	f.ground_height = func(_x, _z): return 10.0
	f.rain_now = func(): return rain
	f.cover_at = func(_p): return roof
	f.peer_connected_hello(1, key)
	f._characters[f._peer_key[1]]["grace_s"] = 0.0
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	return f


# A fire record at AT: `wood` burning seconds by class, lit at `state` (or laid, 9), `lit_s` seconds burned so far.
func fire_at(f, id: int, state: int, wood: Dictionary, lit_s: float = 0.0, left: float = 1.0e9) -> Dictionary:
	var fire: Dictionary = {"state": state, "burn_left": 0.0, "wood": {"log": 0.0, "firewood": 0.0, "weak": 0.0}, "covered": false, "recheck": 0.0}

	for cls in wood:
		fire["wood"][cls] = float(wood[cls])

	f._fire_sum(fire)

	if lit_s > 0.0:
		fire["lit_s"] = lit_s

	f._items[id] = {"number": f.table.number_of("campfire_kit"), "count": 1, "pos": AT, "left": left, "fire": fire}
	return fire


# Time passes as the item tick runs it: fires, then item lifetimes.
func run(f, seconds: float, dt: float) -> void:
	var t: float = 0.0

	while t < seconds - 0.0001:
		var step: float = minf(dt, seconds - t)
		f._fires(step)
		f._expire_items(step)
		t += step


func state_of(f, id: int) -> int:
	return int(f._items[id]["fire"]["state"]) if f._items.has(id) else -1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var f = make("firecoals0001")
	var cfg: Dictionary = f._cooking.get("coals", {})
	var coals_s: float = float(cfg.get("coals_s", 0.0))
	var ash_s: float = float(cfg.get("ash_s", 0.0))
	check(coals_s == 7200.0 and ash_s == 43200.0 and float(cfg.get("coal_bed_s", 0.0)) == 600.0, "cooking.json coals: 2 h of coals, 12 h of warm ash, a 10-minute coal bed")
	check(ItemsScript.FIRE_STATE_COALS == 76 and ItemsScript.FIRE_STATE_ASH == 77, "coals are state 76 and warm ash 77")
	check(StructureLook.CAMPFIRE_STATES.has(76) and StructureLook.CAMPFIRE_STATES.has(77) and StructureLook.look_of(76) == "campfire" and StructureLook.look_of(77) == "campfire", "the client draws 76 and 77 as the campfire")

	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json")).get("structures", {})

	for kind in structures:
		check(not [76, 77].has(int(structures[kind].get("state", -1))), "no building piece uses state 76 or 77 (%s)" % kind)

	# 1. A 10-minute fire burns out to coals, then warm ash, then cold ash, then is gone.
	var long_fire: Dictionary = fire_at(f, 900, ItemsScript.FIRE_STATE_SURVIVAL, {"weak": 700.0})
	run(f, 700.5, 1.0)
	check(state_of(f, 900) == 76, "a fire that burned 700 s leaves coals (state %d)" % state_of(f, 900))
	check(absf(float(f._items[900]["left"]) - coals_s) < 2.0, "for coals_s (%.0f s left)" % float(f._items[900]["left"]))
	check(not ItemsScript.fire_is_lit(76) and not ItemsScript.fire_is_lit(77), "coals and warm ash are not a lit fire")
	check(absf(float(f._fire_extra(f._items[900]).get("glow", -1.0)) - 1.0) < 0.01, "fresh coals send glow 1 on the row")
	run(f, coals_s * 0.5, 10.0)
	check(absf(float(f._fire_extra(f._items[900]).get("glow", -1.0)) - 0.5) < 0.01, "half way through, glow 0.5")
	run(f, coals_s * 0.5 + 1.0, 10.0)
	check(state_of(f, 900) == 77, "after coals_s the coals are warm ash (state %d)" % state_of(f, 900))
	check(not long_fire.has("lit_s"), "the coal bed is spent once it is ash")
	run(f, ash_s - 2.0, 60.0)
	check(state_of(f, 900) == 77, "warm ash lasts ash_s (state %d)" % state_of(f, 900))
	run(f, 3.0, 1.0)
	check(state_of(f, 900) == 8, "then it is cold ash (state %d)" % state_of(f, 900))
	run(f, ItemsScript.FIRE_OUT_S + 1.0, 5.0)
	check(not f._items.has(900), "and after FIRE_OUT_S the cold ash is gone")

	# 2. A 2-minute stick fire goes straight to cold ash.
	fire_at(f, 901, ItemsScript.FIRE_STATE_SURVIVAL, {"weak": 120.0})
	run(f, 121.0, 1.0)
	check(state_of(f, 901) == 8, "a 2-minute stick fire leaves no coals (state %d)" % state_of(f, 901))
	f._items.erase(901)

	# 3. Firewood laid on coals catches in 45 s with no E.
	fire_at(f, 902, 76, {}, 700.0, coals_s)
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("firewood"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_FUEL, 902, 0, 0, Vector3.ZERO)
	check(state_of(f, 902) == 76 and float(f._items[902]["fire"]["burn_left"]) > 0.0, "firewood goes onto the coals (state %d)" % state_of(f, 902))
	run(f, 44.0, 0.25)
	check(state_of(f, 902) == 76, "not caught after 44 s (state %d)" % state_of(f, 902))
	run(f, 1.5, 0.25)
	check(ItemsScript.fire_is_lit(state_of(f, 902)), "caught by 45 s with no E (state %d)" % state_of(f, 902))
	check(float(f._items[902]["left"]) > 1.0e8, "a fire burning again does not run out of time")
	f._items.erase(902)

	# 4. Light rain (0.15, under the 0.2 that puts fires out): a cold laid fire and warm ash without tinder sometimes fail the damp roll; tinder
	# and wood on warm ash light it every time and use the tinder up.
	rain = 0.15
	var cold_fails: int = 0
	var bare_fails: int = 0
	var tinder_lit: int = 0

	for _n in 30:
		fire_at(f, 903, 9, {"weak": 120.0}, 0.0, ItemsScript.FIRE_LAID_S)
		f.action(1, Net.ACT_LIGHT, 903, 0, 0, Vector3.ZERO)
		cold_fails += 1 if state_of(f, 903) == 9 else 0
		fire_at(f, 904, 77, {"weak": 120.0}, 0.0, ash_s)
		f.action(1, Net.ACT_LIGHT, 904, 0, 0, Vector3.ZERO)
		bare_fails += 1 if state_of(f, 904) == 77 else 0

	var fibre: int = f.table.number_of(str(f._cooking.get("tinder", "plant_fibre")))
	f.action(1, Net.ACT_ADMIN_GIVE, fibre, 0, 30, Vector3.ZERO)
	var inv = f.inventory_of(1)

	for _n in 30:
		fire_at(f, 905, 77, {"weak": 120.0}, 0.0, ash_s)
		f.action(1, Net.ACT_LIGHT, 905, 0, 0, Vector3.ZERO)
		tinder_lit += 1 if ItemsScript.fire_is_lit(state_of(f, 905)) else 0

	check(cold_fails > 0, "in light rain a cold laid fire sometimes fails to catch (%d of 30)" % cold_fails)
	check(bare_fails > 0, "so does warm ash with no tinder (%d of 30)" % bare_fails)
	check(tinder_lit == 30, "tinder and wood light warm ash every time (%d of 30)" % tinder_lit)
	check(not inv.has(fibre, 1), "each light used one tinder")
	rain = 0.0

	for k in [903, 904, 905]:
		f._items.erase(k)

	# 5. Rain on uncovered coals: warm ash after rain_s, then cold after a further ash_rain_s; under a roof they stay coals.
	rain = 0.5
	fire_at(f, 906, 76, {}, 700.0, coals_s)
	run(f, float(cfg.get("rain_s", 0.0)) - 2.0, 1.0)
	check(state_of(f, 906) == 76, "coals last a little in the rain (state %d)" % state_of(f, 906))
	run(f, 3.0, 1.0)
	check(state_of(f, 906) == 77, "rain_s of rain turns uncovered coals to ash (state %d)" % state_of(f, 906))
	run(f, float(cfg.get("ash_rain_s", 0.0)) + 1.0, 1.0)
	check(state_of(f, 906) == 8, "a further ash_rain_s and the ash is cold (state %d)" % state_of(f, 906))
	f._items.erase(906)
	roof = 2.0
	fire_at(f, 907, 76, {}, 700.0, coals_s)
	run(f, 900.0, 5.0)
	check(state_of(f, 907) == 76, "covered coals stay coals in the rain (state %d)" % state_of(f, 907))
	roof = 0.0
	rain = 0.0

	# 6. Coals warm within 1.5 m and not at 3 m.
	f._items.erase(907)
	f.weather_now = func(): return {"temp_c": 2.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	f.report_position(1, AT + Vector3(3.0, 0.0, 0.0))
	var none: float = f.warmth_target(1)
	fire_at(f, 908, 76, {}, 700.0, coals_s)
	var far: float = f.warmth_target(1)
	f.report_position(1, AT + Vector3(1.0, 0.0, 0.0))
	var near: float = f.warmth_target(1)
	check(is_equal_approx(far, none), "coals 3 m off give no warmth (%.1f vs %.1f)" % [far, none])
	check(near > none + 1.0, "coals 1 m off do (%.1f vs %.1f)" % [near, none])

	# 7. Wolves are not held off by coals.
	check(not f._lit_fires().has(AT), "coals are not on the list of fires that keep wolves off")

	# 8. A save and load keeps 76 and 77 with their time left.
	fire_at(f, 909, 77, {}, 0.0, 5000.0)
	f._items[908]["left"] = 3000.0
	f._dirty = true
	f.save()
	f._finish_writer()
	var g = make("firecoals0001")
	var coals_left: float = -1.0
	var ash_left: float = -1.0

	for k in g._items:
		if g._items[k].has("fire") and int(g._items[k]["fire"]["state"]) == 76:
			coals_left = float(g._items[k]["left"])
			check(float(g._items[k]["fire"].get("lit_s", 0.0)) == 700.0, "the coal bed's burned time survives a restart")
		elif g._items[k].has("fire") and int(g._items[k]["fire"]["state"]) == 77:
			ash_left = float(g._items[k]["left"])

	check(absf(coals_left - 3000.0) < 1.0, "coals load with their time left (%.0f)" % coals_left)
	check(absf(ash_left - 5000.0) < 1.0, "warm ash loads with its time left (%.0f)" % ash_left)

	print("test_fire_coals: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
