extends SceneTree

# Torches and the wet (Dave, 4 Nov 2026): a held torch goes out under water and after a few seconds in the open rain, a lantern-like flame
# (no rain_douses) only under water; the server swaps the torch for a doused one, and E at a burning fire lights it again.
#   godot --headless --path . --script res://src/worldgen/tools/test_torch_douse.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _find(items, kind: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			return id

	return 0


func _count(items, kind: String) -> int:
	var n: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			n += 1

	return n


# The light burn rule (buildables plan, batch B4): a light's fuel burns fuel_days game days (1 game day = 1 real hour), else fuel_s seconds; the
# open rain puts out a light with rain_douses (a torch post) and never a lantern; a lit light with protect_m keeps wolves off like a held torch.
# No lantern or torch post rows exist yet (Jamie's B4 batch), so stand-in rows are used.
func _light_burn_checks(items, inv) -> void:
	items._structures["test_lantern"] = {"kit": "test_lantern_kit", "item": "chandelier", "state": 9903, "use": "light", "lights": true, "fuel": "candle", "fuel_days": 1.0, "gap_exempt": true, "cap_per_chunk": 12}
	items._structures["test_torch_post"] = {"kit": "test_torch_post_kit", "item": "chandelier", "state": 9904, "use": "light", "lights": true, "fuel": "stick", "fuel_days": 0.5, "rain_douses": true, "protect_m": 8.0, "gap_exempt": true, "cap_per_chunk": 12}
	check(is_equal_approx(items.light_burn_s(items._structures["test_lantern"]), 3600.0), "a candle in a lantern burns one game day (an hour)")
	check(is_equal_approx(items.light_burn_s(items._structures["chandelier"]), float(items._structures["chandelier"]["fuel_s"])), "a row with fuel_s keeps its seconds")
	var lantern_at: Vector3 = Vector3(102.0, 5.0, 101.0)
	var post_at: Vector3 = Vector3(102.0, 5.0, 99.0)
	items._items[910001] = {"number": items.table.number_of("chandelier"), "count": 1, "pos": lantern_at, "left": 1.0e9, "struct": {"kind": "test_lantern", "yaw": 0.0}}
	items._items[910002] = {"number": items.table.number_of("chandelier"), "count": 1, "pos": post_at, "left": 1.0e9, "struct": {"kind": "test_torch_post", "yaw": 0.0}}
	items.rain_now = func(): return 0.0
	items.action(7, Net.ACT_ADMIN_GIVE, items.table.number_of("candle"), 0, 1, Vector3.ZERO)
	items.action(7, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 1, Vector3.ZERO)
	items._light_fixture(7, inv, items._items[910001], items._structures["test_lantern"])
	items._light_fixture(7, inv, items._items[910002], items._structures["test_torch_post"])
	check(bool(items._items[910001]["struct"].get("lit", false)) and is_equal_approx(float(items._items[910001]["struct"]["fuel_left"]), 3600.0), "E with a candle lights the lantern for a game day")
	check(bool(items._items[910002]["struct"].get("lit", false)) and is_equal_approx(float(items._items[910002]["struct"]["fuel_left"]), 1800.0), "a stick lights the torch post for half a game day")
	check(items._lit_fires().has(post_at) and is_equal_approx(items.fire_protect_m(post_at), 8.0), "the lit torch post keeps wolves off 8 m")
	check(not items._lit_fires().has(lantern_at), "a lantern with no protect_m does not")
	items._lights_tick(600.0)
	check(is_equal_approx(float(items._items[910001]["struct"]["fuel_left"]), 3000.0), "the fuel burns down in real seconds")
	items.rain_now = func(): return 0.9
	items.cover_at = func(_p): return 0.0
	items._lights_tick(1.0)
	check(bool(items._items[910001]["struct"].get("lit", false)), "the open rain does not put out a lantern")
	check(not bool(items._items[910002]["struct"].get("lit", false)), "it puts out the torch post")
	check(not items._lit_fires().has(post_at), "and the put-out post keeps nothing off")
	items.rain_now = func(): return 0.0
	# A lantern's own candle (blueprints.json "spent", coordinator ruling 10 Nov 2026): it burns in the lantern from the start and is not given back.
	items._structures["test_lantern"]["kit"] = "test_lantern_kit"
	items._blueprints[99901] = {"number": 99901, "structure": "test_lantern", "cost": [["candle", 1], ["stick", 2]], "spent": [["candle", 1]], "hammer": 1}
	items._blueprint_of_kit["test_lantern_kit"] = 99901
	var built: Dictionary = {"number": items.table.number_of("chandelier"), "count": 1, "pos": Vector3(101.0, 5.0, 101.0), "left": 1.0e9, "struct": {"kind": "test_lantern", "yaw": 0.0}}
	items._after_built(7, built, items._structures["test_lantern"])
	check(bool(built["struct"].get("lit", false)) and is_equal_approx(float(built["struct"]["fuel_left"]), 3600.0), "a lantern built with its candle stands lit for a game day")
	items._items[910003] = built
	var candles: int = inv.count_of(items.table.number_of("candle"))
	var sticks: int = inv.count_of(items.table.number_of("stick"))
	items._take_down(7, inv, 910003)
	check(not items._items.has(910003) and inv.count_of(items.table.number_of("candle")) == candles and inv.count_of(items.table.number_of("stick")) == sticks + 2, "taken down it gives the sticks back, not the burnt candle")
	check(items._refund_blueprint(7, inv, items._blueprints[99901]) and inv.count_of(items.table.number_of("candle")) == candles + 1, "an unbuilt kit's refund still gives everything")
	items._blueprints.erase(99901)
	items._blueprint_of_kit.erase("test_lantern_kit")
	items._items.erase(910001)
	items._items.erase(910002)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var torch: Dictionary = table.entry("torch")
	var lantern: Dictionary = {"doused_item": "lantern_out"}      # a lantern (not in the game yet): rain does not put it out
	var grace: float = FlameRules.RAIN_GRACE_S

	check(FlameRules.douse_reason(torch, true, 0.0, false, 0.0) == "water", "a torch goes out under water")
	check(FlameRules.douse_reason(torch, false, 0.8, false, grace) == "rain", "a torch goes out after a while in the open rain")
	check(FlameRules.douse_reason(torch, false, 0.8, false, grace * 0.5) == "", "a torch keeps burning for a few seconds of rain")
	check(FlameRules.douse_reason(torch, false, 0.8, true, grace * 2.0) == "", "a torch under cover keeps burning in the rain")
	check(FlameRules.douse_reason(torch, false, 0.1, false, grace * 2.0) == "", "a drizzle does not put a torch out")
	check(FlameRules.douse_reason(lantern, false, 1.0, false, grace * 2.0) == "", "a lantern burns in the rain")
	check(FlameRules.douse_reason(lantern, true, 0.0, false, 0.0) == "water", "a lantern goes out under water")
	check(FlameRules.douse_reason(table.entry("torch_doused"), true, 1.0, false, grace * 2.0) == "", "a doused torch has nothing to put out")

	check(FlameRules.light_block(true, 0.0, false) == "water", "a torch cannot be lit under water")
	check(FlameRules.light_block(true, 1.0, true) == "water", "nor under water with cover")
	check(FlameRules.light_block(false, 0.9, false) == "rain", "nor in open rain")
	check(FlameRules.light_block(false, 0.9, true) == "", "a cave or cover lets it light in rain")
	check(FlameRules.light_block(false, 0.1, false) == "", "a drizzle does not stop it")
	check(FlameRules.light_block(false, 0.0, false) == "", "dry and above water it lights")

	var dir: String = "user://test_torch_douse"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(table, dir)
	items.peer_connected_hello(7, "torchtest1234")
	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	var lit: int = table.number_of("torch")
	var doused: int = table.number_of("torch_doused")
	check(doused > 0 and bool(table.entry("torch_doused").get("offhand", false)), "the doused torch is an item and goes in the left hand")
	items.action(7, Net.ACT_ADMIN_GIVE, lit, 0, 1, Vector3.ZERO)
	var inv = items.inventory_of(7)
	var slot: int = inv.numbers.find(lit)
	check(slot >= 0, "the torch is in the pack")

	# Rain: refused when the server sees no rain (the client cannot douse at will), done when it rains.
	items.rain_now = func(): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "no rain on the server: the torch keeps burning")
	items.rain_now = func(): return 0.9
	items.cover_at = func(_p): return 2.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "under a roof: the torch keeps burning")
	items.cover_at = func(_p): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "open rain: the torch goes out")

	# Relight at a burning fire in reach; not at a cold one or one too far.
	items._items[900001] = {"pos": Vector3(101.0, 5.0, 100.0), "fire": {"state": 9}}
	items.action(7, Net.ACT_RELIGHT, 900001, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a cold fire does not light the torch")
	items._items[900002] = {"pos": Vector3(160.0, 5.0, 100.0), "fire": {"state": 1}}
	items.action(7, Net.ACT_RELIGHT, 900002, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a fire out of reach does not light the torch")
	items._items[900003] = {"pos": Vector3(101.0, 5.0, 100.0), "fire": {"state": 1}}
	items.action(7, Net.ACT_RELIGHT, 900003, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "a burning fire lights the torch again")

	# Water: under water the torch goes out whatever the weather, but only when the server too sees the head under water (or the player swimming).
	items.rain_now = func(): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "the client alone saying water does not put it out")
	items.set_head_under(7, true)
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "under water: the torch goes out")
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a doused torch stays doused")
	items.set_head_under(7, false)
	inv.numbers[slot] = lit
	items.set_swimming(7, true)
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "swimming: the torch goes out")
	items.set_swimming(7, false)

	# The rain and a roof over the eye only (a lean-to's low back, a crown above the head): the torch burns on (Dave 10 Nov 2026).
	inv.numbers[slot] = lit
	items.rain_now = func(): return 0.9
	items.cover_at = func(p: Vector3): return 2.0 if p.y > 6.0 else 0.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "cover over the eye keeps the torch burning in the rain")
	items.cover_at = func(_p): return 0.0
	items.rain_now = func(): return 0.0
	inv.numbers[slot] = doused
	items._items.erase(900001)
	items._items.erase(900002)
	items._items.erase(900003)

	# Placing (Dave, 4 Nov 2026): a burning torch stuck in the ground stays lit; the open rain puts it out; hold E gives it back doused.
	items.ground_height = func(_x, _z): return 5.0
	items.action(7, Net.ACT_RELIGHT, 900003, 0, 0, Vector3.ZERO)      # the fire is gone: still doused
	check(inv.numbers[slot] == doused, "E at a missing fire does not relight")
	items.set_swimming(7, true)
	items.action(7, Net.ACT_RELIGHT, 0, slot + 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a torch cannot be lit in the water")
	items.set_swimming(7, false)
	items.action(7, Net.ACT_RELIGHT, 0, slot + 1, 0, Vector3.ZERO)      # the hotkey: no fire needed (Dave 6 Nov 2026)
	check(inv.numbers[slot] == lit, "pressing the torch's key lights it again, with no fire")
	check(str(table.entry("torch")["name"]) == str(table.entry("torch_doused")["name"]), "a torch that went out keeps its name")
	inv.numbers[slot] = doused
	inv.numbers[slot] = lit
	items.action(7, Net.ACT_PLACE_TORCH, slot, 0, 90, Vector3(101.5, 5.0, 100.0))
	var stood: int = _find(items, "standing_torch")
	check(stood != 0 and inv.numbers[slot] == 0, "a torch stuck in the ground leaves the hand")
	check(stood != 0 and bool(items._items[stood]["struct"].get("lit", false)), "the standing torch burns")
	items.action(7, Net.ACT_PLACE_TORCH, slot, 0, 0, Vector3(101.5, 5.0, 100.0))
	check(_count(items, "standing_torch") == 1, "an empty hand places nothing")
	items.rain_now = func(): return 0.9
	items.cover_at = func(_p): return 2.0
	items._lights_tick(1.0)
	check(stood != 0 and bool(items._items[stood]["struct"].get("lit", false)), "under a roof the standing torch burns in the rain")
	items.cover_at = func(_p): return 0.0
	items._lights_tick(1.0)
	check(stood != 0 and not bool(items._items[stood]["struct"].get("lit", false)), "the open rain puts the standing torch out")
	items._take_down(7, inv, stood)
	check(_count(items, "standing_torch") == 0 and inv.count_of(doused) == 1, "taking it back gives a doused torch")

	# On a wall: placed where aimed, off the ground; a burning one comes back burning.
	items.rain_now = func(): return 0.0
	var back: int = inv.numbers.find(doused)
	inv.numbers[back] = lit
	items.action(7, Net.ACT_PLACE_TORCH, back, 1, 180, Vector3(101.0, 6.6, 100.0))
	var hung: int = _find(items, "torch_sconce")
	check(hung != 0 and absf(float(items._items[hung]["pos"].y) - 6.6) < 0.01, "a torch on a wall stays where it was aimed")
	items._take_down(7, inv, hung)
	check(_count(items, "torch_sconce") == 0 and inv.count_of(lit) == 1, "a burning torch comes back burning")
	items.action(7, Net.ACT_PLACE_TORCH, inv.numbers.find(lit), 0, 0, Vector3(101.0, 7.5, 100.0))
	check(_count(items, "standing_torch") == 0, "the ground placement needs the ground")
	items.action(7, Net.ACT_PLACE_TORCH, inv.numbers.find(lit), 0, 0, Vector3(140.0, 5.0, 100.0))
	check(_count(items, "standing_torch") == 0, "out of reach: nothing placed")

	# Burning down (Dave 6 Nov 2026): about half an hour in hand; the bearer scares wolves like a small fire while it burns.
	check(float(table.entry("torch").get("burn_s", 0.0)) == 1800.0, "a torch burns for 30 minutes")
	items.action(7, Net.ACT_ADMIN_GIVE, lit, 0, 1, Vector3.ZERO)
	var burning: int = inv.numbers.find(lit)
	items._torch_seen.erase(7)
	items.action(7, Net.ACT_TORCH_BURN, burning, 0, 0, Vector3.ZERO)
	check(inv.numbers[burning] == lit and inv.wear[burning] > 0, "a burning torch wears down")
	check(items._lit_fires().has(Vector3(100.0, 5.0, 100.0)) and absf(items.fire_protect_m(Vector3(100.0, 5.0, 100.0)) - items.TORCH_PROTECT_M) < 0.01, "its bearer keeps wolves off")
	inv.wear[burning] = 17990
	items._torch_seen[7] = Time.get_ticks_msec() - 1500
	items.action(7, Net.ACT_TORCH_BURN, burning, 0, 0, Vector3.ZERO)
	check(inv.numbers[burning] == 0, "after half an hour the torch is gone")

	_light_burn_checks(items, inv)
	print("torch douse tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
