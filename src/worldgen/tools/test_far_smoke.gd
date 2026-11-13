extends SceneTree

# Far campfire smoke (TEST-011, Dave approved 13 Nov 2026: smoke seen up to 2 km so a camp can be found from a hill; protocol 114 far_fires).
# The server lists the lit campfires past world_items' 100 m and within 2 km, nearest first, at most 32, with their tiers; the client
# (src/client/far_smoke.gd) gives each the tall smoke column only, the same materials as a near fire's (so the same wind), drops those past
# its terrain view distance and draws only the nearest eight.
#   godot --headless --path . -s src/worldgen/tools/test_far_smoke.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const FarSmokeScript := preload("res://src/client/far_smoke.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var _fails: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		_fails += 1


func _initialize() -> void:
	await process_frame
	_server()
	_client()
	print("far smoke: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)


func _server() -> void:
	var items = ItemsScript.new()
	var id: int = 1

	# Lit fires of each tier at growing distance east, one put out, one in coals, one at 50 m (sent whole), one at 3 km.
	for row in [[50.0, 1], [150.0, 40], [400.0, 1], [900.0, 41], [1500.0, 1], [2040.0, 1], [3000.0, 1], [300.0, 0], [600.0, ItemsScript.FIRE_STATE_COALS]]:
		items._items[id] = {"pos": Vector3(float(row[0]), 5.0, 0.0), "number": 1, "count": 1, "fire": {"state": int(row[1])}}
		id += 1

	items._items[id] = {"pos": Vector3(250.0, 5.0, 0.0), "number": 1, "count": 3}   # not a fire
	id += 1
	items._sync_world_items()
	var rows: Array = items.far_fires_near(Vector3.ZERO)
	var xs: Array = []

	for p in rows[0]:
		xs.append(int(p.x))

	check(xs == [150, 400, 900, 1500, 2040], "lit fires 100 m to 2048 m, nearest first; the 50 m one (sent whole), the 3 km one, the cold one and the coals left out (%s)" % str(xs))
	check(Array(rows[1]) == [1, 2, 3, 2, 2], "each with its tier: survival 1, campfire 2, bonfire 3 (%s)" % str(Array(rows[1])))

	for k in range(40):
		items._items[id] = {"pos": Vector3(0.0, 5.0, 200.0 + 10.0 * float(k)), "number": 1, "count": 1, "fire": {"state": 1}}
		id += 1

	items._sync_world_items()
	rows = items.far_fires_near(Vector3.ZERO)
	check(rows[0].size() == ItemsScript.FAR_FIRE_COUNT and rows[0].size() == rows[1].size(), "at most %d (%d)" % [ItemsScript.FAR_FIRE_COUNT, rows[0].size()])
	check((rows[0][0] as Vector3).length() < 160.0 and (rows[0][31] as Vector3).length() <= 510.0, "the nearest ones kept")

	var methods: Array = []
	var net: Node = Net.new()

	for m in net.get_method_list():
		methods.append(str(m["name"]))

	net.free()

	check(methods.has("far_fires") and Net.PROTOCOL_VERSION >= 114, "protocol 114 carries far_fires (%d)" % Net.PROTOCOL_VERSION)


func _client() -> void:
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(0.0, 2.0, 0.0)
	var far: Node3D = FarSmokeScript.new()
	root.add_child(far)
	var points: PackedVector3Array = PackedVector3Array()
	var tiers: PackedByteArray = PackedByteArray()

	for k in range(12):
		points.append(Vector3(150.0 + 100.0 * float(k), 5.0, 0.0))
		tiers.append(1 + k % 3)

	far.on_far_fires(points, tiers)
	check(far.plume_count() == 12, "a plume for each far fire (%d)" % far.plume_count())
	var cap: int = int(BuildingLook.tall_tier("far_max_fires", 1))
	check(far.shown_count() == cap, "only the nearest %d draw (%d)" % [cap, far.shown_count()])
	var nearest: GPUParticles3D = null
	var farthest: GPUParticles3D = null

	for child in far.get_children():
		if (child as Node3D).global_position.x < 160.0:
			nearest = child
		elif (child as Node3D).global_position.x > 1200.0:
			farthest = child

	check(nearest != null and nearest.visible and farthest != null and not farthest.visible, "the nearest shows, the farthest waits")
	check(nearest != null and nearest.process_material == BuildingLook._tall_smoke[1] and nearest.draw_pass_1 == BuildingLook._tall_smoke_mesh,
		"a far plume shares the near fires' tall smoke material (the same wind, rise and fade)")
	check(nearest != null and nearest.find_children("*", "OmniLight3D").is_empty() and nearest.get_child_count() == 0, "smoke only: no light, flames or sparks")

	var before: int = BuildingLook._tall_plumes.size()
	far.on_far_fires(points, tiers)
	check(far.plume_count() == 12 and BuildingLook._tall_plumes.size() == before, "the same set again changes nothing, and far plumes stay out of the near fires' cap")

	far.view_m = func() -> float: return 400.0
	far.refresh()
	check(far.shown_count() == 3, "past the terrain's view distance none draw (%d within 400 m)" % far.shown_count())
	far.view_m = Callable()

	tiers[0] = 3
	far.on_far_fires(points.slice(0, 5), tiers.slice(0, 5))
	check(far.plume_count() == 5, "fires gone from the list lose their plume (%d)" % far.plume_count())
	var bonfire: bool = false

	for child in far.get_children():
		if not child.is_queued_for_deletion() and (child as Node3D).global_position.x < 160.0:
			bonfire = int(child.get_meta("tier", 0)) == 3

	check(bonfire, "a fire that grew gets the bigger plume")
	far.on_far_fires(PackedVector3Array(), PackedByteArray())
	check(far.plume_count() == 0, "an empty list clears them all")
