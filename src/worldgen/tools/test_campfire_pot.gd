extends SceneTree

# The campfire pot (Dave 24 Oct): it snaps onto a small fire, caps that fire at the firewood stage while it hangs there, cooks only
# while the fire is lit, leaves the fire burning when it is taken away, and saves and loads the same in every state.
#   godot --headless --path . --script res://src/worldgen/tools/test_campfire_pot.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func place(items, kit: String, spot: Vector3) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(kit), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of(kit)), 0, 0, spot)


func ids_with(items, key: String) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has(key):
			out.append(id)

	return out


func pot_id(items) -> int:
	for id in items._items:
		if items._is_pot(items._items[id]):
			return id

	return -1


# fire state, pot flag and pot spot, as a comparable row
func summary(items) -> Array:
	var rows: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("fire"):
			rows.append(["fire", snappedf(it["pos"].x, 0.01), snappedf(it["pos"].z, 0.01), int(it["fire"]["state"]), bool(it["fire"].get("pot", false)), snappedf(float(it["fire"]["burn_left"]), 0.1)])
		elif items._is_pot(it):
			rows.append(["pot", snappedf(it["pos"].x, 0.01), snappedf(it["pos"].z, 0.01)])

	rows.sort()
	return rows


func _init() -> void:
	var dir: String = "user://test_campfire_pot"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	items.peer_connected_hello(1, "potkey000001")
	items.report_position(1, Vector3(400.0, 10.0, 400.0))
	var kit: int = items.table.number_of("campfire_pot_kit")

	# 1 names: no tripod anywhere a player reads
	for id in ["campfire_pot_kit", "campfire_pot"]:
		check(items.table.name_of(items.table.number_of(id)) == "Campfire pot", "%s is called Campfire pot" % id)
		check(not str(items.table.entry(id).get("description", "")).to_lower().contains("tripod"), "%s description has no tripod" % id)

	check(items.table.number_of("campfire_pot_kit") == 254 and items.table.number_of("campfire_pot") == 255, "item numbers 254 and 255 are kept")
	check(items.recipes.recipe(165).get("name", "") == "Campfire pot", "recipe 165 is the Campfire pot")

	# 2 no fire nearby: nothing placed, the kit stays in the pack
	place(items, "campfire_pot_kit", Vector3(402.0, 10.0, 400.0))
	check(pot_id(items) < 0, "with no fire nearby the pot is not placed")
	check(items.inventory_of(1).has(kit, 1), "with no fire nearby the kit stays in the pack")
	place(items, "campfire_kit", Vector3(404.0, 10.0, 400.0))
	place(items, "campfire_pot_kit", Vector3(410.0, 10.0, 400.0))
	check(pot_id(items) < 0, "a fire 6 m away is too far to snap to")

	# 2 snap: put near the fire, the pot takes the fire's spot (and not a second pot on the same fire)
	var fire_id: int = ids_with(items, "fire")[0]
	var fire: Dictionary = items._items[fire_id]["fire"]
	place(items, "campfire_pot_kit", Vector3(405.2, 10.0, 400.5))
	check(pot_id(items) >= 0 and items._items[pot_id(items)]["pos"].is_equal_approx(items._items[fire_id]["pos"]), "the pot snaps onto the small fire")
	check(bool(fire["pot"]), "the fire knows its pot is hanging")
	var before_n: int = items._items.size()
	place(items, "campfire_pot_kit", Vector3(404.5, 10.0, 400.2))
	check(items._items.size() == before_n, "a fire takes only one pot")

	# 3 cap: wood never takes a pot's fire past firewood
	fire["state"] = ItemsScript.FIRE_STATE_SURVIVAL
	items._items[fire_id]["left"] = 1.0e9

	for n in range(8):
		items._fire_add(fire, "firewood")
		items._fire_add(fire, "log")

	check(int(fire["state"]) == 1, "with the pot on, fire stays at the firewood stage (state %d)" % int(fire["state"]))
	items._fire_burn(fire, 10.0)
	check(int(fire["state"]) <= 1, "burning does not lift it past firewood")
	check(items._fire_best_state(fire) == 1, "best state with a pot is firewood")

	# 4 cook: only while the fire is lit; the craft waits and keeps its progress
	check(items.station_near(1, "campfire_pot"), "lit fire with the pot: it cooks")
	items.report_position(1, Vector3(404.0, 10.0, 401.0))
	items.inventory_of(1).add(items.table.number_of("clay_pot"), 1)
	fire["state"] = 8
	check(not items.station_near(1, "campfire_pot"), "fire out: the pot does not cook")
	var key: String = str(items._peer_key[1])
	items._craft_queues[key] = {"entries": [[102, 1, [[items.table.number_of("stick"), 1]]]], "elapsed": 0.0}
	items._craft_queues[key]["elapsed"] = 4.0
	items._craft_tick(1.0)
	check(is_equal_approx(float(items._craft_queues[key]["elapsed"]), 4.0), "a queue waiting on a station keeps its progress")
	items._craft_queues[key] = {"entries": [], "elapsed": 0.0}
	fire["state"] = 40
	check(items.station_near(1, "campfire_pot"), "relit fire: it cooks again")

	# 5 save and load: attached and lit, then out, then detached
	fire["state"] = 1
	items._dirty = true
	items.save()
	var again = make(dir)
	again.peer_connected_hello(1, "potkey000001")
	check(summary(again) == summary(items), "attached and lit: the same after save and load %s %s" % [str(summary(items)), str(summary(again))])
	var again_fire: Dictionary = again._items[ids_with(again, "fire")[0]]["fire"]
	check(bool(again_fire["pot"]), "after load the fire is still capped")
	again_fire["state"] = 8
	again._dirty = true
	again.save()
	var third = make(dir)
	third.peer_connected_hello(1, "potkey000001")
	check(summary(third) == summary(again) and int(third._items[ids_with(third, "fire")[0]]["fire"]["state"]) == 8 and pot_id(third) >= 0, "attached with the fire out: the same after save and load")

	# 5 take the pot down: the fire burns on, uncapped, nothing dangles
	var tfire: Dictionary = third._items[ids_with(third, "fire")[0]]["fire"]
	tfire["state"] = 1
	third.report_position(1, Vector3(404.0, 10.0, 401.0))
	third._take_down(1, third.inventory_of(1), pot_id(third))
	check(pot_id(third) < 0, "the pot is gone")
	check(third.inventory_of(1).has(kit, 1), "the kit comes back to the pack")
	check(ids_with(third, "fire").size() == 1 and int(tfire["state"]) == 41 and not bool(tfire["pot"]), "the fire keeps burning and the cap lifts (state %d)" % int(tfire["state"]))
	third._dirty = true
	third.save()
	var fourth = make(dir)
	fourth.peer_connected_hello(1, "potkey000001")
	fourth.report_position(1, Vector3(404.0, 10.0, 401.0))
	check(summary(fourth) == summary(third) and pot_id(fourth) < 0, "detached: the same after save and load")
	check(not bool(fourth._items[ids_with(fourth, "fire")[0]]["fire"].get("pot", false)), "detached: nothing is capped after load")

	# a bonfire takes no pot, a free pot takes the next fire laid beside it
	place(fourth, "campfire_pot_kit", Vector3(404.5, 10.0, 400.2))
	check(pot_id(fourth) < 0, "a bonfire is too big for a pot")
	fourth._items[ids_with(fourth, "fire")[0]]["fire"]["state"] = 1
	place(fourth, "campfire_pot_kit", Vector3(404.5, 10.0, 400.2))
	check(pot_id(fourth) >= 0, "a campfire (firewood stage) takes a pot")
	fourth._items[ids_with(fourth, "fire")[0]]["fire"]["state"] = 41
	fourth._refresh_pots()
	check(int(fourth._items[ids_with(fourth, "fire")[0]]["fire"]["state"]) == 1, "a pot put on a bigger fire steps it down to firewood")

	# old saves: a tripod pot row loads as the campfire pot; an old state 1 fire loads
	var old_dir: String = "user://test_campfire_pot_old"
	DirAccess.make_dir_recursive_absolute(old_dir)

	for file in DirAccess.get_files_at(old_dir):   # a fresh folder: earlier runs left their save here
		DirAccess.remove_absolute(old_dir + "/" + file)

	var old = make(old_dir)
	old._items[1] = {"number": 255, "count": 1, "pos": Vector3(500.0, 10.0, 500.0), "left": 1.0e9, "struct": {"kind": "tripod_pot", "yaw": 0.0}}
	old._items[2] = {"number": 1, "count": 1, "pos": Vector3(500.0, 10.0, 500.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 600.0, "covered": false, "recheck": 5.0}}
	old._next_id = 3
	old._dirty = true
	old.save()
	var rel = make(old_dir)
	rel.peer_connected_hello(1, "potkey000001")
	check(pot_id(rel) >= 0 and str(rel._items[pot_id(rel)]["struct"]["kind"]) == "campfire_pot", "an old tripod pot loads as the campfire pot")
	check(ids_with(rel, "fire").size() == 1 and int(rel._items[ids_with(rel, "fire")[0]]["fire"]["state"]) == 1 and bool(rel._items[ids_with(rel, "fire")[0]]["fire"]["pot"]), "an old state 1 fire loads and takes the pot")

	print("campfire pot tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
