extends SceneTree

# The Advanced smelter on real server state (GOALS-REPAIR R4; master s2.7 items 7 and 8; CATALOG_IMPLEMENTATION_PLAN R4; plan P3 "Smelting
# acceptance tests" and "Windmill acceptance test"; src/stream/server_smelter.gd):
#   1. one station (the old Blast furnace row, large_forge #93), its windmill and two bellows built in: hopper 80, input 80, a 160-ingot rack,
#      two lanes at 1.30 x 1.30 = 1.69 times the Primitive rate; no crafting station; the old 2 Iron ingot steel recipe (193) is retired and
#      no live recipe gives Steel;
#   2. in a calm (wind below smelting.wind_min_mps) it makes no progress at all, the ore and fuel kept; in wind two Iron ore become two Iron
#      ingots together in about 11.83 s;
#   3. a calm mid-batch stops both lanes with their time kept; the wind back finishes the SAME batch, no second batch of ore or fuel taken;
#   4. carbon: Coal or Charcoal put plainly (or onto a hopper slot) goes to the hopper, never the input; Iron ore with fuel in the hopper only
#      makes Iron, not Steel; Coal or Charcoal dragged onto an input slot (protocol 121) goes into the input as carbon, and Iron ore with it makes
#      Steel, the carbon and the hopper fuel each taken once; at the Improved smelter a drag onto its input still goes to its hopper;
#   5. the lanes never share ore: one Iron ore is one ingot; Iron ore and carbon beside more Iron ore make one Steel and one Iron; 1 Copper and
#      1 Tin ore make exactly 2 Bronze ingots, 1 Copper ore alone 1 Copper ingot;
#   6. a full rack (160) makes it wait;
#   7. save and load keep both lanes' banked time and the carbon in the input, and it finishes after the load;
#   8. nothing is lost or made: every item counted in the store, the pack and in front of it is the same before and after each run but for
#      the ore, carbon and fuel a finished ingot took.
#   godot --headless --path . --script res://src/worldgen/tools/test_advanced_smelter.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Weather := preload("res://src/shared/weather.gd")
const DIR := "user://test_advanced_smelter"
const HERE := Vector3(5.0, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []
var key: String = "advsmelt0001"
var wind: Array = [0.0]   # the world wind now, m/s


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_reject = func(_p, _r): pass
	s.send_notice = func(_p, text): said.append(str(text))
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s.game_seconds = func(): return 1000.0 * 86400.0
	s.skill_level = func(_p, _s): return 1.0
	s.weather_now = func(): return {"wind": Weather.wind_of_mps(float(wind[0]))}
	s.peer_connected_hello(1, key)
	s.report_position(1, HERE)
	s.vitals_of(1)["weight"] = 5000.0
	return s


func n(id: String) -> int:
	return items.table.number_of(id)


func place(spec: String) -> int:
	var id: int = items.dev_place(spec)

	if id > 0:
		items._items[id]["struct"]["owner"] = key

	return id


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func def_of(id: int) -> Dictionary:
	return items._structures[str(items._items[id]["struct"]["kind"])]


func span(id: int, which: String) -> Vector2i:
	var hs: int = int(def_of(id)["smelt"]["hopper_slots"])
	var slots: int = int(def_of(id)["slots"])
	return Vector2i(0, hs) if which == "hopper" else (Vector2i(hs, slots) if which == "input" else Vector2i(slots, slots + int(def_of(id).get("out_slots", 0))))


# Units of an item (0: all) in one part of a smelter's store.
func part(id: int, which: String, number: int = 0) -> int:
	var sp: Vector2i = span(id, which)
	var total: int = 0

	for i in range(sp.x, sp.y):
		if box(id).numbers[i] != 0 and (number == 0 or box(id).numbers[i] == number):
			total += box(id).counts[i]

	return total


func pack(number: int) -> int:
	return items.inventory_of(1).count_of(number)


# A put from the pack through the real path (open, put, close); `target` the store slot it is dragged onto (-1: a plain put). Returns how many went in.
func put_in(id: int, item: String, count: int, target: int = -1) -> int:
	var before: int = pack(n(item))
	items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(n(item)), id, count, Vector3(float(target + 1), 0.0, 0.0))
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	return before - pack(n(item))


func run(seconds: float) -> void:
	for s in range(int(ceil(seconds))):
		items.tick(1.0)


func clear_pack() -> void:
	for s in items.inventory_of(1).slot_count:
		items.inventory_of(1).clear_slot(s)


func empty(id: int) -> void:
	for i in box(id).slot_count:
		box(id).clear_slot(i)

	for k in ["smelt_t", "smelt_job", "smelt_lanes"]:
		items._items[id]["struct"].erase(k)


# The lanes' banked seconds.
func banked(id: int) -> Array:
	var out: Array = [float(items._items[id]["struct"].get("smelt_t", 0.0))]

	for lane in items._items[id]["struct"].get("smelt_lanes", []):
		out.append(float(lane[0]))

	return out


# Every unit of the given items in the store, the pack and loose on the ground: the conservation check.
func total(id: int, ids: Array) -> Dictionary:
	var out: Dictionary = {}

	for item in ids:
		var number: int = n(item)
		var count: int = box(id).count_of(number) + pack(number)

		for gid in items._items:
			if int(items._items[gid].get("number", 0)) == number and not items._items[gid].has("struct") and not items._items[gid].has("scatter"):
				count += int(items._items[gid]["count"])

		out[item] = count

	return out


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	var cfg: Dictionary = items._structures_cfg.get("smelting", {})
	var min_mps: float = float(cfg.get("wind_min_mps", 4.0))
	var steel_job: Dictionary = cfg.get("jobs", {}).get("steel", {})
	var per_ore: int = int(cfg.get("fuel_per_ore", 1))
	var carbon_n: int = int(steel_job.get("carbon", 0))
	var watch: Array = ["iron_ore", "coal", "charcoal", "iron_ingot", "steel_ingot"]

	# --- 1. One station ---
	var adv: int = place("large_forge@8,-1,0")
	var d: Dictionary = def_of(adv) if adv > 0 else {}
	var smelt: Dictionary = d.get("smelt", {})
	check(adv > 0 and items.table.entry("large_forge")["name"] == "Advanced smelter" and int(smelt.get("hopper", 0)) == 80 and int(smelt.get("input", 0)) == 80 and int(smelt.get("output", 0)) == 160 and int(smelt.get("lanes", 0)) == 2 and is_equal_approx(float(smelt.get("speed", 0.0)), 1.3 * 1.3) and bool(smelt.get("wind", false)) and bool(smelt.get("carbon", false)), "the Advanced smelter: hopper 80, input 80, a 160-ingot rack, two lanes at 1.69x, its windmill built in (master s2.7 item 7)")
	check(str(d.get("station", "")) == "" and not d.has("also") and not d.has("fuel"), "it is no crafting station: the old Blast furnace's blast_furnace and smelter stations are gone")
	var steel_from_recipe: bool = false

	for r in items.recipes.numbers():
		steel_from_recipe = steel_from_recipe or int(items.recipes.recipe(int(r)).get("gives", [0, 0])[0]) == n("steel_ingot")

	check(items.recipes.recipe(193).is_empty() and not steel_from_recipe, "the old 2 Iron ingot steel recipe (193) is retired and no live recipe gives a Steel ingot (CATALOG_IMPLEMENTATION_PLAN s1)")
	var steel_out: Array = steel_job.get("out", ["", 0])
	check(not steel_job.is_empty() and str(steel_out[0]) == "steel_ingot" and int(steel_out[1]) == 1 and carbon_n >= 1 and bool(steel_job.get("bellows", false)) and (steel_job.get("in", []) as Array).size() == 1 and str(steel_job["in"][0][0]) == "iron_ore" and int(steel_job["in"][0][1]) == 1, "the steel job: 1 Iron ore and %d carbon in the input give 1 Steel ingot (A-19, provisional)" % carbon_n)
	var lane_s: float = float(smelt.get("ingot_s", 20.0)) / float(smelt.get("speed", 1.0))
	check(absf(lane_s - 11.83) < 0.01, "a lane makes an ingot in %.2f s: two ingots together in about 11.83 s (master s2.7 item 7)" % lane_s)

	# --- 2. Calm, then wind ---
	wind[0] = min_mps * 0.5
	items.give(1, n("charcoal"), 2 * per_ore)
	items.give(1, n("iron_ore"), 2)
	put_in(adv, "charcoal", 2 * per_ore)
	put_in(adv, "iron_ore", 2)
	var before: Dictionary = total(adv, watch)
	run(60.0)
	check(part(adv, "output") == 0 and part(adv, "input", n("iron_ore")) == 2 and part(adv, "hopper") == 2 * per_ore and banked(adv).all(func(t): return t == 0.0), "in a calm (%.1f m/s) its windmill stands: 60 s and no progress at all, ore and fuel kept" % wind[0])
	check(JSON.stringify(total(adv, watch)) == JSON.stringify(before), "nothing lost or made in the calm")
	wind[0] = min_mps + 2.0
	run(lane_s - 1.0)
	check(part(adv, "output", n("iron_ingot")) == 0, "in wind, no Iron ingot before %.2f s" % lane_s)
	run(2.0)
	check(part(adv, "output", n("iron_ingot")) == 2 and part(adv, "input") == 0 and part(adv, "hopper") == 0, "in wind both lanes work: 2 Iron ore became 2 Iron ingots together in about %.2f s, 2 fuel burnt" % lane_s)
	empty(adv)

	# --- 3. A calm mid-batch ---
	items.give(1, n("charcoal"), 2 * per_ore)
	items.give(1, n("iron_ore"), 2)
	put_in(adv, "charcoal", 2 * per_ore)
	put_in(adv, "iron_ore", 2)
	run(6.0)
	var mid: Array = banked(adv)
	wind[0] = 0.0
	run(120.0)
	var held: Array = banked(adv)
	check(mid.size() == 2 and mid.all(func(t): return t > 0.0) and absf(float(held[0]) - float(mid[0])) < 0.01 and absf(float(held[1]) - float(mid[1])) < 0.01 and part(adv, "output") == 0 and part(adv, "input") == 2 and part(adv, "hopper") == 2 * per_ore, "the wind drops mid-batch: both lanes stop with their time kept (%.1f, %.1f s), nothing taken" % [float(mid[0]) if mid.size() > 0 else -1.0, float(mid[1]) if mid.size() > 1 else -1.0])
	wind[0] = min_mps + 2.0
	run(lane_s - 6.0 + 1.0)
	check(part(adv, "output", n("iron_ingot")) == 2 and part(adv, "input") == 0 and part(adv, "hopper") == 0, "the wind back, it finishes the same batch by itself: 2 Iron ingots, the 2 ore and 2 fuel taken once")
	empty(adv)

	# --- 4. Carbon ---
	var input_at: int = span(adv, "input").x
	items.give(1, n("coal"), 3)
	check(put_in(adv, "coal", 1) == 1 and part(adv, "hopper", n("coal")) == 1 and part(adv, "input", n("coal")) == 0, "Coal put plainly goes to the hopper, never the input")
	check(put_in(adv, "coal", 1, 0) == 1 and part(adv, "hopper", n("coal")) == 2 and part(adv, "input", n("coal")) == 0, "Coal dragged onto a hopper slot goes to the hopper")
	items.give(1, n("iron_ore"), 1)
	put_in(adv, "iron_ore", 1)
	run(lane_s + 1.0)
	check(part(adv, "output", n("iron_ingot")) == 1 and part(adv, "output", n("steel_ingot")) == 0, "Iron ore with fuel in the hopper only makes Iron, not Steel")
	empty(adv)
	clear_pack()

	for carbon in ["coal", "charcoal"]:
		items.give(1, n("charcoal"), per_ore)
		items.give(1, n(carbon), carbon_n)
		items.give(1, n("iron_ore"), 1)
		put_in(adv, "charcoal", per_ore)
		check(put_in(adv, carbon, carbon_n, input_at) == carbon_n and part(adv, "input", n(carbon)) == carbon_n and part(adv, "hopper") == per_ore, "%s dragged onto an input slot goes into the input as carbon (%d), the hopper fuel unchanged (protocol 121)" % [carbon.capitalize(), carbon_n])
		put_in(adv, "iron_ore", 1)
		var with_carbon: Dictionary = total(adv, watch)
		run(lane_s + 1.0)
		var after: Dictionary = total(adv, watch)
		check(part(adv, "output", n("steel_ingot")) == 1 and part(adv, "output", n("iron_ingot")) == 0 and part(adv, "input") == 0 and part(adv, "hopper") == 0, "Iron ore with %s carbon makes 1 Steel ingot; the carbon and the hopper fuel are each taken once" % carbon)
		var used_fuel: int = int(with_carbon["charcoal"]) - int(after["charcoal"]) + (int(with_carbon["coal"]) - int(after["coal"]))
		check(int(after["steel_ingot"]) == int(with_carbon["steel_ingot"]) + 1 and int(after["iron_ore"]) == int(with_carbon["iron_ore"]) - 1 and used_fuel == per_ore + carbon_n, "conserved: 1 ore and %d fuel and carbon in, 1 Steel ingot out" % (per_ore + carbon_n))
		empty(adv)
		clear_pack()

	var imp: int = place("improved_smelter@3,-2,0")
	items.give(1, n("coal"), 1)
	check(imp > 0 and put_in(imp, "coal", 1, span(imp, "input").x) == 1 and part(imp, "hopper", n("coal")) == 1 and part(imp, "input", n("coal")) == 0, "at the Improved smelter (no carbon input) Coal dragged onto an ore slot still goes to its hopper")
	clear_pack()

	# --- 5. The lanes never share ore ---
	items.give(1, n("charcoal"), 3 * per_ore + carbon_n)
	items.give(1, n("iron_ore"), 3)
	put_in(adv, "charcoal", 3 * per_ore)
	put_in(adv, "iron_ore", 1)
	run(lane_s * 3.0)
	check(part(adv, "output", n("iron_ingot")) == 1 and part(adv, "hopper") == 2 * per_ore, "one Iron ore is one ingot: the second lane does not take the same ore")
	empty(adv)
	items.give(1, n("charcoal"), 2 * per_ore)
	put_in(adv, "charcoal", 2 * per_ore)
	put_in(adv, "charcoal", carbon_n, input_at)
	put_in(adv, "iron_ore", 2)
	run(lane_s + 1.0)
	check(part(adv, "output", n("steel_ingot")) == 1 and part(adv, "output", n("iron_ingot")) == 1 and part(adv, "input") == 0, "Iron ore with carbon beside more Iron ore: one lane makes Steel, the other Iron, together")
	empty(adv)
	clear_pack()
	# Bronze (plan P3: a pair never doubles because two lanes exist): 1 Copper ore + 1 Tin ore is one bronze job, 2 Bronze ingots in one lane's
	# 2 x ingot_s; the other lane takes neither ore, so no Copper or Tin ingot and no extra fuel.
	items.give(1, n("charcoal"), 4 * per_ore)
	items.give(1, n("copper_ore"), 2)
	items.give(1, n("tin_ore"), 1)
	put_in(adv, "charcoal", 4 * per_ore)
	put_in(adv, "copper_ore", 1)
	put_in(adv, "tin_ore", 1)
	run(lane_s * 2.0 + 1.0)
	check(part(adv, "output", n("bronze_ingot")) == 2 and part(adv, "output", n("copper_ingot")) == 0 and part(adv, "output", n("tin_ingot")) == 0 and part(adv, "input") == 0 and part(adv, "hopper") == 2 * per_ore, "1 Copper ore + 1 Tin ore make exactly 2 Bronze ingots in %.1f s, the two lanes notwithstanding (%d fuel used)" % [lane_s * 2.0, 2 * per_ore])
	put_in(adv, "copper_ore", 1)
	run(lane_s + 1.0)
	check(part(adv, "output", n("copper_ingot")) == 1 and part(adv, "output", n("bronze_ingot")) == 2 and part(adv, "hopper") == per_ore, "1 Copper ore alone makes 1 Copper ingot")
	empty(adv)
	clear_pack()

	# --- 6. A full rack ---
	var rack: Vector2i = span(adv, "output")
	box(adv).numbers[rack.x] = n("stone")
	box(adv).counts[rack.x] = int(smelt["output"])
	items.give(1, n("charcoal"), per_ore)
	items.give(1, n("iron_ore"), 1)
	put_in(adv, "charcoal", per_ore)
	put_in(adv, "iron_ore", 1)
	run(lane_s * 3.0)
	check(part(adv, "output", n("iron_ingot")) == 0 and part(adv, "input") == 1 and part(adv, "hopper") == per_ore, "a full rack (%d, its other slots empty): the finished ingot waits, nothing taken" % int(smelt["output"]))
	box(adv).counts[rack.x] = int(smelt["output"]) - 1
	run(2.0)
	check(part(adv, "output", n("iron_ingot")) == 1 and part(adv, "input") == 0, "room for one: it delivers")
	empty(adv)
	clear_pack()

	# --- 7. Save and load ---
	items.give(1, n("charcoal"), 2 * per_ore + carbon_n)
	items.give(1, n("iron_ore"), 2)
	put_in(adv, "charcoal", 2 * per_ore)
	put_in(adv, "charcoal", carbon_n, input_at)
	put_in(adv, "iron_ore", 2)
	run(5.0)
	var saved: Array = banked(adv)
	var saved_jobs: Array = [str(items._items[adv]["struct"].get("smelt_job", ""))] + (items._items[adv]["struct"].get("smelt_lanes", []) as Array).map(func(l): return str(l[1]))
	var adv_pos: Vector3 = items._items[adv]["pos"]
	var before_save: Dictionary = total(adv, watch)
	items.save()
	items._finish_writer()
	items = make_server()
	adv = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "large_forge" and (items._items[id]["pos"] as Vector3).distance_to(adv_pos) < 0.5:
			adv = int(id)

	var loaded: Array = banked(adv) if adv > 0 else []
	var loaded_jobs: Array = ([str(items._items[adv]["struct"].get("smelt_job", ""))] + (items._items[adv]["struct"].get("smelt_lanes", []) as Array).map(func(l): return str(l[1]))) if adv > 0 else []
	check(adv > 0 and loaded.size() == 2 and absf(float(loaded[0]) - float(saved[0])) < 0.01 and absf(float(loaded[1]) - float(saved[1])) < 0.01 and loaded_jobs == saved_jobs and saved_jobs.has("steel"), "save and load keep both lanes' banked time and jobs (%s, %s)" % [str(saved), str(saved_jobs)])
	check(adv > 0 and part(adv, "input", n("charcoal")) == carbon_n and part(adv, "hopper", n("charcoal")) == 2 * per_ore and JSON.stringify(total(adv, watch)) == JSON.stringify(before_save), "the carbon stays in the input through the load, the hopper fuel in the hopper; nothing lost or made")
	run(lane_s - 5.0 + 1.0)
	check(adv > 0 and part(adv, "output", n("steel_ingot")) == 1 and part(adv, "output", n("iron_ingot")) == 1 and part(adv, "input") == 0 and part(adv, "hopper") == 0, "and it finishes both after the load: 1 Steel and 1 Iron ingot")

	print("test_advanced_smelter: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	items._finish_writer()
	quit(1 if failures > 0 else 0)
