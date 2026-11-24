extends SceneTree

# A rescue in a cave carries the player to the nearest campfire (Dave 23 Nov 2026: "if you are in a cave and end up getting rescued they
# should deposit you at the nearest civilization and for these purposes that means campfire for now"). The nearest fire whose flames are not
# under rock is chosen, any owner's, lit or not; a player stuck in a cave's rock (ACT_STUCK) is carried there with the pack kept and one
# plain line, only when the server's own ground has them inside rock, near where they are, once in a while; the spot is saved over a
# restart; a cave-in survivor carried to a fire is told so. terrain_server wiring is checked in its source (the scene is not run here).
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_rescue.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_cave_rescue"

var failures: int = 0
var said: Array = []
var died: Array = []
var solid: bool = true


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make_items():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_died = func(p, cause, at): died.append([p, cause, at])
	items.ground_height = func(_x, _z): return 10.0
	items.ground_open = func(_points): return not solid
	items.setup(ItemTableScript.load_default(), DIR)
	return items


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	# Which fire: under rock below y 0 here (a cave), the nearest fire out of the rock wins; a camp's fire with no height takes the ground's.
	var under: Callable = func(p: Vector3) -> bool: return p.y < 0.0
	var ground: Callable = func(_x: float, _z: float) -> float: return 12.0
	var near: Vector3 = Vector3(0.0, -8.0, 0.0)
	var fires: Array = [[Vector3(3.0, -7.5, 0.0), "campfire"], [Vector3(40.0, 10.0, 0.0), "campfire"], [Vector3(90.0, 10.0, 0.0), "town"], [Vector3(45.0, NAN, 30.0), "bandit"]]
	var got: Array = ItemsScript.nearest_fire_out_of_rock(fires, near, under, ground)
	check(not got.is_empty() and (got[0] as Vector3).is_equal_approx(Vector3(40.0, 10.0, 0.0)) and str(got[1]) == "campfire", "the nearest campfire out of the rock is chosen, not the one in the cave 3 m off (%s)" % str(got))
	fires.append([Vector3(10.0, NAN, 5.0), "goblin"])
	got = ItemsScript.nearest_fire_out_of_rock(fires, near, under, ground)
	check(not got.is_empty() and str(got[1]) == "goblin" and is_equal_approx(float(got[0].y), 12.0), "a nearer camp fire counts, its height read from the ground (%s)" % str(got))
	check(ItemsScript.nearest_fire_out_of_rock([[Vector3(3.0, -7.5, 0.0), "campfire"]], near, under, ground).is_empty() and ItemsScript.nearest_fire_out_of_rock([], near, under, ground).is_empty(), "no fire out of the rock: none (the old rescue place stands)")

	# Every fire counts, lit or not, each named by its camp; a bandit camp's boot-print mark at the road is not a fire.
	var items = make_items()
	var fire_row: Callable = func(camp: Variant, marks: bool) -> Dictionary:
		var f: Dictionary = {"state": 0, "burn_left": 0.0, "covered": false, "recheck": 0.0}
		if camp != null:
			f["camp"] = camp
		if marks:
			f["marks"] = true
		return f
	var NpcCamp = load("res://src/shared/npc_camp.gd")
	var rows: Array = [[990001, Vector3(50.0, 10.0, 0.0), null, false, "campfire"], [990002, Vector3(60.0, 10.0, 0.0), 0, false, "town" if NpcCamp.fire_spot().x != INF else "goblin"], [990003, Vector3(70.0, 10.0, 0.0), 2, false, "goblin"], [990004, Vector3(80.0, 10.0, 0.0), "bandit_3_4", false, "bandit"], [990005, Vector3(90.0, 10.0, 0.0), "bandit_3_4", true, ""]]

	for r in rows:
		items._items[int(r[0])] = {"number": 1, "count": 1, "pos": r[1], "left": 1.0e9, "fire": fire_row.call(r[2], bool(r[3]))}

	var spots: Array = items.campfires()

	for r in rows:
		var found: Array = spots.filter(func(s): return (s[0] as Vector3).is_equal_approx(r[1]))

		if str(r[4]) == "":
			check(found.is_empty(), "a bandit camp's boot-print mark at the road is not a fire to be carried to")
		else:
			check(found.size() == 1 and str(found[0][1]) == str(r[4]), "a fire with camp %s is a %s to be carried to (%s)" % [str(r[2]), str(r[4]), str(found)])

	for r in rows:
		items._items.erase(int(r[0]))

	# Stuck in a cave's rock: carried to the fire, the pack kept, one plain line.
	items.peer_connected_hello(1, "caverescue001")
	items.give_to(1, "stone", 7)
	var stuck: Vector3 = Vector3(100.0, 2.0, 0.0)
	var fire_spot: Vector3 = Vector3(142.5, 12.0, 0.0)
	var asked: Array = []
	items.cave_rescue = func(p: Vector3) -> Array:
		asked.append(p)
		return [[fire_spot, "campfire"]]
	var cave: Dictionary = {"top": 10.0}   # in this test a spot lower than cave.top is in the cave (a dictionary: the lambda sees later changes)
	items.player_under_rock = func(p: Vector3) -> bool: return p.y < float(cave["top"])
	items.report_position(1, stuck + Vector3(0.0, 6.0, 0.0))   # the client already stood them on the cave floor over the rock
	solid = true
	cave["top"] = 0.0
	items.action(1, Net.ACT_STUCK, 0, 0, 0, stuck)
	check(died.is_empty() and asked.is_empty(), "a player on open ground claiming a stuck point in the rock below is not moved (main gate review 8)")
	items._stuck_msec.clear()
	cave["top"] = 10.0
	solid = false
	items.action(1, Net.ACT_STUCK, 0, 0, 0, stuck)
	check(died.is_empty(), "the server's ground is open there: not stuck, nothing happens")
	items._stuck_msec.clear()
	solid = true
	items.action(1, Net.ACT_STUCK, 0, 0, 0, stuck + Vector3(30.0, 0.0, 0.0))
	check(died.is_empty(), "a stuck point far from the player is not taken")
	items._stuck_msec.clear()
	items.action(1, Net.ACT_STUCK, 0, 0, 0, stuck)
	check(died.size() == 1 and str(died[0][1]) == "rescued" and (died[0][2] as Vector3).is_equal_approx(fire_spot), "stuck in the rock: carried to the nearest campfire (%s)" % str(died))
	check(asked.size() == 1 and (asked[0] as Vector3).is_equal_approx(stuck), "  the fire is looked for from where they were stuck")
	check((items.position_of(1) as Vector3).is_equal_approx(fire_spot), "  the server has them at the fire (%s)" % str(items.position_of(1)))
	check(items.inventory_of(1).count_of(items.table.number_of("stone")) == 7, "  the pack is kept")
	check(said.size() > 0 and str(said.back()).contains("nearest campfire"), "  and told in one line (%s)" % str(said.back() if not said.is_empty() else ""))
	items.report_position(1, stuck + Vector3(0.0, 6.0, 0.0))
	items.action(1, Net.ACT_STUCK, 0, 0, 0, stuck)
	check(died.size() == 1, "asking again at once does nothing (no fast way out of a cave by asking)")

	# Over a restart: the saved spot is the fire.
	items.report_position(1, fire_spot)   # the client's next report, from the fire
	items.peer_left(1)
	items.save()
	var again = make_items()
	again.peer_connected_hello(1, "caverescue001")
	var back: Array = again.start_position_for(1)
	check(back.size() == 3 and Vector3(back[0], back[1], back[2]).distance_to(fire_spot) < 0.5, "after a restart they come back at the fire (%s)" % str(back))
	items.peer_connected_hello(1, "caverescue001")

	# No campfire out of the rock: the client's own rescue onto the floor stands.
	died.clear()
	items.cave_rescue = func(_p: Vector3) -> Array: return []
	items._stuck_msec.clear()
	items.report_position(1, stuck + Vector3(0.0, 6.0, 0.0))
	items.action(1, Net.ACT_STUCK, 0, 0, 0, stuck)
	check(died.is_empty(), "no fire anywhere: not moved")

	# A cave-in survivor carried to a fire is told so.
	said.clear()
	died.clear()
	var dd: Dictionary = items._death_cfg
	dd["stop_at_1"] = true
	items.survive_cave_in(1, fire_spot, true)
	check(died.size() == 1 and str(died[0][1]) == "cave-in survived" and (died[0][2] as Vector3).is_equal_approx(fire_spot) and str(said.back()).contains("nearest campfire"), "a cave-in survivor is dug out and carried to the campfire (%s)" % str(said.slice(-1)))

	# The wiring in terrain_server (not run here): every rescue under rock asks _cave_rescue, and the cold and water pass-out wake lines have a campfire line.
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server.contains("if _under_rock(near):") and server.contains("var fire: Array = _cave_rescue(was)") and server.contains("items.cave_rescue = func(pos: Vector3): return _cave_rescue(pos) if _under_rock(pos) else []") and server.contains("items.player_under_rock = func(pos: Vector3) -> bool: return _under_rock(pos)"), "terrain_server: a pass-out under rock, a cave-in and a stuck player all go to _cave_rescue (a stuck player only under rock)")
	var pass_out: Dictionary = items._warmth_cfg.get("pass_out", {})
	check((pass_out.get("say_wake", {}) as Dictionary).has("campfire") and (pass_out.get("say_wake_water", {}) as Dictionary).has("campfire"), "cold and water pass-outs carried to a campfire have their own wake line")
	var client: String = FileAccess.get_file_as_string("res://src/client/rescue.gd")
	check(client.contains("NetScript.ACT_STUCK"), "the client's rock rescue in a cave asks the server (rescue.gd)")

	print("test_cave_rescue: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
