extends SceneTree

# Fen, bog and swamp stand out (Dave 21 Nov 2026: "make them all. I like it. do that now"): the look ids, the ground layer and sound they
# take, the still pools (share of flat ground each), the slowed pace, the wetland plants' rows and the dawn and dusk mist window.
#   godot --headless --path . --script res://src/worldgen/tools/test_wetland_signs.gd      Prints "test_wetland_signs: N failures".

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const Generator := preload("res://src/worldgen/runtime/terrain_generator.gd")
const GroundMaterial := preload("res://src/client/ground_material.gd")
const Puddles := preload("res://src/client/puddles.gd")
const SoundStage := preload("res://src/client/sound_stage.gd")
const WetlandMist := preload("res://src/client/wetland_mist.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# A tile's water classes as the generator reads them (tile_terrain_data.gd fields _wetland_look uses).
class FakeTile:
	var placeholder: bool = false
	var samples: int = 4
	var x0: float = 0.0
	var z0: float = 0.0
	var spacing_m: float = 8.0
	var water_class: PackedByteArray = PackedByteArray()


func _init() -> void:
	# The look ids: past the soils, below the rock ids, and each keeps its real soil for digging and texture layers.
	for look in [Layout.MATERIAL_FEN, Layout.MATERIAL_BOG, Layout.MATERIAL_SWAMP]:
		check(look > 16 and look < Layout.MATERIAL_ROCK, "look id %d sits between the soils and the rock ids" % look)
		check(Layout.is_wetland(look) and GroundMaterial.layer_of(look) == GroundMaterial.layer_of(Layout.soil_of(look)), "look %d draws with its soil's texture layer" % look)
		check(String(SoundStage.SOIL_SURFACE.get(look, "")) == "mud", "look %d squelches underfoot" % look)

	check(Layout.soil_of(Layout.MATERIAL_FEN) == 6 and Layout.soil_of(Layout.MATERIAL_BOG) == 6 and Layout.soil_of(Layout.MATERIAL_SWAMP) == 16, "fen and bog are peat, swamp is mud")
	check(Layout.soil_of(3) == 3 and not Layout.is_wetland(6) and not Layout.is_wetland(Layout.MATERIAL_ROCK + 2), "plain soils and rock are their own soil")
	# The server names the ground under a dig by soils.json (terrain_server.gd items.ground_material, through soil_of): a fen digs as peat,
	# a swamp as mud; and no soil id may ever reach the look ids.
	var soil_names: Dictionary = {}

	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/soils.json")).get("entries", []):
		soil_names[int(row["id"])] = String(row["name"])
		check(int(row["id"]) < Layout.MATERIAL_FEN, "soil %s (id %d) sits below the wetland look ids" % [row["name"], int(row["id"])])

	check(String(soil_names.get(Layout.soil_of(Layout.MATERIAL_FEN), "")) == "peat" and String(soil_names.get(Layout.soil_of(Layout.MATERIAL_BOG), "")) == "peat"
		and String(soil_names.get(Layout.soil_of(Layout.MATERIAL_SWAMP), "")) == "mud", "fen and bog dig as peat, swamp as mud")
	var layers: PackedFloat32Array = GroundMaterial.layers()

	for n in range(17):
		check(int(layers[n]) == int(GroundMaterial.SOIL_LAYER[n]), "soil %d keeps its texture layer" % n)

	check(int(layers[20]) == 5 and int(layers[Layout.MATERIAL_ROCK]) == 5, "unknown ids and rock draw as rock")

	# The generator: a cell of fen draws fen in its middle, plain ground stays plain, and the soil is never changed.
	var generator = Generator.new()
	generator._wet_look.resize(256)
	generator._wet_look.fill(0)
	generator._wet_look[7] = Layout.MATERIAL_FEN
	var tile := FakeTile.new()
	tile.water_class.resize(16)
	tile.water_class.fill(0)

	for j in range(2):
		for i in range(2):
			tile.water_class[j * 4 + i] = 7

	check(generator._wetland_look(tile, 6, 1.0, 1.0) == Layout.MATERIAL_FEN, "fen ground draws fen")
	check(generator._wetland_look(tile, 3, 24.0, 24.0) == 3, "dry ground keeps its soil look")
	check(generator._wetland_look(tile, 0, 1.0, 1.0) == 0, "air stays air")
	tile.placeholder = true
	check(generator._wetland_look(tile, 6, 1.0, 1.0) == 6, "a placeholder tile draws plain soil")

	# Still pools: none on slopes or dry ground, and roughly the share of flat ground the shader shows (POOL_LEVEL, provisional).
	check(Puddles.pool_at(3.0, 4.0, 6, 1.0) == 0.0 and Puddles.pool_at(3.0, 4.0, Layout.MATERIAL_SWAMP, 0.9) == 0.0, "no pools on plain peat or on a slope")
	var shares: Array = []

	for look in [Layout.MATERIAL_FEN, Layout.MATERIAL_BOG, Layout.MATERIAL_SWAMP]:
		var wet: int = 0

		for k in range(4000):
			if Puddles.pool_at(float(k % 64) * 1.37, floorf(float(k) / 64.0) * 1.37, look, 1.0) > 0.5:
				wet += 1

		shares.append(float(wet) / 4000.0)

	print("still water on flat ground: fen %.0f%%, bog %.0f%%, swamp %.0f%%" % [shares[0] * 100.0, shares[1] * 100.0, shares[2] * 100.0])
	check(shares[2] > shares[0] and shares[0] > shares[1] and shares[1] > 0.01 and shares[2] < 0.7, "swamp holds the most standing water, bog the least")
	check(SoundStage.POOL_PACE > 0.7 and SoundStage.POOL_PACE < 1.0, "a pool slows the walker a little (%.2f of the pace)" % SoundStage.POOL_PACE)

	# The plants: wetland only, on the right kind, never along rivers (no per_hectare), each with a drawn look.
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var classes: Dictionary = {}

	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/water_classes.json")).get("entries", []):
		classes[String(row["name"])] = row

	var want: Dictionary = {"cattail": ["fen"], "tussock_sedge": ["fen", "swamp"], "moss_hummock": ["bog"], "cotton_grass": ["bog"], "dead_tree": ["swamp"]}
	var found: int = 0

	for entry in flora.get("entries", []):
		var row: Dictionary = entry
		var plant: String = String(row.get("name", ""))

		for water in row.get("per_water", {}):
			check(classes.has(water) and Layout.WETLAND_LOOKS.has(water), "%s: per_water %s is fen, bog or swamp" % [plant, water])

		if want.has(plant):
			found += 1
			var keys: Array = (row.get("per_water", {}) as Dictionary).keys()
			keys.sort()
			check(keys == want[plant], "%s grows on %s (%s)" % [plant, want[plant], keys])
			check(not (row.get("per_hectare", {}) as Dictionary).has("marsh") and (row.get("water", []) as Array).is_empty(), "%s does not grow along rivers or the marsh edge" % plant)

	check(found == want.size(), "all five wetland plants are in flora.json")

	# The mist: dawn and dusk only, thinned by wind, gone in rain; patches apart, nearest first.
	check(WetlandMist.strength_of(6.0, 6.0, 18.0, 0.0, 0.0) > 0.9 and WetlandMist.strength_of(18.5, 6.0, 18.0, 0.0, 0.0) > 0.9, "full mist at sunrise and just after sunset")
	check(WetlandMist.strength_of(12.0, 6.0, 18.0, 0.0, 0.0) == 0.0 and WetlandMist.strength_of(1.0, 6.0, 18.0, 0.0, 0.0) == 0.0, "no mist at noon or in the dead of night")
	check(WetlandMist.strength_of(6.0, 6.0, 18.0, 0.8, 0.0) == 0.0 and WetlandMist.strength_of(6.0, 6.0, 18.0, 0.0, 0.5) == 0.0, "no mist in a strong wind or in rain")
	var spots: Array = [Vector3(100, 0, 0), Vector3(5, 0, 0), Vector3(10, 0, 0), Vector3(40, 0, 0), Vector3(70, 0, 0), Vector3(200, 0, 0), Vector3(300, 0, 0)]
	var picked: Array = WetlandMist.pick_patches(spots, Vector3.ZERO)
	check(picked.size() == WetlandMist.PATCHES and picked[0] == Vector3(5, 0, 0) and not picked.has(Vector3(10, 0, 0)), "mist patches stand apart, nearest first (%s)" % [picked])

	generator = null
	print("test_wetland_signs: %d failures" % failures)
	quit(1 if failures > 0 else 0)
