extends SceneTree

# Every felled full-size tree gives logs (Dave 1 Nov: a felled tree without logs is a dead end). Fells each species and checks it comes down in its logs on the
# ground (Dave 16 Nov 2026: already broken into logs as it falls), none in the pack, and no trunk left lying.
#   godot --headless --path . --script res://src/worldgen/tools/test_all_trees_logs.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func loose_logs(w, number: int) -> Array:
	var out: Array = []

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and not it.has("struct") and int(it["number"]) == number:
			out.append(k)

	return out


func _init() -> void:
	for species in ["oak", "beech", "maple", "walnut", "birch", "scots_pine", "spruce", "coconut_palm", "acacia", "mangrove", "date_palm", "mirrorbark", "wardpine", "hearthwood", "everember", "witness_tree", "apple_early", "pear_winter", "sour_cherry", "plum", "quince", "fig", "olive", "mango", "sweet_chestnut", "alder", "rowan", "wild_apple", "wild_pear", "wild_cherry", "willow", "balsam_fir"]:
		one(species)

	print("all trees logs tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func one(species: String) -> void:
	var dir: String = "user://test_all_trees_logs_%s_%d" % [species, Time.get_ticks_usec()]
	var w = make(dir)
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true}
	w.game_seconds = func(): return 5000.0
	w.tree_info = func(_c, id): return {"name": species, "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.send_notice = func(_p, _text): pass
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(40):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))

	var log_n: int = w.table.number_of("log_" + species)

	if log_n <= 0 or bool(w.table.entry("log_" + species).get("retired", false)):
		log_n = w.table.number_of("log")   # no own log item: the plain Log

	check(w._items.values().all(func(it): return not it.has("tree") or int(it["tree"]["state"]) == 4), "%s: no trunk is left lying, only the stump" % species)
	check(loose_logs(w, log_n).size() >= 1, "%s: the tree comes down in its logs (%d)" % [species, loose_logs(w, log_n).size()])
	check(w.inventory_of(1).count_of(log_n) == 0, "%s: no log went into the pack" % species)
