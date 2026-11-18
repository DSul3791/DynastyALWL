extends SceneTree

# The admin check switched on (server/client split A5, 18 Nov 2026): a server for other players runs with --dedicated, and only the
# player keys in its <store>/admin.json are admins. This wires a real ServerAdmin into the items server the way terrain_server.gd does
# and sends every admin action from a listed key and from an unlisted one: the unlisted player changes nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_admin_check.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AdminScript := preload("res://src/stream/server_admin.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const ADMIN_KEY := "admincheck001"
const PLAYER_KEY := "admincheck002"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_admin_check"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var f: FileAccess = FileAccess.open(dir + "/admin.json", FileAccess.WRITE)
	f.store_string("{\"keys\": [\"%s\"]}" % ADMIN_KEY)
	f.close()

	var admin = AdminScript.new()
	admin.enforce = true           # as --dedicated
	admin.load_keys(["user://test_admin_check/nope.json", dir + "/admin.json"])
	check(admin.is_admin(ADMIN_KEY) and admin.is_admin("local:" + ADMIN_KEY), "the listed key is an admin, as a raw key or an account id")
	check(not admin.is_admin(PLAYER_KEY) and not admin.is_admin(""), "an unlisted key and no key are not admins")
	var off = AdminScript.new()
	off.enforce = false
	check(off.is_admin(PLAYER_KEY), "with the check off (local play) everybody is an admin")
	var empty = AdminScript.new()
	empty.enforce = true
	empty.load_keys(["user://test_admin_check/nope.json"])
	check(not empty.is_admin(ADMIN_KEY), "with the check on and no admin.json nobody is an admin")

	var said: Array = []
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(p, t): said.append([p, t])
	items.ground_height = func(_x, _z): return 10.0
	var resets: Array = [0]
	items.reset_terrain_edits = func() -> void: resets[0] += 1
	items.dump_water = func(_x, _z) -> String: return "dumped"
	items.land_types = func(_x, _z) -> String: return "typed"
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_ok = func(peer: int) -> bool: return admin.is_admin(items.key_of(peer))   # as terrain_server.gd
	items.admin_mode_on = func(peer: int) -> bool: return items._admin_mode_on.has(peer)
	items.peer_connected_hello(1, ADMIN_KEY)
	items.peer_connected_hello(2, PLAYER_KEY)
	items.report_position(1, Vector3.ZERO)
	items.report_position(2, Vector3(500.0, 0.0, 500.0))
	var stone: int = items.table.number_of("stone")

	# Give.
	var loose: int = items.world_item_count()
	items.action(2, Net.ACT_ADMIN_GIVE, stone, 0, 5, Vector3.ZERO)
	check(items.inventory_of(2).count_of(stone) == 0 and items.world_item_count() == loose, "a player cannot give themselves items")
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 5, Vector3.ZERO)
	check(items.inventory_of(1).count_of(stone) == 5, "the admin can")

	# Admin mode (free crafting).
	items.action(2, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)
	check(not items.free_craft_for(2), "a player cannot switch Admin mode on")
	items.action(1, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)
	check(items.free_craft_for(1), "the admin can")
	items.action(1, Net.ACT_ADMIN_MODE, 0, 0, 0, Vector3.ZERO)

	# Energy.
	var energy2: float = float(items.vitals_of(2)["energy"])
	items.action(2, Net.ACT_ADMIN_ENERGY, 0, 0, 3, Vector3.ZERO)
	check(float(items.vitals_of(2)["energy"]) == energy2, "a player cannot set their energy")

	# Spyglass (the admin glass; a = 1).
	items.action(2, Net.ACT_SPYGLASS, 1, 0, 0, Vector3.ZERO)
	check(int(items.spyglass.get(2, 0)) == -1, "a player is refused the admin spyglass")
	items.action(1, Net.ACT_SPYGLASS, 1, 0, 0, Vector3.ZERO)
	check(int(items.spyglass.get(1, -1)) == 0, "the admin may look")

	# Clear dropped items, reset terrain, reset world.
	items.drop_in_world(stone, 1, Vector3(500.0, 10.0, 500.0))
	var lying: int = items.world_item_count()
	items.action(2, Net.ACT_CLEAR_DROPS, 50, 0, 0, Vector3.ZERO)
	check(items.world_item_count() == lying and lying > 0, "a player cannot clear dropped items")
	items.action(2, Net.ACT_RESET_EDITS, 0, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_RESET_WORLD, 0, 0, 0, Vector3.ZERO)
	check(resets[0] == 0 and items.world_item_count() == lying, "a player cannot reset the terrain edits or the world")
	items.action(1, Net.ACT_RESET_EDITS, 0, 0, 0, Vector3.ZERO)
	check(resets[0] == 1, "the admin can reset the terrain edits")

	# Water and land dumps (they write files on the server).
	said.clear()
	items.action(2, Net.ACT_DUMP_WATER, 0, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_LAND_TYPES, 0, 0, 0, Vector3.ZERO)
	check(said.filter(func(row): return str(row[1]).contains("dumped") or str(row[1]).contains("typed")).is_empty(), "a player cannot dump the water or the land types")
	items.action(1, Net.ACT_DUMP_WATER, 0, 0, 0, Vector3.ZERO)
	check(not said.filter(func(row): return int(row[0]) == 1 and str(row[1]).contains("dumped")).is_empty(), "the admin can")

	# Start over as a new player.
	items.inventory_of(2).add(stone, 3)
	items.action(2, Net.ACT_NEW_PLAYER, 0, 0, 0, Vector3.ZERO)
	check(items.inventory_of(2).count_of(stone) == 3, "a player's Play as a new player is refused (their pack stays)")

	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
