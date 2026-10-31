extends SceneTree

# Cover query checks (COVER_QUERY.md).
#   godot --headless --path . --script res://src/worldgen/tools/test_cover.gd

const Cover := preload("res://src/shared/cover.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var index = Cover.Index.new()
	# species 3: a tree with a 10 m crown (5 m radius), reference height 20 m.
	var info: Callable = func(species_id: int) -> Array: return [0, 10.0, 20.0] if species_id == 3 else ([1, 2.0, 2.0] if species_id == 4 else [])
	var items: Dictionary = {
		"ids": PackedInt32Array([(3 << 16) | 1, (3 << 16) | 2, (4 << 16) | 3, (9 << 16) | 4]),
		"positions": PackedVector3Array([Vector3(100.0, 50.0, 100.0), Vector3(130.0, 50.0, 100.0), Vector3(200.0, 50.0, 200.0), Vector3(300.0, 50.0, 300.0)]),
		"heights": PackedFloat32Array([20.0, 17.0, 2.0, 5.0]),
		"yaws": PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
	}
	Cover.add_chunk(index, Vector2i(0, 0), items, info)
	check(index.trees == 2, "only trees are indexed (%d)" % index.trees)
	check(Cover.at(Vector3(100.0, 52.0, 100.0), index) == 1.0, "under the crown is covered")
	check(Cover.at(Vector3(104.0, 52.0, 100.0), index) == 1.0, "inside the radius is covered")
	check(Cover.at(Vector3(109.5, 52.0, 100.0), index) == 1.0 and Cover.at(Vector3(110.5, 52.0, 100.0), index) == 0.0, "the sheltered radius is the full crown_m (10 m for a 10 m crown)")
	check(Cover.at(Vector3(111.0, 52.0, 100.0), index) == 0.0, "outside the radius is open")
	check(Cover.at(Vector3(100.0, 80.0, 100.0), index) == 0.0, "above the treetop is open")
	# The smaller grown tree (height 17 of 20, scale 0.85): radius 10 * 0.85 = 8.5 m.
	check(Cover.at(Vector3(138.4, 52.0, 100.0), index) == 1.0 and Cover.at(Vector3(138.6, 52.0, 100.0), index) == 0.0, "crown grows with the tree's size")
	# A young tree (height 10 of 20, scale 0.5) gives no shelter at all (Dave 2026-10-30).
	var young: Dictionary = {"ids": PackedInt32Array([(3 << 16) | 8]), "positions": PackedVector3Array([Vector3(400.0, 50.0, 400.0)]), "heights": PackedFloat32Array([10.0]), "yaws": PackedFloat32Array([0.0])}
	Cover.add_chunk(index, Vector2i(2, 2), young, info)
	check(Cover.at(Vector3(400.0, 52.0, 400.0), index) == 0.0, "a young tree gives no shelter")
	check(Cover.at(Vector3(200.0, 52.0, 200.0), index) == 0.0, "shrubs give no cover")
	check(Cover.at(Vector3(100.0, 52.0, 100.0), null) == 0.0, "no index means open")

	# A crown crossing a cell border is found from the next cell.
	var edge: Dictionary = {"ids": PackedInt32Array([(3 << 16) | 7]), "positions": PackedVector3Array([Vector3(159.0, 0.0, 10.0)]), "heights": PackedFloat32Array([20.0]), "yaws": PackedFloat32Array([0.0])}
	Cover.add_chunk(index, Vector2i(1, 0), edge, info)
	check(Cover.at(Vector3(163.0, 2.0, 10.0), index) == 1.0, "crown across a cell border")

	check(index.discs_near(130.0, 100.0, 10.0).size() == 1, "discs near (%d)" % index.discs_near(130.0, 100.0, 10.0).size())
	check(index.discs_near(1000.0, 1000.0, 10.0).is_empty(), "no discs far away")

	# Felling and dropping chunks.
	index.remove_item(Vector2i(0, 0), (3 << 16) | 1)
	check(Cover.at(Vector3(100.0, 52.0, 100.0), index) == 0.0, "felled tree opens the ground")
	check(Cover.at(Vector3(130.0, 52.0, 100.0), index) == 1.0, "the others stay")
	index.remove_chunk(Vector2i(0, 0))
	check(Cover.at(Vector3(130.0, 52.0, 100.0), index) == 0.0, "dropped chunk is open")
	check(Cover.at(Vector3(163.0, 2.0, 10.0), index) == 1.0, "other chunks stay")
	index.remove_chunk(Vector2i(1, 0))
	check(index.trees == 0, "index empty again (%d)" % index.trees)

	# Roofs: a yawed box spanning several cells and a disc.
	var roof_index = Cover.Index.new()
	var box: int = roof_index.add_roof(Cover.box_roof(Vector2(500.0, 500.0), 20.0, 3.0, PI * 0.5, 10.0, 14.0))
	check(Cover.at(Vector3(500.0, 12.0, 515.0), roof_index) == 1.0, "under a turned box, far along its length")
	check(Cover.at(Vector3(505.0, 12.0, 515.0), roof_index) == 0.0, "beside the box")
	check(Cover.at(Vector3(500.0, 15.0, 500.0), roof_index) == 0.0, "standing on the roof is not covered")
	check(Cover.at(Vector3(500.0, 9.0, 500.0), roof_index) == 0.0, "below the roof floor is open")
	var disc: int = roof_index.add_roof(Cover.disc_roof(Vector2(0.0, 0.0), 6.0, 0.0, 5.0))
	check(Cover.at(Vector3(4.0, 2.0, 0.0), roof_index) == 1.0, "under the disc")
	check(roof_index.roofs_near(0.0, 0.0, 5.0).size() == 1, "roofs near")
	roof_index.remove_roof(box)
	check(Cover.at(Vector3(500.0, 12.0, 515.0), roof_index) == 0.0, "removed box opens the ground")
	roof_index.remove_roof(disc)
	check(roof_index.roof_count() == 0, "roofs gone")

	# Cost: 25k trees in a chunk-sized spread, 10k queries.
	var many: Array = []

	for n in range(25000):
		many.append([n, float(n % 500) * 2.0, float(n / 500) * 2.0, 4.0, 40.0])

	index.set_chunk(Vector2i(5, 5), many)
	var started: int = Time.get_ticks_usec()

	for n in range(10000):
		Cover.at(Vector3(float(n % 400) * 2.5, 1.0, float(n / 400) * 2.5), index)

	print("cover: 10000 queries over 25000 trees took %d ms" % [(Time.get_ticks_usec() - started) / 1000])
	print("cover: %d failures" % failures)
	quit(1 if failures > 0 else 0)
