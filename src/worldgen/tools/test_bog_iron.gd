extends SceneTree

# Bog iron (Sonny, water_flow_rules section 11, src/shared/bog_iron.gd): deposits only under fen, marsh, swamp and bog samples, about 4% of a fen
# and twice that at its dry edge, the same every time; a spade dig gives 1 to 2 Iron ore until the deposit is empty, one ore comes back every 3
# game days up to its size, the first find is said once, the state survives a save; main's tile 3,4 holds the expected number near the spawn.
#   godot --headless --path . --script res://src/worldgen/tools/test_bog_iron.gd

const BogIron := preload("res://src/shared/bog_iron.gd")
const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const FEN := 7
const MARSH := 4
const BLOCK := 10      # wetland blocks of BLOCK x BLOCK samples, one dry row and column between them
const BLOCKS := 30     # BLOCKS x BLOCKS of them: 57,600 inside samples and 32,400 edge samples

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _cfg() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json"))
	return parsed.get("bog_iron", {}) if typeof(parsed) == TYPE_DICTIONARY else {}


# A side x side map of BLOCK-sized blocks of one class with dry rows between: [map, side].
func _blocks(cls: int, blocks: int = BLOCKS) -> Array:
	var period: int = BLOCK + 1
	var side: int = blocks * period + 1
	var map: PackedByteArray = PackedByteArray()
	map.resize(side * side)

	for j in range(side):
		for i in range(side):
			map[j * side + i] = cls if (i % period != 0 and j % period != 0) else 0

	return [map, side]


# [inside deposits, inside samples, edge deposits, edge samples, all sizes in range, sizes seen] over a block map.
func _shares(map: PackedByteArray, side: int, cfg: Dictionary) -> Array:
	var counts: Array = [0, 0, 0, 0]
	var sizes_ok: bool = true
	var seen: Dictionary = {}

	for j in range(side):
		for i in range(side):
			if map[j * side + i] == 0:
				continue

			var edge: bool = BogIron.is_edge(map, side, i, j)
			var d: Dictionary = BogIron.deposit_at_sample(map, side, i, j, i + 5000, j + 7000, cfg)
			counts[3 if edge else 1] += 1

			if not d.is_empty():
				counts[2 if edge else 0] += 1
				sizes_ok = sizes_ok and int(d["size"]) >= 6 and int(d["size"]) <= 12 and bool(d["edge"]) == edge
				seen[int(d["size"])] = true

	return [counts[0], counts[1], counts[2], counts[3], sizes_ok, seen.size()]


func _init() -> void:
	var cfg: Dictionary = _cfg()
	check(not cfg.is_empty() and str(cfg.get("item", "")) == "iron_ore", "digging.json has the bog_iron block, digging Iron ore")

	# 1. Where: only fen, marsh, swamp and bog; about 4% inside a fen and 8% at its dry edge; the same every time.
	var fen: Array = _blocks(FEN)
	var a: Array = _shares(fen[0], fen[1], cfg)
	var inside: float = float(a[0]) / float(a[1])
	var edge: float = float(a[2]) / float(a[3])
	check(absf(inside - 0.04) <= 0.01, "a fen holds a deposit on about 4%% of its inside samples (%.2f%% of %d)" % [100.0 * inside, a[1]])
	check(absf(edge - 0.08) <= 0.01, "and on about 8%% of its edge samples (%.2f%% of %d)" % [100.0 * edge, a[3]])
	check(bool(a[4]) and int(a[5]) == 7, "deposit sizes are 6 to 12 Iron ore, all seven seen, and the edge flag is right")
	check(_shares(fen[0], fen[1], cfg) == a, "the same map gives the same deposits")
	var marsh: Array = _blocks(MARSH)
	var m: Array = _shares(marsh[0], marsh[1], cfg)
	check(absf(float(m[0]) / float(m[1]) - 0.028) <= 0.008, "a marsh holds 0.7 of a fen's share (%.2f%%)" % (100.0 * float(m[0]) / float(m[1])))

	for cls in [0, 1, 2, 3, 5, 9, 10, 11]:
		var other: Array = _blocks(cls, 6)
		var none: Array = _shares(other[0], other[1], cfg)
		check(int(none[0]) + int(none[2]) == 0, "no bog iron under water class %d" % cls)

	# 2. A tile: the key is the world sample (the tile's first sample plus its own), the same as the sample rule; open ocean has none.
	var tile = TileDataScript.new()
	tile.samples = fen[1]
	tile.spacing_m = 8.0
	tile.x0 = 15360.0 * 3.0
	tile.z0 = 15360.0 * 4.0
	tile.water_class = fen[0]
	var found: Dictionary = {}

	for j in range(1, 60):
		for i in range(1, 60):
			var here: Dictionary = BogIron.deposit_at(tile, tile.x0 + 8.0 * float(i) + 1.0, tile.z0 + 8.0 * float(j) - 1.0, cfg)
			var by_sample: Dictionary = BogIron.deposit_at_sample(fen[0], fen[1], i, j, i + 5760, j + 7680, cfg)

			if here != by_sample:
				found["mismatch"] = [i, j]

			if not here.is_empty():
				found[str(here["key"])] = true

	check(not found.has("mismatch") and found.size() > 0, "deposit_at on a tile is the sample rule on world samples (%d deposits, %s)" % [found.size(), str(found.get("mismatch", "-"))])
	var ocean = TileDataScript.new()
	ocean.make_placeholder(Vector2i(0, 0), 15360.0, -200.0)
	check(BogIron.deposit_at(ocean, 10.0, 10.0, cfg).is_empty(), "open ocean holds no bog iron")

	# 3. Regrowth: one ore every 3 game days, up to the size, the clock moving on by whole steps only.
	var day: float = 86400.0
	check(BogIron.regrown([2, 0.0], 8, 2.9 * day, cfg) == [2, 0.0], "under 3 game days nothing comes back")
	check(BogIron.regrown([2, 0.0], 8, 7.0 * day, cfg) == [4, 6.0 * day], "7 game days bring back 2 and keep the odd day")
	check(BogIron.regrown([2, 0.0], 8, 300.0 * day, cfg) == [8, 300.0 * day], "never more than the size; a full deposit's clock starts again")
	check(BogIron.regrown([8, 0.0], 8, 50.0 * day, cfg) == [8, 50.0 * day], "a full deposit stays full")

	# 4. The dig on the server: wooden spade, 1 to 2 ore a dig on top of the peat until empty, then 3 game days for one more.
	var dir: String = "user://test_bog_iron"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = _make(dir)
	var clock: Array = [1000.0 * day]
	var notices: Array = []
	items.game_seconds = func(): return clock[0]
	items.skill_level = func(_p, _s): return 1.0
	items.send_notice = func(_p, text): notices.append(text)
	items.dig_ground = func(_centre, _radius): return null
	items.ground_material = func(_x, _z): return "peat"
	items.bog_deposit_at = func(x, _z, _cfg_in): return {"key": "11,22", "size": 7, "edge": true} if x < 20.0 else {}
	items.peer_connected_hello(1, "b0b0b0b0b0b0")
	items.report_position(1, Vector3(5.0, 10.0, 0.0))
	items.give(1, items.table.number_of("wooden_spade"), 1)
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

	check(per_dig_ok and total == 7, "digs give 1 to 2 Iron ore each until the deposit's 7 are gone (%d in %d digs)" % [total, digs])
	check(soil_ok, "the peat still comes up as soil")
	check(int(_dig_once(items, 6.0)[0]) == 0, "an empty deposit gives nothing")
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
	check(int(_dig_once(items, 26.0)[0]) == 0, "a dig off the deposit gives no iron")

	# 5. Save and load: what is left of a deposit, and its clock, survive a restart.
	items._bog_left["11,22"] = [3, 12345.0]
	items._dirty = true
	items.save()
	var reloaded = _make(dir)
	check(reloaded._bog_left.get("11,22", []) == [3, 12345.0], "a worked deposit is saved and loaded (%s)" % str(reloaded._bog_left.get("11,22", [])))
	reloaded.peer_connected_hello(1, "b0b0b0b0b0b0")
	reloaded.game_seconds = func(): return clock[0]
	reloaded.send_notice = func(_p, text): notices.append(text)
	reloaded.dig_ground = func(_centre, _radius): return null
	reloaded.ground_material = func(_x, _z): return "peat"
	reloaded.bog_deposit_at = items.bog_deposit_at
	reloaded.report_position(1, Vector3(5.0, 10.0, 0.0))
	reloaded._bog_left["11,22"] = [1, clock[0]]
	check(int(_dig_once(reloaded, 6.0)[0]) == 1 and notices.count(str(cfg.get("first_find", ""))) == 1, "after a restart the deposit still digs, and the first find is not said again")

	# 6. Main's tile 3,4: deposits within 2 km of the spawn (53296, 68080), expected 226 (Sonny's count on the #868 bake), within 25%.
	var path: String = "res://worlds/base_world/tiles/tile_3_4.tile"
	var head: Dictionary = TileFileScript.read_header(path) if FileAccess.file_exists(path) else {}

	if not bool(head.get("ok", false)):
		print("skip main's tile 3,4: not baked here")
	else:
		var classes: PackedByteArray = TileFileScript.read_section(path, head["table"], "water_class")["raw"]
		var side: int = int(round(sqrt(float(classes.size()))))
		var near: int = 0
		var gi0: int = BogIron.first_sample(15360.0 * 3.0, 8.0)
		var gj0: int = BogIron.first_sample(15360.0 * 4.0, 8.0)
		var ci: int = int(round((53296.0 - 15360.0 * 3.0) / 8.0))
		var cj: int = int(round((68080.0 - 15360.0 * 4.0) / 8.0))

		for j in range(maxi(cj - 250, 0), mini(cj + 251, side)):
			for i in range(maxi(ci - 250, 0), mini(ci + 251, side)):
				if (i - ci) * (i - ci) + (j - cj) * (j - cj) <= 250 * 250 and not BogIron.deposit_at_sample(classes, side, i, j, gi0 + i, gj0 + j, cfg).is_empty():
					near += 1

		check(near >= 170 and near <= 290, "main's tile 3,4 has %d bog iron deposits within 2 km of the spawn (expected 226)" % near)

	print("test_bog_iron: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# One spade dig at (x, 10, 0) by peer 1: [Iron ore gained, soil gained]. The soil is put away again so the pack never gets too heavy.
func _dig_once(items, x: float) -> Array:
	var inv = items.inventory_of(1)
	var ore: int = items.table.number_of("iron_ore")
	var soil: int = items.table.number_of("soil")
	var ore_was: int = inv.count_of(ore)
	var soil_was: int = inv.count_of(soil)
	items._last_dig.clear()
	items.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(x, 10.0, 0.0))
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
