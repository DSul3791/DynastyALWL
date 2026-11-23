extends SceneTree

# Nothing grows out of a tree trunk (world audit, 23 Nov 2026: 1,896 plants in 307 chunks stood inside a trunk). The placer leaves out only
# those plants: every other item keeps its id, position, height and yaw, so the removals, picks and regrowth a live save records by
# (chunk, id) still name the same plants after the change.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_in_trunk.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file("res://worlds/base_world/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, "res://worlds/base_world/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	# Woods round the starter town and an oak wood south of it, where the audit found strawberries and blueberries in oak trunks.
	# Plus the everember grove west of the town (trunks 2.5 to 3.9 m wide, bank shrubs by its brooks): no shrub or bank clump member may go.
	var chunks: Array = [placer.chunk_of(58075.0, 71128.0), placer.chunk_of(58018.0, 71431.0), placer.chunk_of(56200.0, 67040.0),
		placer.chunk_of(50330.0, 69091.0), placer.chunk_of(50590.0, 69091.0), placer.chunk_of(50330.0, 68835.0)]
	var dropped: int = 0
	var kept_all: bool = true
	var same_all: bool = true
	var inside: int = 0
	var only_inside: bool = true

	for chunk in chunks:
		placer.trunk_filter = false
		var before: Dictionary = placer.chunk_items(chunk)
		placer.trunk_filter = true
		var after: Dictionary = placer.chunk_items(chunk)
		var old: Dictionary = {}

		for n in range((before["ids"] as PackedInt32Array).size()):
			old[before["ids"][n]] = n

		for n in range((after["ids"] as PackedInt32Array).size()):
			var id: int = after["ids"][n]

			if not old.has(id):
				kept_all = false
				continue

			var m: int = old[id]
			same_all = same_all and before["positions"][m] == after["positions"][n] and before["heights"][m] == after["heights"][n] and before["yaws"][m] == after["yaws"][n]

		dropped += (before["ids"] as PackedInt32Array).size() - (after["ids"] as PackedInt32Array).size()
		var now: Dictionary = {}

		for n in range((after["ids"] as PackedInt32Array).size()):
			now[after["ids"][n]] = true

		var trunks_before: Array = []

		for n in range((before["ids"] as PackedInt32Array).size()):
			var sp: Dictionary = placer.species_of(before["ids"][n])

			if int(sp["kind"]) == PlacerScript.KIND_TREE:
				trunks_before.append([before["positions"][n], float(sp["trunk"]) * float(before["heights"][n]) / float(sp["height_ref"])])

		for n in range((before["ids"] as PackedInt32Array).size()):
			if now.has(before["ids"][n]):
				continue

			var p: Vector3 = before["positions"][n]
			var was_inside: bool = false

			for t in trunks_before:
				was_inside = was_inside or Vector2(p.x - t[0].x, p.z - t[0].z).length() < float(t[1])

			if not was_inside or int(placer.species_of(before["ids"][n])["kind"]) != PlacerScript.KIND_PLANT:
				only_inside = false

		# Every item left out was a plant or shrub inside a trunk of the same result; none is inside one now.
		var trees: Array = []

		for n in range((after["ids"] as PackedInt32Array).size()):
			var sp: Dictionary = placer.species_of(after["ids"][n])

			if int(sp["kind"]) == PlacerScript.KIND_TREE:
				trees.append([after["positions"][n], float(sp["trunk"]) * float(after["heights"][n]) / float(sp["height_ref"])])

		for n in range((after["ids"] as PackedInt32Array).size()):
			var sp: Dictionary = placer.species_of(after["ids"][n])

			if int(sp["kind"]) != PlacerScript.KIND_PLANT:
				continue   # shrubs keep the spacing rules (_make_room), as before

			var p: Vector3 = after["positions"][n]

			for t in trees:
				if Vector2(p.x - t[0].x, p.z - t[0].z).length() < float(t[1]):
					inside += 1

	check(kept_all, "every item kept after the change has an id the placer gave before (no id is new or renumbered)")
	check(same_all, "every kept item has the same position, height and yaw as before")
	check(only_inside, "every item left out was a small plant inside a tree trunk (no tree, shrub or bank clump member went with it)")
	check(dropped > 0, "plants inside trunks were left out (%d in %d chunks)" % [dropped, chunks.size()])
	check(inside == 0, "no small plant stands inside a tree trunk (%d)" % inside)
	print("test_flora_in_trunk: %d failures" % failures)
	quit(1 if failures > 0 else 0)
