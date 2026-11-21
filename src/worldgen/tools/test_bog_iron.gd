extends SceneTree

# Bog iron (Sonny, water_flow_rules section 11, src/shared/bog_iron.gd), as fields (Dave 21 Nov 2026: "if the bog had one spot it probably has a
# few"): a 512 m field square bears iron or not, about half of them; one that bears and holds enough fen, marsh, swamp or bog gets 3 to 8 patches
# clustered at its wet edge, more for a bigger wetland, spaced apart, each 6 to 12 ore with a radius by its size; none under any other water; the
# same every time. A shovel dig within a patch's radius gives 1 to 2 Bog iron ore until it is empty, one ore comes back every 3 game days, the first
# find is said once, the state survives a save. A hole dug in wetland silts back in a game day later (Dave: "the water washes the dirt back into
# the hole"), not while someone stands in it, with a fill that never heaps over the old ground. Main's tile 3,4 has fields near the spawn.
#   godot --headless --path . --script res://src/worldgen/tools/test_bog_iron.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const BogIron := preload("res://src/shared/bog_iron.gd")
const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const FEN := 7
const PER := 64        # samples along a 512 m field square at 8 m
const FIELDS := 10     # FIELDS x FIELDS field squares on the test map
const SPAWN := Vector2(58167.0, 71364.0)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _cfg() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json"))
	return parsed.get("bog_iron", {}) if typeof(parsed) == TYPE_DICTIONARY else {}


# A tile of FIELDS x FIELDS field squares, each with one block of `cls` in its middle: big (20 x 20 samples) on even columns, small (6 x 5) on odd.
func _tile(cls: int):
	var side: int = FIELDS * PER + 1
	var map: PackedByteArray = PackedByteArray()
	map.resize(side * side)

	for fz in range(FIELDS):
		for fx in range(FIELDS):
			var w: int = 20 if fx % 2 == 0 else 6
			var h: int = 20 if fx % 2 == 0 else 5

			for j in range(fz * PER + 20, fz * PER + 20 + h):
				for i in range(fx * PER + 20, fx * PER + 20 + w):
					map[j * side + i] = cls

	var tile = TileDataScript.new()
	tile.samples = side
	tile.spacing_m = 8.0
	tile.x0 = 15360.0 * 3.0
	tile.z0 = 15360.0 * 4.0
	tile.water_class = map
	return tile


# The class of the sample under world point (x, z) of a tile.
func _class_at(tile, x: float, z: float) -> int:
	return int(tile.water_class[tile.nearest(x, z)])


func _init() -> void:
	var cfg: Dictionary = _cfg()
	check(not cfg.is_empty() and str(cfg.get("item", "")) == "bog_iron_ore", "digging.json has the bog_iron block, digging Bog iron ore (Dave 19 Nov 2026)")
	check(int(cfg.get("field_m", 0)) == 512 and int(15360.0) % int(cfg.get("field_m", 1)) == 0, "a field square is 512 m and lies inside one tile")

	# 1. Fields: about half the squares bear; one that bears has 3 to 8 patches on its wetland, spaced, sized, more for the bigger wetland.
	var tile = _tile(FEN)
	var base: Vector2i = BogIron.field_of(tile.x0 + 1.0, tile.z0 + 1.0, cfg)
	var bearing: int = 0
	var counts_ok: bool = true
	var on_wet: bool = true
	var spaced: bool = true
	var sized: bool = true
	var big: Array = [0, 0]      # [patches, bearing fields] on the big blocks
	var small: Array = [0, 0]
	var edge_patches: int = 0
	var all_patches: int = 0
	var sizes: Dictionary = {}

	for fz in range(FIELDS):
		for fx in range(FIELDS):
			var patches: Array = BogIron.field(tile, base.x + fx, base.y + fz, cfg)

			if patches.is_empty():
				continue

			bearing += 1
			counts_ok = counts_ok and patches.size() >= 3 and patches.size() <= 8
			var tally: Array = big if fx % 2 == 0 else small
			tally[0] += patches.size()
			tally[1] += 1

			for a in range(patches.size()):
				var p: Dictionary = patches[a]
				on_wet = on_wet and _class_at(tile, float(p["x"]), float(p["z"])) == FEN
				sized = sized and int(p["size"]) >= 6 and int(p["size"]) <= 12 and float(p["r"]) >= 2.5 and float(p["r"]) <= 4.0
				sizes[int(p["size"])] = true
				var k: int = tile.nearest(float(p["x"]), float(p["z"]))
				all_patches += 1
				edge_patches += 1 if BogIron.is_edge(tile.water_class, tile.samples, k % tile.samples, floori(float(k) / float(tile.samples))) else 0

				for b in range(a + 1, patches.size()):
					spaced = spaced and Vector2(float(p["x"]) - float(patches[b]["x"]), float(p["z"]) - float(patches[b]["z"])).length() >= 14.0

	check(BogIron.field(tile, base.x, base.y, cfg) == BogIron.field(tile, base.x, base.y, cfg) and BogIron.field(tile, base.x + 2, base.y + 3, cfg) == BogIron.field(tile, base.x + 2, base.y + 3, cfg), "the same square gives the same patches every time")
	var share: float = float(bearing) / float(FIELDS * FIELDS)
	check(share >= 0.3 and share <= 0.7, "about half the field squares bear iron (%d of %d)" % [bearing, FIELDS * FIELDS])
	check(counts_ok, "a bearing field has 3 to 8 patches")
	check(on_wet, "every patch lies on the wetland")
	check(spaced, "patches are at least 14 m apart")
	check(sized and sizes.size() >= 5, "patches hold 6 to 12 ore with a 2.5 to 4 m radius (%d sizes seen)" % sizes.size())
	check(big[1] > 0 and small[1] > 0 and float(big[0]) / float(big[1]) > float(small[0]) / float(small[1]), "a bigger wetland gives a bigger field (%s vs %s)" % [str(big), str(small)])
	# A 20 x 20 block has 76 edge samples of 400 (19%); the seed is an edge sample and edges are taken first.
	check(all_patches > 0 and float(edge_patches) / float(all_patches) > 0.3, "the patches lie mostly at the wet edge (%d of %d)" % [edge_patches, all_patches])

	for cls in [0, 1, 2, 3, 5, 9, 10, 11]:
		var other = _tile(cls)
		var any: int = 0

		for f in range(FIELDS):
			any += BogIron.field(other, base.x + f, base.y + f, cfg).size()

		check(any == 0, "no bog iron under water class %d" % cls)

	var tiny = _tile(0)
	var tiny_side: int = tiny.samples

	for j in range(20, 22):
		for i in range(20, 25):
			tiny.water_class[j * tiny_side + i] = FEN

	check(BogIron.field_on_map(tiny.water_class, tiny_side, BogIron.first_sample(tiny.x0, 8.0), BogIron.first_sample(tiny.z0, 8.0), BogIron.first_sample(tiny.x0, 8.0), BogIron.first_sample(tiny.z0, 8.0), PER, 8.0, cfg).is_empty(), "a wetland of 10 samples is too small to hold a field")
	var ocean = TileDataScript.new()
	ocean.make_placeholder(Vector2i(0, 0), 15360.0, -200.0)
	check(BogIron.field(ocean, 0, 0, cfg).is_empty(), "open ocean holds no bog iron")
	check(BogIron.wet_at(tile, tile.x0 + 8.0 * 21.0, tile.z0 + 8.0 * 21.0, cfg) and not BogIron.wet_at(tile, tile.x0 + 8.0 * 50.0, tile.z0 + 8.0 * 50.0, cfg), "wet_at is true on the fen and false on the dry ground")

	# 2. Regrowth: one ore every 3 game days, up to the size, the clock moving on by whole steps only.
	var day: float = 86400.0
	check(BogIron.regrown([2, 0.0], 8, 2.9 * day, cfg) == [2, 0.0], "under 3 game days nothing comes back")
	check(BogIron.regrown([2, 0.0], 8, 7.0 * day, cfg) == [4, 6.0 * day], "7 game days bring back 2 and keep the odd day")
	check(BogIron.regrown([2, 0.0], 8, 300.0 * day, cfg) == [8, 300.0 * day], "never more than the size; a full deposit's clock starts again")
	check(BogIron.regrown([8, 0.0], 8, 50.0 * day, cfg) == [8, 50.0 * day], "a full deposit stays full")

	# 3. The dig on the server: wooden shovel, 1 to 2 ore a dig on top of the peat until empty, then 3 game days for one more.
	var dir: String = "user://test_bog_iron"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = _make(dir)
	var clock: Array = [1000.0 * day]
	var notices: Array = []
	var fills: Array = []
	items.game_seconds = func(): return clock[0]
	items.skill_level = func(_p, _s): return 1.0
	items.send_notice = func(_p, text): notices.append(text)
	items.dig_ground = func(_centre, _radius): return null
	items.fill_ground = func(centre, radius, material): fills.append([centre, radius, material]); return true
	items.ground_height = func(_x, _z): return 10.0
	items.ground_material = func(_x, _z): return "peat"
	items.bog_field = func(fx, fz, _cfg_in): return [{"key": "11,22", "x": 6.0, "z": 0.0, "size": 7, "r": 3.0}] if fx == 0 and fz == 0 else []
	items.bog_wet_at = func(x, _z, _cfg_in): return x < 20.0
	items.peer_connected_hello(1, "b0b0b0b0b0b0")
	items.report_position(1, Vector3(5.0, 10.0, 0.0))
	items.give(1, items.table.number_of("wooden_shovel"), 1)
	var per_dig_ok: bool = true
	var digs: int = 0
	var total: int = 0
	var soil_ok: bool = true

	while digs < 20:
		var got: Array = _dig_once(items, 6.0)
		digs += 1
		soil_ok = soil_ok and int(got[1]) >= 1

		if int(got[0]) == 0:
			break

		total += int(got[0])
		per_dig_ok = per_dig_ok and int(got[0]) >= 1 and int(got[0]) <= 2

	check(per_dig_ok and total == 7, "digs give 1 to 2 Bog iron ore each until the patch's 7 are gone (%d in %d digs)" % [total, digs])
	check(soil_ok, "the peat still comes up as soil")
	check(int(_dig_once(items, 6.0)[0]) == 0, "an empty patch gives nothing")
	check(items._bog_patch_at(8.5, 0.0).get("key", "") == "11,22", "a dig at the patch's edge is on it")
	check(items._bog_patch_at(9.5, 0.0).is_empty(), "a dig past its radius is not")
	clock[0] += 3.0 * day
	check(int(_dig_once(items, 6.0)[0]) == 1, "3 game days later one ore has come back")
	check(int(_dig_once(items, 6.0)[0]) == 0, "and only one")
	clock[0] += 300.0 * day
	var regrown_total: int = 0

	for _n in range(20):
		regrown_total += int(_dig_once(items, 6.0)[0])

	check(regrown_total == 7, "a long wait fills it back to its size, never more (%d)" % regrown_total)
	var said: int = notices.count(str(cfg.get("first_find", "")))
	check(said == 1, "the first find is said once (%d times)" % said)
	items.report_position(1, Vector3(25.0, 10.0, 0.0))
	check(int(_dig_once(items, 26.0)[0]) == 0, "a dig off the patch gives no iron")

	# 4. Holes in wetland silt back in a game day later; on dry ground they stay.
	check(items._bog_holes.size() == 1, "all the digs at one wetland spot are one waiting hole, the dry dig none (%d)" % items._bog_holes.size())
	var hole: Array = items._bog_holes[0] if not items._bog_holes.is_empty() else [0.0, 0.0, 0.0, 0.0, 0.0]
	check(absf(float(hole[1]) - 10.0) < 0.01 and absf(float(hole[4]) - (clock[0] + day)) < 1.0, "it keeps the old surface (10 m) and is due a game day after the last dig")
	items._bog_holes_tick()
	check(fills.is_empty(), "before then nothing is filled")
	clock[0] += day + 1.0
	items.report_position(1, Vector3(7.0, 10.0, 0.0))
	items._bog_holes_tick()
	check(fills.is_empty() and items._bog_holes.size() == 1, "not while a player stands in it")
	items.report_position(1, Vector3(25.0, 10.0, 0.0))
	items._bog_holes_tick()
	var fill: Array = fills[0] if not fills.is_empty() else [Vector3.ZERO, 0.0, -1]
	var top: float = (fill[0] as Vector3).y + float(fill[1])
	check(fills.size() == 1 and items._bog_holes.is_empty(), "then it silts back in, once (%d fills)" % fills.size())
	check(absf(top - 10.0) < 0.01 and float(fill[1]) >= 2.5 and int(fill[2]) == 6, "with peat, a sphere whose top just meets the old surface (top %.2f, r %.2f, material %d)" % [top, float(fill[1]), int(fill[2])])

	# 5. Save and load: what is left of a patch, its clock, and the waiting holes survive a restart.
	items._bog_left["11,22"] = [3, 12345.0]
	items._bog_holes = [[6.0, 10.0, 0.0, 0.9, 777.0]]
	items._dirty = true
	items.save()
	var reloaded = _make(dir)
	check(reloaded._bog_left.get("11,22", []) == [3, 12345.0], "a worked patch is saved and loaded (%s)" % str(reloaded._bog_left.get("11,22", [])))
	check(reloaded._bog_holes == [[6.0, 10.0, 0.0, 0.9, 777.0]], "a waiting hole is saved and loaded (%s)" % str(reloaded._bog_holes))
	reloaded.peer_connected_hello(1, "b0b0b0b0b0b0")
	reloaded.game_seconds = func(): return clock[0]
	reloaded.send_notice = func(_p, text): notices.append(text)
	reloaded.dig_ground = func(_centre, _radius): return null
	reloaded.ground_material = func(_x, _z): return "peat"
	reloaded.bog_field = items.bog_field
	reloaded.report_position(1, Vector3(5.0, 10.0, 0.0))
	reloaded._bog_left["11,22"] = [1, clock[0]]
	check(int(_dig_once(reloaded, 6.0)[0]) == 1 and notices.count(str(cfg.get("first_find", ""))) == 1, "after a restart the patch still digs, and the first find is not said again")

	# 6. Main's tile 3,4: the fields within 2.5 km of the spawn (58167, 71364). PROVISIONAL numbers: a handful of fields, tens of patches.
	var path: String = "res://worlds/base_world/tiles/tile_3_4.tile"
	var head: Dictionary = TileFileScript.read_header(path) if FileAccess.file_exists(path) else {}

	if not bool(head.get("ok", false)):
		print("skip main's tile 3,4: not baked here")
	else:
		var main = TileDataScript.new()
		main.water_class = TileFileScript.read_section(path, head["table"], "water_class")["raw"]
		main.samples = int(round(sqrt(float(main.water_class.size()))))
		main.spacing_m = 8.0
		main.x0 = 15360.0 * 3.0
		main.z0 = 15360.0 * 4.0
		var low: Vector2i = BogIron.field_of(SPAWN.x - 2500.0, SPAWN.y - 2500.0, cfg)
		var high: Vector2i = BogIron.field_of(SPAWN.x + 2500.0, SPAWN.y + 2500.0, cfg)
		var near: int = 0
		var ore: int = 0
		var fields: int = 0
		var wet_ok: bool = true

		for fz in range(low.y, high.y + 1):
			for fx in range(low.x, high.x + 1):
				var patches: Array = BogIron.field(main, fx, fz, cfg)
				fields += 1 if not patches.is_empty() else 0

				for p in patches:
					wet_ok = wet_ok and float(cfg["classes"].get(str(_class_at(main, float(p["x"]), float(p["z"]))), 0.0)) > 0.0

					if Vector2(float(p["x"]), float(p["z"])).distance_to(SPAWN) <= 2500.0:
						near += 1
						ore += int(p["size"])

		print("     main tile 3,4 within 2.5 km of the spawn: %d bearing fields, %d patches, %d ore" % [fields, near, ore])
		check(near >= 3 and near <= 120 and wet_ok, "main's tile 3,4 has %d bog iron patches within 2.5 km of the spawn, all on wetland" % near)

	print("test_bog_iron: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# One shovel dig at (x, 10, 0) by peer 1: [Bog iron ore gained, soil gained]. The soil is put away again so the pack never gets too heavy.
func _dig_once(items, x: float) -> Array:
	var inv = items.inventory_of(1)
	var ore: int = items.table.number_of("bog_iron_ore")
	var soil: int = items.table.number_of("soil")
	var ore_was: int = inv.count_of(ore)
	var soil_was: int = inv.count_of(soil)
	items._last_dig.clear()
	items.action(1, Net.ACT_DIG, HeldTool.slot_of(items, "shovel"), 0, 0, Vector3(x, 10.0, 0.0))
	var got: Array = [inv.count_of(ore) - ore_was, inv.count_of(soil) - soil_was]
	inv.remove(soil, inv.count_of(soil))
	return got


func _make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items
