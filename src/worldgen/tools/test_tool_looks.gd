extends SceneTree
# Headless check of the tool looks brought to the pickaxe standard (Dave 2026-10-25), one group per round. Spades: a long straight haft along x with the blade at +x, wide in z
# and thin in y, metal tiers (iron, steel) on the metal surface, wood and stone tiers on one plain surface, the blade narrowing to a point.

const BasicLook := preload("res://src/client/basic_look.gd")
const HeldItem := preload("res://src/client/held_item.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	# Spades at real size for the large tier (size 1.0): about 85 cm of haft plus the grip, a 28 by 19 cm blade, scaled down for the medium (0.85) and small (0.7) tiers.
	for tier in ["wooden", "stone", "iron", "steel"]:
		for size in ["", "_medium", "_large"]:
			var id: String = tier + "_spade" + size
			var mesh: Mesh = BasicLook.mesh_for(id)
			var metal: bool = tier in ["iron", "steel"]
			var box: AABB = mesh.get_aabb()
			var scale: float = float(BasicLook.entry(id).get("size", 1.0))
			_check(absf(scale - {"": 0.7, "_medium": 0.85, "_large": 1.0}[size]) < 0.001, id + ": size %.2f scales the real-size large spade" % scale)
			_check(mesh.get_surface_count() == (2 if metal else 1), id + ": surfaces %d (metal tiers have the metal head surface)" % mesh.get_surface_count())
			_check(box.size.x > 1.15 * scale and box.size.x < 1.3 * scale, id + ": about 1.22 m overall at size 1, %.2f m (size %.2f)" % [box.size.x / scale, scale])
			_check(_y_extent(mesh, 0.52 * scale, 1.0, 1.0) < 0.045 * scale, id + ": the dished blade is shallow (y %.3f)" % (_y_extent(mesh, 0.52 * scale, 1.0, 1.0) / scale))
			_check(_y_extent(mesh, 0.6 * scale, 0.012 * scale, 0.012 * scale) < 0.008 * scale, id + ": a thin plate at the centre (%.4f m)" % (_y_extent(mesh, 0.6 * scale, 0.012 * scale, 0.012 * scale) / scale))
			_check(_width_near(mesh, 0.5 * scale, 0.02 * scale) > 0.17 * scale and _width_near(mesh, 0.5 * scale, 0.02 * scale) < 0.21 * scale, id + ": blade about 19 cm wide at the shoulders (%.3f)" % (_width_near(mesh, 0.5 * scale, 0.02 * scale) / scale))
			_check(_width_near(mesh, 0.78 * scale, 0.008 * scale) < 0.55 * _width_near(mesh, 0.5 * scale, 0.02 * scale), id + ": the blade tapers to a rounded tip")
			_check(_width_near(mesh, -0.36 * scale, 0.06 * scale) > 0.14 * scale and _width_near(mesh, -0.36 * scale, 0.06 * scale) < 0.18 * scale, id + ": a closed D-grip about 15 cm across (%.3f)" % (_width_near(mesh, -0.36 * scale, 0.06 * scale) / scale))

			var tris: int = 0

			for surface in mesh.get_surface_count():
				tris += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

			_check(tris <= 1200, id + ": %d triangles (budget 1200)" % tris)

	# Metal colours: no blue tint (blue not above red by more than 15 percent), iron darker than steel, spade metal roughness 0.55 while the pickaxe stays 0.4.
	for id in ["iron_spade_large", "steel_spade_large"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var colours: PackedColorArray = mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
		var mean: Color = Color(0, 0, 0, 0)

		for c in colours:
			mean += c

		mean /= float(colours.size())
		_check(mean.b < mean.r * 1.15, id + ": no blue tint (mean r %.3f b %.3f)" % [mean.r, mean.b])
		_check(absf((mesh.surface_get_material(1) as StandardMaterial3D).roughness - 0.65) < 0.001 and absf((mesh.surface_get_material(1) as StandardMaterial3D).metallic - 0.3) < 0.001, id + ": spade metal roughness 0.65, metallic 0.3 (little sky reflection)")

	_check(absf((BasicLook.mesh_for("iron_pickaxe").surface_get_material(1) as StandardMaterial3D).roughness - 0.4) < 0.001, "the locked pickaxe keeps metal roughness 0.4")
	_check(BasicLook.mesh_for("iron_spade_large").get_surface_count() == 2 and BasicLook.mesh_for("iron_spade_large").surface_get_material(1) != BasicLook.mesh_for("iron_pickaxe").surface_get_material(1), "spade and pickaxe use separate shared metal materials")

	# Carry in third person: a hoe blade-down (haft 45 to 60 degrees below horizontal), a saw by the handle with the blade down and back about 30 degrees.
	var hoe_dir: Vector3 = Basis(Vector3.RIGHT, deg_to_rad(HeldItem.THIRD_HOE_PITCH_DEG)) * HeldItem.HELD_LOOK_TURN["hoe"] * Vector3(1.0, 0.0, 0.0)
	var saw_dir: Vector3 = Basis(Vector3.RIGHT, deg_to_rad(HeldItem.THIRD_SAW_PITCH_DEG)) * HeldItem.HELD_LOOK_TURN["saw"] * Vector3(1.0, 0.0, 0.0)
	var hoe_below: float = rad_to_deg(asin(clampf(-hoe_dir.z, -1.0, 1.0)))
	print("carried hoe haft ", hoe_dir, " is ", hoe_below, " degrees below horizontal; saw blade ", saw_dir)
	_check(hoe_below >= 45.0 and hoe_below <= 60.0, "the carried hoe's haft is %.0f degrees below horizontal (45 to 60)" % hoe_below)
	_check(saw_dir.z < -0.8 and saw_dir.y < -0.3, "the carried saw's blade points down and back (%.2f, %.2f)" % [saw_dir.y, saw_dir.z])

	# Carry: a spade carried in third person points its blade down, at least 20 degrees from vertical but not past it (blade end below the hand).
	var carry: Basis = Basis(Vector3.RIGHT, deg_to_rad(HeldItem.THIRD_SPADE_PITCH_DEG)) * HeldItem.HELD_LOOK_TURN["spade"]
	var blade_dir: Vector3 = carry * Vector3(1.0, 0.0, 0.0)
	var from_vertical: float = rad_to_deg(acos(clampf(-blade_dir.z, -1.0, 1.0)))
	print("spade carried: blade direction ", blade_dir, " is ", from_vertical, " degrees from straight down")
	_check(blade_dir.z < -0.5 and from_vertical >= 20.0, "the carried spade points its blade down, %.0f degrees from vertical" % from_vertical)

	# Axes and hammers: a straight haft along x with the head at its +x end, head wider in z than the haft is thick, all on one plain surface (no metal heads yet).
	for id in ["stone_axe", "stone_hammer", "wooden_hammer"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var box: AABB = mesh.get_aabb()
		var scale: float = float(BasicLook.entry(id).get("size", 1.0))
		_check(mesh.get_surface_count() == 1, id + ": one plain surface")
		_check(box.size.x > 0.4 * scale and box.size.x < 0.9 * scale, id + ": haft along x, %.2f m long (size %.1f)" % [box.size.x, scale])
		_check(box.size.z > 0.1 * scale, id + ": the head is wide across the haft (z %.3f)" % box.size.z)
		_check(_width_near(mesh, 0.22 * scale, 0.1 * scale) > 0.1 * scale, id + ": the head sits at the haft's end (width %.3f near x 0.22)" % _width_near(mesh, 0.22 * scale, 0.1 * scale))
	# Hoes (size 1.0): a 1.25 m haft along x, the blade hanging toward +z, thin in x, wide across y, widening toward the edge; metal tiers on the metal surface.
	for tier in ["wooden", "stone", "iron", "steel"]:
		var id: String = tier + "_hoe"
		var mesh: Mesh = BasicLook.mesh_for(id)
		var box: AABB = mesh.get_aabb()
		var tris: int = 0

		for surface in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

		_check(mesh.get_surface_count() == (2 if tier in ["iron", "steel"] else 1), id + ": surfaces %d" % mesh.get_surface_count())
		_check(box.size.x > 1.3 and box.size.x < 1.45, id + ": about 1.37 m overall (%.2f)" % box.size.x)
		_check(box.size.y > 0.15 and box.size.y < 0.19 and box.end.z > 0.15, id + ": the blade is wide across y (%.3f) and hangs toward +z (to %.3f)" % [box.size.y, box.end.z])
		_check(tris <= 1200, id + ": %d triangles" % tris)

	# Hand saw: about 60 cm overall, a thin blade (z extent 11 cm at the heel), narrower at the toe, on the metal surface.
	var saw: Mesh = BasicLook.mesh_for("hand_saw")
	_check(saw.get_surface_count() == 2, "hand_saw: wooden grip plus the metal blade surface")
	_check(saw.get_aabb().size.x > 0.55 and saw.get_aabb().size.x < 0.66, "hand_saw: about 60 cm overall (%.2f)" % saw.get_aabb().size.x)
	_check(_width_near(saw, -0.1, 0.02) > _width_near(saw, 0.25, 0.02) + 0.02, "hand_saw: the blade narrows toward the toe (%.3f to %.3f)" % [_width_near(saw, -0.1, 0.02), _width_near(saw, 0.25, 0.02)])
	_check(_width_near(saw, -0.1, 0.015) > 0.12 and _width_near(saw, -0.1, 0.015) < 0.16, "hand_saw: about 14 cm across at the heel (%.3f)" % _width_near(saw, -0.1, 0.015))
	_check(_width_near(saw, 0.32, 0.012) < 0.06, "hand_saw: about 5 cm or less at the rounded toe (%.3f)" % _width_near(saw, 0.32, 0.012))
	var saw_tris: int = 0

	for surface in saw.get_surface_count():
		saw_tris += (saw.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

	_check(saw_tris <= 1200, "hand_saw: %d triangles" % saw_tris)
	_check(_y_extent(saw, 0.0, 0.02, 0.03) < 0.01, "hand_saw: a thin plate (%.4f)" % _y_extent(saw, 0.0, 0.02, 0.03))

	# Stone knife: about 23 cm overall at size 1, blade about as long as the handle, a leaf blade (widest in the middle, narrow at the tip), matt stone (not bright steel).
	var knife: Mesh = BasicLook.mesh_for("stone_knife")
	var knife_scale: float = float(BasicLook.entry("stone_knife").get("size", 1.0))
	var length: float = knife.get_aabb().size.x / knife_scale
	_check(knife.get_surface_count() == 1, "stone_knife: one plain surface, no metal sheen")
	_check(length > 0.2 and length < 0.26, "stone_knife: about 23 cm overall (%.3f m)" % length)
	_check(_width_near(knife, 0.06 * knife_scale, 0.015 * knife_scale) > 2.0 * _width_near(knife, 0.14 * knife_scale, 0.008 * knife_scale), "stone_knife: leaf-shaped blade, wide in the middle and narrow at the tip")
	var brightest: float = 0.0

	for v in (knife.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray):
		brightest = maxf(brightest, v.get_luminance())

	_check(brightest < 0.3, "stone_knife: matt stone, no pale steel tones (brightest %.2f)" % brightest)
	_check(str(BasicLook.entry("wooden_hammer").get("shape", "")) == "hammer", "wooden_hammer is drawn as a mallet, not an axe")

	print("tool looks: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# The y extent of the vertices with x above `from_x` (an x window of `window` when it is small) and |z| below `z_limit`: how thick the blade is there.
func _y_extent(mesh: Mesh, from_x: float, window: float, z_limit: float) -> float:
	var low: float = 1e9
	var high: float = -1e9

	for surface in mesh.get_surface_count():
		for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if (v.x > from_x if window >= 1.0 else absf(v.x - from_x) < window) and absf(v.z) <= (z_limit if z_limit < 1.0 else 1e9):
				low = minf(low, v.y)
				high = maxf(high, v.y)

	return high - low


# The z extent of the vertices whose x is within `within` of `at`.
func _width_near(mesh: Mesh, at: float, within: float = 0.02) -> float:
	var low: float = 1e9
	var high: float = -1e9

	for surface in mesh.get_surface_count():
		for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.x - at) < within:
				low = minf(low, v.z)
				high = maxf(high, v.z)

	return high - low
