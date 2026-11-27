extends SceneTree

# Hides to clothes to warmth, as a loop (coordinator, 23 Nov 2026): every warmth piece has a recipe; a full set of each kind (plant, linen, hide,
# leather, wool, fur) is printed with the coldest air it keeps you out of the cold and out of harm, dry and still and soaked in wind, against the
# coldest air of each climate (warmth.json, clothing pieces' warmth and fabric, Climate); two players dressed differently in one cold keep their
# own warmth; worn layers, wetness and warmth come back for both after a restart; the cold rule (Dave 21 Oct, 23 Nov): cold takes you to 1 health
# and never further, then you pass out and are carried to shelter with your pack, and a line dropped while passed out does not leave you stuck.
#   godot --headless --path . --script res://src/worldgen/tools/test_clothes_warmth_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Climate := preload("res://src/shared/climate.gd")

const DIR := "user://test_clothes_warmth_loop"
const DAVE := "warm-loop-dave"
const ANNA := "warm-loop-anna"
const SETS := {
	"none": [],
	"plant": ["grass_cloak", "grass_skirt", "fibre_sandals", "straw_hat"],
	"linen": ["linen_shirt", "linen_trousers", "fibre_sandals", "linen_headwrap"],
	"leather": ["leather_jerkin", "leather_trousers", "leather_boots", "leather_gloves", "leather_cap"],
	"hide": ["hide_tunic", "hide_cloak", "hide_trousers", "hide_boots", "hide_gloves", "hide_hood"],
	"wool": ["wool_tunic", "wool_coat", "wool_trousers", "wool_socks", "leather_boots", "wool_mittens", "wool_cap", "wool_scarf"],
	"fur": ["wool_tunic", "fur_cloak", "hide_trousers", "wool_socks", "fur_boots", "fur_mittens", "fur_hat", "wool_scarf"],
}

var failures: int = 0
var weather: Dictionary = {"temp_c": 20.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
var said: Array = []
var moved: Array = []


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func make():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_worn = func(_p, _n, _i): pass
	items.send_died = func(p, cause, at): moved.append([p, cause, at])
	items.ground_height = func(_x, _z): return 0.0
	items.weather_now = func(): return weather
	items.rescue_spots = func(_pos): return [[Vector3(150.0, 0.0, 0.0), "goblin"]]
	items.setup(ItemTableScript.load_default(), DIR)
	items.admin_mode_on = func(_p): return false
	items._hints_loaded = true
	items._hints = []
	return items


func dress(items, peer: int, set_name: String) -> void:
	items._characters[items._peer_key[peer]]["worn"] = items._clean_worn([])
	var inv = items.inventory_of(peer)

	for id in SETS[set_name]:
		var num: int = items.table.number_of(id)

		if inv.count_of(num) == 0:
			inv.add(num, 1)

		items.action(peer, Net.ACT_WEAR, inv.numbers.find(num), 0, 0, Vector3.ZERO)


func worn_ids(items, peer: int) -> Array:
	var out: Array = []

	for number in items.worn_of(peer):
		if int(number) > 0:
			out.append(items.table.id_of(int(number)))

	out.sort()
	return out


# The coldest air (C, in steps of 0.5) at which the target warmth stays at or over `line`.
func coldest(items, peer: int, line: float) -> float:
	var t: float = 30.0

	while t > -200.0:
		weather["temp_c"] = t

		if items.warmth_target(peer) < line:
			return t + 0.5

		t -= 0.5

	return -200.0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var items = make()
	items.peer_connected_hello(1, DAVE)
	items.peer_connected_hello(2, ANNA)
	items.report_position(1, Vector3(0.0, 0.0, 0.0))
	items.report_position(2, Vector3(6.0, 0.0, 0.0))
	var cfg: Dictionary = items._warmth_cfg
	var cold: float = float(cfg["cold_at"])
	var hurt: float = float(cfg["hurt_at"])
	var cap: float = float(cfg["max_insulation"])

	# 1. Every piece that gives warmth can be made (a recipe that is not retired or locked), and each set's pieces are worn together.
	var no_recipe: Array = []
	var pieces: int = 0

	for id in items.table.ids():
		var entry: Dictionary = items.table.entry(id)

		if float(entry.get("warmth", 0.0)) > 0.0 and not bool(entry.get("retired", false)) and not bool(entry.get("future", false)):
			pieces += 1
			var made: bool = false

			for number in items.recipes.makers_of(items.table.number_of(id)):
				var r: Dictionary = items.recipes.recipe(int(number))
				made = made or (not bool(r.get("retired", false)) and not bool(r.get("locked", false)))

			if not made:
				no_recipe.append(id)

	check(pieces >= 40, "the warmth pieces are found (%d)" % pieces)
	check(no_recipe.is_empty(), "every piece that gives warmth has a live recipe (%s)" % str(no_recipe))

	# 2. The table: each full set, dry and still, and soaked in a 0.6 wind; against the coldest hour of each climate.
	var dry_ins: Dictionary = {}
	print("set      pieces  dry ins  dry: cold below / hurt below   soaked, wind 0.6: cold below / hurt below")

	for set_name in SETS:
		dress(items, 1, set_name)
		check(worn_ids(items, 1).size() == SETS[set_name].size(), "the %s set is worn whole (%s)" % [set_name, str(worn_ids(items, 1))])
		weather["wind"] = 0.0
		items._soak[1] = 0.0
		dry_ins[set_name] = items.insulation_worn(1)
		var dc: float = coldest(items, 1, cold)
		var dh: float = coldest(items, 1, hurt)
		weather["wind"] = 0.6
		items._soak[1] = 1.0
		var wc: float = coldest(items, 1, cold)
		var wh: float = coldest(items, 1, hurt)
		print("%-8s %d       %.2f     %7.1f C / %7.1f C           %5.1f C / %5.1f C" % [set_name, SETS[set_name].size(), float(dry_ins[set_name]), dc, dh, wc, wh])
		check(float(dry_ins[set_name]) <= cap + 0.001, "the %s set's insulation is within max_insulation" % set_name)
		check(wc >= dc and wh >= dh, "soaked in wind the %s set keeps you warm in less cold than dry (wet and wind are what kill)" % set_name)

	weather["wind"] = 0.0
	items._soak[1] = 0.0
	check(float(dry_ins["plant"]) > float(dry_ins["none"]) and float(dry_ins["leather"]) > float(dry_ins["linen"]) and float(dry_ins["hide"]) >= float(dry_ins["leather"]) and float(dry_ins["wool"]) >= float(dry_ins["hide"]) and float(dry_ins["fur"]) >= float(dry_ins["leather"]),
		"dry, the sets rank none < plant, linen < leather <= hide <= wool, leather <= fur (%s)" % str(dry_ins))

	var arctic_low: float = 0.0

	for zone in ["starter", "transition", "arctic"]:
		var c: Dictionary = Climate.of_zone(zone)
		var low: float = float(c["sea_level_mean_c"]) - float(c["seasonal_swing_c"]) - 0.5 * float(c["daily_range_c"]) - float(c.get("spell_amplitude_c", 0.0))
		print("%-10s coldest hour at sea level about %.1f C, at 1000 m about %.1f C" % [zone, low, low - float(c["lapse_c_per_km"])])
		arctic_low = low - float(c["lapse_c_per_km"]) if zone == "arctic" else arctic_low

	dress(items, 1, "fur")
	weather["temp_c"] = arctic_low
	check(items.warmth_target(1) >= cold, "dry and still, the fur set keeps you out of the cold at the arctic's coldest hour at 1000 m (%.1f C)" % arctic_low)

	# 3. Two players in one cold night (-10 C, dry, still): Dave in fur keeps warm, Anna in nothing gets cold; each keeps their own.
	dress(items, 1, "fur")
	dress(items, 2, "none")
	weather["temp_c"] = -10.0
	items._soak[1] = 0.0
	items._soak[2] = 0.0
	items.vitals_of(1)["warmth"] = 80.0
	items.vitals_of(2)["warmth"] = 80.0

	for n in 120:
		items.tick(1.0)

	var w1: float = float(items.vitals_of(1)["warmth"])
	var w2: float = float(items.vitals_of(2)["warmth"])
	check(w1 >= cold and w2 < w1, "at -10 C Dave in fur stays warm (%.1f) and Anna, undressed, cools on her own (%.1f)" % [w1, w2])
	items._soak[2] = 0.6
	items.vitals_of(1)["warmth"] = 70.0
	items.vitals_of(2)["warmth"] = 30.0
	dress(items, 2, "wool")

	# 4. A restart: both come back in what they wore, Anna still wet, each with their own warmth.
	var dave_worn: Array = worn_ids(items, 1)
	var anna_worn: Array = worn_ids(items, 2)
	for n in 3:
		items.tick(1.0)   # the vitals tick writes the wetness into the saved vitals

	var w1_before: float = float(items.vitals_of(1)["warmth"])
	var w2_before: float = float(items.vitals_of(2)["warmth"])
	items._dirty = true
	items.save()
	items._finish_writer()
	var b = make()
	b.peer_connected_hello(3, DAVE)
	b.peer_connected_hello(4, ANNA)
	b.report_position(3, Vector3(0.0, 0.0, 0.0))
	b.report_position(4, Vector3(6.0, 0.0, 0.0))
	check(worn_ids(b, 3) == dave_worn and worn_ids(b, 4) == anna_worn, "after the restart each wears their own set (%d and %d pieces)" % [dave_worn.size(), anna_worn.size()])
	check(absf(float(b.vitals_of(3)["warmth"]) - w1_before) < 1.0 and absf(float(b.vitals_of(4)["warmth"]) - w2_before) < 1.0, "and their own warmth (%.1f, %.1f)" % [float(b.vitals_of(3)["warmth"]), float(b.vitals_of(4)["warmth"])])
	check(float(b.vitals_of(4).get("soak", 0.0)) > 0.3 and float(b.vitals_of(3).get("soak", 0.0)) == 0.0, "Anna's clothes are still wet, Dave's dry (%.2f, %.2f)" % [float(b.vitals_of(4).get("soak", 0.0)), float(b.vitals_of(3).get("soak", 0.0))])

	# 4b. Soaked in the wind and getting cold, the player is told why, once; dry and still the same cold says nothing of it.
	var body: Dictionary = b._warmth_cfg["body_703"]
	var why: String = str(body["say_wet_wind"])
	weather["temp_c"] = 2.0
	weather["wind"] = 0.6
	b._soak[4] = 1.0
	b.vitals_of(4)["warmth"] = float(b._warmth_cfg["cold_at"]) + 0.5
	b._cold_level.erase(4)
	said.clear()

	for n in 60:
		b.tick(1.0)

	check(said.count(why) == 1, "Anna, soaked in the wind and getting cold, is told once why: %s (%s)" % [why, str(said)])
	# Under a roof (cover 2: roofed, the wind cut to covered_wind_share) the same soaking is not told to find a roof.
	b.cover_at = func(at): return 2.0 if (at as Vector3).distance_to(Vector3(6.0, 0.0, 0.0)) < 1.0 else 0.0
	weather["wind"] = 1.0
	b._soak[4] = 1.0
	b._cold_level.erase(4)
	b._wet_wind_told.erase(4)
	b.vitals_of(4)["warmth"] = float(b._warmth_cfg["cold_at"]) + 0.5
	weather["temp_c"] = -15.0
	said.clear()

	for n in 10:
		b.tick(1.0)

	check(said.has(str(b._warmth_cfg["say_cold"])) and not said.has(why), "under a roof in a gale, soaked Anna gets cold and is not told to find a roof (%s)" % str(said))
	b.cover_at = Callable()
	weather["temp_c"] = 2.0
	b._soak[4] = 0.0   # Anna dries off: the checks below are Dave's lines

	# Dry in the same wind, and soaked in still air: getting cold, but neither is told about wet and wind.
	for case in [[0.6, 0.0, "dry in the wind"], [0.0, 1.0, "soaked in still air"]]:
		weather["wind"] = case[0]
		b._soak[3] = case[1]
		b._cold_level.erase(3)
		b._wet_wind_told.erase(3)
		b.vitals_of(3)["warmth"] = float(b._warmth_cfg["cold_at"]) + 0.5
		dress(b, 3, "none")
		weather["temp_c"] = -5.0
		said.clear()

		for n in 10:
			b.tick(1.0)

		check(said.has(str(b._warmth_cfg["say_cold"])) and not said.has(why), "%s, Dave gets cold and is not told about wet and wind (%s)" % [case[2], str(said)])

	b._soak[3] = 0.0
	dress(b, 3, "fur")

	# 5. The cold rule in the worst weather: soaked in a gale at -40 C, even in fur, health stops at 1, then the pass-out and the rescue.
	weather["temp_c"] = -40.0
	weather["wind"] = 1.0
	weather["rain"] = 0.0
	b._soak[3] = 1.0
	var v: Dictionary = b.vitals_of(3)
	v["warmth"] = 5.0
	v["health"] = 6.0
	var low_hp: float = 100.0
	var stone: int = b.table.number_of("stone")
	b.give(3, stone, 5)
	var ticks: int = 0

	while not b.passed_out(3) and ticks < 900:
		b.tick(1.0)
		low_hp = minf(low_hp, float(v["health"]))
		ticks += 1

	check(b.passed_out(3) and low_hp >= 1.0, "cold takes Dave to 1 health and no further, then he passes out (lowest %.2f, %d s)" % [low_hp, ticks])

	# A dropped line while out: the state clears; back on a new connection, still freezing, he passes out again and is carried to shelter.
	b.peer_left(3)
	check(not b.passed_out(3), "his line drops while he is out")
	moved.clear()
	b.peer_connected_hello(5, DAVE)
	b.report_position(5, Vector3(0.0, 0.0, 0.0))
	var v5: Dictionary = b.vitals_of(5)
	check(float(v5["health"]) <= 1.5, "he comes back at the health he had (%.1f)" % float(v5["health"]))
	b._soak[5] = 1.0
	ticks = 0

	while moved.filter(func(m): return int(m[0]) == 5).is_empty() and ticks < 900:
		b.tick(1.0)
		low_hp = minf(low_hp, float(v5["health"]))
		ticks += 1

	check(not moved.filter(func(m): return int(m[0]) == 5).is_empty(), "still freezing, he passes out again and is carried to the goblin camp (%d s, %s)" % [ticks, str(moved)])
	check(not b.passed_out(5) and int(b._strain.get(5, {}).get("state", 0)) == 3, "and wakes, lying while the sight comes back, not stuck fainted")
	check(float(v5["health"]) >= float(cfg["pass_out"]["wake_health"]) - 0.5 and low_hp >= 1.0, "with the wake health (%.1f), never under 1" % float(v5["health"]))
	check(b.inventory_of(5).count_of(stone) == 5 and worn_ids(b, 5) == dave_worn, "his pack and his clothes are all still his")
	check((b._peer_pos[4] as Vector3).is_equal_approx(Vector3(6.0, 0.0, 0.0)) and not b.passed_out(4), "Anna stays where she was, awake")
	check(moved.filter(func(m): return int(m[0]) == 4).is_empty(), "only Dave was carried")
	b._finish_writer()
	print("clothes and warmth loop: %s" % ("all pass" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
