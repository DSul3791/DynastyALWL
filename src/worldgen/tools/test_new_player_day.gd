extends SceneTree

# A new player's first day, every step on the real server code and fails loudly when any step is impossible (Radar, 2026-10-21):
# arrive, gather sticks, stones and fibre, craft a knife, a spear and a campfire kit, place the fire, hunt a rabbit with the spear,
# butcher it with the knife, cook the meat at the fire, eat it, lie down and sleep, die, and come back at the spawn with the remains
# where the body fell. test_first_hour.gd covers the axe, the tree, the water and the shelter; this one covers the hunt and the end.
#   godot --headless --path . --script res://src/worldgen/tools/test_new_player_day.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var zoo
var step: int = 0


func check(ok: bool, what: String) -> void:
	step += 1

	if not ok:
		failures += 1
		print("FAIL step %d: %s" % [step, what])
	else:
		print("ok   step %d: %s" % [step, what])


func count(id: String) -> int:
	return items.count_for(1, id)


func pass_time(seconds: float, exertion: float) -> void:
	for s in range(int(seconds)):
		items._exertion[1] = exertion
		items.tick(1.0)


func queue(recipe_number: int, crafts: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number, 0, crafts, Vector3.ZERO)


func slot_of(id: String) -> int:
	return items.inventory_of(1).numbers.find(items.table.number_of(id))


func _init() -> void:
	var dir: String = "user://test_new_player_day"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.respawn_point = Vector3(5.0, 10.0, 5.0)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "newplayer-day-01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._vitals_cfg["eat_pace_ms"] = 0
	items.vitals_of(1)["weight"] = 400.0   # item weights grew (Sal, 31 Oct): 32 stones and 48 sticks no longer fit a 120 kg frame with the product
	zoo = AnimalsScript.new()
	zoo.ground_height = items.ground_height
	zoo.blocked = func(_x, _z): return false
	zoo.player_positions = func(): return items.peer_positions()
	zoo.setup()
	zoo.cfg["species"]["rabbit"]["target_per_player"] = 0
	zoo.cfg["species"]["deer"]["target_per_player"] = 0
	zoo.died = func(sp, pos, _p): items.make_carcass(sp, pos)
	items.hit_animal = func(peer, origin, aim, reach, amount) -> bool:
		var target: int = zoo.target_along(origin, aim, reach)
		return target != 0 and (zoo.damage(target, amount, peer, "spear") or true)

	check(count("stone") == 0 and items.vitals_of(1)["health"] >= 99.0, "a new character arrives healthy and empty-handed")

	# Gather: stones, sticks and fibre lie about (what the scatter and the plants give).
	for n in range(8):
		items.drop_in_world(items.table.number_of("stone"), 4, Vector3(float(n) * 0.3, 10.0, 1.0))
		items.drop_in_world(items.table.number_of("stick"), 6, Vector3(float(n) * 0.3, 10.0, -1.0))
		items.drop_in_world(items.table.number_of("plant_fibre"), 3, Vector3(float(n) * 0.3, 10.0, 1.5))

	for _pass in range(12):   # the drops merged into heaps; a heap gives a handful at a time
		for id in items._items.keys():
			if not items._items[id].has("scatter"):
				items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	check(count("stone") >= 30 and count("stick") >= 40, "gathering fills the pack (%d stones, %d sticks)" % [count("stone"), count("stick")])

	# Craft the tools and the fire kit by hand.
	queue(6, 1)
	pass_time(60.0, 0.2)   # crafts take longer than their listed seconds (unskilled hands)
	check(count("stone_knife") == 1, "a stone knife is made by hand")
	queue(5, 1)
	pass_time(60.0, 0.2)   # crafts take longer than their listed seconds (unskilled hands)
	check(count("wooden_spear") == 1, "a wooden spear is made by hand")
	queue(4, 1)
	pass_time(60.0, 0.2)   # crafts take longer than their listed seconds (unskilled hands)
	check(count("campfire_kit") == 1, "a campfire kit is made by hand")

	# The player puts the knife and the spear on the hotbar (new items no longer land there by themselves).
	items.action(1, Net.ACT_MOVE, slot_of("stone_knife"), 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_MOVE, slot_of("wooden_spear"), 1, 0, Vector3.ZERO)

	# Make camp: not on a steep bank (the server refuses it), then on level ground.
	var level: Callable = items.ground_height
	items.ground_height = func(x, _z): return 10.0 + 0.5 * (x - 2.0)
	items.action(1, Net.ACT_PLACE, slot_of("campfire_kit"), 0, 0, Vector3(2.0, 10.0, 0.0))
	check(count("campfire_kit") == 1, "a campfire on a steep bank is refused")
	items.ground_height = level
	items.action(1, Net.ACT_PLACE, slot_of("campfire_kit"), 0, 0, Vector3(2.0, 10.0, 0.0))
	var fire: int = 0

	for id in items._items:
		fire = id if items._items[id].has("fire") else fire

	items.action(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)   # a placed fire is laid (fire tiers): light it with tinder from the pack
	check(fire != 0 and items.fire_is_lit(int(items._items[fire]["fire"]["state"])), "the campfire is placed and burning")

	# Hunt: a rabbit three metres off, a spear jab, a carcass, the knife.
	var rabbit: int = zoo.spawn("rabbit", 3.0, 0.0)
	check(rabbit != 0, "a rabbit is about")
	items._last_strike.erase(1)
	items.action(1, Net.ACT_STRIKE, slot_of("wooden_spear"), 0, 0, Vector3(1.0, 0.0, 0.0))
	check(not zoo.animals.has(rabbit), "one spear jab kills the rabbit")
	var carcass: int = 0

	for id in items._items:
		carcass = id if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "carcass" else carcass

	check(carcass != 0, "it leaves a carcass")
	items.report_position(1, Vector3(2.5, 10.0, 0.0))

	for n in 6:
		items._last_process.erase(1)
		items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3.ZERO)

	check(count("raw_meat") >= 1 and count("hide") >= 1, "the knife gives raw meat and a hide (%d meat)" % count("raw_meat"))

	# Cook and eat.
	items.report_position(1, Vector3(1.0, 10.0, 0.0))
	items._last_cook.clear()
	items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	check(count("roast_meat") >= 1, "the fire roasts the meat (%d roast)" % count("roast_meat"))
	items.vitals_of(1)["fed"] = 800.0
	var before_fed: float = float(items.vitals_of(1)["fed"])
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, slot_of("roast_meat"), 0, 0, Vector3.ZERO)
	check(float(items.vitals_of(1)["fed"]) > before_fed and float(items.vitals_of(1).get("sick", 0.0)) == 0.0, "the roast fills the stomach and does not make you sick")

	# Sleep out in the open: lie down, fall asleep, wake.
	items.vitals_of(1)["energy"] = 40.0
	items.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(items.sleeping_of(1), "lying down, the character falls asleep")
	pass_time(120.0, 0.0)
	check(items.energy_of(1) > 40.0, "and the sleep restores energy (%.1f)" % items.energy_of(1))
	items.action(1, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	check(not items.sleeping_of(1), "waking up works")

	# Die far from the spawn: the remains hold the pack, the character is back at the spawn, healthy and empty-handed.
	items.report_position(1, Vector3(300.0, 10.0, 300.0))
	var pack_before: int = count("stone") + count("stick")
	check(items.kill(1, "a fall") and pack_before > 0, "death works")
	check(items._peer_pos[1] == items.respawn_point, "the character is back at the spawn")
	check(count("stone") == 0 and count("stick") == 0, "with an empty pack")
	var remains: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "remains":
			remains = id

	check(remains != 0 and items._items[remains]["pos"].distance_to(Vector3(300.0, 10.0, 300.0)) < 3.0, "the remains lie where the body fell")
	check(float(items.vitals_of(1)["health"]) >= 99.0 and float(items.vitals_of(1)["fed"]) > 0.0, "the new body starts healthy and fed")

	# Walk back and take the pack from the remains (they open like a chest).
	items.report_position(1, Vector3(300.0, 10.0, 301.0))
	items.send_chest = func(_p, _i, _b): pass
	items.action(1, Net.ACT_CHEST_OPEN, remains, 0, 0, Vector3.ZERO)

	for slot in range(items.inventory_of(1).SLOTS):
		items.action(1, Net.ACT_CHEST_TAKE, slot, remains, 99, Vector3.ZERO)

	check(count("stone") + count("stick") >= pack_before - 2, "the dead character's pack can be taken back from the remains (%d of %d)" % [count("stone") + count("stick"), pack_before])

	items._finish_writer()   # an autosave thread may still be running
	print("new player day: %d steps, %d failures" % [step, failures])
	quit(1 if failures > 0 else 0)
