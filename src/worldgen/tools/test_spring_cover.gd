extends SceneTree

# Spring cover (Sonny, 9 Nov 2026; Dave: "use low shrubs that block the view of the ground in clumps over the spring head so its hidden. let the
# water just run out from under the bush"; design R6 as built, "The spring cover"). On the nine tiles from the water record:
#   - every ground spring has its clump: at least the rules' least count of plants of one low shrub species, one of them within 0.6 m of the head;
#     fewer only where open lake or sea, a cave mouth or a tile edge is within the clump's reach (listed);
#   - each plant of a clump stands in one chunk only, and placing a chunk twice gives the same clump;
#   - a sample of clumps comes through the whole chunk placement (spacing, shade and the other rules) whole.
#   godot --headless --path . --script res://src/worldgen/tools/test_spring_cover.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

const TILES := [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]
const HEAD_M := 0.6        # one plant this close to the head
const SAMPLE := 6          # clumps on tile 3,4 checked through the whole chunk_items

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	_check(settings != null and errors.is_empty(), "world, rules and tables load")

	if settings == null or not errors.is_empty():
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var cover: Dictionary = rules["runtime_flora"]["spring_cover"]
	var least: int = int(cover["count"][0])
	var reach: float = float(cover["radius_m"][1]) + float(cover["jitter_m"]) + 0.1
	var tile_m: float = float(generator.tile_size_m)
	_check(not placer._cover.is_empty() and placer._cover["species"].size() == cover["species"].size(), "every cover species is a patch shrub (%d of %d)" % [placer._cover.get("species", []).size(), cover["species"].size()])

	var springs: int = 0
	var full: int = 0
	var excused: Array = []      # [tile, index, plants, why]
	var short: Array = []
	var no_head: Array = []
	var mixed: Array = []
	var twice: int = 0
	var unstable: int = 0
	var by_species: Dictionary = {}
	var sampled: Array = []      # [chunk, head, found entries in that chunk]

	for tile in TILES:
		var data = generator.get_tile(tile)

		if data.placeholder:
			_check(false, "tile %s is baked" % str(tile))
			continue

		for index in range(data.ground_springs.size()):
			var spring: Array = data.ground_springs[index]

			if str(spring[2]) != "bushes":
				continue

			springs += 1
			var head: Vector3 = spring[0]
			var chunks: Dictionary = {}

			for corner in [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
				chunks[placer.chunk_of(head.x + corner.x, head.z + corner.y)] = true

			var plants: Array = []         # [x, z, species]
			var seen: Dictionary = {}

			for chunk in chunks:
				var origin: Vector2 = placer.chunk_origin(chunk)
				var chunk_data = generator.get_tile(generator.tile_of(origin.x + 1.0, origin.y + 1.0))
				var found: Array = []
				placer._spring_cover(origin, chunk_data, found)
				var again: Array = []
				placer._spring_cover(origin, chunk_data, again)
				unstable += 0 if str(found) == str(again) else 1
				var mine: Array = []

				for f in found:
					var number: int = int(f[2]) - PlacerScript.SPRING_BASE - index * PlacerScript.SPRING_MAX_PLANTS

					if chunk_data == data and number >= 0 and number < PlacerScript.SPRING_MAX_PLANTS and Vector2(f[3] - head.x, f[5] - head.z).length() <= reach:
						var key: String = "%d/%d" % [int(f[1]), int(f[2])]
						twice += 1 if seen.has(key) else 0
						seen[key] = true
						plants.append([float(f[3]), float(f[5]), int(f[1])])
						mine.append(f)

				if tile == Vector2i(3, 4) and sampled.size() < SAMPLE and not mine.is_empty() and chunks.size() == 1:
					sampled.append([chunk, head, mine])

			var kinds: Dictionary = {}
			var nearest: float = INF

			for p in plants:
				kinds[p[2]] = true
				nearest = minf(nearest, Vector2(p[0] - head.x, p[1] - head.z).length())

			for sid in kinds:
				var name: String = str(placer.species_by_id(int(sid)).get("name", sid))
				by_species[name] = int(by_species.get(name, 0)) + 1

			if kinds.size() > 1:
				mixed.append([tile, index])

			if plants.size() >= least and nearest <= HEAD_M:
				full += 1
				continue

			var why: String = _excuse(data, head, reach, tile, tile_m)

			if why != "":
				excused.append([tile, index, plants.size(), why])
			elif plants.size() < least:
				short.append([tile, index, plants.size(), Vector2(head.x, head.z)])
			else:
				no_head.append([tile, index, nearest, Vector2(head.x, head.z)])

	print("spring cover: %d ground springs, %d with a full clump; species %s" % [springs, full, str(by_species)])

	for e in excused:
		print("  tile %s spring %d: %d plants (%s)" % [str(e[0]), e[1], e[2], e[3]])

	_check(springs > 0, "the record tiles list ground springs (%d)" % springs)
	_check(short.is_empty(), "every clump has at least %d plants where nothing drops one (%d short%s)" % [least, short.size(), (": " + str(short.slice(0, 5))) if not short.is_empty() else ""])
	_check(no_head.is_empty(), "every clump has a plant within %.1f m of the head (%d without%s)" % [HEAD_M, no_head.size(), (": " + str(no_head.slice(0, 5))) if not no_head.is_empty() else ""])
	_check(mixed.is_empty(), "every clump is one species (%d mixed)" % mixed.size())
	_check(twice == 0, "each plant of a clump stands in one chunk only (%d twice)" % twice)
	_check(unstable == 0, "placing a chunk's cover twice gives the same plants (%d differ)" % unstable)

	# The whole chunk placement keeps the sampled clumps whole (the clump claims its ground first).
	var kept: int = 0
	var wanted: int = 0

	for s in sampled:
		var made: Dictionary = placer.chunk_items(s[0])
		var ids: Dictionary = {}

		for n in range(made["ids"].size()):
			ids[made["ids"][n]] = true

		for f in s[2]:
			wanted += 1
			kept += 1 if ids.has((int(f[1]) << 16) | int(f[2])) else 0

	print("sampled %d clumps on tile 3,4 through chunk_items: %d of %d plants kept" % [sampled.size(), kept, wanted])
	_check(not sampled.is_empty() and kept == wanted, "the sampled clumps come through the whole chunk placement whole (%d of %d plants)" % [kept, wanted])
	print("PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)


# Why a clump may hold fewer plants: open lake or sea or a cave mouth within its reach, or a tile edge (the chunk over it reads its own tile). "" when none.
func _excuse(data, head: Vector3, reach: float, tile: Vector2i, tile_m: float) -> String:
	var x0: float = float(tile.x) * tile_m
	var z0: float = float(tile.y) * tile_m

	if head.x - reach < x0 or head.z - reach < z0 or head.x + reach >= x0 + tile_m or head.z + reach >= z0 + tile_m:
		return "tile edge"

	for ring in [0.0, 0.5 * reach, reach]:
		for a in range(8):
			var x: float = head.x + cos(TAU * float(a) / 8.0) * ring
			var z: float = head.z + sin(TAU * float(a) / 8.0) * ring
			var cls: int = data.water_class[data.nearest(x, z)]

			if cls == PlacerScript.OCEAN_CLASS or cls == PlacerScript.LAKE_CLASS:
				return "lake or sea"

			if not data.cave_openings.is_empty() and data.in_cave_opening(x, z):
				return "cave mouth"

	return ""
