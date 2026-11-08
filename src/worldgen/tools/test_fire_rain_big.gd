extends SceneTree

# Rain on a big fire (docs/design/fire_coals_design.md, step 2; coordinator decision 8 Nov 2026, Dave may revert): a large fire (41) on a
# coal bed burns on through rain of any strength, uncovered, 1.25 times as fast in rain of 0.6 or more and with smoke 1 on its row; one lit a
# minute ago goes out; small and medium fires go out as before; under a roof nothing changes; once its logs are gone the rain takes it.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_rain_big.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const DIR := "user://test_fire_rain_big"
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

	var f = make("firerainbig01")
	var cfg: Dictionary = f._cooking.get("coals", {})
	var bonfire: int = ItemsScript.FIRE_STATE_BONFIRE
	check(float(cfg.get("rain_burn_x", 0.0)) == 1.25 and float(cfg.get("rain_burn_from", 0.0)) == 0.6, "cooking.json coals: rain_burn_x 1.25 from rain 0.6")

	# 1. A log fire on a coal bed stays lit through 30 real minutes of rain 0.9, burns 1.25 times as fast, and smokes.
	rain = 0.9
	var big: Dictionary = fire_at(f, 900, bonfire, {"log": 4000.0}, 700.0)
	run(f, 1800.0, 1.0)
	check(state_of(f, 900) == bonfire, "a log fire on a coal bed burns on through 30 min of rain 0.9 (state %d)" % state_of(f, 900))
	check(absf(float(big["burn_left"]) - (4000.0 - 1800.0 * 1.25)) < 2.0, "and burns 1.25 times as fast (%.0f s left)" % float(big["burn_left"]))
	check(int(f._fire_extra(f._items[900]).get("smoke", 0)) == 1, "its row sends smoke 1")
	f._items.erase(900)

	# 2. A log fire lit a minute ago (no coal bed) goes out.
	fire_at(f, 901, bonfire, {"log": 4000.0}, 60.0)
	run(f, 5.0, 1.0)
	check(state_of(f, 901) == 9, "a log fire lit a minute ago goes out in the rain (state %d)" % state_of(f, 901))
	f._items.erase(901)

	# 3. A firewood fire goes out as today, coal bed or not.
	fire_at(f, 902, 1, {"firewood": 2000.0}, 700.0)
	run(f, 5.0, 1.0)
	check(state_of(f, 902) == 9, "a medium fire goes out in the rain (state %d)" % state_of(f, 902))
	f._items.erase(902)
	fire_at(f, 903, ItemsScript.FIRE_STATE_SURVIVAL, {"weak": 500.0}, 700.0)
	run(f, 5.0, 1.0)
	check(state_of(f, 903) == 9, "so does a small one (state %d)" % state_of(f, 903))
	f._items.erase(903)

	# 4. In light rain (0.3) the log fire burns on at its own pace, smoking.
	rain = 0.3
	var light: Dictionary = fire_at(f, 904, bonfire, {"log": 4000.0}, 700.0)
	run(f, 600.0, 1.0)
	check(state_of(f, 904) == bonfire and absf(float(light["burn_left"]) - 3400.0) < 2.0, "in light rain it burns at its own pace (%.0f s left)" % float(light["burn_left"]))
	check(int(f._fire_extra(f._items[904]).get("smoke", 0)) == 1, "and smokes")
	f._items.erase(904)

	# 5. Under a roof: no extra burn and no smoke.
	rain = 0.9
	roof = 2.0
	var dry: Dictionary = fire_at(f, 905, bonfire, {"log": 4000.0}, 700.0)
	run(f, 600.0, 1.0)
	check(absf(float(dry["burn_left"]) - 3400.0) < 2.0 and not f._fire_extra(f._items[905]).has("smoke"), "under a roof it burns as in the dry, with no smoke (%.0f s left)" % float(dry["burn_left"]))
	f._items.erase(905)
	roof = 0.0

	# 6. Once its logs are gone it is a medium fire, and the rain takes it.
	fire_at(f, 906, bonfire, {"log": 80.0, "firewood": 2000.0}, 700.0)
	run(f, 200.0, 1.0)
	check(state_of(f, 906) == 9, "with its logs gone it is medium and the rain puts it out (state %d)" % state_of(f, 906))
	check(not f._items[906]["fire"].has("smoke"), "and it stops smoking")
	rain = 0.0

	print("test_fire_rain_big: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
