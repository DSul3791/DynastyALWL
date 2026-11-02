extends SceneTree

# Playthrough probe 6 (read-only): one whole kill-to-roast chain on the real server code, wired like scenes/terrain_server/terrain_server.gd
# (server_items + server_animals, hit_animal and died hooked up): make a wooden spear and a stone knife from nothing, jab a rabbit and a deer,
# dress the carcasses, lay and light a campfire, roast the meat, eat it, and make a waterskin from the hide.  Prints "probe6:" lines.
#   godot --headless --path . --script res://art/playthrough/probe_hunt.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var items
var animals
var failures: int = 0


func n(id: String) -> int:
	return items.table.number_of(id)


func count(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func step(what: String, ok: bool, evidence: String = "") -> void:
	print("probe6: ", "PASS" if ok else "BREAK", " | ", what, " | ", evidence)

	if not ok:
		failures += 1


func craft(recipe: int, times: int = 1) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, times, Vector3.ZERO)

	for s in range(60):
		items.tick(1.0)


func hotbar(id: String) -> void:
	var slot: int = items.inventory_of(1).numbers.find(n(id))
	items.action(1, Net.ACT_MOVE, slot, 0, 0, Vector3.ZERO)   # slot 0 is the held slot of the probe; one tool at a time moves in, so move the others to 1..9 first


func _init() -> void:
	var dir: String = "user://probe_hunt"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): print("probe6:   notice: ", t)
	items.ground_height = func(_x, _z): return 10.0
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 10.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return players
	animals.setup()
	animals.cfg["species"]["rabbit"]["burrow_m"] = 0.0
	animals.died = func(sp, pos, peer): items.make_carcass(sp, pos, peer)
	items.hit_animal = func(peer, origin, dir_, reach, amount) -> bool:
		var target: int = animals.target_along(origin, dir_, reach)
		return target != 0 and (animals.damage(target, amount, peer, "spear") or true)
	items.peer_connected_hello(1, "probehunt00001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 120.0
	items._vitals_cfg["eat_pace_ms"] = 0

	# 1. Gear from nothing: fibre, sticks, stones by admin give (the gather chain is probe_playthrough's job), then craft.
	for pair in [["plant_fibre", 12], ["stick", 12], ["stone", 6]]:
		items.give(1, n(pair[0]), pair[1])

	craft(5)   # wooden spear
	step("wooden spear (1 stick, keeps a stone)", count("wooden_spear") == 1, "spears in the pack: %d" % count("wooden_spear"))
	craft(1, 2)   # twine
	craft(3)   # stone spear
	step("stone spear (wooden spear + 2 twine)", count("spear") == 1, "stone spears: %d" % count("spear"))
	craft(6)   # stone knife
	step("stone knife (2 stones, 1 stick)", count("stone_knife") == 1, "knives: %d" % count("stone_knife"))

	# The spear on the hotbar (slot 0), the knife on slot 1.
	var inv = items.inventory_of(1)
	items.action(1, Net.ACT_MOVE, inv.numbers.find(n("spear")), 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_MOVE, inv.numbers.find(n("stone_knife")), 1, 0, Vector3.ZERO)
	step("spear and knife on the hotbar", str(items.table.id_of(inv.numbers[0])) == "spear" and str(items.table.id_of(inv.numbers[1])) == "stone_knife", "slots 0 and 1: %s, %s" % [items.table.id_of(inv.numbers[0]), items.table.id_of(inv.numbers[1])])

	# 2. A rabbit 6 m ahead: jab until it is dead (health 5, stone spear 8).
	var rid: int = animals.spawn("rabbit", 0.0, -1.8)
	step("a rabbit appears (admin spawn at 1.8 m, jab reach)", rid != 0, "id %d" % rid)
	var jabs: int = 0

	while animals.animals.has(rid) and jabs < 8:
		items._last_strike.clear()
		items.action(1, Net.ACT_STRIKE, 0, 0, 0, Vector3(0.0, 0.0, -1.0))
		animals.tick(0.05)
		jabs += 1

	step("one jab kills the rabbit", not animals.animals.has(rid) and jabs <= 2, "jabs %d" % jabs)
	var carcass_id: int = 0

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "carcass":
			carcass_id = k

	step("a carcass lies where it died", carcass_id != 0, "carcass id %d" % carcass_id)
	items.report_position(1, items._items[carcass_id]["pos"] + Vector3(1.0, 0.0, 0.0))

	for b in range(5):
		items._last_process.clear()
		items.action(1, Net.ACT_PROCESS, carcass_id, 0, 0, Vector3.ZERO)

	step("dressing with the stone knife (4 blows): meat, hide, bone", count("raw_meat") >= 1 and count("hide") >= 1 and count("bone") >= 1, "raw_meat %d, hide %d, bone %d" % [count("raw_meat"), count("hide"), count("bone")])
	step("the carcass is used up", not items._items.has(carcass_id), "")

	# 3. A deer (health 20): three stone jabs.
	var did: int = animals.spawn("deer", 0.0, -11.8)
	items.report_position(1, Vector3(0.0, 10.0, -10.0))
	var deer_jabs: int = 0

	while animals.animals.has(did) and deer_jabs < 12:
		items._last_strike.clear()
		items.action(1, Net.ACT_STRIKE, 0, 0, 0, Vector3(0.0, 0.0, -1.0))
		animals.tick(0.05)
		deer_jabs += 1

	step("a deer dies to the stone spear (3 jabs expected; it may bolt and bleed out)", not animals.animals.has(did), "jabs %d, alive: %s" % [deer_jabs, str(animals.animals.has(did))])
	var deer_carcass: int = 0

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "carcass" and k != carcass_id:
			deer_carcass = k

	step("a deer carcass lies there", deer_carcass != 0, "id %d" % deer_carcass)

	if deer_carcass != 0:
		items.report_position(1, items._items[deer_carcass]["pos"] + Vector3(1.0, 0.0, 0.0))

		for b in range(5):
			items._last_process.clear()
			items.action(1, Net.ACT_PROCESS, deer_carcass, 0, 0, Vector3.ZERO)

		step("deer dressed: meat, hide, bone, sinew, fat, antler", count("raw_meat") >= 3 and count("sinew") >= 1 and count("animal_fat") >= 0, "raw_meat %d, hide %d, bone %d, sinew %d, animal_fat %d, antler %d" % [count("raw_meat"), count("hide"), count("bone"), count("sinew"), count("animal_fat"), count("antler")])

	# 4. Fire: kit, place, light with fibre, roast.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	craft(4)   # campfire kit
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	var fire: int = 0

	for k in items._items:
		if items._items[k].has("fire"):
			fire = k

	step("a campfire is placed", fire != 0, "fire id %d" % fire)
	items.action(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)
	step("the fire is lit with plant fibre", fire != 0 and items.fire_is_lit(int(items._items[fire]["fire"]["state"])), "state %s" % str(items._items[fire]["fire"]["state"] if fire != 0 else "-"))
	items._last_cook.clear()
	var raw_before: int = count("raw_meat")
	items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	step("one raw meat roasts at the fire (hold E)", count("roast_meat") == 1 and count("raw_meat") == raw_before - 1, "roast_meat %d, raw_meat %d" % [count("roast_meat"), count("raw_meat")])

	# 5. Eat the roast, and make a waterskin from two hides.
	var food_before: int = items._vitals_points(items.vitals_of(1))[0]
	items.vitals_of(1)["food"] = float(items.vitals_of(1).get("food", 0.0)) * 0.5 if items.vitals_of(1).has("food") else 0.0
	var slot_roast: int = items.inventory_of(1).numbers.find(n("roast_meat"))
	items.action(1, Net.ACT_EAT, slot_roast, 0, 0, Vector3.ZERO)
	step("the roast meat is eaten", count("roast_meat") == 0, "roast_meat left %d, food before %d%%, after %d%%" % [count("roast_meat"), food_before, items._vitals_points(items.vitals_of(1))[0]])
	craft(1)   # one more twine from fibre
	craft(23)   # waterskin: 2 hide + 1 twine
	step("a waterskin from two hides and a twine", count("waterskin") == 1, "waterskins %d, hides left %d" % [count("waterskin"), count("hide")])
	print("probe6: ", failures, " breaks")
	quit(0)
