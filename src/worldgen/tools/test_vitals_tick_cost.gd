extends SceneTree

# The vitals tick keeps a player's worn numbers and Rested row for one tick, what follows from the worn pieces until they change (_dress_of:
# insulation, heat load, rain shed, armour, carry bonus, dressed points) and each item number's weight for good (server_items vitals_memo, _pack_kg): the soak at 64 players (26 Nov 2026) showed vitals at 123 ms a second, the largest part of the server,
# with those read five to eight times a player each look. Here two servers alike, one with the kept readings and one without, must end
# every player's vitals the same, through a comfort level crossed inside the tick and a death inside it.
#   godot --headless --path . --script res://src/worldgen/tools/test_vitals_tick_cost.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")

const PLAYERS := 32

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String, memo: bool):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	items.game_seconds = func(): return 3.0 * 86400.0 + 22.0 * 3600.0
	items.vitals_memo = memo
	var t = items.table
	var places: Array = items._worn_places()
	var dress: Dictionary = {"head:base": "hide_hood", "body:base": "hide_tunic", "legs:base": "hide_trousers", "feet:footwear": "hide_boots", "hands:base": "hide_mittens", "body:outer": "hide_cloak", "head:rigid": "iron_helm", "body:mail": "mail_shirt", "legs:mail": "iron_mail_chausses"}

	for p in range(1, PLAYERS + 1):
		var key: String = "vitcost%05d" % p
		items.peer_connected_hello(p, key)
		items.report_position(p, Vector3(float(p) * 7.0, 5.0, 3.0))
		items.give(p, t.number_of("stone"), 3 + p % 7)
		items.give(p, t.number_of("bucket"), 1, {}, 200 * (p % 4))   # water in the wear field: a litre a kilogram
		var worn: Array = []

		for place in places:
			worn.append(t.number_of(str(dress[place])) if dress.has(place) and p % 3 != 0 else 0)

		items._characters[key]["worn"] = items._clean_worn(worn)
		items._characters[key]["comfort"] = 4.999 if p % 2 == 0 else float(p % 10)   # the even ones cross into level 5 inside the first tick
		items._stance[p] = 2 if p % 4 == 0 else 0
		items._exertion[p] = 0.1 * float(p % 10)
		items._moving[p] = 1.0   # on the move: the armour past effort_free_kg counts in the effort (protection.json; helm, mail shirt and chausses 12.6 kg)

	return items


func _initialize() -> void:
	var a = make("user://test_vitals_tick_cost_a", true)
	var b = make("user://test_vitals_tick_cost_b", false)

	# 1. The pack's kilograms with each number's weight kept equal CarryRules.carried_kg, the client's sum.
	for p in range(1, PLAYERS + 1):
		var inv = a.inventory_of(p)
		check(a._pack_kg(inv) == CarryRules.carried_kg(inv, a.table, a._carry_cfg), "player %d: the kept weights sum as CarryRules does (%.4f against %.4f)" % [p, a._pack_kg(inv), CarryRules.carried_kg(inv, a.table, a._carry_cfg)])

	# 2. Eight ticks each: every player's vitals, comfort and strain the same on both.
	var ms_a: float = 0.0
	var ms_b: float = 0.0

	for tick in 8:
		if tick == 4:
			for s in [a, b]:
				s._vitals[s._peer_key[5]]["health"] = -1.0   # dies inside the next tick (the tick's regen clamps it to 0): kill runs outside the kept readings
				s._death_cause[5] = "cold"

		var t0: int = Time.get_ticks_usec()
		a._vitals_tick(0.25)
		ms_a += float(Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		b._vitals_tick(0.25)
		ms_b += float(Time.get_ticks_usec() - t0) / 1000.0

		if tick == 4:
			for s in [a, b]:
				var remains: int = 0

				for id in s._items:
					if s._items[id].has("struct") and str(s._items[id]["struct"].get("kind", "")) == "remains":
						remains += 1

				check(remains == 1, "player 5 died inside the tick: one remains (%d)" % remains)
				check(s.inventory_of(5).numbers.count(0) == s.inventory_of(5).numbers.size(), "and the pack went with them")
				check(not s._worn_cache.has(5) and not s._rested_cache.has(5) and not s._kg_cache.has(5) and not s._load_cache.has(5), "and that player's kept readings went too")

		for p in range(1, PLAYERS + 1):
			var key: String = a._peer_key[p]
			check(str(a._vitals.get(key, {})) == str(b._vitals.get(key, {})), "tick %d player %d: the same vitals with and without the kept readings\n  %s\n  %s" % [tick, p, str(a._vitals.get(key, {})), str(b._vitals.get(key, {}))])
			check(str(a._characters[key].get("comfort")) == str(b._characters[key].get("comfort")), "tick %d player %d: the same comfort" % [tick, p])
			check(str(a._strain.get(p, {})) == str(b._strain.get(p, {})), "tick %d player %d: the same strain" % [tick, p])

	check(a.comfort_level(2) == 5, "an even player crossed into comfort 5 inside the ticks (%d)" % a.comfort_level(2))
	check(a._armour_kg(1) > float(a._protection_cfg.get("effort_free_kg", 0.0)), "the dressed players wear armour past the free kilograms (%.2f kg)" % a._armour_kg(1))
	var moving_effort: float = a.effort_of(1)
	a._moving[1] = 0.0
	var still_effort: float = a.effort_of(1)
	a._moving[1] = 1.0
	check(moving_effort > still_effort + 0.001, "so on the move the armour is in the effort the ticks compared (%.3f moving, %.3f still)" % [moving_effort, still_effort])

	# 3. The Rested row follows a comfort level crossed inside the tick: kept at level 4, then the meter reaches its target of 5 and the row follows.
	for s in [a, b]:
		var v: Dictionary = s._vitals[s._peer_key[4]]
		s._characters[s._peer_key[4]]["comfort"] = 4.999
		s._vitals_caches_clear()
		s._in_vitals = true
		var before: int = int(s.rested_tier(4).get("level", 0))
		s._comfort_meter_tick(4, v, 60.0)
		var after: int = int(s.rested_tier(4).get("level", 0))
		s._in_vitals = false
		check(before == 4 and after == 5, "memo %s: the Rested row read inside the tick follows the meter from 4 to 5 (%d then %d)" % [str(s.vitals_memo), before, after])
	check(a.worn_of(1) == b.worn_of(1) and a.rested_tier(2) == b.rested_tier(2), "outside the tick the live readings agree")
	# 4. What follows from the worn pieces (_dress_of) is kept until what is worn changes: the same on both servers, wet and dry, before and
	# after a change of clothes between ticks (and the second tick after it, when the kept row is the new one).
	for turn in 3:
		if turn == 1:
			for s in [a, b]:
				for p in [1, 2, 7]:
					var worn: Array = s._characters[s._peer_key[p]]["worn"]
					worn[14] = [0, 0, 0, {}]   # the mail chausses off, in place, as _unwear leaves the list
					worn[6] = [s.table.number_of("grass_cloak"), 1, 0, {}]   # a plant cloak over the hide

				s._characters[s._peer_key[4]]["worn"] = s._clean_worn([])   # undressed
				s._soak[1] = 0.6

		for p in range(1, PLAYERS + 1):
			var same: bool = a.insulation_worn(p) == b.insulation_worn(p) and a.heat_load(p) == b.heat_load(p) and a.rain_shed(p) == b.rain_shed(p)
			same = same and a._armour_kg(p) == b._armour_kg(p) and a._carry_body(p) == b._carry_body(p) and str(a.comfort_points(p)) == str(b.comfort_points(p))
			check(same, "turn %d player %d: insulation, heat load, rain shed, armour, carry body and comfort points the same with the kept dress (%.4f %.4f, %.2f %.2f kg)" % [turn, p, a.insulation_worn(p), b.insulation_worn(p), a._armour_kg(p), b._armour_kg(p)])

		a._vitals_tick(0.25)
		b._vitals_tick(0.25)

	# A swapped config clears the kept rows: no carry config, no armour kilograms (as without the rows), and back again with it.
	var carry: Dictionary = a._carry_cfg
	a._carry_cfg = {}
	b._carry_cfg = {}
	check(a._armour_kg(2) == 0.0 and b._armour_kg(2) == 0.0, "no carry config: no armour kilograms with or without the kept rows")
	a._carry_cfg = carry
	b._carry_cfg = carry
	a._warmth_cfg = a._warmth_cfg.duplicate(true)
	a._warmth_cfg["max_insulation"] = 0.01
	check(a.insulation_worn(2) <= 0.01 and a.heat_load(2) <= 0.01 and a._armour_kg(2) == b._armour_kg(2), "a changed warmth config is read at once (%.3f, %.3f)" % [a.insulation_worn(2), a.heat_load(2)])
	a._warmth_cfg = b._warmth_cfg

	check(a._armour_kg(1) < 12.0 and a.comfort_target(4) < 5.0, "the change of clothes reached the kept rows (armour %.2f kg, comfort target %.1f undressed)" % [a._armour_kg(1), a.comfort_target(4)])

	print("vitals tick, %d players, 8 ticks: %.2f ms with the kept readings, %.2f ms without" % [PLAYERS, ms_a, ms_b])

	print("test_vitals_tick_cost: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
