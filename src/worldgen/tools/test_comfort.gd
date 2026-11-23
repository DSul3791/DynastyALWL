extends SceneTree

# Comfort (docs/COMFORT_DESIGN.md): the furniture level near a player (level 0 outside cover; sheltered alone = 1; a rough bed adds its point; five
# chairs count once; an unlit campfire adds 0, a lit one 1; only the best bed counts; far and other-floor pieces do not count), and the comfort meter
# (Dave 23 Nov 2026, s11): the points it heads for, its slow climb and fall, the bonus by level (half harm, slower exertion, food and water last
# longer), the HUD message, saving, and death emptying it.
#   godot --headless --path . --script res://src/worldgen/tools/test_comfort.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0
var items
var covered: Array = [true]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func add_struct(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": 0, "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	items._next_id += 1
	return id


func level() -> int:
	return int(items.comfort_at(1, true)["level"])


func _init() -> void:
	var dir: String = "user://test_comfort"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.cover_at = func(_p): return 1.0 if covered[0] else 0.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "comfort000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	covered[0] = false
	check(level() == 0 and not bool(items.comfort_at(1, true)["sheltered"]), "outside any cover the level is 0")
	add_struct("chair", Vector3(2.0, 10.0, 0.0))
	check(level() == 0, "a chair does not comfort someone who is not sheltered")
	covered[0] = true
	check(level() == 3, "sheltered (1) plus a chair (2) = 3")

	for n in range(5):
		add_struct("chair", Vector3(1.0 + float(n) * 0.2, 10.0, 1.0))

	check(level() == 3, "five more chairs count as the same one kind (still 3)")
	add_struct("rough_bed", Vector3(0.0, 10.0, 3.0))
	check(level() == 4, "a rough bed adds 1 (4)")
	add_struct("straw_bed", Vector3(0.0, 10.0, -3.0))
	check(level() == 5, "only the best bed counts: a straw bed (2) instead of the rough one (5)")
	var fire: int = items._next_id
	items._items[fire] = {"number": 0, "count": 1, "pos": Vector3(3.0, 10.0, 0.0), "left": 1.0e9, "fire": {"state": 9, "burn_left": 100.0}}
	items._next_id += 1
	check(level() == 5, "a laid, unlit fire adds nothing")
	items._items[fire]["fire"]["state"] = 1
	check(level() == 6, "the same fire lit adds 1 (6)")
	var torch: int = add_struct("wall_torch", Vector3(-2.0, 10.0, 0.0))
	check(level() == 6, "an unlit wall torch adds nothing")
	items._items[torch]["struct"]["lit"] = true
	check(level() == 7, "a lit wall torch adds 1 (7)")
	add_struct("workbench", Vector3(-4.0, 10.0, 4.0))
	add_struct("wicker_basket", Vector3(4.0, 10.0, 4.0))
	check(level() == 9, "workbench (1) and Wicker basket (1) add 2 (9)")
	add_struct("bench", Vector3(40.0, 10.0, 40.0))
	check(level() == 9, "a bench 56 m away adds nothing")
	var upstairs: int = add_struct("table", Vector3(0.0, 20.0, 0.0))
	check(level() == 9, "a table on another floor (10 m up) adds nothing")
	items._items.erase(upstairs)

	# The comfort meter (Dave 23 Nov 2026).
	var v: Dictionary = items.vitals_of(1)
	var cfg: Dictionary = items._meter_cfg()
	check(int(cfg.get("max", 0)) == 10, "the meter runs 0 to 10")
	v["fed"] = 2400.0
	v["wet"] = 2400.0
	items._by_fire[1] = false
	items._comfort_cache.clear()
	var target: float = items.comfort_target(1)
	# sheltered 1 + food >25 1 + food >50 1 + water >50 1 + furniture (chair, workbench, basket, torch... sheltered) 2 = 6; not by a fire, not on a bed, not dressed
	check(target == 6.0, "sheltered, fed, watered, furniture near: the meter heads for 6 (%.0f)" % target)
	items._by_fire[1] = true
	check(items.comfort_target(1) == 7.0, "warmed by a fire adds 1 (7)")
	v["fed"] = 1000.0
	check(items.comfort_target(1) == 6.0, "food at 42 percent loses the over-50 point (6)")
	v["fed"] = 400.0
	v["wet"] = 1000.0
	check(items.comfort_target(1) == 4.0, "food at 17 percent and water at 42 percent: shelter, fire and furniture (2) only (4)")
	covered[0] = false
	items._comfort_cache.clear()
	items._by_fire[1] = false
	check(items.comfort_target(1) == 0.0, "out in the open, hungry and away from a fire: 0, furniture does not count unsheltered")
	covered[0] = true
	items._comfort_cache.clear()
	v["fed"] = 2400.0
	v["wet"] = 2400.0
	items._by_fire[1] = true
	items._characters[items._peer_key[1]]["comfort"] = 0.0
	items._stance[1] = 0
	items._comfort_meter_tick(1, v, 60.0)
	check(absf(items.comfort_meter(1) - 1.0) < 0.01, "standing about it climbs 1 point a minute (%.2f)" % items.comfort_meter(1))
	items._stance[1] = 2
	items._comfort_meter_tick(1, v, 60.0)
	check(absf(items.comfort_meter(1) - 3.0) < 0.01, "sitting it climbs twice as fast (%.2f)" % items.comfort_meter(1))
	items._comfort_meter_tick(1, v, 600.0)
	check(absf(items.comfort_meter(1) - 7.0) < 0.01, "and stops at the target, 7 (%.2f)" % items.comfort_meter(1))
	check(items.comfort_level(1) == 7 and absf(items.comfort_bonus(1, "damage_taken_mult") - 0.65) < 0.001 and absf(items.comfort_bonus(1, "hunger_thirst_mult") - 0.65) < 0.001, "at 7 the bonus is 70 percent: harm x0.65, food and water x0.65")
	var tier: Dictionary = items.rested_tier(1)
	check(absf(float(tier.get("exhaustion_mult", 1.0)) - 0.65) < 0.001 and absf(float(tier.get("regen_mult", 1.0)) - 1.245) < 0.001, "the old Rested hooks read the meter (exhaustion x%.3f, regen x%.3f)" % [float(tier.get("exhaustion_mult", 1.0)), float(tier.get("regen_mult", 1.0))])
	# It falls when the target drops: slow sitting, faster walking, faster again running in the wet cold.
	covered[0] = false
	items._comfort_cache.clear()
	items._by_fire[1] = false
	v["fed"] = 0.0
	v["wet"] = 0.0
	items._comfort_meter_tick(1, v, 60.0)
	var sat_fall: float = 7.0 - items.comfort_meter(1)
	check(absf(sat_fall - 0.06) < 0.005, "sitting, it falls 0.06 a minute (%.3f)" % sat_fall)
	items._stance[1] = 0
	items._exertion[1] = 0.4
	var m0: float = items.comfort_meter(1)
	items._comfort_meter_tick(1, v, 60.0)
	var walk_fall: float = m0 - items.comfort_meter(1)
	check(absf(walk_fall - 0.15) < 0.005, "walking about, 0.15 a minute: about 1 point in 7 minutes (%.3f)" % walk_fall)
	items._exertion[1] = 1.0
	v["soak"] = 1.0
	items._soak[1] = 1.0
	v["warmth"] = 30.0
	m0 = items.comfort_meter(1)
	items._comfort_meter_tick(1, v, 60.0)
	var storm_fall: float = m0 - items.comfort_meter(1)
	check(absf(storm_fall - 0.15 * 2.5 * 1.5 * 1.5) < 0.01, "running soaked in the cold, %.2f a minute (x2.5 x1.5 x1.5)" % storm_fall)
	items._comfort_meter_tick(1, v, 3600.0)
	check(items.comfort_meter(1) == 0.0 and items.rested_tier(1).is_empty() and items.comfort_bonus(1, "damage_taken_mult") == 1.0, "it bottoms out at 0 with no bonus")
	items._exertion[1] = 0.0
	v["soak"] = 0.0
	items._soak[1] = 0.0
	v["warmth"] = 100.0
	covered[0] = true
	items._comfort_cache.clear()
	# The bonus on harm: at 10 a blow does half.
	items._characters[items._peer_key[1]]["comfort"] = 10.0
	v["health"] = 100.0
	items.hurt_player(1, 20.0, false, "test")
	check(absf(float(v["health"]) - 90.0) < 0.01, "at comfort 10 a 20 point blow takes 10 (health counts double): %.1f" % float(v["health"]))
	items._characters[items._peer_key[1]]["comfort"] = 0.0
	v["health"] = 100.0
	items.hurt_player(1, 20.0, false, "test")
	check(absf(float(v["health"]) - 80.0) < 0.01, "at 0 it takes the full 20: %.1f" % float(v["health"]))
	items._characters[items._peer_key[1]]["comfort"] = 7.0
	items._stance[1] = 0
	items._items.erase(torch)   # the lights below start from no lit torch
	var place: int = add_struct("fireplace", Vector3(5.0, 10.0, -1.0))
	items._items[place]["struct"]["lit"] = true
	items._items[place]["struct"]["fuel_left"] = 7200.0

	# Lights: E with the fuel lights a wall torch; it counts while it burns and goes out when the fuel is used up.
	var lamp: int = add_struct("wall_torch", Vector3(-5.0, 10.0, -2.0))
	items.report_position(1, Vector3(-4.0, 10.0, -2.0))
	var before_lamp: int = level()
	items._use_struct(1, items.inventory_of(1), lamp)
	check(not bool(items._items[lamp]["struct"].get("lit", false)) and level() == before_lamp, "without a stick the torch does not light")
	items.inventory_of(1).add(items.table.number_of("stick"), 2)
	items._use_struct(1, items.inventory_of(1), lamp)
	check(bool(items._items[lamp]["struct"].get("lit", false)) and level() == before_lamp + 1, "with a stick the torch burns and adds 1")
	items._lights_tick(1799.0)
	check(bool(items._items[lamp]["struct"].get("lit", false)), "it still burns after 1799 s")
	items._lights_tick(5.0)
	check(not bool(items._items[lamp]["struct"].get("lit", false)) and level() == before_lamp, "and goes out when the stick is used up")

	# The HUD message (protocol 164): tenths, target, trend and the tooltip; told once, again when something changes; the tip only when it changed.
	var told: Array = []
	items.send_comfort = func(_p, t, g, d, words): told.append([t, g, d, words])
	items._comfort_goal[1] = 7.0
	items._comfort_tick()
	items._comfort_tick()
	check(told.size() == 1 and told[0][0] == 70 and told[0][1] == 7 and told[0][2] == 0, "the client is told 70 tenths, target 7, steady, once (%s)" % str(told).left(80))
	var tip: String = str(told[0][3])
	check(tip.contains("Comfort 7 of 10") and tip.contains("Bonus 70%") and tip.contains("health counts x1.5") and tip.contains("You have:") and tip.contains("Missing:") and tip.contains("Lying on a bed"), "the tooltip gives the bonus, what counts and what is missing")
	items._comfort_goal[1] = 9.0
	items._comfort_tick()
	check(told.size() == 2 and told[1][1] == 9 and told[1][2] == 1 and str(told[1][3]) == "", "a higher target is told as rising, without resending the same tooltip")
	var Badge := load("res://src/client/ui/comfort_badge.gd")
	check(Badge.level_of(70) == 7 and Badge.level_of(69) == 6 and Badge.level_of(100) == 10 and Badge.level_of(0) == 0, "the HUD symbol shows the whole level of the tenths")

	# Saved and cleared.
	items._characters[items._peer_key[1]]["comfort"] = 6.5
	items._characters[items._peer_key[1]]["rested"] = {"level": 9, "until": 1.0e12}   # an old save's Rested row: dropped, never read
	items._save_characters()
	items._finish_writer()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.send_notice = func(_p, _t): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	again.peer_connected_hello(1, "comfort000001")
	var lit_rows: Array = items._light_rows_save()
	check(lit_rows.size() == 1 or lit_rows.size() == 2, "the lit lights are listed for saving (%d)" % lit_rows.size())
	var fresh = ItemsScript.new()
	fresh.send_full = func(_p, _b): pass
	fresh.send_slots = func(_p, _b): pass
	fresh.send_world_items = func(_p, _a, _r): pass
	fresh.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	fresh.send_notice = func(_p, _t): pass
	fresh.ground_height = func(_x, _z): return 10.0
	fresh.setup(ItemTableScript.load_default(), dir + "_fresh")
	var cold: int = fresh._next_id
	fresh._items[cold] = {"number": 0, "count": 1, "pos": Vector3(16.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "wall_torch", "yaw": 0.0}}
	fresh._apply_lit_rows([[16.0, 10.0, 0.0, 900.0]])
	check(bool(fresh._items[cold]["struct"].get("lit", false)) and float(fresh._items[cold]["struct"]["fuel_left"]) == 900.0, "a saved lit torch is lit again, with its fuel, after a load")
	check(absf(again.comfort_meter(1) - 6.5) < 0.001 and not again._characters[again._peer_key[1]].has("rested"), "the meter is saved with the character (%.2f after a reload); an old Rested row is dropped" % again.comfort_meter(1))
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.kill(1, "test")
	check(items.comfort_meter(1) == 0.0, "death empties the meter")
	print("comfort: %d failures" % failures)
	quit(1 if failures > 0 else 0)
