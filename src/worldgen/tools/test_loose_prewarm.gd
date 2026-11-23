extends SceneTree

# The loose item meshes are built once, before the first world-items list arrives (bug 6, join freeze: 961 ms of loose_mesh for 282 items).
# Run: godot --headless --path . --script res://src/worldgen/tools/test_loose_prewarm.gd

const ViewScript := preload("res://src/client/inventory_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")


func _init() -> void:
	var failures: int = 0
	var view: Node = ViewScript.new()
	view.table = ItemTableScript.load_default()
	view._prewarm_loose_meshes()
	var cached: int = view._meshes.size()

	if cached < 5:
		print("FAIL prewarm cached only %d meshes" % cached)
		failures += 1

	for id in ["stone", "stick", "firewood", "log"]:
		if not view._meshes.has(view.table.number_of(id)):
			print("FAIL %s not prewarmed" % id)
			failures += 1

	for id in ["leaves", "kindling", "tree_roots", "beechnuts"]:   # what a trunk splits into besides logs (Dave 2 Nov: a pause as the trunk came apart)
		if view.table.number_of(id) > 0 and not view._meshes.has(view.table.number_of(id)):
			print("FAIL trunk drop %s not prewarmed" % id)
			failures += 1

	var t0: int = Time.get_ticks_usec()

	for k in range(300):
		view._mesh_for(view.table.number_of("log"))
		view._natural_mesh(view.table.number_of("stick"), k)

	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("300 cached lookups %.1f ms, %d meshes cached" % [ms, cached])

	if ms > 50.0:
		print("FAIL cached lookups too slow")
		failures += 1

	# Bug 6 (Dave 2 Nov: a pause and a missing tree on the first fell): a stump is built at load, so the bark shader exists before the first fell
	# (a felled tree has no trunk any more: it comes down in its logs, 16 Nov 2026).
	var world: Node3D = Node3D.new()
	view._root = world
	view._prewarm_felled()

	if world.get_child_count() != 1 or ViewScript._felled_bark_shader == null:
		print("FAIL stump not prewarmed (%d nodes)" % world.get_child_count())
		failures += 1

	# Lag lane 23 Nov 2026: the first lit fire took about 1 s at the join (the starter town's bonfire); one lit and one unlit fire of each size
	# are made at load, out of sight, and dropped with the stump.
	view._prewarm_fires()
	var fires: int = 0

	for child in world.get_children():
		if child.position.y < -9000.0 and child.get_node_or_null("Light") != null:
			fires += 1

	if world.get_child_count() != 7 or fires != 3 or view._felled_warm.size() != 7:
		print("FAIL fires not prewarmed (%d nodes, %d lit, %d to drop)" % [world.get_child_count(), fires, view._felled_warm.size()])
		failures += 1

	view._drop_felled_warm()
	world.free()
	view.free()
	print("test_loose_prewarm: %d failures" % failures)
	quit(failures)
