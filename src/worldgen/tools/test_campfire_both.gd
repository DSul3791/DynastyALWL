extends SceneTree

# The campfire is made both ways (Dave 26 Nov 2026, "campfire both": small things like campfires work for both because they are small; the hammer
# is for the larger things people could not carry, and it lets several people finish a build). By hand: the Campfire from the pack is set down as a
# laid fire. With the hammer: blueprint 366 sets down a site that takes nothing; hammer hits fill it, from more than one player; when it is full it
# becomes the same laid fire, and both the builder and the one who finished it count the placed campfire. A site is placed by the fire's own rules
# (2 m from a fire), and a fire or another site keeps the structures' 2.5 m from a site; a site counts toward the fires in its chunk.
#   godot --headless --path . --script res://src/worldgen/tools/test_campfire_both.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const DIR := "user://test_campfire_both"

var failures: int = 0
var said: Array = []
var f


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func n(id: String) -> int:
	return f.table.number_of(id)


func have(peer: int, id: String) -> int:
	return f.inventory_of(peer).count_of(n(id))


func fires_near(at: Vector3, within: float = 0.6) -> Array:
	var out: Array = []

	for id in f._items:
		if f._items[id].has("fire") and (f._items[id]["pos"] as Vector3).distance_to(at) <= within:
			out.append(id)

	return out


func placed_count(peer: int) -> int:
	var st: Dictionary = f._goal_state_of(peer)
	return -1 if st.is_empty() else int(st["goal_counts"].get(f._goal_count_key("placed", "campfire"), 0))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(_p, t): said.append(str(t))
	f.setup(ItemTableScript.load_default(), DIR)
	f.ground_height = func(_x, _z): return 10.0

	for peer in [1, 2]:
		f.peer_connected_hello(peer, "campfireboth%d" % peer)
		f._characters[f._peer_key[peer]]["grace_s"] = 0.0

	var bp: Dictionary = f._blueprints.get(366, {})
	check(str(bp.get("structure", "")) == "campfire" and str(bp.get("lays", "")) == "campfire_kit" and int(bp.get("hammer", 0)) == 1 and bool(bp.get("known", false)), "blueprint 366 is the Campfire, built with any hammer, known from the start")
	check(str(f.table.name_of(n("campfire_kit"))) == "Campfire" and not str(f.table.name_of(n("campfire_kit"))).to_lower().contains("kit"), "the hand-made item reads Campfire, never a kit")

	# By hand: the Campfire from the pack is set down as a laid fire.
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	f.give(1, n("campfire_kit"), 1)
	f.action(1, Net.ACT_PLACE, f.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, Vector3(-3.0, 10.0, 0.0))
	var hand: Array = fires_near(Vector3(-3.0, 10.0, 0.0))
	check(hand.size() == 1 and int(f._items[hand[0]]["fire"]["state"]) == 9 and have(1, "campfire_kit") == 0, "by hand: the Campfire is set down as a laid fire and leaves the pack")

	# With the hammer: the site takes nothing and is no fire yet.
	f.give(1, n("stone_hammer"), 1)
	f.give(1, n("stick"), 6)
	f.give(1, n("stone"), 8)
	f.give(2, n("stone_hammer"), 1)
	f.give(2, n("stone"), 8)
	var spot: Vector3 = Vector3(3.0, 10.0, 0.0)
	var placed_1: int = placed_count(1)
	var placed_2: int = placed_count(2)
	f.action(1, Net.ACT_PLACE_BLUEPRINT, 366, 0, 0, spot)
	var site: int = HeldTool.site_of(f, "campfire")
	check(site >= 0 and fires_near(spot).is_empty() and have(1, "stone") == 8 and have(1, "stick") == 6, "with the hammer: a Campfire blueprint site goes down, takes nothing and is no fire yet (%s)" % (said[-1] if said.size() > 0 else ""))

	if site < 0:
		_done()
		return

	check(int(f._items[site]["number"]) == n("campfire_kit") and f._items[site]["struct"].has("site"), "the site is the Campfire's own blue blueprint")

	# Too close: neither a Campfire from the pack nor another blueprint goes down next to the site.
	f.give(1, n("campfire_kit"), 1)
	f.action(1, Net.ACT_PLACE, f.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, spot + Vector3(1.0, 0.0, 0.0))
	check(fires_near(spot + Vector3(1.0, 0.0, 0.0)).is_empty() and have(1, "campfire_kit") == 1, "a Campfire from the pack is refused 1 m from a campfire site, and stays in the pack")
	f.action(1, Net.ACT_PLACE_BLUEPRINT, 366, 0, 0, spot + Vector3(0.0, 0.0, 1.0))
	check(HeldTool.site_of(f, "campfire") == site, "a second campfire blueprint is refused 1 m from the first")

	# Two players fill it: the builder's hit puts in their 6 sticks and 8 stones, a second player's hit puts in the last 8 stones and finishes it.
	f.report_position(1, spot + Vector3(0.0, 0.0, 1.5))
	HeldTool.hit_site(f, site, 1)
	check(f._items.has(site) and f._items[site]["struct"].has("site") and int(f._items[site]["struct"]["site"]["have"].get("stone", 0)) == 8 and int(f._items[site]["struct"]["site"]["have"].get("stick", 0)) == 6, "the builder's hammer hit puts their 6 sticks and 8 stones in; the site still waits for 8 more stones")
	f.report_position(2, spot + Vector3(0.0, 0.0, -1.5))
	HeldTool.hit_site(f, site, 2)
	var built: Array = fires_near(spot)
	check(not f._items.has(site) and built.size() == 1 and have(2, "stone") == 0, "a second player's hit puts in the last 8 stones: the site is gone and a fire lies where it was")

	if built.size() == 1:
		var fire: Dictionary = f._items[built[0]]
		check(int(fire["number"]) == n("campfire_kit") and int(fire["fire"]["state"]) == 9 and float(fire["fire"]["burn_left"]) > 0.0, "it is a laid fire like one set down from the pack, holding its first sticks")

	check(have(1, "stone") == 0 and have(1, "stick") == 0, "the builder's 8 stones and 6 sticks went in")

	if placed_1 >= 0 and placed_2 >= 0:
		check(placed_count(1) == placed_1 + 1 and placed_count(2) == placed_2 + 1, "both the builder and the one who finished it count a placed campfire (%d, %d)" % [placed_count(1), placed_count(2)])

	# Tests and admin tools lay the fire with no hammer or materials (place_piece by the hand item's name).
	f.report_position(1, Vector3(0.0, 10.0, 6.0))
	f.place_piece(1, "campfire_kit", Vector3(0.0, 10.0, 8.0))
	check(fires_near(Vector3(0.0, 10.0, 8.0)).size() == 1 and HeldTool.site_of(f, "campfire") < 0, "place_piece lays the fire at once, no site")
	_done()


func _done() -> void:
	f._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
