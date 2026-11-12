extends SceneTree

# Catalog Phase 4b (M001-T14): the weapon, armour and clothing rows go live at their stations, and armour stops a share of each attack by
# damage mode (master s3.6, s3.7 rules 1-5, s3.8 design 1-6; data/items/protection.json), through the real server. Section 1 crafts every
# recipe of every Phase 4b row the catalog ledger lists from live materials at its station; the rest dress a player in layers and hit them.
# Numbers come from the live data, so tuning keeps the test valid.
#   godot --headless --path . --script res://src/worldgen/tools/test_armour.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const BowAim := preload("res://src/shared/bow_aim.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(5.0, 10.0, 0.0)
const KEY := "armour000001"

var failures: int = 0
var items
var inv
var said: Array = []
var prot: Dictionary = {}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func n(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return inv.count_of(n(id))


func slot_of(id: String) -> int:
	return inv.numbers.find(n(id))


func run(seconds: float) -> void:
	for k in range(int(ceil(seconds))):
		items.tick(1.0)


func place(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": n(str(items._structures[kind].get("item", kind))), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id, "lit": true, "fuel_left": 1.0e7}}
	items._next_id += 1
	return id


func clear_stations() -> void:
	for id in items._items.keys():
		if items._items[id].has("struct"):
			items._items.erase(id)


func empty_pack() -> void:
	for s in inv.SLOTS:
		inv.clear_slot(s)


func strip() -> void:
	items._characters[KEY]["worn"] = items._clean_worn([])
	empty_pack()


# The first live structure kind that serves a station at `level` or more (its own station and station_level, or "also").
func kind_serving(station: String, level: int = 1) -> String:
	for kind in items._structures:
		var def: Dictionary = items._structures[kind]
		var own: int = int(def.get("station_level", 1)) if str(def.get("station", "")) == station else 0

		if not bool(def.get("retired", false)) and maxi(own, int(def.get("also", {}).get(station, 0))) >= level:
			return kind

	return ""


func recipe_number(id: String) -> int:
	for number in items.recipes.numbers():
		if str(items.recipes.recipe(int(number))["id"]) == id:
			return int(number)

	return 0


# A real item for a cost: a group's first member that is not the group id itself (any knife: a stone knife).
func filler(number: int) -> int:
	var members: PackedInt32Array = items.table.group_members(number)
	return members[1] if members.size() > 1 else number


func wear(id: String) -> void:
	if have(id) == 0:
		inv.add(n(id), 1)

	items.action(1, Net.ACT_WEAR, slot_of(id), 0, 0, Vector3.ZERO)


func place_of(id: String) -> int:
	return items._place_of(n(id))


# What the server should stop for one mode, worked out here from the data: per slot the pieces' protect x cover x (1 - pen), largest first, each
# further one counting layer_keep times the one before, capped at slot_cap, weighted by the slot share; the whole capped at cap.
func expected(ids: Array, mode: String, pen: float = 0.0) -> float:
	var by_slot: Dictionary = {}

	for id in ids:
		var e: Dictionary = items.table.entry(id)
		var stop: float = float(e.get("protect", {}).get(mode, 0.0)) * float(e.get("cover", 1.0)) * (1.0 - pen)

		if stop > 0.0:
			if not by_slot.has(e["slot"]):
				by_slot[e["slot"]] = []

			by_slot[e["slot"]].append(stop)

	var total: float = 0.0

	for slot in by_slot:
		var values: Array = by_slot[slot]
		values.sort()
		values.reverse()
		var layered: float = 0.0
		var share: float = 1.0

		for v in values:
			layered += float(v) * share
			share *= float(prot["layer_keep"])

		total += float(prot["slots"][slot]) * minf(layered, float(prot["slot_cap"]))

	return minf(total, float(prot["cap"]))


# Health lost to one hit (health reset to full first, so the maim floor never hides a difference).
func lost(amount: float, cause: String, mode: String = "", pen: float = 0.0) -> float:
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	items.hurt_player(1, amount, false, cause, 0.0, mode, pen)
	return 100.0 - float(v["health"])


func _init() -> void:
	var dir: String = "user://test_armour"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(_p, _r): pass
	items.send_worn = func(_p, _numbers, _insts): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	items.skill_level = func(_p, _s): return 1.0
	items.peer_connected_hello(1, KEY)
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # carrying is not under test
	inv = items.inventory_of(1)
	prot = items._protection_cfg
	check(not prot.is_empty() and (prot["modes"] as Array).size() == 4, "protection.json loads with its four damage modes (%s)" % str(prot.get("modes", [])))

	# 1. Every recipe of every Phase 4b row (ledger): live, known, from live materials, made at its station (s3.6 to s3.8 stations).
	var ledger: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/catalog_ledger.json"))
	var made: int = 0
	var rows: int = 0

	for row in ledger["entries"]:
		if str(row.get("phase", "")) != "4b":
			continue

		var id: String = str(row["id"]) if row.get("id") != null else str(row["key"])
		var entry: Dictionary = items.table.entry(id)
		rows += 1
		check(not entry.is_empty() and not bool(entry.get("future", false)) and not bool(entry.get("retired", false)), "1. %s is a live row" % id)
		var found: Array = []

		for number in items.recipes.numbers():
			var r: Dictionary = items.recipes.recipe(int(number))

			if not r.get("gives", []).is_empty() and int(r["gives"][0]) == n(id) and not bool(r.get("retired", false)):
				found.append(int(number))

		check(not found.is_empty(), "1. %s has a recipe" % id)

		for number in found:
			var r: Dictionary = items.recipes.recipe(number)
			var station: String = str(r.get("station", ""))
			var want: String = station

			if id.begins_with("bronze_"):
				want = "forge"
			elif id.begins_with("iron_") or id.begins_with("steel_") or id in ["mail_shirt", "plate_cuirass", "heavy_crossbow"]:
				want = "brick_forge"
			elif id.begins_with("leather_"):
				want = "leatherworking_table"
			elif id.begins_with("linen_") or id.begins_with("wool_") or id.begins_with("fur_") or id in ["oilcloth_cloak", "tabard"]:
				want = "tailors_table"

			check(station == want and bool(r.get("known", false)) and not bool(r.get("locked", false)), "1. %s recipe %d is known and made at %s (%s)" % [id, number, want, station if station != "" else "by hand"])
			var live: bool = true

			for need in r["needs"] + r.get("keeps", []):
				var need_row: Dictionary = items.table.entry(items.table.id_of(int(need[0])))
				live = live and not bool(need_row.get("future", false)) and not bool(need_row.get("retired", false))

			check(live, "1. %s recipe %d takes only live materials (%s)" % [id, number, str(r["needs"])])
			empty_pack()
			clear_stations()

			if station != "":
				place(kind_serving(station, int(r.get("station_level", 1))), HERE + Vector3(0.0, 0.0, 2.0))

			for need in r["needs"] + r.get("keeps", []):
				inv.add(filler(int(need[0])), int(need[1]))

			items._last_queue_act.clear()
			items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, 1, Vector3.ZERO)
			run(float(r["craft_s"]) + 2.0)
			var got: bool = have(id) >= int(r["gives"][1])
			check(got, "1. %s is made by recipe %d at %s from live materials" % [id, number, kind_serving(station, int(r.get("station_level", 1))) if station != "" else "hand"])
			made += 1 if got else 0

			if got and int(entry.get("durability", 0)) > 0 and not (entry.get("repair", []) as Array).is_empty() and str(entry.get("repair_station", "")) != "":
				check(str(entry["repair_station"]) == station, "1. %s is mended where it is made (%s)" % [id, station])

	check(rows >= 62 and made >= rows, "1. the sweep made all %d Phase 4b rows (%d crafts)" % [rows, made])
	check(items.table.entry("wooden_bow")["name"] == "Shortbow" and items.table.entry("wooden_longbow")["name"] == "Longbow", "1. the bows are renamed Shortbow and Longbow (ids kept)")
	check(items.recipes.recipe(recipe_number("bronze_shield"))["needs"].all(func(need): return items.table.id_of(int(need[0])) != "lumber"), "1. the Bronze - Shield needs no Planks (s3.6 fix)")
	check(items.table.group_members(n("linen")).is_empty(), "1. the Tabard's two recipes leave Linen a plain cost: a Linen - Shirt is never made of wool")
	clear_stations()
	empty_pack()

	# 2. Layers: gambeson + mail + breastplate + cloak combine per mode with diminishing returns, never past the caps (s3.7 rule 1).
	var layered: Array = ["gambeson", "mail_shirt", "iron_breastplate", "wool_cloak"]

	for id in layered:
		wear(id)

	check(layered.all(func(id): return items.worn_of(1)[place_of(id)] == n(id)), "2. gambeson, mail shirt, breastplate and cloak are worn together on the body")

	for mode in prot["modes"]:
		var got: float = items.protection_of(1, mode)
		var alone_sum: float = 0.0
		var best: float = 0.0

		for id in layered:
			alone_sum += expected([id], mode)
			best = maxf(best, expected([id], mode))

		check(is_equal_approx(got, expected(layered, mode)) and got > best and got < alone_sum and got <= float(prot["cap"]), "2. %s: the layers stop %.3f, more than the best alone (%.3f), less than their sum (%.3f)" % [mode, got, best, alone_sum])

	check(items.protection_of(1, "slashing") > items.protection_of(1, "blunt") * 1.2, "2. mail and plate stop cuts better than blunt force (%.3f against %.3f)" % [items.protection_of(1, "slashing"), items.protection_of(1, "blunt")])
	strip()
	var full: Array = ["gambeson", "iron_mail_hauberk", "steel_plate_harness", "wool_cloak", "iron_mail_coif", "steel_helm", "leather_gloves", "steel_gauntlets", "leather_trousers", "iron_mail_chausses", "steel_greaves", "leather_boots", "steel_sabatons"]

	for id in full:
		wear(id)

	for mode in prot["modes"]:
		check(items.protection_of(1, mode) <= float(prot["cap"]) + 0.0001 and is_equal_approx(items.protection_of(1, mode), expected(full, mode)), "2. a full steel kit stops %.3f of %s, never past the cap %.2f" % [items.protection_of(1, mode), mode, float(prot["cap"])])

	var body_raw: float = expected(["gambeson", "iron_mail_hauberk", "steel_plate_harness"], "slashing") / float(prot["slots"]["body"])
	var harness: Dictionary = items.table.entry("steel_plate_harness")
	check(is_equal_approx(body_raw, float(prot["slot_cap"])) and float(harness["protect"]["slashing"]) * float(harness["cover"]) * (1.0 + float(prot["layer_keep"])) > float(prot["slot_cap"]), "2. the body's three layers would pass the slot cap; they stop at %.2f" % float(prot["slot_cap"]))
	check(lost(30.0, "bear") >= 30.0 * (1.0 - float(prot["cap"])) - 0.001, "2. no blanket immunity: a full kit still takes %.1f of a 30 bear blow" % lost(30.0, "bear"))

	# 3. A sword and a mace against mail: the sword hits harder bare, the mace hurts more through mail (s3.7 rule 3).
	strip()
	var sword: Dictionary = items.weapon_blow(items.table.entry("steel_sword"), {})
	var mace: Dictionary = items.weapon_blow(items.table.entry("steel_mace"), {})
	check(sword["mode"] == "slashing" and mace["mode"] == "blunt" and items.table.entry("steel_spear")["damage_mode"] == "piercing" and items.table.entry("steel_arrow")["damage_mode"] == "projectile", "3. a sword slashes, a mace is blunt, a spear pierces, an arrow is projectile")
	var bare_sword: float = lost(sword["damage"], "test", sword["mode"], sword["pen"])
	var bare_mace: float = lost(mace["damage"], "test", mace["mode"], mace["pen"])
	wear("mail_shirt")
	var mail_sword: float = lost(sword["damage"], "test", sword["mode"], sword["pen"])
	var mail_mace: float = lost(mace["damage"], "test", mace["mode"], mace["pen"])
	check(bare_sword > bare_mace and mail_mace > mail_sword, "3. bare the sword takes %.1f and the mace %.1f; through mail the sword %.2f and the mace %.2f" % [bare_sword, bare_mace, mail_sword, mail_mace])
	check(is_equal_approx(mail_sword, float(sword["damage"]) * (1.0 - expected(["mail_shirt"], "slashing"))), "3. through mail the sword loses exactly the mail's slashing share")
	var rapier: Dictionary = items.weapon_blow(items.table.entry("steel_rapier"), {})
	check(float(rapier["pen"]) > 0.0 and is_equal_approx(lost(rapier["damage"], "test", rapier["mode"], rapier["pen"]), float(rapier["damage"]) * (1.0 - expected(["mail_shirt"], "piercing", float(rapier["pen"])))), "3. a rapier's penetration (%.2f) takes off part of the mail's protection" % float(rapier["pen"]))
	check(is_equal_approx(float(items.weapon_blow(items.table.entry("steel_sword"), {"craft": 2})["damage"]), float(sword["damage"]) + 2.0), "3. a +2 sword's blow is two harder")

	# 4. Attacks by animals take their mode from protection.json; falls are not attacks.
	strip()
	var bite: float = 8.0
	check(is_equal_approx(lost(bite, "wolves"), bite), "4. a wolf bite on a bare player takes its full %.0f" % bite)
	wear("gambeson")
	wear("mail_shirt")
	var bitten: float = lost(bite, "wolves")
	check(items.attack_mode("wolves") == "piercing" and is_equal_approx(bitten, bite * (1.0 - expected(["gambeson", "mail_shirt"], "piercing"))) and bitten < bite, "4. through gambeson and mail the bite (piercing) takes %.2f" % bitten)
	check(items.attack_mode("bear") == "slashing" and items.attack_mode("moose") == "blunt" and lost(25.0, "bear") < lost(25.0, "moose"), "4. mail turns a bear's claws (slashing) better than a moose's charge (blunt)")
	strip()
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	items._last_fall.clear()
	items._fall(1, 1400)
	var fall_bare: float = 100.0 - float(v["health"])
	wear("steel_plate_harness")
	v["health"] = 100.0
	items._last_fall.clear()
	items._fall(1, 1400)
	check(fall_bare > 0.0 and is_equal_approx(100.0 - float(v["health"]), fall_bare), "4. a 14 m fall hurts the same in plate (%.1f): armour stops only attacks" % fall_bare)

	# 5. Durability: hits wear what protects; a broken piece stops nothing; taken off, it is mended at its station.
	strip()
	wear("mail_shirt")
	var at: int = place_of("mail_shirt")
	var mail_row: Dictionary = items.table.entry("mail_shirt")
	var most: int = int(mail_row["durability"])
	lost(10.0, "wolves")
	check(int(items.worn_slots_of(1)[at][2]) == int(round(10.0 * float(prot["wear_per_damage"]) * float(mail_row["cover"]))), "5. a 10 bite wears the mail shirt by %d" % int(items.worn_slots_of(1)[at][2]))
	items._characters[KEY]["worn"][at][2] = most - 1
	said.clear()
	lost(10.0, "wolves")
	check(int(items.worn_slots_of(1)[at][2]) == most and said.any(func(t): return str(t).contains("broke")) and items.worn_of(1)[at] == n("mail_shirt"), "5. the hit that ends it breaks the mail shirt, which stays worn")
	check(is_equal_approx(items.protection_of(1, "slashing"), 0.0) and is_equal_approx(lost(10.0, "wolves"), 10.0), "5. a broken mail shirt stops nothing")
	items.action(1, Net.ACT_UNWEAR, at, 0, 0, Vector3.ZERO)
	var ms: int = slot_of("mail_shirt")
	check(ms >= 0 and inv.wear[ms] == most and items._is_broken(inv, ms), "5. taken off, it is in the pack, still broken")

	for cost in mail_row["repair"]:
		inv.add(n(str(cost[0])), int(cost[1]))

	items.action(1, Net.ACT_REPAIR, ms, 0, 0, Vector3.ZERO)
	check(inv.wear[ms] == most, "5. away from a Smithy it is not mended")
	place(kind_serving(str(mail_row["repair_station"])), HERE + Vector3(0.0, 0.0, 2.0))
	items.action(1, Net.ACT_REPAIR, ms, 0, 0, Vector3.ZERO)
	check(inv.wear[ms] == 0 and have("iron_ingot") == 0, "5. at the Smithy (%s) it is mended with its iron" % kind_serving(str(mail_row["repair_station"])))
	clear_stations()
	strip()

	# 6. Tempered steel armour: durability only, never sharpness (s3.7 rule 5, s4 item 15); iron armour is never Tempered.
	place("blacksmithy", HERE + Vector3(0.0, 0.0, 3.0))
	place("quenching_trough", HERE + Vector3(1.5, 0.0, 3.0))
	var cuirass_recipe: int = recipe_number("plate_cuirass")
	var cr: Dictionary = items.recipes.recipe(cuirass_recipe)
	var tempered: int = SmithingRules.code(true, 0)

	for need in SmithingRules.scaled_needs(cr["needs"], tempered):
		inv.add(int(need[0]), int(need[1]))

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, cuirass_recipe, tempered, 1, Vector3.ZERO)
	run(float(cr["craft_s"]) * SmithingRules.time_mult(tempered) + 3.0)
	var cs: int = slot_of("plate_cuirass")
	var cuirass: Dictionary = items.table.entry("plate_cuirass")
	var temper_d: int = int(round(float(cuirass["durability"]) * (1.0 + float(SmithingRules.cfg()["temper"]["durability"]))))
	check(cs >= 0 and int(inv.inst[cs].get("temper", 0)) == 1 and inv.max_durability(cs) == temper_d and temper_d > int(cuirass["durability"]), "6. a Tempered Steel - Cuirass lasts %d against %d" % [inv.max_durability(cs) if cs >= 0 else -1, int(cuirass["durability"])])
	check(not bool(cuirass.get("edge", false)) and SmithingRules.dull_at(cuirass, inv.inst[cs] if cs >= 0 else {}) == 0, "6. it has no edge and no sharpness")
	var plain_stop: float = expected(["plate_cuirass"], "slashing")

	if cs >= 0:
		items.action(1, Net.ACT_WEAR, cs, 0, 0, Vector3.ZERO)

	check(is_equal_approx(items.protection_of(1, "slashing"), plain_stop), "6. Tempered protects exactly as plain steel (%.3f)" % plain_stop)
	check(not SmithingRules.temper_ok("iron_breastplate", items.table.entry("iron_breastplate"), 1) and SmithingRules.temper_ok("steel_sabatons", items.table.entry("steel_sabatons"), 1), "6. iron armour is never Tempered; every steel piece may be")
	clear_stations()
	strip()

	# 7. Crossbows shoot bolts, with their own reload time; a bow takes no bolts.
	var cross: Dictionary = items.table.entry("light_crossbow")
	var bow_cfg: Dictionary = BowAim.load_config()
	check(BowAim.shoots(cross) and BowAim.ammo_for(bow_cfg, "light_crossbow").has("iron_bolt") and not BowAim.ammo_for(bow_cfg, "wooden_bow").has("wooden_bolt") and BowAim.ammo_for(bow_cfg, "wooden_bow").has("steel_arrow"), "7. crossbows take bolts, bows take arrows (the new metal ones too)")
	check(BowAim.pace_ms(bow_cfg, "heavy_crossbow") > BowAim.pace_ms(bow_cfg, "light_crossbow") and BowAim.pace_ms(bow_cfg, "light_crossbow") > BowAim.pace_ms(bow_cfg, "wooden_bow"), "7. a heavy crossbow reloads slower than a light one, which is slower than a bow")
	inv.add(n("light_crossbow"), 1)
	inv.add(n("wooden_bolt"), 5)
	var xs: int = slot_of("light_crossbow")
	items._last_shot.clear()
	items.action(1, Net.ACT_SHOOT, xs, 1200, 0, Vector3(0.0, 0.2, -1.0))
	check(have("wooden_bolt") == 4, "7. a shot takes one bolt")
	items._last_shot[1] = Time.get_ticks_msec() - BowAim.pace_ms(bow_cfg, "wooden_bow") - 50
	items.action(1, Net.ACT_SHOOT, xs, 1200, 0, Vector3(0.0, 0.2, -1.0))
	check(have("wooden_bolt") == 4, "7. a second shot before the crossbow is spanned again is refused")
	items._last_shot[1] = Time.get_ticks_msec() - BowAim.pace_ms(bow_cfg, "light_crossbow") - 50
	items.action(1, Net.ACT_SHOOT, xs, 1200, 0, Vector3(0.0, 0.2, -1.0))
	check(have("wooden_bolt") == 3, "7. spanned again, it shoots")
	empty_pack()
	inv.add(n("wooden_bow"), 1)
	inv.add(n("wooden_bolt"), 5)
	items._last_shot.clear()
	items.action(1, Net.ACT_SHOOT, slot_of("wooden_bow"), 1200, 0, Vector3(0.0, 0.2, -1.0))
	check(have("wooden_bolt") == 5, "7. a Shortbow does not shoot bolts")
	empty_pack()

	# 8. Weight, heat: worn weight is work on the move; a gambeson is a heat load, plate is not much of one.
	items._moving[1] = 1.0
	var effort_bare: float = items.effort_of(1)
	wear("steel_plate_harness")
	var kg: float = items._worn_kg(1)
	check(kg > 10.0 and is_equal_approx(items.effort_of(1) - effort_bare, float(prot["effort_per_kg"]) * kg), "8. %.0f kg of plate adds %.3f effort on the move" % [kg, items.effort_of(1) - effort_bare])
	items._moving[1] = 0.0
	check(is_equal_approx(items.effort_of(1), effort_bare), "8. standing still, plate is no extra work")
	strip()
	wear("gambeson")
	var hot_gambeson: float = items.heat_load(1)
	strip()
	wear("steel_plate_harness")
	check(hot_gambeson > items.heat_load(1), "8. a quilted gambeson traps more heat (%.3f) than steel plate (%.3f)" % [hot_gambeson, items.heat_load(1)])
	strip()

	# 9. Weapon reach and recovery are the row's own (s3.6 roles): a pike reaches further than a shortsword and recovers slower.
	var pike: Dictionary = items.table.entry("iron_pike")
	var short: Dictionary = items.table.entry("iron_shortsword")
	check(float(pike["reach_m"]) > float(short["reach_m"]) and int(pike["recover_ms"]) > int(short["recover_ms"]), "9. a pike reaches %.1f m against %.1f m and recovers in %d ms against %d" % [float(pike["reach_m"]), float(short["reach_m"]), int(pike["recover_ms"]), int(short["recover_ms"])])
	var reached: Array = []
	items.hit_animal = func(_p, _eye, _dir, reach, damage):
		reached.append([reach, damage])
		return true

	inv.add(n("iron_pike"), 1)
	items._last_strike.clear()
	items.action(1, Net.ACT_STRIKE, slot_of("iron_pike"), 0, 0, Vector3(0.0, 0.0, -1.0))
	items._last_strike[1] = Time.get_ticks_msec() - 700
	items.action(1, Net.ACT_STRIKE, slot_of("iron_pike"), 0, 0, Vector3(0.0, 0.0, -1.0))
	check(reached.size() == 1 and is_equal_approx(float(reached[0][0]), float(pike["reach_m"])) and is_equal_approx(float(reached[0][1]), float(pike["damage"])), "9. the pike strikes at its own reach and damage and is not ready again after 700 ms (%s)" % str(reached))

	print("armour: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
